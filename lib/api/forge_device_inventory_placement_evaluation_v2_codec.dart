part of 'forge_device_inventory_placement_evaluation_v2.dart';

Map<String, dynamic> _placementV2Object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge v2 placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _placementV2ExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge v2 placement fields.');
  }
}

int _placementV2PositiveInt(Object? value) {
  final integer = _placementV2SafeInt(value);
  if (integer == 0) {
    throw const FormatException(
      'Expected positive Forge v2 placement integer.',
    );
  }
  return integer;
}

int _placementV2PositiveOrZeroInt(Object? value) {
  return _placementV2SafeInt(value);
}

int _placementV2SafeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > forgeDeviceInventoryPlacementEvaluationV2MaxSafeInteger) {
    throw const FormatException('Invalid Forge v2 placement integer.');
  }
  return value;
}

int _placementV2BoundedInt(Object? value, int maximum) {
  final integer = _placementV2SafeInt(value);
  if (integer > maximum) {
    throw const FormatException('Invalid Forge v2 placement bound.');
  }
  return integer;
}

String _placementV2Identifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_placementV2ASCIIIdentifier(value)) {
    throw const FormatException('Invalid Forge v2 placement identifier.');
  }
  return value;
}

bool _placementV2ASCIIIdentifier(String value) {
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

int _placementV2Compare(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final comparison = left
        .codeUnitAt(index)
        .compareTo(right.codeUnitAt(index));
    if (comparison != 0) return comparison;
  }
  return left.length.compareTo(right.length);
}

void _placementV2RejectDuplicateKeys(String source) {
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
        while (next < source.length && _placementV2Whitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException('Invalid Forge v2 JSON object key.');
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException(
              'Duplicate Forge v2 placement-evaluation JSON key.',
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
        throw const FormatException('Invalid Forge v2 placement JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge v2 placement JSON.');
  }
}

bool _placementV2Whitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
