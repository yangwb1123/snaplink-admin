import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'portal_widgets.dart';

List<Map<String, dynamic>> organizationRecords(Object? values) =>
    (values as List? ?? const [])
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);

Future<bool> confirmOrganizationAction(
  BuildContext context,
  String title,
  String detail,
  String action, {
  String? confirmText,
  bool destructive = false,
}) => ConfirmDialog.show(
  context,
  title: title,
  message: detail,
  confirmLabel: action,
  confirmText: confirmText,
  destructive: destructive,
);

class OrganizationAdminHeader extends StatelessWidget {
  final String tenantId;
  final bool disabled;
  final VoidCallback onClose;
  final VoidCallback onRefresh;

  const OrganizationAdminHeader({
    super.key,
    required this.tenantId,
    required this.disabled,
    required this.onClose,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: context.tr('Back to organizations'),
        onPressed: onClose,
        icon: const Icon(Icons.arrow_back),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          context.tr('Manage {tenantId}', {'tenantId': tenantId}),
          style: Theme.of(context).textTheme.headlineSmall,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      IconButton(
        tooltip: context.strings.refresh,
        onPressed: disabled ? null : onRefresh,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );
}

class OrganizationInvitationCards extends StatelessWidget {
  final TextEditingController emailController;
  final String role;
  final List<String> roles;
  final bool busy;
  final List<Map<String, dynamic>> invitations;
  final ValueChanged<String> onRoleChanged;
  final VoidCallback onInvite;
  final ValueChanged<Map<String, dynamic>> onRevoke;

  const OrganizationInvitationCards({
    super.key,
    required this.emailController,
    required this.role,
    required this.roles,
    required this.busy,
    required this.invitations,
    required this.onRoleChanged,
    required this.onInvite,
    required this.onRevoke,
  });

  void _onRoleChanged(String? value) {
    if (value != null) onRoleChanged(value);
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      PortalCard(
        title: 'Invite member',
        children: [
          TextField(
            controller: emailController,
            enabled: !busy,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(labelText: context.tr('Email address')),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: role,
            decoration: InputDecoration(
              labelText: context.tr('Organization role'),
            ),
            items: roles
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(context.tr(value)),
                  ),
                )
                .toList(growable: false),
            onChanged: busy ? null : _onRoleChanged,
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: busy ? null : onInvite,
              child: Text(context.tr('Send invitation')),
            ),
          ),
        ],
      ),
      PortalCard(
        title: 'Pending invitations',
        children: [
          Text(
            context.tr('Invitation tokens are intentionally never displayed.'),
          ),
          const SizedBox(height: 8),
          if (invitations.isEmpty) const EmptyHint('No pending invitations.'),
          for (final invitation in invitations)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(invitation['email']?.toString() ?? ''),
              subtitle: Text(
                '${context.tr('${invitation['role'] ?? 'member'}')}${invitation['expires_at'] == null ? '' : context.tr(' · expires {time}', {'time': invitation['expires_at']})}',
              ),
              trailing: TextButton(
                onPressed: busy ? null : () => onRevoke(invitation),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: Text(context.tr('Revoke')),
              ),
            ),
        ],
      ),
    ],
  );
}
