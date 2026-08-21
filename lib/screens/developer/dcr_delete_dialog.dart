import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// RFC 7592 DELETE confirmation: destructive, type-the-exact-client-id gate
/// so the client cannot be removed by accident.
Future<bool> confirmDcrDeletion(
  BuildContext context, {
  required String clientId,
}) async {
  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => _DcrDeleteDialog(clientId: clientId),
      ) ??
      false;
}

class _DcrDeleteDialog extends StatefulWidget {
  final String clientId;

  const _DcrDeleteDialog({required this.clientId});

  @override
  State<_DcrDeleteDialog> createState() => _DcrDeleteDialogState();
}

class _DcrDeleteDialogState extends State<_DcrDeleteDialog> {
  final _confirmation = TextEditingController();

  @override
  void dispose() {
    _confirmation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matches = _confirmation.text == widget.clientId;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
      icon: Icon(
        Icons.delete_forever_outlined,
        color: AppColors.semanticFor(
          Theme.of(context).brightness,
          AppColors.danger,
        ),
      ),
      title: Text(context.tr('Delete app permanently?')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(
                'This removes the OAuth client and cannot be undone. Type the exact client ID to confirm:',
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                widget.clientId,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _confirmation,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(
                labelText: context.tr('Client ID confirmation'),
                prefixIcon: const Icon(Icons.pin_outlined),
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (matches) Navigator.of(context).pop(true);
              },
            ),
            const SizedBox(height: 8),
            Text(
              context.tr('Type the exact client ID to enable deletion.'),
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(context.strings.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          child: Text(context.tr('Delete App')),
        ),
      ],
    );
  }
}
