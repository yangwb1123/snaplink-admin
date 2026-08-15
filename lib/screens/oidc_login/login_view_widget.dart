library;

import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/pressable_scale.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import '../../i18n/app_strings.dart';
import '../../services/product_api_origin.dart';
import 'hosted_login_models.dart';

part 'login_view_widget_subwidgets.dart';

class LoginViewWidget extends StatefulWidget {
  final String provider;
  final List<LoginProviderDescriptor> providers;
  final String? signupConfirmed;
  final TextEditingController userCtrl;
  final TextEditingController passCtrl;
  final TextEditingController codeTargetCtrl;
  final TextEditingController providerCodeCtrl;
  final bool codeSent;
  final String? codeMessage;
  final bool loading;
  final String? error;
  final bool usesFederatedProvider;
  final bool usesCodeProvider;
  final bool usesTotpProvider;
  final String? magicLinkToken;
  final VoidCallback onSubmit;
  final VoidCallback onSendCode;
  final VoidCallback onHomeRealm;
  final VoidCallback onForgotPassword;
  final VoidCallback onSignUp;
  final ValueChanged<String> onProviderChanged;
  final void Function(String connectionId) onFederatedSignIn;
  final FocusNode? passwordFocusNode;

  const LoginViewWidget({
    super.key,
    required this.provider,
    required this.providers,
    this.signupConfirmed,
    required this.userCtrl,
    required this.passCtrl,
    required this.codeTargetCtrl,
    required this.providerCodeCtrl,
    required this.codeSent,
    this.codeMessage,
    required this.loading,
    this.error,
    required this.usesFederatedProvider,
    required this.usesCodeProvider,
    required this.usesTotpProvider,
    this.magicLinkToken,
    required this.onSubmit,
    required this.onSendCode,
    required this.onHomeRealm,
    required this.onForgotPassword,
    required this.onSignUp,
    required this.onProviderChanged,
    required this.onFederatedSignIn,
    this.passwordFocusNode,
  });

  @override
  State<LoginViewWidget> createState() => _LoginViewWidgetState();
}

