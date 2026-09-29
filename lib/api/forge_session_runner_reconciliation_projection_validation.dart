part of 'forge_session_runner_reconciliation_projection.dart';

Map<String, dynamic> _projectionObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Expected session Runner reconciliation projection $label object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _projectionExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.toSet().difference(expected).isNotEmpty) {
    throw const FormatException(
      'Unknown or missing session Runner reconciliation projection field.',
    );
  }
}

String _projectionSchema(Object? value) {
  if (value != forgeSessionRunnerReconciliationProjectionSchema) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection schema.',
    );
  }
  return forgeSessionRunnerReconciliationProjectionSchema;
}

String _projectionMode(Object? value) {
  if (value != forgeSessionRunnerReconciliationProjectionEvaluationMode) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection mode.',
    );
  }
  return forgeSessionRunnerReconciliationProjectionEvaluationMode;
}

String _projectionSourceSchema(Object? value) {
  if (value != forgeSessionRunnerReconciliationProjectionSourceSchema) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection source schema.',
    );
  }
  return forgeSessionRunnerReconciliationProjectionSourceSchema;
}

String _projectionIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_projectionToken(value)) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection identifier.',
    );
  }
  return value;
}

String? _projectionNullableIdentifier(Object? value) {
  if (value == null) return null;
  return _projectionIdentifier(value);
}

bool _projectionToken(String value) {
  for (var index = 0; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    final alphaNumeric =
        (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5a) ||
        (code >= 0x61 && code <= 0x7a);
    if (!alphaNumeric &&
        !(code == 0x2e ||
            code == 0x5f ||
            code == 0x3a ||
            code == 0x2b ||
            code == 0x2f ||
            code == 0x2d)) {
      return false;
    }
  }
  return true;
}

int _projectionSafeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > forgeSessionRunnerReconciliationProjectionMaxSafeInteger) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection integer.',
    );
  }
  return value;
}

int _projectionAttemptCount(Object? value) {
  final count = _projectionSafeInt(value);
  if (count < 1 ||
      count > forgeSessionRunnerReconciliationProjectionMaxAttempts) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection attempt count.',
    );
  }
  return count;
}

bool _projectionBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection boolean.',
    );
  }
  return value;
}

String _projectionDisposition(Object? value) {
  if (value != 'uncertain') {
    throw const FormatException(
      'Invalid session Runner reconciliation projection disposition.',
    );
  }
  return 'uncertain';
}

String _projectionOneOf(Object? value, Set<String> allowed) {
  if (value is! String || !allowed.contains(value)) {
    throw const FormatException(
      'Invalid session Runner reconciliation projection token.',
    );
  }
  return value;
}
