import 'dart:convert';

typedef ForgeDeviceJson = Map<String, dynamic>;

class ForgeDeviceOwner {
  final String issuer;
  final String subject;
  final String tenantID;

  const ForgeDeviceOwner({
    required this.issuer,
    required this.subject,
    required this.tenantID,
  });

  factory ForgeDeviceOwner.fromJson(Object? value) {
    final json = _object(value);
    _exactKeys(json, {'issuer', 'subject', 'tenant_id'});
    return ForgeDeviceOwner(
      issuer: _ownerText(json['issuer']),
      subject: _ownerText(json['subject']),
      tenantID: _ownerText(json['tenant_id']),
    );
  }

  Map<String, dynamic> toJson() => {
    'issuer': issuer,
    'subject': subject,
    'tenant_id': tenantID,
  };

  @override
  bool operator ==(Object other) =>
      other is ForgeDeviceOwner &&
      other.issuer == issuer &&
      other.subject == subject &&
      other.tenantID == tenantID;

  @override
  int get hashCode => Object.hash(issuer, subject, tenantID);
}

class ForgeDeviceDeclaration {
  final String deviceID;
  final ForgeDeviceOwner owner;
  final String approvalState;
  final String cordonState;
  final String liveness;
  final int snapshotObservedAtMS;
  final int leaseExpiresAtMS;
  final String os;
  final String architecture;
  final int availableCPUCores;
  final int availableMemoryBytes;
  final int availableStorageBytes;
  final List<String> runtimes;
  final ForgeDeviceGpu gpu;
  final List<String> dataResidencyZones;
  final String trustZone;
  final List<String> sandboxLevels;
  final int concurrencyLimit;
  final int activeConcurrency;

  const ForgeDeviceDeclaration({
    required this.deviceID,
    required this.owner,
    required this.approvalState,
    required this.cordonState,
    required this.liveness,
    required this.snapshotObservedAtMS,
    required this.leaseExpiresAtMS,
    required this.os,
    required this.architecture,
    required this.availableCPUCores,
    required this.availableMemoryBytes,
    required this.availableStorageBytes,
    required this.runtimes,
    required this.gpu,
    required this.dataResidencyZones,
    required this.trustZone,
    required this.sandboxLevels,
    required this.concurrencyLimit,
    required this.activeConcurrency,
  });

  factory ForgeDeviceDeclaration.fromJson(Object? value) {
    final json = _object(value);
    _exactKeys(json, {
      'device_id',
      'owner',
      'approval_state',
      'cordon_state',
      'liveness',
      'snapshot_observed_at_ms',
      'lease_expires_at_ms',
      'os',
      'architecture',
      'available_cpu_cores',
      'available_memory_bytes',
      'available_storage_bytes',
      'runtimes',
      'gpu',
      'data_residency_zones',
      'trust_zone',
      'sandbox_levels',
      'concurrency_limit',
      'active_concurrency',
    });
    return ForgeDeviceDeclaration(
      deviceID: _identifier(json['device_id']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      approvalState: _oneOf(json['approval_state'], {
        'approved',
        'pending',
        'revoked',
        'unknown',
      }),
      cordonState: _oneOf(json['cordon_state'], {
        'clear',
        'cordoned',
        'unknown',
      }),
      liveness: _oneOf(json['liveness'], {'online', 'offline', 'unknown'}),
      snapshotObservedAtMS: _uint64(json['snapshot_observed_at_ms']),
      leaseExpiresAtMS: _uint64(json['lease_expires_at_ms']),
      os: _token(json['os']),
      architecture: _token(json['architecture']),
      availableCPUCores: _boundedInt(json['available_cpu_cores'], 0xffffffff),
      availableMemoryBytes: _uint64(json['available_memory_bytes']),
      availableStorageBytes: _uint64(json['available_storage_bytes']),
      runtimes: _tokens(json['runtimes'], 32),
      gpu: ForgeDeviceGpu.fromJson(json['gpu']),
      dataResidencyZones: _zones(json['data_residency_zones']),
      trustZone: _oneOf(json['trust_zone'], {
        'untrusted',
        'low',
        'standard',
        'high',
        'restricted',
        'unknown',
      }),
      sandboxLevels: _oneOfList(json['sandbox_levels'], {
        'process',
        'container',
        'microvm',
      }),
      concurrencyLimit: _boundedInt(json['concurrency_limit'], 0xffff),
      activeConcurrency: _boundedInt(json['active_concurrency'], 0xffff),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceID,
    'owner': owner.toJson(),
    'approval_state': approvalState,
    'cordon_state': cordonState,
    'liveness': liveness,
    'snapshot_observed_at_ms': snapshotObservedAtMS,
    'lease_expires_at_ms': leaseExpiresAtMS,
    'os': os,
    'architecture': architecture,
    'available_cpu_cores': availableCPUCores,
    'available_memory_bytes': availableMemoryBytes,
    'available_storage_bytes': availableStorageBytes,
    'runtimes': runtimes,
    'gpu': gpu.toJson(),
    'data_residency_zones': dataResidencyZones,
    'trust_zone': trustZone,
    'sandbox_levels': sandboxLevels,
    'concurrency_limit': concurrencyLimit,
    'active_concurrency': activeConcurrency,
  };
}

class ForgeDeviceGpu {
  final bool present;
  final int memoryBytes;
  final String runtime;

  const ForgeDeviceGpu({
    required this.present,
    required this.memoryBytes,
    required this.runtime,
  });

  factory ForgeDeviceGpu.fromJson(Object? value) {
    final json = _object(value);
    _exactKeys(json, {'present', 'memory_bytes', 'runtime'});
    final present = json['present'];
    if (present is! bool) {
      throw const FormatException('Invalid Forge GPU declaration.');
    }
    final memory = _uint64(json['memory_bytes']);
    final runtime = json['runtime'];
    if (runtime is! String || (runtime.isNotEmpty && !_validToken(runtime))) {
      throw const FormatException('Invalid Forge GPU runtime.');
    }
    if (!present && (memory != 0 || runtime.isNotEmpty)) {
      throw const FormatException('Absent Forge GPU has nonzero resources.');
    }
    return ForgeDeviceGpu(
      present: present,
      memoryBytes: memory,
      runtime: runtime,
    );
  }

  Map<String, dynamic> toJson() => {
    'present': present,
    'memory_bytes': memoryBytes,
    'runtime': runtime,
  };
}

ForgeDeviceJson _object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge device object.');
  }
  return Map<String, dynamic>.from(value);
}

