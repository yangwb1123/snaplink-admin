import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_heartbeat_persistence.dart';
import 'package:sso_admin/api/forge_device_identity.dart';
import 'package:sso_admin/api/forge_device_inventory_persistence.dart';

void main() {
  final fixturePath = Platform
      .environment['FORGE_DEVICE_ENROLLMENT_HEARTBEAT_LIFECYCLE_FIXTURE'];

  test(
    'consumes the joined identity heartbeat inventory fixture',
    () {
      final fixture = _Fixture.fromJsonText(
        File(fixturePath!).readAsStringSync(),
      );
      expect(fixture.authority.anyGranted, isFalse);
      expect(fixture.cases, hasLength(10));

      ForgeDeviceHeartbeatPersistenceState? currentHeartbeat;
      ForgeDeviceInventoryPersistenceState? currentInventory;
      for (final testCase in fixture.cases) {
        final proofOwner = testCase.proofOwner == 'foreign'
            ? ForgeDeviceOwner(
                issuer: fixture.owner.issuer,
                subject: 'user-foreign',
                tenantID: fixture.owner.tenantID,
              )
            : fixture.owner;
        final identity = ForgeDeviceIdentityBinding(
          deviceID: fixture.device.deviceID,
          owner: fixture.owner,
          keyID: fixture.device.keyID,
          publicKeySHA256: fixture.device.publicKeySHA256,
          approvalState: testCase.approvalState,
          credentialState: testCase.credentialState,
        );
        ForgeDeviceIdentityProofDecision? decision;
        String? identityError;
        try {
          decision = evaluateForgeDeviceIdentityProof(
            owner: fixture.owner,
            device: identity,
            challenge: ForgeDeviceIdentityChallenge(
              challengeID: fixture.challenge.challengeID,
              challengeSHA256: fixture.challenge.challengeSHA256,
              issuedAtMS: fixture.challenge.issuedAtMS,
              expiresAtMS: fixture.challenge.expiresAtMS,
              consumed: testCase.challengeConsumed,
            ),
            proof: ForgeDeviceIdentityProof(
              deviceID: fixture.proof.deviceID,
              keyID: fixture.proof.keyID,
              publicKeySHA256: fixture.proof.publicKeySHA256,
              owner: proofOwner,
              challengeID: fixture.proof.challengeID,
              challengeSHA256: fixture.proof.challengeSHA256,
              proofSHA256: fixture.proof.proofSHA256,
              issuedAtMS: fixture.proof.issuedAtMS,
              expiresAtMS: fixture.proof.expiresAtMS,
            ),
            nowMS: testCase.identityNowMS,
          );
        } on ForgeDeviceIdentityProofError catch (error) {
          identityError = error.code;
        }
        if (identityError != null) {
          expect(testCase.expected.error, identityError, reason: testCase.name);
          continue;
        }
        expect(decision, isNotNull, reason: testCase.name);
        if (decision!.approvalRequired) {
          expect(testCase.expected.accepted, isFalse, reason: testCase.name);
          expect(
            testCase.expected.error,
            'approval_required',
            reason: testCase.name,
          );
          continue;
        }

        final heartbeat = ForgeDeviceHeartbeat(
          deviceID: testCase.heartbeat.deviceID,
          instanceID: testCase.heartbeat.instanceID,
          generation: testCase.heartbeat.generation,
          sequence: testCase.heartbeat.sequence,
          capabilities: fixture.capabilities,
        );
        final heartbeatResult = commitForgeDeviceHeartbeat(
          device: ForgeDeviceHeartbeatPersistenceDevice(
            deviceID: fixture.device.deviceID,
            tenantID: fixture.owner.tenantID,
            approvalState: 'approved',
          ),
          current: currentHeartbeat,
          expectedRevision: testCase.expectedHeartbeatRevision,
          heartbeat: heartbeat,
          serverObservedAtMS: testCase.serverObservedAtMS,
          leaseTTLMS: testCase.leaseTTLMS,
        );
        if (!heartbeatResult.accepted) {
          expect(
            testCase.expected.error,
            heartbeatResult.error,
            reason: testCase.name,
          );
          continue;
        }
        final nextHeartbeat = heartbeatResult.state!;
        final inventoryResult = commitForgeDeviceInventory(
          current: currentInventory,
          expectedRevision: testCase.expectedInventoryRevision,
          device: ForgeDeviceInventoryPersistenceDevice(
            deviceID: fixture.device.deviceID,
            owner: fixture.owner,
            approvalState: 'approved',
            cordonState: fixture.device.cordonState,
            reservationState: fixture.device.reservationState,
          ),
          runner: ForgeDeviceInventoryPersistenceRunner(
            deviceID: nextHeartbeat.deviceID,
            instanceID: nextHeartbeat.instanceID,
            generation: nextHeartbeat.generation,
            heartbeatSequence: nextHeartbeat.heartbeatSequence,
            serverObservedAtMS: nextHeartbeat.serverObservedAtMS,
            capabilityLeaseExpiresAtMS:
                nextHeartbeat.capabilityLeaseExpiresAtMS,
            liveness: 'online',
            capabilities: nextHeartbeat.capabilities!,
          ),
        );
        if (!inventoryResult.accepted) {
          expect(
            testCase.expected.error,
            inventoryResult.error,
            reason: testCase.name,
          );
          continue;
        }
        final projectionResult = projectForgeDeviceInventory(
          value: inventoryResult.state!,
          evaluationOwner: fixture.owner,
          evaluatedAtMS: testCase.evaluatedAtMS,
          staleAfterMS: testCase.staleAfterMS,
        );
        expect(projectionResult.accepted, isTrue, reason: testCase.name);
        final projection = projectionResult.projection!;
        expect(
          nextHeartbeat.revision,
          testCase.expected.heartbeatRevision,
          reason: testCase.name,
        );
        expect(
          inventoryResult.state!.revision,
          testCase.expected.inventoryRevision,
          reason: testCase.name,
        );
        expect(
          nextHeartbeat.generation,
          testCase.expected.generation,
          reason: testCase.name,
        );
        expect(
          nextHeartbeat.heartbeatSequence,
          testCase.expected.heartbeatSequence,
          reason: testCase.name,
        );
        expect(
          projection.status,
          testCase.expected.status,
          reason: testCase.name,
        );
        expect(
          projection.fresh,
          testCase.expected.fresh,
          reason: testCase.name,
        );
        expect(
          projection.declaredEligible,
          testCase.expected.declaredEligible,
          reason: testCase.name,
        );
        currentHeartbeat = nextHeartbeat;
        currentInventory = inventoryResult.state;
      }
      expect(currentHeartbeat, isNotNull);
      expect(currentInventory, isNotNull);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

class _Fixture {
  final ForgeDeviceOwner owner;
  final _Device device;
  final _Challenge challenge;
  final _Proof proof;
  final ForgeDeviceHeartbeatReferenceCapabilities capabilities;
  final _Authority authority;
  final List<_Case> cases;

  const _Fixture({
    required this.owner,
    required this.device,
    required this.challenge,
    required this.proof,
    required this.capabilities,
    required this.authority,
    required this.cases,
  });

  factory _Fixture.fromJsonText(String source) =>
      _Fixture.fromJson(jsonDecode(source));

  factory _Fixture.fromJson(Object? value) {
    final json = _object(value, {
      'schema_version',
      'evaluation_mode',
      'notice',
      'owner',
      'device',
      'challenge',
      'proof',
      'capabilities',
      'authority',
      'cases',
    });
    if (json['schema_version'] !=
            'forge.device-enrollment-heartbeat-lifecycle/v1' ||
        json['evaluation_mode'] != 'pure_joined_value_transition') {
      throw const FormatException('Invalid joined lifecycle envelope.');
    }
    final rawCases = json['cases'];
    if (rawCases is! List || rawCases.length != 10) {
      throw const FormatException('Invalid joined lifecycle cases.');
    }
    return _Fixture(
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      device: _Device.fromJson(json['device']),
      challenge: _Challenge.fromJson(json['challenge']),
      proof: _Proof.fromJson(json['proof']),
      capabilities: ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
        json['capabilities'],
      ),
      authority: _Authority.fromJson(json['authority']),
      cases: List.unmodifiable(rawCases.map(_Case.fromJson)),
    );
  }
}

class _Device {
  final String deviceID;
  final String keyID;
  final String publicKeySHA256;
  final String approvalState;
  final String credentialState;
  final String cordonState;
  final String reservationState;

  const _Device({
    required this.deviceID,
    required this.keyID,
    required this.publicKeySHA256,
    required this.approvalState,
    required this.credentialState,
    required this.cordonState,
    required this.reservationState,
  });

  factory _Device.fromJson(Object? value) {
    final json = _object(value, {
      'device_id',
      'key_id',
      'public_key_sha256',
      'approval_state',
      'credential_state',
      'cordon_state',
      'reservation_state',
    });
    return _Device(
      deviceID: _text(json['device_id']),
      keyID: _text(json['key_id']),
      publicKeySHA256: _text(json['public_key_sha256']),
      approvalState: _text(json['approval_state']),
      credentialState: _text(json['credential_state']),
      cordonState: _text(json['cordon_state']),
      reservationState: _text(json['reservation_state']),
    );
  }
}

class _Challenge {
  final String challengeID;
  final String challengeSHA256;
  final BigInt issuedAtMS;
  final BigInt expiresAtMS;

  const _Challenge({
    required this.challengeID,
    required this.challengeSHA256,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory _Challenge.fromJson(Object? value) {
    final json = _object(value, {
      'challenge_id',
      'challenge_sha256',
      'issued_at_ms',
      'expires_at_ms',
    });
    return _Challenge(
      challengeID: _text(json['challenge_id']),
      challengeSHA256: _text(json['challenge_sha256']),
      issuedAtMS: _uint(json['issued_at_ms']),
      expiresAtMS: _uint(json['expires_at_ms']),
    );
  }
}

class _Proof {
  final String deviceID;
  final String keyID;
  final String publicKeySHA256;
  final ForgeDeviceOwner owner;
  final String challengeID;
  final String challengeSHA256;
  final String proofSHA256;
  final BigInt issuedAtMS;
  final BigInt expiresAtMS;

  const _Proof({
    required this.deviceID,
    required this.keyID,
    required this.publicKeySHA256,
    required this.owner,
    required this.challengeID,
    required this.challengeSHA256,
    required this.proofSHA256,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory _Proof.fromJson(Object? value) {
    final json = _object(value, {
      'device_id',
      'key_id',
      'public_key_sha256',
      'owner',
      'challenge_id',
      'challenge_sha256',
      'proof_sha256',
      'issued_at_ms',
      'expires_at_ms',
    });
    return _Proof(
      deviceID: _text(json['device_id']),
      keyID: _text(json['key_id']),
      publicKeySHA256: _text(json['public_key_sha256']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      challengeID: _text(json['challenge_id']),
      challengeSHA256: _text(json['challenge_sha256']),
      proofSHA256: _text(json['proof_sha256']),
      issuedAtMS: _uint(json['issued_at_ms']),
      expiresAtMS: _uint(json['expires_at_ms']),
    );
  }
}

class _Authority {
  final bool identityVerified;
  final bool challengeConsumed;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const _Authority({
    required this.identityVerified,
    required this.challengeConsumed,
    required this.heartbeatPersisted,
    required this.inventoryAuthoritative,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  bool get anyGranted =>
      identityVerified ||
      challengeConsumed ||
      heartbeatPersisted ||
      inventoryAuthoritative ||
      reservationCreated ||
      executionAuthorized ||
      dispatchPerformed;

  factory _Authority.fromJson(Object? value) {
    final json = _object(value, {
      'identity_verified',
      'challenge_consumed',
      'heartbeat_persisted',
      'inventory_authoritative',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    return _Authority(
      identityVerified: _bool(json['identity_verified']),
      challengeConsumed: _bool(json['challenge_consumed']),
      heartbeatPersisted: _bool(json['heartbeat_persisted']),
      inventoryAuthoritative: _bool(json['inventory_authoritative']),
      reservationCreated: _bool(json['reservation_created']),
      executionAuthorized: _bool(json['execution_authorized']),
      dispatchPerformed: _bool(json['dispatch_performed']),
    );
  }
}

class _Case {
  final String name;
  final String approvalState;
  final String credentialState;
  final bool challengeConsumed;
  final String proofOwner;
  final _Heartbeat heartbeat;
  final BigInt expectedHeartbeatRevision;
  final BigInt expectedInventoryRevision;
  final BigInt serverObservedAtMS;
  final BigInt leaseTTLMS;
  final BigInt identityNowMS;
  final BigInt evaluatedAtMS;
  final BigInt staleAfterMS;
  final _Expected expected;

  const _Case({
    required this.name,
    required this.approvalState,
    required this.credentialState,
    required this.challengeConsumed,
    required this.proofOwner,
    required this.heartbeat,
    required this.expectedHeartbeatRevision,
    required this.expectedInventoryRevision,
    required this.serverObservedAtMS,
    required this.leaseTTLMS,
    required this.identityNowMS,
    required this.evaluatedAtMS,
    required this.staleAfterMS,
    required this.expected,
  });

  factory _Case.fromJson(Object? value) {
    final json = _object(value, {
      'name',
      'approval_state',
      'credential_state',
      'challenge_consumed',
      'proof_owner',
      'heartbeat',
      'expected_heartbeat_revision',
      'expected_inventory_revision',
      'server_observed_at_ms',
      'lease_ttl_ms',
      'identity_now_ms',
      'evaluated_at_ms',
      'stale_after_ms',
      'expected',
    });
    return _Case(
      name: _text(json['name']),
      approvalState: _text(json['approval_state']),
      credentialState: _text(json['credential_state']),
      challengeConsumed: _bool(json['challenge_consumed']),
      proofOwner: _text(json['proof_owner']),
      heartbeat: _Heartbeat.fromJson(json['heartbeat']),
      expectedHeartbeatRevision: _uint(json['expected_heartbeat_revision']),
      expectedInventoryRevision: _uint(json['expected_inventory_revision']),
      serverObservedAtMS: _uint(json['server_observed_at_ms']),
      leaseTTLMS: _uint(json['lease_ttl_ms']),
      identityNowMS: _uint(json['identity_now_ms']),
      evaluatedAtMS: _uint(json['evaluated_at_ms']),
      staleAfterMS: _uint(json['stale_after_ms']),
      expected: _Expected.fromJson(json['expected']),
    );
  }
}

class _Heartbeat {
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt sequence;

  const _Heartbeat({
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.sequence,
  });

  factory _Heartbeat.fromJson(Object? value) {
    final json = _object(value, {
      'device_id',
      'instance_id',
      'generation',
      'sequence',
    });
    return _Heartbeat(
      deviceID: _text(json['device_id']),
      instanceID: _text(json['instance_id']),
      generation: _uint(json['generation']),
      sequence: _uint(json['sequence']),
    );
  }
}

class _Expected {
  final bool accepted;
  final String? error;
  final BigInt? heartbeatRevision;
  final BigInt? inventoryRevision;
  final BigInt? generation;
  final BigInt? heartbeatSequence;
  final String? status;
  final bool? fresh;
  final bool? declaredEligible;

  const _Expected({
    required this.accepted,
    required this.error,
    required this.heartbeatRevision,
    required this.inventoryRevision,
    required this.generation,
    required this.heartbeatSequence,
    required this.status,
    required this.fresh,
    required this.declaredEligible,
  });

  factory _Expected.fromJson(Object? value) {
    final json = Map<String, dynamic>.from(value as Map);
    final accepted = _bool(json['accepted']);
    final expected = accepted
        ? {
            'accepted',
            'heartbeat_revision',
            'inventory_revision',
            'generation',
            'heartbeat_sequence',
            'status',
            'fresh',
            'declared_eligible',
          }
        : {'accepted', 'error'};
    if (json.keys.toSet().length != expected.length ||
        json.keys.any((key) => !expected.contains(key))) {
      throw const FormatException('Invalid joined lifecycle expected shape.');
    }
    return _Expected(
      accepted: accepted,
      error: accepted ? null : _text(json['error']),
      heartbeatRevision: accepted ? _uint(json['heartbeat_revision']) : null,
      inventoryRevision: accepted ? _uint(json['inventory_revision']) : null,
      generation: accepted ? _uint(json['generation']) : null,
      heartbeatSequence: accepted ? _uint(json['heartbeat_sequence']) : null,
      status: accepted ? _text(json['status']) : null,
      fresh: accepted ? _bool(json['fresh']) : null,
      declaredEligible: accepted ? _bool(json['declared_eligible']) : null,
    );
  }
}

Map<String, dynamic> _object(Object? value, Set<String> expected) {
  if (value is! Map) throw const FormatException('Expected Forge object.');
  final json = Map<String, dynamic>.from(value);
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge joined lifecycle fields.');
  }
  return json;
}

String _text(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge joined lifecycle text.');
  }
  return value;
}

bool _bool(Object? value) {
  if (value is! bool) throw const FormatException('Invalid Forge boolean.');
  return value;
}

BigInt _uint(Object? value) {
  final result = value is int
      ? BigInt.from(value)
      : value is BigInt
      ? value
      : null;
  if (result == null || result < BigInt.zero) {
    throw const FormatException('Invalid Forge uint64.');
  }
  return result;
}
