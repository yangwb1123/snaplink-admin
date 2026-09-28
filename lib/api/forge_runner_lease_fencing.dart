import 'dart:convert';

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

class ForgeRunnerLeaseState {
  ForgeRunnerLeaseGrant grant;
  ForgeRunnerLeaseTerminalReceipt? terminal;

  ForgeRunnerLeaseState(this.grant) {
    grant.validate();
  }

  void renew({
    required BigInt observedAtMS,
    required String fencingToken,
    required BigInt ttlMS,
  }) {
    if (terminal != null) {
      throw const ForgeRunnerLeaseError('terminal_already_recorded');
    }
    grant = grant.renew(
      observedAtMS: observedAtMS,
      fencingToken: fencingToken,
      ttlMS: ttlMS,
    );
  }

  ForgeRunnerLeaseTerminalSubmission submitTerminal({
    required ForgeRunnerLeaseProof proof,
    required ForgeRunnerLeaseDisposition disposition,
    required BigInt observedAtMS,
  }) {
    disposition.validate();
    final existing = terminal;
    if (existing != null) {
      if (_leaseProofEquals(existing.proof, proof) &&
          _leaseDispositionEquals(existing.disposition, disposition)) {
        return ForgeRunnerLeaseTerminalSubmission(
          receipt: existing,
          replayed: true,
        );
      }
      throw const ForgeRunnerLeaseError('terminal_already_recorded');
    }
    grant.validateProof(proof, observedAtMS);
    final receipt = ForgeRunnerLeaseTerminalReceipt(
      version: 1,
      proof: proof,
      disposition: disposition,
      observedAtMS: observedAtMS,
    );
    terminal = receipt;
    return ForgeRunnerLeaseTerminalSubmission(
      receipt: receipt,
      replayed: false,
    );
  }
}

class ForgeRunnerLeaseCaseExpected {
  final bool? active;
  final bool accepted;
  final String? error;
  final BigInt? epoch;
  final BigInt? issuedAtMS;
  final BigInt? expiresAtMS;
  final bool? replayed;
  final bool? uncertain;
  final bool? automaticRetry;

  const ForgeRunnerLeaseCaseExpected({
    required this.active,
    required this.accepted,
    required this.error,
    required this.epoch,
    required this.issuedAtMS,
    required this.expiresAtMS,
    required this.replayed,
    required this.uncertain,
    required this.automaticRetry,
  });

  factory ForgeRunnerLeaseCaseExpected.fromJson(Object? value) {
    final json = _leaseObject(value, 'expected');
    final expectedKeys = <String>{};
    if (json.containsKey('accepted')) expectedKeys.add('accepted');
    for (final key in const [
      'active',
      'error',
      'epoch',
      'issued_at_ms',
      'expires_at_ms',
      'replayed',
      'uncertain',
      'automatic_retry',
    ]) {
      if (json.containsKey(key)) expectedKeys.add(key);
    }
    _leaseExactKeys(json, expectedKeys);
    // Active cases describe a boolean projection and intentionally omit the
    // accepted field. Treat that metadata-only operation as accepted for the
    // contract runner while retaining strict boolean validation when present.
    final accepted = json.containsKey('accepted')
        ? _leaseBool(json['accepted'])
        : true;
    final error = json.containsKey('error')
        ? _leaseText(json['error'], 64)
        : null;
    if (accepted && error != null) {
      throw const FormatException('Accepted lease case has an error.');
    }
    if (!accepted && (error == null || error.isEmpty)) {
      throw const FormatException('Rejected lease case has no error.');
    }
    return ForgeRunnerLeaseCaseExpected(
      active: json.containsKey('active') ? _leaseBool(json['active']) : null,
      accepted: accepted,
      error: error,
      epoch: json.containsKey('epoch')
          ? _leasePositiveUint64(json['epoch'])
          : null,
      issuedAtMS: json.containsKey('issued_at_ms')
          ? _leaseUint64(json['issued_at_ms'])
          : null,
      expiresAtMS: json.containsKey('expires_at_ms')
          ? _leaseUint64(json['expires_at_ms'])
          : null,
      replayed: json.containsKey('replayed')
          ? _leaseBool(json['replayed'])
          : null,
      uncertain: json.containsKey('uncertain')
          ? _leaseBool(json['uncertain'])
          : null,
      automaticRetry: json.containsKey('automatic_retry')
          ? _leaseBool(json['automatic_retry'])
          : null,
    );
  }
}

