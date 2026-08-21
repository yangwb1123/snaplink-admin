import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// Members management card for tenant organizations.
///
/// 图标按模块组色（tenants 组 amber）上色（X7）；count 徽章恒显示，
/// 空列表时与 EmptyState 并存（与用户支持页卡片一致）。
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
                  child: SectionHeader('Members', count: members.length),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: memberUserController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'User ID'.localized,
                hintText: 'user@example.com'.localized,
              ),
            ),
            const SizedBox(height: 12),
            // R31：3 项短枚举 → SegmentedButton（替代 Organization role 下拉）。
            LocalizedText(
              'Organization role',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'member', label: LocalizedText('Member')),
                ButtonSegment(value: 'admin', label: LocalizedText('Admin')),
                ButtonSegment(value: 'guest', label: LocalizedText('Guest')),
              ],
              selected: {memberRole},
              showSelectedIcon: false,
              onSelectionChanged: mutating
                  ? null
                  : (selection) => onRoleChanged(selection.first),
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
                child: EmptyState(
                  variant: EmptyStateVariant.empty,
                  title: 'No members loaded.',
                  subtitle: 'Add members using the form above.',
                  compact: true,
                ),
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
          // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
          style: TextButton.styleFrom(
            foregroundColor: AppColors.semanticFor(
              Theme.of(context).brightness,
              AppColors.danger,
            ),
          ),
          child: const LocalizedText('Remove'),
        ),
      ),
    ],
    itemCount: members.length,
    rowBuilder: (context, i) => const SizedBox.shrink(),
  );
}
