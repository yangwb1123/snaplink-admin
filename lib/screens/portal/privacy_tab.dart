import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_api.dart';
import 'portal_export_download.dart';
import 'portal_widgets.dart';

/// GDPR data export + account deletion (Art. 17). Ports the "Download your
/// data" and "Delete your account" cards / their handlers in app.js.
class PrivacyTab extends StatefulWidget {
  final PortalApi api;
  final String mySub;
  final VoidCallback onAccountDeleted;
  const PrivacyTab({
    super.key,
    required this.api,
    required this.mySub,
    required this.onAccountDeleted,
  });

  @override
  State<PrivacyTab> createState() => _PrivacyTabState();
}

class _PrivacyTabState extends State<PrivacyTab> {
  // --- Data export ---
  bool _exportBusy = false;
  String? _exportMsg;
  bool _exportOk = false;

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

  Future<void> _export() async {
    setState(() {
      _exportBusy = true;
      _exportMsg = 'Preparing your export...';
      _exportOk = true;
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
      final started = downloadPortalExport(r);
      setState(() {
        _exportMsg = started
            ? 'Your download has started.'
            : 'Data export download is available in the web console.';
        _exportOk = started;
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
      context.tr('Refresh tokens: {count}', {
        'count': d['refresh_tokens_deleted'] ?? 0,
      }),
      context.tr('Sessions: {count}', {'count': d['sessions_destroyed'] ?? 0}),
      context.tr('User record: {state}', {
        'state': context.tr(d['user_deleted'] == true ? 'yes' : 'no'),
      }),
    ];
    final skipped = (d['skipped'] as List?) ?? const [];
    if (skipped.isNotEmpty) {
      parts.add(context.tr('Skipped: {items}', {'items': skipped.join(', ')}));
    }
    return parts.join(' · ');
  }

  Future<void> _erase() async {
    final confirm = _confirmCtrl.text.trim();
    if (confirm.isEmpty || confirm != widget.mySub) {
      setState(() => _eraseMsg = 'Type your subject exactly to confirm.');
      return;
    }
    setState(() {
      _eraseBusy = true;
      _eraseMsg = null;
    });
    try {
      final r = await widget.api.post('/me/account/erase', {
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
        Text(
          context.tr('Data and privacy'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        PortalCard(
          title: 'Download your data',
          children: [
            Text(
              context.tr(
                'Export a copy of the data we hold about your account.',
              ),
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _exportBusy ? null : _export,
                child: _exportBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Export my data')),
              ),
            ),
            MessageBanner(_exportMsg, ok: _exportOk),
          ],
        ),
        PortalCard(
          title: 'Delete your account',
          children: [
            Text(
              context.tr(
                'This permanently removes your account, sessions and tokens. This cannot be undone.',
              ),
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: _previewBusy ? null : _previewErase,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                ),
                child: _previewBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Preview deletion (dry run)')),
              ),
            ),
            if (_previewSummary != null) ...[
              const SizedBox(height: 12),
              Text(
                context.tr('Would remove — {summary}', {
                  'summary': _previewSummary,
                }),
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _confirmCtrl,
              decoration: InputDecoration(
                labelText: context.tr('Type your subject to confirm'),
                hintText: widget.mySub,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _eraseBusy ? null : _erase,
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                ),
                child: _eraseBusy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(context.tr('Permanently delete my account')),
              ),
            ),
            MessageBanner(_eraseMsg, ok: false),
          ],
        ),
      ],
    );
  }
}
