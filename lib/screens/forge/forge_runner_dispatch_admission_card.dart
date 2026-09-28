import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import '../../api/forge_runner_dispatch_admission.dart';

/// Renders the durable lease-to-Runner admission recheck as metadata.
///
/// A ready result only means the current fenced lease and Attempt declaration
/// agree. It does not authorize a command, contact a Runner, execute work, or
/// publish an Audit fact.
class ForgeRunnerDispatchAdmissionCard extends StatelessWidget {
  final ForgeRunnerDispatchAdmission admission;

  const ForgeRunnerDispatchAdmissionCard({super.key, required this.admission});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-runner-dispatch-admission-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Runner dispatch admission preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          LocalizedText(
            admission.admissionReady
                ? 'Lease and Attempt are admissible for a later reviewed dispatch step.'
                : 'The lease-to-Runner admission recheck is not ready.',
          ),
          const SizedBox(height: 12),
          _row('Run / Attempt', '${admission.runID} / ${admission.attemptID}'),
          _row('Attempt state', admission.attemptState),
          _row('Command', admission.commandID),
          _row('Target', admission.targetID),
          _row('Lease epoch', '${admission.leaseEpoch}'),
          _row('Lease active', '${admission.leaseActive}'),
          _row('Proof current', '${admission.leaseProofCurrent}'),
          _row('Command binding', '${admission.commandBindingValid}'),
          if (admission.rejectionReasons.isNotEmpty)
            _row('Reasons', admission.rejectionReasons.join(', ')),
          _row(
            'Authority',
            admission.isDisplayOnly ? 'none issued' : 'invalid',
          ),
          const SizedBox(height: 8),
          const LocalizedText(
            'Preview only · fencing token, argv, workspace, Runner contact, execution, and Audit publication are absent.',
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
        SizedBox(width: 132, child: Text(label)),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );
}
