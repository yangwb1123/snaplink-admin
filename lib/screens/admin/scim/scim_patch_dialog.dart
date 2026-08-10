import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'scim_models.dart';

class ScimPatchDialog extends StatefulWidget {
  final ScimResourceKind kind;
  final String resourceId;

  const ScimPatchDialog({
    super.key,
    required this.kind,
    required this.resourceId,
  });

  @override
  State<ScimPatchDialog> createState() => _ScimPatchDialogState();
}

class _ScimPatchDialogState extends State<ScimPatchDialog> {
  final List<_PatchRow> _rows = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _rows.add(_PatchRow(path: _pathsFor('replace').first));
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  List<String> _pathsFor(String op) {
    if (widget.kind == ScimResourceKind.groups) {
      return const ['displayName', 'members', 'member by ID'];
    }
    final values = <String>[
      'active',
      'userName',
      'displayName',
      'externalId',
      'emails',
      'name.formatted',
      'name.givenName',
      'name.familyName',
      'name.middleName',
      'name.honorificPrefix',
      'name.honorificSuffix',
      'employeeNumber',
      'costCenter',
      'organization',
      'division',
      'department',
      'manager',
    ];
    if (op == 'remove') {
      values
        ..remove('userName')
        ..addAll(const ['email by address', 'emails by type']);
    }
    return values;
  }

  void _addRow() =>
      setState(() => _rows.add(_PatchRow(path: _pathsFor('replace').first)));

  void _removeRow(int index) {
    if (_rows.length == 1) return;
    setState(() => _rows.removeAt(index).dispose());
  }

  void _submit() {
    try {
      final operations = _rows.map(_buildOperation).toList(growable: false);
      Navigator.pop(context, scimPatchBody(operations));
    } on FormatException catch (error) {
      setState(() => _error = error.message);
    }
  }

  ScimPatchOperation _buildOperation(_PatchRow row) {
    final raw = row.controller.text.trim();
    if (row.path == 'member by ID') {
      if (row.op != 'remove') {
        throw const FormatException('Member-by-ID supports remove only.');
      }
      if (raw.isEmpty) {
        throw const FormatException('Member user ID is required.');
      }
      final escaped = raw.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
      return ScimPatchOperation(
        op: row.op,
        path: 'members[value eq "$escaped"]',
      );
    }
    if (row.path == 'email by address' || row.path == 'emails by type') {
      if (raw.isEmpty) {
        throw const FormatException('Email filter value is required.');
      }
      final attribute = row.path == 'email by address' ? 'value' : 'type';
      return ScimPatchOperation(
        op: 'remove',
        path: 'emails[$attribute eq "${_escapeFilter(raw)}"]',
      );
    }
    if (row.op == 'remove') {
      return ScimPatchOperation(op: row.op, path: row.path);
    }
    if (row.path == 'active') {
      return ScimPatchOperation(
        op: row.op,
        path: row.path,
        value: row.activeValue,
      );
    }
    if (raw.isEmpty) {
      throw FormatException('${row.path} requires a value.');
    }
    if (row.path == 'emails') {
      final emails = _lines(raw)
          .map((value) => {'value': value, 'type': 'work'})
          .toList(growable: false);
      return ScimPatchOperation(op: row.op, path: row.path, value: emails);
    }
    if (row.path == 'members') {
      final members = _lines(raw)
          .map((value) => {'value': value, 'type': 'User'})
          .toList(growable: false);
      return ScimPatchOperation(op: row.op, path: row.path, value: members);
    }
    if (row.path == 'manager') {
      return ScimPatchOperation(
        op: row.op,
        path: row.path,
        value: {'value': raw},
      );
    }
    return ScimPatchOperation(op: row.op, path: row.path, value: raw);
  }

  List<String> _lines(String value) => value
      .split(RegExp(r'[,\n]'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList(growable: false);

  String _escapeFilter(String value) =>
      value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: LocalizedText('Patch {widget_kind_singular} {widget_resourceId}', args: {'widget_kind_singular': widget.kind.singular, 'widget_resourceId': widget.resourceId}),
    content: SizedBox(
      width: 700,
      height: MediaQuery.sizeOf(context).height * .62,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            widget.kind == ScimResourceKind.users
                ? 'Operations run in order and are validated before the user '
                      'is persisted once. Invalid paths abort the patch.'
                : 'Operations are validated in order before execution. Group '
                      'membership storage is not transactional; reconcile the '
                      'group if the server reports a partial failure.',
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _rows.length,
              itemBuilder: (context, index) => _operationCard(index),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add),
              label: const LocalizedText('Add ordered operation'),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Cancel'),
      ),
      FilledButton(
        onPressed: _submit,
        child: const LocalizedText('Apply patch'),
      ),
    ],
  );

  void _onOperationChanged(_PatchRow row, String? value) {
    setState(() {
      row.op = value!;
      final nextPaths = _pathsFor(row.op);
      if (!nextPaths.contains(row.path)) {
        row.path = nextPaths.first;
      }
    });
  }

  Widget _operationCard(int index) {
    final row = _rows[index];
    final paths = _pathsFor(row.op);
    if (!paths.contains(row.path)) row.path = paths.first;
    final needsValue =
        row.op != 'remove' ||
        row.path == 'member by ID' ||
        row.path == 'email by address' ||
        row.path == 'emails by type';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                LocalizedText(
                  'Operation ${index + 1}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                IconButton(
                  onPressed: _rows.length > 1 ? () => _removeRow(index) : null,
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: 'Remove operation'.localized,
                ),
              ],
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: row.op,
                    decoration: InputDecoration(
                      labelText: 'Operation'.localized,
                    ),
                    items: const ['add', 'replace', 'remove']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => _onOperationChanged(row, value),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    initialValue: row.path,
                    decoration: InputDecoration(labelText: 'Path'.localized),
                    items: paths
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => row.path = value!),
                  ),
                ),
              ],
            ),
            if (needsValue) ...[
              const SizedBox(height: 8),
              if (row.path == 'active')
                DropdownButtonFormField<bool>(
                  initialValue: row.activeValue,
                  decoration: InputDecoration(labelText: 'Value'.localized),
                  items: const [
                    DropdownMenuItem(value: true, child: LocalizedText('true')),
                    DropdownMenuItem(
                      value: false,
                      child: LocalizedText('false'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => row.activeValue = value!),
                )
              else
                TextField(
                  controller: row.controller,
                  minLines: _multiLine(row.path) ? 2 : 1,
                  maxLines: _multiLine(row.path) ? 5 : 1,
                  decoration: InputDecoration(
                    labelText:
                        (row.path == 'member by ID'
                                ? 'Member user ID'
                                : row.path == 'email by address'
                                ? 'Email address'
                                : row.path == 'emails by type'
                                ? 'Email type'
                                : 'Value')
                            .localized,
                    helperText: _helper(row.path)?.localized,
                    border: _multiLine(row.path)
                        ? const OutlineInputBorder()
                        : null,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  bool _multiLine(String path) => path == 'emails' || path == 'members';

  String? _helper(String path) => switch (path) {
    'emails' => 'Email addresses, one per line',
    'members' => 'User IDs, one per line',
    'manager' => 'Existing manager user ID; cycles are rejected',
    'member by ID' => 'Builds a filtered member removal safely',
    'email by address' => 'Removes matching email elements',
    'emails by type' => 'Removes every email with this type',
    _ => null,
  };
}

class _PatchRow {
  String op = 'replace';
  String path;
  bool activeValue = true;
  final TextEditingController controller;

  _PatchRow({required this.path}) : controller = TextEditingController();

  void dispose() => controller.dispose();
}
