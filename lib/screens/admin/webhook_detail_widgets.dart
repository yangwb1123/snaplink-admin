import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
import 'package:sso_admin/widgets/info_row.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

class WebhookInfoCard extends StatelessWidget {
  final String subscriptionId;
  final Map<String, dynamic>? subscription;

  const WebhookInfoCard({
    super.key,
    required this.subscriptionId,
    required this.subscription,
  });

  /// The API returns the URL either as a bare string or as a map with a
  /// `url` key. Indexing a String with ['url'] would throw at runtime, so
  /// the shape is checked explicitly.
  static String _displayUrl(Object? raw) {
    if (raw is Map) {
      return raw['url']?.toString() ?? '—';
    }
    final text = raw?.toString() ?? '';
    return text.isEmpty ? '—' : text;
  }

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.webhook,
                size: 40,
                color: adminModuleIconColor(AdminModuleId.webhooks),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const LocalizedText(
                      'Webhook details',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    LocalizedText(
                      'URL: {url}',
                      args: {'url': _displayUrl(subscription?['url'])},
                    ),
                    LocalizedText(
                      'ID: {id}',
                      args: {'id': subscriptionId},
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (subscription?['active'] == true)
                StatusChip.active(label: context.tr('Active'))
              else
                StatusChip.inactive(label: context.tr('Inactive')),
            ],
          ),
          const Divider(),
          InfoRow(
            label: 'Created',
            value: formatServerTime(subscription?['created_at']),
            labelWidth: 80,
          ),
          InfoRow(
            label: 'Updated',
            value: formatServerTime(subscription?['updated_at']),
            labelWidth: 80,
          ),
        ],
      ),
    ),
  );
}

class WebhookEventsCard extends StatelessWidget {
  final Map<String, dynamic>? subscription;

  const WebhookEventsCard({super.key, required this.subscription});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Subscribed Events',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          // 空事件列表 = 订阅全部事件；API 值走 Text（X10）。
          if (_events.isEmpty)
            LocalizedText(
              'All events',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: _events
                  .map(
                    (event) => Chip(
                      label: Text(event, style: const TextStyle(fontSize: 12)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    ),
  );

  List<String> get _events {
    final events =
        subscription?['events'] ?? subscription?['event_types'] ?? const [];
    if (events is List) {
      return events.map((event) => event.toString()).toList();
    }
    if (events is Map) {
      return events.keys.map((key) => key.toString()).toList();
    }
    return const [];
  }
}

class WebhookDeadLetterSection extends StatelessWidget {
  final List<dynamic> deadLetters;
  final bool expanded;
  final bool mutating;
  final VoidCallback onToggle;
  final ValueChanged<String> onReplay;
  final VoidCallback onReplayAll;

  const WebhookDeadLetterSection({
    super.key,
    required this.deadLetters,
    required this.expanded,
    required this.mutating,
    required this.onToggle,
    required this.onReplay,
    required this.onReplayAll,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: onToggle,
            child: Row(
              children: [
                LocalizedText(
                  'Dead Letters ({count})',
                  args: {'count': deadLetters.length},
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                  color: adminModuleIconColor(AdminModuleId.webhooks),
                ),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            if (deadLetters.isEmpty)
              const EmptyState(
                variant: EmptyStateVariant.empty,
                title: 'No dead letters',
                compact: true,
              )
            else ...[
              AdminDataTable(
                density: TableDensity.compact,
                minWidth: 560,
                columns: [
                  AdminDataColumn(
                    id: 'event',
                    label: 'EVENT',
                    width: 220,
                    cardPrimary: true,
                    builder: (context, i) => TableCellText(
                      deadLetters[i]['event_type']?.toString() ?? 'Event',
                      bold: true,
                    ),
                  ),
                  AdminDataColumn(
                    id: 'error',
                    label: 'ERROR',
                    width: 300,
                    builder: (context, i) => TableCellText(
                      '${deadLetters[i]['error']?.toString() ?? ''}\n'
                      '${deadLetters[i]['failed_at']?.toString() ?? ''}',
                      muted: true,
                      maxLines: 2,
                    ),
                  ),
                  AdminDataColumn(
                    id: 'actions',
                    label: '',
                    width: 90,
                    builder: (context, i) => TextButton(
                      onPressed: mutating
                          ? null
                          : () => onReplay(
                              deadLetters[i]['id']?.toString() ?? '',
                            ),
                      child: const LocalizedText('Replay'),
                    ),
                  ),
                ],
                itemCount: deadLetters.length > 20 ? 20 : deadLetters.length,
                rowBuilder: (context, i) => const SizedBox.shrink(),
              ),
              if (deadLetters.length > 20)
                Text(
                  '+ ${deadLetters.length - 20} more',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                onPressed: mutating ? null : onReplayAll,
                child: const LocalizedText('Replay all dead letters'),
              ),
            ],
          ],
        ],
      ),
    ),
  );
}


