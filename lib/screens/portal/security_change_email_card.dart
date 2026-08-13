import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_widgets.dart';

/// Change email card displayed in the security tab. Owns its [PortalCard]
/// shell; two-step flow: request a verification code at the new address,
/// then confirm it (the previous double-card nesting rendered the
/// "Change email" title twice).
class SecurityChangeEmailCard extends StatelessWidget {
  final TextEditingController newEmailCtrl;
  final TextEditingController emailTokenCtrl;
  final bool emailBusy;
  final bool emailVerifyVisible;
  final String? emailMsg;
  final bool emailOk;
  final VoidCallback onSendCode;
  final VoidCallback onVerifyCode;

  const SecurityChangeEmailCard({
    super.key,
    required this.newEmailCtrl,
    required this.emailTokenCtrl,
    required this.emailBusy,
    required this.emailVerifyVisible,
    this.emailMsg,
    required this.emailOk,
    required this.onSendCode,
    required this.onVerifyCode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PortalCard(
      title: 'Change email',
      children: [
        Text(
          context.tr(
            'We send a verification code to the new address. Enter it below to confirm the change.',
          ),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: newEmailCtrl,
          decoration: InputDecoration(
            labelText: context.tr('New email'),
            prefixIcon: const Icon(Icons.mail_outline),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: emailBusy ? null : onSendCode,
            icon: emailBusy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(context.tr('Send verification code')),
          ),
        ),
        if (emailVerifyVisible) ...[
          const SizedBox(height: 16),
          TextField(
            controller: emailTokenCtrl,
            decoration: InputDecoration(
              labelText: context.strings.verificationCode,
              prefixIcon: const Icon(Icons.verified_outlined),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton.icon(
              onPressed: emailBusy ? null : onVerifyCode,
              icon: const Icon(Icons.check_circle_outline),
              label: Text(context.tr('Confirm new email')),
            ),
          ),
        ],
        MessageBanner(emailMsg, ok: emailOk),
      ],
    );
  }
}
