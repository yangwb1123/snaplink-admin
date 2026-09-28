import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import '../../api/forge_runner_attempt_boundary.dart';

/// Displays a validated Runner Attempt lifecycle observation. The card has no
/// transition, lease, dispatch, or Runner action.
class ForgeRunnerAttemptBoundaryCard extends StatelessWidget {
  final ForgeRunnerAttemptBoundaryObservation observation;

  const ForgeRunnerAttemptBoundaryCard({super.key, required this.observation});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-runner-attempt-boundary-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Runner Attempt boundary preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          LocalizedText(
            observation.attemptBoundaryReady
                ? 'The proposed Attempt lifecycle edge is display-only and awaits a separately reviewed effect adapter.'
                : 'The Attempt lifecycle boundary is not dispatchable.',
          ),
          const SizedBox(height: 12),
          _row(
            'Conversation / Run',
            '${observation.conversationID} / ${observation.runID}',
          ),
          _row('Attempt', observation.attemptID),
          _row(
            'Command / Target',
            '${observation.commandID} / ${observation.targetID}',
          ),
          _row('Lease epoch', '${observation.leaseEpoch}'),
          _row(
            'Lifecycle',
            '${observation.currentAttemptState} → ${observation.nextAttemptState}',
          ),
          _row(
            'Transition',
            '${observation.transition} / valid=${observation.attemptTransitionValid} / '
                'dispatchable=${observation.attemptTransitionDispatchable}',
          ),
          _row('Boundary ready', '${observation.attemptBoundaryReady}'),
          if (observation.rejectionReasons.isNotEmpty)
            _row('Reasons', observation.rejectionReasons.join(', ')),
          _row(
            'Authority',
            observation.isDisplayOnly ? 'none issued' : 'invalid',
          ),
          const SizedBox(height: 8),
          const LocalizedText(
            'Preview only · Attempt persistence, reservation, authorization, dispatch, argv execution, lease mutation, and Audit publication are absent.',
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
