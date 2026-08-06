import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

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
    return AlertDialog(
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
            SelectableText(
              widget.clientId,
              style: const TextStyle(fontFamily: 'monospace'),
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
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (matches) Navigator.of(context).pop(true);
              },
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
