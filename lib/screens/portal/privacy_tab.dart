import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'portal_api.dart';
import 'portal_widgets.dart';

/// GDPR data export + account deletion (Art. 17). Ports the "Download your
/// data" and "Delete your account" cards / their handlers in app.js.
class PrivacyTab extends StatefulWidget {
  final PortalApi api;
  final String mySub;
  final VoidCallback onAccountDeleted;
  const PrivacyTab({super.key, required this.api, required this.mySub, required this.onAccountDeleted});

  @override
  State<PrivacyTab> createState() => _PrivacyTabState();
}

class _PrivacyTabState extends State<PrivacyTab> {
  // --- Data export ---
  bool _exportBusy = false;
  String? _exportMsg;
  bool _exportOk = false;
  String? _exportBody;

  // --- Account deletion ---
  bool _previewBusy = false;
  String? _previewSummary;
  final TextEditingController _confirmCtrl = TextEditingController();
  String? _eraseMsg;
  bool _eraseBusy = false;

  @override
  void dispose() {
    _confirmCtrl.dispose();
    super.dispose();
  }

  // app.js turns the GET /me/data-export response into a browser file
  // download via Blob + an <a download> click. Flutter web has no built-in
  // way to do that without a JS-interop package (dart:html/package:web),
  // neither of which is wired into this build (see report) — as a working
  // substitute we show the exported JSON inline and offer "Copy to
  // clipboard" via Flutter's built-in Clipboard API instead of a save-as-file.
  Future<void> _export() async {
    setState(() {
      _exportBusy = true;
      _exportMsg = 'Preparing your export...';
      _exportOk = true;
      _exportBody = null;
    });
    try {
      final r = await widget.api.get('/me/data-export');
      if (r.statusCode == 404) {
        setState(() {
          _exportMsg = 'Data export is not enabled.';
          _exportOk = false;
        });
        return;
      }
      if (r.statusCode != 200) {
        setState(() {
          _exportMsg = 'Export failed.';
          _exportOk = false;
        });
        return;
      }
      setState(() {
        _exportBody = r.body;
        _exportMsg = 'Your data is ready below.';
        _exportOk = true;
      });
    } catch (_) {
      setState(() {
        _exportMsg = 'Request failed.';
        _exportOk = false;
      });
    } finally {
      if (mounted) setState(() => _exportBusy = false);
    }
  }

  Future<void> _copyExport() async {
    final body = _exportBody;
    if (body == null) return;
    await Clipboard.setData(ClipboardData(text: body));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Copied to clipboard.')),
    );
  }

  Future<void> _previewErase() async {
    setState(() {
      _previewBusy = true;
      _eraseMsg = null;
    });
    try {
      final r = await widget.api.post('/me/account/erase', {'dry_run': true});
      if (r.statusCode == 404) {
        setState(() => _eraseMsg = 'Account deletion is not enabled.');
        return;
      }
      if (r.statusCode != 200) {
        setState(() => _eraseMsg = 'Could not preview deletion.');
        return;
      }
      final d = PortalApi.decode(r);
      setState(() {
        _previewSummary = _eraseSummary(d);
        _eraseMsg = null;
      });
    } catch (_) {
      setState(() => _eraseMsg = 'Request failed.');
    } finally {
      if (mounted) setState(() => _previewBusy = false);
    }
  }

  String _eraseSummary(Map<String, dynamic> d) {
    final parts = <String>[
      'Refresh tokens: ${d['refresh_tokens_deleted'] ?? 0}',
      'Sessions: ${d['sessions_destroyed'] ?? 0}',
      'User record: ${d['user_deleted'] == true ? 'yes' : 'no'}',
    ];
    final skipped = (d['skipped'] as List?) ?? const [];
    if (skipped.isNotEmpty) parts.add('Skipped: ${skipped.join(', ')}');
    return parts.join(' · ');
  }

  Future<void> _erase() async {
    final confirm = _confirmCtrl.text.trim();
    if (confirm != widget.mySub) {
      setState(() => _eraseMsg = 'Type your subject exactly to confirm.');
      return;
    }
    setState(() {
      _eraseBusy = true;
      _eraseMsg = null;
    });
    try {
      final r = await widget.api.post('/me/account/erase', {
        'confirmation': confirm,
        'confirm': confirm,
        'dry_run': false,
      });
      if (r.statusCode == 404) {
        setState(() => _eraseMsg = 'Account deletion is not enabled.');
        return;
      }
      if (r.statusCode != 200) {
        setState(() => _eraseMsg = 'Deletion was not confirmed.');
        return;
      }
      widget.api.signOut();
      widget.onAccountDeleted();
    } catch (_) {
      setState(() => _eraseMsg = 'Request failed.');
    } finally {
      if (mounted) setState(() => _eraseBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Data and privacy', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        PortalCard(
          title: 'Download your data',
          children: [
            Text(
              'Export a copy of the data we hold about your account.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _exportBusy ? null : _export,
                child: _exportBusy
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Export my data'),
              ),
            ),
            MessageBanner(_exportMsg, ok: _exportOk),
            if (_exportBody != null) ...[
              const SizedBox(height: 12),
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade700),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(_exportBody!, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _copyExport,
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy to clipboard'),
                ),
              ),
            ],
          ],
        ),
        PortalCard(
          title: 'Delete your account',
          children: [
            Text(
              'This permanently removes your account, sessions and tokens. This cannot be undone.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _previewBusy ? null : _previewErase,
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                child: _previewBusy
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Preview deletion (dry run)'),
              ),
            ),
            if (_previewSummary != null) ...[
              const SizedBox(height: 10),
              Text('Would remove — $_previewSummary', style: TextStyle(color: Colors.grey.shade400)),
            ],
            const SizedBox(height: 14),
            TextField(
              controller: _confirmCtrl,
              decoration: InputDecoration(labelText: 'Type your subject to confirm', hintText: widget.mySub),
            ),
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _eraseBusy ? null : _erase,
                style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
                child: _eraseBusy
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Permanently delete my account'),
              ),
            ),
            MessageBanner(_eraseMsg, ok: false),
          ],
        ),
      ],
    );
  }
}
