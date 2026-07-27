import 'package:flutter/material.dart';
import 'portal_widgets.dart';

/// Change email card displayed in the security tab.
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
  Widget build(BuildContext context) => PortalCard(
    title: 'Change email',
    children: [
      Text(
        'We send a verification code to the new address. Enter it below to confirm the change.',
        style: TextStyle(color: Colors.grey.shade500),
      ),
      const SizedBox(height: 14),
      TextField(
        controller: newEmailCtrl,
        decoration: const InputDecoration(labelText: 'New email'),
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: emailBusy ? null : onSendCode,
          child: emailBusy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Send verification code'),
        ),
      ),
      if (emailVerifyVisible) ...[
        const SizedBox(height: 14),
        TextField(
          controller: emailTokenCtrl,
          decoration: const InputDecoration(labelText: 'Verification code'),
        ),
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: emailBusy ? null : onVerifyCode,
            child: const Text('Confirm new email'),
          ),
        ),
      ],
      MessageBanner(emailMsg, ok: emailOk),
    ],
  );
}
