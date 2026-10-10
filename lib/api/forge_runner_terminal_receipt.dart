import 'dart:convert';

import 'forge_runner_execution_intent.dart';

part 'forge_runner_terminal_receipt_observation.dart';
part 'forge_runner_terminal_receipt_validation.dart';

/// The read-only Flutter projection of the Runtime Runner command/receipt ABI.
///
/// This consumer validates values supplied by a caller. It does not execute a
/// process, read a clock, persist a receipt, reserve a target, or grant
/// authority. An uncertain disposition always requires explicit reconciliation
/// and manual handling; it is never an automatic retry signal.
const forgeRunnerTerminalReceiptSchema =
    'forge.runner-command-terminal-receipt/v1';
const forgeRunnerTerminalReceiptEvaluationMode =
    'pure_runner_command_receipt_only';
const forgeRunnerTerminalReceiptABI = 1;
// Flutter Web and native clients share this JSON projection. Use the largest
// integer that is exact in both Dart's JavaScript and native representations;
// values above it fail closed instead of being silently rounded by Web JSON.
const forgeRunnerTerminalReceiptMaxRepresentableInteger = 9007199254740991;
const forgeRunnerTerminalReceiptMinLeaseTTLMS = 1000;
const forgeRunnerTerminalReceiptMaxLeaseTTLMS = 600000;
const forgeRunnerTerminalReceiptMaxReasonBytes = 256;

class ForgeRunnerTerminalReceiptError implements Exception {
  final String code;

  const ForgeRunnerTerminalReceiptError(this.code);

  @override
  String toString() => 'ForgeRunnerTerminalReceiptError($code)';
}

/// The coordinator-issued lease declaration observed alongside a receipt.
class ForgeRunnerTerminalReceiptGrant {
  final int version;
  final String attemptID;
  final String targetID;
  final int epoch;
  final String fencingToken;
  final int issuedAtMS;
  final int expiresAtMS;

