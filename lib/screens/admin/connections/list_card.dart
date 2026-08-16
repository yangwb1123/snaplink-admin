import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import '../admin_module_groups.dart';

class ConnectionsListCard extends StatelessWidget {
  final TextEditingController tenantController;
  final TextEditingController lookupController;
  final List<Map<String, dynamic>> connections;
  final bool canList;
  final bool canGet;
  final bool loadingList;
  final bool loadingConnection;
  final bool mutating;
  final VoidCallback onLoadList;
  final VoidCallback onLoadSelected;
  final ValueChanged<String> onSelect;

  const ConnectionsListCard({
    super.key,
    required this.tenantController,
    required this.lookupController,
    required this.connections,
    required this.canList,
    required this.canGet,
    required this.loadingList,
    required this.loadingConnection,
    required this.mutating,
    required this.onLoadList,
    required this.onLoadSelected,
    required this.onSelect,
  });

  /// 模块强调色（connections → security 组 rose）。
  Color get _accent => adminModuleIconColor('connections');

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.link_outlined, size: 20, color: _accent),
              const SizedBox(width: 8),
              const Expanded(child: SectionHeader('Tenant connections')),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: tenantController,
            decoration: InputDecoration(
              labelText: 'Tenant ID'.localized,
              hintText: 'acme'.localized,
            ),
            onSubmitted: (_) => onLoadList(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: !canList || loadingList || mutating ? null : onLoadList,
            child: loadingList
                ? const LocalizedText('Loading…')
                : const LocalizedText('List connections'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: lookupController,
            decoration: InputDecoration(
              labelText: 'Connection ID'.localized,
              hintText: 'acme-okta'.localized,
            ),
            onSubmitted: (_) => onLoadSelected(),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: !canGet || loadingConnection || mutating
                ? null
                : onLoadSelected,
            child: const LocalizedText('Get connection'),
          ),
          if (loadingList && connections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: SkeletonListTile(itemCount: 3),
            )
          else if (connections.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: EmptyState(
                compact: true,
                variant: EmptyStateVariant.empty,
                title: 'No connections loaded.',
              ),
            )
          else ...[
            _summaryBar(context),
            AdminDataTable(
              minWidth: 640,
              columns: [
                AdminDataColumn(
                  id: 'connection',
                  label: 'Connection',
                  width: 220,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    _connectionTitle(connections[i]),
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'meta',
                  label: 'ID · Type',
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    '${connections[i]['id'] ?? ''} · ${connections[i]['type'] ?? ''}',
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'status',
                  label: 'Status', cardDetail: true,
                  builder: (_, i) => connections[i]['enabled'] == false
                      ? StatusChip.inactive(label: 'Disabled')
                      : StatusChip.active(label: 'Enabled'),
                ),
              ],
              itemCount: connections.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
              onRowTap: !canGet
                  ? null
                  : (i) => onSelect(connections[i]['id']?.toString() ?? ''),
            ),
          ],
        ],
      ),
    ),
  );

  /// 连接健康摘要（异常优先：禁用连接占比一眼可见）。
  /// SectionHeader（标题 + 总数徽章）+ DistributionBar（Enabled/Disabled
  /// 分段，Disabled 前置强调），替代手绘进度条。
  Widget _summaryBar(BuildContext context) {
    final total = connections.length;
    final disabled = connections.where((c) => c['enabled'] == false).length;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionHeader('Connections health', count: total),
          const SizedBox(height: 8),
          DistributionBar(
            emphasizedLabel: 'Disabled',
            segments: [
              DistributionSegment(
                label: 'Enabled',
                value: total - disabled,
                color: AppColors.success,
              ),
              DistributionSegment(
                label: 'Disabled',
                value: disabled,
                color: AppColors.warning,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _connectionTitle(Map<String, dynamic> connection) {
    final displayName = connection['display_name']?.toString() ?? '';
    return displayName.isNotEmpty
        ? displayName
        : connection['id']?.toString() ?? 'Unnamed connection';
  }
}
