import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/screens/forge/forge_sessions_device_observation.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_DEVICE_OBSERVATION_FIXTURE'];

  test(
    'consumes the shared canonical session device observation fixture',
    () {
      final root = jsonDecode(File(fixturePath!).readAsStringSync());
      final observation = ForgeSessionDeviceObservationWire.fromJson(root);
      expect(observation.conversationID, 'conversation-001');
      expect(observation.runID, 'run-001');
      expect(observation.inventory.devices, hasLength(9));
      expect(observation.toJson(), root);
    },
    skip: fixturePath == null
        ? 'Run through the cross-repository contract test script.'
        : false,
  );

  test('round-trips one owner/run offline observation envelope', () {
    final wire = _wire();
    final parsed = ForgeSessionDeviceObservationWire.fromJson(wire.toJson());
    expect(parsed.toJson(), wire.toJson());

    final display = ForgeSessionDeviceObservation.fromWire(parsed);
    expect(display.isFor('conversation-1', 'run-1'), isTrue);
    expect(display.resourceSummary.deviceCount, 1);
    expect(display.placement.deviceResults.single.matchesRequirements, isTrue);
  });

  test('rejects unknown envelope fields and authority claims', () {
    final json = _wire().toJson();
    final unknown = Map<String, dynamic>.from(json)..['extra'] = true;
    expect(
      () => ForgeSessionDeviceObservationWire.fromJson(unknown),
      throwsFormatException,
    );

    final authority = Map<String, dynamic>.from(json);
    authority['authority'] = {
      ...Map<String, dynamic>.from(authority['authority'] as Map),
      'execution_authorized': true,
    };
    expect(
      () => ForgeSessionDeviceObservationWire.fromJson(authority),
      throwsFormatException,
    );
  });

  test('rejects a resource summary altered from the declarations', () {
    final json = _wire().toJson();
    final alteredSummary = Map<String, dynamic>.from(
      json['resource_summary'] as Map,
    )..['available_cpu_cores'] = 5;
    json['resource_summary'] = alteredSummary;
    expect(
      () => ForgeSessionDeviceObservationWire.fromJson(json),
      throwsFormatException,
    );
  });
}

ForgeSessionDeviceObservationWire _wire() {
  const owner = ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-1',
    tenantID: 'tenant-1',
  );
  const device = ForgeDeviceDeclaration(
    deviceID: 'device-1',
    owner: owner,
    approvalState: 'approved',
    cordonState: 'clear',
    liveness: 'online',
    snapshotObservedAtMS: 10,
    leaseExpiresAtMS: 100,
    os: 'linux',
    architecture: 'x86_64',
    availableCPUCores: 4,
    availableMemoryBytes: 4096,
    availableStorageBytes: 8192,
    runtimes: ['oci'],
    gpu: ForgeDeviceGpu(present: false, memoryBytes: 0, runtime: ''),
    dataResidencyZones: ['us-west'],
    trustZone: 'standard',
    sandboxLevels: ['container'],
    concurrencyLimit: 2,
    activeConcurrency: 0,
  );
  final page = ForgeDeviceInventoryPage(
    evaluationMode: forgeDeviceInventoryEvaluationMode,
    evaluatedAtMS: 20,
    owner: owner,
    ownerDeclarationUnverified: true,
    inventoryDeclarationsUnverified: true,
    notice: forgeDeviceInventoryNotice,
    devices: const [
      ForgeDeviceInventoryCandidate(instanceID: 'runner-1', device: device),
    ],
    executionAuthorized: false,
    reservationCreated: false,
    dispatchPerformed: false,
  );
  final placement = ForgeSessionPlacementObservation(
    schemaVersion: forgeSessionPlacementObservationSchema,
    evaluationMode: forgeDeviceResourceSummaryEvaluationMode,
    owner: owner,
    conversationID: 'conversation-1',
    runID: 'run-1',
    evaluatedAtMS: 20,
    ownerDeclarationUnverified: true,
    deviceAttributesUnverified: true,
    decisions: const [
      ForgeSessionPlacementDecision(
        deviceID: 'device-1',
        instanceID: 'runner-1',
        matchesRequirements: true,
        exclusionReasons: [],
      ),
    ],
    selectedDeviceID: null,
    selectedInstanceID: null,
    authority: const ForgeSessionPlacementAuthority.offline(),
  );
  final summary = observeForgeDeviceResourceSummary(
    ForgeDeviceResourceSummaryRequest(
      owner: owner,
      inventory: page.devices,
      placement: placement,
    ),
  );
  return ForgeSessionDeviceObservationWire(
    schemaVersion: forgeSessionDeviceObservationSchema,
    evaluationMode: forgeSessionDeviceObservationEvaluationMode,
    owner: owner,
    conversationID: 'conversation-1',
    runID: 'run-1',
    evaluatedAtMS: 20,
    ownerDeclarationUnverified: true,
    inventory: page,
    placementObservation: placement,
    resourceSummary: summary,
    selectedDeviceID: null,
    selectedInstanceID: null,
    authority: const ForgeSessionPlacementAuthority.offline(),
  );
}
