import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
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

/// Admin sub-header: back to the organization list, the managed tenant
/// title, and a refresh action (icons brand-tinted).
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
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      children: [
        IconButton(
          tooltip: context.tr('Back to organizations'),
          onPressed: onClose,
          icon: Icon(Icons.arrow_back, color: accent),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Semantics(
            container: true,
            header: true,
            child: Text(
              context.tr('Manage {tenantId}', {'tenantId': tenantId}),
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        IconButton(
          tooltip: context.strings.refresh,
          onPressed: disabled ? null : onRefresh,
          icon: Icon(Icons.refresh, color: accent),
        ),
      ],
    );
  }
}

/// Invite form + pending-invitation list. Email field and role dropdown
/// keep the member-invitation semantics; pending rows render the recipient
/// email (API value) with role + expiry meta and a danger Revoke action.
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
            child: FilledButton.icon(
              onPressed: busy ? null : onInvite,
              icon: const Icon(Icons.mail_outline, size: 18),
              label: Text(context.tr('Send invitation')),
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
            _invitationRow(context, invitation),
        ],
      ),
    ],
  );

  /// One pending invitation row: brand-tinted mail icon, recipient email
  /// (API value, raw [Text]), role + expiry meta, danger Revoke action.
  Widget _invitationRow(
    BuildContext context,
    Map<String, dynamic> invitation,
  ) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final email = invitation['email']?.toString() ?? '';
    final role = invitation['role']?.toString() ?? 'member';
    final expiresAt = invitation['expires_at']?.toString();
    final meta = [
      context.tr(role),
      if (expiresAt != null && expiresAt.isNotEmpty)
        context.tr(' · expires {time}', {'time': expiresAt}),
    ].join();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.mail_outline, size: 17, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  email.isEmpty ? context.tr('Unknown') : email,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: busy ? null : () => onRevoke(invitation),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            icon: const Icon(Icons.close, size: 16),
            label: Text(context.tr('Revoke')),
          ),
        ],
      ),
    );
  }
}
