import 'package:flutter/material.dart';

class ConsentView extends StatelessWidget {
  final String clientName;
  final String clientId;
  final List<String> scopes;
  final String? error;
  final bool loading;
  final VoidCallback onAllow;
  final VoidCallback onDeny;
  const ConsentView({super.key, required this.clientName, required this.clientId, required this.scopes, this.error, required this.loading, required this.onAllow, required this.onDeny});
  @override
  Widget build(BuildContext context) {
    final display = scopes.where((s) => s != 'openid').toList()..add('openid');
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('${clientName.isNotEmpty ? clientName : clientId} wants to:', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      ...display.map((s) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Text('\u2022 ${_label(s)}'))),
      if (error != null) ...[const SizedBox(height: 14), Text(error!, style: const TextStyle(color: Colors.redAccent))],
      const SizedBox(height: 20),
      Row(children: [Expanded(child: OutlinedButton(onPressed: loading ? null : onDeny, child: const Text('Deny'))), const SizedBox(width: 12), Expanded(child: FilledButton(onPressed: loading ? null : onAllow, child: const Text('Allow')))]),
    ]);
  }
  String _label(String s) => const {'openid': 'Verify identity', 'profile': 'View profile', 'email': 'View email', 'offline_access': 'Stay signed in'}[s] ?? s;
}
