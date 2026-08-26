part of 'user_support_cards.dart';

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
    // 按钮可用态读取控制器文本：只监听这两个控制器局部重建，
    // 不再让父页每次按键整页重建（R11）。
    return ListenableBuilder(
      listenable: Listenable.merge([passwordController, emailController]),
      builder: (context, _) =>
          _card('Credential recovery and containment', Icons.key_outlined, [
            if (!hasContent)
              const EmptyState(
                variant: EmptyStateVariant.empty,
                title: 'No recovery or containment actions are available.',
                compact: true,
              )
            else ...[
              if (passwordResetData != null)
                _recoveryStatus(
                  context,
                  'Active password-reset links',
                  passwordResetData!,
                ),
              if (emailChangeData != null)
                _recoveryStatus(
                  context,
                  'Active email-change links',
                  emailChangeData!,
                ),
              if (canSetPassword) ...[
                TextField(
                  controller: passwordController,
                  enabled: !mutating,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'New password'.localized,
                  ),
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
                  enabled: !mutating,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => onSetEmail?.call(),
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
          ]),
    );
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
    // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
    final danger = AppColors.semanticFor(
      Theme.of(context).brightness,
      AppColors.danger,
    );
    return OutlinedButton.icon(
      onPressed: onConfirmed,
      icon: Icon(icon, size: 18),
      style: OutlinedButton.styleFrom(
        foregroundColor: danger,
        side: BorderSide(color: danger),
      ),
      label: LocalizedText(label),
    );
  }
}
