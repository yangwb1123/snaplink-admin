import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_heartbeat_persistence.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_HEARTBEAT_PERSISTENCE_CONTRACT_FIXTURE'];

  test(
    'consumes the shared pure heartbeat persistence fixture',
    () {
      final fixture = ForgeDeviceHeartbeatPersistenceFixture.fromJsonText(
        File(fixturePath!).readAsStringSync(),
      );
      expect(fixture.authority.anyGranted, isFalse);
      expect(fixture.device.deviceID, 'device-a');
      expect(fixture.device.tenantID, 'tenant-1');
      expect(fixture.device.approvalState, 'approved');
      expect(fixture.capabilities.runtimes, ['oci']);
      expect(fixture.cases, hasLength(10));

      for (final testCase in fixture.cases) {
        final device = ForgeDeviceHeartbeatPersistenceDevice(
          deviceID: fixture.device.deviceID,
          tenantID: fixture.device.tenantID,
          approvalState:
              testCase.deviceApprovalState ?? fixture.device.approvalState,
        );
        final outcome = commitForgeDeviceHeartbeat(
          device: device,
          current: testCase.current,
          expectedRevision: testCase.expectedRevision,
          heartbeat: testCase.heartbeat,
          serverObservedAtMS: testCase.serverObservedAtMS,
          leaseTTLMS: testCase.leaseTTLMS,
        );
        _expectOutcome(
          testCase.name,
          testCase.expected,
          outcome,
          fixture.capabilities,
        );
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects granted authority and unknown fixture fields', () {
    final fixture = _fixtureJSON();
    (fixture['authority'] as Map<String, dynamic>)['dispatch_performed'] = true;
    expect(
      () => ForgeDeviceHeartbeatPersistenceFixture.fromJson(fixture),
      throwsA(isA<FormatException>()),
    );

    final unknown = _fixtureJSON();
    unknown['unexpected'] = true;
    expect(
      () => ForgeDeviceHeartbeatPersistenceFixture.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeDeviceHeartbeat.fromJson({
        'device_id': 'device-a',
        'instance_id': 'runner-a',
        'generation': 1,
        'sequence': 1,
        'unexpected': true,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeDeviceHeartbeatPersistenceState.fromJson({
        'revision': 1,
        'device_id': 'device-a',
        'instance_id': 'runner-a',
        'generation': 1,
        'heartbeat_sequence': 1,
        'server_observed_at_ms': 100000,
        'capability_lease_expires_at_ms': 160000,
        'unexpected': true,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('retains the canonical capability snapshot on a CAS result', () {
    final capabilities = ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
      'os': 'linux',
      'architecture': 'amd64',
      'cpu_cores': 8,
      'available_cpu_cores': 8,
      'memory_bytes': 16384,
      'available_memory_bytes': 8192,
      'storage_bytes': 8192,
      'available_storage_bytes': 4096,
      'gpus': [
        {
          'id': 'gpu-a',
          'vendor': 'AMD',
          'memory_bytes': 4096,
          'available_memory_bytes': 2048,
        },
      ],
      'runtimes': ['OCI'],
    });
    final outcome = commitForgeDeviceHeartbeat(
      device: const ForgeDeviceHeartbeatPersistenceDevice(
        deviceID: 'device-a',
        tenantID: 'tenant-1',
        approvalState: 'approved',
      ),
      current: null,
      expectedRevision: BigInt.zero,
      heartbeat: ForgeDeviceHeartbeat(
        deviceID: 'device-a',
        instanceID: 'runner-a',
        generation: BigInt.one,
        sequence: BigInt.one,
        capabilities: capabilities,
      ),
      serverObservedAtMS: BigInt.from(100000),
      leaseTTLMS: BigInt.from(60000),
    );
    expect(outcome.accepted, isTrue);
    expect(outcome.state!.capabilities!.runtimes, ['oci']);
    expect(outcome.state!.capabilities!.gpus.single.id, 'gpu-a');
  });
}

void _expectOutcome(
  String name,
  ForgeDeviceHeartbeatPersistenceExpected expected,
  ForgeDeviceHeartbeatPersistenceOutcome actual,
  ForgeDeviceHeartbeatReferenceCapabilities capabilities,
) {
  expect(actual.accepted, expected.accepted, reason: name);
  if (!expected.accepted) {
    expect(actual.error, expected.error, reason: name);
    expect(actual.state, isNull, reason: name);
    return;
  }
  final state = actual.state;
  expect(state, isNotNull, reason: name);
  expect(state!.capabilities, isNotNull, reason: name);
  expect(state.capabilities!.runtimes, capabilities.runtimes, reason: name);
  expect(state.revision, expected.revision, reason: name);
  expect(state.generation, expected.generation, reason: name);
  expect(state.heartbeatSequence, expected.heartbeatSequence, reason: name);
  expect(state.serverObservedAtMS, expected.serverObservedAtMS, reason: name);
  expect(
    state.capabilityLeaseExpiresAtMS,
    expected.capabilityLeaseExpiresAtMS,
    reason: name,
  );
}

Map<String, dynamic> _fixtureJSON() => {
  'schema_version': forgeDeviceHeartbeatPersistenceSchema,
  'evaluation_mode': forgeDeviceHeartbeatPersistenceEvaluationMode,
  'authority': {
    'identity_verified': false,
    'heartbeat_persisted': false,
    'inventory_authoritative': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
  },
  'device': {
    'device_id': 'device-a',
    'tenant_id': 'tenant-1',
    'approval_state': 'approved',
  },
  'cases': List.generate(
    10,
    (index) => {
      'name': 'case-$index',
      'expected_revision': 0,
      'current': null,
      'heartbeat': {
        'device_id': 'device-a',
        'instance_id': 'runner-a',
        'generation': 1,
        'sequence': 1,
      },
      'server_observed_at_ms': 100000,
      'lease_ttl_ms': 60000,
      'expected': {
        'accepted': true,
        'revision': 1,
        'generation': 1,
        'heartbeat_sequence': 1,
        'server_observed_at_ms': 100000,
        'capability_lease_expires_at_ms': 160000,
      },
    },
  ),
};
