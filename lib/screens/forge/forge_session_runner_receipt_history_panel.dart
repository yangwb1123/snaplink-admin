import 'package:flutter/material.dart';

import '../../api/forge_session_runner_receipt_history.dart';

/// Read-only projection of a bounded session Runner receipt history.
///
/// The panel intentionally exposes receipt metadata and the terminal summary
/// only. It has no action that can retry a command, select a target, or write
/// a receipt.
class ForgeSessionRunnerReceiptHistoryPanel extends StatelessWidget {
  final ForgeSessionRunnerReceiptHistory history;

  const ForgeSessionRunnerReceiptHistoryPanel({
    super.key,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final latest = history.receipts.last.receiptObservation;
    return Card(
      key: const ValueKey('forge-session-runner-receipt-history-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Session Runner receipt history',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Offline history · authority disabled',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Attempts: ${history.attemptCount} · latest: ${latest.dispositionKind} · '
              '${latest.observedAtMS} ms',
              key: const ValueKey(
                'forge-session-runner-receipt-history-summary',
              ),
            ),
            if (history.hasUncertainTerminal) ...[
              const SizedBox(height: 4),
              Text(
                'Manual reconciliation required; automatic retry disabled.',
                key: const ValueKey(
                  'forge-session-runner-receipt-history-manual-reconciliation',
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 8),
            for (final receipt in history.receipts)
              ListTile(
                key: ValueKey(
                  'forge-session-runner-receipt-history-${receipt.receiptObservation.attemptID}',
                ),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(
                  '${receipt.receiptObservation.attemptID} · '
                  '${receipt.receiptObservation.dispositionKind}',
                ),
                subtitle: Text(
                  '${receipt.receiptObservation.commandID} → '
                  '${receipt.receiptObservation.targetID} · '
                  '${receipt.receiptObservation.observedAtMS} ms'
                  '${receipt.receiptObservation.uncertain ? ' · manual reconciliation' : ''}',
                ),
                trailing: const Icon(Icons.history),
              ),
          ],
        ),
      ),
    );
  }
}
