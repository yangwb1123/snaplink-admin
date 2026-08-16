import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import '../admin_route.dart';

/// 租户列表表格：选择列 + 名称/标识/状态列 + 行操作菜单。
///
/// 从 tenants_tab 拆出：选中集、行点击与生命周期动作全部通过回调由页面
/// 持有，保持 API 契约、状态徽章（StatusChip）与 i18n 语义不变。
class TenantsTable extends StatelessWidget {
  final List<Map<String, dynamic>> items;
  final bool selecting;
  final Set<String> selected;
  final String? busyId;
  final ValueChanged<int> onRowTap;
  final ValueChanged<int>? onRowLongPress;
  final ValueChanged<String> onToggleSelect;
  final void Function(String id, String currentStatus) onToggleStatus;
  final void Function(String id) onEdit;
  final void Function(String id, String label) onDelete;

  const TenantsTable({
    super.key,
    required this.items,
    required this.selecting,
    required this.selected,
    required this.busyId,
    required this.onRowTap,
    required this.onRowLongPress,
    required this.onToggleSelect,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return AdminDataTable(
      scrollable: true,
      minWidth: 760,
      onRowTap: onRowTap,
      onRowLongPress: onRowLongPress,
      columns: [
        if (selecting)
          AdminDataColumn(
            id: 'select',
            label: '',
            width: 44,
            builder: (context, i) {
              final id = items[i]['id']?.toString() ?? '';
              return Checkbox(
                value: selected.contains(id),
                onChanged: (_) => onToggleSelect(id),
              );
            },
          ),
        AdminDataColumn(
          id: 'name',
          label: 'TENANT',
          width: 240,
          // R52：排序走筛选行下拉（orderBy 服务端排序），表头不接 onSort——
          // 不再声明 sortable，避免可排序列声明与服务端接线不一致。
          builder: (context, i) => TableCellText(
            items[i]['name']?.toString() ?? items[i]['id']?.toString() ?? '?',
            bold: true,
            maxLines: 2,
          ),
        ),
        AdminDataColumn(
          id: 'slug',
          label: 'SLUG',
          width: 140,
          builder: (context, i) =>
              TableCellText(items[i]['slug']?.toString() ?? '', muted: true),
        ),
        AdminDataColumn(
          id: 'status',
          label: 'STATUS',
          width: 190,
          builder: (context, i) {
            final status = items[i]['status']?.toString() ?? 'active';
            return status == 'suspended'
                ? StatusChip.suspended()
                : StatusChip.active();
          },
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 60,
          builder: (context, i) => TenantRowActions(
            tenant: items[i],
            busyId: busyId,
            onToggleStatus: onToggleStatus,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ],
      itemCount: items.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}

/// 单行生命周期入口：忙态 spinner / 挂起·激活 / 编辑 / 删除菜单。
/// 动作执行（type-to-confirm → 撤销报告 → 刷新）仍由页面 [_runLifecycle]
/// 完成，本组件只渲染入口并转发回调。
class TenantRowActions extends StatelessWidget {
  final Map<String, dynamic> tenant;
  final String? busyId;
  final void Function(String id, String currentStatus) onToggleStatus;
  final void Function(String id) onEdit;
  final void Function(String id, String label) onDelete;

  const TenantRowActions({
    super.key,
    required this.tenant,
    required this.busyId,
    required this.onToggleStatus,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final id = tenant['id']?.toString() ?? '';
    final status = tenant['status']?.toString() ?? 'active';
    final suspended = status == 'suspended';
    if (busyId == id) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'toggle':
            onToggleStatus(id, status);
          case 'edit':
            onEdit(id);
          case 'delete':
            onDelete(id, tenant['name']?.toString() ?? id);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toggle',
          child: LocalizedText(suspended ? 'Activate' : 'Suspend'),
        ),
        const PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
        const PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
      ],
    );
  }
}

/// 租户空态：无数据 vs 筛选无匹配两种变体（图标/文案/动作与拆分前一致）。
/// 筛选无匹配时提供“清除筛选”动作（[onClearFilter]）。
class TenantsEmptyState extends StatelessWidget {
  final bool filtering;
  final VoidCallback? onClearFilter;

  const TenantsEmptyState({
    super.key,
    required this.filtering,
    this.onClearFilter,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      variant: filtering ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
      icon: filtering ? null : Icons.business,
      title: 'No tenants',
      subtitle: filtering ? 'No tenants match the current filter.' : null,
      actionLabel: filtering ? 'Clear filter' : 'Create tenant',
      actionIcon: filtering ? Icons.filter_alt_off : null,
      onAction: filtering
          ? onClearFilter
          : () => AdminRoute.go('tenants', action: 'new'),
    );
  }
}
