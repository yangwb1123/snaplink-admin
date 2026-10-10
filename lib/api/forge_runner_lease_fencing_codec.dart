part of 'forge_runner_lease_fencing.dart';

/// Dart's JSON decoder keeps the last value when an object repeats a key.
/// Runner lease fixtures are cross-runtime contracts, so reject ambiguity at
/// every object depth before materializing the map.
void _leaseRejectDuplicateKeys(String source) {
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
              'Duplicate Forge Runner lease fixture JSON key.',
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
        throw const FormatException('Invalid Forge Runner lease fixture JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty || escaped) {
    throw const FormatException('Invalid Forge Runner lease fixture JSON.');
  }
}

String _leaseOperation(Object? value) => _leaseOneOf(value, const {
  'active',
  'renew',
  'proof',
  'terminal',
  'terminal_replay',
  'terminal_conflict',
  'renew_after_terminal',
});

bool _leaseProofEquals(
  ForgeRunnerLeaseProof left,
  ForgeRunnerLeaseProof right,
) =>
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken;

bool _leaseDispositionEquals(
  ForgeRunnerLeaseDisposition left,
  ForgeRunnerLeaseDisposition right,
) =>
    left.kind == right.kind &&
    left.receiptSHA256 == right.receiptSHA256 &&
    left.reason == right.reason;

Map<String, dynamic> _leaseObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Forge Runner lease $label must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

void _leaseExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge Runner lease fields.');
  }
}

String _leaseText(Object? value, int maximum) {
  if (value is! String || !_validLeaseUnicode(value)) {
    throw const FormatException('Invalid Forge Runner lease text.');
  }
  final byteLength = utf8.encode(value).length;
  if (value.isEmpty ||
      byteLength > maximum ||
      value.trim() != value ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge Runner lease text.');
  }
  return value;
}

String _leaseIdentity(Object? value) => _leaseText(value, 128);

String _leaseToken(Object? value) => _leaseText(value, 256);

String _leaseReason(Object? value) => _leaseText(value, 256);

String _leaseDigest(Object? value) {
  final text = _leaseText(value, 64);
  if (text.length != 64 ||
      text.codeUnits.any(
        (code) =>
            !((code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66)),
      )) {
    throw const ForgeRunnerLeaseError('invalid_digest');
  }
  return text;
}

String _leaseOneOf(Object? value, Set<String> allowed) {
  final text = _leaseText(value, 64);
  if (!allowed.contains(text)) {
    throw FormatException('Invalid Forge Runner lease value: $text');
  }
  return text;
}

int _leaseVersion(Object? value) {
  if (value is! int || value != 1) {
    throw const ForgeRunnerLeaseError('unsupported_version');
  }
  return value;
}

bool _leaseBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge Runner lease boolean.');
  }
  return value;
}

BigInt _leaseUint64(Object? value) {
  final number = switch (value) {
    int value => BigInt.from(value),
    BigInt value => value,
    String value => BigInt.tryParse(value),
    _ => null,
  };
  if (number == null ||
      number.isNegative ||
      number > _forgeRunnerLeaseMaxUint64) {
    throw const FormatException('Invalid Forge Runner lease uint64.');
  }
  return number;
}

BigInt _leasePositiveUint64(Object? value) {
  final number = _leaseUint64(value);
  if (number == BigInt.zero) {
    throw const ForgeRunnerLeaseError('invalid_epoch');
  }
  return number;
}

void _leaseTTL(BigInt value) {
  if (value < BigInt.from(forgeRunnerLeaseFencingMinTTLMS) ||
      value > BigInt.from(forgeRunnerLeaseFencingMaxTTLMS)) {
    throw const ForgeRunnerLeaseError('invalid_lease_duration');
  }
}

Object _leaseJsonUint64(BigInt value) =>
    value <= BigInt.from(9007199254740991) ? value.toInt() : value.toString();

bool _validLeaseUnicode(String value) {
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
