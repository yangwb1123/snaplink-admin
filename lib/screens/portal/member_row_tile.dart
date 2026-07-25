import 'package:flutter/material.dart';

/// A single member row with role dropdown and remove button.
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
    final userId = member['user_id']?.toString() ?? '';
    final role = member['role']?.toString() ?? 'member';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(userId),
      subtitle: DropdownButton<String>(
        value: roles.contains(role) ? role : 'member',
        items: roles
            .map((value) => DropdownMenuItem(value: value, child: Text(value)))
            .toList(growable: false),
        onChanged: busy ? null : (next) {
          if (next != null) onChangeRole(member, next);
        },
      ),
      trailing: TextButton(
        onPressed: busy ? null : () => onRemove(member),
        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
        child: const Text('Remove'),
      ),
    );
  }
}
