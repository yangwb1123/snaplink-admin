part of 'forge_device_placement.dart';

Map<String, dynamic> _placementObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _placementExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge placement fields.');
  }
}

String _placementInvalid(String message) {
  throw FormatException(message);
}

String _placementToken(Object? value) {
  if (value is! String || !_placementTokenValue(value)) {
    throw const FormatException('Invalid Forge placement token.');
  }
  return value;
}

String _placementIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_placementIdentifierValue(value)) {
    throw const FormatException('Invalid Forge placement identifier.');
  }
  return value;
}

bool _placementIdentifierValue(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) || const [0x2e, 0x5f, 0x3a, 0x2d].contains(code);
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

bool _placementTokenValue(String value) {
  if (value.isEmpty || value.length > 128) return false;
  return value.codeUnits.every(
    (code) =>
        code >= 0x30 && code <= 0x39 ||
        code >= 0x41 && code <= 0x5a ||
        code >= 0x61 && code <= 0x7a ||
        const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
  );
}

String _placementOneOf(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('Invalid Forge placement enum.');
  }
  return value;
}

List<String> _placementZones(Object? value) {
  if (value is! List || value.isEmpty || value.length > 32) {
    throw const FormatException('Invalid Forge placement zones.');
  }
  final zones = value
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
          throw const FormatException('Invalid Forge placement zone.');
        }
        return item;
      })
      .toList(growable: false);
  if (zones.toSet().length != zones.length) {
    throw const FormatException('Duplicate Forge placement zones.');
  }
  return zones;
}

int _placementPositiveInt(Object? value, {int maximum = 9007199254740991}) {
  final result = _placementUint64(value);
  if (result == 0 || result > maximum) {
    throw const FormatException('Expected positive Forge placement integer.');
  }
  return result;
}

int _placementUint64(Object? value) {
  if (value is! int || value < 0 || value > 9007199254740991) {
    throw const FormatException('Invalid Forge placement integer.');
  }
  return value;
}

int _placementCompareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