class ForgeRunnerLeaseCase {
  final String name;
  final String operation;
  final BigInt? observedAtMS;
  final String? fencingToken;
  final BigInt? ttlMS;
  final ForgeRunnerLeaseProof? proof;
  final ForgeRunnerLeaseDisposition? disposition;
  final ForgeRunnerLeaseDisposition? seedDisposition;
  final BigInt? seedObservedAtMS;
  final ForgeRunnerLeaseCaseExpected expected;

  const ForgeRunnerLeaseCase({
    required this.name,
    required this.operation,
    required this.observedAtMS,
    required this.fencingToken,
    required this.ttlMS,
    required this.proof,
    required this.disposition,
    required this.seedDisposition,
    required this.seedObservedAtMS,
    required this.expected,
  });

  factory ForgeRunnerLeaseCase.fromJson(Object? value) {
    final json = _leaseObject(value, 'case');
    final expectedKeys = {'name', 'operation', 'expected'};
    for (final key in const [
      'observed_at_ms',
      'fencing_token',
      'ttl_ms',
      'proof',
      'disposition',
      'seed_disposition',
      'seed_observed_at_ms',
    ]) {
      if (json.containsKey(key)) expectedKeys.add(key);
    }
    _leaseExactKeys(json, expectedKeys);
    final operation = _leaseOperation(json['operation']);
    final observed = json.containsKey('observed_at_ms')
        ? _leaseUint64(json['observed_at_ms'])
        : null;
    final seedObserved = json.containsKey('seed_observed_at_ms')
        ? _leaseUint64(json['seed_observed_at_ms'])
        : null;
    return ForgeRunnerLeaseCase(
      name: _leaseIdentity(json['name']),
      operation: operation,
      observedAtMS: observed,
      fencingToken: json.containsKey('fencing_token')
          ? _leaseToken(json['fencing_token'])
          : null,
      ttlMS: json.containsKey('ttl_ms') ? _leaseUint64(json['ttl_ms']) : null,
      proof: json.containsKey('proof')
          ? ForgeRunnerLeaseProof.fromJson(json['proof'])
          : null,
      disposition: json.containsKey('disposition')
          ? ForgeRunnerLeaseDisposition.fromJson(json['disposition'])
          : null,
      seedDisposition: json.containsKey('seed_disposition')
          ? ForgeRunnerLeaseDisposition.fromJson(json['seed_disposition'])
          : null,
      seedObservedAtMS: seedObserved,
      expected: ForgeRunnerLeaseCaseExpected.fromJson(json['expected']),
    );
  }
}

class ForgeRunnerLeaseFencingFixture {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeRunnerLeaseAuthority authority;
  final ForgeRunnerLeaseGrant grant;
  final List<ForgeRunnerLeaseCase> cases;

  const ForgeRunnerLeaseFencingFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.authority,
    required this.grant,
    required this.cases,
  });

  factory ForgeRunnerLeaseFencingFixture.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException('Forge Runner lease fixture is too large.');
    }
    _leaseRejectDuplicateKeys(source);
    return ForgeRunnerLeaseFencingFixture.fromJson(jsonDecode(source));
  }

  factory ForgeRunnerLeaseFencingFixture.fromJson(Object? value) {
    final json = _leaseObject(value, 'fixture');
    _leaseExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'authority',
      'grant',
      'cases',
    });
    if (json['schema_version'] != forgeRunnerLeaseFencingSchema ||
        json['evaluation_mode'] != forgeRunnerLeaseFencingEvaluationMode) {
      throw const FormatException('Invalid Forge Runner lease envelope.');
    }
    final rawCases = json['cases'];
    if (rawCases is! List || rawCases.length != 16) {
      throw const FormatException('Invalid Forge Runner lease case count.');
    }
    final cases = rawCases
        .map(ForgeRunnerLeaseCase.fromJson)
        .toList(growable: false);
    if (cases.map((value) => value.name).toSet().length != cases.length) {
      throw const FormatException('Duplicate Forge Runner lease case name.');
    }
    final authority = ForgeRunnerLeaseAuthority.fromJson(json['authority']);
    return ForgeRunnerLeaseFencingFixture(
      schemaVersion: forgeRunnerLeaseFencingSchema,
      evaluationMode: forgeRunnerLeaseFencingEvaluationMode,
      authority: authority,
      grant: ForgeRunnerLeaseGrant.fromJson(json['grant']),
      cases: List.unmodifiable(cases),
    );
  }
}

