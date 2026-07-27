import 'package:flutter/material.dart';

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
          Text('Members', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          TextField(
            controller: memberUserController,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'user@example.com',
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: memberRole,
            decoration: const InputDecoration(labelText: 'Organization role'),
            items: const [
              DropdownMenuItem(value: 'member', child: Text('Member')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'guest', child: Text('Guest')),
            ],
            onChanged: mutating ? null : (v) => onRoleChanged(v ?? memberRole),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: mutating ? null : onSaveMember,
            child: const Text('Add or update member'),
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No members loaded.'),
            ),
          for (final member in members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                member['user_id']?.toString() ??
                    member['userId']?.toString() ??
                    '',
              ),
              subtitle: Text(member['role']?.toString() ?? 'member'),
              trailing: TextButton(
                onPressed: mutating
                    ? null
                    : () => onRemoveMember(
                        member['user_id']?.toString() ??
                            member['userId']?.toString() ??
                            '',
                      ),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Remove'),
              ),
            ),
        ],
      ),
    ),
  );
}
