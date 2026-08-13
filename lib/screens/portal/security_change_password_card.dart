import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_widgets.dart';

/// Change password card displayed in the security tab. Owns its [PortalCard]
/// shell; [SecurityAccountCredentials] renders it directly (the previous
/// double-card nesting rendered the "Change password" title twice).
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
        decoration: InputDecoration(
          labelText: context.tr('Current password'),
          prefixIcon: const Icon(Icons.lock_outline),
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: newPwCtrl,
        obscureText: true,
        decoration: InputDecoration(
          labelText: context.tr('New password'),
          prefixIcon: const Icon(Icons.password_outlined),
        ),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton.icon(
          onPressed: pwBusy ? null : onChangePassword,
          icon: pwBusy
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.lock_reset),
          label: Text(context.tr('Update password')),
        ),
      ),
      MessageBanner(pwMsg, ok: pwOk),
    ],
  );
}
