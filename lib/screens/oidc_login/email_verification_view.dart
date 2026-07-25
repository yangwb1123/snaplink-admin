import 'package:flutter/material.dart';
class EmailVerificationView extends StatelessWidget {
  final String? resetMsg;
  final bool loading;
  final VoidCallback onSubmit;
  const EmailVerificationView({super.key, this.resetMsg, required this.loading, required this.onSubmit});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Verify your email', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: 16),
    const Text('Click below to verify your email address.'),
    if (resetMsg != null) ...[const SizedBox(height: 14), Text(resetMsg!, style: const TextStyle(color: Colors.redAccent))],
    const SizedBox(height: 20),
    FilledButton(onPressed: loading ? null : onSubmit, child: loading ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Verify email')),
  ]);
}
