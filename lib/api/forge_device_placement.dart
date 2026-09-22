import 'forge_device_inventory_declaration.dart';

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

class ForgeDevicePlacementDeviceResult {
  final String deviceID;
  final bool attributesUnverified;
  final bool matchesRequirements;
  final List<String> exclusionReasons;

  const ForgeDevicePlacementDeviceResult({
    required this.deviceID,
    required this.attributesUnverified,
    required this.matchesRequirements,
    required this.exclusionReasons,
  });

  factory ForgeDevicePlacementDeviceResult.fromJson(Object? value) {
    final json = _placementObject(value);
    _placementExactKeys(json, {
      'device_id',
      'attributes_unverified',
      'matches_requirements',
      'exclusion_reasons',
    });
    final attributesUnverified = json['attributes_unverified'];
    final matchesRequirements = json['matches_requirements'];
    if (attributesUnverified is! bool ||
        !attributesUnverified ||
        matchesRequirements is! bool) {
      throw const FormatException('Invalid Forge placement result flags.');
    }
    final rawReasons = json['exclusion_reasons'];
    if (rawReasons is! List || rawReasons.length > 64) {
      throw const FormatException('Invalid Forge placement result reasons.');
    }
    final reasons = rawReasons.map(_placementToken).toList(growable: false);
    for (var index = 1; index < reasons.length; index++) {
      if (_placementCompareIDs(reasons[index - 1], reasons[index]) >= 0) {
        throw const FormatException('Unsorted Forge placement reasons.');
      }
    }
    if (matchesRequirements != reasons.isEmpty) {
      throw const FormatException('Inconsistent Forge placement result.');
    }
    return ForgeDevicePlacementDeviceResult(
      deviceID: _placementIdentifier(json['device_id']),
      attributesUnverified: true,
      matchesRequirements: matchesRequirements,
      exclusionReasons: List.unmodifiable(reasons),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceID,
    'attributes_unverified': attributesUnverified,
    'matches_requirements': matchesRequirements,
    'exclusion_reasons': exclusionReasons,
  };
}

class ForgeDevicePlacementResult {
  final String schemaVersion;
  final String evaluationMode;
  final int evaluatedAtMS;
  final ForgeDeviceOwner owner;
  final bool ownerDeclarationUnverified;
  final bool deviceAttributesUnverified;
  final String notice;
  final List<ForgeDevicePlacementDeviceResult> deviceResults;
  final bool executionAuthorized;
  final bool reservationCreated;
  final bool dispatchPerformed;

  const ForgeDevicePlacementResult({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.evaluatedAtMS,
    required this.owner,
    required this.ownerDeclarationUnverified,
    required this.deviceAttributesUnverified,
    required this.notice,
    required this.deviceResults,
    required this.executionAuthorized,
    required this.reservationCreated,
    required this.dispatchPerformed,
  });

