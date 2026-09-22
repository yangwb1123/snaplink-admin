import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Renders a lossless v2 inventory observation supplied by the caller.
///
/// The panel has no reader, timer, selection callback, reservation action, or
/// dispatch path. The v2 model is decoded before it reaches this widget and
/// remains an unverified, offline-only observation.
class ForgeDeviceInventoryV2Panel extends StatelessWidget {
  final ForgeDeviceInventoryPageV2 page;

  const ForgeDeviceInventoryV2Panel({super.key, required this.page});

  @override
  Widget build(BuildContext context) {
    final candidates = List<ForgeDeviceInventoryCandidateV2>.of(page.devices)
      ..sort((left, right) {
        final devices = _compareIDs(
          left.device.deviceID,
          right.device.deviceID,
        );
        return devices == 0
            ? _compareIDs(left.instanceID, right.instanceID)
            : devices;
      });
    return Card(
      key: const ValueKey('forge-device-inventory-v2-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Forge device inventory observation v2'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'Offline persisted observation; all values are unverified and read-only.',
              ),
            ),
            Text(
              context.tr('Evaluated at: {time} · devices: {count}', {
                'time': '${page.evaluatedAtMS}',
                'count': '${page.devices.length}',
              }),
            ),
            Text(
              context.tr('Owner declaration unverified: {value}', {
                'value': '${page.ownerDeclarationUnverified}',
              }),
            ),
            Text(
              context.tr('Inventory declarations unverified: {value}', {
                'value': '${page.inventoryDeclarationsUnverified}',
              }),
            ),
            Text(
              context.tr('Execution authorized: {value}', {
                'value': '${page.executionAuthorized}',
              }),
            ),
            Text(
              context.tr('Reservation created: {value}', {
                'value': '${page.reservationCreated}',
              }),
            ),
            Text(
              context.tr('Dispatch performed: {value}', {
                'value': '${page.dispatchPerformed}',
              }),
            ),
            const SizedBox(height: 12),
            for (final candidate in candidates)
              _candidateCard(context, candidate),
          ],
        ),
      ),
    );
  }

  Widget _candidateCard(
    BuildContext context,
    ForgeDeviceInventoryCandidateV2 candidate,
  ) {
    final device = candidate.device;
    return Card(
      key: ValueKey(
        'forge-inventory-v2-${device.deviceID}-${candidate.instanceID}',
      ),
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Device: {id}', {'id': device.deviceID}),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(context.tr('Instance: {id}', {'id': candidate.instanceID})),
            Text(
              context.tr(
                'Persisted counters: revision {revision} · generation {generation} · heartbeat {heartbeat}',
                {
                  'revision': '${candidate.revision}',
                  'generation': '${candidate.generation}',
                  'heartbeat': '${candidate.heartbeatSequence}',
                },
              ),
            ),
            Text(
              context.tr(
                'State: approval {approval} · cordon {cordon} · reservation {reservation} · liveness {liveness}',
                {
                  'approval': device.approvalState,
                  'cordon': device.cordonState,
                  'reservation': device.reservationState,
                  'liveness': device.liveness,
                },
              ),
            ),
            Text(
              context.tr(
                'Resources: CPU {cpu} · memory {memory} B · storage {storage} B',
                {
                  'cpu': '${device.availableCPUCores}',
                  'memory': '${device.availableMemoryBytes}',
                  'storage': '${device.availableStorageBytes}',
                },
              ),
            ),
            Text(
              context.tr('Runtimes: {runtimes}', {
                'runtimes': device.runtimes.isEmpty
                    ? 'none'
                    : device.runtimes.join(', '),
              }),
            ),
            Text(
              context.tr('Concurrency: {active} active / {limit} limit', {
                'active': '${device.activeConcurrency}',
                'limit': '${device.concurrencyLimit}',
              }),
            ),
            if (device.gpus.isEmpty)
              Text(context.tr('GPUs: none'))
            else ...[
              Text(
                context.tr('GPUs: {count}', {'count': '${device.gpus.length}'}),
              ),
              for (final gpu in device.gpus)
                Text(
                  context.tr(
                    'GPU {id}: {vendor} · memory {memory} B · available {available} B',
                    {
                      'id': gpu.id,
                      'vendor': gpu.vendor,
                      'memory': '${gpu.memoryBytes}',
                      'available': '${gpu.availableMemoryBytes}',
                    },
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

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
