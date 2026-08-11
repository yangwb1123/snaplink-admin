import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';

/// Members management card for tenant organizations.
class OrgMembersCard extends StatelessWidget {
  final List<Map<String, dynamic>> members;
  final bool mutating;
  final TextEditingController memberUserController;
  final String memberRole;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSaveMember;
  final void Function(String userId) onRemoveMember;

  const OrgMembersCard({
    super.key,
    required this.members,
    required this.mutating,
    required this.memberUserController,
    required this.memberRole,
    required this.onRoleChanged,
    required this.onSaveMember,
    required this.onRemoveMember,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Members',
            style: Theme.of(context).textTheme.titleMedium,
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
              DropdownMenuItem(value: 'member', child: LocalizedText('Member')),
              DropdownMenuItem(value: 'admin', child: LocalizedText('Admin')),
              DropdownMenuItem(value: 'guest', child: LocalizedText('Guest')),
            ],
            onChanged: mutating ? null : (v) => onRoleChanged(v ?? memberRole),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: mutating ? null : onSaveMember,
            child: const LocalizedText('Add or update member'),
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No members loaded.'),
            )
          else
            _membersTable(context),
        ],
      ),
    ),
  );

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
