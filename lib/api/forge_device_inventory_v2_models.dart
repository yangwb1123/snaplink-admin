import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

/// Bounded local reader seam for the lossless v2 inventory preview. The
/// default Sessions surface uses the platform workspace picker; tests and
/// native shells can inject a reader without opening an inventory route.
typedef ForgeDeviceInventoryV2FileReader = Future<String?> Function();

const _forgeDeviceInventoryV2Schema = 'forge.device-inventory-observation/v2';
const _forgeDeviceInventoryV2Mode = 'offline_static_only';
const _forgeDeviceInventoryV2MaxSafeInteger = 9007199254740991;
const _forgeDeviceInventoryV2MaxDevices = 128;
const _forgeDeviceInventoryV2MaxArrayItems = 32;
const _forgeDeviceInventoryV2MaxGPUCount = 32;
const _forgeDeviceInventoryV2MaxCPUCores = 4096;
const _forgeDeviceInventoryV2MinLeaseTTLMS = 1000;
const _forgeDeviceInventoryV2MaxLeaseTTLMS = 600000;
const _forgeDeviceInventoryV2Notice =
    'Every owner, instance, state, timestamp, resource, GPU, reservation, residency, trust, sandbox, and concurrency value is an unverified caller declaration. This read-only observation selects no target and grants no execution authority.';

const forgeDeviceInventoryV2Schema = _forgeDeviceInventoryV2Schema;
const forgeDeviceInventoryV2EvaluationMode = _forgeDeviceInventoryV2Mode;
const forgeDeviceInventoryV2Notice = _forgeDeviceInventoryV2Notice;

/// Lossless, display-only inventory observation. This v2 model is kept
/// separate from the v1 UI model so adding reservation and multi-GPU data
/// cannot silently change the existing contract.
class ForgeDeviceInventoryPageV2 {
  final String evaluationMode;
  final int evaluatedAtMS;
  final ForgeDeviceOwner owner;
  final bool ownerDeclarationUnverified;
  final bool inventoryDeclarationsUnverified;
  final String notice;
  final List<ForgeDeviceInventoryCandidateV2> devices;
  final bool executionAuthorized;
  final bool reservationCreated;
  final bool dispatchPerformed;

  const ForgeDeviceInventoryPageV2({
    required this.evaluationMode,
    required this.evaluatedAtMS,
    required this.owner,
    required this.ownerDeclarationUnverified,
    required this.inventoryDeclarationsUnverified,
    required this.notice,
    required this.devices,
    required this.executionAuthorized,
    required this.reservationCreated,
    required this.dispatchPerformed,
  });

  /// Whether this value still carries the bounded, display-only v2 contract.
  ///
  /// [fromJson] enforces these invariants while decoding wire data, but the
  /// public constructor is also used by native/test seams.  Local
  /// convergence guards must therefore re-check the envelope before using a
  /// manually constructed observation as a freshness boundary.
  bool get isDisplayOnly =>
      evaluationMode == _forgeDeviceInventoryV2Mode &&
      evaluatedAtMS > 0 &&
      ownerDeclarationUnverified &&
      inventoryDeclarationsUnverified &&
      notice == _forgeDeviceInventoryV2Notice &&
      !executionAuthorized &&
      !reservationCreated &&
      !dispatchPerformed;

