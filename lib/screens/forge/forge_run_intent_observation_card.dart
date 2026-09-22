import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_run_intent_observation.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only presentation of a Forge prompt-to-Run observation.
///
/// The observation is already computed by a pure contract consumer. This
/// widget only renders its values: it owns no API client, clock, timer,
/// selection, reservation, Run creation, execution, or dispatch callback.
class ForgeRunIntentObservationCard extends StatelessWidget {
  final ForgeRunIntentObservation observation;

  const ForgeRunIntentObservationCard({super.key, required this.observation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final authority = observation.authority;
    return Card(
      key: const ValueKey('forge-run-intent-observation-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Run intent preview'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              context.tr(
                'Read-only observation; no Run or device is selected.',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            _section(context, 'Prompt and Run', [
              _valueRow(context, 'Conversation ID', observation.conversationID),
              _valueRow(context, 'Prompt ID', observation.promptID),
              _valueRow(context, 'Run ID', observation.runID),
              _valueRow(context, 'Run status', observation.runStatus),
              _valueRow(
                context,
                'Run sequence',
                '${observation.runLatestSequence}',
              ),
            ]),
            _section(context, 'Placement preview', [
              _valueRow(
                context,
                'Eligible instances',
                '${observation.eligibleInstanceCount}',
              ),
              _valueRow(
                context,
                'Placement decisions',
                '${observation.placementDecisionCount}',
              ),
              _valueRow(context, 'Preview only', '${observation.previewOnly}'),
              _valueRow(
                context,
                'Owner declaration unverified',
                '${observation.ownerDeclarationUnverified}',
              ),
              _valueRow(
                context,
                'Device attributes unverified',
                '${observation.deviceAttributesUnverified}',
              ),
            ]),
            _section(context, 'Authority', [
              _valueRow(
                context,
                'Authority granted',
                '${_authorityGranted(authority)}',
              ),
              _valueRow(
                context,
                'Identity verified',
                '${authority.identityVerified}',
              ),
              _valueRow(
                context,
                'Heartbeat persisted',
                '${authority.heartbeatPersisted}',
              ),
              _valueRow(
                context,
                'Inventory authoritative',
                '${authority.inventoryAuthoritative}',
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
        SizedBox(width: 190, child: Text(context.tr(label))),
        Expanded(child: Text(value)),
      ],
    ),
  );

  static bool _authorityGranted(ForgeSessionPlacementAuthority authority) =>
      authority.identityVerified &&
      authority.heartbeatPersisted &&
      authority.inventoryAuthoritative &&
      authority.reservationCreated &&
      authority.executionAuthorized &&
      authority.dispatchPerformed;
}
