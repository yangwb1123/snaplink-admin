import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_evaluation.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_PLACEMENT_EVALUATION_FIXTURE'];

  test(
    'strictly consumes the persisted inventory placement evaluation fixture',
    () {
      final path = fixturePath;
      if (path == null) return;
      final fixture = _fixture(path);
      expect(
        fixture.schemaVersion,
        forgeDeviceInventoryPlacementEvaluationSchema,
      );
      expect(
        fixture.evaluationMode,
        forgeDeviceInventoryPlacementEvaluationMode,
      );
      expect(
        fixture.sourceFixture,
        forgeDeviceInventoryPlacementEvaluationSourceFixture,
      );
      expect(fixture.sourceCase, 'online');
      expect(fixture.evaluatedAtMS, 200500);
      expect(fixture.policyRequirements.os, 'linux');
      expect(fixture.policyRequirements.gpu.required, isFalse);
      expect(fixture.authority.anyGranted, isFalse);

      final expected = fixture.expected;
      expect(expected.accepted, isTrue);
      expect(expected.error, isEmpty);
      expect(expected.revision, 7);
      expect(expected.deviceID, 'device-a');
      expect(expected.instanceID, 'runner-a');
      expect(expected.matchesRequirements, isFalse);
      expect(expected.exclusionReasons, [
        'concurrency_capacity_insufficient',
        'data_residency_zone_mismatch',
        'sandbox_floor_unmet',
        'trust_zone_unconfirmed',
      ]);
      expect(expected.ownerDeclarationUnverified, isTrue);
      expect(expected.deviceAttributesUnverified, isTrue);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown fields, enabled authority, and invalid reasons',
    () {
      final path = fixturePath;
      if (path == null) return;

      final unknownRoot = _root(path)..['unexpected'] = true;
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationFixture.fromJson(
          unknownRoot,
        ),
        throwsFormatException,
      );

      final authorityRoot = _root(path);
      authorityRoot['authority'] = {
        'placement_evaluated': true,
        'placement_selected': false,
        'reservation_created': false,
        'execution_authorized': false,
        'dispatch_performed': false,
      };
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationFixture.fromJson(
          authorityRoot,
        ),
        throwsFormatException,
      );

      final reasonRoot = _root(path);
      final expected = Map<String, dynamic>.from(reasonRoot['expected'] as Map);
      final reasons = List<dynamic>.from(expected['exclusion_reasons'] as List);
      reasons[reasons.length - 1] = 'trust_zone_unconfirmed_invalid';
      expected['exclusion_reasons'] = reasons;
      reasonRoot['expected'] = expected;
      expect(
        () =>
            ForgeDeviceInventoryPlacementEvaluationFixture.fromJson(reasonRoot),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects duplicate members and trailing JSON values',
    () {
      final path = fixturePath;
      if (path == null) return;
      final source = File(path).readAsStringSync();
      final duplicate = source.replaceFirst(
        '"source_case": "online",',
        '"source_case": "online", "source_case": "online",',
      );
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(
          duplicate,
        ),
        throwsFormatException,
      );
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(
          '$source\n{}',
        ),
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

ForgeDeviceInventoryPlacementEvaluationFixture _fixture(String path) =>
    ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(
      File(path).readAsStringSync(),
    );
