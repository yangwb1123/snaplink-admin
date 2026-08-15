import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:flutter/services.dart';

import '../admin_module_groups.dart';
import 'scim_models.dart';

String formatScimBytes(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB'
    : bytes >= 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
    : '$bytes B';

class ScimMetric extends StatelessWidget {
  final String label;
  final String value;

  const ScimMetric({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.analytics_outlined, size: 16),
    label: LocalizedText(
      '{label}: {value}',
      args: {'label': label, 'value': value},
    ),
  );
}

class ScimBulkResultSummary extends StatelessWidget {
  final Map<String, dynamic> result;

  const ScimBulkResultSummary({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final operations = (result['Operations'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final succeeded = operations.where((operation) {
      final status = int.tryParse(operation['status']?.toString() ?? '') ?? 0;
      return status >= 200 && status < 300;
    }).length;
    final unavailable = operations.where((operation) {
      final status = operation['status']?.toString() ?? '';
      return status == '404' || status == '501';
    }).length;
    return Card(
      child: ListTile(
        leading: Icon(
          succeeded == operations.length
              ? Icons.check_circle_outline
              : Icons.warning_amber_outlined,
          color: succeeded == operations.length
              ? AppColors.success
              : AppColors.warning,
        ),
        title: Text(
          '$succeeded of ${operations.length} operations succeeded',
        ),
        subtitle: LocalizedText(
          unavailable > 0
              ? '$unavailable operations returned 404/501; the target '
                    'resource family may not be enabled.'
              : operations.length == succeeded
              ? 'All reported operations completed.'
              : 'Inspect each status and response before retrying.',
        ),
      ),
    );
  }
}

class ScimQueryBar extends StatelessWidget {
  final ScimResourceKind kind;
  final TextEditingController filterController;
  final TextEditingController startIndexController;
  final int count;
  final String sortBy;
  final bool descending;
  final bool busy;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onDescendingChanged;
  final VoidCallback onApply;

  const ScimQueryBar({
    super.key,
    required this.kind,
    required this.filterController,
    required this.startIndexController,
    required this.count,
    required this.sortBy,
    required this.descending,
    required this.busy,
    required this.onCountChanged,
    required this.onSortChanged,
    required this.onDescendingChanged,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: filterController,
              decoration: InputDecoration(
                labelText: 'SCIM search filter'.localized,
                hintText: kind == ScimResourceKind.users
                    ? 'userName co "alice"'
                    : 'displayName sw "ops"',
                helperText:
                    'RFC 7644 filter; blank returns all resources'.localized,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => busy ? null : onApply(),
            ),
          ),
          SizedBox(
            width: 115,
            child: TextField(
              controller: startIndexController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Start index'.localized,
                helperText: '1-based'.localized,
              ),
              onSubmitted: (_) => busy ? null : onApply(),
            ),
          ),
          SizedBox(
            width: 105,
            child: DropdownButtonFormField<int>(
              initialValue: count,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Count'.localized,
                helperText: 'Max 200'.localized,
              ),
              items: const [25, 50, 100, 200]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: LocalizedText('{value}', args: {'value': value}),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) => onCountChanged(value ?? count),
            ),
          ),
          SizedBox(
            width: 185,
            child: DropdownButtonFormField<String>(
              initialValue: sortBy,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Sort by'.localized,
                helperText: 'Before pagination'.localized,
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: LocalizedText('Store order'),
                ),
                ...kind.sortAttributes.map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: busy ? null : (value) => onSortChanged(value ?? ''),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<bool>(
              initialValue: descending,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Order'.localized,
                helperText: 'Case-insensitive'.localized,
              ),
              items: const [
                DropdownMenuItem(
                  value: false,
                  child: LocalizedText('Ascending'),
                ),
                DropdownMenuItem(
                  value: true,
                  child: LocalizedText('Descending'),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) => onDescendingChanged(value ?? false),
            ),
          ),
          FilledButton.icon(
            onPressed: busy ? null : onApply,
            icon: const Icon(Icons.manage_search),
            label: const LocalizedText('Apply filters'),
          ),
        ],
      ),
    ),
  );
}

