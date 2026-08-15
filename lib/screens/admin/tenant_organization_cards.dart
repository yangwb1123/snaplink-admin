import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

class OrganizationInvitationsCard extends StatelessWidget {
  final List<Map<String, dynamic>> invitations;
  final TextEditingController emailController;
  final String role;
  final bool mutating;

  /// 模块强调色（tenants 组 amber）：标题图标按组色上色（X7）。
  /// 缺省时回退组色，保证无强调色传入的调用方（测试/复用）仍按组色渲染。
  final Color? accent;

  final ValueChanged<String> onRoleChanged;
  final VoidCallback onSend;
  final ValueChanged<String> onRevoke;

  const OrganizationInvitationsCard({
    super.key,
    required this.invitations,
    required this.emailController,
    required this.role,
    required this.mutating,
    this.accent,
    required this.onRoleChanged,
    required this.onSend,
    required this.onRevoke,
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
                Icon(Icons.mail_outlined, size: 20, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    'Pending invitations',
                    count: invitations.isEmpty ? null : invitations.length,
                  ),
                ),
              ],
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
            FilledButton.icon(
              onPressed: mutating ? null : onSend,
              icon: const Icon(Icons.send_outlined, size: 18),
              label: const LocalizedText('Send invitation'),
            ),
            if (invitations.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: EmptyState(
                  compact: true,
                  title: 'No pending invitations loaded.',
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _invitationsTable(context),
              ),
          ],
        ),
      ),
    );
  }

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

  /// 模块强调色（tenants 组 amber）：图标按组色上色（X7）。
  /// 缺省时回退组色，保证无强调色传入的调用方（测试/复用）仍按组色渲染。
  final Color? accent;

  final VoidCallback onExport;

  const TenantOrganizationExportCard({
    super.key,
    required this.mutating,
    this.accent,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context) {
    final accent =
        this.accent ?? adminModuleIconColor(AdminModuleId.organizations);
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: ListTile(
        leading: Icon(Icons.file_download_outlined, color: accent),
        title: const LocalizedText('Tenant data export'),
        subtitle: const LocalizedText(
          'Creates Snaplink’s redacted tenant offboarding or migration bundle.',
        ),
        trailing: FilledButton.icon(
          onPressed: mutating ? null : onExport,
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const LocalizedText('Export'),
        ),
      ),
    );
  }
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
