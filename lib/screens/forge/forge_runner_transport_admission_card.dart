import 'package:flutter/material.dart';

import '../../api/forge_runner_transport_admission.dart';

/// Renders the value-only join between a verified transport observation and a
/// fenced command/lease admission. It never opens a Runner connection or
/// sends payload bytes.
class ForgeRunnerTransportAdmissionCard extends StatelessWidget {
  final ForgeRunnerTransportAdmission admission;

  const ForgeRunnerTransportAdmissionCard({super.key, required this.admission});

  @override
  Widget build(BuildContext context) => Card(
    key: const ValueKey('forge-runner-transport-admission-card'),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Runner transport admission preview',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            admission.admissionReady
                ? 'The verified transport observation matches the current fenced lease and Attempt.'
                : 'The transport-to-lease admission recheck is not ready.',
          ),
          const SizedBox(height: 12),
          _row('Run / Attempt', '${admission.runID} / ${admission.attemptID}'),
          _row('Attempt state', admission.attemptState),
          _row('Command', admission.commandID),
          _row('Target', admission.targetID),
          _row('Lease epoch', '${admission.leaseEpoch}'),
          _row(
            'Transport',
            '${admission.transportMethod} ${admission.transportPath}',
          ),
          _row('Payload bytes', '${admission.transportPayloadBytes}'),
          _row('Transport binding', '${admission.transportBindingValid}'),
          _row('Replay checked', '${admission.transportReplayChecked}'),
          if (admission.rejectionReasons.isNotEmpty)
            _row('Reasons', admission.rejectionReasons.join(', ')),
          _row(
            'Authority',
            admission.isDisplayOnly ? 'none issued' : 'invalid',
          ),
          const SizedBox(height: 8),
          const Text(
            'Preview only · no device authentication, Runner contact, payload send, execution, or Audit publication.',
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
