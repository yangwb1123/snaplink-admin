import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_session_placement.dart';

void main() {
  final path = Platform.environment['FORGE_SESSION_PLACEMENT_CONTRACT_FIXTURE'];

  test(
    'matches the shared owner/session/run placement observation fixture',
    () => _assertFixture(path!),
    skip: path == null ? 'Run through scripts/test-forge-contracts.sh.' : false,
  );

  test('rejects a duplicate declared Runner instance', () {
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
    final device = ForgeDeviceDeclaration.fromJson({
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
    });
    final placement = ForgeDevicePlacementRequest(
      schemaVersion: forgeDevicePlacementRequestSchema,
      evaluatedAtMS: 10,
      owner: owner,
      maxSnapshotAgeMS: 20,
      requirements: requirements,
      devices: [device],
    );
    final request = ForgeSessionPlacementRequest(
      owner: owner,
      conversationID: 'conversation-1',
      runID: 'run-1',
      placement: placement,
      candidates: [
        ForgeSessionPlacementCandidate(instanceID: 'runner-1', device: device),
        ForgeSessionPlacementCandidate(instanceID: 'runner-1', device: device),
      ],
    );
    expect(
      () => observeForgeSessionPlacement(request),
      throwsA(
        isA<ForgeSessionPlacementError>().having(
          (error) => error.code,
          'code',
          'invalid_candidate',
        ),
      ),
    );
  });
}

void _assertFixture(String path) {
  final root = Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
  _exactKeys(root, {
    'api_version',
    'owner',
    'conversation_id',
    'run_id',
    'placement',
    'expected',
  });
  expect(
    root['api_version'],
    'forgeos.session-placement-observation-contract/v1',
  );
  final owner = ForgeDeviceOwner.fromJson(root['owner']);
  final placement = Map<String, dynamic>.from(root['placement'] as Map);
  _exactKeys(placement, {
    'schema_version',
    'evaluated_at_ms',
    'max_snapshot_age_ms',
    'owner',
    'requirements',
    'candidates',
    'expected',
  });
  expect(
    placement['schema_version'],
    'forge.device-placement-policy-parity-test/v1',
  );
  expect(ForgeDeviceOwner.fromJson(placement['owner']), owner);
  final rawCandidates = (placement['candidates'] as List).cast<Map>();
  final candidates = rawCandidates
      .map((row) {
        final value = Map<String, dynamic>.from(row);
        _exactKeys(value, {'instance_id', 'device'});
        final instanceID = value['instance_id'];
        if (instanceID is! String || instanceID.isEmpty) {
          throw const FormatException('Invalid session placement instance.');
        }
        return ForgeSessionPlacementCandidate(
          instanceID: instanceID,
          device: ForgeDeviceDeclaration.fromJson(value['device']),
        );
      })
      .toList(growable: false);
  final placementJSON = <String, dynamic>{
    'schema_version': forgeDevicePlacementRequestSchema,
    'evaluated_at_ms': placement['evaluated_at_ms'],
    'max_snapshot_age_ms': placement['max_snapshot_age_ms'],
    'owner': placement['owner'],
    'requirements': placement['requirements'],
    'devices': candidates
        .map((candidate) => _deviceJSON(candidate.device))
        .toList(),
  };
  final request = ForgeSessionPlacementRequest(
    owner: owner,
    conversationID: root['conversation_id'] as String,
    runID: root['run_id'] as String,
    placement: ForgeDevicePlacementRequest.fromJson(placementJSON),
    candidates: candidates,
  );
  final generated = observeForgeSessionPlacement(request);
  final observation = ForgeSessionPlacementObservation.fromJson(
    generated.toJson(),
  );
  final expected = Map<String, dynamic>.from(root['expected'] as Map);
  _exactKeys(expected, {
    'evaluation_mode',
    'evaluated_at_ms',
    'owner_declaration_unverified',
    'device_attributes_unverified',
    'decisions',
    'selected_device_id',
    'selected_instance_id',
    'authority',
  });
  expect(observation.schemaVersion, forgeSessionPlacementObservationSchema);
  expect(observation.evaluationMode, expected['evaluation_mode']);
  expect(observation.owner, owner);
  expect(observation.conversationID, request.conversationID);
  expect(observation.runID, request.runID);
  expect(observation.evaluatedAtMS, expected['evaluated_at_ms']);
  expect(observation.ownerDeclarationUnverified, isTrue);
  expect(observation.deviceAttributesUnverified, isTrue);
  expect(observation.selectedDeviceID, isNull);
  expect(observation.selectedInstanceID, isNull);
  expect(observation.authority.toJson(), expected['authority']);

  final expectedDecisions = (expected['decisions'] as List).cast<Map>();
  expect(observation.decisions, hasLength(expectedDecisions.length));
  for (var index = 0; index < expectedDecisions.length; index++) {
    final want = Map<String, dynamic>.from(expectedDecisions[index]);
    expect(observation.decisions[index].toJson(), want);
  }
}

Map<String, dynamic> _deviceJSON(ForgeDeviceDeclaration device) => {
  'device_id': device.deviceID,
  'owner': {
    'issuer': device.owner.issuer,
    'subject': device.owner.subject,
    'tenant_id': device.owner.tenantID,
  },
  'approval_state': device.approvalState,
  'cordon_state': device.cordonState,
  'liveness': device.liveness,
  'snapshot_observed_at_ms': device.snapshotObservedAtMS,
  'lease_expires_at_ms': device.leaseExpiresAtMS,
  'os': device.os,
  'architecture': device.architecture,
  'available_cpu_cores': device.availableCPUCores,
  'available_memory_bytes': device.availableMemoryBytes,
  'available_storage_bytes': device.availableStorageBytes,
  'runtimes': device.runtimes,
  'gpu': {
    'present': device.gpu.present,
    'memory_bytes': device.gpu.memoryBytes,
    'runtime': device.gpu.runtime,
  },
  'data_residency_zones': device.dataResidencyZones,
  'trust_zone': device.trustZone,
  'sandbox_levels': device.sandboxLevels,
  'concurrency_limit': device.concurrencyLimit,
  'active_concurrency': device.activeConcurrency,
};

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected session placement fields.');
  }
}
