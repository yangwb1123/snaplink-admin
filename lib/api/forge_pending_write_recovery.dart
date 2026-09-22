import 'dart:convert';

const forgePendingWriteRecoverySchema = 'forge.pending-write-recovery/v1';
const forgePendingWriteRecoveryEvaluationMode = 'pure_metadata_projection';
final _pendingRecoveryMaxUint64 = (BigInt.one << 64) - BigInt.one;

class ForgePendingWriteRecoveryMetadata {
  final String operation;
  final String? conversationID;
  final BigInt? expectedVersion;
  final String idempotencyKey;
  final String state;
  final BigInt? attemptedAtMS;
  final BigInt? lastObservedAtMS;

  const ForgePendingWriteRecoveryMetadata({
    required this.operation,
    required this.conversationID,
    required this.expectedVersion,
    required this.idempotencyKey,
    required this.state,
    required this.attemptedAtMS,
    required this.lastObservedAtMS,
  });

  factory ForgePendingWriteRecoveryMetadata.fromJson(Object? value) {
    final json = _pendingRecoveryObject(value);
    _pendingRecoveryExactKeys(json, {
      'operation',
      'conversation_id',
      'expected_version',
      'idempotency_key',
      'state',
      'attempted_at_ms',
      'last_observed_at_ms',
    });
    final operation = _pendingRecoveryText(json['operation']);
    final conversation = _pendingRecoveryNullableText(json['conversation_id']);
    final version = _pendingRecoveryNullableUint64(json['expected_version']);
    final state = _pendingRecoveryText(json['state']);
    return ForgePendingWriteRecoveryMetadata(
      operation: operation,
      conversationID: conversation,
      expectedVersion: version,
      idempotencyKey: _pendingRecoveryText(json['idempotency_key']),
      state: state,
      attemptedAtMS: _pendingRecoveryNullableUint64(json['attempted_at_ms']),
      lastObservedAtMS: _pendingRecoveryNullableUint64(
        json['last_observed_at_ms'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'operation': operation,
    'conversation_id': conversationID,
    'expected_version': expectedVersion?.toString(),
    'idempotency_key': idempotencyKey,
    'state': state,
    'attempted_at_ms': attemptedAtMS?.toString(),
    'last_observed_at_ms': lastObservedAtMS?.toString(),
  };
}

class ForgePendingWriteRecoveryProjection {
  final String schemaVersion;
  final String evaluationMode;
  final ForgePendingWriteRecoveryMetadata metadata;
  final bool pending;
  final bool unconfirmed;
  final bool retryAllowed;
  final bool sameKeyRequired;
  final bool reconcileBeforeRetry;

  const ForgePendingWriteRecoveryProjection({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.metadata,
    required this.pending,
    required this.unconfirmed,
    required this.retryAllowed,
    required this.sameKeyRequired,
    required this.reconcileBeforeRetry,
  });

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    ...metadata.toJson(),
    'pending': pending,
    'unconfirmed': unconfirmed,
    'retry_allowed': retryAllowed,
    'same_key_required': sameKeyRequired,
    'reconcile_before_retry': reconcileBeforeRetry,
  };
}

class ForgePendingWriteRecoveryError implements Exception {
  final String code;

  const ForgePendingWriteRecoveryError(this.code);

  @override
  String toString() => code;
}

/// Projects metadata without reading a clock, writing state, sending a
/// request, creating a Run, or carrying the original Prompt/title/scope body.
ForgePendingWriteRecoveryProjection projectForgePendingWriteRecovery(
  ForgePendingWriteRecoveryMetadata metadata,
) {
  if (!const {
    'append_prompt',
    'create_conversation',
  }.contains(metadata.operation)) {
    throw const ForgePendingWriteRecoveryError('invalid_operation');
  }
  if (!_pendingRecoveryKey(metadata.idempotencyKey)) {
    throw const ForgePendingWriteRecoveryError('invalid_idempotency_key');
  }
  if (metadata.operation == 'append_prompt') {
    if (metadata.conversationID == null ||
        !_pendingRecoveryIdentifier(metadata.conversationID!)) {
      throw const ForgePendingWriteRecoveryError('conversation_id_required');
    }
    if (metadata.expectedVersion == null) {
      throw const ForgePendingWriteRecoveryError('expected_version_required');
    }
  } else {
    if (metadata.conversationID != null) {
      throw const ForgePendingWriteRecoveryError('conversation_id_required');
    }
    if (metadata.expectedVersion != null) {
      throw const ForgePendingWriteRecoveryError('expected_version_forbidden');
    }
  }
  if (metadata.lastObservedAtMS != null &&
      metadata.attemptedAtMS != null &&
      metadata.lastObservedAtMS! < metadata.attemptedAtMS!) {
    throw const ForgePendingWriteRecoveryError('observation_time_regressed');
  }
  if (metadata.state != 'pending' && metadata.state != 'unconfirmed') {
    throw const ForgePendingWriteRecoveryError('invalid_state');
  }
  final unconfirmed = metadata.state == 'unconfirmed';
  return ForgePendingWriteRecoveryProjection(
    schemaVersion: forgePendingWriteRecoverySchema,
    evaluationMode: forgePendingWriteRecoveryEvaluationMode,
    metadata: metadata,
    pending: true,
    unconfirmed: unconfirmed,
    retryAllowed: true,
    sameKeyRequired: true,
    reconcileBeforeRetry: unconfirmed,
  );
}

Map<String, dynamic> decodeForgePendingWriteRecoveryJSON(String source) {
  final decoded = jsonDecode(source);
  return _pendingRecoveryObject(decoded);
}

Map<String, dynamic> _pendingRecoveryObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Forge pending-write metadata.');
  }
  return Map<String, dynamic>.from(value);
}

void _pendingRecoveryExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge pending-write fields.');
  }
}

String _pendingRecoveryText(Object? value) {
  if (value is! String || value.isEmpty || value != value.trim()) {
    throw const FormatException('Invalid Forge pending-write text.');
  }
  return value;
}

String? _pendingRecoveryNullableText(Object? value) {
  if (value == null) return null;
  return _pendingRecoveryText(value);
}

BigInt? _pendingRecoveryNullableUint64(Object? value) {
  if (value == null) return null;
  final parsed = switch (value) {
    BigInt integer => integer,
    int integer => BigInt.from(integer),
    String text when RegExp(r'^\d+$').hasMatch(text) => BigInt.parse(text),
    _ => throw const FormatException('Invalid Forge pending-write integer.'),
  };
  if (parsed < BigInt.zero || parsed > _pendingRecoveryMaxUint64) {
    throw const FormatException('Invalid Forge pending-write integer.');
  }
  return parsed;
}

bool _pendingRecoveryIdentifier(String value) {
  final bytes = utf8.encode(value);
  if (bytes.isEmpty || bytes.length > 128) return false;
  final codes = value.codeUnits;
  final first = codes.first;
  if (!_pendingRecoveryIdentifierStart(first)) return false;
  return codes.skip(1).every(_pendingRecoveryIdentifierPart);
}

bool _pendingRecoveryIdentifierStart(int code) =>
    code >= 0x30 && code <= 0x39 ||
    code >= 0x41 && code <= 0x5a ||
    code >= 0x61 && code <= 0x7a;

bool _pendingRecoveryIdentifierPart(int code) =>
    _pendingRecoveryIdentifierStart(code) ||
    const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code);

bool _pendingRecoveryKey(String value) {
  final bytes = utf8.encode(value);
  return value.isNotEmpty &&
      value == value.trim() &&
      bytes.length <= 256 &&
      !value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));
}
