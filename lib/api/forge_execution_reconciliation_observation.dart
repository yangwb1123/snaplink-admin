import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_runner_lease_fencing.dart';

/// Pure, metadata-only execution reconciliation contract shared by Forge
/// Core, Runtime, and the Flutter Web/App/Mobile clients.
///
/// The request is a caller-supplied restart image. The observation only
/// classifies that image; it does not read durable state, renew a lease,
/// select a device, dispatch a process, retry a command, or publish audit.
const forgeExecutionReconciliationObservationSchema =
    'forge.execution-reconciliation-observation/v1';
const forgeExecutionReconciliationObservationEvaluationMode =
    'pure_execution_reconciliation_observation';
const forgeExecutionReconciliationMaxSafeInteger = 9007199254740991;

class ForgeExecutionReconciliationAuthority {
  final bool identityVerified;
  final bool runAuthoritative;
  final bool attemptPersisted;
  final bool leaseIssued;
  final bool terminalPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeExecutionReconciliationAuthority.offline()
    : identityVerified = false,
      runAuthoritative = false,
      attemptPersisted = false,
      leaseIssued = false,
      terminalPersisted = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  const ForgeExecutionReconciliationAuthority._({
    required this.identityVerified,
    required this.runAuthoritative,
    required this.attemptPersisted,
    required this.leaseIssued,
    required this.terminalPersisted,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeExecutionReconciliationAuthority.fromJson(Object? value) {
    final json = _reconciliationObject(value, 'authority');
    _reconciliationExactKeys(json, {
      'identity_verified',
      'run_authoritative',
      'attempt_persisted',
      'lease_issued',
      'terminal_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeExecutionReconciliationAuthority._(
      identityVerified: _reconciliationBool(json['identity_verified']),
      runAuthoritative: _reconciliationBool(json['run_authoritative']),
      attemptPersisted: _reconciliationBool(json['attempt_persisted']),
      leaseIssued: _reconciliationBool(json['lease_issued']),
      terminalPersisted: _reconciliationBool(json['terminal_persisted']),
      reservationCreated: _reconciliationBool(json['reservation_created']),
      executionAuthorized: _reconciliationBool(json['execution_authorized']),
      dispatchPerformed: _reconciliationBool(json['dispatch_performed']),
      auditPublished: _reconciliationBool(json['audit_published']),
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Forge execution reconciliation authority must remain false.',
      );
    }
    return authority;
  }

  bool get isOffline =>
      !identityVerified &&
      !runAuthoritative &&
      !attemptPersisted &&
      !leaseIssued &&
      !terminalPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'identity_verified': identityVerified,
    'run_authoritative': runAuthoritative,
    'attempt_persisted': attemptPersisted,
    'lease_issued': leaseIssued,
    'terminal_persisted': terminalPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

/// The optional terminal declaration included in an input restart image.
///
/// This is deliberately separate from the higher-level Runner terminal
/// receipt contract because reconciliation receives only the proof,
/// disposition, and observation time. It has no command output.
class ForgeExecutionReconciliationTerminal {
  final int version;
  final ForgeRunnerLeaseProof proof;
  final ForgeRunnerLeaseDisposition disposition;
  final int observedAtMS;

  const ForgeExecutionReconciliationTerminal({
    required this.version,
    required this.proof,
    required this.disposition,
    required this.observedAtMS,
  });

  factory ForgeExecutionReconciliationTerminal.fromJson(Object? value) {
    final json = _reconciliationObject(value, 'terminal');
    _reconciliationExactKeys(json, {
      'v',
      'proof',
      'disposition',
      'observed_at_ms',
    });
    final proofJSON = _reconciliationObject(json['proof'], 'terminal proof');
    if (proofJSON['epoch'] is! int) {
      throw const FormatException(
        'Forge execution reconciliation proof epoch must be a JSON integer.',
      );
    }
    final terminal = ForgeExecutionReconciliationTerminal(
      version: _reconciliationVersion(json['v']),
      proof: ForgeRunnerLeaseProof.fromJson(json['proof']),
      disposition: ForgeRunnerLeaseDisposition.fromJson(json['disposition']),
      observedAtMS: _reconciliationSafeInteger(json['observed_at_ms']),
    );
    terminal.validateShape();
    return terminal;
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'proof': proof.toJson(),
    'disposition': disposition.toJson(),
    'observed_at_ms': observedAtMS,
  };

  void validateShape() {
    if (version != 1 ||
        observedAtMS < 1 ||
        observedAtMS > forgeExecutionReconciliationMaxSafeInteger ||
        proof.epoch > BigInt.from(forgeExecutionReconciliationMaxSafeInteger)) {
      throw const FormatException(
        'Invalid Forge execution reconciliation terminal.',
      );
    }
    disposition.validate();
  }
}

/// Caller-supplied, owner-bound restart image sent to the candidate preview.
class ForgeExecutionReconciliationInput {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String commandID;
  final String targetID;
  final String runStatus;
  final String attemptState;
  final ForgeRunnerLeaseGrant lease;
  final int observedAtMS;
  final ForgeExecutionReconciliationTerminal? terminal;

  const ForgeExecutionReconciliationInput({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.commandID,
    required this.targetID,
    required this.runStatus,
    required this.attemptState,
    required this.lease,
    required this.observedAtMS,
    required this.terminal,
  });

  factory ForgeExecutionReconciliationInput.fromJson(Object? value) {
    final json = _reconciliationObject(value, 'input');
    _reconciliationExactKeys(json, {
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'command_id',
      'target_id',
      'run_status',
      'attempt_state',
      'lease',
      'observed_at_ms',
      'terminal',
    });
    final leaseJSON = _reconciliationObject(json['lease'], 'lease');
    for (final field in const ['v', 'epoch', 'issued_at_ms', 'expires_at_ms']) {
      if (leaseJSON[field] is! int) {
        throw const FormatException(
          'Forge execution reconciliation lease integer must be a JSON integer.',
        );
      }
    }
    final input = ForgeExecutionReconciliationInput(
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _reconciliationIdentifier(json['conversation_id']),
      runID: _reconciliationIdentifier(json['run_id']),
      attemptID: _reconciliationIdentifier(json['attempt_id']),
      commandID: _reconciliationIdentifier(json['command_id']),
      targetID: _reconciliationIdentifier(json['target_id']),
      runStatus: _reconciliationRunStatus(json['run_status']),
      attemptState: _reconciliationAttemptState(json['attempt_state']),
      lease: ForgeRunnerLeaseGrant.fromJson(json['lease']),
      observedAtMS: _reconciliationSafeInteger(json['observed_at_ms']),
      terminal: json['terminal'] == null
          ? null
          : ForgeExecutionReconciliationTerminal.fromJson(json['terminal']),
    );
    input.validate();
    return input;
  }

  /// Decodes a complete JSON value while rejecting duplicate keys at every
  /// object depth before Dart's map decoder can apply last-key-wins behavior.
  factory ForgeExecutionReconciliationInput.fromJsonText(String source) {
    _reconciliationRejectDuplicateJsonKeys(source);
    final decoded = jsonDecode(source);
    return ForgeExecutionReconciliationInput.fromJson(decoded);
  }

  Map<String, dynamic> toJson() => {
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'command_id': commandID,
    'target_id': targetID,
    'run_status': runStatus,
    'attempt_state': attemptState,
    'lease': lease.toJson(),
    'observed_at_ms': observedAtMS,
    'terminal': terminal?.toJson(),
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  void validate() {
    _reconciliationIdentifier(conversationID);
    _reconciliationIdentifier(runID);
    _reconciliationIdentifier(attemptID);
    _reconciliationIdentifier(commandID);
    _reconciliationIdentifier(targetID);
    _reconciliationRunStatus(runStatus);
    _reconciliationAttemptState(attemptState);
    if (observedAtMS < 1 ||
        observedAtMS > forgeExecutionReconciliationMaxSafeInteger ||
        lease.epoch < BigInt.one ||
        lease.epoch > BigInt.from(forgeExecutionReconciliationMaxSafeInteger) ||
        lease.issuedAtMS >
            BigInt.from(forgeExecutionReconciliationMaxSafeInteger) ||
        lease.expiresAtMS >
            BigInt.from(forgeExecutionReconciliationMaxSafeInteger)) {
      throw const FormatException(
        'Forge execution reconciliation value exceeds the safe integer range.',
      );
    }
    lease.validate();
    if (lease.attemptID != attemptID ||
        lease.targetID != targetID ||
        BigInt.from(observedAtMS) < lease.issuedAtMS) {
      throw const FormatException(
        'Forge execution reconciliation lease binding is invalid.',
      );
    }
    final terminal = this.terminal;
    if (terminal == null) return;
    terminal.validateShape();
    if (!_sameProof(terminal.proof, lease.proof()) ||
        terminal.observedAtMS < lease.issuedAtMS.toInt() ||
        terminal.observedAtMS >= lease.expiresAtMS.toInt() ||
        terminal.observedAtMS > observedAtMS) {
      throw const FormatException(
        'Forge execution reconciliation terminal binding is invalid.',
      );
    }
  }
}

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

Map<String, dynamic> _reconciliationObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException(
      'Forge execution reconciliation $label must be an object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _reconciliationExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge execution reconciliation fields.',
    );
  }
}

bool _reconciliationBool(Object? value) {
  if (value is! bool) {
    throw const FormatException(
      'Invalid Forge execution reconciliation boolean.',
    );
  }
  return value;
}

int _reconciliationSafeInteger(Object? value) {
  if (value is int &&
      value >= 0 &&
      value <= forgeExecutionReconciliationMaxSafeInteger) {
    return value;
  }
  throw const FormatException(
    'Forge execution reconciliation integer is outside the safe range.',
  );
}

int _reconciliationPositiveSafeInteger(Object? value) {
  final integer = _reconciliationSafeInteger(value);
  if (integer < 1) {
    throw const FormatException(
      'Forge execution reconciliation integer must be positive.',
    );
  }
  return integer;
}

int _reconciliationVersion(Object? value) {
  if (value is! int || value != 1) {
    throw const FormatException(
      'Unsupported Forge execution reconciliation version.',
    );
  }
  return value;
}

String _reconciliationSchema(Object? value) {
  if (value != forgeExecutionReconciliationObservationSchema) {
    throw const FormatException(
      'Invalid Forge execution reconciliation schema.',
    );
  }
  return forgeExecutionReconciliationObservationSchema;
}

String _reconciliationMode(Object? value) {
  if (value != forgeExecutionReconciliationObservationEvaluationMode) {
    throw const FormatException(
      'Invalid Forge execution reconciliation evaluation mode.',
    );
  }
  return forgeExecutionReconciliationObservationEvaluationMode;
}

String _reconciliationIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      utf8.encode(value).length > 85 ||
      !_reconciliationWellFormedUnicode(value) ||
      RegExp(r'\s').hasMatch(value) ||
      value.runes.any(
        (rune) =>
            rune <= 0x20 ||
            (rune >= 0x7f && rune <= 0x9f) ||
            rune == 0x3a ||
            rune == 0x2f ||
            rune == 0x5c,
      )) {
    throw const FormatException(
      'Invalid Forge execution reconciliation identifier.',
    );
  }
  return value;
}

