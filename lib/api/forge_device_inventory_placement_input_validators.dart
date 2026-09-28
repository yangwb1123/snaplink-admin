part of 'forge_device_inventory_placement_input.dart';

Map<String, dynamic> _placementInputObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge placement-input object.');
  }
  return Map<String, dynamic>.from(value);
}

void _placementInputExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge placement-input fields.');
  }
}

bool _placementInputBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge placement-input boolean.');
  }
  return value;
}

String _placementInputError(Object? value) {
  if (value is! String || value.trim() != value || value.length > 128) {
    throw const FormatException('Invalid Forge placement-input error.');
  }
  return value;
}

String _placementInputIdentifier(Object? value) {
  if (value is! String || value.isEmpty || value.length > 128) {
    throw const FormatException('Invalid Forge placement-input identifier.');
  }
  final codes = value.codeUnits;
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
    throw const FormatException('Invalid Forge placement-input identifier.');
  }
  return value;
}

String _placementInputOneOfText(Object? value, Set<String> choices) {
  if (value is! String || !choices.contains(value)) {
    throw const FormatException('Invalid Forge placement-input state.');
  }
  return value;
}

bool _placementInputOneOf(Object? value, Set<String> choices) =>
    value is String && choices.contains(value);

List<String> _placementInputTokens(Object? value) {
  if (value is! List || value.length > 32) {
    throw const FormatException('Invalid Forge placement-input token list.');
  }
  final tokens = value
      .map((item) {
        if (item is! String ||
            item.isEmpty ||
            item.length > 128 ||
            item.codeUnits.any(
              (code) =>
                  !((code >= 0x30 && code <= 0x39) ||
                      (code >= 0x41 && code <= 0x5a) ||
                      (code >= 0x61 && code <= 0x7a) ||
                      code == 0x2e ||
                      code == 0x5f ||
                      code == 0x2d ||
                      code == 0x2b),
            )) {
          throw const FormatException('Invalid Forge placement-input token.');
        }
        return item;
      })
      .toList(growable: false);
  return tokens;
}

List<String> _placementInputZones(Object? value) {
  final zones = _placementInputTokens(value);
  for (final zone in zones) {
    if (zone.length > 64 ||
        zone.codeUnits.any(
          (code) =>
              !((code >= 0x30 && code <= 0x39) ||
                  (code >= 0x41 && code <= 0x5a) ||
                  (code >= 0x61 && code <= 0x7a) ||
                  code == 0x2e ||
                  code == 0x5f ||
                  code == 0x2d),
        )) {
      throw const FormatException('Invalid Forge placement-input zone.');
    }
  }
  return zones;
}

bool _placementInputSortedUnique(List<String> values) {
  for (var index = 1; index < values.length; index++) {
    if (values[index - 1].compareTo(values[index]) >= 0) return false;
  }
  return true;
}

BigInt _placementInputUint64(Object? value) {
  final number = value is BigInt
      ? value
      : value is int
      ? BigInt.from(value)
      : null;
  if (number == null ||
      number < BigInt.zero ||
      number > _placementInputMaxUint64) {
    throw const FormatException('Invalid Forge placement-input uint64.');
  }
  return number;
}

BigInt _placementInputPositiveUint64(Object? value) {
  final number = _placementInputUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException(
      'Invalid Forge placement-input positive uint64.',
    );
  }
  return number;
}

BigInt _placementInputSafeInteger(Object? value) {
  final number = _placementInputUint64(value);
  if (number > BigInt.from(9007199254740991)) {
    throw const FormatException('Unsafe Forge placement-input integer.');
  }
  return number;
}

int _placementInputBoundedInt(
  Object? value,
  int maximum, {
  bool positive = false,
}) {
  if (value is! int ||
      value < 0 ||
      value > maximum ||
      (positive && value == 0)) {
    throw const FormatException('Invalid Forge placement-input integer.');
  }
  return value;
}