  /// Decodes one bounded raw JSON document without allowing duplicate object
  /// keys to be silently replaced by [dart:convert].
  factory ForgeDeviceInventoryPageV2.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Forge v2 device observation document is too large.',
      );
    }
    _v2RejectDuplicateKeys(source);
    return ForgeDeviceInventoryPageV2.fromJson(jsonDecode(source));
  }

  factory ForgeDeviceInventoryPageV2.fromJson(Object? value) {
    final json = _v2Object(value);
    _v2ExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'evaluated_at_ms',
      'owner_declaration',
      'owner_declaration_unverified',
      'inventory_declarations_unverified',
      'notice',
      'devices',
      'execution_authorized',
      'reservation_created',
      'dispatch_performed',
    });
    if (json['schema_version'] != _forgeDeviceInventoryV2Schema ||
        json['evaluation_mode'] != _forgeDeviceInventoryV2Mode ||
        json['owner_declaration_unverified'] != true ||
        json['inventory_declarations_unverified'] != true ||
        json['notice'] != _forgeDeviceInventoryV2Notice ||
        json['execution_authorized'] != false ||
        json['reservation_created'] != false ||
        json['dispatch_performed'] != false) {
      throw const FormatException(
        'Invalid Forge v2 device observation envelope.',
      );
    }
    final evaluatedAt = _v2PositiveInt(json['evaluated_at_ms']);
    final owner = ForgeDeviceOwner.fromJson(json['owner_declaration']);
    final rawDevices = json['devices'];
    if (rawDevices is! List ||
        rawDevices.length > _forgeDeviceInventoryV2MaxDevices) {
      throw const FormatException('Invalid Forge v2 device observations.');
    }
    final devices = rawDevices
        .map((row) => ForgeDeviceInventoryCandidateV2.fromJson(row, owner))
        .toList(growable: false);
    final instances = <String>{};
    for (var index = 0; index < devices.length; index++) {
      final candidate = devices[index];
      if (!instances.add(candidate.instanceID)) {
        throw const FormatException(
          'Forge v2 observations contain duplicate instances.',
        );
      }
      if (index > 0 &&
          _v2CompareIDs(
                devices[index - 1].device.deviceID,
                candidate.device.deviceID,
              ) >=
              0) {
        throw const FormatException('Forge v2 observations are unsorted.');
      }
    }
    return ForgeDeviceInventoryPageV2(
      evaluationMode: _forgeDeviceInventoryV2Mode,
      evaluatedAtMS: evaluatedAt,
      owner: owner,
      ownerDeclarationUnverified: true,
      inventoryDeclarationsUnverified: true,
      notice: _forgeDeviceInventoryV2Notice,
      devices: devices,
      executionAuthorized: false,
      reservationCreated: false,
      dispatchPerformed: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': _forgeDeviceInventoryV2Schema,
    'evaluation_mode': evaluationMode,
    'evaluated_at_ms': evaluatedAtMS,
    'owner_declaration': owner.toJson(),
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'inventory_declarations_unverified': inventoryDeclarationsUnverified,
    'notice': notice,
    'devices': devices.map((candidate) => candidate.toJson()).toList(),
    'execution_authorized': executionAuthorized,
    'reservation_created': reservationCreated,
    'dispatch_performed': dispatchPerformed,
  };
}

class ForgeDeviceInventoryCandidateV2 {
  final String instanceID;
  final int revision;
  final int generation;
  final int heartbeatSequence;
  final ForgeDeviceV2 device;

  const ForgeDeviceInventoryCandidateV2({
    required this.instanceID,
    required this.revision,
    required this.generation,
    required this.heartbeatSequence,
    required this.device,
  });

  factory ForgeDeviceInventoryCandidateV2.fromJson(
    Object? value,
    ForgeDeviceOwner owner,
  ) {
    final json = _v2Object(value);
    _v2ExactKeys(json, {
      'instance_id',
      'revision',
      'generation',
      'heartbeat_sequence',
      'device',
    });
    final device = ForgeDeviceV2.fromJson(json['device']);
    if (device.owner != owner) {
      throw const FormatException('Forge v2 device owner mismatch.');
    }
    return ForgeDeviceInventoryCandidateV2(
      instanceID: _v2Identifier(json['instance_id']),
      revision: _v2PositiveInt(json['revision']),
      generation: _v2PositiveInt(json['generation']),
      heartbeatSequence: _v2PositiveInt(json['heartbeat_sequence']),
      device: device,
    );
  }

  Map<String, dynamic> toJson() => {
    'instance_id': instanceID,
    'revision': revision,
    'generation': generation,
    'heartbeat_sequence': heartbeatSequence,
    'device': device.toJson(),
  };
}

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

