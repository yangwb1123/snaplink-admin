part of 'forge_device_inventory_placement_evaluation_v2.dart';

List<ForgeDeviceInventoryPlacementDecisionV2> _placementV2Decisions(
  Object? value,
  ForgeDeviceInventoryPageV2 observation,
  ForgeDevicePlacementRequirements requirements,
  int evaluatedAtMS,
) {
  if (value is! List ||
      value.length > forgeDeviceInventoryPlacementEvaluationV2MaxDecisions) {
    throw const FormatException('Invalid Forge v2 placement decisions.');
  }
  final decisions = value
      .map(ForgeDeviceInventoryPlacementDecisionV2.fromJson)
      .toList(growable: false);
  final candidates = <String, ForgeDeviceInventoryCandidateV2>{
    for (final candidate in observation.devices)
      candidate.device.deviceID: candidate,
  };
  final instances = <String>{};
  for (var index = 0; index < decisions.length; index++) {
    final decision = decisions[index];
    final candidate = candidates[decision.deviceID];
    if (candidate == null ||
        candidate.instanceID != decision.instanceID ||
        candidate.revision != decision.revision ||
        candidate.generation != decision.generation ||
        candidate.heartbeatSequence != decision.heartbeatSequence ||
        candidate.device.reservationState != decision.reservationState ||
        candidate.device.gpus.length != decision.gpuCount ||
        _placementV2GpuTotal(candidate.device) !=
            decision.availableGPUMemoryBytes ||
        !instances.add(decision.instanceID)) {
      throw const FormatException(
        'Forge v2 placement decision is not bound to its observation.',
      );
    }
    _placementV2ValidateLease(candidate.device);
    final computedReasons = _placementV2ComputedReasons(
      candidate.device,
      requirements,
      evaluatedAtMS,
    );
    if (decision.matchesRequirements != computedReasons.isEmpty ||
        !_placementV2SameStrings(decision.exclusionReasons, computedReasons)) {
      throw const FormatException(
        'Forge v2 placement decision does not match the observation.',
      );
    }
    if (index > 0) {
      final previous = decisions[index - 1];
      if (_placementV2Compare(previous.deviceID, decision.deviceID) > 0 ||
          (previous.deviceID == decision.deviceID &&
              _placementV2Compare(previous.instanceID, decision.instanceID) >=
                  0)) {
        throw const FormatException(
          'Forge v2 placement decisions are unsorted.',
        );
      }
    }
  }
  if (decisions.length != observation.devices.length) {
    throw const FormatException(
      'Forge v2 placement decision set is incomplete.',
    );
  }
  return decisions;
}

void _placementV2ValidateLease(ForgeDeviceV2 device) {
  final ttl = device.leaseExpiresAtMS - device.snapshotObservedAtMS;
  if (ttl < _forgeDeviceInventoryPlacementEvaluationV2MinLeaseTTLMS ||
      ttl > _forgeDeviceInventoryPlacementEvaluationV2MaxLeaseTTLMS) {
    throw const FormatException('Invalid Forge v2 capability lease.');
  }
}

