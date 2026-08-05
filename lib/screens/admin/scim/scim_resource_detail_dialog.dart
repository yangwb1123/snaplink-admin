import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'scim_models.dart';

enum ScimDetailAction { replace, patch, delete }

class ScimResourceDetailDialog extends StatelessWidget {
  final ScimResourceKind kind;
  final Map<String, dynamic> resource;

  const ScimResourceDetailDialog({
    super.key,
    required this.kind,
    required this.resource,
  });

  @override
  Widget build(BuildContext context) {
    final id = resource['id']?.toString() ?? '';
    final meta = _map(resource['meta']);
    final version = meta['version']?.toString() ?? '';
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            kind == ScimResourceKind.users
                ? Icons.person_outline
                : Icons.groups_outlined,
          ),
          const SizedBox(width: 8),
          Expanded(child: LocalizedText(_title)),
        ],
      ),
      content: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * .66,
        child: ListView(
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _chip('ID', id),
                if (kind == ScimResourceKind.users)
                  Chip(
                    avatar: Icon(
                      resource['active'] == false ? Icons.block : Icons.check,
                      size: 16,
                    ),
                    label: LocalizedText(
                      resource['active'] == false ? 'Inactive' : 'Active',
                    ),
                  ),
                if (version.isNotEmpty) _chip('ETag', version),
              ],
            ),
            const SizedBox(height: 12),
            if (version.isNotEmpty)
              const _ConcurrencyNotice(protected: true)
            else
              const _ConcurrencyNotice(protected: false),
            const SizedBox(height: 12),
            if (kind == ScimResourceKind.users)
              _userDetails(context)
            else
              _groupDetails(context),
            const SizedBox(height: 12),
            _metadata(context, meta),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const LocalizedText('Raw SCIM resource'),
              subtitle: const LocalizedText('Read-only expert view'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ').convert(resource),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LocalizedText('Close'),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.pop(context, ScimDetailAction.patch),
          icon: const Icon(Icons.edit_note),
          label: const LocalizedText('Patch'),
        ),
        FilledButton.tonalIcon(
          onPressed: () => Navigator.pop(context, ScimDetailAction.replace),
          icon: const Icon(Icons.sync),
          label: const LocalizedText('Replace'),
        ),
        IconButton(
          onPressed: () => Navigator.pop(context, ScimDetailAction.delete),
          icon: const Icon(Icons.delete_outline),
          color: Theme.of(context).colorScheme.error,
          tooltip: 'Delete'.localized,
        ),
      ],
    );
  }

  String get _title {
    if (kind == ScimResourceKind.users) {
      return resource['displayName']?.toString().isNotEmpty == true
          ? resource['displayName'].toString()
          : resource['userName']?.toString() ?? 'SCIM user';
    }
    return resource['displayName']?.toString() ?? 'SCIM group';
  }

  Widget _userDetails(BuildContext context) {
    final name = _map(resource['name']);
    final enterprise = _map(resource[scimEnterpriseUserSchema]);
    final manager = _map(enterprise['manager']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section(context, 'Identity'),
        _row('User name', resource['userName']),
        _row('Display name', resource['displayName']),
        _row('External ID', resource['externalId']),
        if (name.isNotEmpty) ...[
          _section(context, 'Name'),
          for (final entry in name.entries) _row(entry.key, entry.value),
        ],
        _section(context, 'Emails'),
        _objectList(resource['emails'], emptyText: 'No email addresses'),
        if (enterprise.isNotEmpty) ...[
          _section(context, 'Enterprise extension'),
          for (final entry in enterprise.entries)
            if (entry.key != 'manager') _row(entry.key, entry.value),
          if (manager.isNotEmpty)
            _row(
              'manager',
              '${manager['displayName'] ?? ''} (${manager['value'] ?? ''})',
            ),
        ],
      ],
    );
  }

  Widget _groupDetails(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(context, 'Group'),
      _row('Display name', resource['displayName']),
      _row('External ID', resource['externalId']),
      _section(context, 'Members'),
      _objectList(resource['members'], emptyText: 'No members'),
    ],
  );

  Widget _metadata(BuildContext context, Map<String, dynamic> meta) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _section(context, 'Metadata'),
      _row('Resource type', meta['resourceType']),
      _row('Created', meta['created']),
      _row('Last modified', meta['lastModified']),
      _row('Location', meta['location']),
    ],
  );

  Widget _section(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: 12, bottom: 4),
    child: LocalizedText(text, style: Theme.of(context).textTheme.titleSmall),
  );

  Widget _row(String label, Object? value) {
    final text = value?.toString() ?? '';
    if (text.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: LocalizedText(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(child: SelectableText(text)),
        ],
      ),
    );
  }

  Widget _objectList(Object? value, {required String emptyText}) {
    final items = value is List ? value.whereType<Map>().toList() : const [];
    if (items.isEmpty) return LocalizedText(emptyText);
    return Column(
      children: [
        for (final item in items)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.chevron_right),
            title: LocalizedText(
              item['value']?.toString() ??
                  item['display']?.toString() ??
                  'Item',
            ),
            subtitle: Text(
              item.entries
                  .where((entry) => entry.key != 'value')
                  .map((entry) => '${entry.key}: ${entry.value}')
                  .join(' · '),
            ),
          ),
      ],
    );
  }

  Widget _chip(String label, String value) => Chip(
    label: LocalizedText('$label: $value'),
    visualDensity: VisualDensity.compact,
  );

  static Map<String, dynamic> _map(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : const {};
}

class _ConcurrencyNotice extends StatelessWidget {
  final bool protected;

  const _ConcurrencyNotice({required this.protected});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.tertiaryContainer,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: LocalizedText(
            protected
                ? 'Replace, patch, and delete send this version with If-Match. '
                      'A concurrent change is rejected instead of overwritten.'
                : 'This response has no resource version. Writes against this '
                      'older deployment cannot use optimistic concurrency.',
          ),
        ),
      ],
    ),
  );
}
