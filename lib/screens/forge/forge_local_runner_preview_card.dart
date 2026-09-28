import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import '../../api/forge_local_runner_preview.dart';

/// Displays metadata from the injected local Runner readiness candidate.
/// The observation never exposes command arguments, output, fencing material,
/// or an execution action.
class ForgeLocalRunnerPreviewCard extends StatelessWidget {
  final ForgeLocalRunnerPreviewObservation observation;

  const ForgeLocalRunnerPreviewCard({super.key, required this.observation});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-local-runner-preview-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Local Runner execution-readiness preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _row('Command', observation.commandID),
          _row('Attempt', observation.attemptID),
          _row('Target', observation.targetID),
          _row('Disposition', observation.dispositionKind),
          _row('Exit code', '${observation.exitCode}'),
          _row('Output bytes', '${observation.outputBytes}'),
          _row('Observed', '${observation.observedAtMS} ms'),
          _row(
            'Authority',
            observation.authority.isOffline ? 'none issued' : 'invalid',
          ),
          const SizedBox(height: 8),
          const LocalizedText('Preview only · no execution authority granted'),
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
