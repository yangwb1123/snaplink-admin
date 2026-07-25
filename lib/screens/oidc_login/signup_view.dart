import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
class SignupView extends StatelessWidget {
  final TextEditingController signupUserCtrl;
  final TextEditingController signupPassCtrl;
  final TextEditingController signupEmailCtrl;
  final String? error;
  final bool loading;
  final VoidCallback onSubmitSignup;
  final VoidCallback onBack;
  const SignupView({super.key, required this.signupUserCtrl, required this.signupPassCtrl, required this.signupEmailCtrl, this.error, required this.loading, required this.onSubmitSignup, required this.onBack});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.createAccount, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 20),
      TextField(controller: signupUserCtrl, decoration: InputDecoration(labelText: s.username)),
      const SizedBox(height: 14),
      TextField(controller: signupPassCtrl, obscureText: true, decoration: InputDecoration(labelText: s.password)),
      const SizedBox(height: 14),
      TextField(controller: signupEmailCtrl, decoration: InputDecoration(labelText: s.emailOptional)),
      if (error != null) ...[const SizedBox(height: 14), Text(error!, style: const TextStyle(color: Colors.redAccent))],
      const SizedBox(height: 20),
      FilledButton(onPressed: loading ? null : onSubmitSignup, child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.createAccount)),
      TextButton(onPressed: onBack, child: Text(s.back)),
    ]);
  }
}
