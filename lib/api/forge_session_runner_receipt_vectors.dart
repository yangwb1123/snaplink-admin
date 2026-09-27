import 'dart:convert';

import 'forge_json_strict.dart';
import 'forge_session_runner_receipt_observation.dart';

/// Canonical multi-outcome value consumed by the shared Web/App/Mobile
/// Sessions surface.  It is deliberately an offline projection: importing
/// it never contacts Forge and never turns a receipt into execution authority.
const forgeSessionRunnerReceiptVectorsSchema =
    'forge.session-runner-receipt-vectors/v1';
const forgeSessionRunnerReceiptVectorsEvaluationMode =
    'pure_session_runner_receipt_vectors_only';
const forgeSessionRunnerReceiptVectorsMaxBytes = 2 * 1024 * 1024;

typedef ForgeSessionRunnerReceiptVectorsFileReader = Future<String?> Function();

class ForgeSessionRunnerReceiptVectorExpected {
  final String commandID;
  final String commandSHA256;
  final String attemptID;
  final String targetID;
  final String dispositionKind;
  final int observedAtMS;
  final bool uncertain;
  final bool reconciliationRequired;
  final bool manualReviewRequired;
  final bool automaticRetry;
  final String followUp;

  const ForgeSessionRunnerReceiptVectorExpected({
    required this.commandID,
    required this.commandSHA256,
    required this.attemptID,
    required this.targetID,
    required this.dispositionKind,
    required this.observedAtMS,
    required this.uncertain,
    required this.reconciliationRequired,
    required this.manualReviewRequired,
    required this.automaticRetry,
    required this.followUp,
  });

  factory ForgeSessionRunnerReceiptVectorExpected.fromJson(Object? value) {
    final json = _vectorsObject(value, 'expected');
    _vectorsExactKeys(json, {
      'command_id',
      'command_sha256',
      'attempt_id',
      'target_id',
      'disposition_kind',
      'observed_at_ms',
      'uncertain',
      'reconciliation_required',
      'manual_review_required',
      'automatic_retry',
      'follow_up',
    });
    return ForgeSessionRunnerReceiptVectorExpected(
      commandID: _vectorsText(json['command_id']),
      commandSHA256: _vectorsText(json['command_sha256']),
      attemptID: _vectorsText(json['attempt_id']),
      targetID: _vectorsText(json['target_id']),
      dispositionKind: _vectorsText(json['disposition_kind']),
      observedAtMS: _vectorsSafeInt(json['observed_at_ms']),
      uncertain: _vectorsBool(json['uncertain']),
      reconciliationRequired: _vectorsBool(json['reconciliation_required']),
      manualReviewRequired: _vectorsBool(json['manual_review_required']),
      automaticRetry: _vectorsBool(json['automatic_retry']),
      followUp: _vectorsText(json['follow_up']),
    );
  }

  Map<String, dynamic> toJson() => {
    'command_id': commandID,
    'command_sha256': commandSHA256,
    'attempt_id': attemptID,
    'target_id': targetID,
    'disposition_kind': dispositionKind,
    'observed_at_ms': observedAtMS,
    'uncertain': uncertain,
    'reconciliation_required': reconciliationRequired,
    'manual_review_required': manualReviewRequired,
    'automatic_retry': automaticRetry,
    'follow_up': followUp,
  };

  bool matches(ForgeSessionRunnerReceiptObservation observation) {
    final receipt = observation.receiptObservation;
    return receipt.commandID == commandID &&
        receipt.commandSHA256 == commandSHA256 &&
        receipt.attemptID == attemptID &&
        receipt.targetID == targetID &&
        receipt.dispositionKind == dispositionKind &&
        receipt.observedAtMS == observedAtMS &&
        receipt.uncertain == uncertain &&
        receipt.reconciliationRequired == reconciliationRequired &&
        receipt.manualReviewRequired == manualReviewRequired &&
        receipt.automaticRetry == automaticRetry &&
        receipt.followUp == followUp;
  }
}

class ForgeSessionRunnerReceiptVector {
  final String name;
  final ForgeSessionRunnerReceiptObservation observation;
  final ForgeSessionRunnerReceiptVectorExpected expected;

  const ForgeSessionRunnerReceiptVector({
    required this.name,
    required this.observation,
    required this.expected,
  });

