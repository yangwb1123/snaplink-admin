import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/pressable_scale.dart';

/// Multi-factor authentication view.
///
/// Pure presentation: the challenge lifecycle (invalidation, re-authentication,
/// one-time method selection) lives in the owning flow. This view only renders
/// the current server-declared factor list and disabled/loading states.
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

  String _label(AppStrings strings, String method) => switch (method) {
    'totp' => strings.mfaMethodTotp,
    'otp' => strings.mfaMethodOtp,
    'webauthn' => strings.mfaMethodWebauthn,
    'push' => strings.mfaMethodPush,
    'sms' => strings.mfaMethodSms,
    _ => method,
  };

  IconData _methodIcon(String method) => switch (method) {
    'totp' => Icons.smartphone_outlined,
    'otp' => Icons.pin_outlined,
    'webauthn' => Icons.fingerprint,
    'push' => Icons.notifications_active_outlined,
    'sms' => Icons.sms_outlined,
    _ => Icons.shield_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final strings = AppStrings.of(context);
    final acceptsCode =
        selectedMfaMethod != null &&
        selectedMfaMethod != 'webauthn' &&
        selectedMfaMethod != 'push';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          container: true,
          header: true,
          child: Text(
            strings.verifyIdentity,
            style: theme.textTheme.titleLarge,
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: mfaMethods.map((method) {
            final selected = selectedMfaMethod == method;
            return ChoiceChip(
              avatar: Icon(
                _methodIcon(method),
                size: 18,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              label: Text(_label(strings, method)),
              selected: selected,
              onSelected: loading ? null : (_) => onMethodChanged(method),
            );
          }).toList(),
        ),
        if (selectedMfaMethod == null && mfaMethods.length > 1) ...[
          const SizedBox(height: 12),
          _notice(
            context,
            context.tr('Select a verification method.'),
            Icons.info_outline,
          ),
        ],
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
              prefixIcon: Icon(Icons.pin_outlined, color: scheme.primary),
            ),
            onSubmitted: (_) {
              if (!loading) onSubmit();
            },
          ),
        ],
        if (selectedMfaMethod == 'webauthn') ...[
          const SizedBox(height: 16),
          _notice(
            context,
            context.tr('Use a registered passkey to verify this sign-in.'),
            Icons.fingerprint,
          ),
        ],
        if (selectedMfaMethod == 'push') ...[
          const SizedBox(height: 16),
          _notice(
            context,
            context.tr(
              'Approve the notification on your device, then continue.',
            ),
            Icons.notifications_active_outlined,
          ),
        ],
        if (allowTrustDevice)
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.trailing,
            secondary: Icon(
              Icons.verified_user_outlined,
              color: scheme.primary,
            ),
            title: Text(context.tr('Trust this device')),
            subtitle: Text(context.tr('Skip future MFA when allowed.')),
            value: trustThisDevice,
            onChanged: loading ? null : onTrustChanged,
          ),
        if (error != null) ...[
          const SizedBox(height: 16),
          _notice(
            context,
            context.tr(error!),
            Icons.error_outline,
            color: scheme.onErrorContainer,
            contained: true,
            live: true,
          ),
        ],
        const SizedBox(height: 20),
        PressableScale(
          child: FilledButton(
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
        ),
        TextButton(
          onPressed: loading ? null : onBack,
          child: Text(strings.back),
        ),
      ],
    );
  }

  /// 内联提示条：品牌/语义色图标 + 文案；`contained` 变体用于错误
  /// （errorContainer 底 + onErrorContainer 前景）。
  Widget _notice(
    BuildContext context,
    String text,
    IconData icon, {
    Color? color,
    bool contained = false,
    bool live = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color ?? scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: color ?? scheme.primary)),
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