Map<String, dynamic> _v2Object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge v2 object.');
  }
  return Map<String, dynamic>.from(value);
}

void _v2ExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge v2 observation fields.');
  }
}

String _v2Identifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_v2ASCIIIdentifier(value)) {
    throw const FormatException('Invalid Forge v2 identifier.');
  }
  return value;
}

bool _v2ASCIIIdentifier(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x3a ||
      code == 0x2d;
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

int _v2PositiveInt(Object? value) {
  if (value is! int ||
      value <= 0 ||
      value > _forgeDeviceInventoryV2MaxSafeInteger) {
    throw const FormatException('Expected positive Forge v2 integer.');
  }
  return value;
}

int _v2NonNegativeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > _forgeDeviceInventoryV2MaxSafeInteger) {
    throw const FormatException('Expected non-negative Forge v2 integer.');
  }
  return value;
}

int _v2CapabilityBytes(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > _forgeDeviceInventoryV2MaxSafeInteger) {
    throw const FormatException('Invalid Forge v2 capability bytes.');
  }
  return value;
}

int _v2BoundedInt(Object? value, int maximum) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Invalid Forge v2 bounded integer.');
  }
  return value;
}

String _v2Token(Object? value, {int maxBytes = 64}) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maxBytes ||
      value.trim() != value ||
      value.codeUnits.any((unit) => !_v2TokenCode(unit))) {
    throw const FormatException('Invalid Forge v2 token.');
  }
  return value;
}

String _v2LowerToken(Object? value, {int maxBytes = 64}) {
  final token = _v2Token(value, maxBytes: maxBytes);
  if (token != token.toLowerCase()) {
    throw const FormatException('Invalid Forge v2 normalized token.');
  }
  return token;
}

bool _v2TokenCode(int code) =>
    code >= 0x30 && code <= 0x39 ||
    code >= 0x41 && code <= 0x5a ||
    code >= 0x61 && code <= 0x7a ||
    const [0x2e, 0x5f, 0x2b, 0x2d].contains(code);

String _v2Label(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.trim() != value ||
      utf8.encode(value).length > 64 ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge v2 label.');
  }
  return value;
}

String _v2OneOf(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('Invalid Forge v2 enum.');
  }
  return value;
}

List<String> _v2Tokens(Object? value, int maximum) {
  if (value is! List || value.length > maximum) {
    throw const FormatException('Invalid Forge v2 token list.');
  }
  final tokens = value.map((entry) => _v2Token(entry)).toList(growable: false);
  if (tokens.any((token) => token != token.toLowerCase())) {
    throw const FormatException('Forge v2 tokens are not normalized.');
  }
  _v2RequireSortedUnique(tokens);
  return tokens;
}

List<String> _v2EnumList(Object? value, Set<String> allowed) {
  if (value is! List || value.length > _forgeDeviceInventoryV2MaxArrayItems) {
    throw const FormatException('Invalid Forge v2 enum list.');
  }
  final values = value
      .map((entry) => _v2OneOf(entry, allowed))
      .toList(growable: false);
  _v2RequireSortedUnique(values);
  return values;
}

void _v2RequireSortedUnique(List<String> values) {
  for (var index = 1; index < values.length; index++) {
    if (_v2CompareIDs(values[index - 1], values[index]) >= 0) {
      throw const FormatException(
        'Forge v2 values are unsorted or duplicated.',
      );
    }
  }
}

int _v2CompareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}

void _v2RejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && _v2Whitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException('Invalid Forge v2 JSON object key.');
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException('Duplicate Forge v2 JSON key.');
          }
        }
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      stringStart = index;
    } else if (char == '{') {
      objects.add(<String>{});
    } else if (char == '}') {
      if (objects.isEmpty) {
        throw const FormatException('Invalid Forge v2 JSON object.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge v2 JSON.');
  }
}

bool _v2Whitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
