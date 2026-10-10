import 'dart:convert';

part 'forge_runner_lease_fencing_fixtures.dart';
part 'forge_runner_lease_fencing_codec.dart';

/// Pure lease/fencing values shared with Forge Core and Runtime. This module
/// does not read a clock, persist a grant, reserve a device, contact a
/// Runner, or authorize execution.
const forgeRunnerLeaseFencingSchema = 'forge.runner-lease-fencing/v1';
const forgeRunnerLeaseFencingEvaluationMode = 'pure_lease_fencing_only';
const forgeRunnerLeaseFencingMinTTLMS = 1000;
const forgeRunnerLeaseFencingMaxTTLMS = 600000;

/// File reader seam used by the Web/App/Mobile local preview. The default
/// screen implementation uses the platform workspace JSON picker; tests and
/// native shells may inject a bounded reader without opening a network route.
typedef ForgeRunnerLeaseFencingFileReader = Future<String?> Function();

final _forgeRunnerLeaseMaxUint64 = (BigInt.one << 64) - BigInt.one;

class ForgeRunnerLeaseError implements Exception {
  final String code;

  const ForgeRunnerLeaseError(this.code);

  @override
  String toString() => code;
}

class ForgeRunnerLeaseAuthority {
  final bool deviceIdentityVerified;
  final bool commandPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeRunnerLeaseAuthority.offline()
    : deviceIdentityVerified = false,
      commandPersisted = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  factory ForgeRunnerLeaseAuthority.fromJson(Object? value) {
    final json = _leaseObject(value, 'authority');
    _leaseExactKeys(json, {
      'device_identity_verified',
      'command_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    for (final entry in json.entries) {
      if (entry.value is! bool || entry.value == true) {
        throw const FormatException(
          'Forge Runner lease fixture claims authority.',
        );
      }
    }
    return const ForgeRunnerLeaseAuthority.offline();
  }

  bool get isOffline =>
      !deviceIdentityVerified &&
      !commandPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  /// Encodes a local proof for fixture/debug round trips. This is not a
  /// network transport encoder; see [ForgeRunnerLeaseGrant.toJson] for the
  /// uint64 representation boundary.
  Map<String, dynamic> toJson() => {
    'device_identity_verified': deviceIdentityVerified,
    'command_persisted': commandPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeRunnerLeaseProof {
  final String attemptID;
  final String targetID;
  final BigInt epoch;
  final String fencingToken;

  const ForgeRunnerLeaseProof({
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
  });

  factory ForgeRunnerLeaseProof.fromJson(Object? value) {
    final json = _leaseObject(value, 'proof');
    _leaseExactKeys(json, {
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
    });
    return ForgeRunnerLeaseProof(
      attemptID: _leaseIdentity(json['attempt_id']),
      targetID: _leaseIdentity(json['target_id']),
      epoch: _leasePositiveUint64(json['epoch']),
      fencingToken: _leaseToken(json['fencing_token']),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': _leaseJsonUint64(epoch),
    'fencing_token': fencingToken,
  };
}

class ForgeRunnerLeaseGrant {
  final int version;
  final String attemptID;
  final String targetID;
  final BigInt epoch;
  final String fencingToken;
  final BigInt issuedAtMS;
  final BigInt expiresAtMS;

  const ForgeRunnerLeaseGrant({
    required this.version,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory ForgeRunnerLeaseGrant.fromJson(Object? value) {
    final json = _leaseObject(value, 'grant');
    _leaseExactKeys(json, {
      'v',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
      'issued_at_ms',
      'expires_at_ms',
    });
    final grant = ForgeRunnerLeaseGrant(
      version: _leaseVersion(json['v']),
      attemptID: _leaseIdentity(json['attempt_id']),
      targetID: _leaseIdentity(json['target_id']),
      epoch: _leasePositiveUint64(json['epoch']),
      fencingToken: _leaseToken(json['fencing_token']),
      issuedAtMS: _leaseUint64(json['issued_at_ms']),
      expiresAtMS: _leaseUint64(json['expires_at_ms']),
    );
    grant.validate();
    return grant;
  }

  factory ForgeRunnerLeaseGrant.issue({
    required String attemptID,
    required String targetID,
    required BigInt epoch,
    required String fencingToken,
    required BigInt issuedAtMS,
    required BigInt ttlMS,
  }) {
    _leaseIdentity(attemptID);
    _leaseIdentity(targetID);
    _leasePositiveUint64(epoch);
    _leaseToken(fencingToken);
    _leaseUint64(issuedAtMS);
    _leaseTTL(ttlMS);
    final expiresAtMS = issuedAtMS + ttlMS;
    if (expiresAtMS > _forgeRunnerLeaseMaxUint64 || expiresAtMS < issuedAtMS) {
      throw const ForgeRunnerLeaseError('time_overflow');
    }
    final grant = ForgeRunnerLeaseGrant(
      version: 1,
      attemptID: attemptID,
      targetID: targetID,
      epoch: epoch,
      fencingToken: fencingToken,
      issuedAtMS: issuedAtMS,
      expiresAtMS: expiresAtMS,
    );
    grant.validate();
    return grant;
  }

  void validate() {
    if (version != 1) {
      throw const ForgeRunnerLeaseError('unsupported_version');
    }
    _leaseIdentity(attemptID);
    _leaseIdentity(targetID);
    _leasePositiveUint64(epoch);
    _leaseToken(fencingToken);
    if (expiresAtMS <= issuedAtMS) {
      throw const ForgeRunnerLeaseError('invalid_lease_window');
    }
    _leaseTTL(expiresAtMS - issuedAtMS);
  }

  bool isActive(BigInt observedAtMS) {
    _leaseUint64(observedAtMS);
    return observedAtMS >= issuedAtMS && observedAtMS < expiresAtMS;
  }

  ForgeRunnerLeaseProof proof() => ForgeRunnerLeaseProof(
    attemptID: attemptID,
    targetID: targetID,
    epoch: epoch,
    fencingToken: fencingToken,
  );

  void validateProof(ForgeRunnerLeaseProof value, BigInt observedAtMS) {
    if (value.attemptID != attemptID) {
      throw const ForgeRunnerLeaseError('attempt_mismatch');
    }
    if (value.targetID != targetID) {
      throw const ForgeRunnerLeaseError('target_mismatch');
    }
    if (value.epoch != epoch) {
      throw const ForgeRunnerLeaseError('epoch_mismatch');
    }
    if (value.fencingToken != fencingToken) {
      throw const ForgeRunnerLeaseError('fencing_token_mismatch');
    }
    _leaseUint64(observedAtMS);
    if (observedAtMS < issuedAtMS) {
      throw const ForgeRunnerLeaseError('time_went_backwards');
    }
    if (!isActive(observedAtMS)) {
      throw const ForgeRunnerLeaseError('lease_expired');
    }
  }

  ForgeRunnerLeaseGrant renew({
    required BigInt observedAtMS,
    required String fencingToken,
    required BigInt ttlMS,
  }) {
    _leaseUint64(observedAtMS);
    if (observedAtMS < issuedAtMS) {
      throw const ForgeRunnerLeaseError('time_went_backwards');
    }
    if (!isActive(observedAtMS)) {
      throw const ForgeRunnerLeaseError('lease_expired');
    }
    if (fencingToken == this.fencingToken) {
      throw const ForgeRunnerLeaseError('fencing_token_reused');
    }
    if (epoch == _forgeRunnerLeaseMaxUint64) {
      throw const ForgeRunnerLeaseError('epoch_overflow');
    }
    return ForgeRunnerLeaseGrant.issue(
      attemptID: attemptID,
      targetID: targetID,
      epoch: epoch + BigInt.one,
      fencingToken: fencingToken,
      issuedAtMS: observedAtMS,
      ttlMS: ttlMS,
    );
  }

  /// Encodes a local value for fixture/debug round trips.
  ///
  /// Values above JavaScript's safe integer range are represented as decimal
  /// strings so Web does not silently round them. This helper is not a
  /// network transport encoder; a future wire adapter must negotiate the
  /// uint64 representation with Go/Rust before sending these fields.
  Map<String, dynamic> toJson() => {
    'v': version,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': _leaseJsonUint64(epoch),
    'fencing_token': fencingToken,
    'issued_at_ms': _leaseJsonUint64(issuedAtMS),
    'expires_at_ms': _leaseJsonUint64(expiresAtMS),
  };
}

class ForgeRunnerLeaseDisposition {
  final String kind;
  final String? receiptSHA256;
  final String? reason;

  const ForgeRunnerLeaseDisposition({
    required this.kind,
    this.receiptSHA256,
    this.reason,
  });

  factory ForgeRunnerLeaseDisposition.fromJson(Object? value) {
    final json = _leaseObject(value, 'disposition');
    final kind = _leaseText(json['kind'], 32);
    final expected = <String>{'kind'};
    if (json.containsKey('receipt_sha256')) expected.add('receipt_sha256');
    if (json.containsKey('reason')) expected.add('reason');
    _leaseExactKeys(json, expected);
    final receipt = json['receipt_sha256'];
    final reason = json['reason'];
    // A present optional field is still part of the closed wire shape. Rust's
    // tagged enum and Go's value struct do not interpret an explicit JSON null
    // as an omitted field, so reject it before constructing the value.
    if ((json.containsKey('receipt_sha256') && receipt == null) ||
        (json.containsKey('reason') && reason == null)) {
      throw const FormatException('Null Forge Runner lease disposition field.');
    }
    final disposition = ForgeRunnerLeaseDisposition(
      kind: kind,
      receiptSHA256: json.containsKey('receipt_sha256')
          ? _leaseDigest(receipt)
          : null,
      reason: json.containsKey('reason') ? _leaseReason(reason) : null,
    );
    disposition.validate();
    return disposition;
  }

  void validate() {
    switch (kind) {
      case 'completed':
        if (reason != null || receiptSHA256 == null) {
          throw const ForgeRunnerLeaseError('invalid_digest');
        }
        _leaseDigest(receiptSHA256);
      case 'failed':
      case 'uncertain':
        if (receiptSHA256 != null || reason == null) {
          throw const ForgeRunnerLeaseError('invalid_reason');
        }
        _leaseReason(reason);
      default:
        throw const ForgeRunnerLeaseError('invalid_reason');
    }
  }

  bool get isUncertain => kind == 'uncertain';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (receiptSHA256 != null) 'receipt_sha256': receiptSHA256,
    if (reason != null) 'reason': reason,
  };
}

class ForgeRunnerLeaseTerminalReceipt {
  final int version;
  final ForgeRunnerLeaseProof proof;
  final ForgeRunnerLeaseDisposition disposition;
  final BigInt observedAtMS;

  const ForgeRunnerLeaseTerminalReceipt({
    required this.version,
    required this.proof,
    required this.disposition,
    required this.observedAtMS,
  });
}

class ForgeRunnerLeaseTerminalSubmission {
  final ForgeRunnerLeaseTerminalReceipt receipt;
  final bool replayed;

  const ForgeRunnerLeaseTerminalSubmission({
    required this.receipt,
    required this.replayed,
  });
}
