import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
class ResetView extends StatelessWidget {
  final TextEditingController resetPassCtrl;
  final TextEditingController resetConfirmCtrl;
  final String? resetMsg;
  final bool loading;
  final VoidCallback onSubmitReset;
  const ResetView({super.key, required this.resetPassCtrl, required this.resetConfirmCtrl, this.resetMsg, required this.loading, required this.onSubmitReset});
  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text(s.resetPassword, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 16),
      TextField(controller: resetPassCtrl, obscureText: true, decoration: InputDecoration(labelText: s.password)),
      const SizedBox(height: 14),
      TextField(controller: resetConfirmCtrl, obscureText: true, decoration: const InputDecoration(labelText: 'Confirm password')),
      if (resetMsg != null) ...[const SizedBox(height: 14), Text(resetMsg!, style: const TextStyle(color: Colors.redAccent))],
      const SizedBox(height: 20),
      FilledButton(onPressed: loading ? null : onSubmitReset, child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(s.resetPassword)),
    ]);
  }
}
