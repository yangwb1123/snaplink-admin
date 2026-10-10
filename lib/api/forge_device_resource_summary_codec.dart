part of 'forge_device_resource_summary.dart';

Map<String, dynamic> _summaryObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected Forge resource summary object.');
  }
  return Map<String, dynamic>.from(value);
}

void _summaryExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge resource summary fields.');
  }
}

String _summaryIdentifier(Object? value) {
  if (value is! String || !_identifier(value)) {
    throw const FormatException('Invalid Forge resource summary identifier.');
  }
  return value;
}

int _summarySafeInteger(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > forgeDeviceResourceSummaryMaxSafeInteger) {
    throw const FormatException('Invalid Forge resource summary integer.');
  }
  return value;
}

int _summaryPositiveSafeInteger(Object? value) {
  final parsed = _summarySafeInteger(value);
  if (parsed == 0) {
    throw const FormatException('Invalid Forge resource summary timestamp.');
  }
  return parsed;
}

int _summaryBoundedCount(Object? value) {
  final parsed = _summarySafeInteger(value);
  if (parsed > forgeDeviceResourceSummaryMaxDeclarations) {
    throw const FormatException('Invalid Forge resource summary count.');
  }
  return parsed;
}

void _summaryFixtureRejectDuplicateKeys(String source) {
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
        while (next < source.length && _summaryWhitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException('Invalid Forge resource summary key.');
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException(
              'Duplicate Forge resource summary key.',
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
        throw const FormatException('Invalid Forge resource summary object.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge resource summary JSON.');
  }
}

bool _summaryWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
