import 'package:flutter/material.dart';

import '../../api/forge_session_runner_reconciliation_projection.dart';

/// Read-only manual reconciliation projection for an uncertain terminal
/// session Runner receipt. There are no retry, target, lease, or execution
/// controls in this surface.
class ForgeSessionRunnerReconciliationProjectionPanel extends StatelessWidget {
  final ForgeSessionRunnerReconciliationProjection projection;

  const ForgeSessionRunnerReconciliationProjectionPanel({
    super.key,
    required this.projection,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey(
        'forge-session-runner-reconciliation-projection-panel',
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Session Runner reconciliation',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('Manual review · automatic retry disabled'),
            const SizedBox(height: 8),
            Text(
              'Latest attempt: ${projection.latestAttemptID} · '
              '${projection.latestDispositionKind}',
              key: const ValueKey(
                'forge-session-runner-reconciliation-projection-latest',
              ),
            ),
            Text(
              'Command: ${projection.latestCommandID} · '
              'target: ${projection.latestTargetID}',
            ),
            Text(
              'Observed: ${projection.latestObservedAtMS} ms · '
              'attempts: ${projection.source.attemptCount}',
            ),
            const SizedBox(height: 4),
            Text(
              'Reason: ${projection.reconciliationReason} · '
              'follow-up: ${projection.followUp}',
              key: const ValueKey(
                'forge-session-runner-reconciliation-projection-reason',
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Selected target: none · authority: disabled',
              key: ValueKey(
                'forge-session-runner-reconciliation-projection-boundary',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
