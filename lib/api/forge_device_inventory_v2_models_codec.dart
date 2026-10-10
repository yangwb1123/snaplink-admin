part of 'forge_device_inventory_v2_models.dart';

Map<String, dynamic> _v2Object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge v2 object.');
  }
  return Map<String, dynamic>.from(value);
}

void _v2ExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge v2 observation fields.');
  }
}

String _v2Identifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_v2ASCIIIdentifier(value)) {
    throw const FormatException('Invalid Forge v2 identifier.');
  }
  return value;
}

bool _v2ASCIIIdentifier(String value) {
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

int _v2PositiveInt(Object? value) {
  if (value is! int ||
      value <= 0 ||
      value > _forgeDeviceInventoryV2MaxSafeInteger) {
    throw const FormatException('Expected positive Forge v2 integer.');
  }
  return value;
}

int _v2NonNegativeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > _forgeDeviceInventoryV2MaxSafeInteger) {
    throw const FormatException('Expected non-negative Forge v2 integer.');
  }
  return value;
}

int _v2CapabilityBytes(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > _forgeDeviceInventoryV2MaxSafeInteger) {
    throw const FormatException('Invalid Forge v2 capability bytes.');
  }
  return value;
}

int _v2BoundedInt(Object? value, int maximum) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Invalid Forge v2 bounded integer.');
  }
  return value;
}

String _v2Token(Object? value, {int maxBytes = 64}) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maxBytes ||
      value.trim() != value ||
      value.codeUnits.any((unit) => !_v2TokenCode(unit))) {
    throw const FormatException('Invalid Forge v2 token.');
  }
  return value;
}

String _v2LowerToken(Object? value, {int maxBytes = 64}) {
  final token = _v2Token(value, maxBytes: maxBytes);
  if (token != token.toLowerCase()) {
    throw const FormatException('Invalid Forge v2 normalized token.');
  }
  return token;
}

bool _v2TokenCode(int code) =>
    code >= 0x30 && code <= 0x39 ||
    code >= 0x41 && code <= 0x5a ||
    code >= 0x61 && code <= 0x7a ||
    const [0x2e, 0x5f, 0x2b, 0x2d].contains(code);

String _v2Label(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.trim() != value ||
      utf8.encode(value).length > 64 ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge v2 label.');
  }
  return value;
}

String _v2OneOf(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException('Invalid Forge v2 enum.');
  }
  return value;
}

List<String> _v2Tokens(Object? value, int maximum) {
  if (value is! List || value.length > maximum) {
    throw const FormatException('Invalid Forge v2 token list.');
  }
  final tokens = value.map((entry) => _v2Token(entry)).toList(growable: false);
  if (tokens.any((token) => token != token.toLowerCase())) {
    throw const FormatException('Forge v2 tokens are not normalized.');
  }
  _v2RequireSortedUnique(tokens);
  return tokens;
}

List<String> _v2EnumList(Object? value, Set<String> allowed) {
  if (value is! List || value.length > _forgeDeviceInventoryV2MaxArrayItems) {
    throw const FormatException('Invalid Forge v2 enum list.');
  }
  final values = value
      .map((entry) => _v2OneOf(entry, allowed))
      .toList(growable: false);
  _v2RequireSortedUnique(values);
  return values;
}

void _v2RequireSortedUnique(List<String> values) {
  for (var index = 1; index < values.length; index++) {
    if (_v2CompareIDs(values[index - 1], values[index]) >= 0) {
      throw const FormatException(
        'Forge v2 values are unsorted or duplicated.',
      );
    }
  }
}

int _v2CompareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}

void _v2RejectDuplicateKeys(String source) {
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
        while (next < source.length && _v2Whitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException('Invalid Forge v2 JSON object key.');
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException('Duplicate Forge v2 JSON key.');
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
        throw const FormatException('Invalid Forge v2 JSON object.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge v2 JSON.');
  }
}

bool _v2Whitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