String _reconciliationRunStatus(Object? value) => _reconciliationOneOf(value, {
  'nonterminal',
  'completed',
  'cancelled',
  'limit_exceeded',
  'failed',
}, 'Run status');

String _reconciliationAttemptState(Object? value) =>
    _reconciliationOneOf(value, {
      'requested',
      'accepted',
      'starting',
      'running',
      'interrupted',
      'completed',
      'failed',
      'uncertain',
    }, 'Attempt state');

String _reconciliationTerminalDisposition(Object? value) =>
    _reconciliationOneOf(value, {
      'none',
      'completed',
      'failed',
      'uncertain',
    }, 'terminal disposition');

String _reconciliationNextObservation(Object? value) =>
    _reconciliationOneOf(value, {
      'await_terminal',
      'lease_expired_without_terminal',
      'attempt_not_dispatchable',
      'attempt_terminal_without_receipt',
      'run_terminal_without_receipt',
      'terminal_completed',
      'terminal_failed',
      'terminal_uncertain',
      'terminal_state_conflict',
    }, 'next observation');

String _reconciliationOneOf(Object? value, Set<String> allowed, String label) {
  if (value is! String || !allowed.contains(value)) {
    throw FormatException('Invalid Forge execution reconciliation $label.');
  }
  return value;
}

