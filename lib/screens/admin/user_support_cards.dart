import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
export 'account_lockout_card.dart';

/// 用户支持卡共用强调色：模块组色（system → indigo）（X7）。
Color _supportAccent() => adminModuleIconColor(AdminModuleId.userSupport);

/// 卡壳：组色图标 + SectionHeader(count) + 内容区。
Widget _card(
  String title,
  IconData icon,
  List<Widget> children, {
  int? count,
}) => Card(
  margin: const EdgeInsets.only(top: 20),
  child: Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: _supportAccent()),
            const SizedBox(width: 8),
            Expanded(child: SectionHeader(title, count: count)),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  ),
);

/// 会话列表卡：API 值一律走 TableCellText（X10），绝不作为 i18n 键。
class SessionsCard extends StatelessWidget {
  final List<Map<String, dynamic>> sessions;
  const SessionsCard({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) => _card(
    'Active sessions',
    Icons.devices_outlined,
    [
      if (sessions.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No active sessions.',
          compact: true,
        )
      else
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 460,
          columns: [
            AdminDataColumn(id: 'session', label: 'SESSION', width: 220, cardPrimary: true, builder: (c, i) => TableCellText(sessions[i]['id']?.toString() ?? '', bold: true)),
            AdminDataColumn(id: 'device', label: 'DEVICE', width: 320, builder: (c, i) => TableCellText('${sessions[i]['ip'] ?? ''} ${sessions[i]['user_agent'] ?? ''}'.trim(), muted: true)),
          ],
          itemCount: sessions.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
    ],
    count: sessions.length,
  );
}

/// 应用授权卡：撤销按钮按 client_id 精确删除，语义保持不变。
class ConsentsCard extends StatelessWidget {
  final List<Map<String, dynamic>> consents;
  final String userId;
  final bool mutating;
  final Future<void> Function(String clientId) onRevoke;
  const ConsentsCard({
    super.key,
    required this.consents,
    required this.userId,
    required this.mutating,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => _card(
    'Application consents',
    Icons.policy_outlined,
    [
      if (consents.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No grants found.',
          compact: true,
        )
      else
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 520,
          columns: [
            AdminDataColumn(id: 'client', label: 'CLIENT', width: 220, cardPrimary: true, builder: (c, i) => TableCellText(consents[i]['client_id']?.toString() ?? '', bold: true)),
            AdminDataColumn(id: 'scopes', label: 'SCOPES', width: 240, builder: (c, i) => TableCellText((consents[i]['scopes'] as List? ?? const []).join(' '), muted: true)),
            AdminDataColumn(id: 'actions', label: '', width: 100, builder: (c, i) => TextButton(onPressed: mutating ? null : () => onRevoke(consents[i]['client_id']?.toString() ?? ''), style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const LocalizedText('Revoke'))),
          ],
          itemCount: consents.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
    ],
    count: consents.length,
  );
}

/// MFA 因素卡：按 factor id 删除 / 重置恢复代码。
class MfaFactorsCard extends StatelessWidget {
  final List<Map<String, dynamic>> factors;
  final bool mutating;
  final bool canResetRecoveryCodes;
  final Future<void> Function(String factorId) onRemove;
  final VoidCallback? onResetRecoveryCodes;
  const MfaFactorsCard({
    super.key,
    required this.factors,
    required this.mutating,
    required this.canResetRecoveryCodes,
    required this.onRemove,
    this.onResetRecoveryCodes,
  });

  @override
  Widget build(BuildContext context) => _card(
    'Second factors',
    Icons.verified_user_outlined,
    [
      if (factors.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No registered factors.',
          compact: true,
        )
      else
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 460,
          columns: [
            AdminDataColumn(id: 'factor', label: 'FACTOR', width: 220, cardPrimary: true, builder: (c, i) => TableCellText(factors[i]['label']?.toString() ?? factors[i]['method']?.toString() ?? '', bold: true)),
            AdminDataColumn(id: 'method', label: 'METHOD', width: 140, builder: (c, i) => TableCellText(factors[i]['method']?.toString() ?? '', muted: true)),
            AdminDataColumn(id: 'actions', label: '', width: 110, builder: (c, i) => TextButton(onPressed: mutating ? null : () => onRemove(factors[i]['id']?.toString() ?? ''), style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const LocalizedText('Remove'))),
          ],
          itemCount: factors.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
      if (canResetRecoveryCodes)
        OutlinedButton(
          onPressed: mutating ? null : onResetRecoveryCodes,
          child: const LocalizedText('Reset recovery codes'),
        ),
    ],
    count: factors.length,
  );
}

/// 账户生命周期状态机卡：allowed_transitions 是 API 值，走 Text（X10）。
class LifecycleCard extends StatelessWidget {
  final Map<String, dynamic> lifecycleData;
  final bool mutating;
  final String? nextState;
  final ValueChanged<String?> onStateChanged;
  final TextEditingController reasonController;
  final VoidCallback onApply;
  const LifecycleCard({
    super.key,
    required this.lifecycleData,
    required this.mutating,
    required this.nextState,
    required this.onStateChanged,
    required this.reasonController,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    final allowed =
        (lifecycleData['allowed_transitions'] as List? ?? const [])
            .map((value) => value.toString())
            .toList();
    return _card('Account lifecycle', Icons.swap_vert, [
      LocalizedText(
        'Current state: {state}',
        args: {'state': lifecycleData['state'] ?? 'active'},
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        initialValue: allowed.contains(nextState) ? nextState : null,
        decoration: InputDecoration(labelText: 'Transition to'.localized),
        items: allowed
            .map((state) => DropdownMenuItem(value: state, child: Text(state)))
            .toList(growable: false),
        onChanged: mutating ? null : onStateChanged,
      ),
      const SizedBox(height: 12),
      TextField(
        controller: reasonController,
        decoration: InputDecoration(
          labelText: 'Reason / ticket reference'.localized,
        ),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: mutating || nextState == null ? null : onApply,
        child: const LocalizedText('Apply transition'),
      ),
    ]);
  }
}

/// 凭据恢复与遏制卡：无可用动作时显示空态（三态齐全）。
class CredentialRecoveryCard extends StatelessWidget {
  final Map<String, dynamic>? passwordResetData;
  final Map<String, dynamic>? emailChangeData;
  final bool mutating;
  final bool canSetPassword;
  final bool canSetEmail;
  final TextEditingController passwordController;
  final TextEditingController emailController;
  final VoidCallback? onSetPassword;
  final VoidCallback? onSetEmail;
  final List<DangerAction> dangerActions;
  const CredentialRecoveryCard({
    super.key,
    this.passwordResetData,
    this.emailChangeData,
    required this.mutating,
    required this.canSetPassword,
    required this.canSetEmail,
    required this.passwordController,
    required this.emailController,
    this.onSetPassword,
    this.onSetEmail,
    required this.dangerActions,
  });

  @override
  Widget build(BuildContext context) {
    final hasContent =
        passwordResetData != null ||
        emailChangeData != null ||
        canSetPassword ||
        canSetEmail ||
        dangerActions.isNotEmpty;
    return _card('Credential recovery and containment', Icons.key_outlined, [
      if (!hasContent)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No recovery or containment actions are available.',
          compact: true,
        )
      else ...[
        if (passwordResetData != null)
          _recoveryStatus(context, 'Active password-reset links', passwordResetData!),
        if (emailChangeData != null)
          _recoveryStatus(context, 'Active email-change links', emailChangeData!),
        if (canSetPassword) ...[
          TextField(
            controller: passwordController,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(labelText: 'New password'.localized),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: mutating || passwordController.text.isEmpty
                ? null
                : onSetPassword,
            child: const LocalizedText('Set password'),
          ),
        ],
        if (canSetEmail) ...[
          const SizedBox(height: 12),
          TextField(
            controller: emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: InputDecoration(
              labelText: 'Replacement email'.localized,
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: mutating || emailController.text.trim().isEmpty
                ? null
                : onSetEmail,
            child: const LocalizedText('Set email'),
          ),
        ],
        if (dangerActions.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: dangerActions.map((a) => a.build(context)).toList(),
          ),
        ],
      ],
    ]);
  }

  /// 恢复链接计数：label 走 catalog 翻译，count 是 API 值。
  Widget _recoveryStatus(
    BuildContext context,
    String label,
    Map<String, dynamic> data,
  ) {
    final records = data['tokens'] ?? data['links'] ?? data['items'];
    final count =
        data['total'] ??
        data['count'] ??
        (records is List ? records.length : 0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LocalizedText(
        '{label}: {count}',
        args: {'label': context.tr(label), 'count': count},
      ),
    );
  }
}

/// 需要二次确认的危险操作按钮：确认弹窗由调用方（tab 的 _mutate）负责。
class DangerAction {
  final String label;
  final String confirmTitle;
  final String confirmMessage;
  final IconData icon;
  final VoidCallback onConfirmed;
  const DangerAction({
    required this.label,
    required this.confirmTitle,
    required this.confirmMessage,
    this.icon = Icons.warning_amber_outlined,
    required this.onConfirmed,
  });

  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onConfirmed,
      icon: Icon(icon, size: 18),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.danger,
        side: const BorderSide(color: AppColors.danger),
      ),
      label: LocalizedText(label),
    );
  }
}
