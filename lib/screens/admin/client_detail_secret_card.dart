import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';

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
    copyable: true,
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

class ClientSecretDialog extends StatefulWidget {
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
  State<ClientSecretDialog> createState() => _ClientSecretDialogState();
}

class _ClientSecretDialogState extends State<ClientSecretDialog> {
  // Reveal by default so the existing one-time delivery remains immediately
  // usable. Hiding is local presentation only; acknowledgement still clears
  // the card by closing this blocking dialog.
  bool _revealed = true;

  void _toggleVisibility() => setState(() => _revealed = !_revealed);

  Future<void> _copySecret(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: widget.secret));
    if (!context.mounted) return;
    showCopySnackBar(
      context,
      content: const LocalizedText('Copied to clipboard'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: false,
      child: AlertDialog(
        // Keep the action reachable when the keyboard or a very small window
        // reduces the available height. The content remains one scrollable
        // secret card; no secret/lifecycle behaviour is changed.
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        scrollable: true,
        title: const LocalizedText('New client secret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LocalizedText(widget.introKey),
            if (widget.expiryLabel != null) ...[
              const SizedBox(height: 12),
              Text(widget.expiryLabel!, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _revealed
                        ? SelectableText(
                            widget.secret,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontFamily: 'monospace',
                            ),
                          )
                        : ExcludeSemantics(
                            child: Text(
                              '••••••••••••',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                  ),
                  IconButton(
                    icon: Icon(
                      _revealed
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                    tooltip: (_revealed ? 'Hide' : 'Show').localized,
                    visualDensity: VisualDensity.compact,
                    onPressed: _toggleVisibility,
                  ),
                  if (widget.copyable)
                    IconButton(
                      icon: const Icon(Icons.copy_outlined),
                      tooltip: 'Copy to clipboard'.localized,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _copySecret(context),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          FilledButton.icon(
            autofocus: true,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check),
            label: LocalizedText(widget.acknowledgeKey),
          ),
        ],
      ),
    );
  }
}
