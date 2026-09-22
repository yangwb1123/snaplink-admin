import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';

void main() {
  final fixturePath = Platform
      .environment['FORGE_INVENTORY_PLACEMENT_BATCH_EVALUATION_FIXTURE'];

  test(
    'strictly consumes the persisted inventory placement batch fixture',
    () {
      final path = fixturePath;
      if (path == null) return;
      final fixture = _fixture(path);
      expect(
        fixture.schemaVersion,
        forgeDeviceInventoryPlacementBatchEvaluationSchema,
      );
      expect(
        fixture.evaluationMode,
        forgeDeviceInventoryPlacementBatchEvaluationMode,
      );
      expect(
        fixture.sourceFixture,
        forgeDeviceInventoryPlacementBatchEvaluationSourceFixture,
      );
      expect(fixture.evaluationOwner.tenantID, 'tenant-1');
      expect(fixture.evaluatedAtMS, 200500);
      expect(fixture.requirements.runtime, 'oci');
      expect(fixture.cases, hasLength(6));
      expect(fixture.emptyInputsAllowed, isTrue);
      expect(fixture.selectedDeviceID, isNull);
      expect(fixture.selectedInstanceID, isNull);
      expect(fixture.authority.anyGranted, isFalse);
      expect(fixture.errorCases, hasLength(4));

      final online = fixture.cases.firstWhere((item) => item.name == 'online');
      expect(online.sourceCase, 'online');
      expect(online.expected.revision, 7);
      expect(online.expected.deviceID, 'device-a');
      expect(online.expected.instanceID, 'runner-a');
      expect(online.expected.matchesRequirements, isFalse);
      expect(online.expected.exclusionReasons, [
        'concurrency_capacity_insufficient',
        'data_residency_zone_mismatch',
        'sandbox_floor_unmet',
        'trust_zone_unconfirmed',
      ]);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown fields, enabled authority, duplicate identities, and bad reasons',
    () {
      final path = fixturePath;
      if (path == null) return;

      final unknownRoot = _root(path)..['unexpected'] = true;
      expect(
        () => ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
          unknownRoot,
        ),
        throwsFormatException,
      );

      final authorityRoot = _root(path);
      final authority = Map<String, dynamic>.from(
        authorityRoot['authority'] as Map,
      )..['placement_selected'] = true;
      authorityRoot['authority'] = authority;
      expect(
        () => ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
          authorityRoot,
        ),
        throwsFormatException,
      );

      final duplicateRoot = _root(path);
      final cases = List<Map<String, dynamic>>.from(
        (duplicateRoot['cases'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      cases[1]['device_id'] = cases[0]['device_id'];
      duplicateRoot['cases'] = cases;
      expect(
        () => ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
          duplicateRoot,
        ),
        throwsFormatException,
      );

      final reasonRoot = _root(path);
      final reasonCases = List<Map<String, dynamic>>.from(
        (reasonRoot['cases'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final expected = Map<String, dynamic>.from(
        reasonCases[0]['expected'] as Map,
      );
      final reasons = List<dynamic>.from(expected['exclusion_reasons'] as List);
      reasons[reasons.length - 1] = 'trust_zone_unconfirmed_invalid';
      expected['exclusion_reasons'] = reasons;
      reasonCases[0]['expected'] = expected;
      reasonRoot['cases'] = reasonCases;
      expect(
        () => ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
          reasonRoot,
        ),
        throwsFormatException,
      );

      final source = File(path).readAsStringSync();
      final duplicateSource = source.replaceFirst(
        '"schema_version": "forge.device-inventory-placement-batch-evaluation/v1",',
        '"schema_version": "forge.device-inventory-placement-batch-evaluation/v1", '
            '"schema_version": "forge.device-inventory-placement-batch-evaluation/v1",',
      );
      expect(
        () => ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJsonText(
          duplicateSource,
        ),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unsorted decisions',
    () {
      final path = fixturePath;
      if (path == null) return;
      final root = _root(path);
      final cases = List<Map<String, dynamic>>.from(
        (root['cases'] as List).map(
          (item) => Map<String, dynamic>.from(item as Map),
        ),
      );
      final first = cases.removeAt(0);
      cases.add(first);
      root['cases'] = cases;
      expect(
        () =>
            ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(root),
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

ForgeDeviceInventoryPlacementBatchEvaluationFixture _fixture(String path) =>
    ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(_root(path));
