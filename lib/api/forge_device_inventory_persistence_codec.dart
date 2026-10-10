part of 'forge_device_inventory_persistence.dart';

Map<String, dynamic> _inventoryPersistenceObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge persisted inventory object.');
  }
  return Map<String, dynamic>.from(value);
}

void _inventoryPersistenceExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge persisted inventory fields.');
  }
}

bool _inventoryPersistenceBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge persisted inventory bool.');
  }
  return value;
}

String _inventoryPersistenceText(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge persisted inventory text.');
  }
  return value;
}

String _inventoryPersistenceIdentifier(Object? value) {
  final text = _inventoryPersistenceText(value);
  if (!_inventoryPersistenceIdentifierValid(text)) {
    throw const FormatException(
      'Invalid Forge persisted inventory identifier.',
    );
  }
  return text;
}

bool _inventoryPersistenceIdentifierValid(String value) {
  if (value.isEmpty || value.length > 128) return false;
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

bool _inventoryPersistenceOwnerValid(ForgeDeviceOwner owner) {
  bool validPart(String value) =>
      value.isNotEmpty &&
      utf8.encode(value).length <= 512 &&
      value.trim() == value &&
      !value.runes.any(
        (rune) => rune <= 0x1f || (rune >= 0x7f && rune <= 0x9f),
      );
  return validPart(owner.issuer) &&
      validPart(owner.subject) &&
      validPart(owner.tenantID);
}

String _inventoryPersistenceOneOf(Object? value, Set<String> allowed) {
  final text = _inventoryPersistenceText(value);
  if (!allowed.contains(text)) {
    throw const FormatException('Invalid Forge persisted inventory state.');
  }
  return text;
}

bool _inventoryPersistenceAllowed(String value, Set<String> allowed) =>
    allowed.contains(value);

bool _inventoryPersistenceCapabilitiesCanonical(
  Object? rawValue,
  ForgeDeviceHeartbeatReferenceCapabilities canonical,
) {
  final json = _inventoryPersistenceObject(rawValue);
  if (json['os'] != canonical.os ||
      json['architecture'] != canonical.architecture ||
      !_inventoryPersistenceSameUint64(json['cpu_cores'], canonical.cpuCores) ||
      !_inventoryPersistenceSameUint64(
        json['available_cpu_cores'],
        canonical.availableCPUCores,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['memory_bytes'],
        canonical.memoryBytes,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['available_memory_bytes'],
        canonical.availableMemoryBytes,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['storage_bytes'],
        canonical.storageBytes,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['available_storage_bytes'],
        canonical.availableStorageBytes,
      )) {
    return false;
  }
  final rawRuntimes = json['runtimes'];
  if (rawRuntimes is! List || rawRuntimes.length != canonical.runtimes.length) {
    return false;
  }
  for (var index = 0; index < rawRuntimes.length; index++) {
    if (rawRuntimes[index] != canonical.runtimes[index]) return false;
  }
  if (!json.containsKey('gpus')) return canonical.gpus.isEmpty;
  final rawGPUs = json['gpus'];
  if (rawGPUs is! List || rawGPUs.length != canonical.gpus.length) {
    return false;
  }
  for (var index = 0; index < rawGPUs.length; index++) {
    final rawGPU = _inventoryPersistenceObject(rawGPUs[index]);
    final canonicalGPU = canonical.gpus[index];
    if (rawGPU['id'] != canonicalGPU.id ||
        rawGPU['vendor'] != canonicalGPU.vendor ||
        !_inventoryPersistenceSameUint64(
          rawGPU['memory_bytes'],
          canonicalGPU.memoryBytes,
        ) ||
        !_inventoryPersistenceSameUint64(
          rawGPU['available_memory_bytes'],
          canonicalGPU.availableMemoryBytes,
        )) {
      return false;
    }
  }
  return true;
}

bool _inventoryPersistenceSameUint64(Object? raw, BigInt canonical) {
  try {
    return _inventoryPersistenceUint64(raw) == canonical;
  } on FormatException {
    return false;
  }
}

BigInt _inventoryPersistenceUint64(Object? value) {
  final number = value is BigInt
      ? value
      : value is int
      ? BigInt.from(value)
      : null;
  if (number == null ||
      number < BigInt.zero ||
      number > _forgeDeviceInventoryPersistenceMaxUint64) {
    throw const FormatException('Invalid Forge persisted inventory uint64.');
  }
  return number;
}

BigInt _inventoryPersistencePositiveUint64(Object? value) {
  final number = _inventoryPersistenceUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException(
      'Invalid Forge persisted inventory positive uint64.',
    );
  }
  return number;
}

Object? _restoreForgeDeviceInventoryPersistenceUint64Markers(Object? value) {
  if (value is String &&
      value == _forgeDeviceInventoryPersistenceMaxUint64Marker) {
    return _forgeDeviceInventoryPersistenceMaxUint64;
  }
  if (value is List) {
    return value
        .map(_restoreForgeDeviceInventoryPersistenceUint64Markers)
        .toList(growable: false);
  }
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(
          entry.key as String,
          _restoreForgeDeviceInventoryPersistenceUint64Markers(entry.value),
        ),
      ),
    );
  }
  return value;
}
