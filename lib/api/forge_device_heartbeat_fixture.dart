part of 'forge_device_heartbeat.dart';

const _forgeHeartbeatMaxCPUCoreCount = 4096;
final _forgeHeartbeatMaxCapabilityBytes = BigInt.one << 60;
const _forgeHeartbeatMaxGPUCount = 32;
const _forgeHeartbeatMaxRuntimeCount = 64;
const _forgeHeartbeatMaxRuntimeNameBytes = 64;

class ForgeDeviceHeartbeatReferenceGPU {
  final String id;
  final String vendor;
  final BigInt memoryBytes;
  final BigInt availableMemoryBytes;

  const ForgeDeviceHeartbeatReferenceGPU({
    required this.id,
    required this.vendor,
    required this.memoryBytes,
    required this.availableMemoryBytes,
  });

  factory ForgeDeviceHeartbeatReferenceGPU.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    _heartbeatReferenceExactKeys(json, {
      'id',
      'vendor',
      'memory_bytes',
      'available_memory_bytes',
    });
    final memoryBytes = _heartbeatReferenceCapabilityBytes(
      json['memory_bytes'],
      requireNonzero: true,
    );
    final availableMemoryBytes = _heartbeatReferenceCapabilityBytes(
      json['available_memory_bytes'],
      requireNonzero: false,
    );
    if (availableMemoryBytes > memoryBytes) {
      throw const FormatException(
        'Invalid Forge heartbeat GPU memory capacity.',
      );
    }
    return ForgeDeviceHeartbeatReferenceGPU(
      id: _heartbeatReferenceIdentifier(json['id']),
      vendor: _heartbeatReferenceLabel(json['vendor']),
      memoryBytes: memoryBytes,
      availableMemoryBytes: availableMemoryBytes,
    );
  }
}

class ForgeDeviceHeartbeatReferenceCapabilities {
  final String os;
  final String architecture;
  final BigInt cpuCores;
  final BigInt availableCPUCores;
  final BigInt memoryBytes;
  final BigInt availableMemoryBytes;
  final BigInt storageBytes;
  final BigInt availableStorageBytes;
  final List<ForgeDeviceHeartbeatReferenceGPU> gpus;
  final List<String> runtimes;

  const ForgeDeviceHeartbeatReferenceCapabilities({
    required this.os,
    required this.architecture,
    required this.cpuCores,
    required this.availableCPUCores,
    required this.memoryBytes,
    required this.availableMemoryBytes,
    required this.storageBytes,
    required this.availableStorageBytes,
    this.gpus = const [],
    required this.runtimes,
  });

