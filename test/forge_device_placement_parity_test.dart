import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';

void main() {
  final policyPath = Platform.environment['FORGE_PLACEMENT_PARITY_FIXTURE'];
  final gpuPath = Platform.environment['FORGE_PLACEMENT_GPU_PARITY_FIXTURE'];

  test(
    'matches the shared offline placement policy fixture',
    () => _assertFixture(policyPath!),
    skip: policyPath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'matches the shared offline GPU placement fixture',
    () => _assertFixture(gpuPath!),
    skip: gpuPath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects malformed requests before producing a dry-run result', () {
    const owner = ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    );
    const requirements = ForgeDevicePlacementRequirements(
      os: 'linux',
      architecture: 'x86_64',
      minCPUCores: 1,
      minMemoryBytes: 1,
      minStorageBytes: 1,
      runtime: 'oci',
      gpu: ForgeDevicePlacementGpuRequirement(
        required: false,
        minMemoryBytes: 0,
        runtime: '',
      ),
      dataResidencyZones: ['us-west'],
      minimumTrustZone: 'standard',
      sandboxFloor: 'container',
      concurrencySlots: 1,
    );
    final request = ForgeDevicePlacementRequest(
      schemaVersion: 'wrong',
      evaluatedAtMS: 200000,
      owner: owner,
      maxSnapshotAgeMS: 90000,
      requirements: requirements,
      devices: const [],
    );
    expect(
      () => dryRunForgeDevicePlacement(request),
      throwsA(
        isA<ForgeDevicePlacementError>().having(
          (error) => error.code,
          'code',
          'invalid_request',
        ),
      ),
    );
  });

  test('rejects placement CPU requirements above uint32', () {
    expect(
      () => ForgeDevicePlacementRequirements.fromJson({
        'os': 'linux',
        'architecture': 'x86_64',
        'min_cpu_cores': 0x100000000,
        'min_memory_bytes': 1,
        'min_storage_bytes': 1,
        'runtime': 'oci',
        'gpu': {'required': false, 'min_memory_bytes': 0, 'runtime': ''},
        'data_residency_zones': ['us-west'],
        'minimum_trust_zone': 'standard',
        'sandbox_floor': 'container',
        'concurrency_slots': 1,
      }),
      throwsFormatException,
    );
  });

  test('accepts the uint32 CPU requirement boundary', () {
    final requirements = ForgeDevicePlacementRequirements.fromJson({
      'os': 'linux',
      'architecture': 'x86_64',
      'min_cpu_cores': 0xffffffff,
      'min_memory_bytes': 1,
      'min_storage_bytes': 1,
      'runtime': 'oci',
      'gpu': {'required': false, 'min_memory_bytes': 0, 'runtime': ''},
      'data_residency_zones': ['us-west'],
      'minimum_trust_zone': 'standard',
      'sandbox_floor': 'container',
      'concurrency_slots': 1,
    });
    expect(requirements.minCPUCores, 0xffffffff);
  });

  test('rejects concurrency slots above uint16 and accepts its boundary', () {
    final base = <String, dynamic>{
      'os': 'linux',
      'architecture': 'x86_64',
      'min_cpu_cores': 1,
      'min_memory_bytes': 1,
      'min_storage_bytes': 1,
      'runtime': 'oci',
      'gpu': {'required': false, 'min_memory_bytes': 0, 'runtime': ''},
      'data_residency_zones': ['us-west'],
      'minimum_trust_zone': 'standard',
      'sandbox_floor': 'container',
    };
    expect(
      () => ForgeDevicePlacementRequirements.fromJson({
        ...base,
        'concurrency_slots': 0x10000,
      }),
      throwsFormatException,
    );
    final requirements = ForgeDevicePlacementRequirements.fromJson({
      ...base,
      'concurrency_slots': 0xffff,
    });
    expect(requirements.concurrencySlots, 0xffff);
  });
}

void _assertFixture(String path) {
  final fixture = jsonDecode(File(path).readAsStringSync()) as Map;
  expect(
    fixture['schema_version'],
    'forge.device-placement-policy-parity-test/v1',
  );
  final owner = ForgeDeviceOwner.fromJson(fixture['owner']);
  final requirements = ForgeDevicePlacementRequirements.fromJson(
    fixture['requirements'],
  );
  final candidates = (fixture['candidates'] as List)
      .cast<Map>()
      .map((row) {
        final candidate = Map<String, dynamic>.from(row);
        return ForgeDeviceDeclaration.fromJson(candidate['device']);
      })
      .toList(growable: false);
  final request = ForgeDevicePlacementRequest(
    schemaVersion: forgeDevicePlacementRequestSchema,
    evaluatedAtMS: fixture['evaluated_at_ms'] as int,
    owner: owner,
    maxSnapshotAgeMS: fixture['max_snapshot_age_ms'] as int,
    requirements: requirements,
    devices: candidates,
  );
  final before = List<ForgeDeviceDeclaration>.of(request.devices);
  final result = dryRunForgeDevicePlacement(request);
  expect(request.devices, orderedEquals(before));
  expect(result.schemaVersion, forgeDevicePlacementResultSchema);
  expect(result.evaluationMode, forgeDevicePlacementEvaluationMode);
  expect(result.ownerDeclarationUnverified, isTrue);
  expect(result.deviceAttributesUnverified, isTrue);
  expect(result.executionAuthorized, isFalse);
  expect(result.reservationCreated, isFalse);
  expect(result.dispatchPerformed, isFalse);

  final expected = fixture['expected'] as List;
  expect(result.deviceResults, hasLength(expected.length));
  for (var index = 0; index < expected.length; index++) {
    final want = Map<String, dynamic>.from(expected[index] as Map);
    final got = result.deviceResults[index];
    expect(got.deviceID, want['device_id']);
    expect(got.attributesUnverified, isTrue);
    expect(got.matchesRequirements, want['matches_requirements']);
    expect(got.exclusionReasons, want['exclusion_reasons']);
  }
}