bool _sameProof(ForgeRunnerLeaseProof left, ForgeRunnerLeaseProof right) =>
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken;

bool _terminalStateMatchesAttempt(String disposition, String state) =>
    (disposition == 'completed' && state == 'completed') ||
    (disposition == 'failed' && state == 'failed') ||
    (disposition == 'uncertain' && state == 'uncertain');

bool _dispatchableAttemptState(String value) =>
    value == 'accepted' || value == 'starting' || value == 'running';

String _classify(
  String runStatus,
  String attemptState,
  bool leaseActive,
  bool terminalObserved,
  String terminalDisposition,
  bool terminalStateAligned,
) {
  if (terminalObserved) {
    if (!terminalStateAligned) return 'terminal_state_conflict';
    switch (terminalDisposition) {
      case 'completed':
        return 'terminal_completed';
      case 'failed':
        return 'terminal_failed';
      default:
        return 'terminal_uncertain';
    }
  }
  if (runStatus != 'nonterminal') return 'run_terminal_without_receipt';
  if (attemptState == 'completed' ||
      attemptState == 'failed' ||
      attemptState == 'uncertain') {
    return 'attempt_terminal_without_receipt';
  }
  if (!_dispatchableAttemptState(attemptState)) {
    return 'attempt_not_dispatchable';
  }
  if (!leaseActive) return 'lease_expired_without_terminal';
  return 'await_terminal';
}

