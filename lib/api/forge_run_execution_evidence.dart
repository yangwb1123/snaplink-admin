import 'dart:convert';

/// Strict, content-free binding of a Run observation to a Runner receipt
/// observation. This value is display evidence only; it does not establish
/// ownership, persistence, reservation, dispatch, or execution authority.
const forgeRunExecutionEvidenceSchema = 'forge.run.execution-evidence.v1';
const forgeRunExecutionEvidenceEvaluationMode =
    'pure_run_execution_evidence_binding';
const forgeRunExecutionEvidenceMaxSafeInteger = 9007199254740991;

class ForgeRunExecutionEvidenceAuthority {
  final bool identityVerified;
  final bool ownerAuthorized;
  final bool runAuthoritative;
  final bool receiptPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeRunExecutionEvidenceAuthority.offline()
    : identityVerified = false,
      ownerAuthorized = false,
      runAuthoritative = false,
      receiptPersisted = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  factory ForgeRunExecutionEvidenceAuthority.fromJson(Object? value) {
    final json = _executionEvidenceObject(value, 'authority');
    _executionEvidenceExactKeys(json, {
      'identity_verified',
      'owner_authorized',
      'run_authoritative',
      'receipt_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    for (final entry in json.entries) {
      if (entry.value is! bool || entry.value == true) {
        throw const FormatException('Run execution evidence claims authority.');
      }
    }
    return const ForgeRunExecutionEvidenceAuthority.offline();
  }

  Map<String, dynamic> toJson() => {
    'identity_verified': identityVerified,
    'owner_authorized': ownerAuthorized,
    'run_authoritative': runAuthoritative,
    'receipt_persisted': receiptPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };

  bool get isOffline =>
      !identityVerified &&
      !ownerAuthorized &&
      !runAuthoritative &&
      !receiptPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;
}

class ForgeRunExecutionEvidence {
  final String ownerRef;
  final String conversationID;
  final String runID;
  final String promptID;
  final String runStatus;
  final String attemptID;
  final String targetID;
  final String commandID;
  final String commandSHA256;
  final String dispositionKind;
  final int receiptObservedAtMS;
  final bool uncertain;
  final bool reconciliationRequired;
  final bool metadataObserved;
  final bool contentIncluded;
  final ForgeRunExecutionEvidenceAuthority authority;

  const ForgeRunExecutionEvidence({
    required this.ownerRef,
    required this.conversationID,
    required this.runID,
    required this.promptID,
    required this.runStatus,
    required this.attemptID,
    required this.targetID,
    required this.commandID,
    required this.commandSHA256,
    required this.dispositionKind,
    required this.receiptObservedAtMS,
    required this.uncertain,
    required this.reconciliationRequired,
    required this.metadataObserved,
    required this.contentIncluded,
    required this.authority,
  });

  factory ForgeRunExecutionEvidence.fromJson(Object? value) {
    final json = _executionEvidenceObject(value, 'value');
    _executionEvidenceExactKeys(json, {
      'api_version',
      'evaluation_mode',
      'owner_ref',
      'conversation_id',
      'run_id',
      'prompt_id',
      'run_status',
      'attempt_id',
      'target_id',
      'command_id',
      'command_sha256',
      'disposition_kind',
      'receipt_observed_at_ms',
      'uncertain',
      'reconciliation_required',
      'metadata_observed',
      'content_included',
      'authority',
    });
    final ownerRef = _executionEvidenceText(json['owner_ref'], 'owner_ref');
    final runStatus = _executionEvidenceText(json['run_status'], 'run_status');
    final dispositionKind = _executionEvidenceText(
      json['disposition_kind'],
      'disposition_kind',
    );
    final uncertain = _executionEvidenceBool(json['uncertain'], 'uncertain');
    final reconciliationRequired = _executionEvidenceBool(
      json['reconciliation_required'],
      'reconciliation_required',
    );
    final metadataObserved = _executionEvidenceBool(
      json['metadata_observed'],
      'metadata_observed',
    );
    final contentIncluded = _executionEvidenceBool(
      json['content_included'],
      'content_included',
    );
    if (_executionEvidenceText(json['api_version'], 'api_version') !=
            forgeRunExecutionEvidenceSchema ||
        _executionEvidenceText(json['evaluation_mode'], 'evaluation_mode') !=
            forgeRunExecutionEvidenceEvaluationMode ||
        !_executionEvidenceSHA256(ownerRef) ||
        !_executionEvidenceIdentifier(json['conversation_id']) ||
        !_executionEvidenceIdentifier(json['run_id']) ||
        !_executionEvidenceIdentifier(json['prompt_id']) ||
        !_executionEvidenceStatuses.contains(runStatus) ||
        !_executionEvidenceIdentifier(json['attempt_id']) ||
        !_executionEvidenceIdentifier(json['target_id']) ||
        !_executionEvidenceIdentifier(json['command_id']) ||
        !_executionEvidenceSHA256(
          _executionEvidenceText(json['command_sha256'], 'command_sha256'),
        ) ||
        !_executionEvidenceDispositions.contains(dispositionKind) ||
        !_executionEvidenceUncertainPair(
          dispositionKind,
          uncertain,
          reconciliationRequired,
        ) ||
        !_executionEvidenceSafeInt(json['receipt_observed_at_ms']) ||
        !metadataObserved ||
        contentIncluded) {
      throw const FormatException(
        'Invalid or content-bearing Run execution evidence.',
      );
    }
    return ForgeRunExecutionEvidence(
      ownerRef: ownerRef,
      conversationID: _executionEvidenceText(
        json['conversation_id'],
        'conversation_id',
      ),
      runID: _executionEvidenceText(json['run_id'], 'run_id'),
      promptID: _executionEvidenceText(json['prompt_id'], 'prompt_id'),
      runStatus: runStatus,
      attemptID: _executionEvidenceText(json['attempt_id'], 'attempt_id'),
      targetID: _executionEvidenceText(json['target_id'], 'target_id'),
      commandID: _executionEvidenceText(json['command_id'], 'command_id'),
      commandSHA256: _executionEvidenceText(
        json['command_sha256'],
        'command_sha256',
      ),
      dispositionKind: dispositionKind,
      receiptObservedAtMS: json['receipt_observed_at_ms'] as int,
      uncertain: uncertain,
      reconciliationRequired: reconciliationRequired,
      metadataObserved: metadataObserved,
      contentIncluded: contentIncluded,
      authority: ForgeRunExecutionEvidenceAuthority.fromJson(json['authority']),
    );
  }

