import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;

/// Setup wizard "Done" panel.
class SetupDonePanel extends StatelessWidget {
  final Map<String, dynamic>? config;
  final String? clientId;
  final String? clientSecret;

  const SetupDonePanel({super.key, this.config, this.clientId, this.clientSecret});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.check_circle_outline, size: 72, color: Colors.green),
        const SizedBox(height: 16),
        Text('Setup complete', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text(
          'Your single sign-on server is ready. These credentials will not be shown again.',
        ),
        if (config != null) ...[
          const SizedBox(height: 24),
          Text('Issuer', style: Theme.of(context).textTheme.titleSmall),
          SelectableText(config!['issuer']?.toString() ?? '', style: const TextStyle(fontFamily: 'monospace')),
        ],
        if (clientId != null) ...[
          const SizedBox(height: 16),
          Text('Client ID', style: Theme.of(context).textTheme.titleSmall),
          SelectableText(clientId!, style: const TextStyle(fontFamily: 'monospace')),
        ],
        if (clientSecret != null) ...[
          const SizedBox(height: 16),
          Text('Client secret', style: Theme.of(context).textTheme.titleSmall),
          SelectableText(clientSecret!, style: const TextStyle(fontFamily: 'monospace')),
        ],
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => web.window.location.replace('/admin/'),
          child: const Text('Go to admin console'),
        ),
      ],
    );
  }
}
