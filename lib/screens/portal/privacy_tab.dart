import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_api.dart';
import 'portal_export_download.dart';
import 'portal_widgets.dart';

/// GDPR data export + account deletion (Art. 17). Ports the "Download your
/// data" and "Delete your account" cards / their handlers in app.js.
///
/// Action-driven page: idle renders guidance copy, busy shows an inline
/// progress row plus button spinners, and outcomes render via [MessageBanner]
/// (green success / red failure). Brand-tinted leading icons replace raw
/// glyphs; secondary copy uses theme tokens instead of hard-coded greys.
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
    if (_exportBusy) return;
    setState(() {
      _exportBusy = true;
      _exportMsg = null;
      _exportOk = false;
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
    if (_previewBusy || _eraseBusy) return;
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
    if (_eraseBusy || _previewBusy) return;
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
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Semantics(container: true, header: true, child: Text(context.tr('Data and privacy'), style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3))),
        const SizedBox(height: 4),
        Text(
          context.tr(
            'Data shared with this server and your export or deletion options.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        _exportCard(theme, accent),
        _deleteCard(theme),
      ],
    );
  }

  Widget _exportCard(ThemeData theme, Color accent) {
    return PortalCard(
      title: 'Download your data',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LeadingIcon(icon: Icons.file_download_outlined, color: accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(
                  'Export a copy of the data we hold about your account.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _export,
            icon: _exportBusy
                ? _spinner(theme.colorScheme.onPrimary)
                : const Icon(Icons.file_download_outlined, size: 18),
            label: Text(context.tr('Export my data')),
          ),
        ),
        if (_exportBusy)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: _busyRow(theme),
          )
        else
          MessageBanner(_exportMsg, ok: _exportOk),
      ],
    );
  }

  Widget _deleteCard(ThemeData theme) {
    return PortalCard(
      title: 'Delete your account',
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _LeadingIcon(
              icon: Icons.delete_forever_outlined,
              color: AppColors.danger,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.tr(
                  'This permanently removes your account, sessions and tokens. This cannot be undone.',
                ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _previewErase,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
            ),
            icon: _previewBusy
                ? _spinner(AppColors.danger)
                : const Icon(Icons.visibility_outlined, size: 18),
            label: Text(context.tr('Preview deletion (dry run)')),
          ),
        ),
        const SizedBox(height: 12),
        if (_previewSummary != null)
          _previewPanel(theme)
        else
          Text(
            context.tr('Run a dry run to see what will be removed.'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _confirmCtrl,
          enabled: !_eraseBusy,
          decoration: InputDecoration(
            labelText: context.tr('Type your subject to confirm'),
            hintText: widget.mySub,
            prefixIcon: const Icon(Icons.person_outline, size: 20),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _erase,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            icon: _eraseBusy
                ? _spinner(theme.colorScheme.onPrimary)
                : const Icon(Icons.delete_forever_outlined, size: 18),
            label: Text(context.tr('Permanently delete my account')),
          ),
        ),
        MessageBanner(_eraseMsg, ok: false),
      ],
    );
  }

  /// Dry-run result: danger-tinted panel listing what deletion would remove.
  Widget _previewPanel(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.tr('Would remove — {summary}', {
                'summary': _previewSummary!,
              }),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Inline progress row shown while an action is in flight.
  Widget _busyRow(ThemeData theme) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr('Preparing your export...'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Brand-tinted rounded icon container for card leading glyphs.
class _LeadingIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _LeadingIcon({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 19, color: color),
    );
  }
}

/// Small in-button busy indicator, tinted to sit on the button surface.
Widget _spinner(Color color) => SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        valueColor: AlwaysStoppedAnimation(color),
      ),
    );