/// Dart's JSON decoder keeps the last value when an object repeats a key.
/// Runner lease fixtures are cross-runtime contracts, so reject ambiguity at
/// every object depth before materializing the map.
void _leaseRejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge Runner lease fixture JSON key.',
            );
          }
        }
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      stringStart = index;
    } else if (char == '{') {
      objects.add(<String>{});
    } else if (char == '}') {
      if (objects.isEmpty) {
        throw const FormatException('Invalid Forge Runner lease fixture JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty || escaped) {
    throw const FormatException('Invalid Forge Runner lease fixture JSON.');
  }
}

String _leaseOperation(Object? value) => _leaseOneOf(value, const {
  'active',
  'renew',
  'proof',
  'terminal',
  'terminal_replay',
  'terminal_conflict',
  'renew_after_terminal',
});

bool _leaseProofEquals(
  ForgeRunnerLeaseProof left,
  ForgeRunnerLeaseProof right,
) =>
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken;

bool _leaseDispositionEquals(
  ForgeRunnerLeaseDisposition left,
  ForgeRunnerLeaseDisposition right,
) =>
    left.kind == right.kind &&
    left.receiptSHA256 == right.receiptSHA256 &&
    left.reason == right.reason;

Map<String, dynamic> _leaseObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Forge Runner lease $label must be an object.');
  }
  return Map<String, dynamic>.from(value);
}

void _leaseExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge Runner lease fields.');
  }
}

String _leaseText(Object? value, int maximum) {
  if (value is! String || !_validLeaseUnicode(value)) {
    throw const FormatException('Invalid Forge Runner lease text.');
  }
  final byteLength = utf8.encode(value).length;
  if (value.isEmpty ||
      byteLength > maximum ||
      value.trim() != value ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge Runner lease text.');
  }
  return value;
}

String _leaseIdentity(Object? value) => _leaseText(value, 128);

String _leaseToken(Object? value) => _leaseText(value, 256);

String _leaseReason(Object? value) => _leaseText(value, 256);

String _leaseDigest(Object? value) {
  final text = _leaseText(value, 64);
  if (text.length != 64 ||
      text.codeUnits.any(
        (code) =>
            !((code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66)),
      )) {
    throw const ForgeRunnerLeaseError('invalid_digest');
  }
  return text;
}

String _leaseOneOf(Object? value, Set<String> allowed) {
  final text = _leaseText(value, 64);
  if (!allowed.contains(text)) {
    throw FormatException('Invalid Forge Runner lease value: $text');
  }
  return text;
}

int _leaseVersion(Object? value) {
  if (value is! int || value != 1) {
    throw const ForgeRunnerLeaseError('unsupported_version');
  }
  return value;
}

bool _leaseBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge Runner lease boolean.');
  }
  return value;
}

BigInt _leaseUint64(Object? value) {
  final number = switch (value) {
    int value => BigInt.from(value),
    BigInt value => value,
    String value => BigInt.tryParse(value),
    _ => null,
  };
  if (number == null ||
      number.isNegative ||
      number > _forgeRunnerLeaseMaxUint64) {
    throw const FormatException('Invalid Forge Runner lease uint64.');
  }
  return number;
}

BigInt _leasePositiveUint64(Object? value) {
  final number = _leaseUint64(value);
  if (number == BigInt.zero) {
    throw const ForgeRunnerLeaseError('invalid_epoch');
  }
  return number;
}

void _leaseTTL(BigInt value) {
  if (value < BigInt.from(forgeRunnerLeaseFencingMinTTLMS) ||
      value > BigInt.from(forgeRunnerLeaseFencingMaxTTLMS)) {
    throw const ForgeRunnerLeaseError('invalid_lease_duration');
  }
}

Object _leaseJsonUint64(BigInt value) =>
    value <= BigInt.from(9007199254740991) ? value.toInt() : value.toString();

bool _validLeaseUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= (0xdb00 + 0xff)) {
      if (index + 1 >= value.length) return false;
      final next = value.codeUnitAt(++index);
      if (next < 0xdc00 || next > 0xdfff) return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}
