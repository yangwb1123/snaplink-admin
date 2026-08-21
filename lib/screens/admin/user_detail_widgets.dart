import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';

/// 模块强调色（identity 组 indigo-violet）：详情头部与子资源图标统一按组色上色。
Color _userAccent() => adminModuleIconColor('users');

class UserDetailHeader extends StatelessWidget {
  final Map<String, dynamic>? user;

  const UserDetailHeader({super.key, required this.user});

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _userAccent().withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.person, size: 32, color: _userAccent()),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?['id']?.toString() ?? '',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                LocalizedText(
                  'Provider: {provider}',
                  args: {'provider': user?['provider'] ?? ''},
                ),
                LocalizedText(
                  'External ID: {external_id}',
                  args: {
                    'external_id':
                        user?['externalId'] ?? user?['external_id'] ?? '',
                  },
                ),
              ],
            ),
          ),
          // 状态徽章：仅在 API 返回 status 字段时展示（active/其他），与
          // client/tenant/connection 详情头部同一位置约定（状态在头部右上）。
          if (user?['status'] case final status?)
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: status == 'active'
                  ? StatusChip.active(label: context.tr('active'))
                  : StatusChip.inactive(label: status),
            ),
        ],
      ),
    ),
  );
}

class UserDetailTabBar extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  const UserDetailTabBar({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < labels.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(labels[i]),
              selected: selectedIndex == i,
              onSelected: (_) => onSelected(i),
            ),
          ),
      ],
    ),
  );
}

/// 会话列表：空态用 EmptyState，数据用 AdminDataTable(compact)。
class UserSessionsView extends StatelessWidget {
  final List<dynamic> sessions;

  const UserSessionsView({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) {
      return const EmptyState(
        variant: EmptyStateVariant.empty,
        icon: Icons.devices,
        title: 'No active sessions',
        compact: true,
      );
    }
    return AdminDataTable(
      scrollable: true,
      minWidth: 560,
      density: TableDensity.compact,
      columns: [
        AdminDataColumn(
          id: 'session',
          label: 'SESSION',
          width: 240,
          cardPrimary: true,
          builder: (context, i) => TableCellText(
            sessions[i]['id']?.toString() ?? '',
            bold: true,
            maxLines: 1,
          ),
        ),
        AdminDataColumn(
          id: 'context',
          label: 'CONTEXT',
          builder: (context, i) => LocalizedText(
            'IP: {address}  UA: {agent}',
            args: {
              'address': sessions[i]['ip'] ?? '',
              'agent': _truncatedUserAgent(sessions[i]),
            },
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
      itemCount: sessions.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }

  static String _truncatedUserAgent(dynamic session) {
    final userAgent = session['user_agent']?.toString() ?? '';
    return userAgent.length <= 80 ? userAgent : userAgent.substring(0, 80);
  }
}

/// 授权同意列表：空态 + AdminDataTable + 撤销动作。
class UserConsentsView extends StatelessWidget {
  final List<dynamic> consents;
  final bool mutating;
  final ValueChanged<String> onRevoke;

  const UserConsentsView({
    super.key,
    required this.consents,
    required this.mutating,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) {
    if (consents.isEmpty) {
      return const EmptyState(
        variant: EmptyStateVariant.empty,
        icon: Icons.checklist,
        title: 'No consents granted',
        compact: true,
      );
    }
    return AdminDataTable(
      scrollable: true,
      minWidth: 560,
      density: TableDensity.compact,
      columns: [
        AdminDataColumn(
          id: 'client',
          label: 'CLIENT',
          width: 240,
          cardPrimary: true,
          builder: (context, i) => TableCellText(
            consents[i]['client_id']?.toString() ?? '',
            bold: true,
            maxLines: 1,
          ),
        ),
        AdminDataColumn(
          id: 'scopes',
          label: 'SCOPES',
          builder: (context, i) => TableCellText(
            (consents[i]['scopes'] as List?)?.join(', ') ?? '',
            muted: true,
            maxLines: 2,
          ),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 100,
          builder: (context, i) => TextButton(
            onPressed: mutating
                ? null
                : () => onRevoke(consents[i]['client_id']?.toString() ?? ''),
            style: TextButton.styleFrom(
              // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
              foregroundColor: AppColors.semanticFor(
                Theme.of(context).brightness,
                AppColors.danger,
              ),
            ),
            child: const LocalizedText('Revoke'),
          ),
        ),
      ],
      itemCount: consents.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}

/// MFA 因素列表：空态 + AdminDataTable + 移除动作。
class UserMfaView extends StatelessWidget {
  final List<dynamic> factors;
  final bool mutating;
  final ValueChanged<String> onRemove;

  const UserMfaView({
    super.key,
    required this.factors,
    required this.mutating,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (factors.isEmpty) {
      return const EmptyState(
        variant: EmptyStateVariant.empty,
        icon: Icons.security,
        title: 'No MFA factors registered',
        compact: true,
      );
    }
    return AdminDataTable(
      scrollable: true,
      minWidth: 520,
      density: TableDensity.compact,
      columns: [
        AdminDataColumn(
          id: 'factor',
          label: 'FACTOR',
          width: 220,
          cardPrimary: true,
          builder: (context, i) => TableCellText(
            factors[i]['label']?.toString() ??
                factors[i]['method']?.toString() ??
                '',
            bold: true,
            maxLines: 1,
          ),
        ),
        AdminDataColumn(
          id: 'method',
          label: 'METHOD',
          width: 160,
          builder: (context, i) => TableCellText(
            factors[i]['method']?.toString() ?? '',
            muted: true,
          ),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 110,
          builder: (context, i) => TextButton(
            onPressed: mutating
                ? null
                : () => onRemove(factors[i]['id']?.toString() ?? ''),
            style: TextButton.styleFrom(
              // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
              foregroundColor: AppColors.semanticFor(
                Theme.of(context).brightness,
                AppColors.danger,
              ),
            ),
            child: const LocalizedText('Remove'),
          ),
        ),
      ],
      itemCount: factors.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}

class UserLifecycleView extends StatelessWidget {
  final Map<String, dynamic> lifecycle;
  final bool showBackButton;
  final VoidCallback onBack;

  const UserLifecycleView({
    super.key,
    required this.lifecycle,
    required this.showBackButton,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final state = lifecycle['state']?.toString() ?? 'active';
    final transitions =
        (lifecycle['allowed_transitions'] as List?)
            ?.map((item) => item.toString())
            .toList() ??
        [];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Icon(Icons.route, size: 48, color: _userAccent()),
                const SizedBox(height: 8),
                LocalizedText(
                  'Current state: {state}',
                  args: {'state': state},
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                StatusChip.info(label: state),
                if (transitions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const LocalizedText('Allowed transitions:'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: transitions
                        .map((transition) => Chip(label: Text(transition)))
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (showBackButton) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back),
            label: const LocalizedText('Back to user list'),
          ),
        ],
      ],
    );
  }
}