  ForgeDeviceHeartbeatReferenceCapabilities canonicalized() {
    return ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
      'os': os,
      'architecture': architecture,
      'cpu_cores': cpuCores,
      'available_cpu_cores': availableCPUCores,
      'memory_bytes': memoryBytes,
      'available_memory_bytes': availableMemoryBytes,
      'storage_bytes': storageBytes,
      'available_storage_bytes': availableStorageBytes,
      'gpus': gpus
          .map(
            (gpu) => {
              'id': gpu.id,
              'vendor': gpu.vendor,
              'memory_bytes': gpu.memoryBytes,
              'available_memory_bytes': gpu.availableMemoryBytes,
            },
          )
          .toList(growable: false),
      'runtimes': runtimes,
    });
  }

  factory ForgeDeviceHeartbeatReferenceCapabilities.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    final expectedKeys = {
      'os',
      'architecture',
      'cpu_cores',
      'available_cpu_cores',
      'memory_bytes',
      'available_memory_bytes',
      'storage_bytes',
      'available_storage_bytes',
      'runtimes',
    };
    if (json.containsKey('gpus')) expectedKeys.add('gpus');
    _heartbeatReferenceExactKeys(json, expectedKeys);
    final rawRuntimes = json['runtimes'];
    if (rawRuntimes is! List ||
        rawRuntimes.length > _forgeHeartbeatMaxRuntimeCount) {
      throw const FormatException('Invalid Forge heartbeat runtimes.');
    }
    final runtimes =
        rawRuntimes.map(_heartbeatReferenceTag).toList(growable: false)..sort();
    if (_hasDuplicateStrings(runtimes)) {
      throw const FormatException('Duplicate Forge heartbeat runtime.');
    }
    final cpuCores = _heartbeatReferenceCPUCoreCount(json['cpu_cores']);
    final availableCPUCores = _heartbeatReferenceUint64(
      json['available_cpu_cores'],
    );
    if (availableCPUCores > cpuCores) {
      throw const FormatException('Invalid Forge heartbeat CPU capacity.');
    }
    final memoryBytes = _heartbeatReferenceCapabilityBytes(
      json['memory_bytes'],
      requireNonzero: true,
    );
    final availableMemoryBytes = _heartbeatReferenceCapabilityBytes(
      json['available_memory_bytes'],
      requireNonzero: false,
    );
    if (availableMemoryBytes > memoryBytes) {
      throw const FormatException('Invalid Forge heartbeat memory capacity.');
    }
    final storageBytes = _heartbeatReferenceCapabilityBytes(
      json['storage_bytes'],
      requireNonzero: false,
    );
    final availableStorageBytes = _heartbeatReferenceCapabilityBytes(
      json['available_storage_bytes'],
      requireNonzero: false,
    );
    if (availableStorageBytes > storageBytes) {
      throw const FormatException('Invalid Forge heartbeat storage capacity.');
    }
    final rawGPUs = json['gpus'];
    if (rawGPUs != null && rawGPUs is! List) {
      throw const FormatException('Invalid Forge heartbeat GPUs.');
    }
    final rawGPUValues = rawGPUs == null
        ? const <Object?>[]
        : List<Object?>.from(rawGPUs as List);
    final gpus =
        rawGPUValues
            .map<ForgeDeviceHeartbeatReferenceGPU>(
              ForgeDeviceHeartbeatReferenceGPU.fromJson,
            )
            .toList(growable: false)
          ..sort(
            (
              ForgeDeviceHeartbeatReferenceGPU left,
              ForgeDeviceHeartbeatReferenceGPU right,
            ) => left.id.compareTo(right.id),
          );
    if (gpus.length > _forgeHeartbeatMaxGPUCount ||
        _hasDuplicateStrings(gpus.map((gpu) => gpu.id).toList())) {
      throw const FormatException('Invalid Forge heartbeat GPU collection.');
    }
    return ForgeDeviceHeartbeatReferenceCapabilities(
      os: _heartbeatReferenceTag(json['os']),
      architecture: _heartbeatReferenceTag(json['architecture']),
      cpuCores: cpuCores,
      availableCPUCores: availableCPUCores,
      memoryBytes: memoryBytes,
      availableMemoryBytes: availableMemoryBytes,
      storageBytes: storageBytes,
      availableStorageBytes: availableStorageBytes,
      gpus: List.unmodifiable(gpus),
      runtimes: List.unmodifiable(runtimes),
    );
  }
}

BigInt _heartbeatReferenceCPUCoreCount(Object? value) {
  final number = _heartbeatReferenceUint64(value);
  if (number == BigInt.zero ||
      number > BigInt.from(_forgeHeartbeatMaxCPUCoreCount)) {
    throw const FormatException('Invalid Forge heartbeat CPU core count.');
  }
  return number;
}

BigInt _heartbeatReferenceCapabilityBytes(
  Object? value, {
  required bool requireNonzero,
}) {
  final number = _heartbeatReferenceUint64(value);
  if (number > _forgeHeartbeatMaxCapabilityBytes ||
      (requireNonzero && number == BigInt.zero)) {
    throw const FormatException('Invalid Forge heartbeat capability capacity.');
  }
  return number;
}

