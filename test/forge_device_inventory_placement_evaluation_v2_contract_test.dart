import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_evaluation_v2.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_PLACEMENT_V2_FIXTURE'];

  test(
    'consumes the lossless v2 placement comparison fixture',
    () {
      final path = fixturePath;
      if (path == null) return;
      final fixture = _fixture(path);
      expect(
        fixture.schemaVersion,
        forgeDeviceInventoryPlacementEvaluationV2Schema,
      );
      expect(
        fixture.evaluationMode,
        forgeDeviceInventoryPlacementEvaluationV2Mode,
      );
      expect(
        fixture.sourceSchemaVersion,
        forgeDeviceInventoryPlacementEvaluationV2SourceSchema,
      );
      expect(fixture.evaluationOwner.tenantID, 'tenant');
      expect(fixture.observation.devices, hasLength(2));
      expect(
        fixture.observation.devices.first.device.reservationState,
        'reserved',
      );
      expect(fixture.observation.devices.first.device.gpus, hasLength(2));
      expect(fixture.decisions, hasLength(2));
      expect(fixture.decisions.first.availableGPUMemoryBytes, 17179869184);
      expect(fixture.decisions.first.matchesRequirements, isFalse);
      expect(
        fixture.decisions.first.exclusionReasons,
        contains('device_reserved'),
      );
      expect(fixture.eligibleCandidateCount, 0);
      expect(fixture.selectedDeviceID, isNull);
      expect(fixture.selectedInstanceID, isNull);
      expect(fixture.authority.anyGranted, isFalse);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects authority, binding, and GPU-total drift',
    () {
      final path = fixturePath;
      if (path == null) return;

      final unknownRoot = _root(path)..['unexpected'] = true;
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationV2.fromJson(unknownRoot),
        throwsFormatException,
      );

      final authorityRoot = _root(path);
      authorityRoot['authority'] = {
        'identity_verified': true,
        'heartbeat_persisted': false,
        'inventory_authoritative': false,
        'placement_selected': false,
        'reservation_created': false,
        'execution_authorized': false,
        'dispatch_performed': false,
      };
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationV2.fromJson(authorityRoot),
        throwsFormatException,
      );

      final totalRoot = _root(path);
      final decisions = List<dynamic>.from(totalRoot['expected'] as List);
      final first = Map<String, dynamic>.from(decisions.first as Map);
      first['available_gpu_memory_bytes'] = 1;
      decisions[0] = first;
      totalRoot['expected'] = decisions;
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationV2.fromJson(totalRoot),
        throwsFormatException,
      );

      final reasonRoot = _root(path);
      final reasonDecisions = List<dynamic>.from(
        reasonRoot['expected'] as List,
      );
      final reasonFirst = Map<String, dynamic>.from(
        reasonDecisions.first as Map,
      );
      final reasons = List<dynamic>.from(
        reasonFirst['exclusion_reasons'] as List,
      );
      reasons.remove('device_reserved');
      reasonFirst['exclusion_reasons'] = reasons;
      reasonDecisions[0] = reasonFirst;
      reasonRoot['expected'] = reasonDecisions;
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationV2.fromJson(reasonRoot),
        throwsFormatException,
      );

      final runtimeRoot = _root(path);
      final requirements = Map<String, dynamic>.from(
        runtimeRoot['requirements'] as Map,
      );
      final gpu = Map<String, dynamic>.from(requirements['gpu'] as Map);
      gpu['runtime'] = 'cuda';
      requirements['gpu'] = gpu;
      runtimeRoot['requirements'] = requirements;
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationV2.fromJson(runtimeRoot),
        throwsFormatException,
      );

      final source = File(path).readAsStringSync();
      final duplicateSource = source.replaceFirst(
        '"schema_version": "forge.device-inventory-placement-evaluation/v2",',
        '"schema_version": "forge.device-inventory-placement-evaluation/v2", '
            '"schema_version": "forge.device-inventory-placement-evaluation/v2",',
      );
      expect(
        () => ForgeDeviceInventoryPlacementEvaluationV2.fromJsonText(
          duplicateSource,
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

ForgeDeviceInventoryPlacementEvaluationV2 _fixture(String path) =>
    ForgeDeviceInventoryPlacementEvaluationV2.fromJsonText(
      File(path).readAsStringSync(),
    );
