import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';

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
      description:
          'Enter your username or email. If the account is eligible, '
          'Snaplink will send recovery instructions.',
      fields: [
        TextField(
          controller: identifierController,
          enabled: !loading,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.username, AutofillHints.email],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(labelText: strings.usernameOrEmail),
          onSubmitted: (_) => onSubmit(),
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
        TextField(
          controller: passwordController,
          enabled: !loading,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: confirmController,
          enabled: !loading,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Confirm new password'),
          onSubmitted: (_) => onSubmit(),
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
      description:
          'Create a Snaplink account. Some organizations require email '
          'verification before the account becomes active.',
      fields: [
        TextField(
          controller: usernameController,
          enabled: !loading,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          autofillHints: const [AutofillHints.newUsername],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: strings.username),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: emailController,
          enabled: !loading,
          autocorrect: false,
          enableSuggestions: false,
          textCapitalization: TextCapitalization.none,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: strings.emailOptional),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: passwordController,
          enabled: !loading,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.next,
          decoration: InputDecoration(labelText: strings.password),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: confirmController,
          enabled: !loading,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.newPassword],
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(labelText: 'Confirm password'),
          onSubmitted: (_) => onSubmit(),
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
  Widget build(BuildContext context) {
    return _AccountFlowLayout(
      title: 'Verify your email',
      description: tokenAvailable
          ? 'Confirm below to finish creating your account.'
          : 'This verification link is missing its token. Request a new link.',
      fields: const [],
      error: error,
      loading: loading,
      primaryEnabled: tokenAvailable,
      primaryLabel: 'Verify email',
      onPrimary: onVerify,
      onBack: onBack,
    );
  }
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
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 10),
        Text(message, textAlign: TextAlign.center),
        const SizedBox(height: 22),
        FilledButton(onPressed: onBack, child: const Text('Back to sign in')),
      ],
    );
  }
}

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
    final strings = AppStrings.of(context);
    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(description),
          if (fields.isNotEmpty) ...[const SizedBox(height: 20), ...fields],
          if (message != null) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                message!,
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            Semantics(
              liveRegion: true,
              child: Text(
                error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading || !primaryEnabled ? null : onPrimary,
            child: loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(primaryLabel),
          ),
          TextButton(
            onPressed: loading ? null : onBack,
            child: Text(strings.back),
          ),
        ],
      ),
    );
  }
}
