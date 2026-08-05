import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';
import '../../services/product_api_origin.dart';
import 'hosted_login_models.dart';

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
  });

  @override

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
        .where(
          (item) =>
              item.isFederated &&
              (!widget.usesFederatedProvider || item.id != widget.provider),
        )
        .toList();
    final selected = _descriptorFor(widget.provider);
    final selectedBuiltin = builtinProviders.any((item) => item.id == widget.provider);

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.signIn, style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          if (builtinProviders.length > 1)
            DropdownButtonFormField<String>(
              initialValue: selectedBuiltin ? widget.provider : null,
              hint: Text(strings.provider),
              items: builtinProviders
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.displayName),
                    ),
                  )
                  .toList(),
              onChanged: widget.loading
                  ? null
                  : (value) {
                      if (value != null) widget.onProviderChanged(value);
                    },
              decoration: InputDecoration(labelText: strings.provider),
            ),
          if (widget.signupConfirmed != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                context.tr(widget.signupConfirmed!),
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
          if (widget.usesFederatedProvider)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Text(
                context.tr('Continue to {widget.provider} to sign in.', {
                  'widget.provider': selected.displayName,
                }),
              ),
            )
          else if (widget.provider == 'webauthn')
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Text(
                context.tr('Choose a passkey to sign in without a password.'),
              ),
            )
          else if (widget.usesCodeProvider)
            _codeForm(context)
          else if (widget.usesTotpProvider)
            _totpForm(strings)
          else
            _passwordForm(strings),
          if (widget.error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                context.tr(widget.error!),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: widget.loading ? null : widget.onSubmit,
            child: widget.loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    widget.usesFederatedProvider
                        ? selected.effectiveButtonLabel
                        : widget.provider == 'webauthn'
                        ? context.tr('Sign in with passkey')
                        : strings.signIn,
                  ),
          ),
          if (widget.provider == 'password') ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: widget.loading ? null : widget.onForgotPassword,
                    child: Text(
                      strings.forgotPassword,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: widget.loading ? null : widget.onSignUp,
                    child: Text(
                      strings.signUp,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.loading ? null : widget.onHomeRealm,
                icon: const Icon(Icons.business_outlined),
                label: Text(context.tr('Use organization sign-in')),
              ),
            ),
          ],
          if (federatedProviders.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    strings.orDivider,
                    style: theme.textTheme.bodySmall,
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
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
      TextField(
        controller: widget.userCtrl,
        enabled: !widget.loading,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        autofillHints: const [AutofillHints.username],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: strings.username),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: widget.passCtrl,
        enabled: !widget.loading,
        obscureText: _obscurePassword,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: strings.password,
          suffixIcon: IconButton(
            tooltip: _obscurePassword ? 'Show password' : 'Hide password',
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword),
          ),
        ),
        onSubmitted: (_) => widget.onSubmit(),
      ),
    ],
  );

  Widget _codeForm(BuildContext context) => Column(
    children: [
      TextField(
        controller: widget.codeTargetCtrl,
        enabled: !widget.loading,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        keyboardType: widget.provider == 'phone'
            ? TextInputType.phone
            : TextInputType.emailAddress,
        autofillHints: widget.provider == 'phone'
            ? const [AutofillHints.telephoneNumber]
            : const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: context.tr(
            widget.provider == 'phone' ? 'Phone number' : 'Email address',
          ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: widget.loading || widget.magicLinkToken != null ? null : widget.onSendCode,
        child: Text(
          context.tr(
            widget.provider == 'magiclink'
                ? (widget.codeSent ? 'Resend link' : 'Send link')
                : (widget.codeSent ? 'Resend code' : 'Send code'),
          ),
        ),
      ),
      if (widget.codeMessage != null) ...[
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(context.tr(widget.codeMessage!))),
      ],
      if (widget.provider != 'magiclink' || widget.magicLinkToken == null) ...[
        const SizedBox(height: 16),
        TextField(
          controller: widget.providerCodeCtrl,
          enabled: !widget.loading,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.tr(
              widget.provider == 'magiclink' ? 'Token' : 'Verification code',
            ),
          ),
          onSubmitted: (_) => widget.onSubmit(),
        ),
      ],
    ],
  );

  Widget _totpForm(AppStrings strings) => Column(
    children: [
      TextField(
        controller: widget.userCtrl,
        enabled: !widget.loading,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        autofillHints: const [AutofillHints.username],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: strings.username),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: widget.providerCodeCtrl,
        enabled: !widget.loading,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: strings.verificationCode),
        onSubmitted: (_) => widget.onSubmit(),
      ),
    ],
  );
}

class _FederatedProviderButton extends StatelessWidget {
  final LoginProviderDescriptor provider;
  final bool loading;
  final VoidCallback onPressed;

  const _FederatedProviderButton({
    required this.provider,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final color = _parseButtonColor(provider.buttonColor);
    final foreground = color == null
        ? null
        : ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
    final iconUrl = provider.safeIconUrl(ProductApiOrigin.baseUri);
    final icon = iconUrl == null
        ? const Icon(Icons.login)
        : Image.network(
            iconUrl,
            width: 20,
            height: 20,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(Icons.login),
          );

    return OutlinedButton.icon(
      onPressed: loading ? null : onPressed,
      style: color == null
          ? null
          : OutlinedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: foreground,
              side: BorderSide(color: color),
            ),
      icon: icon,
      label: Text(context.tr(provider.effectiveButtonLabel)),
    );
  }

  Color? _parseButtonColor(String raw) {
    final match = RegExp(
      r'^#([0-9a-fA-F]{6}|[0-9a-fA-F]{8})$',
    ).firstMatch(raw.trim());
    if (match == null) return null;
    final hex = match.group(1)!;
    final flutterHex = hex.length == 6
        ? 'ff$hex'
        : '${hex.substring(6)}${hex.substring(0, 6)}';
    return Color(int.parse(flutterHex, radix: 16));
  }
}
