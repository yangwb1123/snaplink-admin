import 'dart:convert';

import 'forge_runner_execution_intent.dart';

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

/// Validates a terminal receipt against the exact command and current lease.
///
/// This is a read-only value operation. It deliberately does not adopt the
/// lease, record the receipt, or retry an uncertain command.
ForgeRunnerTerminalReceiptObservation observeForgeRunnerTerminalReceipt(
  ForgeRunnerTerminalReceiptRequest request,
) {
  _validateCommand(request.command);
  _validateGrant(request.grant);
  _validateReceipt(request.receipt);

  final receipt = request.receipt;
  final command = request.command;
  if (receipt.version != forgeRunnerTerminalReceiptABI) {
    throw const ForgeRunnerTerminalReceiptError('unsupported_receipt_version');
  }
  if (receipt.commandID != command.commandID) {
    throw const ForgeRunnerTerminalReceiptError('command_mismatch');
  }
  if (receipt.commandSHA256 != command.commandSHA256()) {
    throw const ForgeRunnerTerminalReceiptError('command_digest_mismatch');
  }
  if (!_sameProof(receipt.proof, command.leaseProof)) {
    throw const ForgeRunnerTerminalReceiptError('proof_mismatch');
  }
  if (!_sameProof(receipt.proof, request.grant.proof)) {
    throw const ForgeRunnerTerminalReceiptError('lease_mismatch');
  }
  if (receipt.observedAtMS < request.grant.issuedAtMS ||
      receipt.observedAtMS >= request.grant.expiresAtMS) {
    throw const ForgeRunnerTerminalReceiptError('lease_expired');
  }

  final uncertain = receipt.disposition.isUncertain;
  return ForgeRunnerTerminalReceiptObservation(
    schemaVersion: forgeRunnerTerminalReceiptSchema,
    evaluationMode: forgeRunnerTerminalReceiptEvaluationMode,
    commandID: receipt.commandID,
    commandSHA256: receipt.commandSHA256,
    attemptID: receipt.proof.attemptID,
    targetID: receipt.proof.targetID,
    dispositionKind: receipt.disposition.kind,
    observedAtMS: receipt.observedAtMS,
    receiptValid: true,
    previewOnly: true,
    uncertain: uncertain,
    reconciliationRequired: uncertain,
    manualReviewRequired: uncertain,
    automaticRetry: false,
    followUp: uncertain ? 'reconciliation_manual' : 'none',
    authority: const ForgeRunnerTerminalReceiptAuthority.offline(),
  );
}

String _terminalSchema(Object? value) {
  if (value != forgeRunnerTerminalReceiptSchema) {
    throw const FormatException('Invalid Runner terminal receipt schema.');
  }
  return forgeRunnerTerminalReceiptSchema;
}

String _terminalMode(Object? value) {
  if (value != forgeRunnerTerminalReceiptEvaluationMode) {
    throw const FormatException('Invalid Runner terminal receipt mode.');
  }
  return forgeRunnerTerminalReceiptEvaluationMode;
}

String _terminalCommandIDValue(Object? value) {
  if (value is! String || !_terminalCommandID(value)) {
    throw const FormatException('Invalid Runner terminal command ID.');
  }
  return value;
}

String _terminalDigestValue(Object? value) {
  if (value is! String || !_terminalDigest(value)) {
    throw const FormatException('Invalid Runner terminal digest.');
  }
  return value;
}

String _terminalLeaseIdentityValue(Object? value) {
  if (value is! String || !_terminalLeaseIdentity(value)) {
    throw const FormatException('Invalid Runner terminal lease identity.');
  }
  return value;
}

String _terminalDispositionValue(Object? value) {
  if (value is! String ||
      !const {'completed', 'failed', 'uncertain'}.contains(value)) {
    throw const FormatException('Invalid Runner terminal disposition.');
  }
  return value;
}

int _terminalUint64Value(Object? value) {
  if (value is int && _terminalUint64(value)) {
    return value;
  }
  // Some Flutter Web JSON paths materialize integral JSON numbers as `double`.
  // Accept only an exactly integral, finite value that remains within the
  // platform-safe bound; fractional or rounded values still fail closed.
  if (value is num && value.isFinite && value == value.truncateToDouble()) {
    final coerced = value.toInt();
    if (_terminalUint64(coerced) && coerced.toDouble() == value.toDouble()) {
      return coerced;
    }
  }
  throw const FormatException('Invalid Runner terminal observation time.');
}

String _terminalFollowUpValue(Object? value) {
  if (value is! String ||
      !const {'none', 'reconciliation_manual'}.contains(value)) {
    throw const FormatException('Invalid Runner terminal follow-up.');
  }
  return value;
}

void _validateCommand(ForgeRunnerExecutionCommand command) {
  if (command.version != forgeRunnerTerminalReceiptABI ||
      !_terminalCommandID(command.commandID) ||
      !_terminalLeaseProof(command.leaseProof) ||
      !_terminalTextBounded(command.idempotencyKey, 256, trimmed: true) ||
      !_terminalTextBounded(command.workspaceRef, 256, trimmed: true) ||
      command.argv.isEmpty ||
      command.argv.length > 64 ||
      command.timeoutMS < 1 ||
      command.timeoutMS > forgeRunnerTerminalReceiptMaxLeaseTTLMS ||
      command.maxOutputBytes < 1 ||
      command.maxOutputBytes > 8 * 1024 * 1024 ||
      !_terminalArguments(command.argv)) {
    throw const ForgeRunnerTerminalReceiptError('invalid_command');
  }
}

