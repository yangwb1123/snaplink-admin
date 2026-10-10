import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_runner_lease_fencing.dart';

part 'forge_execution_reconciliation_observation_projection.dart';
part 'forge_execution_reconciliation_observation_validation.dart';
part 'forge_execution_reconciliation_observation_json.dart';

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
