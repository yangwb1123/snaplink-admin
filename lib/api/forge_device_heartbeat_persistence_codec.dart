part of 'forge_device_heartbeat_persistence.dart';

Map<String, dynamic> _heartbeatObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge heartbeat object.');
  }
  return Map<String, dynamic>.from(value);
}

void _heartbeatExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge heartbeat fields.');
  }
}

bool _heartbeatBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge heartbeat bool.');
  }
  return value;
}

String _heartbeatText(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge heartbeat text.');
  }
  return value;
}

String _heartbeatIdentifier(Object? value) {
  final text = _heartbeatText(value);
  if (text.length > 128) {
    throw const FormatException('Invalid Forge heartbeat identifier.');
  }
  final codes = text.codeUnits;
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
  if (!first(codes.first) || !codes.skip(1).every(rest)) {
    throw const FormatException('Invalid Forge heartbeat identifier.');
  }
  return text;
}

BigInt _heartbeatUint64(Object? value) {
  final number = value is BigInt
      ? value
      : value is int
      ? BigInt.from(value)
      : null;
  if (number == null ||
      number < BigInt.zero ||
      number > _forgeDeviceHeartbeatMaxUint64) {
    throw const FormatException('Invalid Forge heartbeat uint64.');
  }
  return number;
}

BigInt _heartbeatPositiveUint64(Object? value) {
  final number = _heartbeatUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException('Invalid Forge heartbeat positive uint64.');
  }
  return number;
}

Object? _restoreHeartbeatUint64Markers(Object? value) {
  if (value is String && value == _forgeDeviceHeartbeatMaxUint64Marker) {
    return _forgeDeviceHeartbeatMaxUint64;
  }
  if (value is List) {
    return value.map(_restoreHeartbeatUint64Markers).toList(growable: false);
  }
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(
          entry.key as String,
          _restoreHeartbeatUint64Markers(entry.value),
        ),
      ),
    );
  }
  return value;
}