  factory ForgeDevicePlacementResult.fromJson(Object? value) {
    final json = _placementObject(value);
    _placementExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'evaluated_at_ms',
      'owner_declaration',
      'owner_declaration_unverified',
      'device_attributes_unverified',
      'notice',
      'device_results',
      'execution_authorized',
      'reservation_created',
      'dispatch_performed',
    });
    if (json['schema_version'] != forgeDevicePlacementResultSchema ||
        json['evaluation_mode'] != forgeDevicePlacementEvaluationMode ||
        json['notice'] != forgeDevicePlacementNotice) {
      throw const FormatException('Invalid Forge placement result schema.');
    }
    final ownerDeclarationUnverified = json['owner_declaration_unverified'];
    final deviceAttributesUnverified = json['device_attributes_unverified'];
    final executionAuthorized = json['execution_authorized'];
    final reservationCreated = json['reservation_created'];
    final dispatchPerformed = json['dispatch_performed'];
    if (ownerDeclarationUnverified is! bool ||
        !ownerDeclarationUnverified ||
        deviceAttributesUnverified is! bool ||
        !deviceAttributesUnverified ||
        executionAuthorized is! bool ||
        executionAuthorized ||
        reservationCreated is! bool ||
        reservationCreated ||
        dispatchPerformed is! bool ||
        dispatchPerformed) {
      throw const FormatException('Forge placement result claims authority.');
    }
    final rawResults = json['device_results'];
    if (rawResults is! List ||
        rawResults.length > forgeDevicePlacementMaxDevices) {
      throw const FormatException('Invalid Forge placement result devices.');
    }
    final results = rawResults
        .map(ForgeDevicePlacementDeviceResult.fromJson)
        .toList(growable: false);
    for (var index = 1; index < results.length; index++) {
      if (_placementCompareIDs(
            results[index - 1].deviceID,
            results[index].deviceID,
          ) >=
          0) {
        throw const FormatException('Unsorted Forge placement results.');
      }
    }
    return ForgeDevicePlacementResult(
      schemaVersion: forgeDevicePlacementResultSchema,
      evaluationMode: forgeDevicePlacementEvaluationMode,
      evaluatedAtMS: _placementPositiveInt(json['evaluated_at_ms']),
      owner: ForgeDeviceOwner.fromJson(json['owner_declaration']),
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
      notice: forgeDevicePlacementNotice,
      deviceResults: List.unmodifiable(results),
      executionAuthorized: false,
      reservationCreated: false,
      dispatchPerformed: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'evaluated_at_ms': evaluatedAtMS,
    'owner_declaration': {
      'issuer': owner.issuer,
      'subject': owner.subject,
      'tenant_id': owner.tenantID,
    },
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'device_attributes_unverified': deviceAttributesUnverified,
    'notice': notice,
    'device_results': deviceResults.map((result) => result.toJson()).toList(),
    'execution_authorized': executionAuthorized,
    'reservation_created': reservationCreated,
    'dispatch_performed': dispatchPerformed,
  };
}

class ForgeDevicePlacementError implements Exception {
  final String code;

  const ForgeDevicePlacementError(this.code);
}

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

Map<String, dynamic> _placementObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _placementExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge placement fields.');
  }
}

String _placementInvalid(String message) {
  throw FormatException(message);
}

String _placementToken(Object? value) {
  if (value is! String || !_placementTokenValue(value)) {
    throw const FormatException('Invalid Forge placement token.');
  }
  return value;
}

String _placementIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_placementIdentifierValue(value)) {
    throw const FormatException('Invalid Forge placement identifier.');
  }
  return value;
}

bool _placementIdentifierValue(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) || const [0x2e, 0x5f, 0x3a, 0x2d].contains(code);
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

bool _placementTokenValue(String value) {
  if (value.isEmpty || value.length > 128) return false;
  return value.codeUnits.every(
    (code) =>
        code >= 0x30 && code <= 0x39 ||
        code >= 0x41 && code <= 0x5a ||
        code >= 0x61 && code <= 0x7a ||
        const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
  );
}

String _placementOneOf(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('Invalid Forge placement enum.');
  }
  return value;
}

List<String> _placementZones(Object? value) {
  if (value is! List || value.isEmpty || value.length > 32) {
    throw const FormatException('Invalid Forge placement zones.');
  }
  final zones = value
      .map((item) {
        if (item is! String ||
            item.isEmpty ||
            item.length > 64 ||
            !item.codeUnits.every(
              (code) =>
                  code >= 0x30 && code <= 0x39 ||
                  code >= 0x41 && code <= 0x5a ||
                  code >= 0x61 && code <= 0x7a ||
                  const [0x2e, 0x5f, 0x2d].contains(code),
            )) {
          throw const FormatException('Invalid Forge placement zone.');
        }
        return item;
      })
      .toList(growable: false);
  if (zones.toSet().length != zones.length) {
    throw const FormatException('Duplicate Forge placement zones.');
  }
  return zones;
}

int _placementPositiveInt(Object? value, {int maximum = 9007199254740991}) {
  final result = _placementUint64(value);
  if (result == 0 || result > maximum) {
    throw const FormatException('Expected positive Forge placement integer.');
  }
  return result;
}

int _placementUint64(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw const FormatException('Invalid Forge placement integer.');
  }
  return value;
}

int _placementCompareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
