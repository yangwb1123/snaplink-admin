import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_identity.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_DEVICE_IDENTITY_CONTRACT_FIXTURE'];

  test(
    'consumes the pure device identity binding fixture',
    () {
      final fixture = _object(
        decodeForgeDeviceIdentityJSON(File(fixturePath!).readAsStringSync()),
      );
      _expectExactKeys(fixture, {
        'schema_version',
        'evaluation_mode',
        'notice',
        'owner_declaration',
        'device',
        'challenge',
        'authority',
        'cases',
      });
      expect(fixture['schema_version'], forgeDeviceIdentityProofSchema);
      expect(
        fixture['evaluation_mode'],
        forgeDeviceIdentityProofEvaluationMode,
      );
      expect(fixture['notice'], forgeDeviceIdentityProofNotice);

      final owner = ForgeDeviceOwner.fromJson(fixture['owner_declaration']);
      final device = ForgeDeviceIdentityBinding.fromJson(fixture['device']);
      final challenge = ForgeDeviceIdentityChallenge.fromJson(
        fixture['challenge'],
      );
      expect(owner, device.owner);
      expect(device.deviceID, 'device-a');
      expect(device.keyID, 'key-a');
      expect(device.approvalState, 'approved');
      expect(device.credentialState, 'active');
      expect(challenge.consumed, isFalse);
      _assertOfflineAuthority(fixture['authority']);

      final cases = fixture['cases'];
      if (cases is! List) {
        throw const FormatException('Expected identity proof cases.');
      }
      expect(cases.length, 12);
      final names = <String>{};
      for (final rawCase in cases) {
        final testCase = _object(rawCase);
        _expectExactKeys(testCase, {
          'name',
          'now_ms',
          'challenge_consumed',
          'device_approval_state',
          'device_credential_state',
          'proof',
          'expected',
        });
        final name = _text(testCase['name']);
        expect(names.add(name), isTrue, reason: name);
        final proof = ForgeDeviceIdentityProof.fromJson(testCase['proof']);
        final expected = _object(testCase['expected']);
        _expectExactKeys(expected, {
          'accepted',
          'reason',
          'identity_bound',
          'approval_required',
        });
        ForgeDeviceIdentityProofDecision evaluate() => _evaluateCase(
          owner: owner,
          device: device,
          challenge: challenge,
          testCase: testCase,
          proof: proof,
        );
        _assertOutcome(name, expected, evaluate);
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('nested decoders reject unknown fields and non-false authority', () {
    final owner = const ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    );
    final device = <String, dynamic>{
      'device_id': 'device-a',
      'owner': {
        'issuer': owner.issuer,
        'subject': owner.subject,
        'tenant_id': owner.tenantID,
      },
      'key_id': 'key-a',
      'public_key_sha256': 'a' * 64,
      'approval_state': 'approved',
      'credential_state': 'active',
      'unexpected': true,
    };
    expect(
      () => ForgeDeviceIdentityBinding.fromJson(device),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => _assertOfflineAuthority({
        'identity_verified': true,
        'challenge_consumed': false,
        'enrollment_persisted': false,
        'owner_approval_recorded': false,
        'credential_issued': false,
        'inventory_authoritative': false,
        'execution_authorized': false,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('invalid structural proof fails closed without authority', () {
    const owner = ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    );
    const device = ForgeDeviceIdentityBinding(
      deviceID: 'device-a',
      owner: owner,
      keyID: 'key-a',
      publicKeySHA256: 'not-a-digest',
      approvalState: 'approved',
      credentialState: 'active',
    );
    final challenge = ForgeDeviceIdentityChallenge(
      challengeID: 'challenge-a',
      challengeSHA256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      issuedAtMS: BigInt.from(100000),
      expiresAtMS: BigInt.from(160000),
      consumed: false,
    );
    final proof = ForgeDeviceIdentityProof(
      deviceID: 'device-a',
      keyID: 'key-a',
      publicKeySHA256: 'not-a-digest',
      owner: owner,
      challengeID: 'challenge-a',
      challengeSHA256:
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
      proofSHA256:
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
      issuedAtMS: BigInt.from(120000),
      expiresAtMS: BigInt.from(150000),
    );
    expect(
      () => evaluateForgeDeviceIdentityProof(
        owner: owner,
        device: device,
        challenge: challenge,
        proof: proof,
        nowMS: BigInt.from(120000),
      ),
      throwsA(
        isA<ForgeDeviceIdentityProofError>().having(
          (error) => error.code,
          'code',
          'invalid_binding',
        ),
      ),
    );
  });

  test('preserves a full uint64 timestamp from fixture text', () {
    final challenge = ForgeDeviceIdentityChallenge.fromJson(
      decodeForgeDeviceIdentityJSON(
        '{"challenge_id":"challenge-a",'
        '"challenge_sha256":"${'a' * 64}",'
        '"issued_at_ms":1,'
        '"expires_at_ms":18446744073709551615,'
        '"consumed":false}',
      ),
    );
    expect(challenge.expiresAtMS, BigInt.parse('18446744073709551615'));
  });
}

ForgeDeviceIdentityProofDecision _evaluateCase({
  required ForgeDeviceOwner owner,
  required ForgeDeviceIdentityBinding device,
  required ForgeDeviceIdentityChallenge challenge,
  required Map<String, dynamic> testCase,
  required ForgeDeviceIdentityProof proof,
}) {
  final nowMS = _bigInt(testCase['now_ms']);
  final caseDevice = ForgeDeviceIdentityBinding(
    deviceID: device.deviceID,
    owner: device.owner,
    keyID: device.keyID,
    publicKeySHA256: device.publicKeySHA256,
    approvalState: _text(testCase['device_approval_state']),
    credentialState: _text(testCase['device_credential_state']),
  );
  final caseChallenge = ForgeDeviceIdentityChallenge(
    challengeID: challenge.challengeID,
    challengeSHA256: challenge.challengeSHA256,
    issuedAtMS: challenge.issuedAtMS,
    expiresAtMS: challenge.expiresAtMS,
    consumed: _bool(testCase['challenge_consumed']),
  );
  return evaluateForgeDeviceIdentityProof(
    owner: owner,
    device: caseDevice,
    challenge: caseChallenge,
    proof: proof,
    nowMS: nowMS,
  );
}

void _assertOutcome(
  String name,
  Map<String, dynamic> expected,
  ForgeDeviceIdentityProofDecision Function() evaluate,
) {
  final accepted = _bool(expected['accepted']);
  final reason = _text(expected['reason']);
  final identityBound = _bool(expected['identity_bound']);
  final approvalRequired = _bool(expected['approval_required']);
  if (!accepted) {
    expect(
      evaluate,
      throwsA(
        isA<ForgeDeviceIdentityProofError>().having(
          (error) => error.code,
          'code',
          reason,
        ),
      ),
      reason: name,
    );
    return;
  }
  final decision = evaluate();
  expect(decision.reason, reason, reason: name);
  expect(decision.identityBound, identityBound, reason: name);
  expect(decision.approvalRequired, approvalRequired, reason: name);
}

void _assertOfflineAuthority(Object? value) {
  final authority = _object(value);
  _expectExactKeys(authority, {
    'identity_verified',
    'challenge_consumed',
    'enrollment_persisted',
    'owner_approval_recorded',
    'credential_issued',
    'inventory_authoritative',
    'execution_authorized',
  });
  for (final item in authority.values) {
    if (item is! bool || item) {
      throw const FormatException(
        'Forge device identity authority must remain false.',
      );
    }
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected identity proof object.');
  }
  return Map<String, dynamic>.from(value);
}

void _expectExactKeys(Map<String, dynamic> value, Set<String> expected) {
  expect(value.keys.toSet(), expected);
}

String _text(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Expected identity proof text.');
  }
  return value;
}

bool _bool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Expected identity proof boolean.');
  }
  return value;
}

BigInt _bigInt(Object? value) {
  if (value is! BigInt && value is! int) {
    throw const FormatException('Expected identity proof integer.');
  }
  return value is BigInt ? value : BigInt.from(value as int);
}
