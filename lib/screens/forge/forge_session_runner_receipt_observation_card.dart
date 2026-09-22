import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only presentation of terminal Runner evidence bound to one Run.
class ForgeSessionRunnerReceiptObservationCard extends StatelessWidget {
  final ForgeSessionRunnerReceiptObservation observation;

  const ForgeSessionRunnerReceiptObservationCard({
    super.key,
    required this.observation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final receipt = observation.receiptObservation;
    final authority = observation.authority;
    return Card(
      key: const ValueKey('forge-session-runner-receipt-observation-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Session Runner receipt preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Read-only terminal evidence bound to this Run; no receipt is persisted and no target is selected.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Session binding', [
              _valueRow(context, 'Conversation ID', observation.conversationID),
              _valueRow(context, 'Prompt ID', observation.promptID),
              _valueRow(context, 'Run ID', observation.runID),
              _valueRow(
                context,
                'Prompt/Run binding valid',
                '${observation.promptRunBindingValid}',
              ),
              _valueRow(
                context,
                'Receipt binding valid',
                '${observation.receiptBindingValid}',
              ),
              _valueRow(context, 'Preview only', '${observation.previewOnly}'),
              _valueRow(
                context,
                'Selected target',
                observation.selectedTargetID ?? 'none',
              ),
            ]),
            _section(context, 'Terminal receipt', [
              _valueRow(context, 'Attempt ID', receipt.attemptID),
              _valueRow(context, 'Command ID', receipt.commandID),
              _valueRow(context, 'Target declaration', receipt.targetID),
              _valueRow(context, 'Command digest', receipt.commandSHA256),
              _valueRow(context, 'Disposition', receipt.dispositionKind),
              _valueRow(context, 'Observed at (ms)', '${receipt.observedAtMS}'),
              _valueRow(context, 'Receipt valid', '${receipt.receiptValid}'),
              _valueRow(context, 'Follow-up', receipt.followUp),
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
                'Receipt persisted',
                '${authority.receiptPersisted}',
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
