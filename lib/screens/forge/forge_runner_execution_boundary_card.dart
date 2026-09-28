import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import '../../api/forge_runner_execution_boundary.dart';

/// Renders the final server-owned Runner execution-boundary preview. A ready
/// card remains display-only and never sends a command or opens a Runner.
class ForgeRunnerExecutionBoundaryCard extends StatelessWidget {
  final ForgeRunnerExecutionBoundaryObservation observation;

  const ForgeRunnerExecutionBoundaryCard({
    super.key,
    required this.observation,
  });

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-runner-execution-boundary-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Runner execution boundary preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          LocalizedText(
            observation.executionBoundaryReady
                ? 'Server-owned P4, Runner authority, lease, transport, and effect observations line up for a future reviewed adapter.'
                : 'The server-owned execution boundary is not ready.',
          ),
          const SizedBox(height: 12),
          _row(
            'Run / Attempt',
            '${observation.runID} / ${observation.attemptID}',
          ),
          _row('Attempt state', observation.attemptState),
          _row('Command', observation.commandID),
          _row('Target', observation.targetID),
          _row('Lease epoch', '${observation.leaseEpoch}'),
          _row(
            'Gates',
            '${observation.mode} / activation=${observation.activationAllowed} / '
                'authority=${observation.runnerAuthorityAccepted}',
          ),
          _row(
            'Admissions',
            'dispatch=${observation.dispatchAdmissionReady} / '
                'transport=${observation.transportAdmissionReady}',
          ),
          _row(
            'Effect',
            '${observation.effectState} / cancellation_clear=${observation.cancellationClear}',
          ),
          if (observation.rejectionReasons.isNotEmpty)
            _row('Reasons', observation.rejectionReasons.join(', ')),
          _row(
            'Authority',
            observation.isDisplayOnly ? 'none issued' : 'invalid',
          ),
          const SizedBox(height: 8),
          const LocalizedText(
            'Preview only · fencing token, argv, workspace, payload, Runner output, execution, and Audit publication are absent.',
          ),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 180, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
