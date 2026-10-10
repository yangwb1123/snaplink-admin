part of 'forge_device_inventory_v2_models.dart';

class ForgeDeviceV2 {
  final String deviceID;
  final ForgeDeviceOwner owner;
  final String approvalState;
  final String cordonState;
  final String reservationState;
  final String liveness;
  final int snapshotObservedAtMS;
  final int leaseExpiresAtMS;
  final String os;
  final String architecture;
  final int availableCPUCores;
  final int availableMemoryBytes;
  final int availableStorageBytes;
  final List<String> runtimes;
  final List<ForgeDeviceGpuV2> gpus;
  final List<String> dataResidencyZones;
  final String trustZone;
  final List<String> sandboxLevels;
  final int concurrencyLimit;
  final int activeConcurrency;

  const ForgeDeviceV2({
    required this.deviceID,
    required this.owner,
    required this.approvalState,
    required this.cordonState,
    required this.reservationState,
    required this.liveness,
    required this.snapshotObservedAtMS,
    required this.leaseExpiresAtMS,
    required this.os,
    required this.architecture,
    required this.availableCPUCores,
    required this.availableMemoryBytes,
    required this.availableStorageBytes,
    required this.runtimes,
    required this.gpus,
    required this.dataResidencyZones,
    required this.trustZone,
    required this.sandboxLevels,
    required this.concurrencyLimit,
    required this.activeConcurrency,
  });

  factory ForgeDeviceV2.fromJson(Object? value) {
    final json = _v2Object(value);
    _v2ExactKeys(json, {
      'device_id',
      'owner',
      'approval_state',
      'cordon_state',
      'reservation_state',
      'liveness',
      'snapshot_observed_at_ms',
      'lease_expires_at_ms',
      'os',
      'architecture',
      'available_cpu_cores',
      'available_memory_bytes',
      'available_storage_bytes',
      'runtimes',
      'gpus',
      'data_residency_zones',
      'trust_zone',
      'sandbox_levels',
      'concurrency_limit',
      'active_concurrency',
    });
    final rawGPUs = json['gpus'];
    if (rawGPUs is! List ||
        rawGPUs.length > _forgeDeviceInventoryV2MaxGPUCount) {
      throw const FormatException('Invalid Forge v2 GPUs.');
    }
    final gpus = rawGPUs
        .map((gpu) => ForgeDeviceGpuV2.fromJson(gpu))
        .toList(growable: false);
    for (var index = 1; index < gpus.length; index++) {
      if (_v2CompareIDs(gpus[index - 1].id, gpus[index].id) >= 0) {
        throw const FormatException('Forge v2 GPUs are unsorted.');
      }
    }
    final runtimes = _v2Tokens(
      json['runtimes'],
      _forgeDeviceInventoryV2MaxArrayItems,
    );
    final zones = _v2Tokens(
      json['data_residency_zones'],
      _forgeDeviceInventoryV2MaxArrayItems,
    );
    final sandbox = _v2EnumList(json['sandbox_levels'], {
      'process',
      'container',
      'microvm',
    });
    final snapshotObservedAt = _v2NonNegativeInt(
      json['snapshot_observed_at_ms'],
    );
    final leaseExpiresAt = _v2NonNegativeInt(json['lease_expires_at_ms']);
    final leaseTTL = leaseExpiresAt - snapshotObservedAt;
    if (leaseExpiresAt < snapshotObservedAt ||
        leaseTTL < _forgeDeviceInventoryV2MinLeaseTTLMS ||
        leaseTTL > _forgeDeviceInventoryV2MaxLeaseTTLMS ||
        zones.isNotEmpty ||
        sandbox.isNotEmpty ||
        json['concurrency_limit'] != 0 ||
        json['active_concurrency'] != 0) {
      throw const FormatException('Invalid Forge v2 device observation.');
    }
    final os = _v2LowerToken(json['os']);
    final architecture = _v2LowerToken(json['architecture']);
    return ForgeDeviceV2(
      deviceID: _v2Identifier(json['device_id']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      approvalState: _v2OneOf(json['approval_state'], {
        'approved',
        'pending',
        'revoked',
      }),
      cordonState: _v2OneOf(json['cordon_state'], {'clear', 'cordoned'}),
      reservationState: _v2OneOf(json['reservation_state'], {
        'none',
        'reserved',
      }),
      liveness: _v2OneOf(json['liveness'], {'online', 'offline'}),
      snapshotObservedAtMS: snapshotObservedAt,
      leaseExpiresAtMS: leaseExpiresAt,
      os: os,
      architecture: architecture,
      availableCPUCores: _v2BoundedInt(
        json['available_cpu_cores'],
        _forgeDeviceInventoryV2MaxCPUCores,
      ),
      availableMemoryBytes: _v2CapabilityBytes(json['available_memory_bytes']),
      availableStorageBytes: _v2CapabilityBytes(
        json['available_storage_bytes'],
      ),
      runtimes: runtimes,
      gpus: gpus,
      dataResidencyZones: zones,
      trustZone: _v2OneOf(json['trust_zone'], {'unknown'}),
      sandboxLevels: sandbox,
      concurrencyLimit: _v2BoundedInt(json['concurrency_limit'], 0xffff),
      activeConcurrency: _v2BoundedInt(json['active_concurrency'], 0xffff),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceID,
    'owner': owner.toJson(),
    'approval_state': approvalState,
    'cordon_state': cordonState,
    'reservation_state': reservationState,
    'liveness': liveness,
    'snapshot_observed_at_ms': snapshotObservedAtMS,
    'lease_expires_at_ms': leaseExpiresAtMS,
    'os': os,
    'architecture': architecture,
    'available_cpu_cores': availableCPUCores,
    'available_memory_bytes': availableMemoryBytes,
    'available_storage_bytes': availableStorageBytes,
    'runtimes': runtimes,
    'gpus': gpus.map((gpu) => gpu.toJson()).toList(),
    'data_residency_zones': dataResidencyZones,
    'trust_zone': trustZone,
    'sandbox_levels': sandboxLevels,
    'concurrency_limit': concurrencyLimit,
    'active_concurrency': activeConcurrency,
  };
}

class ForgeDeviceGpuV2 {
  final String id;
  final String vendor;
  final int memoryBytes;
  final int availableMemoryBytes;

  const ForgeDeviceGpuV2({
    required this.id,
    required this.vendor,
    required this.memoryBytes,
    required this.availableMemoryBytes,
  });

  factory ForgeDeviceGpuV2.fromJson(Object? value) {
    final json = _v2Object(value);
    _v2ExactKeys(json, {
      'id',
      'vendor',
      'memory_bytes',
      'available_memory_bytes',
    });
    final memory = _v2CapabilityBytes(json['memory_bytes']);
    final available = _v2CapabilityBytes(json['available_memory_bytes']);
    if (memory == 0 || available > memory) {
      throw const FormatException('Forge v2 GPU memory exceeds capacity.');
    }
    return ForgeDeviceGpuV2(
      id: _v2Identifier(json['id']),
      vendor: _v2Label(json['vendor']),
      memoryBytes: memory,
      availableMemoryBytes: available,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'vendor': vendor,
    'memory_bytes': memoryBytes,
    'available_memory_bytes': availableMemoryBytes,
  };
}
