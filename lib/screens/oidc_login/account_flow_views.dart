import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/pressable_scale.dart';

import '../../i18n/app_strings.dart';

/// 账户流视图：忘记密码 / 重置密码 / 注册 / 邮箱验证 / 结果页。纯展示：
/// 请求生命周期、防枚举文案与一次性令牌语义留在 flow（oidc_account_flow.dart）。
class ForgotPasswordView extends StatelessWidget {
  final TextEditingController identifierController;
  final bool loading;
  final String? message;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;
  const ForgotPasswordView({
    super.key,
    required this.identifierController,
    required this.loading,
    this.message,
    this.error,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _AccountFlowLayout(
      title: strings.resetPassword,
      description: context.tr(
        'Enter your username or email. If the account is eligible, Snaplink will send recovery instructions.',
      ),
      fields: [
        _field(
          controller: identifierController,
          label: strings.usernameOrEmail,
          enabled: !loading,
          hints: const [AutofillHints.username, AutofillHints.email],
          onSubmit: onSubmit,
        ),
      ],
      message: message,
      error: error,
      loading: loading,
      primaryLabel: strings.sendResetLink,
      onPrimary: onSubmit,
      onBack: onBack,
    );
  }
}

class ResetPasswordView extends StatelessWidget {
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool tokenAvailable;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const ResetPasswordView({
    super.key,
    required this.passwordController,
    required this.confirmController,
    required this.tokenAvailable,
    required this.loading,
    this.error,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _AccountFlowLayout(
      title: strings.resetPassword,
      description: tokenAvailable
          ? 'Choose a new password for your account.'
          : 'This reset link is missing its token. Request a new link.',
      fields: [
        _field(
          controller: passwordController,
          label: context.tr('New password'),
          enabled: !loading,
          hints: const [AutofillHints.newPassword],
          obscure: true,
          next: true,
        ),
        const SizedBox(height: 16),
        _field(
          controller: confirmController,
          label: context.tr('Confirm new password'),
          enabled: !loading,
          hints: const [AutofillHints.newPassword],
          obscure: true,
          onSubmit: onSubmit,
        ),
      ],
      error: error,
      loading: loading,
      primaryEnabled: tokenAvailable,
      primaryLabel: 'Update password',
      onPrimary: onSubmit,
      onBack: onBack,
    );
  }
}

class SignupView extends StatelessWidget {
  final TextEditingController usernameController;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmController;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const SignupView({
    super.key,
    required this.usernameController,
    required this.emailController,
    required this.passwordController,
    required this.confirmController,
    required this.loading,
    this.error,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return _AccountFlowLayout(
      title: strings.createAccount,
      description: context.tr(
        'Create a Snaplink account. Some organizations require email verification before the account becomes active.',
      ),
      fields: [
        _field(
          controller: usernameController,
          label: strings.username,
          enabled: !loading,
          hints: const [AutofillHints.newUsername],
          next: true,
        ),
        const SizedBox(height: 16),
        _field(
          controller: emailController,
          label: strings.emailOptional,
          enabled: !loading,
          hints: const [AutofillHints.email],
          keyboard: TextInputType.emailAddress,
          next: true,
        ),
        const SizedBox(height: 16),
        _field(
          controller: passwordController,
          label: strings.password,
          enabled: !loading,
          hints: const [AutofillHints.newPassword],
          obscure: true,
          next: true,
        ),
        const SizedBox(height: 16),
        _field(
          controller: confirmController,
          label: strings.confirmPassword,
          enabled: !loading,
          hints: const [AutofillHints.newPassword],
          obscure: true,
          onSubmit: onSubmit,
        ),
      ],
      error: error,
      loading: loading,
      primaryLabel: strings.createAccount,
      onPrimary: onSubmit,
      onBack: onBack,
    );
  }
}

class EmailVerificationView extends StatelessWidget {
  final bool tokenAvailable;
  final bool loading;
  final String? error;
  final VoidCallback onVerify;
  final VoidCallback onBack;

  const EmailVerificationView({
    super.key,
    required this.tokenAvailable,
    required this.loading,
    this.error,
    required this.onVerify,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) => _AccountFlowLayout(
    title: context.tr('Verify your email'),
    description: tokenAvailable
        ? context.tr('Confirm below to finish creating your account.')
        : context.tr(
            'This verification link is missing its token. Request a new link.',
          ),
    fields: const [],
    error: error,
    loading: loading,
    primaryEnabled: tokenAvailable,
    primaryLabel: context.tr('Verify email'),
    onPrimary: onVerify,
    onBack: onBack,
  );
}

class AccountFlowResultView extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback onBack;

  const AccountFlowResultView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.mark_email_read_outlined,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(icon, size: 44, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Semantics(
          container: true,
          header: true,
          child: Text(
            context.tr(title),
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          context.tr(message),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onBack,
          child: Text(context.tr('Back to sign in')),
        ),
      ],
    );
  }
}

/// 账户流共用骨架：标题 + 描述 + 字段 + 提示/错误 + 主操作 + 返回。
class _AccountFlowLayout extends StatelessWidget {
  final String title;
  final String description;
  final List<Widget> fields;
  final String? message;
  final String? error;
  final bool loading;
  final bool primaryEnabled;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onBack;

  const _AccountFlowLayout({
    required this.title,
    required this.description,
    required this.fields,
    this.message,
    this.error,
    required this.loading,
    this.primaryEnabled = true,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 错误优先于消息（flow 中二者互斥，防御性取错误样式）。
    final notice = error ?? message;
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(
              context.tr(title),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.tr(description),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          if (fields.isNotEmpty) ...[const SizedBox(height: 20), ...fields],
          if (notice != null) ...[
            const SizedBox(height: 16),
            _notice(
              context,
              context.tr(notice),
              error != null ? Icons.error_outline : Icons.info_outline,
              contained: error != null,
              live: true,
            ),
          ],
          const SizedBox(height: 20),
          PressableScale(
            child: FilledButton(
              onPressed: loading || !primaryEnabled ? null : onPrimary,
              child: loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr(primaryLabel)),
            ),
          ),
          TextButton(
            onPressed: loading ? null : onBack,
            child: Text(AppStrings.of(context).back),
          ),
        ],
      ),
    );
  }

  /// 内联提示条：图标 + 文案；`contained` 变体 = errorContainer 底（错误）。
  Widget _notice(
    BuildContext context,
    String text,
    IconData icon, {
    bool contained = false,
    bool live = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = contained ? scheme.onErrorContainer : scheme.primary;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color)),
        ),
      ],
    );
    final wrapped = contained
        ? Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: row,
          )
        : row;
    return live ? Semantics(liveRegion: true, child: wrapped) : wrapped;
  }
}

/// 账户流字段：autofillHints/键盘/提交语义集中一处，loading 时禁用。
Widget _field({
  required TextEditingController controller,
  required String label,
  required bool enabled,
  List<String>? hints,
  TextInputType? keyboard,
  bool obscure = false,
  bool next = false,
  VoidCallback? onSubmit,
}) => TextField(
  controller: controller,
  enabled: enabled,
  obscureText: obscure,
  autocorrect: false,
  enableSuggestions: false,
  textCapitalization: TextCapitalization.none,
  keyboardType: keyboard,
  autofillHints: hints,
  textInputAction: next ? TextInputAction.next : TextInputAction.done,
  decoration: InputDecoration(labelText: label),
  onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
);
