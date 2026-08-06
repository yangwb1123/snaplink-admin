import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

class TenantMembersTab extends StatelessWidget {
  final List<dynamic> members;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<String> onRemove;

  const TenantMembersTab({
    super.key,
    required this.members,
    required this.error,
    required this.onRetry,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (error != null)
        _SectionUnavailable(
          title: 'Members unavailable',
          error: error!,
          onRetry: onRetry,
        )
      else if (members.isEmpty)
        const Center(child: LocalizedText('No members'))
      else
        for (final raw in members.whereType<Map>())
          _memberCard(Map<String, dynamic>.from(raw)),
    ],
  );

  Widget _memberCard(Map<String, dynamic> member) {
    final id = member['user_id']?.toString() ?? member['id']?.toString() ?? '';
    final initial = id.isEmpty ? '?' : id[0].toUpperCase();
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(child: Text(initial)),
        title: Text(id),
        subtitle: LocalizedText('Role: {role}', args: {'role': member['role'] ?? 'member'}),
        trailing: member['role'] == 'owner'
            ? null
            : TextButton(
                onPressed: id.isEmpty ? null : () => onRemove(id),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const LocalizedText('Remove'),
              ),
      ),
    );
  }
}

class TenantInvitationsTab extends StatelessWidget {
  final List<dynamic> invitations;
  final String? error;
  final VoidCallback onRetry;
  final ValueChanged<Map<String, dynamic>> onResend;
  final ValueChanged<String> onRevoke;

  const TenantInvitationsTab({
    super.key,
    required this.invitations,
    required this.error,
    required this.onRetry,
    required this.onResend,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (error != null)
        _SectionUnavailable(
          title: 'Invitations unavailable',
          error: error!,
          onRetry: onRetry,
        )
      else if (invitations.isEmpty)
        const Center(child: LocalizedText('No pending invitations'))
      else
        for (final raw in invitations.whereType<Map>())
          _invitationCard(Map<String, dynamic>.from(raw)),
    ],
  );

  Widget _invitationCard(Map<String, dynamic> invitation) {
    final email = invitation['email']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.mail_outline),
        title: Text(email),
        subtitle: LocalizedText(
          'Role: ${invitation['role'] ?? 'member'}  '
          'Expires: ${invitation['expires_at'] ?? invitation['expiry'] ?? ''}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: email.isEmpty ? null : () => onResend(invitation),
              child: const LocalizedText('Resend'),
            ),
            TextButton(
              onPressed: email.isEmpty ? null : () => onRevoke(email),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const LocalizedText('Revoke'),
            ),
          ],
        ),
      ),
    );
  }
}

class TenantUsageTab extends StatelessWidget {
  final Map<String, dynamic> usage;
  final String? error;
  final VoidCallback onRetry;

  const TenantUsageTab({
    super.key,
    required this.usage,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      if (error != null)
        _SectionUnavailable(
          title: 'Usage unavailable',
          error: error!,
          onRetry: onRetry,
        )
      else if (usage.isEmpty)
        const Center(child: LocalizedText('No usage data'))
      else
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LocalizedText(
                  'Tenant usage',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _row('Period', usage['period']),
                _row('Period start', usage['period_start']),
                _row('Successful logins', usage['logins']),
                _row('Tokens issued', usage['tokens_issued']),
                _row('Active users', usage['active_users']),
                _row('Active clients', usage['active_clients']),
                _row('MFA challenges', usage['mfa_challenges']),
              ],
            ),
          ),
        ),
    ],
  );

  Widget _row(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        LocalizedText(label),
        Text(
          value?.toString() ?? '—',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    ),
  );
}

class _SectionUnavailable extends StatelessWidget {
  final String title;
  final String error;
  final VoidCallback onRetry;

  const _SectionUnavailable({
    required this.title,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: const Icon(Icons.info_outline, color: AppColors.warning),
      title: LocalizedText(title),
      subtitle: LocalizedText(error),
      trailing: IconButton(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        tooltip: 'Retry'.localized,
      ),
    ),
  );
}
