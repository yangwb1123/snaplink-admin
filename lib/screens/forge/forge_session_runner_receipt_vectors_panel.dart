import 'package:flutter/material.dart';

import '../../api/forge_session_runner_receipt_vectors.dart';

/// A compact display-only projection of the three canonical session receipt
/// outcomes. No command payload, target selection, or authority is rendered.
class ForgeSessionRunnerReceiptVectorsPanel extends StatelessWidget {
  final ForgeSessionRunnerReceiptVectors fixture;

  const ForgeSessionRunnerReceiptVectorsPanel({
    super.key,
    required this.fixture,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const ValueKey('forge-session-runner-receipt-vectors-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Session Runner receipt outcomes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Offline contract · authority disabled',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final vector in fixture.vectors)
              ListTile(
                key: ValueKey(
                  'forge-session-runner-receipt-vector-${vector.name}',
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(vector.name),
                subtitle: Text(
                  '${vector.observation.receiptObservation.dispositionKind} · '
                  'observed ${vector.observation.receiptObservation.observedAtMS} ms'
                  '${vector.observation.receiptObservation.uncertain ? ' · manual reconciliation' : ''}',
                ),
                trailing: const Icon(Icons.visibility_outlined),
              ),
          ],
        ),
      ),
    );
  }
}
