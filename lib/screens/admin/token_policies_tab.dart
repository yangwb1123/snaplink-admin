import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// Token policy governance view tab.
///
/// 只读策略列表页：GET /api/v1/admin/token-policies → 策略 name/effect/
/// priority/description。用量/Subject 统计属 usage-analytics 模块，不在本页。
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
  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;

  /// 模块强调色（security 组 rose）：页内图标/刷新统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.tokenPolicies);

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_path) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_path);

  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      final items =
          data['policies'] as List? ?? data['token_policies'] as List? ?? [];
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _policies = items
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && seq == _reqSeq) {
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
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).tokenPolicies,
          subtitle: 'Token issuance and validation policy configuration.',
          onRefresh: _load,
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        if (_error != null) ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading && _policies.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(
              compact: true,
              variant: EmptyStateVariant.empty,
              title: 'No token policies configured.',
            ),
          ),
        if (!_loading && _policies.isNotEmpty) _policiesCard(context),
      ],
    );
  }

  /// 策略卡：组色图标 + SectionHeader（含策略数）+ AdminDataTable(compact)。
  Widget _policiesCard(BuildContext context) {
    final rows = _policies;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.policy_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader('Token policies', count: rows.length),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              columns: [
                AdminDataColumn(
                  id: 'policy',
                  label: 'Policy'.localized,
                  width: 220,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    rows[i]['name']?.toString() ??
                        rows[i]['id']?.toString() ??
                        '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'effect',
                  label: 'Effect'.localized,
                  builder: (_, i) => _effectCell(rows[i]),
                ),
                AdminDataColumn(
                  id: 'description',
                  label: 'Description'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    rows[i]['description']?.toString() ?? '',
                    muted: true,
                    maxLines: 2,
                  ),
                ),
              ],
              itemCount: rows.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  /// Effect 单元格：StatusChip 表达 allow/deny 语义色（X9）；effect 与
  /// priority 均来自 API，走纯 Text（X1/X10 合规）。
  Widget _effectCell(Map<String, dynamic> policy) {
    final effect = (policy['effect'] ?? policy['action'] ?? 'allow').toString();
    final priority = policy['priority']?.toString() ?? '';
    final chip = switch (effect.toLowerCase()) {
      'allow' || 'permit' => StatusChip.active(label: effect),
      'deny' || 'block' => StatusChip.failed(label: effect),
      _ => StatusChip.info(label: effect),
    };
    return Row(
      children: [
        chip,
        if (priority.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              priority,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

