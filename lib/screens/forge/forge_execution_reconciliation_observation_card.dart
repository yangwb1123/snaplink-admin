import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only presentation of a restart-boundary execution reconciliation
/// observation. The card does not turn a classification into a retry,
/// scheduling, lease, or execution action.
class ForgeExecutionReconciliationObservationCard extends StatelessWidget {
  final ForgeExecutionReconciliationObservation observation;

  const ForgeExecutionReconciliationObservationCard({
    super.key,
    required this.observation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authority = observation.authority;
    return Card(
      key: const ValueKey('forge-execution-reconciliation-observation-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Execution reconciliation preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Read-only restart-boundary classification; it does not retry, select a target, or grant execution authority.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Run binding', [
              _valueRow(context, 'Conversation ID', observation.conversationID),
              _valueRow(context, 'Run ID', observation.runID),
              _valueRow(context, 'Attempt ID', observation.attemptID),
              _valueRow(context, 'Command ID', observation.commandID),
              _valueRow(context, 'Target ID', observation.targetID),
              _valueRow(context, 'Run status', observation.runStatus),
              _valueRow(context, 'Attempt state', observation.attemptState),
            ]),
            _section(context, 'Lease and terminal evidence', [
              _valueRow(context, 'Lease epoch', '${observation.leaseEpoch}'),
              _valueRow(context, 'Lease active', '${observation.leaseActive}'),
              _valueRow(
                context,
                'Observed at (ms)',
                '${observation.observedAtMS}',
              ),
              _valueRow(
                context,
                'Terminal observed',
                '${observation.terminalObserved}',
              ),
              _valueRow(
                context,
                'Terminal disposition',
                observation.terminalDisposition,
              ),
              _valueRow(
                context,
                'Terminal state aligned',
                '${observation.terminalStateAligned}',
              ),
            ]),
            _section(context, 'Classification', [
              _valueRow(
                context,
                'Next observation',
                observation.nextObservation,
              ),
              _valueRow(
                context,
                'Reconciliation required',
                '${observation.reconciliationRequired}',
              ),
              _valueRow(
                context,
                'Manual review required',
                '${observation.manualReviewRequired}',
              ),
              _valueRow(
                context,
                'Automatic retry',
                '${observation.automaticRetry}',
              ),
              _valueRow(context, 'Preview only', '${observation.previewOnly}'),
            ]),
            _section(context, 'Authority', [
              _valueRow(
                context,
                'Authority granted',
                '${!authority.isOffline}',
              ),
              _valueRow(
                context,
                'Identity verified',
                '${authority.identityVerified}',
              ),
              _valueRow(
                context,
                'Run authoritative',
                '${authority.runAuthoritative}',
              ),
              _valueRow(
                context,
                'Attempt persisted',
                '${authority.attemptPersisted}',
              ),
              _valueRow(context, 'Lease issued', '${authority.leaseIssued}'),
              _valueRow(
                context,
                'Terminal persisted',
                '${authority.terminalPersisted}',
              ),
              _valueRow(
                context,
                'Reservation created',
                '${authority.reservationCreated}',
              ),
              _valueRow(
                context,
                'Execution authorized',
                '${authority.executionAuthorized}',
              ),
              _valueRow(
                context,
                'Dispatch performed',
                '${authority.dispatchPerformed}',
              ),
              _valueRow(
                context,
                'Audit published',
                '${authority.auditPublished}',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, String title, List<Widget> children) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr(title),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            ...children,
          ],
        ),
      );

  Widget _valueRow(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 210, child: Text(context.tr(label))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
