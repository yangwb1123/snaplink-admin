part of 'forge_pending_run_intent.dart';

Map<String, dynamic> _pendingIntentObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Forge pending Run-intent $label must be an object.');
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _pendingIntentExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Forge pending Run-intent fixture has unknown or missing fields.',
    );
  }
}

bool _pendingIntentBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Forge pending Run-intent flag must be boolean.',
    );
  }
  return value;
}

String _pendingIntentText(Object? value, String label) {
  if (value is! String || value.isEmpty || value.length > 512) {
    throw FormatException('Invalid Forge pending Run-intent $label.');
  }
  return value;
}

String _pendingIntentContent(Object? value) {
  if (value is! String || value.trim().isEmpty || value.length > 256 * 1024) {
    throw const FormatException('Invalid Forge pending Run-intent prompt.');
  }
  return value;
}

int _pendingIntentSafeUInt(Object? value, String label) {
  if (value is! int ||
      value < 0 ||
      value > forgePendingRunIntentMaxSafeInteger) {
    throw FormatException('Invalid Forge pending Run-intent $label.');
  }
  return value;
}

void _pendingIntentRejectDuplicateKeys(String source) {
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
              'Duplicate Forge pending Run-intent JSON key.',
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
        throw const FormatException('Invalid Forge pending Run-intent JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge pending Run-intent JSON.');
  }
}
