import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_heartbeat.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_HEARTBEAT_CONTRACT_FIXTURE'];

  test(
    'consumes the shared pure heartbeat sequencing fixture',
    () {
      final fixture = ForgeDeviceHeartbeatReferenceFixture.fromJsonText(
        File(fixturePath!).readAsStringSync(),
      );
      expect(fixture.tenantID, 'tenant-1');
      expect(fixture.device.deviceID, 'device-a');
      expect(fixture.device.tenantID, fixture.tenantID);
      expect(fixture.device.approvalState, 'approved');
      expect(fixture.capabilities.os, 'linux');
      expect(fixture.capabilities.architecture, 'amd64');
      expect(fixture.capabilities.cpuCores, BigInt.from(8));
      expect(fixture.capabilities.runtimes, ['oci']);
      expect(fixture.authority.anyGranted, isFalse);
      expect(fixture.cases, hasLength(12));

      for (final testCase in fixture.cases) {
        final device = ForgeDeviceHeartbeatReferenceDevice(
          deviceID: fixture.device.deviceID,
          tenantID: fixture.device.tenantID,
          approvalState:
              testCase.deviceApprovalState ?? fixture.device.approvalState,
        );
        final outcome = applyForgeDeviceHeartbeat(
          device: device,
          current: testCase.current,
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

  test('rejects unknown fields and granted authority', () {
    expect(
      () => ForgeDeviceHeartbeatReferenceDevice.fromJson({
        'device_id': 'device-a',
        'tenant_id': 'tenant-1',
        'approval_state': 'approved',
        'unexpected': true,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeDeviceHeartbeatAuthority.fromJson({
        'identity_verified': true,
        'heartbeat_persisted': false,
        'inventory_authoritative': false,
        'execution_authorized': false,
        'reservation_created': false,
        'dispatch_performed': false,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeDeviceHeartbeatSignal.fromJson({
        'device_id': 'device-a',
        'instance_id': 'runner-a',
        'generation': 1,
        'sequence': 1,
        'unexpected': true,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeDeviceHeartbeatInstance.fromJson({
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
    expect(
      () => ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
        'os': 'linux',
        'architecture': 'amd64',
        'cpu_cores': 1,
        'available_cpu_cores': 1,
        'memory_bytes': 1,
        'available_memory_bytes': 1,
        'storage_bytes': 0,
        'available_storage_bytes': 0,
        'runtimes': ['oci'],
        'unexpected': true,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('preserves a full uint64 generation from fixture text', () {
    final signal = ForgeDeviceHeartbeatSignal.fromJson(
      decodeForgeDeviceHeartbeatJSON(
        '{"device_id":"device-a","instance_id":"runner-a",'
        '"generation":18446744073709551615,"sequence":1}',
      ),
    );
    expect(signal.generation, BigInt.parse('18446744073709551615'));
  });

  test('rejects a heartbeat without a capability snapshot', () {
    final outcome = applyForgeDeviceHeartbeat(
      device: const ForgeDeviceHeartbeatReferenceDevice(
        deviceID: 'device-a',
        tenantID: 'tenant-1',
        approvalState: 'approved',
      ),
      current: null,
      heartbeat: ForgeDeviceHeartbeatSignal(
        deviceID: 'device-a',
        instanceID: 'runner-a',
        generation: BigInt.one,
        sequence: BigInt.one,
      ),
      serverObservedAtMS: BigInt.from(100000),
      leaseTTLMS: BigInt.from(60000),
    );
    expect(outcome.accepted, isFalse);
    expect(outcome.error, 'invalid_capability_value');
  });

  test('canonicalizes bounded capability declarations and GPU rows', () {
    final capabilities = ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
      'os': 'Linux',
      'architecture': 'X86_64',
      'cpu_cores': 8,
      'available_cpu_cores': 4,
      'memory_bytes': 16384,
      'available_memory_bytes': 8192,
      'storage_bytes': 32768,
      'available_storage_bytes': 16384,
      'gpus': [
        {
          'id': 'gpu-b',
          'vendor': ' NVIDIA Corporation ',
          'memory_bytes': 8192,
          'available_memory_bytes': 4096,
        },
        {
          'id': 'gpu-a',
          'vendor': 'AMD',
          'memory_bytes': 4096,
          'available_memory_bytes': 0,
        },
      ],
      'runtimes': ['Python', 'docker'],
    });
    expect(capabilities.os, 'linux');
    expect(capabilities.architecture, 'x86_64');
    expect(capabilities.runtimes, ['docker', 'python']);
    expect(capabilities.gpus.map((gpu) => gpu.id), ['gpu-a', 'gpu-b']);
    expect(capabilities.gpus.last.vendor, 'NVIDIA Corporation');
  });

  test(
    'retains the canonical capability snapshot on the transition result',
    () {
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
      final outcome = applyForgeDeviceHeartbeat(
        device: const ForgeDeviceHeartbeatReferenceDevice(
          deviceID: 'device-a',
          tenantID: 'tenant-1',
          approvalState: 'approved',
        ),
        current: null,
        heartbeat: ForgeDeviceHeartbeatSignal(
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
      expect(outcome.instance!.capabilities!.runtimes, ['oci']);
      expect(outcome.instance!.capabilities!.gpus.single.id, 'gpu-a');
    },
  );

  test('rejects invalid capability capacities and duplicate declarations', () {
    final gpu = <String, Object?>{
      'id': 'gpu-a',
      'vendor': 'AMD',
      'memory_bytes': 4096,
      'available_memory_bytes': 2048,
    };
    final base = <String, Object?>{
      'os': 'linux',
      'architecture': 'amd64',
      'cpu_cores': 8,
      'available_cpu_cores': 8,
      'memory_bytes': 16384,
      'available_memory_bytes': 16384,
      'storage_bytes': 8192,
      'available_storage_bytes': 8192,
      'gpus': [gpu],
      'runtimes': ['oci'],
    };
    expect(
      () => ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
        ...base,
        'memory_bytes': 0,
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
        ...base,
        'runtimes': ['OCI', 'oci'],
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
        ...base,
        'gpus': [gpu, gpu],
      }),
      throwsA(isA<FormatException>()),
    );
  });
}

void _expectOutcome(
  String name,
  ForgeDeviceHeartbeatReferenceExpected expected,
  ForgeDeviceHeartbeatOutcome actual,
  ForgeDeviceHeartbeatReferenceCapabilities capabilities,
) {
  expect(actual.accepted, expected.accepted, reason: name);
  if (!expected.accepted) {
    expect(actual.error, expected.error, reason: name);
    expect(actual.instance, isNull, reason: name);
    return;
  }
  final instance = actual.instance;
  expect(instance, isNotNull, reason: name);
  expect(instance!.generation, expected.generation, reason: name);
  expect(instance.capabilities, isNotNull, reason: name);
  expect(instance.capabilities!.runtimes, capabilities.runtimes, reason: name);
  expect(
    instance.capabilities!.gpus.length,
    capabilities.gpus.length,
    reason: name,
  );
  expect(instance.heartbeatSequence, expected.heartbeatSequence, reason: name);
  expect(
    instance.serverObservedAtMS,
    expected.serverObservedAtMS,
    reason: name,
  );
  expect(
    instance.capabilityLeaseExpiresAtMS,
    expected.capabilityLeaseExpiresAtMS,
    reason: name,
  );
}
