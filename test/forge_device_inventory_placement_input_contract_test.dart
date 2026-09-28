import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_input.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_PLACEMENT_INPUT_CONTRACT_FIXTURE'];

  test('validates placement-input values without an external fixture', () {
    final rejected = ForgeDeviceInventoryPlacementExpected.fromJson({
      'accepted': false,
      'error': 'owner_mismatch',
    });
    expect(rejected.accepted, isFalse);
    expect(rejected.error, 'owner_mismatch');
    expect(rejected.revision, isNull);

    final policy = ForgeDeviceInventoryPlacementPolicy.fromJson({
      'data_residency_zones': ['us-west'],
      'minimum_trust_zone': 'standard',
      'sandbox_floor': 'process',
      'concurrency_slots': 2,
    });
    expect(policy.dataResidencyZones, ['us-west']);
    expect(policy.concurrencySlots, 2);
  });

  test(
    'strictly consumes the persisted inventory placement-input fixture',
    () {
      final path = fixturePath;
      if (path == null) return;
      final fixture = _fixture(path);
      expect(fixture.schemaVersion, forgeDeviceInventoryPlacementInputSchema);
      expect(
        fixture.evaluationMode,
        forgeDeviceInventoryPlacementInputEvaluationMode,
      );
      expect(fixture.evaluationOwner.tenantID, 'tenant-1');
      expect(fixture.policyRequirements.dataResidencyZones, ['us-west']);
      expect(fixture.state.revision, BigInt.from(7));
      expect(fixture.state.runner.instanceID, 'runner-a');
      expect(fixture.state.runner.capabilities.runtimes, ['oci']);
      expect(fixture.authority.anyGranted, isFalse);
      expect(fixture.cases, hasLength(12));

      final online = fixture.cases.firstWhere((item) => item.name == 'online');
      expect(online.expected.accepted, isTrue);
      expect(online.expected.error, isEmpty);
      expect(online.expected.deviceID, 'device-a');
      expect(online.expected.trustZone, 'unknown');
      expect(online.expected.policyRequirementsMet, isFalse);

      final unsafe = fixture.cases.firstWhere(
        (item) => item.name == 'unsafe_snapshot_observed_at_ms',
      );
      expect(unsafe.serverObservedAtMS, BigInt.from(9007199254740992));
      expect(unsafe.expected.accepted, isFalse);
      expect(
        unsafe.expected.error,
        'invalid_persisted_inventory_placement_input',
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown fields and any enabled authority in the fixture',
    () {
      final path = fixturePath;
      if (path == null) return;
      final root = _root(path);
      root['unexpected'] = true;
      expect(
        () => ForgeDeviceInventoryPlacementInputFixture.fromJson(root),
        throwsFormatException,
      );

      final authorityRoot = _root(path);
      final authority = Map<String, dynamic>.from(
        authorityRoot['authority'] as Map,
      )..['execution_authorized'] = true;
      authorityRoot['authority'] = authority;
      expect(
        () => ForgeDeviceInventoryPlacementInputFixture.fromJson(authorityRoot),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown case and accepted-result fields',
    () {
      final path = fixturePath;
      if (path == null) return;
      final root = _root(path);
      final cases = List<Map<String, dynamic>>.from(
        (root['cases'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      cases[0]['unknown_case_field'] = true;
      root['cases'] = cases;
      expect(
        () => ForgeDeviceInventoryPlacementInputFixture.fromJson(root),
        throwsFormatException,
      );

      final expectedRoot = _root(path);
      final expectedCases = List<Map<String, dynamic>>.from(
        (expectedRoot['cases'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final expected = Map<String, dynamic>.from(
        expectedCases[0]['expected'] as Map,
      )..['unknown_expected_field'] = true;
      expectedCases[0]['expected'] = expected;
      expectedRoot['cases'] = expectedCases;
      expect(
        () => ForgeDeviceInventoryPlacementInputFixture.fromJson(expectedRoot),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects residency zone spellings outside the Go/Rust zone grammar',
    () {
      final path = fixturePath;
      if (path == null) return;
      final root = _root(path);
      final policy = Map<String, dynamic>.from(
        root['policy_requirements'] as Map,
      )..['data_residency_zones'] = ['us+west'];
      root['policy_requirements'] = policy;
      expect(
        () => ForgeDeviceInventoryPlacementInputFixture.fromJson(root),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

Map<String, dynamic> _root(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

ForgeDeviceInventoryPlacementInputFixture _fixture(String path) =>
    ForgeDeviceInventoryPlacementInputFixture.fromJson(_root(path));
