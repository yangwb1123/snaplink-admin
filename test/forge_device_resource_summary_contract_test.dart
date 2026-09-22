import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_session_placement.dart';

void main() {
  final path =
      Platform.environment['FORGE_DEVICE_RESOURCE_SUMMARY_CONTRACT_FIXTURE'];

  test(
    'matches the shared multi-instance resource summary fixture',
    () => _assertFixture(path!),
    skip: path == null ? 'Run through scripts/test-forge-contracts.sh.' : false,
  );

  test('rejects a placement decision bound to a foreign instance', () {
    const owner = ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    );
    final device = ForgeDeviceDeclaration.fromJson(_deviceJSON(owner));
    final request = ForgeDeviceResourceSummaryRequest(
      owner: owner,
      inventory: [
        ForgeDeviceInventoryCandidate(instanceID: 'runner-1', device: device),
      ],
      placement: ForgeSessionPlacementObservation(
        schemaVersion: forgeSessionPlacementObservationSchema,
        evaluationMode: forgeDeviceResourceSummaryEvaluationMode,
        owner: owner,
        conversationID: 'conversation-1',
        runID: 'run-1',
        evaluatedAtMS: 10,
        ownerDeclarationUnverified: true,
        deviceAttributesUnverified: true,
        decisions: [
          const ForgeSessionPlacementDecision(
            deviceID: 'device-1',
            instanceID: 'foreign-runner',
            matchesRequirements: true,
            exclusionReasons: [],
          ),
        ],
        selectedDeviceID: null,
        selectedInstanceID: null,
        authority: const ForgeSessionPlacementAuthority.offline(),
      ),
    );
    expect(
      () => observeForgeDeviceResourceSummary(request),
      throwsA(
        isA<ForgeDeviceResourceSummaryError>().having(
          (error) => error.code,
          'code',
          'invalid_binding',
        ),
      ),
    );
  });

  test(
    'complete fixture decoder rejects duplicate keys and aggregate drift',
    () {
      final path = Platform
          .environment['FORGE_DEVICE_RESOURCE_SUMMARY_CONTRACT_FIXTURE'];
      if (path == null) return;
      final source = File(path).readAsStringSync();
      expect(
        () => ForgeDeviceResourceSummaryFixture.fromJsonText(
          source.replaceFirst(
            RegExp(r'\}\s*$'),
            '},"api_version":"forgeos.device-resource-summary-contract/v1"}',
          ),
        ),
        throwsFormatException,
      );
      final root = Map<String, dynamic>.from(jsonDecode(source) as Map);
      final expected = Map<String, dynamic>.from(root['expected'] as Map)
        ..['available_cpu_cores'] = 67;
      root['expected'] = expected;
      expect(
        () => ForgeDeviceResourceSummaryFixture.fromJsonText(jsonEncode(root)),
        throwsFormatException,
      );
    },
    skip:
        Platform.environment['FORGE_DEVICE_RESOURCE_SUMMARY_CONTRACT_FIXTURE'] ==
            null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

void _assertFixture(String path) {
  final root = Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
  _exactKeys(root, {
    'api_version',
    'inventory_contract_fixture',
    'placement_contract_fixture',
    'owner',
    'inventory',
    'placement_observation',
    'expected',
  });
  expect(root['api_version'], 'forgeos.device-resource-summary-contract/v1');
  expect(
    root['inventory_contract_fixture'],
    'forge-device-inventory-observation-v1',
  );
  expect(
    root['placement_contract_fixture'],
    'forge-session-placement-observation-v1',
  );
  final owner = ForgeDeviceOwner.fromJson(root['owner']);
  final inventory = ForgeDeviceInventoryPage.fromJson(root['inventory']);
  expect(inventory.owner, owner);
  final placement = ForgeSessionPlacementObservation.fromJson(
    root['placement_observation'],
  );
  expect(placement.owner, owner);
  final generated = observeForgeDeviceResourceSummary(
    ForgeDeviceResourceSummaryRequest(
      owner: owner,
      inventory: inventory.devices,
      placement: placement,
    ),
  );
  final observation = ForgeDeviceResourceSummary.fromJson(generated.toJson());
  final expected = Map<String, dynamic>.from(root['expected'] as Map);
  _exactKeys(expected, {
    'schema_version',
    'evaluation_mode',
    'conversation_id',
    'run_id',
    'evaluated_at_ms',
    'owner_declaration_unverified',
    'inventory_declarations_unverified',
    'placement_declaration_unverified',
    'notice',
    'device_count',
    'runner_instance_count',
    'available_cpu_cores',
    'available_memory_bytes',
    'available_storage_bytes',
    'available_gpu_count',
    'available_gpu_memory_bytes',
    'eligible_device_count',
    'eligible_instance_count',
    'selected_device_id',
    'selected_instance_id',
    'authority',
  });
  final actual = observation.toJson();
  for (final key in expected.keys) {
    expect(actual[key], expected[key], reason: 'resource summary field $key');
  }
}

Map<String, dynamic> _deviceJSON(ForgeDeviceOwner owner) => {
  'device_id': 'device-1',
  'owner': {
    'issuer': owner.issuer,
    'subject': owner.subject,
    'tenant_id': owner.tenantID,
  },
  'approval_state': 'approved',
  'cordon_state': 'clear',
  'liveness': 'online',
  'snapshot_observed_at_ms': 1,
  'lease_expires_at_ms': 100,
  'os': 'linux',
  'architecture': 'x86_64',
  'available_cpu_cores': 2,
  'available_memory_bytes': 2,
  'available_storage_bytes': 2,
  'runtimes': ['oci'],
  'gpu': {'present': false, 'memory_bytes': 0, 'runtime': ''},
  'data_residency_zones': ['us-west'],
  'trust_zone': 'standard',
  'sandbox_levels': ['container'],
  'concurrency_limit': 2,
  'active_concurrency': 0,
};

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge resource summary fields.');
  }
}