bool _requiresReconciliation(String value) => const {
  'lease_expired_without_terminal',
  'attempt_not_dispatchable',
  'attempt_terminal_without_receipt',
  'run_terminal_without_receipt',
  'terminal_uncertain',
  'terminal_state_conflict',
}.contains(value);

bool _reconciliationWellFormedUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (index + 1 >= value.length) return false;
      final next = value.codeUnitAt(++index);
      if (next < 0xdc00 || next > 0xdfff) return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

/// Minimal JSON grammar scanner for duplicate object member names. It does
/// not replace `jsonDecode`; it only prevents last-key-wins ambiguity first.
void _reconciliationRejectDuplicateJsonKeys(String source) {
  _ReconciliationDuplicateScanner(source).scan();
}

class _ReconciliationDuplicateScanner {
  final String source;
  var index = 0;

  _ReconciliationDuplicateScanner(this.source);

  void scan() {
    _skipWhitespace();
    _scanValue();
    _skipWhitespace();
    if (index != source.length) {
      throw const FormatException(
        'Invalid Forge execution reconciliation JSON.',
      );
    }
  }

  void _scanValue() {
    if (index >= source.length) _invalid();
    switch (source[index]) {
      case '{':
        _scanObject();
      case '[':
        _scanArray();
      case '"':
        _scanString();
      case 't':
        _scanLiteral('true');
      case 'f':
        _scanLiteral('false');
      case 'n':
        _scanLiteral('null');
      default:
        _scanNumber();
    }
  }

  void _scanObject() {
    index++;
    _skipWhitespace();
    final keys = <String>{};
    if (_consume('}')) return;
    while (true) {
      if (index >= source.length || source[index] != '"') _invalid();
      final key = _scanString();
      if (!keys.add(key)) {
        throw const FormatException(
          'Forge execution reconciliation JSON contains duplicate fields.',
        );
      }
      _skipWhitespace();
      _expect(':');
      _skipWhitespace();
      _scanValue();
      _skipWhitespace();
      if (_consume('}')) return;
      _expect(',');
      _skipWhitespace();
    }
  }

  void _scanArray() {
    index++;
    _skipWhitespace();
    if (_consume(']')) return;
    while (true) {
      _scanValue();
      _skipWhitespace();
      if (_consume(']')) return;
      _expect(',');
      _skipWhitespace();
    }
  }

  String _scanString() {
    final start = index;
    _expect('"');
    while (index < source.length) {
      final character = source[index++];
      if (character == '"') {
        final decoded = jsonDecode(source.substring(start, index));
        if (decoded is! String) _invalid();
        return decoded;
      }
      if (character == '\\') {
        if (index >= source.length) _invalid();
        final escaped = source[index++];
        if (escaped == 'u') {
          if (index + 4 > source.length) _invalid();
          for (var digit = 0; digit < 4; digit++) {
            if (!_isHex(source[index++])) _invalid();
          }
        } else if (!'"\\/bfnrt'.contains(escaped)) {
          _invalid();
        }
      } else if (character.codeUnitAt(0) < 0x20) {
        _invalid();
      }
    }
    _invalid();
  }

  void _scanLiteral(String literal) {
    if (!source.startsWith(literal, index)) _invalid();
    index += literal.length;
  }

  void _scanNumber() {
    final start = index;
    _consume('-');
    if (index >= source.length) _invalid();
    if (_consume('0')) {
      if (index < source.length && _isDigit(source[index])) _invalid();
    } else {
      if (index >= source.length || !_isNonZeroDigit(source[index])) _invalid();
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    if (_consume('.')) {
      if (index >= source.length || !_isDigit(source[index])) _invalid();
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    if (index < source.length &&
        (source[index] == 'e' || source[index] == 'E')) {
      index++;
      if (index < source.length &&
          (source[index] == '+' || source[index] == '-')) {
        index++;
      }
      if (index >= source.length || !_isDigit(source[index])) _invalid();
      while (index < source.length && _isDigit(source[index])) {
        index++;
      }
    }
    if (start == index) _invalid();
  }

  void _skipWhitespace() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) {
      index++;
    }
  }

  bool _consume(String character) {
    if (index < source.length && source[index] == character) {
      index++;
      return true;
    }
    return false;
  }

  void _expect(String character) {
    if (!_consume(character)) _invalid();
  }

  bool _isDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }

  bool _isNonZeroDigit(String value) {
    final code = value.codeUnitAt(0);
    return code >= 0x31 && code <= 0x39;
  }

  bool _isHex(String value) {
    final code = value.codeUnitAt(0);
    return (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x46) ||
        (code >= 0x61 && code <= 0x66);
  }

  Never _invalid() => throw const FormatException(
    'Invalid Forge execution reconciliation JSON.',
  );
}
