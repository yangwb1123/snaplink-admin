import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/user_avatar.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// A single member row with role dropdown and remove button.
///
/// Semantics preserved from app.js's organization roster render: the role
/// dropdown is the change-role control (disabled while [busy]), and the
/// trailing danger button removes the member. Visual polish: brand-tinted
/// [UserAvatar], w600 user id, icon on the remove action.
class MemberRowTile extends StatelessWidget {
  final Map<String, dynamic> member;
  final List<String> roles;
  final bool busy;
  final void Function(Map<String, dynamic> member, String role) onChangeRole;
  final void Function(Map<String, dynamic> member) onRemove;

  const MemberRowTile({
    super.key,
    required this.member,
    required this.roles,
    required this.busy,
    required this.onChangeRole,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userId = member['user_id']?.toString() ?? '';
    final role = member['role']?.toString() ?? 'member';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: UserAvatar(name: userId, radius: 16),
      title: Text(
        userId,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: DropdownButton<String>(
        value: roles.contains(role) ? role : 'member',
        isDense: true,
        underline: const SizedBox.shrink(),
        items: roles
            .map(
              (value) => DropdownMenuItem(
                value: value,
                child: Text(context.tr(value)),
              ),
            )
            .toList(growable: false),
        onChanged: busy
            ? null
            : (next) {
                if (next != null) onChangeRole(member, next);
              },
      ),
      trailing: TextButton.icon(
        onPressed: busy ? null : () => onRemove(member),
        style: TextButton.styleFrom(foregroundColor: AppColors.danger),
        icon: const Icon(Icons.person_remove_outlined, size: 18),
        label: Text(context.tr('Remove')),
      ),
    );
  }
}
