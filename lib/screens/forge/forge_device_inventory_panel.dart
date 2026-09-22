import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Read-only rendering of caller-declared Forge inventory values.
///
/// [statusByDeviceInstance] uses [statusKey] and is display metadata only.
/// This widget owns no API client, clock, timer, reservation, or dispatch
/// callback.
class ForgeDeviceInventoryPanel extends StatelessWidget {
  final ForgeDeviceInventoryPage page;
  final Map<String, ForgeDeviceInventoryStatusProjection>
  statusByDeviceInstance;
  final ForgeDeviceInventorySnapshot? snapshot;
  final ForgeDevicePlacementResult? placement;
  final ForgeDeviceResourceSummary? resourceSummary;

  const ForgeDeviceInventoryPanel({
    super.key,
    required this.page,
    this.statusByDeviceInstance = const {},
    this.snapshot,
    this.placement,
    this.resourceSummary,
  });

  static String statusKey(String deviceID, String instanceID) =>
      '$deviceID::$instanceID';

  @override
  Widget build(BuildContext context) {
    final candidates = List<ForgeDeviceInventoryCandidate>.of(page.devices)
      ..sort((left, right) {
        final devices = _compareIDs(
          left.device.deviceID,
          right.device.deviceID,
        );
        return devices == 0
            ? _compareIDs(left.instanceID, right.instanceID)
            : devices;
      });
    final placementByDevice = {
      for (final result in placement?.deviceResults ?? const [])
        result.deviceID: result,
    };
    return Card(
      key: const ValueKey('forge-device-inventory-panel'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.tr('Forge device inventory'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              context.tr(
                'All values below are unverified caller declarations.',
              ),
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
            Text(
              context.tr(
                'Status projection is display-only; it does not authorize execution.',
              ),
            ),
            if (resourceSummary != null) ...[
              const SizedBox(height: 8),
              _resourceSummary(context, resourceSummary!),
            ],
            if (snapshot != null)
              Text(
                context.tr('Snapshot: {id} · rows: {count}', {
                  'id': snapshot!.snapshotID,
                  'count': '${snapshot!.rows.length}',
                }),
              ),
            const SizedBox(height: 12),
            for (final candidate in candidates)
              _deviceCard(
                context,
                candidate,
                statusByDeviceInstance[statusKey(
                  candidate.device.deviceID,
                  candidate.instanceID,
                )],
                placementByDevice[candidate.device.deviceID],
              ),
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

  Widget _resourceSummary(
    BuildContext context,
    ForgeDeviceResourceSummary summary,
  ) => Card(
    key: const ValueKey('forge-device-resource-summary'),
    margin: EdgeInsets.zero,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.tr('Declared resource aggregate'),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          Text(
            context.tr('Devices: {devices} · Runner instances: {instances}', {
              'devices': '${summary.deviceCount}',
              'instances': '${summary.runnerInstanceCount}',
            }),
          ),
          Text(
            context.tr(
              'Declared totals: CPU {cpu} · memory {memory} B · storage {storage} B',
              {
                'cpu': '${summary.availableCPUCores}',
                'memory': '${summary.availableMemoryBytes}',
                'storage': '${summary.availableStorageBytes}',
              },
            ),
          ),
          Text(
            context.tr('Declared GPUs: {count} · GPU memory {memory} B', {
              'count': '${summary.availableGPUCount}',
              'memory': '${summary.availableGPUMemoryBytes}',
            }),
          ),
          Text(
            context.tr(
              'Eligible declared devices: {devices} · instances: {instances}',
              {
                'devices': '${summary.eligibleDeviceCount}',
                'instances': '${summary.eligibleInstanceCount}',
              },
            ),
          ),
          Text(
            context.tr(
              'Totals include ineligible declarations; they are not schedulable capacity.',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _deviceCard(
    BuildContext context,
    ForgeDeviceInventoryCandidate candidate,
    ForgeDeviceInventoryStatusProjection? status,
    ForgeDevicePlacementDeviceResult? placement,
  ) {
    final device = candidate.device;
    final gpu = device.gpu.present
        ? context.tr('GPU: {memory} B · runtime {runtime}', {
            'memory': '${device.gpu.memoryBytes}',
            'runtime': device.gpu.runtime.isEmpty
                ? 'unknown'
                : device.gpu.runtime,
          })
        : context.tr('GPU: none');
    return Card(
      key: ValueKey(
        'forge-inventory-${device.deviceID}-${candidate.instanceID}',
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
                'State: approval {approval} · cordon {cordon} · liveness {liveness}',
                {
                  'approval': device.approvalState,
                  'cordon': device.cordonState,
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
            Text(gpu),
            Text(
              status == null
                  ? context.tr('Status projection: unavailable')
                  : context.tr('Status: {status} · fresh: {fresh}', {
                      'status': status.status,
                      'fresh': '${status.fresh}',
                    }),
            ),
            if (placement != null) ...[
              Text(
                context.tr('Dry-run match: {match}', {
                  'match': '${placement.matchesRequirements}',
                }),
              ),
              if (placement.exclusionReasons.isNotEmpty)
                Text(
                  context.tr('Exclusion reasons: {reasons}', {
                    'reasons': placement.exclusionReasons.join(', '),
                  }),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
