import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/api/forge_session_placement.dart';

void main() {
  test('posts and strictly binds a session device observation preview', () async {
    final request = _sessionRequest();
    late http.Request sent;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((value) async {
        sent = value;
        final decoded = jsonDecode(value.body) as Map<String, dynamic>;
        final received = _sessionRequestFromJson(decoded);
        return _jsonResponse(_wireFor(received));
      }),
    );
    addTearDown(api.close);

    final wire = await api.previewSessionDeviceObservation(request: request);

    expect(sent.method, 'POST');
    expect(
      sent.url.path,
      '/api/v1/conversations/conversation-1/runs/run-1/device-observation/preview',
    );
    expect(sent.headers['authorization'], 'Bearer forge-bearer');
    expect(sent.headers.containsKey('idempotency-key'), isFalse);
    expect(wire.owner, request.owner);
    expect(wire.conversationID, request.conversationID);
    expect(wire.runID, request.runID);
    expect(wire.inventory.devices.single.instanceID, 'runner-1');
    expect(wire.authority.executionAuthorized, isFalse);
  });

  test(
    'rejects a session observation that drifts from caller candidates',
    () async {
      final request = _sessionRequest();
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async {
          final serverRequest = ForgeSessionPlacementRequest(
            owner: request.owner,
            conversationID: request.conversationID,
            runID: request.runID,
            placement: request.placement,
            candidates: [
              ForgeSessionPlacementCandidate(
                instanceID: 'runner-foreign',
                device: request.candidates.single.device,
              ),
            ],
          );
          final placement = observeForgeSessionPlacement(serverRequest);
          expect(placement.decisions.single.instanceID, 'runner-foreign');
          return _jsonResponse(_wireFor(serverRequest));
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.previewSessionDeviceObservation(request: request),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('rejects a self-consistent placement decision drift', () async {
    final request = _sessionRequest();
    final requirements = request.placement.requirements;
    final alteredPlacement = ForgeDevicePlacementRequest(
      schemaVersion: request.placement.schemaVersion,
      evaluatedAtMS: request.placement.evaluatedAtMS,
      owner: request.placement.owner,
      maxSnapshotAgeMS: request.placement.maxSnapshotAgeMS,
      requirements: ForgeDevicePlacementRequirements(
        os: requirements.os,
        architecture: requirements.architecture,
        minCPUCores: 99,
        minMemoryBytes: requirements.minMemoryBytes,
        minStorageBytes: requirements.minStorageBytes,
        runtime: requirements.runtime,
        gpu: requirements.gpu,
        dataResidencyZones: requirements.dataResidencyZones,
        minimumTrustZone: requirements.minimumTrustZone,
        sandboxFloor: requirements.sandboxFloor,
        concurrencySlots: requirements.concurrencySlots,
      ),
      devices: request.placement.devices,
    );
    final serverRequest = ForgeSessionPlacementRequest(
      owner: request.owner,
      conversationID: request.conversationID,
      runID: request.runID,
      placement: alteredPlacement,
      candidates: request.candidates,
    );
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient(
        (_) async => _jsonResponse(_wireFor(serverRequest)),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewSessionDeviceObservation(request: request),
      throwsA(isA<FormatException>()),
    );
  });
}

ForgeSessionPlacementRequest _sessionRequest() {
  final placement = _placementRequest();
  return ForgeSessionPlacementRequest(
    owner: placement.owner,
    conversationID: 'conversation-1',
    runID: 'run-1',
    placement: placement,
    candidates: [
      ForgeSessionPlacementCandidate(
        instanceID: 'runner-1',
        device: placement.devices.single,
      ),
    ],
  );
}

ForgeSessionPlacementRequest _sessionRequestFromJson(
  Map<String, dynamic> json,
) {
  final owner = ForgeDeviceOwner.fromJson(json['owner']);
  final placement = ForgeDevicePlacementRequest.fromJson(json['placement']);
  final rawCandidates = json['candidates'] as List;
  return ForgeSessionPlacementRequest(
    owner: owner,
    conversationID: json['conversation_id'] as String,
    runID: json['run_id'] as String,
    placement: placement,
    candidates: rawCandidates.map((value) {
      final row = Map<String, dynamic>.from(value as Map);
      return ForgeSessionPlacementCandidate(
        instanceID: row['instance_id'] as String,
        device: ForgeDeviceDeclaration.fromJson(row['device']),
      );
    }).toList(),
  );
}

ForgeSessionDeviceObservationWire _wireFor(
  ForgeSessionPlacementRequest request,
) {
  final placement = observeForgeSessionPlacement(request);
  final inventory = ForgeDeviceInventoryPage(
    evaluationMode: forgeDeviceInventoryEvaluationMode,
    evaluatedAtMS: placement.evaluatedAtMS,
    owner: request.owner,
    ownerDeclarationUnverified: true,
    inventoryDeclarationsUnverified: true,
    notice: forgeDeviceInventoryNotice,
    devices: request.candidates
        .map(
          (candidate) => ForgeDeviceInventoryCandidate(
            instanceID: candidate.instanceID,
            device: candidate.device,
          ),
        )
        .toList(),
    executionAuthorized: false,
    reservationCreated: false,
    dispatchPerformed: false,
  );
  final summary = observeForgeDeviceResourceSummary(
    ForgeDeviceResourceSummaryRequest(
      owner: request.owner,
      inventory: inventory.devices,
      placement: placement,
    ),
  );
  return ForgeSessionDeviceObservationWire(
    schemaVersion: forgeSessionDeviceObservationSchema,
    evaluationMode: forgeSessionDeviceObservationEvaluationMode,
    owner: request.owner,
    conversationID: request.conversationID,
    runID: request.runID,
    evaluatedAtMS: placement.evaluatedAtMS,
    ownerDeclarationUnverified: true,
    inventory: inventory,
    placementObservation: placement,
    resourceSummary: summary,
    selectedDeviceID: null,
    selectedInstanceID: null,
    authority: const ForgeSessionPlacementAuthority.offline(),
  );
}

http.Response _jsonResponse(ForgeSessionDeviceObservationWire wire) =>
    http.Response(
      jsonEncode(wire.toJson()),
      200,
      headers: const {'content-type': 'application/json'},
    );

ForgeDevicePlacementRequest _placementRequest() {
  const owner = ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-1',
    tenantID: 'tenant-1',
  );
  return ForgeDevicePlacementRequest(
    schemaVersion: forgeDevicePlacementRequestSchema,
    evaluatedAtMS: 200000,
    owner: owner,
    maxSnapshotAgeMS: 90000,
    requirements: const ForgeDevicePlacementRequirements(
      os: 'linux',
      architecture: 'amd64',
      minCPUCores: 4,
      minMemoryBytes: 8192,
      minStorageBytes: 4096,
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
    ),
    devices: [
      ForgeDeviceDeclaration(
        deviceID: 'device-1',
        owner: owner,
        approvalState: 'approved',
        cordonState: 'clear',
        liveness: 'online',
        snapshotObservedAtMS: 150000,
        leaseExpiresAtMS: 210000,
        os: 'linux',
        architecture: 'amd64',
        availableCPUCores: 8,
        availableMemoryBytes: 16384,
        availableStorageBytes: 8192,
        runtimes: ['oci'],
        gpu: ForgeDeviceGpu(present: false, memoryBytes: 0, runtime: ''),
        dataResidencyZones: ['us-west'],
        trustZone: 'high',
        sandboxLevels: ['container'],
        concurrencyLimit: 4,
        activeConcurrency: 1,
      ),
    ],
  );
}
