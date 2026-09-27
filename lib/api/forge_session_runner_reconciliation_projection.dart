import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';

const forgeSessionRunnerReconciliationProjectionSchema =
    'forge.session-runner-reconciliation-projection/v1';
const forgeSessionRunnerReconciliationProjectionEvaluationMode =
    'pure_session_runner_reconciliation_projection_only';
const forgeSessionRunnerReconciliationProjectionSourceSchema =
    'forge.session-runner-receipt-history/v1';
const forgeSessionRunnerReconciliationProjectionMaxBytes = 2 * 1024 * 1024;
const forgeSessionRunnerReconciliationProjectionMaxAttempts = 16;
const forgeSessionRunnerReconciliationProjectionMaxSafeInteger =
    9007199254740991;

typedef ForgeSessionRunnerReconciliationProjectionFileReader =
    Future<String?> Function();

/// Display-only manual reconciliation metadata derived from an uncertain
/// terminal session Runner receipt history. It never authorizes a retry,
/// target, lease, Runner action, persistence operation, or Audit publication.
class ForgeSessionRunnerReconciliationProjection {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String promptID;
  final String runID;
  final ForgeSessionRunnerReconciliationProjectionSource source;
  final String latestAttemptID;
  final String latestCommandID;
  final String latestTargetID;
  final String latestDispositionKind;
  final int latestObservedAtMS;
  final String reconciliationKind;
  final String reconciliationReason;
  final bool reconciliationRequired;
  final bool manualReviewRequired;
  final bool automaticRetry;
  final String followUp;
  final String? selectedTargetID;
  final bool previewOnly;
  final ForgeSessionRunnerReconciliationProjectionAuthority authority;

  const ForgeSessionRunnerReconciliationProjection({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.promptID,
    required this.runID,
    required this.source,
    required this.latestAttemptID,
    required this.latestCommandID,
    required this.latestTargetID,
    required this.latestDispositionKind,
    required this.latestObservedAtMS,
    required this.reconciliationKind,
    required this.reconciliationReason,
    required this.reconciliationRequired,
    required this.manualReviewRequired,
    required this.automaticRetry,
    required this.followUp,
    required this.selectedTargetID,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgeSessionRunnerReconciliationProjection.fromJsonText(
    String source,
  ) {
    if (source.isEmpty ||
        source.length > forgeSessionRunnerReconciliationProjectionMaxBytes) {
      throw const FormatException(
        'Session Runner reconciliation projection exceeds the size limit.',
      );
    }
    rejectDuplicateForgeJsonKeys(source);
    return ForgeSessionRunnerReconciliationProjection.fromJson(
      jsonDecode(source),
    );
  }

  factory ForgeSessionRunnerReconciliationProjection.fromJson(Object? value) {
    final json = _projectionObject(value, 'root');
    _projectionExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'prompt_id',
      'run_id',
      'source',
      'latest_attempt_id',
      'latest_command_id',
      'latest_target_id',
      'latest_disposition_kind',
      'latest_observed_at_ms',
      'reconciliation_kind',
      'reconciliation_reason',
      'reconciliation_required',
      'manual_review_required',
      'automatic_retry',
      'follow_up',
      'selected_target_id',
      'preview_only',
      'authority',
    });
    final projection = ForgeSessionRunnerReconciliationProjection(
      schemaVersion: _projectionSchema(json['schema_version']),
      evaluationMode: _projectionMode(json['evaluation_mode']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _projectionIdentifier(json['conversation_id']),
      promptID: _projectionIdentifier(json['prompt_id']),
      runID: _projectionIdentifier(json['run_id']),
      source: ForgeSessionRunnerReconciliationProjectionSource.fromJson(
        json['source'],
      ),
      latestAttemptID: _projectionIdentifier(json['latest_attempt_id']),
      latestCommandID: _projectionIdentifier(json['latest_command_id']),
      latestTargetID: _projectionIdentifier(json['latest_target_id']),
      latestDispositionKind: _projectionDisposition(
        json['latest_disposition_kind'],
      ),
      latestObservedAtMS: _projectionSafeInt(json['latest_observed_at_ms']),
      reconciliationKind: _projectionOneOf(json['reconciliation_kind'], {
        'manual',
      }),
      reconciliationReason: _projectionOneOf(json['reconciliation_reason'], {
        'uncertain_terminal_receipt',
      }),
      reconciliationRequired: _projectionBool(json['reconciliation_required']),
      manualReviewRequired: _projectionBool(json['manual_review_required']),
      automaticRetry: _projectionBool(json['automatic_retry']),
      followUp: _projectionOneOf(json['follow_up'], {'reconciliation_manual'}),
      selectedTargetID: _projectionNullableIdentifier(
        json['selected_target_id'],
      ),
      previewOnly: _projectionBool(json['preview_only']),
      authority: ForgeSessionRunnerReconciliationProjectionAuthority.fromJson(
        json['authority'],
      ),
    );
    projection._validate();
    return projection;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'prompt_id': promptID,
    'run_id': runID,
    'source': source.toJson(),
    'latest_attempt_id': latestAttemptID,
    'latest_command_id': latestCommandID,
    'latest_target_id': latestTargetID,
    'latest_disposition_kind': latestDispositionKind,
    'latest_observed_at_ms': latestObservedAtMS,
    'reconciliation_kind': reconciliationKind,
    'reconciliation_reason': reconciliationReason,
    'reconciliation_required': reconciliationRequired,
    'manual_review_required': manualReviewRequired,
    'automatic_retry': automaticRetry,
    'follow_up': followUp,
    'selected_target_id': selectedTargetID,
    'preview_only': previewOnly,
    'authority': authority.toJson(),
  };

  bool get isDisplayOnly =>
      schemaVersion == forgeSessionRunnerReconciliationProjectionSchema &&
      evaluationMode ==
          forgeSessionRunnerReconciliationProjectionEvaluationMode &&
      reconciliationKind == 'manual' &&
      reconciliationReason == 'uncertain_terminal_receipt' &&
      reconciliationRequired &&
      manualReviewRequired &&
      !automaticRetry &&
      followUp == 'reconciliation_manual' &&
      selectedTargetID == null &&
      previewOnly &&
      authority.isOffline;

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  void _validate() {
    if (!isDisplayOnly ||
        source.schemaVersion !=
            forgeSessionRunnerReconciliationProjectionSourceSchema ||
        source.owner != owner ||
        source.conversationID != conversationID ||
        source.promptID != promptID ||
        source.runID != runID ||
        source.attemptCount < 1 ||
        source.attemptCount >
            forgeSessionRunnerReconciliationProjectionMaxAttempts ||
        source.latestAttemptID != latestAttemptID ||
        source.latestCommandID != latestCommandID ||
        source.latestTargetID != latestTargetID ||
        source.latestDispositionKind != latestDispositionKind ||
        source.latestObservedAtMS != latestObservedAtMS ||
        latestDispositionKind != 'uncertain') {
      throw const FormatException(
        'Session Runner reconciliation projection is not bound or display-only.',
      );
    }
  }
}

class ForgeSessionRunnerReconciliationProjectionSource {
  final String schemaVersion;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String promptID;
  final String runID;
  final int attemptCount;
  final String latestAttemptID;
  final String latestCommandID;
  final String latestTargetID;
  final String latestDispositionKind;
  final int latestObservedAtMS;

