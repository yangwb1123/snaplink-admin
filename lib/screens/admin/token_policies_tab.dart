import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

/// Token policy governance view tab.
class TokenPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<TokenPoliciesTab> createState() => _TokenPoliciesTabState();
}

class _TokenPoliciesTabState extends State<TokenPoliciesTab> {
  static const _path = '/api/v1/admin/token-policies';
  List<Map<String, dynamic>> _policies = const [];
  String? _error;
  bool _loading = false;

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_path) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_path);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      final items =
          data['policies'] as List? ?? data['token_policies'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _policies = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load token policies.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Row(
          children: [
            Text(
              AppStrings.of(context).tokenPolicies,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'.localized,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Token issuance and validation policy configuration.',
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const LocalizedText('Retry'),
                ),
              ],
            ),
          ),
        if (_loading) const SkeletonListTile(itemCount: 3),
        if (!_loading && _policies.isEmpty)
          EmptyState(title: 'No token policies configured.'),
        if (!_loading && _policies.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AdminDataTable(
              minWidth: 720,
              columns: [
                AdminDataColumn(
                  id: 'policy',
                  label: 'Policy',
                  width: 220,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    _policies[i]['name']?.toString() ??
                        _policies[i]['id']?.toString() ??
                        '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'effect',
                  label: 'Effect',
                  builder: (_, i) => TableCellText(
                    '${_policies[i]['effect'] ?? _policies[i]['action'] ?? 'allow'} · ${_policies[i]['priority'] ?? ''}',
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'description',
                  label: 'Description',
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _policies[i]['description']?.toString() ?? '',
                    muted: true,
                    maxLines: 2,
                  ),
                ),
              ],
              itemCount: _policies.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }
}
