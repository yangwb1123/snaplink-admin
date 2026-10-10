import 'forge_device_inventory_declaration.dart';

part 'forge_device_placement_results.dart';
part 'forge_device_placement_evaluation.dart';
part 'forge_device_placement_codec.dart';

const forgeDevicePlacementRequestSchema = 'forge.device-placement-dry-run/v1';
const forgeDevicePlacementResultSchema =
    'forge.device-placement-dry-run-result/v1';
const forgeDevicePlacementEvaluationMode = 'offline_static_only';
const forgeDevicePlacementMaxDevices = 128;
const forgeDevicePlacementMaxSnapshotAgeMS = 24 * 60 * 60 * 1000;
const forgeDevicePlacementNotice =
    'All owner, approval, liveness, resource, residency, trust, and sandbox attributes are unverified caller declarations. This offline comparison selects no target and grants no execution authority.';

class ForgeDevicePlacementGpuRequirement {
  final bool required;
  final int minMemoryBytes;
  final String runtime;

  const ForgeDevicePlacementGpuRequirement({
    required this.required,
    required this.minMemoryBytes,
    required this.runtime,
  });

  factory ForgeDevicePlacementGpuRequirement.fromJson(Object? value) {
    final json = _placementObject(value);
    _placementExactKeys(json, {'required', 'min_memory_bytes', 'runtime'});
    final required = json['required'];
    if (required is! bool) {
      throw const FormatException('Invalid Forge GPU placement requirement.');
    }
    final minMemoryBytes = _placementUint64(json['min_memory_bytes']);
    final runtime = json['runtime'];
    if (runtime is! String ||
        (runtime.isNotEmpty && !_placementTokenValue(runtime))) {
      throw const FormatException('Invalid Forge GPU placement runtime.');
    }
    if (!required && (minMemoryBytes != 0 || runtime.isNotEmpty)) {
      throw const FormatException(
        'Optional Forge GPU placement requirement has resources.',
      );
    }
    return ForgeDevicePlacementGpuRequirement(
      required: required,
      minMemoryBytes: minMemoryBytes,
      runtime: runtime,
    );
  }

  Map<String, dynamic> toJson() => {
    'required': required,
    'min_memory_bytes': minMemoryBytes,
    'runtime': runtime,
  };
}

class ForgeDevicePlacementRequirements {
  final String os;
  final String architecture;
  final int minCPUCores;
  final int minMemoryBytes;
  final int minStorageBytes;
  final String runtime;
  final ForgeDevicePlacementGpuRequirement gpu;
  final List<String> dataResidencyZones;
  final String minimumTrustZone;
  final String sandboxFloor;
  final int concurrencySlots;

  const ForgeDevicePlacementRequirements({
    required this.os,
    required this.architecture,
    required this.minCPUCores,
    required this.minMemoryBytes,
    required this.minStorageBytes,
    required this.runtime,
    required this.gpu,
    required this.dataResidencyZones,
    required this.minimumTrustZone,
    required this.sandboxFloor,
    required this.concurrencySlots,
  });

  factory ForgeDevicePlacementRequirements.fromJson(Object? value) {
    final json = _placementObject(value);
    _placementExactKeys(json, {
      'os',
      'architecture',
      'min_cpu_cores',
      'min_memory_bytes',
      'min_storage_bytes',
      'runtime',
      'gpu',
      'data_residency_zones',
      'minimum_trust_zone',
      'sandbox_floor',
      'concurrency_slots',
    });
    final zones = _placementZones(json['data_residency_zones']);
    final minimumTrustZone = _placementOneOf(json['minimum_trust_zone'], {
      'untrusted',
      'low',
      'standard',
      'high',
      'restricted',
    });
    final sandboxFloor = _placementOneOf(json['sandbox_floor'], {
      'process',
      'container',
      'microvm',
    });
    return ForgeDevicePlacementRequirements(
      os: _placementToken(json['os']),
      architecture: _placementToken(json['architecture']),
      minCPUCores: _placementPositiveInt(
        json['min_cpu_cores'],
        maximum: 0xffffffff,
      ),
      minMemoryBytes: _placementPositiveInt(json['min_memory_bytes']),
      minStorageBytes: _placementPositiveInt(json['min_storage_bytes']),
      runtime: _placementToken(json['runtime']),
      gpu: ForgeDevicePlacementGpuRequirement.fromJson(json['gpu']),
      dataResidencyZones: zones,
      minimumTrustZone: minimumTrustZone,
      sandboxFloor: sandboxFloor,
      concurrencySlots: _placementPositiveInt(
        json['concurrency_slots'],
        maximum: 0xffff,
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'os': os,
    'architecture': architecture,
    'min_cpu_cores': minCPUCores,
    'min_memory_bytes': minMemoryBytes,
    'min_storage_bytes': minStorageBytes,
    'runtime': runtime,
    'gpu': gpu.toJson(),
    'data_residency_zones': dataResidencyZones,
    'minimum_trust_zone': minimumTrustZone,
    'sandbox_floor': sandboxFloor,
    'concurrency_slots': concurrencySlots,
  };
}

class ForgeDevicePlacementRequest {
  final String schemaVersion;
  final int evaluatedAtMS;
  final ForgeDeviceOwner owner;
  final int maxSnapshotAgeMS;
  final ForgeDevicePlacementRequirements requirements;
  final List<ForgeDeviceDeclaration> devices;

  const ForgeDevicePlacementRequest({
    required this.schemaVersion,
    required this.evaluatedAtMS,
    required this.owner,
    required this.maxSnapshotAgeMS,
    required this.requirements,
    required this.devices,
  });

  factory ForgeDevicePlacementRequest.fromJson(Object? value) {
    final json = _placementObject(value);
    _placementExactKeys(json, {
      'schema_version',
      'evaluated_at_ms',
      'owner',
      'max_snapshot_age_ms',
      'requirements',
      'devices',
    });
    final rawDevices = json['devices'];
    if (rawDevices is! List ||
        rawDevices.length > forgeDevicePlacementMaxDevices) {
      throw const FormatException('Invalid Forge placement devices.');
    }
    return ForgeDevicePlacementRequest(
      schemaVersion: json['schema_version'] == forgeDevicePlacementRequestSchema
          ? forgeDevicePlacementRequestSchema
          : _placementInvalid('Invalid Forge placement schema.'),
      evaluatedAtMS: _placementPositiveInt(json['evaluated_at_ms']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      maxSnapshotAgeMS: _placementPositiveInt(json['max_snapshot_age_ms']),
      requirements: ForgeDevicePlacementRequirements.fromJson(
        json['requirements'],
      ),
      devices: rawDevices
          .map(ForgeDeviceDeclaration.fromJson)
          .toList(growable: false),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluated_at_ms': evaluatedAtMS,
    'owner': owner.toJson(),
    'max_snapshot_age_ms': maxSnapshotAgeMS,
    'requirements': requirements.toJson(),
    'devices': devices.map((device) => device.toJson()).toList(growable: false),
  };
}
