import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/staggered_fade_in.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';

/// Connected applications (OAuth consents) list + per-app revoke. Ports the
/// "Connected applications" card / loadConsents() in app.js.
///
/// Layout: header → three-state body. Loading renders [SkeletonListTile],
/// failures render a retryable [PortalErrorCard], and an empty list renders
/// an [EmptyState] (loading/empty/error triad). Each row shows the client id
/// (API value, raw [Text]), the granted scopes, and a destructive Revoke
/// action behind the shared [ConfirmDialog], with a per-row busy spinner.
class ConsentsTab extends StatefulWidget {
  final PortalApi api;

  const ConsentsTab({super.key, required this.api});

  @override
  State<ConsentsTab> createState() => _ConsentsTabState();
}

class _ConsentsTabState extends State<ConsentsTab> {
  bool _loading = true;
  bool _loadInFlight = false;
  List<Map<String, dynamic>> _consents = const [];
  String? _error;
  String? _notice;
  String? _pendingClientId;
  String? _revokingClientId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool preserveNotice = false}) async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
        if (!preserveNotice) _notice = null;
      });
    }
    try {
      final response = await widget.api.get('/consents/me');
      if (!mounted) return;
      if (response.statusCode == 401) {
        setState(() => _error = 'Your session has expired.');
        return;
      }
      if (response.statusCode != 200) {
        setState(() => _error = 'Connected applications are not available.');
        return;
      }
      final values =
          PortalApi.decode(response)['consents'] as List? ?? const [];
      setState(() {
        _consents = values
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connected applications are not available.');
      }
    } finally {
      _loadInFlight = false;
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _revoke(String clientId) async {
    if (clientId.isEmpty ||
        _pendingClientId != null ||
        _revokingClientId != null) {
      return;
    }
    setState(() => _pendingClientId = clientId);
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke application access?',
      message: context.tr(
        '{clientId} will no longer be able to use the permissions you '
        'granted. You can authorize it again later.',
        {'clientId': clientId},
      ),
      confirmLabel: 'Revoke',
      destructive: true,
    );
    if (mounted) setState(() => _pendingClientId = null);
    if (confirmed != true || !mounted) return;
    setState(() {
      _revokingClientId = clientId;
      _notice = null;
      _error = null;
    });
    try {
      final response = await widget.api.delete(
        '/consents/me/${Uri.encodeComponent(clientId)}',
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _notice = 'Application access revoked.');
        await _load(preserveNotice: true);
      } else {
        _revokeError(clientId);
      }
    } catch (_) {
      if (mounted) _revokeError(clientId);
    } finally {
      if (mounted) setState(() => _revokingClientId = null);
    }
  }

  /// Renders one consent row: brand-tinted app icon, client id (API value,
  /// raw [Text]), granted scopes meta, and a danger Revoke action with a
  /// per-row busy spinner. Scope text stays the API-joined `'a b c'` string
  /// so the revoke semantics (and its tests) are unchanged.
  Widget _consentRow(BuildContext context, Map<String, dynamic> consent) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final clientId = consent['client_id']?.toString() ?? '';
    final scopes = ((consent['scopes'] as List?) ?? const [])
        .map((scope) => scope.toString())
        .join(' ');
    final busy = _revokingClientId == clientId;
    final action = TextButton(
      onPressed:
          busy ||
              clientId.isEmpty ||
              _pendingClientId != null ||
              (_revokingClientId != null && !busy)
          ? null
          : () => _revoke(clientId),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.danger,
        minimumSize: const Size(72, 48),
      ),
      child: busy
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Text(context.tr('Revoke')),
    );
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          clientId.isEmpty ? context.tr('Unknown') : clientId,
          softWrap: true,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (scopes.isNotEmpty) ...[
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline,
                size: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  scopes,
                  softWrap: true,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 420;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.apps_outlined, size: 19, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: narrow
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          details,
                          Align(
                            alignment: Alignment.centerRight,
                            child: action,
                          ),
                        ],
                      )
                    : details,
              ),
              if (!narrow) ...[const SizedBox(width: 8), action],
            ],
          );
        },
      ),
    );
  }

  List<Widget> _consentListChildren(BuildContext context) => [
    MessageBanner(_notice, ok: true),
    if (_consents.isEmpty)
      const EmptyState(
        compact: true,
        icon: Icons.apps_outlined,
        title: 'No connected applications.',
      )
    else
      PortalCard(
        title: 'Authorized applications',
        children: _consentRows(context),
      ),
  ];

  List<Widget> _consentRows(BuildContext context) => [
    for (final (index, consent) in _consents.indexed)
      StaggeredFadeIn(index: index, child: _consentRow(context, consent)),
  ];

  void _revokeError(String clientId) {
    showAppSnackBar(
      context,
      content: Text(context.tr('Could not revoke application access.')),
      kind: AppSnackBarKind.error,
      action: SnackBarAction(
        label: context.tr('Retry'),
        onPressed: () => _revoke(clientId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      container: true,
                      header: true,
                      child: Text(
                        context.tr('Connected applications'),
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Applications you have authorized to access your '
                        'account data.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Refresh applications'),
                onPressed:
                    _loading ||
                        _loadInFlight ||
                        _pendingClientId != null ||
                        _revokingClientId != null
                    ? null
                    : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const SkeletonListTile(itemCount: 3)
              : _error != null
              ? PortalErrorCard(message: context.tr(_error!), onRetry: _load)
              : PullToRefresh(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: _consentListChildren(context),
                  ),
                ),
        ),
      ],
    );
  }
}
