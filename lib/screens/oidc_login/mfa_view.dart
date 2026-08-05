import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Multi-factor authentication view.
class MfaView extends StatelessWidget {
  final List<String> mfaMethods;
  final String? selectedMfaMethod;
  final Map<String, Map<String, String>> mfaMethodData;
  final TextEditingController mfaCodeCtrl;
  final bool allowTrustDevice;
  final bool trustThisDevice;
  final bool loading;
  final String? error;
  final ValueChanged<String?> onMethodChanged;
  final ValueChanged<bool?> onTrustChanged;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  const MfaView({
    super.key,
    required this.mfaMethods,
    this.selectedMfaMethod,
    required this.mfaMethodData,
    required this.mfaCodeCtrl,
    required this.allowTrustDevice,
    required this.trustThisDevice,
    required this.loading,
    this.error,
    required this.onMethodChanged,
    required this.onTrustChanged,
    required this.onSubmit,
    required this.onBack,
  });

  String _label(String m) {
    const labels = {
      'totp': 'Authenticator app (TOTP)',
      'otp': 'One-time code',
      'webauthn': 'Security key / passkey',
      'push': 'Push notification',
      'sms': 'SMS code',
    };
    return labels[m] ?? m;
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final acceptsCode =
        selectedMfaMethod != null &&
        selectedMfaMethod != 'webauthn' &&
        selectedMfaMethod != 'push';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.verifyIdentity,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: mfaMethods.map((method) {
            final selected = selectedMfaMethod == method;
            return ChoiceChip(
              label: Text(context.tr(_label(method))),
              selected: selected,
              onSelected: loading ? null : (_) => onMethodChanged(method),
            );
          }).toList(),
        ),
        if (acceptsCode) ...[
          const SizedBox(height: 16),
          TextField(
            controller: mfaCodeCtrl,
            enabled: !loading,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: selectedMfaMethod == 'recovery'
                ? TextInputType.visiblePassword
                : TextInputType.number,
            autofillHints: selectedMfaMethod == 'recovery'
                ? const []
                : const [AutofillHints.oneTimeCode],
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: selectedMfaMethod == 'recovery'
                  ? context.tr('Recovery code')
                  : strings.verificationCode,
            ),
            onSubmitted: (_) {
              if (!loading) onSubmit();
            },
          ),
        ],
        if (selectedMfaMethod == 'webauthn') ...[
          const SizedBox(height: 16),
          Text(context.tr('Use a registered passkey to verify this sign-in.')),
        ],
        if (selectedMfaMethod == 'push') ...[
          const SizedBox(height: 16),
          Text(
            context.tr(
              'Approve the notification on your device, then continue.',
            ),
          ),
        ],
        if (allowTrustDevice)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.tr('Trust this device')),
            subtitle: Text(context.tr('Skip future MFA when allowed.')),
            value: trustThisDevice,
            onChanged: loading ? null : onTrustChanged,
          ),
        if (error != null) ...[
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              context.tr(error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
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
                  selectedMfaMethod == 'webauthn'
                      ? context.tr('Use passkey')
                      : strings.verify,
                ),
        ),
        TextButton(
          onPressed: loading ? null : onBack,
          child: Text(strings.back),
        ),
      ],
    );
  }
}
