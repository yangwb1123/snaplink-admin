import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// Blocking one-time-secret dialog (barrier + back button locked until the
/// user acknowledges). Shared by the detail screen and the list-tab rotate
/// flow; copy/intro/acknowledge strings are injected as i18n keys.
Future<void> showClientDetailSecret(
  BuildContext context,
  String secret, {
  int expiresAt = 0,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => ClientSecretDialog(
    secret: secret,
    expiryLabel: expiresAt > 0
        ? dialogContext.tr('Expires: {time}', {
            'time': DateTime.fromMillisecondsSinceEpoch(
              expiresAt * 1000,
              isUtc: true,
            ).toLocal(),
          })
        : null,
    introKey:
        'Save this value through an approved secure channel. It will not be '
        'retained or shown again after you acknowledge this dialog.',
    acknowledgeKey: 'I have saved it — clear secret',
  ),
);

/// List-tab rotation variant: copyable secret + short intro + expiry label
/// already localized by [clientSecretExpiryLabel].
Future<void> showRotatedClientSecret(
  BuildContext context,
  String secret, {
  required String expiryLabel,
}) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (dialogContext) => ClientSecretDialog(
    secret: secret,
    expiryLabel: expiryLabel,
    copyable: true,
    introKey: 'This secret will not be shown again.',
    acknowledgeKey: 'I have saved it',
  ),
);

class ClientSecretDialog extends StatelessWidget {
  final String secret;
  final String introKey;
  final String acknowledgeKey;
  final String? expiryLabel;
  final bool copyable;

  const ClientSecretDialog({
    super.key,
    required this.secret,
    required this.introKey,
    required this.acknowledgeKey,
    this.expiryLabel,
    this.copyable = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const LocalizedText('New client secret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(introKey),
            if (expiryLabel != null) ...[
              const SizedBox(height: 12),
              Text(expiryLabel!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(child: SelectableText(secret)),
                  if (copyable)
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy to clipboard'.localized,
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: secret));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: LocalizedText('Copied to clipboard'),
                            ),
                          );
                        }
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: LocalizedText(acknowledgeKey),
          ),
        ],
      ),
    );
  }
}
