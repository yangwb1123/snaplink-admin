import 'dart:convert';

part 'forge_execution_lease_checkpoint_fixtures.dart';
part 'forge_execution_lease_checkpoint_codec.dart';

/// Strict local consumer for the cross-runtime execution-lease checkpoint
/// value. This module does not restore a lease, persist a receipt, reserve a
/// device, contact a Runner, or authorize execution.
const forgeExecutionLeaseCheckpointSchema =
    'forge.execution-lease-checkpoint/v1';
const forgeExecutionLeaseCheckpointEvaluationMode =
    'pure_execution_lease_checkpoint_only';
const forgeExecutionLeaseCheckpointMinTTLMS = 1000;
const forgeExecutionLeaseCheckpointMaxTTLMS = 600000;

/// File reader seam used by the shared Web/App/Mobile local preview. The
/// default Sessions screen uses the platform workspace picker; tests and
/// native shells can inject a bounded reader without opening a network route.
typedef ForgeExecutionLeaseCheckpointFileReader = Future<String?> Function();

final _checkpointMaxUint64 = (BigInt.one << 64) - BigInt.one;

class ForgeExecutionLeaseCheckpointAuthority {
  final bool leaseIssued;
  final bool terminalPersisted;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeExecutionLeaseCheckpointAuthority({
    required this.leaseIssued,
    required this.terminalPersisted,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeExecutionLeaseCheckpointAuthority.fromJson(Object? value) {
    final json = _checkpointObject(value, 'authority');
    _checkpointExactKeys(json, {
      'lease_issued',
      'terminal_persisted',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeExecutionLeaseCheckpointAuthority(
      leaseIssued: _checkpointBool(json['lease_issued']),
      terminalPersisted: _checkpointBool(json['terminal_persisted']),
      executionAuthorized: _checkpointBool(json['execution_authorized']),
      dispatchPerformed: _checkpointBool(json['dispatch_performed']),
      auditPublished: _checkpointBool(json['audit_published']),
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Execution lease checkpoint claims authority.',
      );
    }
    return authority;
  }

  const ForgeExecutionLeaseCheckpointAuthority.offline()
    : leaseIssued = false,
      terminalPersisted = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  bool get isOffline =>
      !leaseIssued &&
      !terminalPersisted &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'lease_issued': leaseIssued,
    'terminal_persisted': terminalPersisted,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeExecutionLeaseCheckpointGrant {
  final int version;
  final String attemptID;
  final String targetID;
  final BigInt epoch;
  final String fencingToken;
  final BigInt issuedAtMS;
  final BigInt expiresAtMS;

  const ForgeExecutionLeaseCheckpointGrant({
    required this.version,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory ForgeExecutionLeaseCheckpointGrant.fromJson(Object? value) {
    final json = _checkpointObject(value, 'grant');
    _checkpointExactKeys(json, {
      'v',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
      'issued_at_ms',
      'expires_at_ms',
    });
    final grant = ForgeExecutionLeaseCheckpointGrant(
      version: _checkpointVersion(json['v']),
      attemptID: _checkpointIdentity(json['attempt_id']),
      targetID: _checkpointIdentity(json['target_id']),
      epoch: _checkpointPositiveUint64(json['epoch']),
      fencingToken: _checkpointToken(json['fencing_token']),
      issuedAtMS: _checkpointUint64(json['issued_at_ms']),
      expiresAtMS: _checkpointUint64(json['expires_at_ms']),
    );
    grant.validate();
    return grant;
  }

  void validate() {
    if (version != 1) {
      throw const FormatException('Unsupported execution lease version.');
    }
    if (expiresAtMS <= issuedAtMS) {
      throw const FormatException('Invalid execution lease window.');
    }
    final ttl = expiresAtMS - issuedAtMS;
    if (ttl < BigInt.from(forgeExecutionLeaseCheckpointMinTTLMS) ||
        ttl > BigInt.from(forgeExecutionLeaseCheckpointMaxTTLMS)) {
      throw const FormatException('Invalid execution lease duration.');
    }
  }

  bool isActive(BigInt observedAtMS) =>
      observedAtMS >= issuedAtMS && observedAtMS < expiresAtMS;

  Map<String, dynamic> toJson() => {
    'v': version,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': _checkpointJsonUint64(epoch),
    'fencing_token': fencingToken,
    'issued_at_ms': _checkpointJsonUint64(issuedAtMS),
    'expires_at_ms': _checkpointJsonUint64(expiresAtMS),
  };
}

class ForgeExecutionLeaseCheckpointProof {
  final String attemptID;
  final String targetID;
  final BigInt epoch;
  final String fencingToken;

  const ForgeExecutionLeaseCheckpointProof({
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
  });

  factory ForgeExecutionLeaseCheckpointProof.fromJson(Object? value) {
    final json = _checkpointObject(value, 'proof');
    _checkpointExactKeys(json, {
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
    });
    return ForgeExecutionLeaseCheckpointProof(
      attemptID: _checkpointIdentity(json['attempt_id']),
      targetID: _checkpointIdentity(json['target_id']),
      epoch: _checkpointPositiveUint64(json['epoch']),
      fencingToken: _checkpointToken(json['fencing_token']),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': _checkpointJsonUint64(epoch),
    'fencing_token': fencingToken,
  };
}

class ForgeExecutionLeaseCheckpointDisposition {
  final String kind;
  final String? receiptSHA256;
  final String? reason;

  const ForgeExecutionLeaseCheckpointDisposition({
    required this.kind,
    this.receiptSHA256,
    this.reason,
  });

  factory ForgeExecutionLeaseCheckpointDisposition.fromJson(Object? value) {
    final json = _checkpointObject(value, 'disposition');
    final kind = _checkpointOneOf(json['kind'], const {
      'completed',
      'failed',
      'uncertain',
    });
    final expected = <String>{'kind'};
    if (json.containsKey('receipt_sha256')) expected.add('receipt_sha256');
    if (json.containsKey('reason')) expected.add('reason');
    _checkpointExactKeys(json, expected);
    if (kind == 'completed') {
      if (!json.containsKey('receipt_sha256') ||
          json.containsKey('reason') ||
          json['receipt_sha256'] == null) {
        throw const FormatException(
          'Invalid completed checkpoint disposition.',
        );
      }
      return ForgeExecutionLeaseCheckpointDisposition(
        kind: kind,
        receiptSHA256: _checkpointDigest(json['receipt_sha256']),
      );
    }
    if (!json.containsKey('reason') ||
        json.containsKey('receipt_sha256') ||
        json['reason'] == null) {
      throw const FormatException('Invalid terminal checkpoint disposition.');
    }
    return ForgeExecutionLeaseCheckpointDisposition(
      kind: kind,
      reason: _checkpointReason(json['reason']),
    );
  }

  bool get isUncertain => kind == 'uncertain';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (receiptSHA256 != null) 'receipt_sha256': receiptSHA256,
    if (reason != null) 'reason': reason,
  };
}

class ForgeExecutionLeaseCheckpointTerminal {
  final int version;
  final ForgeExecutionLeaseCheckpointProof proof;
  final ForgeExecutionLeaseCheckpointDisposition disposition;
  final BigInt observedAtMS;

  const ForgeExecutionLeaseCheckpointTerminal({
    required this.version,
    required this.proof,
    required this.disposition,
    required this.observedAtMS,
  });

  factory ForgeExecutionLeaseCheckpointTerminal.fromJson(Object? value) {
    final json = _checkpointObject(value, 'terminal');
    _checkpointExactKeys(json, {'v', 'proof', 'disposition', 'observed_at_ms'});
    final version = _checkpointVersion(json['v']);
    if (version != 1) {
      throw const FormatException('Unsupported terminal checkpoint version.');
    }
    return ForgeExecutionLeaseCheckpointTerminal(
      version: version,
      proof: ForgeExecutionLeaseCheckpointProof.fromJson(json['proof']),
      disposition: ForgeExecutionLeaseCheckpointDisposition.fromJson(
        json['disposition'],
      ),
      observedAtMS: _checkpointUint64(json['observed_at_ms']),
    );
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'proof': proof.toJson(),
    'disposition': disposition.toJson(),
    'observed_at_ms': _checkpointJsonUint64(observedAtMS),
  };
}

class ForgeExecutionLeaseCheckpoint {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeExecutionLeaseCheckpointGrant grant;
  final ForgeExecutionLeaseCheckpointTerminal? terminal;

  const ForgeExecutionLeaseCheckpoint({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.grant,
    required this.terminal,
  });

  factory ForgeExecutionLeaseCheckpoint.fromJson(Object? value) {
    final json = _checkpointObject(value, 'checkpoint');
    _checkpointExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'grant',
      'terminal',
    });
    final schemaVersion = _checkpointSchema(json['schema_version']);
    final evaluationMode = _checkpointMode(json['evaluation_mode']);
    final terminalValue = json['terminal'];
    if (terminalValue != null && terminalValue is! Map) {
      throw const FormatException(
        'Checkpoint terminal must be an object or null.',
      );
    }
    return ForgeExecutionLeaseCheckpoint(
      schemaVersion: schemaVersion,
      evaluationMode: evaluationMode,
      grant: ForgeExecutionLeaseCheckpointGrant.fromJson(json['grant']),
      terminal: terminalValue == null
          ? null
          : ForgeExecutionLeaseCheckpointTerminal.fromJson(terminalValue),
    );
  }

  /// True when this value can be restored into the pure in-memory state
  /// machine. A false result is retained for the canonical foreign-proof case
  /// so the fixture can show a bounded rejection without exposing proof data.
  bool get isValid {
    if (schemaVersion != forgeExecutionLeaseCheckpointSchema ||
        evaluationMode != forgeExecutionLeaseCheckpointEvaluationMode) {
      return false;
    }
    try {
      grant.validate();
    } on FormatException {
      return false;
    }
    final receipt = terminal;
    if (receipt == null) return true;
    if (receipt.version != 1 ||
        receipt.proof.attemptID != grant.attemptID ||
        receipt.proof.targetID != grant.targetID ||
        receipt.proof.epoch != grant.epoch ||
        receipt.proof.fencingToken != grant.fencingToken) {
      return false;
    }
    return grant.isActive(receipt.observedAtMS);
  }

  bool get isUncertain => terminal?.disposition.isUncertain == true;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'grant': grant.toJson(),
    'terminal': terminal?.toJson(),
  };
}
