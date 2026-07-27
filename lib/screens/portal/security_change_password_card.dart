import 'package:flutter/material.dart';
import 'portal_widgets.dart';

/// Change password card displayed in the security tab.
class SecurityChangePasswordCard extends StatelessWidget {
  final TextEditingController curPwCtrl;
  final TextEditingController newPwCtrl;
  final bool pwBusy;
  final String? pwMsg;
  final bool pwOk;
  final VoidCallback onChangePassword;

  const SecurityChangePasswordCard({
    super.key,
    required this.curPwCtrl,
    required this.newPwCtrl,
    required this.pwBusy,
    this.pwMsg,
    required this.pwOk,
    required this.onChangePassword,
  });

  @override
  Widget build(BuildContext context) => PortalCard(
    title: 'Change password',
    children: [
      TextField(
        controller: curPwCtrl,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'Current password'),
      ),
      const SizedBox(height: 10),
      TextField(
        controller: newPwCtrl,
        obscureText: true,
        decoration: const InputDecoration(labelText: 'New password'),
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: pwBusy ? null : onChangePassword,
          child: pwBusy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Update password'),
        ),
      ),
      MessageBanner(pwMsg, ok: pwOk),
    ],
  );
}