  Map<String, dynamic> toJson() => {
    'api_version': forgeRunExecutionEvidenceSchema,
    'evaluation_mode': forgeRunExecutionEvidenceEvaluationMode,
    'owner_ref': ownerRef,
    'conversation_id': conversationID,
    'run_id': runID,
    'prompt_id': promptID,
    'run_status': runStatus,
    'attempt_id': attemptID,
    'target_id': targetID,
    'command_id': commandID,
    'command_sha256': commandSHA256,
    'disposition_kind': dispositionKind,
    'receipt_observed_at_ms': receiptObservedAtMS,
    'uncertain': uncertain,
    'reconciliation_required': reconciliationRequired,
    'metadata_observed': metadataObserved,
    'content_included': contentIncluded,
    'authority': authority.toJson(),
  };

  /// Returns whether this caller-supplied projection belongs to the selected
  /// Conversation and Run. The owner reference is intentionally only a
  /// digest, so the screen never derives an owner identity from it.
  bool isFor(String selectedConversationID, String selectedRunID) =>
      conversationID == selectedConversationID && runID == selectedRunID;

  bool get isDisplayOnly =>
      metadataObserved &&
      !contentIncluded &&
      authority.isOffline &&
      _executionEvidenceUncertainPair(
        dispositionKind,
        uncertain,
        reconciliationRequired,
      );
}

const _executionEvidenceStatuses = {
  'nonterminal',
  'completed',
  'cancelled',
  'limit_exceeded',
  'failed',
};
const _executionEvidenceDispositions = {'completed', 'failed', 'uncertain'};

Map<String, dynamic> _executionEvidenceObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Expected Run execution evidence $label object.');
  }
  return Map<String, dynamic>.from(value);
}

void _executionEvidenceExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unknown or missing Run execution evidence field.',
    );
  }
}

String _executionEvidenceText(Object? value, String label) {
  if (value is! String ||
      value.isEmpty ||
      value != value.trim() ||
      value.length > 128) {
    throw FormatException('Invalid Run execution evidence $label.');
  }
  return value;
}

bool _executionEvidenceBool(Object? value, String label) {
  if (value is! bool) {
    throw FormatException('Invalid Run execution evidence $label.');
  }
  return value;
}

bool _executionEvidenceSafeInt(Object? value) =>
    value is int &&
    value >= 0 &&
    value <= forgeRunExecutionEvidenceMaxSafeInteger;

bool _executionEvidenceIdentifier(Object? value) {
  if (value is! String || value.isEmpty || value.length > 85) return false;
  final bytes = utf8.encode(value).length;
  return bytes <= 85 &&
      !value.runes.any((rune) {
        if (rune < 0x20 || (rune >= 0x7f && rune <= 0x9f)) return true;
        if (String.fromCharCode(rune).trim().isEmpty) return true;
        return rune == 0x3a || rune == 0x2f || rune == 0x5c;
      });
}

bool _executionEvidenceSHA256(String value) =>
    RegExp(r'^[0-9a-f]{64}$').hasMatch(value);

bool _executionEvidenceUncertainPair(
  String disposition,
  bool uncertain,
  bool reconciliationRequired,
) =>
    (disposition == 'uncertain') == uncertain &&
    uncertain == reconciliationRequired;
