import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';

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
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No members',
        )
      else
        _membersTable(context),
    ],
  );

  Widget _membersTable(BuildContext context) {
    final rows = members.whereType<Map>().toList();
    return AdminDataTable(
      density: TableDensity.compact,
      minWidth: 640,
      columns: [
        AdminDataColumn(
          id: 'user',
          label: 'USER',
          width: 260,
          cardPrimary: true,
          builder: (context, i) {
            final id =
                rows[i]['user_id']?.toString() ?? rows[i]['id']?.toString() ?? '';
            return TableCellText(id.isEmpty ? '?' : id, bold: true);
          },
        ),
        AdminDataColumn(
          id: 'role',
          label: 'ROLE',
          width: 140,
          builder: (context, i) => TableCellText(
            rows[i]['role']?.toString() ?? 'member',
            muted: true,
          ),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 110,
          builder: (context, i) {
            final id =
                rows[i]['user_id']?.toString() ?? rows[i]['id']?.toString() ?? '';
            return rows[i]['role'] == 'owner'
                ? const SizedBox.shrink()
                : TextButton(
                    onPressed: id.isEmpty ? null : () => onRemove(id),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.danger,
                    ),
                    child: const LocalizedText('Remove'),
                  );
          },
        ),
      ],
      itemCount: rows.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
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
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No pending invitations',
        )
      else
        _invitationsTable(context),
    ],
  );

  Widget _invitationsTable(BuildContext context) {
    final rows = invitations.whereType<Map>().toList();
    return AdminDataTable(
      density: TableDensity.compact,
      minWidth: 640,
      columns: [
        AdminDataColumn(
          id: 'email',
          label: 'EMAIL',
          width: 240,
          cardPrimary: true,
          builder: (context, i) => TableCellText(
            rows[i]['email']?.toString() ?? '',
            bold: true,
          ),
        ),
        AdminDataColumn(
          id: 'role',
          label: 'ROLE',
          width: 120,
          builder: (context, i) => TableCellText(
            rows[i]['role']?.toString() ?? 'member',
            muted: true,
          ),
        ),
        AdminDataColumn(
          id: 'expires',
          label: 'EXPIRES',
          width: 200,
          builder: (context, i) => TableCellText(
            rows[i]['expires_at']?.toString() ??
                rows[i]['expiry']?.toString() ??
                '—',
            muted: true,
          ),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 160,
          builder: (context, i) {
            final email = rows[i]['email']?.toString() ?? '';
            final invitation = Map<String, dynamic>.from(rows[i]);
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: email.isEmpty ? null : () => onResend(invitation),
                  child: const LocalizedText('Resend'),
                ),
                TextButton(
                  onPressed: email.isEmpty ? null : () => onRevoke(email),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const LocalizedText('Revoke'),
                ),
              ],
            );
          },
        ),
      ],
      itemCount: rows.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
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
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No usage data',
        )
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
      subtitle: Text(error),
      trailing: IconButton(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh),
        tooltip: 'Retry'.localized,
      ),
    ),
  );
}
