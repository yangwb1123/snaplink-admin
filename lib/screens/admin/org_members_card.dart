import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// Members management card for tenant organizations.
class OrgMembersCard extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final bool mutating;
  final TextEditingController memberUserController;
  final String memberRole;

  /// 模块强调色（tenants 组 amber）：标题图标按组色上色（X7）。
  /// 缺省时回退组色，保证无强调色传入的调用方（测试/复用）仍按组色渲染。
  final Color? accent;

  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSaveMember;
  final void Function(String userId) onRemoveMember;

  const OrgMembersCard({
    super.key,
    required this.members,
    required this.mutating,
    required this.memberUserController,
    required this.memberRole,
    this.accent,
    required this.onRoleChanged,
    required this.onSaveMember,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        this.accent ?? adminModuleIconColor(AdminModuleId.organizations);
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.groups_outlined, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    'Members',
                    count: members.isEmpty ? null : members.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memberUserController,
              decoration: InputDecoration(
                labelText: 'User ID'.localized,
                hintText: 'user@example.com'.localized,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: memberRole,
              decoration: InputDecoration(
                labelText: 'Organization role'.localized,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'member',
                  child: LocalizedText('Member'),
                ),
                DropdownMenuItem(value: 'admin', child: LocalizedText('Admin')),
                DropdownMenuItem(value: 'guest', child: LocalizedText('Guest')),
              ],
              onChanged: mutating
                  ? null
                  : (v) => onRoleChanged(v ?? memberRole),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: mutating ? null : onSaveMember,
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const LocalizedText('Add or update member'),
            ),
            if (members.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: EmptyState(compact: true, title: 'No members loaded.'),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _membersTable(context),
              ),
          ],
        ),
      ),
    );
  }

  Widget _membersTable(BuildContext context) => AdminDataTable(
    density: TableDensity.compact,
    minWidth: 560,
    columns: [
      AdminDataColumn(
        id: 'user',
        label: 'USER',
        width: 260,
        cardPrimary: true,
        builder: (context, i) => TableCellText(
          members[i]['user_id']?.toString() ??
              members[i]['userId']?.toString() ??
              '',
          bold: true,
        ),
      ),
      AdminDataColumn(
        id: 'role',
        label: 'ROLE',
        width: 140,
        builder: (context, i) => TableCellText(
          members[i]['role']?.toString() ?? 'member',
          muted: true,
        ),
      ),
      AdminDataColumn(
        id: 'actions',
        label: '',
        width: 110,
        builder: (context, i) => TextButton(
          onPressed: mutating
              ? null
              : () => onRemoveMember(
                  members[i]['user_id']?.toString() ??
                      members[i]['userId']?.toString() ??
                      '',
                ),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const LocalizedText('Remove'),
        ),
      ),
    ],
    itemCount: members.length,
    rowBuilder: (context, i) => const SizedBox.shrink(),
  );
}
