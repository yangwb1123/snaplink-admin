import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

Future<void> showClientDetailSecret(
  BuildContext context,
  String secret, {
  int expiresAt = 0,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _ClientDetailSecretDialog(secret: secret, expiresAt: expiresAt),
);

/// Deliberately short-lived, blocking presentation for a rotated secret.
class _ClientDetailSecretDialog extends StatelessWidget {
  final String secret;
  final int expiresAt;

  const _ClientDetailSecretDialog({
    required this.secret,
    required this.expiresAt,
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const LocalizedText('New client secret'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LocalizedText(
            'Save this value through an approved secure channel. It will not be '
            'retained or shown again after you acknowledge this dialog.',
          ),
          const SizedBox(height: 12),
          if (expiresAt > 0)
            LocalizedText(
              'Expires: {time}',
              args: {
                'time': DateTime.fromMillisecondsSinceEpoch(
                  expiresAt * 1000,
                  isUtc: true,
                ).toLocal(),
              },
            ),
          if (expiresAt > 0) const SizedBox(height: 12),
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
          label: const LocalizedText('I have saved it — clear secret'),
        ),
      ],
    ),
  );
}
