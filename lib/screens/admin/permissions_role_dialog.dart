import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'admin_module_groups.dart';

class PermissionsRoleDraft {
  final String code;
  final String name;
  final String description;
  final List<String> permissions;

  const PermissionsRoleDraft(
    this.code,
    this.name,
    this.description,
    this.permissions,
  );

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'description': description,
    'permissions': permissions,
  };
}

class PermissionsRoleDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const PermissionsRoleDialog({super.key, this.existing});

  @override
  State<PermissionsRoleDialog> createState() => _PermissionsRoleDialogState();
}

class _PermissionsRoleDialogState extends State<PermissionsRoleDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _permissionsCtrl;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final role = widget.existing;
    _codeCtrl = TextEditingController(text: role?['code']?.toString() ?? '');
    _nameCtrl = TextEditingController(text: role?['name']?.toString() ?? '');
    _descriptionCtrl = TextEditingController(
      text: role?['description']?.toString() ?? '',
    );
    _permissionsCtrl = TextEditingController(
      text: _strings(role?['permissions']).join('\n'),
    );
  }

  @override
  void dispose() {
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _permissionsCtrl.dispose();
    super.dispose();
  }

  List<String> _strings(Object? value) => value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final permissions = _permissionsCtrl.text
        .split(RegExp(r'[,\n]'))
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    Navigator.pop(
      context,
      PermissionsRoleDraft(
        _codeCtrl.text.trim(),
        _nameCtrl.text.trim(),
        _descriptionCtrl.text.trim(),
        permissions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = adminModuleIconColor('permissions');
    return AlertDialog(
      title: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Icon(Icons.shield_outlined, size: 18, color: accent),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: LocalizedText(_editing ? 'Edit role' : 'Create role'),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _codeCtrl,
                  enabled: !_editing,
                  autofocus: !_editing,
                  decoration: InputDecoration(
                    labelText: 'Role code'.localized,
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? context.tr('Required')
                      : null,
                ),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(labelText: 'Name'.localized),
                ),
                TextFormField(
                  controller: _descriptionCtrl,
                  decoration: InputDecoration(
                    labelText: 'Description'.localized,
                  ),
                  maxLines: 2,
                ),
                TextFormField(
                  controller: _permissionsCtrl,
                  decoration: InputDecoration(
                    labelText: 'Permissions'.localized,
                    helperText: 'Comma or line separated'.localized,
                  ),
                  minLines: 2,
                  maxLines: 5,
                ),
              ],
            ),
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
          child: const LocalizedText('Continue'),
        ),
      ],
    );
  }
}

