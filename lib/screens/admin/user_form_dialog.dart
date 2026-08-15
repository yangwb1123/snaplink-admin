import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/sso_client.dart';

/// Create/edit form for an [AdminUser]. Reused for both flows: [existing]
/// null means create (the id field is editable and required); non-null means
/// edit (id is fixed, shown disabled, and used only to address the update call).
class UserFormDialog extends StatefulWidget {
  final SSOAdminClient client;
  final Map<String, dynamic>? existing;

  const UserFormDialog({super.key, required this.client, this.existing});

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _idController;
  late final TextEditingController _externalIdController;
  late final TextEditingController _providerController;
  late final TextEditingController _attributesController;
  bool _submitting = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _idController = TextEditingController(text: u?['id']?.toString() ?? '');
    _externalIdController = TextEditingController(
      text: u?['external_id']?.toString() ?? u?['externalId']?.toString() ?? '',
    );
    _providerController = TextEditingController(
      text: u?['provider']?.toString() ?? '',
    );
    _attributesController = TextEditingController(
      text: _attributesToText(u?['attributes']),
    );
  }

  @override
  void dispose() {
    _idController.dispose();
    _externalIdController.dispose();
    _providerController.dispose();
    _attributesController.dispose();
    super.dispose();
  }

  static String _attributesToText(dynamic attributes) {
    if (attributes is Map) {
      return attributes.entries.map((e) => '${e.key}=${e.value}').join('\n');
    }
    return '';
  }

  static Map<String, String> _parseAttributes(String text) {
    final result = <String, String>{};
    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      final idx = trimmed.indexOf('=');
      if (idx <= 0) continue;
      result[trimmed.substring(0, idx).trim()] = trimmed
          .substring(idx + 1)
          .trim();
    }
    return result;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);
    final body = <String, dynamic>{
      'external_id': _externalIdController.text.trim(),
      'provider': _providerController.text.trim(),
      'attributes': _parseAttributes(_attributesController.text),
    };
    try {
      Map<String, dynamic> result;
      if (_isEditing) {
        result = await widget.client.updateUser(
          _idController.text.trim(),
          body,
        );
      } else {
        body['id'] = _idController.text.trim();
        result = await widget.client.createUser(body);
      }
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } on SSOError catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: LocalizedText(_isEditing ? 'Edit User' : 'Create user'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _idController,
                  enabled: !_isEditing,
                  autofocus: !_isEditing,
                  decoration: InputDecoration(labelText: 'ID'.localized),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _externalIdController,
                  decoration: InputDecoration(labelText: 'External ID'.localized),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _providerController,
                  decoration: InputDecoration(labelText: 'Provider'.localized),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _attributesController,
                  decoration: InputDecoration(
                    labelText: 'Attributes (one key=value per line)'.localized,
                    alignLabelWithHint: true,
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const LocalizedText('Cancel'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : LocalizedText(_isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
