import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_persistence.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_PERSISTENCE_CONTRACT_FIXTURE'];

  test(
    'consumes the shared pure persisted inventory fixture',
    () {
      final fixture = ForgeDeviceInventoryPersistenceFixture.fromJsonText(
        File(fixturePath!).readAsStringSync(),
      );
      expect(fixture.authority.anyGranted, isFalse);
      expect(fixture.staleAfterMS, BigInt.from(90000));
      expect(fixture.state.revision, BigInt.from(3));
      expect(fixture.state.device.deviceID, 'device-a');
      expect(fixture.state.device.owner.tenantID, 'tenant');
      expect(fixture.state.runner.instanceID, 'runner-a');
      expect(fixture.state.runner.generation, BigInt.one);
      expect(fixture.state.runner.capabilities.runtimes, ['go', 'rust']);
      expect(fixture.cases, hasLength(12));

      for (final testCase in fixture.cases) {
        final actual = evaluateForgeDeviceInventoryPersistenceCase(
          fixture,
          testCase,
        );
        expect(
          actual.accepted,
          testCase.expected.accepted,
          reason: testCase.name,
        );
        if (!testCase.expected.accepted) {
          expect(actual.error, testCase.expected.error, reason: testCase.name);
          expect(actual.state, isNull, reason: testCase.name);
          expect(actual.projection, isNull, reason: testCase.name);
          continue;
        }
        if (testCase.operation == 'commit') {
          final state = actual.state;
          expect(state, isNotNull, reason: testCase.name);
          expect(
            state!.revision,
            testCase.expected.revision,
            reason: testCase.name,
          );
          expect(
            state.runner.heartbeatSequence,
            testCase.expected.heartbeatSequence,
            reason: testCase.name,
          );
          expect(
            state.runner.serverObservedAtMS,
            testCase.expected.serverObservedAtMS,
            reason: testCase.name,
          );
          expect(
            state.runner.capabilityLeaseExpiresAtMS,
            testCase.expected.capabilityLeaseExpiresAtMS,
            reason: testCase.name,
          );
        } else if (testCase.operation == 'project') {
          final projection = actual.projection;
          expect(projection, isNotNull, reason: testCase.name);
          expect(
            projection!.revision,
            testCase.expected.revision,
            reason: testCase.name,
          );
          expect(
            projection.deviceID,
            testCase.expected.deviceID,
            reason: testCase.name,
          );
          expect(
            projection.instanceID,
            testCase.expected.instanceID,
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
        } else {
          expect(actual.state, isNotNull, reason: testCase.name);
        }
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects authority, unknown fields, duplicate cases, and bad shapes',
    () {
      final fixture = _fixtureJSON();
      (fixture['authority']
              as Map<String, dynamic>)['inventory_authoritative'] =
          true;
      expect(
        () => ForgeDeviceInventoryPersistenceFixture.fromJson(fixture),
        throwsA(isA<FormatException>()),
      );

      final unknown = _fixtureJSON();
      unknown['unexpected'] = true;
      expect(
        () => ForgeDeviceInventoryPersistenceFixture.fromJson(unknown),
        throwsA(isA<FormatException>()),
      );

      final duplicate = _fixtureJSON();
      final cases = duplicate['cases'] as List<dynamic>;
      cases[1] = Map<String, dynamic>.from(cases[0] as Map<String, dynamic>);
      expect(
        () => ForgeDeviceInventoryPersistenceFixture.fromJson(duplicate),
        throwsA(isA<FormatException>()),
      );

      final unknownCase = _fixtureJSON();
      final first = Map<String, dynamic>.from(
        (unknownCase['cases'] as List<dynamic>)[0] as Map<String, dynamic>,
      );
      first['unexpected'] = true;
      (unknownCase['cases'] as List<dynamic>)[0] = first;
      expect(
        () => ForgeDeviceInventoryPersistenceFixture.fromJson(unknownCase),
        throwsA(isA<FormatException>()),
      );

      final unknownExpected = _fixtureJSON();
      final firstExpected = Map<String, dynamic>.from(
        ((unknownExpected['cases'] as List<dynamic>)[0]
                as Map<String, dynamic>)['expected']
            as Map<String, dynamic>,
      );
      firstExpected['unexpected'] = true;
      ((unknownExpected['cases'] as List<dynamic>)[0]
              as Map<String, dynamic>)['expected'] =
          firstExpected;
      expect(
        () => ForgeDeviceInventoryPersistenceFixture.fromJson(unknownExpected),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('preserves and evaluates full uint64 revisions as BigInt', () {
    final source =
        '{"schema_version":"$forgeDeviceInventoryPersistenceSchema",'
        '"evaluation_mode":"$forgeDeviceInventoryPersistenceEvaluationMode",'
        '"stale_after_ms":90000,'
        '"authority":{"identity_verified":false,"heartbeat_persisted":false,'
        '"inventory_authoritative":false,"reservation_created":false,'
        '"execution_authorized":false,"dispatch_performed":false},'
        '"state":${_stateJSON(revision: 3)},'
        '"cases":${_casesJSON()}}';
    final fixture = ForgeDeviceInventoryPersistenceFixture.fromJsonText(source);
    expect(
      fixture.cases.last.stateRevision,
      BigInt.parse('18446744073709551615'),
    );
  });

  test('rejects non-canonical persistence error tokens', () {
    final fixture = _fixtureJSON();
    final first = Map<String, dynamic>.from(
      (fixture['cases'] as List<dynamic>)[0] as Map<String, dynamic>,
    );
    first['expected'] = {'accepted': false, 'error': 'not_a_real_error'};
    (fixture['cases'] as List<dynamic>)[0] = first;
    expect(
      () => ForgeDeviceInventoryPersistenceFixture.fromJson(fixture),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _fixtureJSON() => {
  'schema_version': forgeDeviceInventoryPersistenceSchema,
  'evaluation_mode': forgeDeviceInventoryPersistenceEvaluationMode,
  'stale_after_ms': 90000,
  'authority': {
    'identity_verified': false,
    'heartbeat_persisted': false,
    'inventory_authoritative': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
  },
  'state': {
    'revision': 3,
    'device': {
      'device_id': 'device-a',
      'owner': {'issuer': 'issuer', 'subject': 'user', 'tenant_id': 'tenant'},
      'approval_state': 'approved',
      'cordon_state': 'clear',
      'reservation_state': 'none',
    },
    'runner': {
      'device_id': 'device-a',
      'instance_id': 'runner-a',
      'generation': 1,
      'heartbeat_sequence': 1,
      'server_observed_at_ms': 1000,
      'capability_lease_expires_at_ms': 5000,
      'liveness': 'online',
      'capabilities': {
        'os': 'linux',
        'architecture': 'amd64',
        'cpu_cores': 8,
        'available_cpu_cores': 7,
        'memory_bytes': 17179869184,
        'available_memory_bytes': 8589934592,
        'storage_bytes': 107374182400,
        'available_storage_bytes': 53687091200,
        'gpus': <Object?>[],
        'runtimes': ['go', 'rust'],
      },
    },
  },
  'cases': List<dynamic>.generate(
    forgeDeviceInventoryPersistenceMaxCases,
    (index) => {
      'name': 'case-$index',
      'operation': 'restore',
      'expected': {'accepted': false, 'error': 'invalid_persisted_state'},
    },
  ),
};

String _stateJSON({required int revision}) =>
    '{"revision":$revision,"device":{"device_id":"device-a",'
    '"owner":{"issuer":"issuer","subject":"user","tenant_id":"tenant"},'
    '"approval_state":"approved","cordon_state":"clear",'
    '"reservation_state":"none"},"runner":{"device_id":"device-a",'
    '"instance_id":"runner-a","generation":1,"heartbeat_sequence":1,'
    '"server_observed_at_ms":1000,"capability_lease_expires_at_ms":5000,'
    '"liveness":"online","capabilities":{"os":"linux",'
    '"architecture":"amd64","cpu_cores":8,"available_cpu_cores":7,'
    '"memory_bytes":17179869184,"available_memory_bytes":8589934592,'
    '"storage_bytes":107374182400,"available_storage_bytes":53687091200,'
    '"gpus":[],"runtimes":["go","rust"]}}}';

String _casesJSON() {
  final cases =
      List.generate(
        forgeDeviceInventoryPersistenceMaxCases - 1,
        (index) =>
            '{"name":"case-$index","operation":"restore",'
            '"expected":{"accepted":false,"error":"invalid_persisted_state"}}',
      )..add(
        '{"name":"max-revision","operation":"commit",'
        '"state_revision":18446744073709551615,"expected_revision":0,'
        '"expected":{"accepted":false,"error":"revision_conflict"}}',
      );
  return '[${cases.join(',')}]';
}
