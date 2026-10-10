part of 'forge_execution_reconciliation_observation.dart';

/// Strict, content-free result returned by the reconciliation preview.
class ForgeExecutionReconciliationObservation {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String commandID;
  final String targetID;
  final String runStatus;
  final String attemptState;
  final int leaseEpoch;
  final bool leaseActive;
  final int observedAtMS;
  final bool terminalObserved;
  final String terminalDisposition;
  final bool terminalStateAligned;
  final String nextObservation;
  final bool reconciliationRequired;
  final bool manualReviewRequired;
  final bool automaticRetry;
  final bool previewOnly;
  final ForgeExecutionReconciliationAuthority authority;

  const ForgeExecutionReconciliationObservation({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.commandID,
    required this.targetID,
    required this.runStatus,
    required this.attemptState,
    required this.leaseEpoch,
    required this.leaseActive,
    required this.observedAtMS,
    required this.terminalObserved,
    required this.terminalDisposition,
    required this.terminalStateAligned,
    required this.nextObservation,
    required this.reconciliationRequired,
    required this.manualReviewRequired,
    required this.automaticRetry,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgeExecutionReconciliationObservation.fromJson(Object? value) {
    final json = _reconciliationObject(value, 'observation');
    _reconciliationExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'command_id',
      'target_id',
      'run_status',
      'attempt_state',
      'lease_epoch',
      'lease_active',
      'observed_at_ms',
      'terminal_observed',
      'terminal_disposition',
      'terminal_state_aligned',
      'next_observation',
      'reconciliation_required',
      'manual_review_required',
      'automatic_retry',
      'preview_only',
      'authority',
    });
    final observation = ForgeExecutionReconciliationObservation(
      schemaVersion: _reconciliationSchema(json['schema_version']),
      evaluationMode: _reconciliationMode(json['evaluation_mode']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _reconciliationIdentifier(json['conversation_id']),
      runID: _reconciliationIdentifier(json['run_id']),
      attemptID: _reconciliationIdentifier(json['attempt_id']),
      commandID: _reconciliationIdentifier(json['command_id']),
      targetID: _reconciliationIdentifier(json['target_id']),
      runStatus: _reconciliationRunStatus(json['run_status']),
      attemptState: _reconciliationAttemptState(json['attempt_state']),
      leaseEpoch: _reconciliationPositiveSafeInteger(json['lease_epoch']),
      leaseActive: _reconciliationBool(json['lease_active']),
      observedAtMS: _reconciliationPositiveSafeInteger(json['observed_at_ms']),
      terminalObserved: _reconciliationBool(json['terminal_observed']),
      terminalDisposition: _reconciliationTerminalDisposition(
        json['terminal_disposition'],
      ),
      terminalStateAligned: _reconciliationBool(json['terminal_state_aligned']),
      nextObservation: _reconciliationNextObservation(json['next_observation']),
      reconciliationRequired: _reconciliationBool(
        json['reconciliation_required'],
      ),
      manualReviewRequired: _reconciliationBool(json['manual_review_required']),
      automaticRetry: _reconciliationBool(json['automatic_retry']),
      previewOnly: _reconciliationBool(json['preview_only']),
      authority: ForgeExecutionReconciliationAuthority.fromJson(
        json['authority'],
      ),
    );
    observation.validate();
    return observation;
  }

  factory ForgeExecutionReconciliationObservation.fromJsonText(String source) {
    _reconciliationRejectDuplicateJsonKeys(source);
    final decoded = jsonDecode(source);
    return ForgeExecutionReconciliationObservation.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'command_id': commandID,
    'target_id': targetID,
    'run_status': runStatus,
    'attempt_state': attemptState,
    'lease_epoch': leaseEpoch,
    'lease_active': leaseActive,
    'observed_at_ms': observedAtMS,
    'terminal_observed': terminalObserved,
    'terminal_disposition': terminalDisposition,
    'terminal_state_aligned': terminalStateAligned,
    'next_observation': nextObservation,
    'reconciliation_required': reconciliationRequired,
    'manual_review_required': manualReviewRequired,
    'automatic_retry': automaticRetry,
    'preview_only': previewOnly,
    'authority': authority.toJson(),
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  bool get isDisplayOnly {
    try {
      validate();
      return true;
    } on FormatException {
      return false;
    }
  }

  void validate() {
    if (schemaVersion != forgeExecutionReconciliationObservationSchema ||
        evaluationMode !=
            forgeExecutionReconciliationObservationEvaluationMode ||
        leaseEpoch < 1 ||
        leaseEpoch > forgeExecutionReconciliationMaxSafeInteger ||
        observedAtMS < 1 ||
        observedAtMS > forgeExecutionReconciliationMaxSafeInteger ||
        terminalObserved != (terminalDisposition != 'none') ||
        !previewOnly ||
        automaticRetry ||
        !authority.isOffline ||
        reconciliationRequired != _requiresReconciliation(nextObservation) ||
        manualReviewRequired != reconciliationRequired ||
        (!terminalObserved && !terminalStateAligned)) {
      throw const FormatException(
        'Forge execution reconciliation observation is not display-only.',
      );
    }
    final expected = _classify(
      runStatus,
      attemptState,
      leaseActive,
      terminalObserved,
      terminalDisposition,
      terminalStateAligned,
    );
    if (nextObservation != expected) {
      throw const FormatException(
        'Forge execution reconciliation classification is invalid.',
      );
    }
    if (nextObservation == 'terminal_completed' &&
        (terminalDisposition != 'completed' || !terminalStateAligned)) {
      throw const FormatException(
        'Forge execution reconciliation completed state is invalid.',
      );
    }
    if (nextObservation == 'terminal_failed' &&
        (terminalDisposition != 'failed' || !terminalStateAligned)) {
      throw const FormatException(
        'Forge execution reconciliation failed state is invalid.',
      );
    }
    if (nextObservation == 'terminal_uncertain' &&
        (terminalDisposition != 'uncertain' || !terminalStateAligned)) {
      throw const FormatException(
        'Forge execution reconciliation uncertain state is invalid.',
      );
    }
    if (nextObservation == 'terminal_state_conflict' &&
        (!terminalObserved || terminalStateAligned)) {
      throw const FormatException(
        'Forge execution reconciliation conflict state is invalid.',
      );
    }
    if (terminalObserved &&
        !terminalStateAligned &&
        nextObservation != 'terminal_state_conflict') {
      throw const FormatException(
        'Forge execution reconciliation terminal alignment is invalid.',
      );
    }
  }
}

/// Applies the same deterministic projection as Forge Core and Runtime.
ForgeExecutionReconciliationObservation observeForgeExecutionReconciliation(
  ForgeExecutionReconciliationInput input,
) {
  input.validate();
  final terminal = input.terminal;
  final terminalObserved = terminal != null;
  final terminalDisposition = terminal?.disposition.kind ?? 'none';
  final terminalStateAligned = terminal == null
      ? true
      : _terminalStateMatchesAttempt(terminalDisposition, input.attemptState);
  final leaseActive =
      BigInt.from(input.observedAtMS) >= input.lease.issuedAtMS &&
      BigInt.from(input.observedAtMS) < input.lease.expiresAtMS;
  final nextObservation = _classify(
    input.runStatus,
    input.attemptState,
    leaseActive,
    terminalObserved,
    terminalDisposition,
    terminalStateAligned,
  );
  final reconciliationRequired = _requiresReconciliation(nextObservation);
  return ForgeExecutionReconciliationObservation(
    schemaVersion: forgeExecutionReconciliationObservationSchema,
    evaluationMode: forgeExecutionReconciliationObservationEvaluationMode,
    owner: input.owner,
    conversationID: input.conversationID,
    runID: input.runID,
    attemptID: input.attemptID,
    commandID: input.commandID,
    targetID: input.targetID,
    runStatus: input.runStatus,
    attemptState: input.attemptState,
    leaseEpoch: input.lease.epoch.toInt(),
    leaseActive: leaseActive,
    observedAtMS: input.observedAtMS,
    terminalObserved: terminalObserved,
    terminalDisposition: terminalDisposition,
    terminalStateAligned: terminalStateAligned,
    nextObservation: nextObservation,
    reconciliationRequired: reconciliationRequired,
    manualReviewRequired: reconciliationRequired,
    automaticRetry: false,
    previewOnly: true,
    authority: const ForgeExecutionReconciliationAuthority.offline(),
  );
}
