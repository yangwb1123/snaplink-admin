import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/info_row.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// 租户详情各子资源 tab（成员/邀请/用量/品牌）。成员与邀请用
/// AdminDataTable（compact）；用量是租户粒度的汇总键值对，属明细区块，
/// 用 InfoRow 逐行呈现（R42：不误用表格），三态齐全。
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
            formatServerTime(
              rows[i]['expires_at'] ?? rows[i]['expiry'],
            ),
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

  static const _labels = [
    'Period',
    'Period start',
    'Successful logins',
    'Tokens issued',
    'Active users',
    'Active clients',
    'MFA challenges',
  ];
  static const _keys = [
    'period',
    'period_start',
    'logins',
    'tokens_issued',
    'active_users',
    'active_clients',
    'mfa_challenges',
  ];

  /// 指标字段（logins/tokens/active…）走千分位计数；period/period_start
  /// 等元数据原样展示；缺失回退 '—'（信息完整性优先于裸 formatCount）。
  static String _usageValue(Map<String, dynamic> usage, String key) {
    final raw = usage[key];
    if (raw == null) return '—';
    final n = raw is num ? raw : num.tryParse('$raw');
    return n == null ? raw.toString() : formatCount(n);
  }

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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.bar_chart,
                      size: 20,
                      color: adminModuleIconColor(AdminModuleId.tenants),
                    ),
                    const SizedBox(width: 8),
                    LocalizedText(
                      'Tenant usage',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (var i = 0; i < _labels.length; i++)
                  InfoRow(
                    label: _labels[i],
                    value: _usageValue(usage, _keys[i]),
                    labelWidth: 150,
                  ),
              ],
            ),
          ),
        ),
    ],
  );
}

/// 分区数据加载失败：提示卡 + Retry（X4 模式）。
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
