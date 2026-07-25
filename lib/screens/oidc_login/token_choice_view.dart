import 'package:flutter/material.dart';
class TokenChoiceView extends StatelessWidget {
  final VoidCallback onVerifyEmail;
  final VoidCallback onResetPassword;
  const TokenChoiceView({super.key, required this.onVerifyEmail, required this.onResetPassword});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Continue with your email link', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 12),
    const Text('Choose the action that sent this link.'),
    const SizedBox(height: 20),
    FilledButton(onPressed: onVerifyEmail, child: const Text('Verify my email')),
    const SizedBox(height: 10),
    OutlinedButton(onPressed: onResetPassword, child: const Text('Reset my password')),
  ]);
}
