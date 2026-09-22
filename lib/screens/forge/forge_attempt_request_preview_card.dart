import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_attempt_request_preview.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only display of the pure Forge Attempt-request contract.
///
/// The card has no network client, persistence callback, target selector,
/// reservation action, command payload, or execution affordance. It renders
/// only normalized metadata produced by [ForgeAttemptRequestPreviewFixture].
class ForgeAttemptRequestPreviewCard extends StatelessWidget {
  final ForgeAttemptRequestPreviewFixture fixture;

  const ForgeAttemptRequestPreviewCard({super.key, required this.fixture});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accepted = fixture.cases.where((item) => item.accepted).length;
    return Card(
      key: const ValueKey('forge-attempt-request-preview-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Attempt request preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Offline display only. No references were resolved and no task was dispatched.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _section(context, 'Contract', [
              _valueRow(context, 'Schema', fixture.schemaVersion),
              _valueRow(context, 'Evaluation mode', fixture.evaluationMode),
              _valueRow(context, 'Cases', '${fixture.cases.length}'),
              _valueRow(context, 'Accepted cases', '$accepted'),
              _valueRow(
                context,
                'Rejected cases',
                '${fixture.cases.length - accepted}',
              ),
            ]),
            _section(context, 'Cases', [
              for (final item in fixture.cases) _caseRow(context, item),
            ]),
            _section(context, 'Authority', [
              _valueRow(
                context,
                'Authority granted',
                '${!fixture.authority.isOffline}',
              ),
              _valueRow(
                context,
                'Device identity verified',
                '${fixture.authority.deviceIdentityVerified}',
              ),
              _valueRow(
                context,
                'References resolved',
                '${fixture.authority.referencesResolved}',
              ),
              _valueRow(
                context,
                'Request persisted',
                '${fixture.authority.requestPersisted}',
              ),
              _valueRow(
                context,
                'Reservation created',
                '${fixture.authority.reservationCreated}',
              ),
              _valueRow(
                context,
                'Execution authorized',
                '${fixture.authority.executionAuthorized}',
              ),
              _valueRow(
                context,
                'Dispatch performed',
                '${fixture.authority.dispatchPerformed}',
              ),
              _valueRow(
                context,
                'Audit published',
                '${fixture.authority.auditPublished}',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _caseRow(
    BuildContext context,
    ForgeAttemptRequestPreviewCase item,
  ) => Card(
    key: ValueKey('forge-attempt-request-case-${item.name}'),
    margin: const EdgeInsets.symmetric(vertical: 3),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _valueRow(context, 'Case', item.name),
          _valueRow(context, 'Accepted', '${item.accepted}'),
          _valueRow(context, 'Result', item.accepted ? 'accepted' : 'rejected'),
          _valueRow(context, 'Error', item.error.isEmpty ? 'none' : item.error),
          _valueRow(context, 'Initial state', item.initialState),
          _valueRow(
            context,
            'Requested effects',
            item.requestedEffects.isEmpty
                ? 'none'
                : item.requestedEffects.join(', '),
          ),
          _valueRow(
            context,
            'Approval records',
            item.approvalRecordIDs.isEmpty
                ? 'none'
                : item.approvalRecordIDs.join(', '),
          ),
        ],
      ),
    ),
  );

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
        SizedBox(width: 190, child: Text(context.tr(label))),
        Expanded(child: Text(value)),
      ],
    ),
  );
}