/// Users/Groups 资源表（AdminDataTable 替代手写 Card+ListTile 模板行）。
/// 行点击打开详情；`enabled` 为 false 时（变更进行中）禁用手势。
class ScimResourceTable extends StatelessWidget {
  final ScimResourceKind kind;
  final List<Map<String, dynamic>> resources;
  final bool enabled;
  final ValueChanged<Map<String, dynamic>> onOpen;

  const ScimResourceTable({
    super.key,
    required this.kind,
    required this.resources,
    required this.enabled,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final accent = adminModuleIconColor('scim-directory');
    final isUser = kind == ScimResourceKind.users;
    return AdminDataTable(
      scrollable: true,
      minWidth: isUser ? 880 : 700,
      onRowTap: enabled ? (index) => onOpen(resources[index]) : null,
      columns: [
        AdminDataColumn(
          id: 'name',
          label: isUser ? 'USER' : 'GROUP',
          width: 280,
          cardPrimary: true,
          builder: (context, index) {
            final resource = resources[index];
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: accent.withValues(alpha: 0.14),
                  child: Icon(
                    isUser ? Icons.person_outline : Icons.groups_outlined,
                    size: 16,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: TableCellText(
                    _displayName(resource, isUser),
                    bold: true,
                    maxLines: 1,
                  ),
                ),
              ],
            );
          },
        ),
        AdminDataColumn(
          id: 'id',
          label: 'ID',
          width: 240,
          builder: (context, index) => CopyableCell(
            text: resources[index]['id']?.toString() ?? '',
            contextProvider: () => context,
          ),
        ),
        if (isUser)
          AdminDataColumn(
            id: 'email',
            label: 'EMAIL',
            builder: (context, index) => TableCellText(
              _primaryEmail(resources[index]['emails']),
              muted: true,
              maxLines: 1,
            ),
          )
        else
          AdminDataColumn(
            id: 'members',
            label: 'MEMBERS',
            width: 110,
            builder: (context, index) => TableCellText(
              '${(resources[index]['members'] as List? ?? const []).length}',
              muted: true,
            ),
          ),
        if (isUser)
          AdminDataColumn(
            id: 'status',
            label: 'STATUS',
            width: 120,
            builder: (context, index) {
              final active = resources[index]['active'] != false;
              return Tooltip(
                message: active ? 'Active' : 'Inactive',
                child: Icon(
                  active ? Icons.check_circle_outline : Icons.block,
                  size: 18,
                  color: active
                      ? AppColors.success
                      : Theme.of(context).colorScheme.error,
                ),
              );
            },
          ),
      ],
      itemCount: resources.length,
      rowBuilder: (_, _) => const SizedBox.shrink(),
    );
  }

  static String _displayName(Map<String, dynamic> resource, bool isUser) {
    final name = resource['displayName']?.toString() ?? '';
    if (name.isNotEmpty) return name;
    return isUser
        ? resource['userName']?.toString() ?? ''
        : resource['id']?.toString() ?? '';
  }

  static String _primaryEmail(Object? value) {
    if (value is! List) return '';
    final emails = value.whereType<Map>().toList();
    if (emails.isEmpty) return '';
    final primary = emails.where((email) => email['primary'] == true).firstOrNull;
    return (primary ?? emails.first)['value']?.toString() ?? '';
  }
}

class ScimUnavailable extends StatelessWidget {
  final ScimResourceKind? kind;
  final VoidCallback onRetry;

  const ScimUnavailable({super.key, this.kind, required this.onRetry});

  @override
  Widget build(BuildContext context) => EmptyState(
    variant: EmptyStateVariant.notEnabled,
    icon: Icons.extension_off_outlined,
    title: kind == ScimResourceKind.groups
        ? 'SCIM Groups are not enabled'
        : 'SCIM is not enabled on this replica',
    subtitle: kind == ScimResourceKind.groups
        ? 'Groups require scim.groups.enabled and a permissions provider.'
        : 'The server returned 404 or 501 for this SCIM surface.',
    actionLabel: 'Probe again',
    onAction: onRetry,
  );
}
