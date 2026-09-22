import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';

/// Receipt for the explicit candidate scheduling-review action.
///
/// The server response is intentionally shown as metadata only. A pending
/// Run-intent is not a Run and this card has no action that could select,
/// reserve, dispatch, or execute a device.
class ForgePendingRunIntentSubmissionCard extends StatelessWidget {
  final ForgePendingRunIntentSubmission submission;
  final ForgeDeviceOwner owner;

  const ForgePendingRunIntentSubmissionCard({
    super.key,
    required this.submission,
    required this.owner,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final intent = submission.intent;
    return Card(
      key: const ValueKey('forge-pending-run-intent-submission-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Scheduling review requested',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text(
              'Candidate receipt only. No Run was created, no device was selected, and no execution authority was granted.',
            ),
            const SizedBox(height: 12),
            _row('Owner', '${owner.subject} · ${owner.tenantID}'),
            _row('Conversation', intent.conversationID),
            _row('Prompt', submission.prompt.id),
            _row('Intent', intent.intentID),
            _row('Status', intent.status),
            _row('Aggregate version', '${intent.aggregateVersion}'),
            _row('Receipt', submission.replayed ? 'replayed' : 'created'),
            const _AuthorityRow(),
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
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}

class _AuthorityRow extends StatelessWidget {
  const _AuthorityRow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text('Authority')),
        Expanded(child: Text('offline · all execution flags false')),
      ],
    ),
  );
}
