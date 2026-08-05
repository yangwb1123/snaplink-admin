import 'package:flutter/material.dart';

import '../../i18n/app_strings.dart';
import '../../services/product_api_origin.dart';
import 'hosted_login_models.dart';

class LoginViewWidget extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final builtinProviders = providers.where((item) => item.builtin).toList();
    final federatedProviders = providers
        .where(
          (item) =>
              item.isFederated &&
              (!usesFederatedProvider || item.id != provider),
        )
        .toList();
    final selected = _descriptorFor(provider);
    final selectedBuiltin = builtinProviders.any((item) => item.id == provider);

    return AutofillGroup(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.signIn, style: theme.textTheme.titleLarge),
          const SizedBox(height: 20),
          if (builtinProviders.length > 1)
            DropdownButtonFormField<String>(
              initialValue: selectedBuiltin ? provider : null,
              hint: Text(strings.provider),
              items: builtinProviders
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.id,
                      child: Text(item.displayName),
                    ),
                  )
                  .toList(),
              onChanged: loading
                  ? null
                  : (value) {
                      if (value != null) onProviderChanged(value);
                    },
              decoration: InputDecoration(labelText: strings.provider),
            ),
          if (signupConfirmed != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                context.tr(signupConfirmed!),
                style: TextStyle(color: theme.colorScheme.primary),
              ),
            ),
          ],
          if (usesFederatedProvider)
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Text(
                context.tr('Continue to {provider} to sign in.', {
                  'provider': selected.displayName,
                }),
              ),
            )
          else if (provider == 'webauthn')
            Padding(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              child: Text(
                context.tr('Choose a passkey to sign in without a password.'),
              ),
            )
          else if (usesCodeProvider)
            _codeForm(context)
          else if (usesTotpProvider)
            _totpForm(strings)
          else
            _passwordForm(strings),
          if (error != null) ...[
            const SizedBox(height: 16),
            Semantics(
              liveRegion: true,
              child: Text(
                context.tr(error!),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading ? null : onSubmit,
            child: loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    usesFederatedProvider
                        ? selected.effectiveButtonLabel
                        : provider == 'webauthn'
                        ? context.tr('Sign in with passkey')
                        : strings.signIn,
                  ),
          ),
          if (provider == 'password') ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: TextButton(
                    onPressed: loading ? null : onForgotPassword,
                    child: Text(
                      strings.forgotPassword,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                Flexible(
                  child: TextButton(
                    onPressed: loading ? null : onSignUp,
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
                onPressed: loading ? null : onHomeRealm,
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
                  loading: loading,
                  onPressed: () => onFederatedSignIn(item.id),
                ),
              ),
          ],
        ],
      ),
    );
  }

  LoginProviderDescriptor _descriptorFor(String id) {
    for (final item in providers) {
      if (item.id == id) return item;
    }
    return LoginProviderDescriptor.fromWire(id);
  }

  Widget _passwordForm(AppStrings strings) => Column(
    children: [
      TextField(
        controller: userCtrl,
        enabled: !loading,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        autofillHints: const [AutofillHints.username],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: strings.username),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: passCtrl,
        enabled: !loading,
        obscureText: true,
        autocorrect: false,
        enableSuggestions: false,
        autofillHints: const [AutofillHints.password],
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: strings.password),
        onSubmitted: (_) => onSubmit(),
      ),
    ],
  );

  Widget _codeForm(BuildContext context) => Column(
    children: [
      TextField(
        controller: codeTargetCtrl,
        enabled: !loading,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        keyboardType: provider == 'phone'
            ? TextInputType.phone
            : TextInputType.emailAddress,
        autofillHints: provider == 'phone'
            ? const [AutofillHints.telephoneNumber]
            : const [AutofillHints.email],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(
          labelText: context.tr(
            provider == 'phone' ? 'Phone number' : 'Email address',
          ),
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: loading || magicLinkToken != null ? null : onSendCode,
        child: Text(
          context.tr(
            provider == 'magiclink'
                ? (codeSent ? 'Resend link' : 'Send link')
                : (codeSent ? 'Resend code' : 'Send code'),
          ),
        ),
      ),
      if (codeMessage != null) ...[
        const SizedBox(height: 12),
        Semantics(liveRegion: true, child: Text(context.tr(codeMessage!))),
      ],
      if (provider != 'magiclink' || magicLinkToken == null) ...[
        const SizedBox(height: 16),
        TextField(
          controller: providerCodeCtrl,
          enabled: !loading,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.visiblePassword,
          autofillHints: const [AutofillHints.oneTimeCode],
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: context.tr(
              provider == 'magiclink' ? 'Token' : 'Verification code',
            ),
          ),
          onSubmitted: (_) => onSubmit(),
        ),
      ],
    ],
  );

  Widget _totpForm(AppStrings strings) => Column(
    children: [
      TextField(
        controller: userCtrl,
        enabled: !loading,
        autocorrect: false,
        enableSuggestions: false,
        textCapitalization: TextCapitalization.none,
        autofillHints: const [AutofillHints.username],
        textInputAction: TextInputAction.next,
        decoration: InputDecoration(labelText: strings.username),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: providerCodeCtrl,
        enabled: !loading,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: TextInputType.number,
        autofillHints: const [AutofillHints.oneTimeCode],
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(labelText: strings.verificationCode),
        onSubmitted: (_) => onSubmit(),
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
