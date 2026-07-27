import 'package:flutter/material.dart';

class OrganizationInvitationsCard extends StatelessWidget {
  final List<Map<String, dynamic>> invitations;
  final TextEditingController emailController;
  final String role;
  final bool mutating;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSend;
  final ValueChanged<String> onRevoke;

  const OrganizationInvitationsCard({
    super.key,
    required this.invitations,
    required this.emailController,
    required this.role,
    required this.mutating,
    required this.onRoleChanged,
    required this.onSend,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pending invitations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email address'),
          ),
          const SizedBox(height: 10),
          _OrganizationRolePicker(
            value: role,
            enabled: !mutating,
            onChanged: onRoleChanged,
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: mutating ? null : onSend,
            child: const Text('Send invitation'),
          ),
          if (invitations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text('No pending invitations loaded.'),
            ),
          for (final invitation in invitations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(invitation['email']?.toString() ?? ''),
              subtitle: Text(
                '${invitation['role'] ?? 'member'}'
                '${invitation['expires_at'] == null ? '' : ' · expires ${invitation['expires_at']}'}',
              ),
              trailing: TextButton(
                onPressed: mutating
                    ? null
                    : () => onRevoke(invitation['email']?.toString() ?? ''),
                style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                child: const Text('Revoke'),
              ),
            ),
        ],
      ),
    ),
  );
}

class TenantOrganizationExportCard extends StatelessWidget {
  final bool mutating;
  final VoidCallback onExport;

  const TenantOrganizationExportCard({
    super.key,
    required this.mutating,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: ListTile(
      leading: const Icon(Icons.download_outlined),
      title: const Text('Tenant data export'),
      subtitle: const Text(
        'Creates Snaplink’s redacted tenant offboarding or migration bundle.',
      ),
      trailing: FilledButton(
        onPressed: mutating ? null : onExport,
        child: const Text('Export'),
      ),
    ),
  );
}

class _OrganizationRolePicker extends StatelessWidget {
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  const _OrganizationRolePicker({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    initialValue: value,
    decoration: const InputDecoration(labelText: 'Organization role'),
    items: const [
      DropdownMenuItem(value: 'member', child: Text('Member')),
      DropdownMenuItem(value: 'admin', child: Text('Admin')),
      DropdownMenuItem(value: 'guest', child: Text('Guest')),
    ],
    onChanged: enabled ? (next) => onChanged(next ?? value) : null,
  );
}