String _heartbeatReferenceTag(Object? value) {
  final text = _heartbeatReferenceText(value);
  if (text.length > _forgeHeartbeatMaxRuntimeNameBytes ||
      text.codeUnits.any(
        (code) =>
            !((code >= 0x30 && code <= 0x39) ||
                (code >= 0x41 && code <= 0x5a) ||
                (code >= 0x61 && code <= 0x7a) ||
                code == 0x2e ||
                code == 0x5f ||
                code == 0x2d ||
                code == 0x2b),
      )) {
    throw const FormatException('Invalid Forge heartbeat capability tag.');
  }
  return text.toLowerCase();
}

String _heartbeatReferenceLabel(Object? value) {
  if (value is! String) {
    throw const FormatException('Invalid Forge heartbeat capability label.');
  }
  final text = value.trim();
  if (text.isEmpty ||
      utf8.encode(text).length > _forgeHeartbeatMaxRuntimeNameBytes ||
      text.codeUnits.any(
        (code) => (code <= 0x1f) || (code >= 0x7f && code <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge heartbeat capability label.');
  }
  return text;
}

bool _hasDuplicateStrings(List<String> values) {
  for (var index = 1; index < values.length; index++) {
    if (values[index - 1] == values[index]) return true;
  }
  return false;
}

class ForgeDeviceHeartbeatReferenceExpected {
  final bool accepted;
  final String? error;
  final BigInt? generation;
  final BigInt? heartbeatSequence;
  final BigInt? serverObservedAtMS;
  final BigInt? capabilityLeaseExpiresAtMS;

  const ForgeDeviceHeartbeatReferenceExpected._({
    required this.accepted,
    required this.error,
    required this.generation,
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
  });

  factory ForgeDeviceHeartbeatReferenceExpected.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    final accepted = _heartbeatReferenceBool(json['accepted']);
    if (!accepted) {
      _heartbeatReferenceExactKeys(json, {'accepted', 'error'});
      return ForgeDeviceHeartbeatReferenceExpected._(
        accepted: false,
        error: _heartbeatReferenceText(json['error']),
        generation: null,
        heartbeatSequence: null,
        serverObservedAtMS: null,
        capabilityLeaseExpiresAtMS: null,
      );
    }
    _heartbeatReferenceExactKeys(json, {
      'accepted',
      'generation',
      'heartbeat_sequence',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
    });
    return ForgeDeviceHeartbeatReferenceExpected._(
      accepted: true,
      error: null,
      generation: _heartbeatReferencePositiveUint64(json['generation']),
      heartbeatSequence: _heartbeatReferencePositiveUint64(
        json['heartbeat_sequence'],
      ),
      serverObservedAtMS: _heartbeatReferenceUint64(
        json['server_observed_at_ms'],
      ),
      capabilityLeaseExpiresAtMS: _heartbeatReferenceUint64(
        json['capability_lease_expires_at_ms'],
      ),
    );
  }
}

class ForgeDeviceHeartbeatReferenceCase {
  final String name;
  final BigInt serverObservedAtMS;
  final BigInt leaseTTLMS;
  final String? deviceApprovalState;
  final ForgeDeviceHeartbeatInstance? current;
  final ForgeDeviceHeartbeatSignal heartbeat;
  final ForgeDeviceHeartbeatReferenceExpected expected;

  const ForgeDeviceHeartbeatReferenceCase({
    required this.name,
    required this.serverObservedAtMS,
    required this.leaseTTLMS,
    required this.deviceApprovalState,
    required this.current,
    required this.heartbeat,
    required this.expected,
  });

  ForgeDeviceHeartbeatReferenceCase withCapabilities(
    ForgeDeviceHeartbeatReferenceCapabilities capabilities,
  ) => ForgeDeviceHeartbeatReferenceCase(
    name: name,
    serverObservedAtMS: serverObservedAtMS,
    leaseTTLMS: leaseTTLMS,
    deviceApprovalState: deviceApprovalState,
    current: current?.withCapabilities(capabilities),
    heartbeat: heartbeat.withCapabilities(capabilities),
    expected: expected,
  );

  factory ForgeDeviceHeartbeatReferenceCase.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    final keys = {
      'name',
      'server_observed_at_ms',
      'lease_ttl_ms',
      'current',
      'heartbeat',
      'expected',
    };
    if (json.containsKey('device_approval_state')) {
      keys.add('device_approval_state');
    }
    _heartbeatReferenceExactKeys(json, keys);
    final rawApproval = json['device_approval_state'];
    final approval = rawApproval == null
        ? null
        : _heartbeatReferenceText(rawApproval);
    if (approval != null &&
        !const {'approved', 'pending', 'revoked'}.contains(approval)) {
      throw const FormatException('Invalid Forge heartbeat approval override.');
    }
    final rawCurrent = json['current'];
    if (rawCurrent != null && rawCurrent is! Map) {
      throw const FormatException('Invalid Forge heartbeat current state.');
    }
    return ForgeDeviceHeartbeatReferenceCase(
      name: _heartbeatReferenceIdentifier(json['name']),
      serverObservedAtMS: _heartbeatReferenceUint64(
        json['server_observed_at_ms'],
      ),
      leaseTTLMS: _heartbeatReferenceUint64(json['lease_ttl_ms']),
      deviceApprovalState: approval,
      current: rawCurrent == null
          ? null
          : ForgeDeviceHeartbeatInstance.fromJson(rawCurrent),
      heartbeat: ForgeDeviceHeartbeatSignal.fromJson(json['heartbeat']),
      expected: ForgeDeviceHeartbeatReferenceExpected.fromJson(
        json['expected'],
      ),
    );
  }
}

