import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/staggered_fade_in.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';

/// Linked external identities for the current account. Ports the
/// "External sign-in methods" card / loadIdentities() in app.js.
///
/// Layout: header → three-state body. Loading renders [SkeletonListTile],
/// "not enabled" (404) renders an [EmptyState] notEnabled variant, failures
/// render a retryable [PortalErrorCard], and an empty list renders an
/// [EmptyState] (loading/empty/error triad).
class IdentitiesTab extends StatefulWidget {
  final PortalApi api;

  const IdentitiesTab({super.key, required this.api});

  @override
  State<IdentitiesTab> createState() => _IdentitiesTabState();
}

class _IdentitiesTabState extends State<IdentitiesTab> {
  bool _loading = true;
  bool _available = true;
  List<Map<String, dynamic>> _identities = const [];
  String? _error;
  String? _notice;
  String? _busyId;
  final TextEditingController _filterCtrl = TextEditingController();
  String _query = '';
  String? _providerFilter;

  List<String> get _providerOptions {
    final providers = _identities
        .map((identity) => identity['provider']?.toString() ?? '')
        .where((provider) => provider.isNotEmpty)
        .toSet()
        .toList();
    providers.sort();
    return providers;
  }

  List<Map<String, dynamic>> get _filteredIdentities {
    final query = _query.trim().toLowerCase();
    return _identities
        .where((identity) {
          final provider = identity['provider']?.toString() ?? '';
          final subject = identity['subject']?.toString() ?? '';
          final linkedAt = identity['linked_at']?.toString() ?? '';
          final id = identity['id']?.toString() ?? '';
          final matchesProvider =
              _providerFilter == null || provider == _providerFilter;
          final matchesQuery =
              query.isEmpty ||
              [
                provider,
                subject,
                linkedAt,
                id,
              ].any((value) => value.toLowerCase().contains(query));
          return matchesProvider && matchesQuery;
        })
        .toList(growable: false);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    setState(() => _query = value);
  }

  void _clearFilters() {
    _filterCtrl.clear();
    setState(() {
      _query = '';
      _providerFilter = null;
    });
  }

  Future<void> _load({bool preserveNotice = false}) async {
    setState(() {
      _loading = true;
      _available = true;
      _error = null;
      if (!preserveNotice) _notice = null;
    });
    try {
      final response = await widget.api.get('/me/identities');
      if (!mounted) return;
      if (response.statusCode == 404) {
        setState(() {
          _available = false;
          _identities = const [];
        });
        return;
      }
      if (response.statusCode != 200) {
        setState(() => _error = 'Could not load linked identities.');
        return;
      }
      final values =
          PortalApi.decode(response)['identities'] as List? ?? const [];
      setState(() {
        _available = true;
        _identities = values
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .toList(growable: false);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load linked identities.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unlink(Map<String, dynamic> identity) async {
    final id = identity['id']?.toString() ?? '';
    if (id.isEmpty) {
      setState(() => _error = 'This identity record has no usable ID.');
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Unlink identity?',
      message:
          'You may be unable to sign in with this provider after unlinking it.',
      confirmLabel: 'Unlink',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _busyId = id;
      _notice = null;
      _error = null;
    });
    try {
      final response = await widget.api.delete(
        '/me/identities/${Uri.encodeComponent(id)}',
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() => _notice = 'Identity unlinked.');
        await _load(preserveNotice: true);
      } else if (response.statusCode == 409) {
        setState(
          () => _error =
              'Add another sign-in method before unlinking this identity.',
        );
      } else {
        setState(() => _error = 'Could not unlink this identity.');
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not unlink this identity.');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  /// Renders one identity row: brand-tinted provider icon, provider name
  /// (API value, raw [Text]), subject + linked-at meta, danger Unlink
  /// action with a per-row busy spinner.
  Widget _identityRow(BuildContext context, Map<String, dynamic> identity) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final id = identity['id']?.toString() ?? '';
    final provider = identity['provider']?.toString() ?? '';
    final subject = identity['subject']?.toString() ?? '';
    final linkedAt = identity['linked_at']?.toString();
    final busy = _busyId == id;
    final meta = [
      if (subject.isNotEmpty) subject,
      if (linkedAt != null && linkedAt.isNotEmpty)
        context.tr(' · linked {time}', {'time': linkedAt}),
    ].join();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_providerIcon(provider), size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  provider.isEmpty ? context.tr('Unknown') : provider,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: busy ? null : () => _unlink(identity),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('Unlink')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filteredIdentities = _filteredIdentities;
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
                        context.strings.linkedIdentities,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr(
                        'Third-party identities linked to your account for '
                        'sign-in.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.tr('Refresh identities'),
                onPressed: _loading || _busyId != null ? null : _load,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const SkeletonListTile(itemCount: 3)
              : !_available
              ? const EmptyState(
                  compact: true,
                  variant: EmptyStateVariant.notEnabled,
                  icon: Icons.link_off,
                  title: 'Linked-identity management is not enabled.',
                )
              : _error != null
              ? PortalErrorCard(message: context.tr(_error!), onRetry: _load)
              : PullToRefresh(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    children: [
                      MessageBanner(_notice, ok: true),
                      if (_identities.isNotEmpty) ...[
                        Align(
                          alignment: Alignment.centerLeft,
                          child: StatusChip(
                            label: context.tr('Linked identities'),
                            color: AppColors.accentBlue,
                            icon: Icons.link,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SearchFilterBar(
                          controller: _filterCtrl,
                          hintText: context.strings.search,
                          filterOptions: _providerOptions,
                          selectedFilter: _providerFilter,
                          onSearchChanged: _onSearchChanged,
                          onFilterChanged: (value) =>
                              setState(() => _providerFilter = value),
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_identities.isEmpty)
                        const EmptyState(
                          compact: true,
                          icon: Icons.link_outlined,
                          title:
                              'No external identities are linked to this '
                              'account.',
                        )
                      else if (filteredIdentities.isEmpty)
                        EmptyState(
                          compact: true,
                          variant: EmptyStateVariant.noMatch,
                          title: 'No matches',
                          actionLabel: 'Clear filter',
                          actionIcon: Icons.filter_alt_off,
                          onAction: _clearFilters,
                        )
                      else
                        PortalCard(
                          title: 'External sign-in methods',
                          children: [
                            for (final (index, identity)
                                in filteredIdentities.indexed)
                              StaggeredFadeIn(
                                index: index,
                                child: _identityRow(context, identity),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

/// Maps a provider name (API value) to a stable Material icon; unknown
/// providers fall back to a generic link glyph. Never routed through i18n —
/// provider names are API values.
IconData _providerIcon(String provider) {
  final name = provider.toLowerCase();
  if (name.contains('github')) return Icons.code;
  if (name.contains('gitlab')) return Icons.merge_type;
  if (name.contains('google')) return Icons.g_mobiledata;
  if (name.contains('microsoft') ||
      name.contains('azure') ||
      name.contains('entra')) {
    return Icons.window;
  }
  if (name.contains('facebook')) return Icons.facebook;
  if (name.contains('apple')) return Icons.apple;
  if (name.contains('linkedin')) return Icons.work_outline;
  return Icons.link;
}
