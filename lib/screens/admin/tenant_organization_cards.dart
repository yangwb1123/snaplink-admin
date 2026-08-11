import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';

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
          LocalizedText(
            'Pending invitations',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: 'Email address'.localized),
          ),
          const SizedBox(height: 12),
          _OrganizationRolePicker(
            value: role,
            enabled: !mutating,
            onChanged: onRoleChanged,
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: mutating ? null : onSend,
            child: const LocalizedText('Send invitation'),
          ),
          if (invitations.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: LocalizedText('No pending invitations loaded.'),
            )
          else
            _invitationsTable(context),
        ],
      ),
    ),
  );

  Widget _invitationsTable(BuildContext context) => AdminDataTable(
    density: TableDensity.compact,
    minWidth: 560,
    columns: [
      AdminDataColumn(
        id: 'email',
        label: 'EMAIL',
        width: 240,
        cardPrimary: true,
        builder: (context, i) => TableCellText(
          invitations[i]['email']?.toString() ?? '',
          bold: true,
        ),
      ),
      AdminDataColumn(
        id: 'role',
        label: 'ROLE',
        width: 120,
        builder: (context, i) => TableCellText(
          invitations[i]['role']?.toString() ?? 'member',
          muted: true,
        ),
      ),
      AdminDataColumn(
        id: 'expires',
        label: 'EXPIRES',
        width: 180,
        builder: (context, i) => TableCellText(
          invitations[i]['expires_at']?.toString() ?? '—',
          muted: true,
        ),
      ),
      AdminDataColumn(
        id: 'actions',
        label: '',
        width: 100,
        builder: (context, i) => TextButton(
          onPressed: mutating
              ? null
              : () => onRevoke(invitations[i]['email']?.toString() ?? ''),
          style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          child: const LocalizedText('Revoke'),
        ),
      ),
    ],
    itemCount: invitations.length,
    rowBuilder: (context, i) => const SizedBox.shrink(),
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
      title: const LocalizedText('Tenant data export'),
      subtitle: const LocalizedText(
        'Creates Snaplink’s redacted tenant offboarding or migration bundle.',
      ),
      trailing: FilledButton(
        onPressed: mutating ? null : onExport,
        child: const LocalizedText('Export'),
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
    decoration: InputDecoration(labelText: 'Organization role'.localized),
    items: const [
      DropdownMenuItem(value: 'member', child: LocalizedText('Member')),
      DropdownMenuItem(value: 'admin', child: LocalizedText('Admin')),
      DropdownMenuItem(value: 'guest', child: LocalizedText('Guest')),
    ],
    onChanged: enabled ? (next) => onChanged(next ?? value) : null,
  );
}
