import 'package:flutter/material.dart';

import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';

/// Displays one accepted scheduler lease release without rendering its proof.
/// Release preserves the historical epoch and grants no execution authority.
class ForgeSchedulerSelectionLeaseReleasePanel extends StatelessWidget {
  final ForgeSchedulerSelectionLeaseRelease release;

  const ForgeSchedulerSelectionLeaseReleasePanel({
    super.key,
    required this.release,
  });

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-lease-release-panel'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Scheduler lease released',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _row('Target', '${release.deviceID}/${release.instanceID}'),
          _row('Conversation', release.conversationID),
          _row('Run / Attempt', '${release.runID} / ${release.attemptID}'),
          _row('Epoch', '${release.epoch}'),
          _row('Released at', '${release.releasedAtMS} ms'),
          _row('Replay', '${release.replayed}'),
          const SizedBox(height: 8),
          const Text(
            'The reservation is inactive; its epoch remains in durable history for fencing. Execution, Runner dispatch, and Audit publication remain disabled.',
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text('$label: $value'),
  );
}
