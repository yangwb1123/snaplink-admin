import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';

/// Displays one accepted scheduler lease without rendering its fencing token.
/// A lease reserves a target; it does not authorize command execution or
/// Runner dispatch.
class ForgeSchedulerSelectionLeasePanel extends StatelessWidget {
  final ForgeSchedulerSelectionLease lease;

  const ForgeSchedulerSelectionLeasePanel({super.key, required this.lease});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-scheduler-selection-lease-panel'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Scheduler lease',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _row('Target', '${lease.deviceID}/${lease.instanceID}'),
          _row('Conversation', lease.conversationID),
          _row('Run / Attempt', '${lease.runID} / ${lease.attemptID}'),
          _row('Inventory revision', '${lease.inventoryRevision}'),
          _row(
            'Generation / heartbeat',
            '${lease.generation} / ${lease.heartbeatSequence}',
          ),
          _row('Epoch', '${lease.grant.epoch}'),
          _row(
            'Window',
            '${lease.grant.issuedAtMS}–${lease.grant.expiresAtMS} ms',
          ),
          _row('Replay', '${lease.replayed}'),
          const SizedBox(height: 8),
          const LocalizedText(
            'Lease issued; command execution, Runner dispatch, and Audit publication remain disabled. The fencing token is withheld from this view.',
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
