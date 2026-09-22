import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_lease_fencing.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_LEASE_FENCING_FIXTURE'];

  test('consumes the shared Go/Rust lease and fencing fixture', () {
    if (fixturePath == null || fixturePath.isEmpty) return;
    final fixture = ForgeRunnerLeaseFencingFixture.fromJsonText(
      File(fixturePath).readAsStringSync(),
    );
    expect(fixture.schemaVersion, forgeRunnerLeaseFencingSchema);
    expect(fixture.evaluationMode, forgeRunnerLeaseFencingEvaluationMode);
    expect(fixture.authority.isOffline, isTrue);
    expect(fixture.cases, hasLength(16));
    expect(fixture.grant.isActive(BigInt.from(100)), isTrue);

    for (final testCase in fixture.cases) {
      _runCase(fixture.grant, testCase);
    }
  });

  test('fails closed on unknown fields and enabled authority', () {
    final fixture = _fixture();
    fixture['unexpected'] = true;
    expect(
      () => ForgeRunnerLeaseFencingFixture.fromJson(fixture),
      throwsA(isA<FormatException>()),
    );

    final authority = <String, dynamic>{
      'device_identity_verified': false,
      'command_persisted': false,
      'reservation_created': false,
      'execution_authorized': false,
      'dispatch_performed': true,
      'audit_published': false,
    };
    expect(
      () => ForgeRunnerLeaseAuthority.fromJson(authority),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'rejects duplicate JSON keys before lease fixture decoding',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final duplicateRoot = source.replaceFirst(
        '  "schema_version": "forge.runner-lease-fencing/v1",\n',
        '  "schema_version": "forge.runner-lease-fencing/v1",\n'
            '  "schema_version": "forge.runner-lease-fencing/v1",\n',
      );
      expect(duplicateRoot, isNot(source));
      expect(
        () => ForgeRunnerLeaseFencingFixture.fromJsonText(duplicateRoot),
        throwsA(isA<FormatException>()),
      );

      final duplicateNested = source.replaceFirst(
        '    "device_identity_verified": false,\n',
        '    "device_identity_verified": false,\n'
            '    "device_identity_verified": false,\n',
      );
      expect(duplicateNested, isNot(source));
      expect(
        () => ForgeRunnerLeaseFencingFixture.fromJsonText(duplicateNested),
        throwsA(isA<FormatException>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects stale proofs after a fencing epoch rotates', () {
    final grant = ForgeRunnerLeaseGrant.issue(
      attemptID: 'attempt-1',
      targetID: 'runner-1',
      epoch: BigInt.one,
      fencingToken: 'fence-1',
      issuedAtMS: BigInt.from(100),
      ttlMS: BigInt.from(10000),
    );
    final state = ForgeRunnerLeaseState(grant);
    final oldProof = grant.proof();
    state.renew(
      observedAtMS: BigInt.from(1000),
      fencingToken: 'fence-2',
      ttlMS: BigInt.from(10000),
    );
    expect(
      () => state.submitTerminal(
        proof: oldProof,
        disposition: const ForgeRunnerLeaseDisposition(
          kind: 'completed',
          receiptSHA256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        observedAtMS: BigInt.from(2000),
      ),
      throwsA(
        isA<ForgeRunnerLeaseError>().having(
          (error) => error.code,
          'code',
          'epoch_mismatch',
        ),
      ),
    );
  });

  test('rejects explicit null optional disposition fields', () {
    expect(
      () => ForgeRunnerLeaseDisposition.fromJson({
        'kind': 'failed',
        'reason': null,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeRunnerLeaseDisposition.fromJson({
        'kind': 'completed',
        'receipt_sha256': null,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeRunnerLeaseDisposition.fromJson({
        'kind': 'failed',
        'reason': 'late',
        'receipt_sha256': null,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('uses UTF-8 byte bounds and rejects malformed Unicode', () {
    final acceptedID = 'é' * 64; // exactly 128 UTF-8 bytes
    final grant = ForgeRunnerLeaseGrant.issue(
      attemptID: acceptedID,
      targetID: 'runner-1',
      epoch: BigInt.one,
      fencingToken: 'fence-1',
      issuedAtMS: BigInt.from(100),
      ttlMS: BigInt.from(1000),
    );
    expect(grant.attemptID, acceptedID);
    expect(
      () => ForgeRunnerLeaseGrant.issue(
        attemptID: '${'é' * 64}a',
        targetID: 'runner-1',
        epoch: BigInt.one,
        fencingToken: 'fence-1',
        issuedAtMS: BigInt.from(100),
        ttlMS: BigInt.from(1000),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeRunnerLeaseGrant.issue(
        attemptID: String.fromCharCode(0xd800),
        targetID: 'runner-1',
        epoch: BigInt.one,
        fencingToken: 'fence-1',
        issuedAtMS: BigInt.from(100),
        ttlMS: BigInt.from(1000),
      ),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeRunnerLeaseDisposition.fromJson({
        'kind': 'failed',
        'reason': 'é' * 129, // 258 UTF-8 bytes
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('documents local round-trip encoding for unsafe uint64 values', () {
    final max = (BigInt.one << 64) - BigInt.one;
    final grant = ForgeRunnerLeaseGrant.issue(
      attemptID: 'attempt-1',
      targetID: 'runner-1',
      epoch: max,
      fencingToken: 'fence-1',
      issuedAtMS: max - BigInt.from(1000),
      ttlMS: BigInt.from(1000),
    );
    final encoded = grant.toJson();
    expect(encoded['epoch'], max.toString());
    expect(encoded['issued_at_ms'], (max - BigInt.from(1000)).toString());
    expect(encoded['expires_at_ms'], max.toString());
    final decoded = ForgeRunnerLeaseGrant.fromJson(encoded);
    expect(decoded.epoch, max);
    expect(decoded.expiresAtMS, max);
  });
}

void _runCase(ForgeRunnerLeaseGrant grant, ForgeRunnerLeaseCase testCase) {
  final expected = testCase.expected;
  switch (testCase.operation) {
    case 'active':
      expect(
        grant.isActive(testCase.observedAtMS!),
        expected.active,
        reason: testCase.name,
      );
    case 'renew':
      _expectAccepted(testCase, () {
        final renewed = grant.renew(
          observedAtMS: testCase.observedAtMS!,
          fencingToken: testCase.fencingToken!,
          ttlMS: testCase.ttlMS!,
        );
        expect(renewed.epoch, expected.epoch, reason: testCase.name);
        expect(renewed.issuedAtMS, expected.issuedAtMS, reason: testCase.name);
        expect(
          renewed.expiresAtMS,
          expected.expiresAtMS,
          reason: testCase.name,
        );
      });
    case 'proof':
      _expectAccepted(testCase, () {
        grant.validateProof(testCase.proof!, testCase.observedAtMS!);
      });
    case 'terminal':
    case 'terminal_replay':
    case 'terminal_conflict':
      final state = ForgeRunnerLeaseState(grant);
      if (testCase.seedDisposition != null) {
        state.submitTerminal(
          proof: grant.proof(),
          disposition: testCase.seedDisposition!,
          observedAtMS: testCase.seedObservedAtMS!,
        );
      }
      _expectAccepted(testCase, () {
        final result = state.submitTerminal(
          proof: testCase.proof ?? grant.proof(),
          disposition: testCase.disposition!,
          observedAtMS: testCase.observedAtMS!,
        );
        expect(
          result.replayed,
          expected.replayed ?? false,
          reason: testCase.name,
        );
        expect(
          result.receipt.disposition.isUncertain,
          expected.uncertain ?? false,
          reason: testCase.name,
        );
        if (expected.automaticRetry == true) {
          fail('lease fixture must never enable automatic retry');
        }
      });
    case 'renew_after_terminal':
      final state = ForgeRunnerLeaseState(grant);
      state.submitTerminal(
        proof: grant.proof(),
        disposition: testCase.seedDisposition!,
        observedAtMS: testCase.seedObservedAtMS!,
      );
      _expectAccepted(testCase, () {
        state.renew(
          observedAtMS: testCase.observedAtMS!,
          fencingToken: testCase.fencingToken!,
          ttlMS: testCase.ttlMS!,
        );
      });
    default:
      fail('Unsupported lease fixture operation ${testCase.operation}');
  }
}

void _expectAccepted(ForgeRunnerLeaseCase testCase, void Function() action) {
  final expected = testCase.expected;
  if (expected.accepted) {
    action();
    return;
  }
  expect(
    action,
    throwsA(
      isA<ForgeRunnerLeaseError>().having(
        (error) => error.code,
        'code',
        expected.error,
      ),
    ),
    reason: testCase.name,
  );
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgeRunnerLeaseFencingSchema,
  'evaluation_mode': forgeRunnerLeaseFencingEvaluationMode,
  'authority': {
    'device_identity_verified': false,
    'command_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
  'grant': {
    'v': 1,
    'attempt_id': 'attempt-1',
    'target_id': 'runner-1',
    'epoch': 1,
    'fencing_token': 'fence-1',
    'issued_at_ms': 100,
    'expires_at_ms': 10100,
  },
  'cases': [
    {
      'name': 'active_at_issue',
      'operation': 'active',
      'observed_at_ms': 100,
      'expected': {'active': true},
    },
  ],
};
