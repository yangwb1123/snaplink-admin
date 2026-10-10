part of 'forge_runner_lease_fencing.dart';

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
