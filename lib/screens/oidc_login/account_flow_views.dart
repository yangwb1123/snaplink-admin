import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/pressable_scale.dart';

import '../../i18n/app_strings.dart';

part 'account_flow_layout.dart';

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