  const ForgeRunnerTerminalReceiptGrant({
    required this.version,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory ForgeRunnerTerminalReceiptGrant.fromJson(Object? value) {
    final json = _terminalObject(value);
    _terminalExactKeys(json, {
      'v',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
      'issued_at_ms',
      'expires_at_ms',
    });
    return ForgeRunnerTerminalReceiptGrant(
      version: _terminalInt(json['v']),
      attemptID: _terminalText(json['attempt_id']),
      targetID: _terminalText(json['target_id']),
      epoch: _terminalInt(json['epoch']),
      fencingToken: _terminalText(json['fencing_token']),
      issuedAtMS: _terminalInt(json['issued_at_ms']),
      expiresAtMS: _terminalInt(json['expires_at_ms']),
    );
  }

  ForgeRunnerExecutionLeaseProof get proof => ForgeRunnerExecutionLeaseProof(
    attemptID: attemptID,
    targetID: targetID,
    epoch: epoch,
    fencingToken: fencingToken,
  );
}

/// The terminal outcome attached to a Runner command.
class ForgeRunnerTerminalReceiptDisposition {
  final String kind;
  final String? receiptSHA256;
  final String? reason;

  const ForgeRunnerTerminalReceiptDisposition._({
    required this.kind,
    required this.receiptSHA256,
    required this.reason,
  });

  const ForgeRunnerTerminalReceiptDisposition.completed(String receiptSHA256)
    : this._(kind: 'completed', receiptSHA256: receiptSHA256, reason: null);

  const ForgeRunnerTerminalReceiptDisposition.failed(String reason)
    : this._(kind: 'failed', receiptSHA256: null, reason: reason);

  const ForgeRunnerTerminalReceiptDisposition.uncertain(String reason)
    : this._(kind: 'uncertain', receiptSHA256: null, reason: reason);

  factory ForgeRunnerTerminalReceiptDisposition.fromJson(Object? value) {
    final json = _terminalObject(value);
    final kind = _terminalText(json['kind']);
    switch (kind) {
      case 'completed':
        _terminalExactKeys(json, {'kind', 'receipt_sha256'});
        return ForgeRunnerTerminalReceiptDisposition.completed(
          _terminalText(json['receipt_sha256']),
        );
      case 'failed':
        _terminalExactKeys(json, {'kind', 'reason'});
        return ForgeRunnerTerminalReceiptDisposition.failed(
          _terminalText(json['reason']),
        );
      case 'uncertain':
        _terminalExactKeys(json, {'kind', 'reason'});
        return ForgeRunnerTerminalReceiptDisposition.uncertain(
          _terminalText(json['reason']),
        );
      default:
        throw const FormatException('Invalid Runner terminal disposition.');
    }
  }

  bool get isUncertain => kind == 'uncertain';
}

/// An immutable terminal observation for one command.
class ForgeRunnerTerminalReceipt {
  final int version;
  final String commandID;
  final String commandSHA256;
  final ForgeRunnerExecutionLeaseProof proof;
  final ForgeRunnerTerminalReceiptDisposition disposition;
  final int observedAtMS;

  const ForgeRunnerTerminalReceipt({
    required this.version,
    required this.commandID,
    required this.commandSHA256,
    required this.proof,
    required this.disposition,
    required this.observedAtMS,
  });

  factory ForgeRunnerTerminalReceipt.fromJson(Object? value) {
    final json = _terminalObject(value);
    _terminalExactKeys(json, {
      'v',
      'command_id',
      'command_sha256',
      'proof',
      'disposition',
      'observed_at_ms',
    });
    final proof = _terminalObject(json['proof']);
    _terminalExactKeys(proof, {
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
    });
    return ForgeRunnerTerminalReceipt(
      version: _terminalInt(json['v']),
      commandID: _terminalText(json['command_id']),
      commandSHA256: _terminalText(json['command_sha256']),
      proof: ForgeRunnerExecutionLeaseProof(
        attemptID: _terminalText(proof['attempt_id']),
        targetID: _terminalText(proof['target_id']),
        epoch: _terminalInt(proof['epoch']),
        fencingToken: _terminalText(proof['fencing_token']),
      ),
      disposition: ForgeRunnerTerminalReceiptDisposition.fromJson(
        json['disposition'],
      ),
      observedAtMS: _terminalInt(json['observed_at_ms']),
    );
  }
}

class ForgeRunnerTerminalReceiptRequest {
  final ForgeRunnerExecutionCommand command;
  final ForgeRunnerTerminalReceiptGrant grant;
  final ForgeRunnerTerminalReceipt receipt;

  const ForgeRunnerTerminalReceiptRequest({
    required this.command,
    required this.grant,
    required this.receipt,
  });
}

class ForgeRunnerTerminalReceiptAuthority {
  final bool deviceIdentityVerified;
  final bool commandPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeRunnerTerminalReceiptAuthority.offline()
    : deviceIdentityVerified = false,
      commandPersisted = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  bool get isOffline =>
      !deviceIdentityVerified &&
      !commandPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  bool get anyGranted => !isOffline;

  factory ForgeRunnerTerminalReceiptAuthority.fromJson(Object? value) {
    final json = _terminalObject(value);
    _terminalExactKeys(json, {
      'device_identity_verified',
      'command_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeRunnerTerminalReceiptAuthority._(
      deviceIdentityVerified: _terminalBool(json['device_identity_verified']),
      commandPersisted: _terminalBool(json['command_persisted']),
      reservationCreated: _terminalBool(json['reservation_created']),
      executionAuthorized: _terminalBool(json['execution_authorized']),
      dispatchPerformed: _terminalBool(json['dispatch_performed']),
      auditPublished: _terminalBool(json['audit_published']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Runner terminal receipt authority must remain false.',
      );
    }
    return authority;
  }

  const ForgeRunnerTerminalReceiptAuthority._({
    required this.deviceIdentityVerified,
    required this.commandPersisted,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  Map<String, dynamic> toJson() => {
    'device_identity_verified': deviceIdentityVerified,
    'command_persisted': commandPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeRunnerTerminalReceiptObservation {
  final String schemaVersion;
  final String evaluationMode;
  final String commandID;
  final String commandSHA256;
  final String attemptID;
  final String targetID;
  final String dispositionKind;
  final int observedAtMS;
  final bool receiptValid;
  final bool previewOnly;
  final bool uncertain;
  final bool reconciliationRequired;
  final bool manualReviewRequired;
  final bool automaticRetry;
  final String followUp;
  final ForgeRunnerTerminalReceiptAuthority authority;

  const ForgeRunnerTerminalReceiptObservation({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.commandID,
    required this.commandSHA256,
    required this.attemptID,
    required this.targetID,
    required this.dispositionKind,
    required this.observedAtMS,
    required this.receiptValid,
    required this.previewOnly,
    required this.uncertain,
    required this.reconciliationRequired,
    required this.manualReviewRequired,
    required this.automaticRetry,
    required this.followUp,
    required this.authority,
  });

  /// Consumes the canonical metadata-only receipt observation envelope. It
  /// carries no command output and accepts no authority-bearing mutation.
  factory ForgeRunnerTerminalReceiptObservation.fromJson(Object? value) {
    final json = _terminalObject(value);
    _terminalExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'command_id',
      'command_sha256',
      'attempt_id',
      'target_id',
      'disposition_kind',
      'observed_at_ms',
      'receipt_valid',
      'preview_only',
      'uncertain',
      'reconciliation_required',
      'manual_review_required',
      'automatic_retry',
      'follow_up',
      'authority',
    });
    final observation = ForgeRunnerTerminalReceiptObservation(
      schemaVersion: _terminalSchema(json['schema_version']),
      evaluationMode: _terminalMode(json['evaluation_mode']),
      commandID: _terminalCommandIDValue(json['command_id']),
      commandSHA256: _terminalDigestValue(json['command_sha256']),
      attemptID: _terminalLeaseIdentityValue(json['attempt_id']),
      targetID: _terminalLeaseIdentityValue(json['target_id']),
      dispositionKind: _terminalDispositionValue(json['disposition_kind']),
      observedAtMS: _terminalUint64Value(json['observed_at_ms']),
      receiptValid: _terminalBool(json['receipt_valid']),
      previewOnly: _terminalBool(json['preview_only']),
      uncertain: _terminalBool(json['uncertain']),
      reconciliationRequired: _terminalBool(json['reconciliation_required']),
      manualReviewRequired: _terminalBool(json['manual_review_required']),
      automaticRetry: _terminalBool(json['automatic_retry']),
      followUp: _terminalFollowUpValue(json['follow_up']),
      authority: ForgeRunnerTerminalReceiptAuthority.fromJson(
        json['authority'],
      ),
    );
    if (!observation.isDisplayOnly) {
      throw const FormatException(
        'Forge Runner terminal receipt is not display-only.',
      );
    }
    return observation;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'command_id': commandID,
    'command_sha256': commandSHA256,
    'attempt_id': attemptID,
    'target_id': targetID,
    'disposition_kind': dispositionKind,
    'observed_at_ms': observedAtMS,
    'receipt_valid': receiptValid,
    'preview_only': previewOnly,
    'uncertain': uncertain,
    'reconciliation_required': reconciliationRequired,
    'manual_review_required': manualReviewRequired,
    'automatic_retry': automaticRetry,
    'follow_up': followUp,
    'authority': authority.toJson(),
  };

  bool get isDisplayOnly =>
      schemaVersion == forgeRunnerTerminalReceiptSchema &&
      evaluationMode == forgeRunnerTerminalReceiptEvaluationMode &&
      receiptValid &&
      previewOnly &&
      automaticRetry == false &&
      (uncertain == reconciliationRequired) &&
      (uncertain == manualReviewRequired) &&
      (uncertain ? followUp == 'reconciliation_manual' : followUp == 'none') &&
      authority.isOffline;
}
