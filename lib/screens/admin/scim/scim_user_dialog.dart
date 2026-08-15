import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'scim_models.dart';

class ScimUserDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;

  const ScimUserDialog({super.key, this.existing});

  @override
  State<ScimUserDialog> createState() => _ScimUserDialogState();
}

class _ScimUserDialogState extends State<ScimUserDialog> {
  final _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _controllers;
  late bool _active;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final user = widget.existing ?? const <String, dynamic>{};
    final name = _map(user['name']);
    final enterprise = _map(user[scimEnterpriseUserSchema]);
    final manager = _map(enterprise['manager']);
    _active = user['active'] != false;
    _controllers = {
      'userName': _controller(user['userName']),
      'displayName': _controller(user['displayName']),
      'externalId': _controller(user['externalId']),
      'formatted': _controller(name['formatted']),
      'givenName': _controller(name['givenName']),
      'familyName': _controller(name['familyName']),
      'middleName': _controller(name['middleName']),
      'honorificPrefix': _controller(name['honorificPrefix']),
      'honorificSuffix': _controller(name['honorificSuffix']),
      'emails': TextEditingController(text: _formatEmails(user['emails'])),
      'employeeNumber': _controller(enterprise['employeeNumber']),
      'costCenter': _controller(enterprise['costCenter']),
      'organization': _controller(enterprise['organization']),
      'division': _controller(enterprise['division']),
      'department': _controller(enterprise['department']),
      'managerValue': _controller(manager['value']),
      'managerDisplay': _controller(manager['displayName']),
      'managerRef': _controller(manager[r'$ref']),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final emails = _parseEmails(_text('emails'));
    final managerValue = _text('managerValue');
    final enterprise = <String, dynamic>{
      for (final key in const [
        'employeeNumber',
        'costCenter',
        'organization',
        'division',
        'department',
      ])
        if (_text(key).isNotEmpty) key: _text(key),
      if (managerValue.isNotEmpty)
        'manager': {
          'value': managerValue,
          if (_text('managerDisplay').isNotEmpty)
            'displayName': _text('managerDisplay'),
          if (_text('managerRef').isNotEmpty) r'$ref': _text('managerRef'),
        },
    };
    Navigator.pop(
      context,
      ScimUserDraft(
        userName: _text('userName'),
        displayName: _text('displayName'),
        externalId: _text('externalId'),
        active: _active,
        name: {
          'formatted': _text('formatted'),
          'givenName': _text('givenName'),
          'familyName': _text('familyName'),
          'middleName': _text('middleName'),
          'honorificPrefix': _text('honorificPrefix'),
          'honorificSuffix': _text('honorificSuffix'),
        },
        emails: emails,
        enterprise: enterprise,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LocalizedText(_editing ? 'Replace SCIM user' : 'Create SCIM user'),
    content: SizedBox(
      width: 720,
      height: MediaQuery.sizeOf(context).height * .68,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          children: [
            if (_editing)
              const _Notice(
                text:
                    'PUT is a full SCIM replacement. Attributes represented '
                    'below are sent as the new resource state.',
              ),
            _sectionTitle(context, 'Identity'),
            _twoColumns(
              _field(
                'userName',
                'User name',
                required: true,
                helper: 'Required and unique (case-insensitive)',
                autofocus: !_editing,
              ),
              _field('displayName', 'Display name'),
            ),
            _twoColumns(
              _field('externalId', 'External ID'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const LocalizedText('Active'),
                subtitle: const LocalizedText('Turn off to deprovision'),
                value: _active,
                onChanged: (value) => setState(() => _active = value),
              ),
            ),
            _sectionTitle(context, 'Name'),
            _twoColumns(
              _field('givenName', 'Given name'),
              _field('familyName', 'Family name'),
            ),
            _twoColumns(
              _field('middleName', 'Middle name'),
              _field('honorificPrefix', 'Honorific prefix'),
            ),
            _field('honorificSuffix', 'Honorific suffix'),
            _field('formatted', 'Formatted name'),
            _sectionTitle(context, 'Email addresses'),
            TextFormField(
              controller: _controllers['emails'],
              minLines: 2,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Emails'.localized,
                helperText:
                    'One per line: address | type | primary. Only one primary.'
                        .localized,
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              validator: _validateEmails,
            ),
            _sectionTitle(context, 'Enterprise extension'),
            _twoColumns(
              _field('employeeNumber', 'Employee number'),
              _field('department', 'Department'),
            ),
            _twoColumns(
              _field('costCenter', 'Cost center'),
              _field('organization', 'Organization'),
            ),
            _twoColumns(
              _field('division', 'Division'),
              _field(
                'managerValue',
                'Manager user ID',
                helper: 'Must resolve to an existing user; cycles are rejected',
              ),
            ),
            _twoColumns(
              _field('managerDisplay', 'Manager display name'),
              _field('managerRef', r'Manager $ref URI'),
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
        child: LocalizedText(_editing ? 'Replace user' : 'Create user'),
      ),
    ],
  );

  Widget _field(
    String key,
    String label, {
    bool required = false,
    String? helper,
    bool autofocus = false,
  }) => TextFormField(
    controller: _controllers[key],
    autofocus: autofocus,
    decoration: InputDecoration(
      labelText: label.localized,
      helperText: helper?.localized,
    ),
    validator: required
        ? (value) => value == null || value.trim().isEmpty ? 'Required' : null
        : null,
  );

  Widget _twoColumns(Widget first, Widget second) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 560) {
        return Column(children: [first, second]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: first),
          const SizedBox(width: 16),
          Expanded(child: second),
        ],
      );
    },
  );

  Widget _sectionTitle(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 8),
    child: LocalizedText(text, style: Theme.of(context).textTheme.titleMedium),
  );

  String _text(String key) => _controllers[key]!.text.trim();

  String? _validateEmails(String? source) {
    var primaryCount = 0;
    final seen = <String>{};
    for (final line in (source ?? '').split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('|').map((value) => value.trim()).toList();
      final email = parts.first;
      if (!email.contains('@')) return 'Invalid email address: $email';
      if (!seen.add(email.toLowerCase())) return 'Duplicate email: $email';
      if (parts.length > 2 &&
          const ['true', 'yes', 'primary'].contains(parts[2].toLowerCase())) {
        primaryCount++;
      }
    }
    return primaryCount > 1 ? 'Only one email may be primary.' : null;
  }

  List<Map<String, dynamic>> _parseEmails(String source) {
    final values = <Map<String, dynamic>>[];
    for (final line in source.split('\n')) {
      if (line.trim().isEmpty) continue;
      final parts = line.split('|').map((value) => value.trim()).toList();
      values.add({
        'value': parts.first,
        if (parts.length > 1 && parts[1].isNotEmpty) 'type': parts[1],
        if (parts.length > 2 &&
            const ['true', 'yes', 'primary'].contains(parts[2].toLowerCase()))
          'primary': true,
      });
    }
    return values;
  }

  static TextEditingController _controller(Object? value) =>
      TextEditingController(text: value?.toString() ?? '');

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};

  static String _formatEmails(Object? value) {
    if (value is! List) return '';
    return value
        .whereType<Map>()
        .map((email) {
          final parts = [
            email['value']?.toString() ?? '',
            email['type']?.toString() ?? '',
            if (email['primary'] == true) 'primary',
          ];
          while (parts.isNotEmpty && parts.last.isEmpty) {
            parts.removeLast();
          }
          return parts.join(' | ');
        })
        .join('\n');
  }
}

class _Notice extends StatelessWidget {
  final String text;

  const _Notice({required this.text});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.secondaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: LocalizedText(text),
  );
}
