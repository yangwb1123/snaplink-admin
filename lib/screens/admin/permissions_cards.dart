import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'admin_module_groups.dart';

/// 权限模块组色（identity → indigo-violet）。
Color _accent() => adminModuleIconColor('permissions');

/// Roles management card: header + AdminDataTable (workbench rows).
class RolesCard extends StatelessWidget {
  final List<Map<String, dynamic>> roles;
  final bool mutating;
  final String? clientId;
  final VoidCallback onCreateRole;
  final void Function(Map<String, dynamic> role) onEditRole;
  final void Function(String code) onDeleteRole;

  const RolesCard({
    super.key,
    required this.roles,
    required this.mutating,
    required this.clientId,
    required this.onCreateRole,
    required this.onEditRole,
    required this.onDeleteRole,
  });

  String _name(Map<String, dynamic> role) =>
      role['name']?.toString() ?? role['code']?.toString() ?? '';

  String _code(Map<String, dynamic> role) =>
      role['code']?.toString() ?? '';

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final items = List<Map<String, dynamic>>.of(roles);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(
              'Roles',
              count: items.length,
              action: FilledButton.icon(
                onPressed: mutating || clientId == null ? null : onCreateRole,
                icon: const Icon(Icons.add, size: 18),
                label: const LocalizedText('Create role'),
              ),
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const EmptyState(compact: true, title: 'No roles loaded.')
            else
              AdminDataTable(
                minWidth: 720,
                columns: [
                  AdminDataColumn(
                    id: 'role',
                    label: 'ROLE',
                    width: 280,
                    cardPrimary: true,
                    builder: (context, i) => Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.shield_outlined, size: 16, color: accent),
                        const SizedBox(width: 8),
                        Flexible(
                          child: TableCellText(_name(items[i]), bold: true),
                        ),
                      ],
                    ),
                  ),
                  AdminDataColumn(
                    id: 'code',
                    label: 'CODE',
                    width: 180,
                    builder: (context, i) {
                      final code = _code(items[i]);
                      // 与显示名相同时不重复渲染（保持单实例文本）。
                      return TableCellText(
                        code == _name(items[i]) ? '' : code,
                        muted: true,
                      );
                    },
                  ),
                  AdminDataColumn(
                    id: 'permissions',
                    label: 'PERMISSIONS',
                    width: 200,
                    builder: (context, i) {
                      final count =
                          (items[i]['permissions'] as List?)?.length ?? 0;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.key_outlined, size: 14, color: accent),
                          const SizedBox(width: 8),
                          Flexible(
                            child: LocalizedText(
                              '{n} permissions',
                              args: {'n': count},
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  AdminDataColumn(
                    id: 'actions',
                    label: '',
                    width: 96,
                    builder: (context, i) {
                      final role = items[i];
                      return PopupMenuButton<String>(
                        enabled: !mutating,
                        onSelected: (action) {
                          if (action == 'edit') onEditRole(role);
                          if (action == 'delete') onDeleteRole(_code(role));
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: LocalizedText('Edit'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: LocalizedText('Delete'),
                          ),
                        ],
                      );
                    },
                  ),
                ],
                itemCount: items.length,
                rowBuilder: (context, i) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}

/// User role assignments card: assign form + AdminDataTable of subjects.
class AssignmentsCard extends StatelessWidget {
  final List<Map<String, dynamic>> assignments;
  final bool mutating;
  final String? clientId;
  final TextEditingController userController;
  final TextEditingController roleCodesController;
  final VoidCallback onAssignRoles;
  final void Function(String userId, String code) onUnassignRole;

  const AssignmentsCard({
    super.key,
    required this.assignments,
    required this.mutating,
    required this.clientId,
    required this.userController,
    required this.roleCodesController,
    required this.onAssignRoles,
    required this.onUnassignRole,
  });

  @override
  Widget build(BuildContext context) {
    final accent = _accent();
    final items = List<Map<String, dynamic>>.of(assignments);
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader('User role assignments', count: items.length),
            const SizedBox(height: 12),
            TextField(
              controller: userController,
              decoration: InputDecoration(
                labelText: 'User ID'.localized,
                prefixIcon: Icon(Icons.person_outline, size: 18, color: accent),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: roleCodesController,
              decoration: InputDecoration(
                labelText: 'Role codes'.localized,
                helperText:
                    'Comma or line separated. Snaplink validates that each role exists.'
                        .localized,
                prefixIcon: Icon(Icons.key_outlined, size: 18, color: accent),
              ),
              minLines: 1,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: mutating || clientId == null ? null : onAssignRoles,
              icon: const Icon(Icons.person_add_alt_1, size: 18),
              label: const LocalizedText('Assign roles'),
            ),
            const SizedBox(height: 16),
            if (items.isEmpty)
              const EmptyState(compact: true, title: 'No assignments loaded.')
            else
              AdminDataTable(
                minWidth: 640,
                columns: [
                  AdminDataColumn(
                    id: 'user',
                    label: 'USER',
                    width: 280,
                    cardPrimary: true,
                    builder: (context, i) => TableCellText(
                      items[i]['user_id']?.toString() ?? '',
                      bold: true,
                    ),
                  ),
                  AdminDataColumn(
                    id: 'roles',
                    label: 'ROLES',
                    width: 460,
                    builder: (context, i) {
                      final userId = items[i]['user_id']?.toString() ?? '';
                      final roles =
                          (items[i]['roles'] as List?)
                              ?.map((e) => e.toString())
                              .toList() ??
                          const <String>[];
                      return Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final code in roles)
                            InputChip(
                              label: Text(code),
                              visualDensity: VisualDensity.compact,
                              onDeleted: mutating
                                  ? null
                                  : () => onUnassignRole(userId, code),
                            ),
                        ],
                      );
                    },
                  ),
                ],
                itemCount: items.length,
                rowBuilder: (context, i) => const SizedBox.shrink(),
              ),
          ],
        ),
      ),
    );
  }
}
