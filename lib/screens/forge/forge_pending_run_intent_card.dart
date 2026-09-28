import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';

/// Read-only rendering of a pending Run-intent receipt.
///
/// The card intentionally omits Prompt content and has no callback that can
/// create a Run, select a device, reserve capacity, or dispatch work.
class ForgePendingRunIntentCard extends StatelessWidget {
  final ForgePendingRunIntentFixture fixture;

  const ForgePendingRunIntentCard({super.key, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final submission = fixture.submission;
    final intent = submission.intent;
    return Card(
      key: const ValueKey('forge-pending-run-intent-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LocalizedText(
              'Pending Run-intent preview',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const LocalizedText(
              'Receipt only. No Run was created and no device was selected.',
            ),
            const SizedBox(height: 12),
            _row(
              'Owner',
              '${fixture.owner.subject} · ${fixture.owner.tenantID}',
            ),
            _row('Conversation', fixture.conversationID),
            _row('Prompt', submission.prompt.id),
            _row('Intent', intent.intentID),
            _row('Project', intent.projectID),
            _row('Status', intent.status),
            _row('Aggregate version', '${intent.aggregateVersion}'),
            _row(
              'Timeline sequence',
              '${fixture.timeline.scannedThroughSequence}',
            ),
            _row('Initial event', submission.initialEvent.type),
            _row(
              'Authority',
              fixture.authority.isOffline ? 'offline' : 'invalid',
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
