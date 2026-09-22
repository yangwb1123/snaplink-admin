import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';

/// Read-only metadata for the owner-scoped pending Run-intent candidate.
///
/// The list projection intentionally contains no Prompt body and exposes no
/// action callback. A pending receipt is not a Run and this panel never
/// selects, reserves, dispatches, or executes work.
class ForgePendingRunIntentMetadataPanel extends StatelessWidget {
  final ForgePendingRunIntentListPage page;
  final Map<String, ForgePendingRunIntentTimelinePage> timelines;
  final Set<String> loadingTimelineIntentIDs;
  final Map<String, String> timelineErrors;
  final ValueChanged<String>? onTimelineExpanded;
  final VoidCallback? onLoadMore;
  final bool loadingMore;

  const ForgePendingRunIntentMetadataPanel({
    super.key,
    required this.page,
    this.timelines = const {},
    this.loadingTimelineIntentIDs = const {},
    this.timelineErrors = const {},
    this.onTimelineExpanded,
    this.onLoadMore,
    this.loadingMore = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      key: const ValueKey('forge-pending-run-intent-metadata-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pending Run-intent metadata',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Read-only receipt metadata. Prompt content is hidden and no Run was started.',
            ),
            const SizedBox(height: 12),
            if (page.intents.isEmpty)
              const Text('No pending Run-intent receipts for this session.')
            else
              for (final intent in page.intents) ...[
                if (intent != page.intents.first) const Divider(height: 24),
                _intent(context, intent),
              ],
            if (page.hasMore && onLoadMore != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const ValueKey('forge-pending-run-intent-load-more'),
                  onPressed: loadingMore ? null : onLoadMore,
                  child: Text(
                    loadingMore
                        ? 'Loading more pending Run-intents…'
                        : 'Load more pending Run-intents',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _intent(BuildContext context, ForgePendingRunIntentRecord intent) =>
      Column(
        key: ValueKey('forge-pending-run-intent-${intent.intentID}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row('Intent', intent.intentID),
          _row('Prompt', intent.promptID),
          _row('Project', intent.projectID),
          _row('Profile', intent.profileID),
          _row('Status', intent.status),
          _row('Aggregate version', '${intent.aggregateVersion}'),
          _row('Latest sequence', '${intent.latestSequence}'),
          _row('Initial event', 'submitted'),
          _row('Authority', 'metadata-only · all execution flags false'),
          const SizedBox(height: 8),
          _timeline(context, intent),
        ],
      );

  Widget _timeline(BuildContext context, ForgePendingRunIntentRecord intent) {
    final timeline = timelines[intent.intentID];
    final loading = loadingTimelineIntentIDs.contains(intent.intentID);
    final error = timelineErrors[intent.intentID];
    return ExpansionTile(
      key: ValueKey('forge-pending-run-intent-timeline-${intent.intentID}'),
      initiallyExpanded: timeline != null,
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 4),
      title: const Text('Timeline metadata'),
      subtitle: const Text('Expand to read payload-free event markers.'),
      onExpansionChanged: (expanded) {
        if (expanded) onTimelineExpanded?.call(intent.intentID);
      },
      children: [
        if (loading) const LinearProgressIndicator(),
        if (error != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        if (!loading && error == null && timeline == null)
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Timeline metadata is not loaded.'),
          ),
        if (timeline != null) ...[
          _row('Scanned through', '${timeline.scannedThroughSequence}'),
          for (final event in timeline.events) ...[
            const Divider(height: 16),
            _row('Event', event.eventID),
            _row('Sequence', '${event.sequence}'),
            _row('Emitted at', '${event.emittedAtMS}'),
            _row('Type', event.type),
          ],
        ],
      ],
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
