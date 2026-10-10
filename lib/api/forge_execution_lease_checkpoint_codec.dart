part of 'forge_execution_lease_checkpoint.dart';

Map<String, dynamic> _checkpointObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException(
      'Execution lease checkpoint $label must be an object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _checkpointExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected execution lease checkpoint fields.',
    );
  }
}

String _checkpointSchema(Object? value) {
  final text = _checkpointText(value, 128);
  if (text != forgeExecutionLeaseCheckpointSchema) {
    throw const FormatException('Invalid execution lease checkpoint schema.');
  }
  return text;
}

String _checkpointMode(Object? value) {
  final text = _checkpointText(value, 128);
  if (text != forgeExecutionLeaseCheckpointEvaluationMode) {
    throw const FormatException('Invalid execution lease checkpoint mode.');
  }
  return text;
}

String _checkpointText(Object? value, int maximum) {
  if (value is! String || !_checkpointValidUnicode(value)) {
    throw const FormatException('Invalid execution lease checkpoint text.');
  }
  final byteLength = utf8.encode(value).length;
  if (value.isEmpty ||
      byteLength > maximum ||
      value.trim() != value ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid execution lease checkpoint text.');
  }
  return value;
}

String _checkpointIdentity(Object? value) => _checkpointText(value, 128);

String _checkpointToken(Object? value) => _checkpointText(value, 256);

String _checkpointReason(Object? value) => _checkpointText(value, 256);

String _checkpointDigest(Object? value) {
  final text = _checkpointText(value, 64);
  if (text.length != 64 ||
      text.codeUnits.any(
        (code) =>
            !((code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66)),
      )) {
    throw const FormatException('Invalid execution lease checkpoint digest.');
  }
  return text;
}

String _checkpointOneOf(Object? value, Set<String> allowed) {
  final text = _checkpointText(value, 64);
  if (!allowed.contains(text)) {
    throw FormatException('Invalid execution lease checkpoint value: $text');
  }
  return text;
}

int _checkpointVersion(Object? value) {
  if (value is! int || value != 1) {
    throw const FormatException(
      'Unsupported execution lease checkpoint version.',
    );
  }
  return value;
}

bool _checkpointBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid execution lease checkpoint boolean.');
  }
  return value;
}

BigInt _checkpointUint64(Object? value) {
  final number = switch (value) {
    int value => BigInt.from(value),
    BigInt value => value,
    String value => BigInt.tryParse(value),
    _ => null,
  };
  if (number == null || number.isNegative || number > _checkpointMaxUint64) {
    throw const FormatException('Invalid execution lease checkpoint uint64.');
  }
  return number;
}

BigInt _checkpointPositiveUint64(Object? value) {
  final number = _checkpointUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException('Invalid execution lease checkpoint epoch.');
  }
  return number;
}

Object _checkpointJsonUint64(BigInt value) =>
    value <= BigInt.from(9007199254740991) ? value.toInt() : value.toString();

bool _checkpointGrantEquals(
  ForgeExecutionLeaseCheckpointGrant left,
  ForgeExecutionLeaseCheckpointGrant right,
) =>
    left.version == right.version &&
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken &&
    left.issuedAtMS == right.issuedAtMS &&
    left.expiresAtMS == right.expiresAtMS;

bool _checkpointValidUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= (0xdb00 + 0xff)) {
      if (index + 1 >= value.length) return false;
      final next = value.codeUnitAt(++index);
      if (next < 0xdc00 || next > 0xdfff) return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

/// Dart's JSON decoder keeps the last value when an object repeats a key.
/// Cross-runtime fixtures reject that ambiguity before map materialization.
void _checkpointRejectDuplicateKeys(String source) {
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
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate execution lease checkpoint JSON key.',
            );
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
        throw const FormatException('Invalid execution lease checkpoint JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty || escaped) {
    throw const FormatException('Invalid execution lease checkpoint JSON.');
  }
}
