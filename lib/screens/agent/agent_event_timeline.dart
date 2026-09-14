import 'package:flutter/material.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';

class AgentTimelineItem {
  final String key;
  final String label;
  final String text;
  final bool assistantMessage;
  final bool truncated;
  final Color? color;
  final Map<String, String> labelArguments;
  final DateTime? createdAt;
  final bool userMessage;

  const AgentTimelineItem({
    required this.key,
    required this.label,
    required this.text,
    this.assistantMessage = false,
    this.truncated = false,
    this.color,
    this.labelArguments = const {},
    this.createdAt,
    this.userMessage = false,
  });
}

List<AgentTimelineItem> buildAgentTimeline(Iterable<AgentSessionEvent> events) {
  final items = <AgentTimelineItem>[];
  final messageByTurn = <String, int>{};
  for (final event in events) {
    final kind = event.kind.toLowerCase();
    if (kind == 'message.delta' || kind == 'message.completed') {
      if (event.text.isEmpty) continue;
      final key = event.turnId.isEmpty ? 'event:${event.cursor}' : event.turnId;
      final existing = messageByTurn[key];
      final chunkIndex = _integer(event.payload['chunk_index']);
      if (existing == null) {
        messageByTurn[key] = items.length;
        items.add(
          AgentTimelineItem(
            key: key,
            label: 'Prompt output',
            text: event.text,
            assistantMessage: true,
            truncated: event.payload['truncated'] == true,
            createdAt: event.createdAt,
          ),
        );
      } else {
        final previous = items[existing];
        items[existing] = AgentTimelineItem(
          key: previous.key,
          label: previous.label,
          text:
              kind == 'message.completed' &&
                  (chunkIndex == null || chunkIndex == 0)
              ? event.text
              : '${previous.text}${event.text}',
          assistantMessage: true,
          truncated: previous.truncated || event.payload['truncated'] == true,
          createdAt: event.createdAt ?? previous.createdAt,
        );
      }
      continue;
    }
    if (kind == 'turn.queued') {
      if (event.text.isEmpty) continue;
      final actor = event.payload['actor']?.toString() ?? '';
      items.add(
        AgentTimelineItem(
          key: event.eventId.isNotEmpty
              ? event.eventId
              : 'cursor:${event.cursor}',
          label: actor.isEmpty
              ? 'Prompt from another device'
              : 'Prompt from {actor}',
          labelArguments: {'actor': actor},
          text: event.text,
          userMessage: true,
          createdAt: event.createdAt,
        ),
      );
      continue;
    }
    final status = _turnStatus(kind);
    final label = status?.$1 ?? 'Other event: {kind}';
    items.add(
      AgentTimelineItem(
        key: event.eventId.isNotEmpty
            ? event.eventId
            : 'cursor:${event.cursor}',
        label: label,
        text: '',
        color: status?.$2,
        labelArguments: {'kind': event.kind},
        createdAt: event.createdAt,
      ),
    );
  }
  return List.unmodifiable(items);
}

int? _integer(Object? value) => switch (value) {
  int number => number,
  num number => number.toInt(),
  String text => int.tryParse(text),
  _ => null,
};

(String, Color)? _turnStatus(String kind) => switch (kind) {
  'turn.running' => ('Turn running', AppColors.accentBlue),
  'turn.cancel_requested' => ('Cancel requested', AppColors.warning),
  'turn.completed' => ('Turn completed', AppColors.success),
  'turn.failed' => ('Turn failed', AppColors.danger),
  'turn.interrupted' => ('Turn interrupted', AppColors.warning),
  'turn.lost' => ('Turn lost', AppColors.danger),
  'turn.cancelled' => ('Turn cancelled', AppColors.warning),
  'turn.queued' => ('Turn queued', AppColors.accentBlue),
  _ => null,
};

class AgentTimelineView extends StatelessWidget {
  final List<AgentTimelineItem> items;

  const AgentTimelineView({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(context.tr('No activity yet.')));
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[items.length - index - 1];
        final background = item.assistantMessage || item.userMessage
            ? Color.alphaBlend(
                scheme.primary.withValues(alpha: 0.08),
                scheme.surfaceContainerLow,
              )
            : scheme.surfaceContainerLow;
        return Align(
          alignment: item.userMessage
              ? Alignment.centerRight
              : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: Card(
              color: background,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr(item.label, item.labelArguments),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: item.color ?? scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        MaterialLocalizations.of(context).formatTimeOfDay(
                          TimeOfDay.fromDateTime(item.createdAt!.toLocal()),
                        ),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    if (item.text.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      SelectableText(item.text),
                    ],
                    if (item.truncated) ...[
                      const SizedBox(height: 8),
                      Text(
                        context.tr('Output was truncated.'),
                        style: Theme.of(
                          context,
                        ).textTheme.labelSmall?.copyWith(color: scheme.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
