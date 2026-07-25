import 'package:flutter/material.dart';

class SetupLogo extends StatelessWidget {
  const SetupLogo({super.key});
  @override
  Widget build(BuildContext context) => Container(
    width: 44, height: 44,
    decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(10)),
    child: const Icon(Icons.vpn_key, color: Colors.white, size: 24),
  );
}

class SetupStepDots extends StatelessWidget {
  final int activeCount;
  const SetupStepDots({super.key, required this.activeCount});
  @override
  Widget build(BuildContext context) {
    Widget dot(bool on) => Container(
      width: 34, height: 4,
      decoration: BoxDecoration(
        color: on ? const Color(0xFF6366F1) : const Color(0xFF334155),
        borderRadius: BorderRadius.circular(3),
      ),
    );
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      dot(activeCount >= 1),
      const SizedBox(width: 8),
      dot(activeCount >= 2),
    ]);
  }
}

class SetupOptionalTag extends StatelessWidget {
  const SetupOptionalTag({super.key});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
    decoration: BoxDecoration(color: const Color(0xFF3730A3), borderRadius: BorderRadius.circular(6)),
    child: const Text('optional', style: TextStyle(color: Color(0xFFC7D2FE), fontSize: 11)),
  );
}

class SetupErrorBox extends StatelessWidget {
  final String text;
  const SetupErrorBox({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF7F1D1D), border: Border.all(color: const Color(0xFFB91C1C)), borderRadius: BorderRadius.circular(9)),
    child: Text(text, style: const TextStyle(color: Color(0xFFFECACA), fontSize: 13)),
  );
}

class SetupSuccessBox extends StatelessWidget {
  final String text;
  const SetupSuccessBox({super.key, required this.text});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(color: const Color(0xFF064E3B), border: Border.all(color: const Color(0xFF059669)), borderRadius: BorderRadius.circular(9)),
    child: Text(text, style: const TextStyle(color: Color(0xFFA7F3D0), fontSize: 14)),
  );
}

class SetupCredBox extends StatelessWidget {
  final Widget child;
  const SetupCredBox({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    decoration: BoxDecoration(color: const Color(0xFF0F172A), border: Border.all(color: const Color(0xFF334155)), borderRadius: BorderRadius.circular(9)),
    child: child,
  );
}

class SetupDonePanel extends StatelessWidget {
  final Map<String, dynamic>? config;
  final String? clientId;
  final String? clientSecret;
  final VoidCallback onDone;
  const SetupDonePanel({super.key, this.config, this.clientId, this.clientSecret, required this.onDone});
  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
    const SizedBox(height: 16),
    Text('Setup complete', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 8),
    const Text('Your single sign-on server is ready. These credentials will not be shown again.'),
    if (config != null) SetupCredBox(child: SelectableText(config!['issuer']?.toString() ?? '', style: const TextStyle(fontFamily: 'monospace'))),
    if (clientId != null) ...[const SizedBox(height: 8), SetupCredBox(child: Text(clientId!, style: const TextStyle(fontFamily: 'monospace')))],
    if (clientSecret != null) ...[const SizedBox(height: 8), SetupCredBox(child: SelectableText(clientSecret!, style: const TextStyle(fontFamily: 'monospace')))],
    const SizedBox(height: 32),
    FilledButton(onPressed: onDone, child: const Text('Go to admin console')),
  ]);
}
