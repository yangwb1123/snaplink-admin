import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import '../../api/forge_runner_dispatch_plan_preview.dart';

/// Renders a validated Runner dispatch-plan comparison without exposing an
/// action. A preview never selects, reserves, authorizes, or dispatches.
class ForgeRunnerDispatchPlanPreviewCard extends StatelessWidget {
  final ForgeRunnerDispatchPlanPreview preview;

  const ForgeRunnerDispatchPlanPreviewCard({super.key, required this.preview});

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Runner dispatch-plan preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _row('Run', preview.runID),
          _row('Attempt', '${preview.attemptID} · ${preview.attemptState}'),
          _row('Command', preview.commandID),
          _row('Target', preview.intentTargetID),
          _row(
            'Lease',
            'epoch ${preview.leaseEpoch} · ${preview.leaseActive ? 'active' : 'inactive'}',
          ),
          _row(
            'Candidates',
            '${preview.declarativeReadyCount}/${preview.candidateCount} declaratively ready',
          ),
          _row('Selected target', preview.selectedTargetID ?? 'none'),
          _row('Evaluated', '${preview.evaluatedAtMS} ms'),
          _row(
            'Authority',
            preview.authority.values.every((value) => !value)
                ? 'none issued'
                : 'invalid',
          ),
          const SizedBox(height: 8),
          const LocalizedText('Preview only · no dispatch performed'),
        ],
      ),
    ),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        SizedBox(width: 132, child: Text(label)),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
