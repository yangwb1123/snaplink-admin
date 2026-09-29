part of 'forge_device_enrollment_heartbeat_lifecycle_registry.dart';

Map<String, dynamic> _lifecycleRegistryObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Forge lifecycle registry $label must be an object.');
  }
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    throw FormatException('Forge lifecycle registry $label has invalid keys.');
  }
}

void _lifecycleRegistryExactKeys(
  Map<String, dynamic> value,
  Set<String> expected,
) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Forge lifecycle registry has unknown or missing fields.',
    );
  }
}

String _lifecycleRegistryIdentifier(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_lifecycleRegistryASCIIIdentifier(value)) {
    throw FormatException('Forge lifecycle registry $label is invalid.');
  }
  return value;
}

bool _lifecycleRegistryASCIIIdentifier(String value) {
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

String _lifecycleRegistryDigest(Object? value, String label) {
  if (value is! String ||
      value.length != 64 ||
      value.runes.any(
        (rune) =>
            !(rune >= 0x30 && rune <= 0x39 || rune >= 0x61 && rune <= 0x66),
      )) {
    throw FormatException('Forge lifecycle registry $label is invalid.');
  }
  return value;
}

String _lifecycleRegistryOneOf(
  Object? value,
  Set<String> allowed,
  String label,
) {
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Forge lifecycle registry $label is invalid.');
  }
  return value;
}

BigInt _lifecycleRegistrySafeInteger(Object? value, String label) {
  if (value is! int ||
      value < 0 ||
      value > forgeDeviceEnrollmentHeartbeatLifecycleRegistryMaxSafeInteger) {
    throw FormatException(
      'Forge lifecycle registry $label exceeds the safe integer bound.',
    );
  }
  return BigInt.from(value);
}

BigInt _lifecycleRegistryPositiveSafeInteger(Object? value, String label) {
  final number = _lifecycleRegistrySafeInteger(value, label);
  if (number == BigInt.zero) {
    throw FormatException('Forge lifecycle registry $label must be positive.');
  }
  return number;
}

void _lifecycleRegistryRequireCanonicalCapabilities(
  Object? rawValue,
  ForgeDeviceHeartbeatReferenceCapabilities parsed,
) {
  final raw = _lifecycleRegistryObject(rawValue, 'capabilities');
  final rawRuntimes = raw['runtimes'];
  if (rawRuntimes is! List ||
      rawRuntimes.length != parsed.runtimes.length ||
      rawRuntimes.asMap().entries.any(
        (entry) => entry.value != parsed.runtimes[entry.key],
      )) {
    throw const FormatException(
      'Forge lifecycle registry capabilities are not canonical.',
    );
  }
  final rawGPUs = raw['gpus'];
  final parsedGPUs = parsed.gpus;
  if (rawGPUs is! List || rawGPUs.length != parsedGPUs.length) {
    throw const FormatException(
      'Forge lifecycle registry GPU capabilities are not canonical.',
    );
  }
  for (var index = 0; index < parsedGPUs.length; index++) {
    final gpu = _lifecycleRegistryObject(rawGPUs[index], 'GPU capability');
    final expected = parsedGPUs[index];
    if (gpu['id'] != expected.id ||
        gpu['vendor'] != expected.vendor ||
        gpu['memory_bytes'] != expected.memoryBytes.toInt() ||
        gpu['available_memory_bytes'] !=
            expected.availableMemoryBytes.toInt()) {
      throw const FormatException(
        'Forge lifecycle registry GPU capabilities are not canonical.',
      );
    }
  }
}

bool _sameLifecycleCapabilities(
  ForgeDeviceHeartbeatReferenceCapabilities left,
  ForgeDeviceHeartbeatReferenceCapabilities right,
) {
  if (left.os != right.os ||
      left.architecture != right.architecture ||
      left.cpuCores != right.cpuCores ||
      left.availableCPUCores != right.availableCPUCores ||
      left.memoryBytes != right.memoryBytes ||
      left.availableMemoryBytes != right.availableMemoryBytes ||
      left.storageBytes != right.storageBytes ||
      left.availableStorageBytes != right.availableStorageBytes ||
      left.runtimes.length != right.runtimes.length ||
      left.gpus.length != right.gpus.length) {
    return false;
  }
  for (var index = 0; index < left.runtimes.length; index++) {
    if (left.runtimes[index] != right.runtimes[index]) return false;
  }
  for (var index = 0; index < left.gpus.length; index++) {
    final leftGPU = left.gpus[index];
    final rightGPU = right.gpus[index];
    if (leftGPU.id != rightGPU.id ||
        leftGPU.vendor != rightGPU.vendor ||
        leftGPU.memoryBytes != rightGPU.memoryBytes ||
        leftGPU.availableMemoryBytes != rightGPU.availableMemoryBytes) {
      return false;
    }
  }
  return true;
}

Map<String, dynamic> _lifecycleRegistryDeepCopy(Map<String, dynamic> value) =>
    Map<String, dynamic>.unmodifiable(
      value.map(
        (key, item) => MapEntry(key, _lifecycleRegistryCopyValue(item)),
      ),
    );

Object? _lifecycleRegistryCopyValue(Object? value) {
  if (value is Map) {
    return Map<String, dynamic>.unmodifiable(
      value.map<String, dynamic>(
        (key, item) =>
            MapEntry(key.toString(), _lifecycleRegistryCopyValue(item)),
      ),
    );
  }
  if (value is List) {
    return List<Object?>.unmodifiable(value.map(_lifecycleRegistryCopyValue));
  }
  return value;
}

void _lifecycleRegistryRejectDuplicateKeys(String source) {
  final objectKeys = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final character = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (character == '\\') {
        escaped = true;
      } else if (character == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String ||
              objectKeys.isEmpty ||
              !objectKeys.last.add(key)) {
            throw const FormatException(
              'Forge lifecycle registry contains duplicate JSON fields.',
            );
          }
        }
      }
      continue;
    }
    if (character == '"') {
      inString = true;
      stringStart = index;
    } else if (character == '{') {
      objectKeys.add(<String>{});
    } else if (character == '}') {
      if (objectKeys.isEmpty) {
        throw const FormatException('Invalid Forge lifecycle registry JSON.');
      }
      objectKeys.removeLast();
    }
  }
  if (inString || objectKeys.isNotEmpty) {
    throw const FormatException('Invalid Forge lifecycle registry JSON.');
  }
}
