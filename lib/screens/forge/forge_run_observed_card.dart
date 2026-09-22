import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only presentation of the content-free `forge.run.observed.v1` value.
///
/// The card has no action callback and never treats the opaque owner reference
/// as an authenticated owner identity.
class ForgeRunObservedCard extends StatelessWidget {
  final ForgeRunObserved observation;

  const ForgeRunObservedCard({super.key, required this.observation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authority = observation.authority;
    return Card(
      key: const ValueKey('forge-run-observed-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Run metadata observation'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Content-free Run metadata; it does not establish ownership, persistence, or execution authority.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            _section(context, 'Run binding', [
              _valueRow(context, 'Conversation ID', observation.conversationID),
              _valueRow(context, 'Prompt ID', observation.promptID),
              _valueRow(context, 'Run ID', observation.runID),
              _valueRow(context, 'Run status', observation.status),
              _valueRow(
                context,
                'Created at (ms)',
                '${observation.createdAtMS}',
              ),
              _valueRow(
                context,
                'Latest sequence',
                '${observation.latestSequence}',
              ),
              _valueRow(context, 'Owner reference', observation.ownerRef),
            ]),
            _section(context, 'Observation boundary', [
              _valueRow(
                context,
                'Metadata observed',
                '${observation.metadataObserved}',
              ),
              _valueRow(
                context,
                'Content included',
                '${observation.contentIncluded}',
              ),
            ]),
            _section(context, 'Authority', [
              _valueRow(
                context,
                'Authority granted',
                '${!authority.isAllFalse}',
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
                'Persistence attested',
                '${authority.persistenceAttested}',
              ),
              _valueRow(
                context,
                'Content provenance verified',
                '${authority.contentProvenanceVerified}',
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
