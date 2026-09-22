import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only presentation of a Prompt/Run to Runner-command binding.
///
/// The card deliberately exposes metadata only. It has no target selector,
/// lease action, dispatch callback, process output, or execution affordance.
class ForgeRunnerExecutionIntentCard extends StatelessWidget {
  final ForgeRunnerExecutionIntentObservation observation;

  const ForgeRunnerExecutionIntentCard({super.key, required this.observation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authority = observation.authority;
    return Card(
      key: const ValueKey('forge-runner-execution-intent-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Runner execution intent preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Read-only binding; no target is selected and no command is executed.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _section(context, 'Prompt and Runner', [
              _valueRow(context, 'Conversation ID', observation.conversationID),
              _valueRow(context, 'Prompt ID', observation.promptID),
              _valueRow(context, 'Run ID', observation.runID),
              _valueRow(context, 'Attempt ID', observation.attemptID),
              _valueRow(context, 'Command ID', observation.commandID),
              _valueRow(context, 'Target declaration', observation.targetID),
              _valueRow(context, 'Command digest', observation.commandSHA256),
              _valueRow(context, 'Idempotency key', observation.idempotencyKey),
            ]),
            _section(context, 'Binding', [
              _valueRow(
                context,
                'Prompt/Run binding valid',
                '${observation.promptRunBindingValid}',
              ),
              _valueRow(
                context,
                'Runner command binding valid',
                '${observation.runnerCommandBindingValid}',
              ),
              _valueRow(context, 'Preview only', '${observation.previewOnly}'),
              _valueRow(
                context,
                'Selected target',
                observation.selectedTargetID ?? 'none',
              ),
            ]),
            _section(context, 'Authority', [
              _valueRow(
                context,
                'Authority granted',
                '${!authority.isOffline}',
              ),
              _valueRow(
                context,
                'Device identity verified',
                '${authority.deviceIdentityVerified}',
              ),
              _valueRow(
                context,
                'Command persisted',
                '${authority.commandPersisted}',
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
