part of 'forge_session_placement.dart';

bool _sessionPlacementToken(String value) {
  if (value.isEmpty || value.length > 128) return false;
  final codes = value.codeUnits;
  final first = codes.first;
  if (!((first >= 0x30 && first <= 0x39) ||
      (first >= 0x41 && first <= 0x5a) ||
      (first >= 0x61 && first <= 0x7a))) {
    return false;
  }
  return codes
      .skip(1)
      .every(
        (code) =>
            code >= 0x30 && code <= 0x39 ||
            code >= 0x41 && code <= 0x5a ||
            code >= 0x61 && code <= 0x7a ||
            const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
      );
}

Map<String, dynamic> _sessionPlacementObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected Forge session placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _sessionPlacementExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge session placement observation fields.',
    );
  }
}

String _sessionPlacementParseIdentifier(Object? value) {
  if (value is! String || !_sessionPlacementToken(value)) {
    throw const FormatException('Invalid Forge session placement identifier.');
  }
  return value;
}

String _sessionPlacementParseToken(Object? value) {
  if (value is! String || !_sessionPlacementToken(value)) {
    throw const FormatException('Invalid Forge session placement token.');
  }
  return value;
}

int _sessionPlacementPositiveSafeInteger(Object? value) {
  if (value is! int ||
      value <= 0 ||
      value > forgeSessionPlacementObservationMaxSafeInteger) {
    throw const FormatException(
      'Invalid Forge session placement observation integer.',
    );
  }
  return value;
}

int _sessionPlacementCompareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
