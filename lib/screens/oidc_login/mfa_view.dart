import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Multi-factor authentication view.
class MfaView extends StatelessWidget {
  final List<String> mfaMethods;
  final String? selectedMfaMethod;
  final Map<String, Map<String, String>> mfaMethodData;
  final TextEditingController mfaCodeCtrl;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(strings.verifyIdentity, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Wrap(spacing: 8, children: mfaMethods.map((m) {
          final sel = selectedMfaMethod == m;
          return ChoiceChip(label: Text(_label(m)), selected: sel, onSelected: (_) => onMethodChanged(m));
        }).toList()),
        if (selectedMfaMethod != null && selectedMfaMethod != 'webauthn' && selectedMfaMethod != 'push') ...[
          const SizedBox(height: 14),
          TextField(controller: mfaCodeCtrl, decoration: InputDecoration(labelText: selectedMfaMethod == 'recovery' ? 'Recovery code' : strings.verificationCode)),
        ],
        if (selectedMfaMethod == 'webauthn') ...[const SizedBox(height: 14), const Text('Use a registered passkey to verify this sign-in.')],
        if (selectedMfaMethod == 'push') ...[const SizedBox(height: 14), const Text('Approve the notification on your device, then continue.')],
        CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Trust this device'), subtitle: const Text('Skip future MFA when allowed.'), value: trustThisDevice, onChanged: loading ? null : onTrustChanged),
        if (error != null) ...[const SizedBox(height: 14), Text(error!, style: const TextStyle(color: Colors.redAccent))],
        const SizedBox(height: 20),
        FilledButton(onPressed: loading ? null : onSubmit, child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(selectedMfaMethod == 'webauthn' ? 'Use passkey' : strings.verify)),
        TextButton(onPressed: onBack, child: Text(strings.back)),
      ],
    );
  }
}
