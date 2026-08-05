import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'scim_models.dart';

class ScimGroupDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const ScimGroupDialog({super.key, this.existing});

  @override
  State<ScimGroupDialog> createState() => _ScimGroupDialogState();
}

class _ScimGroupDialogState extends State<ScimGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _membersController;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final group = widget.existing ?? const <String, dynamic>{};
    _nameController = TextEditingController(
      text: group['displayName']?.toString() ?? '',
    );
    _membersController = TextEditingController(
      text: (group['members'] as List? ?? const [])
          .whereType<Map>()
          .map((member) => member['value']?.toString() ?? '')
          .where((value) => value.isNotEmpty)
          .join('\n'),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _membersController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final memberIds = _membersController.text
        .split(RegExp(r'[,\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    Navigator.pop(
      context,
      ScimGroupDraft(
        displayName: _nameController.text.trim(),
        memberIds: memberIds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LocalizedText(_editing ? 'Replace SCIM group' : 'Create SCIM group'),
    content: SizedBox(
      width: 560,
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_editing) ...[
              LocalizedText(
                'PUT replaces the display name and reconciles membership to '
                'exactly this list. Role and membership persistence is not a '
                'cross-store transaction; reconcile after a partial failure.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Display name'.localized,
                helperText:
                    'Required. The server assigns the immutable ID.'.localized,
              ),
              validator: (value) =>
                  value == null || value.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _membersController,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: 'Member user IDs'.localized,
                helperText: 'One per line or comma-separated; duplicates drop.'
                    .localized,
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: LocalizedText(_editing ? 'Replace group' : 'Create group'),
      ),
    ],
  );
}
