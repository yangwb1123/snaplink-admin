part of 'forge_device_heartbeat.dart';

const _forgeHeartbeatMaxUint64Marker = '__forge_heartbeat_u64_max__';

String _markForgeHeartbeatMaxUint64(String source) => source.replaceAllMapped(
  RegExp(r'(:\s*)18446744073709551615(?=\s*[,}\]])'),
  (match) => '${match.group(1)}"$_forgeHeartbeatMaxUint64Marker"',
);

Map<String, dynamic> _heartbeatReferenceObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge heartbeat object.');
  }
  return Map<String, dynamic>.from(value);
}

void _heartbeatReferenceExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge heartbeat fields.');
  }
}

bool _heartbeatReferenceBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge heartbeat boolean.');
  }
  return value;
}

String _heartbeatReferenceText(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge heartbeat text.');
  }
  return value;
}

String _heartbeatReferenceIdentifier(Object? value) {
  final text = _heartbeatReferenceText(value);
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

BigInt _heartbeatReferenceUint64(Object? value) {
  final number = value is BigInt
      ? value
      : value is int
      ? BigInt.from(value)
      : null;
  if (number == null ||
      number < BigInt.zero ||
      number > _forgeHeartbeatMaxUint64) {
    throw const FormatException('Invalid Forge heartbeat uint64.');
  }
  return number;
}

BigInt _heartbeatReferencePositiveUint64(Object? value) {
  final number = _heartbeatReferenceUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException('Invalid Forge heartbeat positive uint64.');
  }
  return number;
}

Object? _restoreForgeHeartbeatUint64Markers(Object? value) {
  if (value is String && value == _forgeHeartbeatMaxUint64Marker) {
    return _forgeHeartbeatMaxUint64;
  }
  if (value is List) {
    return value
        .map(_restoreForgeHeartbeatUint64Markers)
        .toList(growable: false);
  }
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(
          entry.key as String,
          _restoreForgeHeartbeatUint64Markers(entry.value),
        ),
      ),
    );
  }
  return value;
}
