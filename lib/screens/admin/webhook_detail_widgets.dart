import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

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
              const Icon(Icons.webhook, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LocalizedText(
                      'Webhook #$subscriptionId',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    LocalizedText('URL: ${_displayUrl(subscription?['url'])}'),
                  ],
                ),
              ),
              Chip(
                label: LocalizedText(
                  subscription?['active'] == true ? 'Active' : 'Inactive',
                ),
                backgroundColor: subscription?['active'] == true
                    ? AppColors.success.withValues(alpha: 0.10)
                    : Colors.grey.shade200,
              ),
            ],
          ),
          const Divider(),
          _InfoRow(
            label: 'Created',
            value: subscription?['created_at']?.toString() ?? '—',
          ),
          _InfoRow(
            label: 'Updated',
            value: subscription?['updated_at']?.toString() ?? '—',
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
                  'Dead Letters (${deadLetters.length})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(expanded ? Icons.expand_less : Icons.expand_more),
              ],
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 8),
            if (deadLetters.isEmpty)
              const LocalizedText('No dead letters')
            else
              ...deadLetters
                  .take(20)
                  .map(
                    (deadLetter) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        color: AppColors.danger.withValues(alpha: 0.05),
                        child: ListTile(
                          title: LocalizedText(
                            deadLetter['event_type']?.toString() ?? 'Event',
                          ),
                          subtitle: LocalizedText(
                            '${deadLetter['error']?.toString() ?? ''}\n'
                            '${deadLetter['failed_at']?.toString() ?? ''}',
                          ),
                          trailing: TextButton(
                            onPressed: mutating
                                ? null
                                : () => onReplay(
                                    deadLetter['id']?.toString() ?? '',
                                  ),
                            child: const LocalizedText('Replay'),
                          ),
                        ),
                      ),
                    ),
                  ),
            if (deadLetters.length > 20)
              LocalizedText(
                '+ ${deadLetters.length - 20} more',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            if (deadLetters.isNotEmpty)
              OutlinedButton(
                onPressed: mutating ? null : onReplayAll,
                child: const LocalizedText('Replay all dead letters'),
              ),
          ],
        ],
      ),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );
}
