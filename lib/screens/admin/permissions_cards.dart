import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// Roles management card.
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

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              LocalizedText(
                'Roles',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: mutating || clientId == null ? null : onCreateRole,
                icon: const Icon(Icons.add),
                label: const LocalizedText('Create role'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (roles.isEmpty) const LocalizedText('No roles loaded.'),
          for (final role in roles)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                role['name']?.toString() ?? role['code']?.toString() ?? '',
              ),
              subtitle: LocalizedText(
                "${role['code'] ?? ''}\n${(role['permissions'] as List?)?.map((e) => e.toString()).join(', ') ?? ''}",
              ),
              isThreeLine: role['description']?.toString().isNotEmpty == true,
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Edit role'.localized,
                    onPressed: mutating ? null : () => onEditRole(role),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: 'Delete role'.localized,
                    onPressed: mutating
                        ? null
                        : () => onDeleteRole(role['code']?.toString() ?? ''),
                    color: AppColors.danger,
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

/// User role assignments card.
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'User role assignments',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: userController,
            decoration: InputDecoration(labelText: 'User ID'.localized),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: roleCodesController,
            decoration: InputDecoration(
              labelText: 'Role codes'.localized,
              helperText:
                  'Comma or line separated. Snaplink validates that each role exists.'
                      .localized,
            ),
            minLines: 1,
            maxLines: 3,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: mutating || clientId == null ? null : onAssignRoles,
            child: const LocalizedText('Assign roles'),
          ),
          if (assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No assignments loaded.'),
            ),
          for (final assignment in assignments)
            _AssignmentRowTile(
              assignment: assignment,
              mutating: mutating,
              onUnassign: onUnassignRole,
            ),
        ],
      ),
    ),
  );
}

/// A single assignment row showing a user and their role chips.
class _AssignmentRowTile extends StatelessWidget {
  final Map<String, dynamic> assignment;
  final bool mutating;
  final void Function(String userId, String roleCode) onUnassign;

  const _AssignmentRowTile({
    required this.assignment,
    required this.mutating,
    required this.onUnassign,
  });

  @override
  Widget build(BuildContext context) {
    final userId = assignment['user_id']?.toString() ?? '';
    final roles =
        (assignment['roles'] as List?)?.map((e) => e.toString()).toList() ??
        const [];
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(userId),
      subtitle: Wrap(
        spacing: 6,
        children: [
          for (final code in roles)
            InputChip(
              label: Text(code),
              onDeleted: mutating ? null : () => onUnassign(userId, code),
            ),
        ],
      ),
    );
  }
}

/// Menu tree JSON editor card.
class MenusCard extends StatelessWidget {
  final bool mutating;
  final String? clientId;
  final TextEditingController menusController;
  final VoidCallback onSetMenus;

  const MenusCard({
    super.key,
    required this.mutating,
    required this.clientId,
    required this.menusController,
    required this.onSetMenus,
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
            'Menu tree JSON',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          const LocalizedText(
            'Provide an array of menu items. Each item needs id and name; children and buttons are nested arrays.',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: menusController,
            decoration: InputDecoration(labelText: 'Menu tree'.localized),
            minLines: 8,
            maxLines: 16,
            style: TextStyle(fontFamily: 'monospace'),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: mutating || clientId == null ? null : onSetMenus,
            child: const LocalizedText('Replace menu tree'),
          ),
        ],
      ),
    ),
  );
}
