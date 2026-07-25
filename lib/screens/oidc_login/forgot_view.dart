import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

class ForgotView extends StatelessWidget {
  final TextEditingController forgotIdCtrl;
  final String? forgotMsg;
  final bool loading;
  final VoidCallback onSubmitForgot;
  final VoidCallback onBack;
  const ForgotView({super.key, required this.forgotIdCtrl, this.forgotMsg, required this.loading, required this.onSubmitForgot, required this.onBack});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.resetPassword, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      TextField(controller: forgotIdCtrl, decoration: InputDecoration(labelText: s.usernameOrEmail)),
      if (forgotMsg != null) ...[const SizedBox(height: 14), Text(forgotMsg!)],
      const SizedBox(height: 20),
      FilledButton(onPressed: loading ? null : onSubmitForgot, child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.sendResetLink)),
      TextButton(onPressed: onBack, child: Text(s.back)),
    ]);
  }
}
