import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_evaluation.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Renders one caller-supplied persisted-inventory placement evaluation.
///
/// This is a value-only panel. It owns no API client, reader, timer, target
/// selection, reservation, dispatch, or execution callback.
class ForgeDeviceInventoryPlacementEvaluationPanel extends StatelessWidget {
  final ForgeDeviceInventoryPlacementEvaluationFixture evaluation;

  const ForgeDeviceInventoryPlacementEvaluationPanel({
    super.key,
    required this.evaluation,
  });

  @override
  Widget build(BuildContext context) {
    final expected = evaluation.expected;
    return Card(
      key: const ValueKey('forge-device-inventory-placement-evaluation-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Forge device placement evaluation'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Offline read-only comparison; all values are unverified and no target was selected.',
              ),
            ),
            _row(context, 'Source case', evaluation.sourceCase),
            _row(context, 'Evaluated at', '${evaluation.evaluatedAtMS}'),
            _row(context, 'Accepted', '${expected.accepted}'),
            if (expected.error.isNotEmpty)
              _row(context, 'Error', expected.error),
            if (expected.accepted) ...[
              _row(context, 'Persisted revision', '${expected.revision}'),
              _row(context, 'Device', expected.deviceID ?? 'none'),
              _row(context, 'Instance', expected.instanceID ?? 'none'),
              _row(
                context,
                'Matches requirements',
                '${expected.matchesRequirements}',
              ),
              _row(
                context,
                'Exclusion reasons',
                expected.exclusionReasons?.isEmpty ?? true
                    ? 'none'
                    : expected.exclusionReasons!.join(', '),
              ),
              _row(
                context,
                'Declaration status',
                'owner and device values unverified',
              ),
            ],
            _row(context, 'Authority', 'all false · display-only'),
            const SizedBox(height: 12),
            _requirements(context, evaluation.policyRequirements),
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
      'forge-device-inventory-placement-evaluation-requirements',
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
}