List<String> _placementV2ComputedReasons(
  ForgeDeviceV2 device,
  ForgeDevicePlacementRequirements requirements,
  int evaluatedAtMS,
) {
  final reasons = <String>[];
  switch (device.approvalState) {
    case 'pending':
      reasons.add('approval_pending');
      break;
    case 'revoked':
      reasons.add('device_revoked');
      break;
    case 'approved':
      break;
  }
  if (device.cordonState == 'cordoned') reasons.add('device_cordoned');
  if (device.liveness == 'offline') reasons.add('declared_offline');
  if (device.snapshotObservedAtMS > evaluatedAtMS) {
    reasons.add('snapshot_declared_from_future');
  } else if (evaluatedAtMS - device.snapshotObservedAtMS >
      _forgeDeviceInventoryPlacementEvaluationV2StaleAfterMS) {
    reasons.add('snapshot_stale');
  }
  if (device.leaseExpiresAtMS <= evaluatedAtMS) {
    reasons.add('declared_lease_expired');
  }
  if (device.reservationState == 'reserved') reasons.add('device_reserved');

  if (device.os != requirements.os) reasons.add('os_mismatch');
  if (device.architecture != requirements.architecture) {
    reasons.add('architecture_mismatch');
  }
  if (device.availableCPUCores < requirements.minCPUCores) {
    reasons.add('cpu_cores_insufficient');
  }
  if (device.availableMemoryBytes < requirements.minMemoryBytes) {
    reasons.add('memory_insufficient');
  }
  if (device.availableStorageBytes < requirements.minStorageBytes) {
    reasons.add('storage_insufficient');
  }
  if (!device.runtimes.contains(requirements.runtime)) {
    reasons.add('runtime_missing');
  }
  if (requirements.gpu.required) {
    if (device.gpus.isEmpty) {
      reasons.add('gpu_missing');
    } else if (device.gpus
        .where(
          (gpu) => gpu.availableMemoryBytes >= requirements.gpu.minMemoryBytes,
        )
        .isEmpty) {
      reasons.add('gpu_memory_insufficient');
    }
  }
  if (!requirements.dataResidencyZones.any(
    device.dataResidencyZones.contains,
  )) {
    reasons.add('data_residency_zone_mismatch');
  }
  final declaredTrust = _placementV2TrustRank(device.trustZone);
  final minimumTrust = _placementV2TrustRank(requirements.minimumTrustZone);
  if (declaredTrust == null) {
    reasons.add('trust_zone_unconfirmed');
  } else if (minimumTrust == null || declaredTrust < minimumTrust) {
    reasons.add('trust_zone_below_minimum');
  }
  if (!_placementV2SandboxFloorMet(
    requirements.sandboxFloor,
    device.sandboxLevels,
  )) {
    reasons.add('sandbox_floor_unmet');
  }
  if (device.activeConcurrency > device.concurrencyLimit ||
      requirements.concurrencySlots >
          device.concurrencyLimit - device.activeConcurrency) {
    reasons.add('concurrency_capacity_insufficient');
  }
  reasons.sort(_placementV2Compare);
  return reasons;
}

int? _placementV2TrustRank(String value) => switch (value) {
  'untrusted' => 0,
  'low' => 1,
  'standard' => 2,
  'high' => 3,
  'restricted' => 4,
  _ => null,
};

bool _placementV2SandboxFloorMet(String floor, List<String> declared) {
  final minimum = _placementV2SandboxRank(floor);
  if (minimum == null) return false;
  return declared.any((level) {
    final actual = _placementV2SandboxRank(level);
    return actual != null && actual >= minimum;
  });
}

int? _placementV2SandboxRank(String value) => switch (value) {
  'process' => 1,
  'container' => 2,
  'microvm' => 3,
  _ => null,
};

bool _placementV2SameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

int _placementV2GpuTotal(ForgeDeviceV2 device) {
  var total = 0;
  for (final gpu in device.gpus) {
    total += gpu.availableMemoryBytes;
    if (total > forgeDeviceInventoryPlacementEvaluationV2MaxSafeInteger) {
      throw const FormatException('Forge v2 GPU total exceeds safe integer.');
    }
  }
  return total;
}

List<String> _placementV2Reasons(Object? value) {
  const allowed = {
    'approval_pending',
    'architecture_mismatch',
    'concurrency_capacity_insufficient',
    'cpu_cores_insufficient',
    'data_residency_zone_mismatch',
    'declared_lease_expired',
    'declared_lease_invalid',
    'declared_offline',
    'device_cordoned',
    'device_reserved',
    'device_revoked',
    'gpu_memory_insufficient',
    'gpu_missing',
    'memory_insufficient',
    'os_mismatch',
    'runtime_missing',
    'sandbox_floor_unmet',
    'snapshot_declared_from_future',
    'snapshot_stale',
    'storage_insufficient',
    'trust_zone_below_minimum',
    'trust_zone_unconfirmed',
  };
  if (value is! List || value.length > 64) {
    throw const FormatException('Invalid Forge v2 placement reasons.');
  }
  final reasons = value
      .map((reason) {
        if (reason is! String || !allowed.contains(reason)) {
          throw const FormatException('Unknown Forge v2 placement reason.');
        }
        return reason;
      })
      .toList(growable: false);
  for (var index = 1; index < reasons.length; index++) {
    if (_placementV2Compare(reasons[index - 1], reasons[index]) >= 0) {
      throw const FormatException('Forge v2 placement reasons are unsorted.');
    }
  }
  return reasons;
}
