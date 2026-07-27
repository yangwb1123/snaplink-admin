import 'package:flutter/material.dart';

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
      title: const Text('Delete app permanently?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This removes the OAuth client and cannot be undone. Type the '
              'exact client ID to confirm:',
            ),
            const SizedBox(height: 10),
            SelectableText(
              widget.clientId,
              style: const TextStyle(fontFamily: 'monospace'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmation,
              autofocus: true,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Client ID confirmation',
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
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: matches ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete App'),
        ),
      ],
    );
  }
}
