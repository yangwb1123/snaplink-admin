import 'package:flutter/material.dart';

class WebhookInfoCard extends StatelessWidget {
  final String subscriptionId;
  final Map<String, dynamic>? subscription;

  const WebhookInfoCard({
    super.key,
    required this.subscriptionId,
    required this.subscription,
  });

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
                    Text(
                      'Webhook #$subscriptionId',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'URL: '
                      '${subscription?['url']?['url'] ?? subscription?['url'] ?? '—'}',
                    ),
                  ],
                ),
              ),
              Chip(
                label: Text(
                  subscription?['active'] == true ? 'Active' : 'Inactive',
                ),
                backgroundColor: subscription?['active'] == true
                    ? Colors.green.shade100
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
          Text(
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
                Text(
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
              const Text('No dead letters')
            else
              ...deadLetters
                  .take(20)
                  .map(
                    (deadLetter) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Card(
                        color: Colors.red.shade50,
                        child: ListTile(
                          title: Text(
                            deadLetter['event_type']?.toString() ?? 'Event',
                          ),
                          subtitle: Text(
                            '${deadLetter['error']?.toString() ?? ''}\n'
                            '${deadLetter['failed_at']?.toString() ?? ''}',
                          ),
                          trailing: TextButton(
                            onPressed: mutating
                                ? null
                                : () => onReplay(
                                    deadLetter['id']?.toString() ?? '',
                                  ),
                            child: const Text('Replay'),
                          ),
                        ),
                      ),
                    ),
                  ),
            if (deadLetters.length > 20)
              Text(
                '+ ${deadLetters.length - 20} more',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            if (deadLetters.isNotEmpty)
              OutlinedButton(
                onPressed: mutating ? null : onReplayAll,
                child: const Text('Replay all dead letters'),
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