class ForgeDeviceHeartbeatReferenceFixture {
  final String tenantID;
  final ForgeDeviceHeartbeatReferenceDevice device;
  final ForgeDeviceHeartbeatReferenceCapabilities capabilities;
  final ForgeDeviceHeartbeatAuthority authority;
  final List<ForgeDeviceHeartbeatReferenceCase> cases;

  const ForgeDeviceHeartbeatReferenceFixture({
    required this.tenantID,
    required this.device,
    required this.capabilities,
    required this.authority,
    required this.cases,
  });

  factory ForgeDeviceHeartbeatReferenceFixture.fromJsonText(String source) {
    final marked = _markForgeHeartbeatMaxUint64(source);
    return ForgeDeviceHeartbeatReferenceFixture.fromJson(
      _restoreForgeHeartbeatUint64Markers(jsonDecode(marked)),
    );
  }

  factory ForgeDeviceHeartbeatReferenceFixture.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    _heartbeatReferenceExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner_declaration',
      'device',
      'capabilities',
      'authority',
      'cases',
    });
    if (json['schema_version'] != forgeDeviceHeartbeatSchema ||
        json['evaluation_mode'] != forgeDeviceHeartbeatEvaluationMode) {
      throw const FormatException(
        'Invalid Forge heartbeat reference envelope.',
      );
    }
    final owner = _heartbeatReferenceObject(json['owner_declaration']);
    _heartbeatReferenceExactKeys(owner, {'tenant_id'});
    final rawCases = json['cases'];
    if (rawCases is! List || rawCases.length != 12) {
      throw const FormatException('Invalid Forge heartbeat reference cases.');
    }
    final capabilities = ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
      json['capabilities'],
    );
    final cases = rawCases
        .map(ForgeDeviceHeartbeatReferenceCase.fromJson)
        .map((testCase) => testCase.withCapabilities(capabilities))
        .toList(growable: false);
    if (cases.map((testCase) => testCase.name).toSet().length != cases.length) {
      throw const FormatException('Duplicate Forge heartbeat case name.');
    }
    final tenantID = _heartbeatReferenceIdentifier(owner['tenant_id']);
    final device = ForgeDeviceHeartbeatReferenceDevice.fromJson(json['device']);
    if (device.tenantID != tenantID) {
      throw const FormatException('Forge heartbeat owner/device mismatch.');
    }
    return ForgeDeviceHeartbeatReferenceFixture(
      tenantID: tenantID,
      device: device,
      capabilities: capabilities,
      authority: ForgeDeviceHeartbeatAuthority.fromJson(json['authority']),
      cases: List.unmodifiable(cases),
    );
  }
}
