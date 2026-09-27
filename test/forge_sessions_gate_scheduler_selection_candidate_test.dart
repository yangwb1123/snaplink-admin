import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_resource_convergence.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(BrowserNavigation.resetForTest);
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('explicit Gate performs one scheduler preview POST', (
    tester,
  ) async {
    final store = await _credentialStore('scheduler-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path == '/api/v1/device-placement/scheduler-preview') {
        return _json(_preview().toJson());
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionPreviewRequest: _request(),
          schedulerSelectionPreviewCandidateApiOrigin:
              'https://candidate.example',
          enableSchedulerSelectionPreviewCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    final schedulerRequests = requests
        .where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-preview',
        )
        .toList();
    expect(schedulerRequests, hasLength(1));
    expect(schedulerRequests.single.method, 'POST');
    expect(
      schedulerRequests.single.headers['authorization'],
      'Bearer scheduler-token',
    );
    expect(
      ForgeSchedulerSelectionPreviewRequest.fromJson(
        jsonDecode(schedulerRequests.single.body),
      ).toJson(),
      _request().toJson(),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('default Gate keeps scheduler preview request-free', (
    tester,
  ) async {
    final store = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted candidate: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionPreviewRequest: _request(),
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) => request.url.path.contains('scheduler-preview'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('inventory/resource drift keeps scheduler preview request-free', (
    tester,
  ) async {
    final convergence = ForgeDeviceInventoryResourceConvergence.fromJsonText(
      File(
        'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
      ).readAsStringSync(),
    );
    final driftedResource = convergence.resourceView.toJson();
    final devices = List<Map<String, dynamic>>.from(
      (driftedResource['devices'] as List).map(
        (value) => Map<String, dynamic>.from(value as Map),
      ),
    );
    devices.single['observed_at_ms'] =
        (devices.single['observed_at_ms'] as int) + 1;
    driftedResource['devices'] = devices;
    final resource = ForgeClientInstanceResourceView.fromJson(driftedResource);
    final store = await _credentialStore('scheduler-drift-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path == '/api/v1/device-placement/scheduler-preview') {
        throw StateError('Scheduler preview must stay closed on drift.');
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);
    addTearDown(store.clear);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          deviceInventoryOwner: convergence.inventory.owner,
          deviceInventoryV2Reader: (_) async =>
              ForgeDeviceInventoryPageV2.fromJson(
                convergence.inventory.toJson(),
              ),
          clientInstanceResourceViewOwner: convergence.inventory.owner,
          clientInstanceResourceViewReader: (_) async => resource,
          schedulerSelectionPreviewRequest: _request(),
          schedulerSelectionPreviewCandidateApiOrigin:
              'https://candidate.example',
          enableSchedulerSelectionPreviewCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/device-placement/scheduler-preview',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('selected Run mismatch keeps scheduler preview request-free', (
    tester,
  ) async {
    final store = await _credentialStore('mismatch-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      switch ('${request.method} ${request.url.path}') {
        case 'GET /api/v1/conversations':
          return _json({
            'conversations': [_conversation()],
            'has_more': false,
          });
        case 'GET /api/v1/conversations/conversation-001/prompts':
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        case 'GET /api/v1/conversations/conversation-001/runs':
          return _json({
            'conversation_id': 'conversation-001',
            'runs': [_runSummary()],
            'has_more': false,
          });
        case 'GET /api/v1/conversations/conversation-001/runs/run-001/timeline':
          return _json({
            'conversation_id': 'conversation-001',
            'run_id': 'run-001',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        case 'POST /api/v1/device-placement/scheduler-preview':
          throw StateError(
            'Scheduler preview must stay closed on selected Run mismatch.',
          );
        default:
          throw StateError(
            'Unexpected Forge request: ${request.method} ${request.url}',
          );
      }
    });
    addTearDown(client.close);

    final mismatchedRequest = ForgeSchedulerSelectionPreviewRequest(
      conversationID: 'conversation-001',
      runID: 'run-other',
      attemptID: 'attempt-1',
      requirements: _request().requirements,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionPreviewRequest: mismatchedRequest,
          schedulerSelectionPreviewCandidateApiOrigin:
              'https://candidate.example',
          enableSchedulerSelectionPreviewCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/device-placement/scheduler-preview',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'selected instance projection keeps hidden scheduler preview request-free',
    (tester) async {
      final store = await _credentialStore('instance-scope-token');
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/v1/conversations':
            return _json({
              'conversations': [_conversation()],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/prompts':
            return _json({
              'conversation_id': 'conversation-001',
              'prompts': <Object>[],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs':
            return _json({
              'conversation_id': 'conversation-001',
              'runs': [_runSummary()],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs/run-001/timeline':
            return _json({
              'conversation_id': 'conversation-001',
              'run_id': 'run-001',
              'after_sequence': 0,
              'scanned_through_sequence': 0,
              'has_more': false,
              'events': <Object>[],
            });
          case 'POST /api/v1/device-placement/scheduler-preview':
            throw StateError(
              'Scheduler preview must stay closed for a hidden instance Conversation.',
            );
          default:
            throw StateError(
              'Unexpected Forge request: ${request.method} ${request.url}',
            );
        }
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-hidden',
            clientInstanceSessionViewPreview: _hiddenInstanceView(),
            schedulerSelectionPreviewRequest: _request(
              conversationID: 'conversation-001',
              runID: 'run-001',
            ),
            schedulerSelectionPreviewCandidateApiOrigin:
                'https://candidate.example',
            enableSchedulerSelectionPreviewCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-preview',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

ForgeSchedulerSelectionPreviewRequest _request({
  String conversationID = 'conversation-1',
  String runID = 'run-1',
}) => ForgeSchedulerSelectionPreviewRequest(
  conversationID: conversationID,
  runID: runID,
  attemptID: 'attempt-1',
  requirements: const ForgeDevicePlacementRequirements(
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
  ),
);

ForgeSchedulerSelectionPreview _preview() =>
    const ForgeSchedulerSelectionPreview(
      schemaVersion: ForgeSchedulerSelectionPreview.schema,
      mode: ForgeSchedulerSelectionPreview.evaluationMode,
      owner: ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-a',
        tenantID: 'tenant-a',
      ),
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      evaluatedAtMS: 1800000000000,
      candidateCount: 2,
      eligibleCandidateCount: 1,
      selectionAvailable: true,
      selectionReason: 'first_sorted_eligible_candidate',
      selectedDeviceID: 'device-a',
      selectedInstanceID: 'runner-a',
      previewOnly: true,
      authority: ForgeSchedulerSelectionAuthority(
        placementSelected: false,
        reservationCreated: false,
        leaseIssued: false,
        executionAuthorized: false,
        dispatchPerformed: false,
        auditPublished: false,
      ),
    );

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Scheduler selection mismatch test',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _runSummary() => {
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 10,
  'latest_sequence': 1,
  'status': 'nonterminal',
};

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

ForgeClientInstanceSessionView _hiddenInstanceView() =>
    ForgeClientInstanceSessionView.fromJson({
      'schema_version': forgeClientInstanceSessionViewSchema,
      'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
      'owner_declaration': {
        'issuer': 'https://id.example',
        'subject': 'user-a',
        'tenant_id': 'tenant-a',
      },
      'owner_declaration_unverified': true,
      'instances': [
        {
          'instance_id': 'client-web-hidden',
          'client_kind': 'web',
          'session_ids': ['conversation-002'],
          'observed_at_ms': 1,
          'status': 'active',
        },
      ],
      'read_only': true,
      'authority': const ForgeClientInstanceSessionViewAuthority.offline()
          .toJson(),
    });
