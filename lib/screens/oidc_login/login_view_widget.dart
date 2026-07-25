import 'package:flutter/material.dart';

/// Login form view with providers, federated sign-in, and home realm discovery.
class LoginViewWidget extends StatelessWidget {
  final String provider;
  final List<String> providers;
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
  final List<({String id, String label, IconData icon})> federatedConnections;
  final VoidCallback onSubmit;
  final VoidCallback onSendCode;
  final VoidCallback onHomeRealm;
  final VoidCallback onPasskeyLogin;
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
    required this.federatedConnections,
    required this.onSubmit,
    required this.onSendCode,
    required this.onHomeRealm,
    required this.onPasskeyLogin,
    required this.onForgotPassword,
    required this.onSignUp,
    required this.onProviderChanged,
    required this.onFederatedSignIn,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Sign in', style: theme.textTheme.titleLarge),
      const SizedBox(height: 20),
      if (providers.length > 1)
        DropdownButtonFormField<String>(
          initialValue: provider,
          items: providers.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
          onChanged: (v) => onProviderChanged(v ?? provider),
          decoration: const InputDecoration(labelText: 'Provider'),
        ),
      if (signupConfirmed != null) ...[const SizedBox(height: 10), Text(signupConfirmed!, style: const TextStyle(color: Colors.greenAccent))],
      if (usesFederatedProvider) Padding(padding: const EdgeInsets.only(bottom: 14), child: Text('Continue to $provider to sign in.'))
      else if (provider == 'webauthn') const Padding(padding: EdgeInsets.only(bottom: 14), child: Text('Choose a passkey to sign in without a password.'))
      else if (usesCodeProvider) _codeForm(theme)
      else if (usesTotpProvider) _totpForm(theme)
      else _passwordForm(theme),
      if (error != null) ...[const SizedBox(height: 14), Text(error!, style: const TextStyle(color: Colors.redAccent))],
      const SizedBox(height: 20),
      FilledButton(onPressed: loading ? null : onSubmit, child: loading
        ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
        : Text(usesFederatedProvider ? 'Continue with $provider' : provider == 'webauthn' ? 'Sign in with passkey' : 'Sign in')),
      if (provider == 'password') ...[
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: TextButton(onPressed: onForgotPassword, child: const Text('Forgot password?', overflow: TextOverflow.ellipsis))),
          Flexible(child: TextButton(onPressed: onSignUp, child: const Text('Sign up', overflow: TextOverflow.ellipsis))),
        ]),
        Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: loading ? null : onHomeRealm, icon: const Icon(Icons.business_outlined), label: const Text('Use organization sign-in'))),
      ],
      const SizedBox(height: 20),
      Row(children: [const Expanded(child: Divider()), Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text('or', style: theme.textTheme.bodySmall)), const Expanded(child: Divider())]),
      const SizedBox(height: 14),
      for (final c in federatedConnections)
        Padding(padding: const EdgeInsets.only(bottom: 10), child: OutlinedButton.icon(onPressed: () => onFederatedSignIn(c.id), icon: Icon(c.icon), label: Text('Sign in with ${c.label}'))),
    ]);
  }

  Widget _passwordForm(ThemeData theme) => Column(children: [
    TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username')),
    const SizedBox(height: 14),
    TextField(controller: passCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Password'), onSubmitted: (_) => onSubmit()),
  ]);

  Widget _codeForm(ThemeData theme) => Column(children: [
    TextField(controller: codeTargetCtrl, keyboardType: provider == 'phone' ? TextInputType.phone : TextInputType.emailAddress, decoration: InputDecoration(labelText: provider == 'phone' ? 'Phone number' : 'Email address')),
    const SizedBox(height: 10),
    OutlinedButton(onPressed: loading || magicLinkToken != null ? null : onSendCode, child: Text(provider == 'magiclink' ? (codeSent ? 'Resend link' : 'Send link') : (codeSent ? 'Resend code' : 'Send code'))),
    if (codeMessage != null) ...[const SizedBox(height: 10), Text(codeMessage!)],
    if (provider != 'magiclink' || magicLinkToken == null) ...[const SizedBox(height: 14), TextField(controller: providerCodeCtrl, decoration: InputDecoration(labelText: provider == 'magiclink' ? 'Token' : 'Verification code'), onSubmitted: (_) => onSubmit())],
  ]);

  Widget _totpForm(ThemeData theme) => Column(children: [
    TextField(controller: userCtrl, decoration: const InputDecoration(labelText: 'Username')),
    const SizedBox(height: 14),
    TextField(controller: providerCodeCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Verification code'), onSubmitted: (_) => onSubmit()),
  ]);
}