void _exactKeys(ForgeDeviceJson json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge device observation fields.');
  }
}

String _ownerText(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.trim() != value ||
      !_ownerWellFormedUnicode(value) ||
      utf8.encode(value).length > 512 ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge device owner declaration.');
  }
  return value;
}

bool _ownerWellFormedUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= (0xdb00 + 0xff)) {
      if (index + 1 >= value.length) {
        return false;
      }
      final next = value.codeUnitAt(index + 1);
      if (next < 0xdc00 || next > 0xdfff) {
        return false;
      }
      index++;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

String _identifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_asciiIdentifier(value)) {
    throw const FormatException('Invalid Forge device identifier.');
  }
  return value;
}

bool _asciiIdentifier(String value) {
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

String _token(Object? value) {
  if (value is! String || !_validToken(value)) {
    throw const FormatException('Invalid Forge device label.');
  }
  return value;
}

bool _validToken(String value) =>
    value.isNotEmpty &&
    value.length <= 128 &&
    value.codeUnits.every(
      (code) =>
          code >= 0x30 && code <= 0x39 ||
          code >= 0x41 && code <= 0x5a ||
          code >= 0x61 && code <= 0x7a ||
          const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
    );

String _oneOf(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('Invalid Forge device state.');
  }
  return value;
}

List<String> _tokens(Object? value, int maximum) {
  if (value is! List || value.length > maximum) {
    throw const FormatException('Invalid Forge device labels.');
  }
  final values = value.map(_token).toList(growable: false);
  if (values.toSet().length != values.length) {
    throw const FormatException('Duplicate Forge device labels.');
  }
  return values;
}

List<String> _zones(Object? value) {
  if (value is! List || value.length > 32) {
    throw const FormatException('Invalid Forge residency zones.');
  }
  final values = value
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
          throw const FormatException('Invalid Forge residency zone.');
        }
        return item;
      })
      .toList(growable: false);
  if (values.toSet().length != values.length) {
    throw const FormatException('Duplicate Forge residency zones.');
  }
  return values;
}

List<String> _oneOfList(Object? value, Set<String> allowed) {
  if (value is! List || value.length > 32) {
    throw const FormatException('Invalid Forge sandbox levels.');
  }
  final values = value
      .map((item) => _oneOf(item, allowed))
      .toList(growable: false);
  if (values.toSet().length != values.length) {
    throw const FormatException('Duplicate Forge sandbox levels.');
  }
  return values;
}

int _nonNegativeInt(Object? value) {
  if (value is! int || value < 0) {
    throw const FormatException('Expected nonnegative Forge integer.');
  }
  return value;
}

int _uint64(Object? value) => _boundedInt(value, 9007199254740991);

int _boundedInt(Object? value, int maximum) {
  final result = _nonNegativeInt(value);
  if (result > maximum) {
    throw const FormatException('Forge integer exceeds bound.');
  }
  return result;
}
