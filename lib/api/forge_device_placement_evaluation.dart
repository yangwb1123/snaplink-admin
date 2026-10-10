part of 'forge_device_placement.dart';

ForgeDevicePlacementResult dryRunForgeDevicePlacement(
  ForgeDevicePlacementRequest request,
) {
  _validatePlacementRequest(request);
  final results = request.devices
      .map((device) => _evaluatePlacementDevice(request, device))
      .toList();
  results.sort(
    (left, right) => _placementCompareIDs(left.deviceID, right.deviceID),
  );
  return ForgeDevicePlacementResult(
    schemaVersion: forgeDevicePlacementResultSchema,
    evaluationMode: forgeDevicePlacementEvaluationMode,
    evaluatedAtMS: request.evaluatedAtMS,
    owner: request.owner,
    ownerDeclarationUnverified: true,
    deviceAttributesUnverified: true,
    notice: forgeDevicePlacementNotice,
    deviceResults: List.unmodifiable(results),
    executionAuthorized: false,
    reservationCreated: false,
    dispatchPerformed: false,
  );
}

ForgeDevicePlacementDeviceResult _evaluatePlacementDevice(
  ForgeDevicePlacementRequest request,
  ForgeDeviceDeclaration device,
) {
  final reasons = <String>[];
  if (device.owner != request.owner) reasons.add('owner_mismatch');
  switch (device.approvalState) {
    case 'approved':
      break;
    case 'pending':
      reasons.add('approval_pending');
      break;
    case 'revoked':
      reasons.add('device_revoked');
      break;
    default:
      reasons.add('approval_unconfirmed');
  }
  switch (device.cordonState) {
    case 'clear':
      break;
    case 'cordoned':
      reasons.add('device_cordoned');
      break;
    default:
      reasons.add('cordon_unconfirmed');
  }
  if (device.liveness == 'offline') {
    reasons.add('declared_offline');
  } else if (device.liveness != 'online') {
    reasons.add('liveness_unconfirmed');
  }
  if (device.snapshotObservedAtMS > request.evaluatedAtMS) {
    reasons.add('snapshot_declared_from_future');
  } else if (request.evaluatedAtMS - device.snapshotObservedAtMS >
      request.maxSnapshotAgeMS) {
    reasons.add('snapshot_stale');
  }
  if (device.leaseExpiresAtMS <= request.evaluatedAtMS) {
    reasons.add('declared_lease_expired');
  }

  final required = request.requirements;
  if (device.os != required.os) reasons.add('os_mismatch');
  if (device.architecture != required.architecture) {
    reasons.add('architecture_mismatch');
  }
  if (device.availableCPUCores < required.minCPUCores) {
    reasons.add('cpu_cores_insufficient');
  }
  if (device.availableMemoryBytes < required.minMemoryBytes) {
    reasons.add('memory_insufficient');
  }
  if (device.availableStorageBytes < required.minStorageBytes) {
    reasons.add('storage_insufficient');
  }
  if (!device.runtimes.contains(required.runtime)) {
    reasons.add('runtime_missing');
  }
  if (required.gpu.required) {
    if (!device.gpu.present) {
      reasons.add('gpu_missing');
    } else {
      if (device.gpu.memoryBytes < required.gpu.minMemoryBytes) {
        reasons.add('gpu_memory_insufficient');
      }
      if (required.gpu.runtime.isNotEmpty &&
          device.gpu.runtime != required.gpu.runtime) {
        reasons.add('gpu_runtime_mismatch');
      }
    }
  }
  if (device.activeConcurrency > device.concurrencyLimit ||
      required.concurrencySlots >
          device.concurrencyLimit - device.activeConcurrency) {
    reasons.add('concurrency_capacity_insufficient');
  }
  if (!required.dataResidencyZones.any(device.dataResidencyZones.contains)) {
    reasons.add('data_residency_zone_mismatch');
  }
  final declaredTrust = _trustRank(device.trustZone);
  final minimumTrust = _trustRank(required.minimumTrustZone);
  if (declaredTrust == null) {
    reasons.add('trust_zone_unconfirmed');
  } else if (declaredTrust < minimumTrust!) {
    reasons.add('trust_zone_below_minimum');
  }
  if (!_sandboxFloorMet(required.sandboxFloor, device.sandboxLevels)) {
    reasons.add('sandbox_floor_unmet');
  }
  reasons.sort();
  return ForgeDevicePlacementDeviceResult(
    deviceID: device.deviceID,
    attributesUnverified: true,
    matchesRequirements: reasons.isEmpty,
    exclusionReasons: List.unmodifiable(reasons),
  );
}

void _validatePlacementRequest(ForgeDevicePlacementRequest request) {
  if (request.schemaVersion != forgeDevicePlacementRequestSchema ||
      request.evaluatedAtMS <= 0 ||
      request.maxSnapshotAgeMS <= 0 ||
      request.maxSnapshotAgeMS > forgeDevicePlacementMaxSnapshotAgeMS ||
      request.devices.length > forgeDevicePlacementMaxDevices ||
      request.devices.map((device) => device.deviceID).toSet().length !=
          request.devices.length) {
    throw const ForgeDevicePlacementError('invalid_request');
  }
  for (final device in request.devices) {
    if (device.deviceID.isEmpty) {
      throw const ForgeDevicePlacementError('invalid_request');
    }
  }
}

int? _trustRank(String value) => switch (value) {
  'untrusted' => 0,
  'low' => 1,
  'standard' => 2,
  'high' => 3,
  'restricted' => 4,
  _ => null,
};

bool _sandboxFloorMet(String floor, List<String> declared) {
  final minimum = _sandboxRank(floor);
  if (minimum == null) return false;
  return declared.any((level) {
    final actual = _sandboxRank(level);
    return actual != null && actual >= minimum;
  });
}

int? _sandboxRank(String value) => switch (value) {
  'process' => 1,
  'container' => 2,
  'microvm' => 3,
  _ => null,
};
