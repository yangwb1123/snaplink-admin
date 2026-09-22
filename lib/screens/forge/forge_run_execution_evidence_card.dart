import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_run_execution_evidence.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only presentation of content-free Run execution evidence.
///
/// This card deliberately exposes metadata and reconciliation state only. It
/// has no action callback and does not imply receipt persistence, target
/// selection, dispatch, or execution authority.
class ForgeRunExecutionEvidenceCard extends StatelessWidget {
  final ForgeRunExecutionEvidence evidence;

  const ForgeRunExecutionEvidenceCard({super.key, required this.evidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authority = evidence.authority;
    return Card(
      key: const ValueKey('forge-run-execution-evidence-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Run execution evidence preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Content-free metadata bound to this Run; it does not persist a receipt or authorize execution.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Run binding', [
              _valueRow(context, 'Conversation ID', evidence.conversationID),
              _valueRow(context, 'Prompt ID', evidence.promptID),
              _valueRow(context, 'Run ID', evidence.runID),
              _valueRow(context, 'Run status', evidence.runStatus),
              _valueRow(context, 'Owner reference', evidence.ownerRef),
            ]),
            _section(context, 'Receipt metadata', [
              _valueRow(context, 'Attempt ID', evidence.attemptID),
              _valueRow(context, 'Target declaration', evidence.targetID),
              _valueRow(context, 'Command ID', evidence.commandID),
              _valueRow(context, 'Command digest', evidence.commandSHA256),
              _valueRow(context, 'Disposition', evidence.dispositionKind),
              _valueRow(
                context,
                'Observed at (ms)',
                '${evidence.receiptObservedAtMS}',
              ),
              _valueRow(context, 'Uncertain', '${evidence.uncertain}'),
              _valueRow(
                context,
                'Reconciliation required',
                '${evidence.reconciliationRequired}',
              ),
            ]),
            _section(context, 'Authority', [
              _valueRow(
                context,
                'Metadata observed',
                '${evidence.metadataObserved}',
              ),
              _valueRow(
                context,
                'Content included',
                '${evidence.contentIncluded}',
              ),
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
                'Owner authorized',
                '${authority.ownerAuthorized}',
              ),
              _valueRow(
                context,
                'Run authoritative',
                '${authority.runAuthoritative}',
              ),
              _valueRow(
                context,
                'Receipt persisted',
                '${authority.receiptPersisted}',
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
