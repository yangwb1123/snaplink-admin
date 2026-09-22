import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/screens/forge/forge_sessions_device_observation.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 8; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders a matching offline observation beside the Run', (
    tester,
  ) async {
    final observation = _observation(runID: 'run-1');
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_ownedConversation()],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json({
          'conversation_id': 'conversation-1',
          'runs': [_run()],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-1/runs/run-1/timeline') {
        return _json({
          'conversation_id': 'conversation-1',
          'run_id': 'run-1',
          'after_sequence': 0,
          'scanned_through_sequence': 2,
          'has_more': false,
          'events': [
            {'seq': 1, 'emitted_at_ms': 11, 'type': 'run_started'},
            {'seq': 2, 'emitted_at_ms': 12, 'type': 'run_finished'},
          ],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceObservation: observation,
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.scrollUntilVisible(
      find.text('Offline device observation'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const ValueKey('forge-session-device-observation')),
      findsOneWidget,
    );
    expect(find.text('Offline device observation'), findsOneWidget);
    expect(find.text('Conversation: conversation-1'), findsOneWidget);
    expect(find.text('Run: run-1'), findsOneWidget);
    expect(find.text('Device: device-1'), findsOneWidget);
    expect(find.text('Instance: runner-1'), findsOneWidget);
    expect(find.text('Execution authorized: false'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });

  testWidgets('does not render an observation bound to another Run', (
    tester,
  ) async {
    final observation = _observation(runID: 'run-foreign');
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_ownedConversation()],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json({
          'conversation_id': 'conversation-1',
          'runs': [_run()],
          'has_more': false,
        });
      }
      if (request.method == 'GET' && request.url.path.endsWith('/timeline')) {
        return _json({
          'conversation_id': 'conversation-1',
          'run_id': 'run-1',
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceObservation: observation,
        ),
      ),
    );
    await _pumpRequests(tester);
    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.text('Run timeline · run-1'),
      500,
      scrollable: scrollable,
    );
    await tester.drag(scrollable, const Offset(0, -5000));
    await tester.pump();

    expect(
      find.byKey(const ValueKey('forge-session-device-observation')),
      findsNothing,
    );
    expect(find.text('Device: device-1'), findsNothing);
  });

  testWidgets('loads a matching observation through the authenticated preview', (
    tester,
  ) async {
    final observation = _observation(runID: 'run-1');
    final request = _placementRequest();
    var previewCalls = 0;
    final client = MockClient((requestMessage) async {
      if (requestMessage.method == 'GET' &&
          requestMessage.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_ownedConversation()],
          'has_more': false,
        });
      }
      if (requestMessage.method == 'GET' &&
          requestMessage.url.path ==
              '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (requestMessage.method == 'GET' &&
          requestMessage.url.path ==
              '/api/v1/conversations/conversation-1/runs') {
        return _json({
          'conversation_id': 'conversation-1',
          'runs': [_run()],
          'has_more': false,
        });
      }
      if (requestMessage.method == 'GET' &&
          requestMessage.url.path ==
              '/api/v1/conversations/conversation-1/runs/run-1/timeline') {
        return _json({
          'conversation_id': 'conversation-1',
          'run_id': 'run-1',
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      if (requestMessage.method == 'POST' &&
          requestMessage.url.path ==
              '/api/v1/conversations/conversation-1/runs/run-1/device-observation/preview') {
        previewCalls++;
        final body = jsonDecode(requestMessage.body) as Map<String, dynamic>;
        expect(body['conversation_id'], 'conversation-1');
        expect(body['run_id'], 'run-1');
        expect(body['candidates'], hasLength(1));
        expect(requestMessage.headers['authorization'], 'Bearer forge-bearer');
        return _json(_wireFor(observation));
      }
      throw StateError(
        'Unexpected Forge request: ${requestMessage.method} ${requestMessage.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceObservationRequest: request,
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.scrollUntilVisible(
      find.text('Offline device observation'),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(previewCalls, 1);
    expect(
      find.byKey(const ValueKey('forge-session-device-observation')),
      findsOneWidget,
    );
    expect(find.text('Device: device-1'), findsOneWidget);
  });

  testWidgets('imports a matching canonical observation for the selected Run', (
    tester,
  ) async {
    var unexpectedPost = false;
    final client = _sessionsClient(
      onRequest: (request) {
        if (request.method == 'POST') unexpectedPost = true;
      },
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    final scrollable = find.byType(Scrollable).first;
    final importButton = find.byKey(
      const ValueKey('forge-import-device-observation'),
    );
    await tester.scrollUntilVisible(importButton, 500, scrollable: scrollable);
    await tester.tap(importButton);
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('forge-offline-device-observation-json')),
      jsonEncode(_wireFor(_observation(runID: 'run-1'))),
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-import-offline-observation')),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-session-device-observation')),
      500,
      scrollable: scrollable,
    );

    expect(
      find.byKey(const ValueKey('forge-session-device-observation')),
      findsOneWidget,
    );
    expect(find.text('Device: device-1'), findsOneWidget);
    expect(unexpectedPost, isFalse);
  });

  testWidgets(
    'reloads a changed observation request while the screen stays mounted',
    (tester) async {
      final request = _placementRequest();
      var previewCalls = 0;
      final client = _sessionsClient(
        previewObservation: _observation(runID: 'run-1'),
        onRequest: (request) {
          if (request.method == 'POST' &&
              request.url.path.endsWith('/device-observation/preview')) {
            previewCalls++;
          }
        },
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(
        find.byKey(const ValueKey('forge-session-device-observation')),
        findsNothing,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            deviceObservationRequest: request,
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(previewCalls, 1);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-session-device-observation')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('forge-session-device-observation')),
        findsOneWidget,
      );
      expect(find.text('Device: device-1'), findsOneWidget);
    },
  );

  testWidgets('rejects an imported observation for another Run', (
    tester,
  ) async {
    final client = _sessionsClient();

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    final scrollable = find.byType(Scrollable).first;
    final importButton = find.byKey(
      const ValueKey('forge-import-device-observation'),
    );
    await tester.scrollUntilVisible(importButton, 500, scrollable: scrollable);
    await tester.tap(importButton);
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('forge-offline-device-observation-json')),
      jsonEncode(_wireFor(_observation(runID: 'run-foreign'))),
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-import-offline-observation')),
    );
    await tester.pump();

    expect(
      find.text('The observation must match the selected Run.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-session-device-observation')),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
  });

  testWidgets('rejects an imported observation with a selected instance', (
    tester,
  ) async {
    final client = _sessionsClient();

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    final scrollable = find.byType(Scrollable).first;
    final importButton = find.byKey(
      const ValueKey('forge-import-device-observation'),
    );
    await tester.scrollUntilVisible(importButton, 500, scrollable: scrollable);
    await tester.tap(importButton);
    await tester.pump();

    final selected = Map<String, dynamic>.from(
      _wireFor(_observation(runID: 'run-1')),
    )..['selected_instance_id'] = 'runner-1';
    await tester.enterText(
      find.byKey(const ValueKey('forge-offline-device-observation-json')),
      jsonEncode(selected),
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-import-offline-observation')),
    );
    await tester.pump();

    expect(find.text('Invalid offline device observation.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('forge-session-device-observation')),
      findsNothing,
    );
    await tester.tap(find.text('Cancel'));
  });

  test('rejects an authoritative page declaration', () {
    final owner = _owner;
    final page = ForgeDeviceInventoryPage(
      evaluationMode: forgeDeviceInventoryEvaluationMode,
      evaluatedAtMS: 200000,
      owner: owner,
      ownerDeclarationUnverified: true,
      inventoryDeclarationsUnverified: true,
      notice: forgeDeviceInventoryNotice,
      devices: const [],
      executionAuthorized: true,
      reservationCreated: false,
      dispatchPerformed: false,
    );
    expect(
      () => ForgeSessionDeviceObservation.fromOfflineDeclarations(
        conversationID: 'conversation-1',
        runID: 'run-1',
        page: page,
        requirements: _requirements,
        maxSnapshotAgeMS: 90000,
        candidates: const [],
      ),
      throwsA(
        isA<ForgeSessionDeviceObservationError>().having(
          (error) => error.code,
          'code',
          'page_authority',
        ),
      ),
    );
  });

  test('rejects snapshot rows that are not bound to the page', () {
    final page = _page;
    expect(
      () => ForgeSessionDeviceObservation.fromOfflineDeclarations(
        conversationID: 'conversation-1',
        runID: 'run-1',
        page: page,
        requirements: _requirements,
        maxSnapshotAgeMS: 90000,
        candidates: const [
          ForgeSessionPlacementCandidate(
            instanceID: 'runner-1',
            device: _device,
          ),
        ],
        snapshot: const ForgeDeviceInventorySnapshot(
          snapshotID: 'snapshot-1',
          observedAtMS: 200000,
          owner: _owner,
          rows: [
            ForgeDeviceInventorySnapshotRow(
              deviceID: 'foreign-device',
              instanceID: 'runner-1',
              owner: _owner,
            ),
          ],
        ),
      ),
      throwsA(
        isA<ForgeSessionDeviceObservationError>().having(
          (error) => error.code,
          'code',
          'snapshot_binding',
        ),
      ),
    );
  });

  test('rejects duplicate Runner instance declarations before aggregation', () {
    final page = ForgeDeviceInventoryPage(
      evaluationMode: forgeDeviceInventoryEvaluationMode,
      evaluatedAtMS: 200000,
      owner: _owner,
      ownerDeclarationUnverified: true,
      inventoryDeclarationsUnverified: true,
      notice: forgeDeviceInventoryNotice,
      devices: [
        ForgeDeviceInventoryCandidate(instanceID: 'runner-1', device: _device),
        ForgeDeviceInventoryCandidate(
          instanceID: 'runner-1',
          device: _deviceWithID('device-2'),
        ),
      ],
      executionAuthorized: false,
      reservationCreated: false,
      dispatchPerformed: false,
    );
    expect(
      () => ForgeSessionDeviceObservation.fromOfflineDeclarations(
        conversationID: 'conversation-1',
        runID: 'run-1',
        page: page,
        requirements: _requirements,
        maxSnapshotAgeMS: 90000,
        candidates: [
          ForgeSessionPlacementCandidate(
            instanceID: 'runner-1',
            device: _device,
          ),
          ForgeSessionPlacementCandidate(
            instanceID: 'runner-1',
            device: _deviceWithID('device-2'),
          ),
        ],
      ),
      throwsA(
        isA<ForgeSessionDeviceObservationError>().having(
          (error) => error.code,
          'code',
          'page_binding',
        ),
      ),
    );
  });
}

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

const _requirements = ForgeDevicePlacementRequirements(
  os: 'linux',
  architecture: 'amd64',
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

const _device = ForgeDeviceDeclaration(
  deviceID: 'device-1',
  owner: _owner,
  approvalState: 'approved',
  cordonState: 'clear',
  liveness: 'online',
  snapshotObservedAtMS: 150000,
  leaseExpiresAtMS: 210000,
  os: 'linux',
  architecture: 'amd64',
  availableCPUCores: 4,
  availableMemoryBytes: 8192,
  availableStorageBytes: 4096,
  runtimes: ['oci'],
  gpu: ForgeDeviceGpu(present: false, memoryBytes: 0, runtime: ''),
  dataResidencyZones: ['us-west'],
  trustZone: 'standard',
  sandboxLevels: ['container'],
  concurrencyLimit: 2,
  activeConcurrency: 0,
);
const _page = ForgeDeviceInventoryPage(
  evaluationMode: forgeDeviceInventoryEvaluationMode,
  evaluatedAtMS: 200000,
  owner: _owner,
  ownerDeclarationUnverified: true,
  inventoryDeclarationsUnverified: true,
  notice: forgeDeviceInventoryNotice,
  devices: [
    ForgeDeviceInventoryCandidate(instanceID: 'runner-1', device: _device),
  ],
  executionAuthorized: false,
  reservationCreated: false,
  dispatchPerformed: false,
);

ForgeDeviceDeclaration _deviceWithID(String deviceID) => ForgeDeviceDeclaration(
  deviceID: deviceID,
  owner: _device.owner,
  approvalState: _device.approvalState,
  cordonState: _device.cordonState,
  liveness: _device.liveness,
  snapshotObservedAtMS: _device.snapshotObservedAtMS,
  leaseExpiresAtMS: _device.leaseExpiresAtMS,
  os: _device.os,
  architecture: _device.architecture,
  availableCPUCores: _device.availableCPUCores,
  availableMemoryBytes: _device.availableMemoryBytes,
  availableStorageBytes: _device.availableStorageBytes,
  runtimes: _device.runtimes,
  gpu: _device.gpu,
  dataResidencyZones: _device.dataResidencyZones,
  trustZone: _device.trustZone,
  sandboxLevels: _device.sandboxLevels,
  concurrencyLimit: _device.concurrencyLimit,
  activeConcurrency: _device.activeConcurrency,
);

ForgeSessionDeviceObservation _observation({required String runID}) {
  return ForgeSessionDeviceObservation.fromOfflineDeclarations(
    conversationID: 'conversation-1',
    runID: runID,
    page: _page,
    requirements: _requirements,
    maxSnapshotAgeMS: 90000,
    candidates: const [
      ForgeSessionPlacementCandidate(instanceID: 'runner-1', device: _device),
    ],
  );
}

ForgeSessionPlacementRequest _placementRequest() =>
    ForgeSessionPlacementRequest(
      owner: _owner,
      conversationID: 'conversation-1',
      runID: 'run-1',
      placement: ForgeDevicePlacementRequest(
        schemaVersion: forgeDevicePlacementRequestSchema,
        evaluatedAtMS: _page.evaluatedAtMS,
        owner: _owner,
        maxSnapshotAgeMS: 90000,
        requirements: _requirements,
        devices: [_device],
      ),
      candidates: const [
        ForgeSessionPlacementCandidate(instanceID: 'runner-1', device: _device),
      ],
    );

Map<String, dynamic> _wireFor(ForgeSessionDeviceObservation observation) =>
    ForgeSessionDeviceObservationWire(
      schemaVersion: forgeSessionDeviceObservationSchema,
      evaluationMode: forgeSessionDeviceObservationEvaluationMode,
      owner: observation.page.owner,
      conversationID: observation.conversationID,
      runID: observation.runID,
      evaluatedAtMS: observation.page.evaluatedAtMS,
      ownerDeclarationUnverified: true,
      inventory: observation.page,
      placementObservation: observation.placementObservation,
      resourceSummary: observation.resourceSummary,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: const ForgeSessionPlacementAuthority.offline(),
    ).toJson();

Map<String, Object> _ownedConversation() => {
  'conversation': {
    'id': 'conversation-1',
    'scope': {'kind': 'global'},
    'title': 'Shared work',
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': 1,
};

Map<String, Object> _run() => {
  'run_id': 'run-1',
  'prompt_id': 'prompt-1',
  'created_at_ms': 10,
  'latest_sequence': 2,
  'status': 'completed',
};

MockClient _sessionsClient({
  ForgeSessionDeviceObservation? previewObservation,
  void Function(http.BaseRequest request)? onRequest,
}) {
  return MockClient((request) async {
    onRequest?.call(request);
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/conversations') {
      return _json({
        'conversations': [_ownedConversation()],
        'has_more': false,
      });
    }
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/conversations/conversation-1/prompts') {
      return _json({
        'conversation_id': 'conversation-1',
        'prompts': <Object>[],
        'has_more': false,
      });
    }
    if (request.method == 'GET' &&
        request.url.path == '/api/v1/conversations/conversation-1/runs') {
      return _json({
        'conversation_id': 'conversation-1',
        'runs': [_run()],
        'has_more': false,
      });
    }
    if (request.method == 'GET' && request.url.path.endsWith('/timeline')) {
      return _json({
        'conversation_id': 'conversation-1',
        'run_id': 'run-1',
        'after_sequence': 0,
        'scanned_through_sequence': 0,
        'has_more': false,
        'events': <Object>[],
      });
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/device-observation/preview') &&
        previewObservation != null) {
      return _json(_wireFor(previewObservation));
    }
    throw StateError(
      'Unexpected Forge request: ${request.method} ${request.url}',
    );
  });
}
