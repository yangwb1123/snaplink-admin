import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:flutter/services.dart';

import 'scim_models.dart';

String formatScimBytes(int bytes) => bytes >= 1024 * 1024
    ? '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MiB'
    : bytes >= 1024
    ? '${(bytes / 1024).toStringAsFixed(1)} KiB'
    : '$bytes B';

class ScimMetric extends StatelessWidget {
  final String label;
  final String value;

  const ScimMetric({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: const Icon(Icons.analytics_outlined, size: 16),
    label: LocalizedText('$label: $value'),
  );
}

class ScimBulkResultSummary extends StatelessWidget {
  final Map<String, dynamic> result;

  const ScimBulkResultSummary({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final operations = (result['Operations'] as List? ?? const [])
        .whereType<Map>()
        .toList();
    final succeeded = operations.where((operation) {
      final status = int.tryParse(operation['status']?.toString() ?? '') ?? 0;
      return status >= 200 && status < 300;
    }).length;
    final unavailable = operations.where((operation) {
      final status = operation['status']?.toString() ?? '';
      return status == '404' || status == '501';
    }).length;
    return Card(
      child: ListTile(
        leading: Icon(
          succeeded == operations.length
              ? Icons.check_circle_outline
              : Icons.warning_amber_outlined,
          color: succeeded == operations.length ? Colors.green : Colors.orange,
        ),
        title: LocalizedText(
          '$succeeded of ${operations.length} operations succeeded',
        ),
        subtitle: LocalizedText(
          unavailable > 0
              ? '$unavailable operations returned 404/501; the target '
                    'resource family may not be enabled.'
              : operations.length == succeeded
              ? 'All reported operations completed.'
              : 'Inspect each status and response before retrying.',
        ),
      ),
    );
  }
}

class ScimQueryBar extends StatelessWidget {
  final ScimResourceKind kind;
  final TextEditingController filterController;
  final TextEditingController startIndexController;
  final int count;
  final String sortBy;
  final bool descending;
  final bool busy;
  final ValueChanged<int> onCountChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<bool> onDescendingChanged;
  final VoidCallback onApply;

  const ScimQueryBar({
    super.key,
    required this.kind,
    required this.filterController,
    required this.startIndexController,
    required this.count,
    required this.sortBy,
    required this.descending,
    required this.busy,
    required this.onCountChanged,
    required this.onSortChanged,
    required this.onDescendingChanged,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 360,
            child: TextField(
              controller: filterController,
              decoration: InputDecoration(
                labelText: 'SCIM search filter'.localized,
                hintText: kind == ScimResourceKind.users
                    ? 'userName co "alice"'
                    : 'displayName sw "ops"',
                helperText:
                    'RFC 7644 filter; blank returns all resources'.localized,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => busy ? null : onApply(),
            ),
          ),
          SizedBox(
            width: 115,
            child: TextField(
              controller: startIndexController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Start index'.localized,
                helperText: '1-based'.localized,
              ),
              onSubmitted: (_) => busy ? null : onApply(),
            ),
          ),
          SizedBox(
            width: 105,
            child: DropdownButtonFormField<int>(
              initialValue: count,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Count'.localized,
                helperText: 'Max 200'.localized,
              ),
              items: const [25, 50, 100, 200]
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: LocalizedText('$value'),
                    ),
                  )
                  .toList(),
              onChanged: busy
                  ? null
                  : (value) => onCountChanged(value ?? count),
            ),
          ),
          SizedBox(
            width: 185,
            child: DropdownButtonFormField<String>(
              initialValue: sortBy,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Sort by'.localized,
                helperText: 'Before pagination'.localized,
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: LocalizedText('Store order'),
                ),
                ...kind.sortAttributes.map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
              onChanged: busy ? null : (value) => onSortChanged(value ?? ''),
            ),
          ),
          SizedBox(
            width: 150,
            child: DropdownButtonFormField<bool>(
              initialValue: descending,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Order'.localized,
                helperText: 'Case-insensitive'.localized,
              ),
              items: const [
                DropdownMenuItem(
                  value: false,
                  child: LocalizedText('Ascending'),
                ),
                DropdownMenuItem(
                  value: true,
                  child: LocalizedText('Descending'),
                ),
              ],
              onChanged: busy
                  ? null
                  : (value) => onDescendingChanged(value ?? false),
            ),
          ),
          FilledButton.icon(
            onPressed: busy ? null : onApply,
            icon: const Icon(Icons.manage_search),
            label: const LocalizedText('Apply'),
          ),
        ],
      ),
    ),
  );
}

class ScimResourceTile extends StatelessWidget {
  final ScimResourceKind kind;
  final Map<String, dynamic> resource;
  final VoidCallback onTap;

  const ScimResourceTile({
    super.key,
    required this.kind,
    required this.resource,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final id = resource['id']?.toString() ?? '';
    final isUser = kind == ScimResourceKind.users;
    final title = isUser
        ? resource['displayName']?.toString().isNotEmpty == true
              ? resource['displayName'].toString()
              : resource['userName']?.toString() ?? id
        : resource['displayName']?.toString() ?? id;
    final details = isUser
        ? [
            resource['userName']?.toString() ?? '',
            _primaryEmail(resource['emails']),
            resource['externalId']?.toString() ?? '',
          ]
        : ['$id · ${(resource['members'] as List? ?? const []).length} members'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          child: Icon(isUser ? Icons.person_outline : Icons.groups_outlined),
        ),
        title: LocalizedText(title),
        subtitle: Text(
          details.where((value) => value.isNotEmpty).join('\n'),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        isThreeLine: isUser,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isUser)
              Tooltip(
                message: resource['active'] == false ? 'Inactive' : 'Active',
                child: Icon(
                  resource['active'] == false
                      ? Icons.block
                      : Icons.check_circle_outline,
                  color: resource['active'] == false
                      ? Theme.of(context).colorScheme.error
                      : Colors.green,
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }

  static String _primaryEmail(Object? value) {
    if (value is! List) return '';
    final emails = value.whereType<Map>().toList();
    if (emails.isEmpty) return '';
    final primary = emails
        .where((email) => email['primary'] == true)
        .firstOrNull;
    return (primary ?? emails.first)['value']?.toString() ?? '';
  }
}

class ScimPager extends StatelessWidget {
  final ScimListPage page;
  final bool busy;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const ScimPager({
    super.key,
    required this.page,
    required this.busy,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final last = page.itemsPerPage == 0
        ? page.startIndex
        : page.startIndex + page.itemsPerPage - 1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        LocalizedText(
          page.totalResults == 0
              ? '0 results'
              : '${page.startIndex}–$last of ${page.totalResults}',
        ),
        IconButton(
          onPressed: page.hasPrevious && !busy ? onPrevious : null,
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous page'.localized,
        ),
        IconButton(
          onPressed: page.hasNext && !busy ? onNext : null,
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next page'.localized,
        ),
      ],
    );
  }
}

class ScimUnavailable extends StatelessWidget {
  final ScimResourceKind? kind;
  final VoidCallback onRetry;

  const ScimUnavailable({super.key, this.kind, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.extension_off_outlined, size: 48),
          const SizedBox(height: 12),
          LocalizedText(
            kind == ScimResourceKind.groups
                ? 'SCIM Groups are not enabled'
                : 'SCIM is not enabled on this replica',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          LocalizedText(
            kind == ScimResourceKind.groups
                ? 'Groups require scim.groups.enabled and a permissions provider.'
                : 'The server returned 404 or 501 for this SCIM surface.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const LocalizedText('Probe again'),
          ),
        ],
      ),
    ),
  );
}
