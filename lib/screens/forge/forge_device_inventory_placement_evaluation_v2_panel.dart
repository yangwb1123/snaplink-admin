import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_evaluation_v2.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Renders an injected v2 placement comparison as an offline preview.
///
/// The evaluation has already been decoded and checked by the caller. This
/// widget owns no API client, reader, timer, selection callback, reservation,
/// dispatch, or execution path.
class ForgeDeviceInventoryPlacementEvaluationV2Panel extends StatelessWidget {
  final ForgeDeviceInventoryPlacementEvaluationV2 evaluation;

  const ForgeDeviceInventoryPlacementEvaluationV2Panel({
    super.key,
    required this.evaluation,
  });

  @override
  Widget build(BuildContext context) {
    final decisions =
        List<ForgeDeviceInventoryPlacementDecisionV2>.of(evaluation.decisions)
          ..sort((left, right) {
            final devices = _compareIDs(left.deviceID, right.deviceID);
            return devices == 0
                ? _compareIDs(left.instanceID, right.instanceID)
                : devices;
          });
    return Card(
      key: const ValueKey(
        'forge-device-inventory-placement-evaluation-v2-panel',
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Forge device placement evaluation v2'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Offline read-only comparison; all values are unverified and no target was selected.',
              ),
            ),
            _row(context, 'Evaluated at', '${evaluation.evaluatedAtMS}'),
            _row(
              context,
              'Eligible candidates',
              '${evaluation.eligibleCandidateCount}',
            ),
            _row(
              context,
              'Selected device',
              evaluation.selectedDeviceID ?? 'none',
            ),
            _row(
              context,
              'Selected instance',
              evaluation.selectedInstanceID ?? 'none',
            ),
            _row(context, 'Authority', 'all false · display-only'),
            const SizedBox(height: 12),
            _requirements(context, evaluation.requirements),
            const SizedBox(height: 12),
            if (decisions.isEmpty)
              Text(context.tr('No device placement decisions.'))
            else
              for (final decision in decisions)
                _decisionCard(context, decision),
          ],
        ),
      ),
    );
  }

  Widget _requirements(
    BuildContext context,
    ForgeDevicePlacementRequirements requirements,
  ) => Card(
    key: const ValueKey(
      'forge-device-inventory-placement-evaluation-v2-requirements',
    ),
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Placement requirements'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          _row(
            context,
            'OS / architecture',
            '${requirements.os} / ${requirements.architecture}',
          ),
          _row(context, 'Minimum CPU', '${requirements.minCPUCores} cores'),
          _row(context, 'Minimum memory', '${requirements.minMemoryBytes} B'),
          _row(context, 'Minimum storage', '${requirements.minStorageBytes} B'),
          _row(
            context,
            'Runtime',
            requirements.runtime.isEmpty ? 'none' : requirements.runtime,
          ),
          _row(
            context,
            'GPU',
            requirements.gpu.required
                ? '${requirements.gpu.minMemoryBytes} B${requirements.gpu.runtime.isEmpty ? '' : ' · ${requirements.gpu.runtime}'}'
                : 'not required',
          ),
          _row(
            context,
            'Residency / trust / sandbox',
            '${requirements.dataResidencyZones.join(', ')} / ${requirements.minimumTrustZone} / ${requirements.sandboxFloor}',
          ),
          _row(
            context,
            'Concurrency slots',
            '${requirements.concurrencySlots}',
          ),
        ],
      ),
    ),
  );

  Widget _decisionCard(
    BuildContext context,
    ForgeDeviceInventoryPlacementDecisionV2 decision,
  ) => Card(
    key: ValueKey(
      'forge-placement-evaluation-v2-${decision.deviceID}-${decision.instanceID}',
    ),
    margin: const EdgeInsets.only(bottom: 8),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Device: {id}', {'id': decision.deviceID}),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(context.tr('Instance: {id}', {'id': decision.instanceID})),
          _row(
            context,
            'Persisted counters',
            'revision ${decision.revision} · generation ${decision.generation} · heartbeat ${decision.heartbeatSequence}',
          ),
          _row(context, 'Reservation', decision.reservationState),
          _row(
            context,
            'GPU resources',
            '${decision.gpuCount} GPUs · ${decision.availableGPUMemoryBytes} B available memory',
          ),
          _row(
            context,
            'Matches requirements',
            '${decision.matchesRequirements}',
          ),
          _row(
            context,
            'Exclusion reasons',
            decision.exclusionReasons.isEmpty
                ? 'none'
                : decision.exclusionReasons.join(', '),
          ),
          _row(
            context,
            'Declaration status',
            'owner and device values unverified',
          ),
        ],
      ),
    ),
  );

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 150, child: Text(context.tr(label))),
        Expanded(child: SelectableText(value)),
      ],
    ),
  );

  static int _compareIDs(String left, String right) {
    final length = left.length < right.length ? left.length : right.length;
    for (var index = 0; index < length; index++) {
      final compared = left
          .codeUnitAt(index)
          .compareTo(right.codeUnitAt(index));
      if (compared != 0) return compared;
    }
    return left.length.compareTo(right.length);
  }
}