class _LoginViewWidgetState extends State<LoginViewWidget> {
  var _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final builtinProviders = widget.providers.where((item) => item.builtin).toList();
    final federatedProviders = widget.providers
        .where((item) => item.isFederated && (!widget.usesFederatedProvider || item.id != widget.provider))
        .toList();
    final selected = _descriptorFor(widget.provider);
    final selectedBuiltin = builtinProviders.any((item) => item.id == widget.provider);

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            container: true,
            header: true,
            child: Text(strings.signIn, style: theme.textTheme.titleLarge),
          ),
          const SizedBox(height: 20),
          if (builtinProviders.length > 1)
            DropdownButtonFormField<String>(
              initialValue: selectedBuiltin ? widget.provider : null,
              hint: Text(strings.provider),
              items: [
                for (final item in builtinProviders)
                  DropdownMenuItem(value: item.id, child: Text(item.displayName)),
              ],
              onChanged: widget.loading ? null : (value) {
                if (value != null) widget.onProviderChanged(value);
              },
              decoration: InputDecoration(labelText: strings.provider),
            ),
          if (widget.signupConfirmed != null)
            _notice(context.tr(widget.signupConfirmed!), Icons.check_circle_outline, top: 12, live: true),
          if (widget.usesFederatedProvider)
            _notice(
              context.tr('Continue to {provider} to sign in.', {'provider': selected.displayName}),
              Icons.open_in_new,
              vertical: 16,
            )
          else if (widget.provider == 'webauthn')
            _notice(context.tr('Choose a passkey to sign in without a password.'), Icons.fingerprint, vertical: 16)
          else if (widget.usesCodeProvider)
            _codeForm(context)
          else if (widget.usesTotpProvider)
            _totpForm(strings)
          else
            _passwordForm(strings),
          if (widget.error != null)
            _notice(
              context.tr(widget.error!),
              Icons.error_outline,
              top: 16,
              color: Theme.of(context).colorScheme.onErrorContainer,
              contained: true,
              live: true,
            ),
          const SizedBox(height: 20),
          PressableScale(
            child: FilledButton(
              onPressed: widget.loading ? null : widget.onSubmit,
              child: widget.loading
                  ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(
                      widget.usesFederatedProvider
                          ? selected.effectiveButtonLabel
                          : widget.provider == 'webauthn'
                          ? context.tr('Sign in with passkey')
                          : strings.signIn,
                    ),
            ),
          ),
          if (widget.provider == 'password') ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(child: TextButton(
                  onPressed: widget.loading ? null : widget.onForgotPassword,
                  child: Text(strings.forgotPassword, overflow: TextOverflow.ellipsis),
                )),
                Flexible(child: TextButton(
                  onPressed: widget.loading ? null : widget.onSignUp,
                  child: Text(strings.signUp, overflow: TextOverflow.ellipsis),
                )),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.loading ? null : widget.onHomeRealm,
                icon: Icon(Icons.business_outlined, color: theme.colorScheme.primary),
                label: Text(context.tr('Use organization sign-in')),
              ),
            ),
          ],
          if (federatedProviders.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(strings.orDivider, style: theme.textTheme.bodySmall),
              ),
              const Expanded(child: Divider()),
            ]),
            const SizedBox(height: 16),
            for (final item in federatedProviders)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _FederatedProviderButton(
                  provider: item,
                  loading: widget.loading,
                  onPressed: () => widget.onFederatedSignIn(item.id),
                ),
              ),
          ],
        ],
      ),
    );
  }
  LoginProviderDescriptor _descriptorFor(String id) {
    for (final item in widget.providers) {
      if (item.id == id) return item;
    }
    return LoginProviderDescriptor.fromWire(id);
  }
  Widget _passwordForm(AppStrings strings) => Column(
    children: [
      _field(controller: widget.userCtrl, label: strings.username, hints: const [AutofillHints.username], next: true),
      const SizedBox(height: 16),
      _field(
        controller: widget.passCtrl,
        focusNode: widget.passwordFocusNode,
        label: strings.password,
        hints: const [AutofillHints.password],
        obscure: true,
        suffix: IconButton(
          tooltip: context.tr(_obscurePassword ? 'Show password' : 'Hide password'),
          icon: Icon(
            _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Theme.of(context).colorScheme.primary,
          ),
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
        ),
        onSubmit: () => widget.onSubmit(),
      ),
    ],
  );
  Widget _codeForm(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isPhone = widget.provider == 'phone';
    final isMagicLink = widget.provider == 'magiclink';
    return Column(
      children: [
        _field(
          controller: widget.codeTargetCtrl,
          label: context.tr(isPhone ? 'Phone number' : 'Email address'),
          hints: isPhone ? const [AutofillHints.telephoneNumber] : const [AutofillHints.email],
          keyboard: isPhone ? TextInputType.phone : TextInputType.emailAddress,
          next: true,
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            onPressed: widget.loading || widget.magicLinkToken != null ? null : widget.onSendCode,
            child: widget.loading
                ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(context.tr(
                    isMagicLink
                        ? (widget.codeSent ? 'Resend link' : 'Send link')
                        : (widget.codeSent ? 'Resend code' : 'Send code'),
                  )),
          ),
        ),
        if (widget.codeMessage != null) ...[
          const SizedBox(height: 12),
          Semantics(
            liveRegion: true,
            child: Align(
              alignment: Alignment.centerLeft,
              child: widget.codeSent
                  ? StatusChip.active(label: context.tr(widget.codeMessage!))
                  : _notice(context.tr(widget.codeMessage!), Icons.info_outline, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        if (!isMagicLink || widget.magicLinkToken == null) ...[
          const SizedBox(height: 16),
          _field(
            controller: widget.providerCodeCtrl,
            label: context.tr(isMagicLink ? 'Token' : 'Verification code'),
            hints: const [AutofillHints.oneTimeCode],
            keyboard: TextInputType.visiblePassword,
            onSubmit: () => widget.onSubmit(),
          ),
        ],
      ],
    );
  }
  Widget _totpForm(AppStrings strings) => Column(
    children: [
      _field(controller: widget.userCtrl, label: strings.username, hints: const [AutofillHints.username], next: true),
      const SizedBox(height: 16),
      _field(
        controller: widget.providerCodeCtrl,
        label: strings.verificationCode,
        hints: const [AutofillHints.oneTimeCode],
        keyboard: TextInputType.number,
        onSubmit: () => widget.onSubmit(),
      ),
    ],
  );

  /// 统一登录表单字段：autofillHints/键盘/提交语义集中一处，loading 时禁用。
  Widget _field({
    required TextEditingController controller,
    required String label,
    FocusNode? focusNode,
    List<String>? hints,
    TextInputType? keyboard,
    bool next = false,
    bool obscure = false,
    Widget? suffix,
    VoidCallback? onSubmit,
  }) => TextField(
    controller: controller,
    focusNode: focusNode,
    enabled: !widget.loading,
    autocorrect: false,
    enableSuggestions: false,
    textCapitalization: TextCapitalization.none,
    keyboardType: keyboard,
    autofillHints: hints,
    textInputAction: next ? TextInputAction.next : TextInputAction.done,
    obscureText: obscure,
    decoration: InputDecoration(labelText: label, suffixIcon: suffix),
    onSubmitted: onSubmit == null ? null : (_) => onSubmit(),
  );

  /// 表单内联提示的简洁入口：品牌/语义色图标 + 文案（默认品牌主色）。
  Widget _notice(
    String text,
    IconData icon, {
    double? top,
    double? vertical,
    Color? color,
    bool contained = false,
    bool live = false,
  }) {
    final notice = _InlineNotice(
      text: text,
      icon: icon,
      color: color ?? Theme.of(context).colorScheme.primary,
      contained: contained,
      liveRegion: live,
    );
    final margin = EdgeInsets.only(top: top ?? 0)
        .add(EdgeInsets.symmetric(vertical: vertical ?? 0));
    return margin == EdgeInsets.zero ? notice : Padding(padding: margin, child: notice);
  }
}
