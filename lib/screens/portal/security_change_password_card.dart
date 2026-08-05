import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

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
        decoration: InputDecoration(labelText: context.tr('Current password')),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: newPwCtrl,
        obscureText: true,
        decoration: InputDecoration(labelText: context.tr('New password')),
      ),
      const SizedBox(height: 16),
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
              : Text(context.tr('Update password')),
        ),
      ),
      MessageBanner(pwMsg, ok: pwOk),
    ],
  );
}