void _validateGrant(ForgeRunnerTerminalReceiptGrant grant) {
  if (grant.version != forgeRunnerTerminalReceiptABI ||
      !_terminalLeaseIdentity(grant.attemptID) ||
      !_terminalLeaseIdentity(grant.targetID) ||
      grant.epoch <= 0 ||
      !_terminalLeaseToken(grant.fencingToken) ||
      !_terminalUint64(grant.issuedAtMS) ||
      !_terminalUint64(grant.expiresAtMS) ||
      grant.expiresAtMS <= grant.issuedAtMS ||
      grant.expiresAtMS - grant.issuedAtMS <
          forgeRunnerTerminalReceiptMinLeaseTTLMS ||
      grant.expiresAtMS - grant.issuedAtMS >
          forgeRunnerTerminalReceiptMaxLeaseTTLMS) {
    throw const ForgeRunnerTerminalReceiptError('invalid_grant');
  }
}

void _validateReceipt(ForgeRunnerTerminalReceipt receipt) {
  if (receipt.version != forgeRunnerTerminalReceiptABI ||
      !_terminalCommandID(receipt.commandID) ||
      !_terminalDigest(receipt.commandSHA256) ||
      !_terminalLeaseProof(receipt.proof) ||
      !_terminalUint64(receipt.observedAtMS)) {
    throw const ForgeRunnerTerminalReceiptError('invalid_receipt');
  }
  final disposition = receipt.disposition;
  if (disposition.kind == 'completed') {
    if (disposition.receiptSHA256 == null ||
        !_terminalDigest(disposition.receiptSHA256!)) {
      throw const ForgeRunnerTerminalReceiptError('invalid_disposition');
    }
  } else if (disposition.kind == 'failed' || disposition.isUncertain) {
    if (disposition.reason == null || !_terminalReason(disposition.reason!)) {
      throw const ForgeRunnerTerminalReceiptError('invalid_disposition');
    }
  } else {
    throw const ForgeRunnerTerminalReceiptError('invalid_disposition');
  }
}

bool _terminalArguments(List<String> arguments) {
  var totalBytes = 0;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    final bytes = utf8.encode(argument).length;
    if (!_terminalTextBounded(argument, 4096, allowEmpty: index != 0) ||
        totalBytes > 65536 - bytes) {
      return false;
    }
    totalBytes += bytes;
  }
  return true;
}

bool _terminalLeaseProof(ForgeRunnerExecutionLeaseProof proof) =>
    _terminalLeaseIdentity(proof.attemptID) &&
    _terminalLeaseIdentity(proof.targetID) &&
    proof.epoch > 0 &&
    _terminalLeaseToken(proof.fencingToken);

bool _sameProof(
  ForgeRunnerExecutionLeaseProof left,
  ForgeRunnerExecutionLeaseProof right,
) =>
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken;

bool _terminalCommandID(String value) =>
    _terminalTextBounded(value, 128, trimmed: true);

bool _terminalLeaseIdentity(String value) => _terminalLeaseText(value, 128);

bool _terminalLeaseToken(String value) => _terminalLeaseText(value, 256);

bool _terminalReason(String value) =>
    value.isNotEmpty &&
    _terminalWellFormedUnicode(value) &&
    utf8.encode(value).length <= forgeRunnerTerminalReceiptMaxReasonBytes &&
    !value.contains('\u0000');

bool _terminalLeaseText(String value, int maxBytes) =>
    value.isNotEmpty &&
    _terminalWellFormedUnicode(value) &&
    utf8.encode(value).length <= maxBytes &&
    value.trim() == value &&
    !value.contains('\u0000') &&
    !value.contains('\r') &&
    !value.contains('\n');

bool _terminalDigest(String value) =>
    value.length == 64 &&
    value.codeUnits.every(
      (code) =>
          (code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66),
    );

bool _terminalUint64(int value) =>
    value >= 0 && value <= forgeRunnerTerminalReceiptMaxRepresentableInteger;

bool _terminalTextBounded(
  String value,
  int maxBytes, {
  bool allowEmpty = false,
  bool trimmed = false,
  bool rejectCRLF = false,
}) {
  if ((!allowEmpty && value.isEmpty) ||
      !_terminalWellFormedUnicode(value) ||
      utf8.encode(value).length > maxBytes ||
      (trimmed && value.trim() != value)) {
    return false;
  }
  return value.codeUnits.every(
    (unit) =>
        unit > 0x1f &&
        !(unit >= 0x7f && unit <= 0x9f) &&
        (!rejectCRLF || (unit != 0x0a && unit != 0x0d)),
  );
}

/// Dart strings can contain an isolated UTF-16 surrogate even though JSON
/// and the Go/Rust ABI require well-formed Unicode scalar sequences. Reject
/// those code units before [utf8.encode], which otherwise replaces them and
/// could make an invalid value appear bounded and valid.
bool _terminalWellFormedUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (index + 1 >= value.length) return false;
      final next = value.codeUnitAt(index + 1);
      if (next < 0xdc00 || next > 0xdfff) return false;
      index++;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

Map<String, dynamic> _terminalObject(Object? value) {
  if (value is! Map) throw const FormatException('Expected Runner object.');
  return Map<String, dynamic>.from(value);
}

void _terminalExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Runner terminal fields.');
  }
}

String _terminalText(Object? value) {
  if (value is! String) throw const FormatException('Expected Runner text.');
  return value;
}

int _terminalInt(Object? value) {
  if (value is! int) throw const FormatException('Expected Runner integer.');
  return value;
}

bool _terminalBool(Object? value) {
  if (value is! bool) throw const FormatException('Expected Runner boolean.');
  return value;
}