  factory ForgeSessionRunnerReceiptVector.fromJson(Object? value) {
    final json = _vectorsObject(value, 'vector');
    _vectorsExactKeys(json, {'name', 'observation', 'expected'});
    final vector = ForgeSessionRunnerReceiptVector(
      name: _vectorsName(json['name']),
      observation: ForgeSessionRunnerReceiptObservation.fromJson(
        json['observation'],
      ),
      expected: ForgeSessionRunnerReceiptVectorExpected.fromJson(
        json['expected'],
      ),
    );
    if (!vector.expected.matches(vector.observation)) {
      throw const FormatException(
        'Session Runner receipt vector expectation drifted.',
      );
    }
    return vector;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'observation': observation.toJson(),
    'expected': expected.toJson(),
  };
}

class ForgeSessionRunnerReceiptVectors {
  final String schemaVersion;
  final String evaluationMode;
  final Map<String, bool> authority;
  final List<ForgeSessionRunnerReceiptVector> vectors;

  const ForgeSessionRunnerReceiptVectors({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.authority,
    required this.vectors,
  });

  factory ForgeSessionRunnerReceiptVectors.fromJsonText(String source) {
    if (source.isEmpty ||
        source.length > forgeSessionRunnerReceiptVectorsMaxBytes) {
      throw const FormatException(
        'Session Runner receipt vectors exceed the size limit.',
      );
    }
    rejectDuplicateForgeJsonKeys(source);
    final decoded = jsonDecode(source);
    return ForgeSessionRunnerReceiptVectors.fromJson(decoded);
  }

  factory ForgeSessionRunnerReceiptVectors.fromJson(Object? value) {
    final json = _vectorsObject(value, 'root');
    _vectorsExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'authority',
      'vectors',
    });
    final authorityJSON = _vectorsObject(json['authority'], 'authority');
    _vectorsExactKeys(authorityJSON, {
      'identity_verified',
      'receipt_persisted',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = <String, bool>{
      for (final key in authorityJSON.keys)
        key: _vectorsBool(authorityJSON[key]),
    };
    if (authority.values.any((value) => value)) {
      throw const FormatException(
        'Session Runner receipt vectors claim authority.',
      );
    }
    final rawVectors = json['vectors'];
    if (rawVectors is! List || rawVectors.length != 3) {
      throw const FormatException(
        'Session Runner receipt vectors must contain three outcomes.',
      );
    }
    final vectors = rawVectors
        .map(ForgeSessionRunnerReceiptVector.fromJson)
        .toList(growable: false);
    final names = vectors.map((vector) => vector.name).toSet();
    if (names.length != vectors.length ||
        !names.containsAll({'completed', 'failed', 'uncertain'})) {
      throw const FormatException(
        'Session Runner receipt vectors must cover all outcomes once.',
      );
    }
    return ForgeSessionRunnerReceiptVectors(
      schemaVersion: _vectorsSchema(json['schema_version']),
      evaluationMode: _vectorsMode(json['evaluation_mode']),
      authority: Map.unmodifiable(authority),
      vectors: List.unmodifiable(vectors),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'authority': authority,
    'vectors': vectors.map((vector) => vector.toJson()).toList(growable: false),
  };

  bool get isDisplayOnly =>
      schemaVersion == forgeSessionRunnerReceiptVectorsSchema &&
      evaluationMode == forgeSessionRunnerReceiptVectorsEvaluationMode &&
      authority.values.every((value) => !value) &&
      vectors.length == 3;
}

Map<String, dynamic> _vectorsObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Expected session Runner receipt vectors $label object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _vectorsExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw const FormatException(
      'Unknown or missing session Runner receipt vectors field.',
    );
  }
}

String _vectorsSchema(Object? value) {
  if (value != forgeSessionRunnerReceiptVectorsSchema) {
    throw const FormatException(
      'Invalid session Runner receipt vectors schema.',
    );
  }
  return forgeSessionRunnerReceiptVectorsSchema;
}

String _vectorsMode(Object? value) {
  if (value != forgeSessionRunnerReceiptVectorsEvaluationMode) {
    throw const FormatException('Invalid session Runner receipt vectors mode.');
  }
  return forgeSessionRunnerReceiptVectorsEvaluationMode;
}

String _vectorsText(Object? value) {
  if (value is! String || value.isEmpty || value.length > 256) {
    throw const FormatException('Invalid session Runner receipt vector text.');
  }
  return value;
}

String _vectorsName(Object? value) {
  final name = _vectorsText(value);
  if (!{'completed', 'failed', 'uncertain'}.contains(name)) {
    throw const FormatException('Invalid session Runner receipt vector name.');
  }
  return name;
}

bool _vectorsBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Invalid session Runner receipt vector boolean.',
    );
  }
  return value;
}

int _vectorsSafeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > forgeSessionRunnerReceiptObservationMaxSafeInteger) {
    throw const FormatException('Invalid session Runner receipt vector time.');
  }
  return value;
}
