import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_batch_evaluation.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Renders one caller-supplied persisted-inventory placement batch evaluation.
///
/// This panel is deliberately a value-only surface. It owns no API client,
/// reader, timer, target selection, reservation, dispatch, or execution
/// callback. The caller must decode the canonical envelope before passing it
/// here; the model itself requires null selection and all-false authority.
class ForgeDeviceInventoryPlacementBatchEvaluationPanel
    extends StatelessWidget {
  final ForgeDeviceInventoryPlacementBatchEvaluationFixture evaluation;

  const ForgeDeviceInventoryPlacementBatchEvaluationPanel({
    super.key,
    required this.evaluation,
  });

  @override
  Widget build(BuildContext context) {
    final decisions = List<ForgeDeviceInventoryPlacementBatchCase>.of(
      evaluation.cases,
    )..sort((left, right) => _compareIDs(left.deviceID, right.deviceID));
    final matching = decisions
        .where((item) => item.expected.matchesRequirements)
        .length;
    return Card(
      key: const ValueKey(
        'forge-device-inventory-placement-batch-evaluation-panel',
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Forge device placement batch evaluation'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Offline read-only batch comparison; all values are unverified and no target was selected.',
              ),
            ),
            _row(context, 'Evaluated at', '${evaluation.evaluatedAtMS}'),
            _row(context, 'Candidates', '${decisions.length}'),
            _row(context, 'Matching candidates', '$matching'),
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
              Text(context.tr('No device placement batch decisions.'))
            else
              for (final item in decisions) _decisionCard(context, item),
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
      'forge-device-inventory-placement-batch-evaluation-requirements',
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
    ForgeDeviceInventoryPlacementBatchCase item,
  ) {
    final decision = item.expected;
    return Card(
      key: ValueKey(
        'forge-placement-batch-${item.deviceID}-${item.instanceID}',
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Device: {id}', {'id': item.deviceID}),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(context.tr('Instance: {id}', {'id': item.instanceID})),
            _row(context, 'Case', item.name),
            _row(context, 'Persisted revision', '${decision.revision}'),
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
  }

  Widget _row(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(width: 160, child: Text(context.tr(label))),
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