  const ForgeSessionRunnerReconciliationProjectionSource({
    required this.schemaVersion,
    required this.owner,
    required this.conversationID,
    required this.promptID,
    required this.runID,
    required this.attemptCount,
    required this.latestAttemptID,
    required this.latestCommandID,
    required this.latestTargetID,
    required this.latestDispositionKind,
    required this.latestObservedAtMS,
  });

  factory ForgeSessionRunnerReconciliationProjectionSource.fromJson(
    Object? value,
  ) {
    final json = _projectionObject(value, 'source');
    _projectionExactKeys(json, {
      'schema_version',
      'owner',
      'conversation_id',
      'prompt_id',
      'run_id',
      'attempt_count',
      'latest_attempt_id',
      'latest_command_id',
      'latest_target_id',
      'latest_disposition_kind',
      'latest_observed_at_ms',
    });
    return ForgeSessionRunnerReconciliationProjectionSource(
      schemaVersion: _projectionSourceSchema(json['schema_version']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _projectionIdentifier(json['conversation_id']),
      promptID: _projectionIdentifier(json['prompt_id']),
      runID: _projectionIdentifier(json['run_id']),
      attemptCount: _projectionAttemptCount(json['attempt_count']),
      latestAttemptID: _projectionIdentifier(json['latest_attempt_id']),
      latestCommandID: _projectionIdentifier(json['latest_command_id']),
      latestTargetID: _projectionIdentifier(json['latest_target_id']),
      latestDispositionKind: _projectionDisposition(
        json['latest_disposition_kind'],
      ),
      latestObservedAtMS: _projectionSafeInt(json['latest_observed_at_ms']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'prompt_id': promptID,
    'run_id': runID,
    'attempt_count': attemptCount,
    'latest_attempt_id': latestAttemptID,
    'latest_command_id': latestCommandID,
    'latest_target_id': latestTargetID,
    'latest_disposition_kind': latestDispositionKind,
    'latest_observed_at_ms': latestObservedAtMS,
  };
}

class ForgeSessionRunnerReconciliationProjectionAuthority {
  final bool identityVerified;
  final bool receiptPersisted;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeSessionRunnerReconciliationProjectionAuthority({
    required this.identityVerified,
    required this.receiptPersisted,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeSessionRunnerReconciliationProjectionAuthority.fromJson(
    Object? value,
  ) {
    final json = _projectionObject(value, 'authority');
    _projectionExactKeys(json, {
      'identity_verified',
      'receipt_persisted',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeSessionRunnerReconciliationProjectionAuthority(
      identityVerified: _projectionBool(json['identity_verified']),
      receiptPersisted: _projectionBool(json['receipt_persisted']),
      executionAuthorized: _projectionBool(json['execution_authorized']),
      dispatchPerformed: _projectionBool(json['dispatch_performed']),
      auditPublished: _projectionBool(json['audit_published']),
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Session Runner reconciliation projection claims authority.',
      );
    }
    return authority;
  }

  Map<String, dynamic> toJson() => {
    'identity_verified': identityVerified,
    'receipt_persisted': receiptPersisted,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };

  bool get isOffline =>
      !identityVerified &&
      !receiptPersisted &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;
}

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
