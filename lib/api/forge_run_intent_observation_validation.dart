part of 'forge_run_intent_observation.dart';

bool _identifier(String value) {
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

bool _runStatus(String status) => const {
  'nonterminal',
  'completed',
  'cancelled',
  'limit_exceeded',
  'failed',
}.contains(status);

Map<String, dynamic> _runIntentObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected Forge Run-intent object.');
  }
  return Map<String, dynamic>.from(value);
}

void _runIntentExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge Run-intent fields.');
  }
}

String _runIntentSchema(Object? value) {
  if (value != forgeRunIntentObservationSchema) {
    throw const FormatException('Invalid Forge Run-intent schema.');
  }
  return forgeRunIntentObservationSchema;
}

String _runIntentMode(Object? value) {
  if (value != 'offline_static_only') {
    throw const FormatException('Invalid Forge Run-intent evaluation mode.');
  }
  return 'offline_static_only';
}

String _runIntentIdentifier(Object? value) {
  if (value is! String || !_identifier(value)) {
    throw const FormatException('Invalid Forge Run-intent identifier.');
  }
  return value;
}

String? _runIntentNullableIdentifier(Object? value) {
  if (value == null) return null;
  return _runIntentIdentifier(value);
}

bool _runIntentBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge Run-intent boolean.');
  }
  return value;
}

int _runIntentNonNegativeInteger(Object? value) {
  if (value is! int || value < 0 || value > forgeRunIntentMaxSafeInteger) {
    throw const FormatException('Invalid Forge Run-intent integer.');
  }
  return value;
}

int _runIntentPositiveInteger(Object? value) {
  final result = _runIntentNonNegativeInteger(value);
  if (result == 0) {
    throw const FormatException('Invalid Forge Run-intent integer.');
  }
  return result;
}

int _runIntentCount(Object? value) {
  final result = _runIntentNonNegativeInteger(value);
  if (result > 128) {
    throw const FormatException('Invalid Forge Run-intent count.');
  }
  return result;
}

String _runIntentStatus(Object? value) {
  if (value is! String || !_runStatus(value)) {
    throw const FormatException('Invalid Forge Run-intent status.');
  }
  return value;
}
