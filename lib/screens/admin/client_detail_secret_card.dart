import 'package:flutter/material.dart';

Future<void> showClientDetailSecret(BuildContext context, String secret) =>
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ClientDetailSecretDialog(secret: secret),
    );

/// Deliberately short-lived, blocking presentation for a rotated secret.
class _ClientDetailSecretDialog extends StatelessWidget {
  final String secret;

  const _ClientDetailSecretDialog({required this.secret});

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('New client secret'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Save this value through an approved secure channel. It will not be '
            'retained or shown again after you acknowledge this dialog.',
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(secret),
          ),
        ],
      ),
      actions: [
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check),
          label: const Text('I have saved it — clear secret'),
        ),
      ],
    ),
  );
}
