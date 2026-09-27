import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';
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

  testWidgets('claim candidate stays request-free when selected Run differs', (
    tester,
  ) async {
    final store = await _credentialStore('claim-scope-token');
    final requests = <http.Request>[];
    final client = _ownerClient(requests);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionLeaseRequest: _claimRequest(runID: 'run-other'),
          schedulerSelectionLeaseCandidateApiOrigin:
              'https://candidate.example',
          schedulerSelectionLeaseIdempotencyKey: 'claim-scope-key-00000001',
          enableSchedulerSelectionLeaseCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/device-placement/scheduler-lease',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'renewal candidate stays request-free when selected Conversation differs',
    (tester) async {
      final store = await _credentialStore('renew-scope-token');
      final requests = <http.Request>[];
      final client = _ownerClient(requests);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            schedulerSelectionLeaseRenewalRequest: _renewalRequest(
              conversationID: 'conversation-other',
            ),
            schedulerSelectionLeaseRenewalCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseRenewalIdempotencyKey:
                'renew-scope-key-00000001',
            enableSchedulerSelectionLeaseRenewalCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path ==
              '/api/v1/device-placement/scheduler-lease/renew',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'release candidate stays request-free when selected Run differs',
    (tester) async {
      final store = await _credentialStore('release-scope-token');
      final requests = <http.Request>[];
      final client = _ownerClient(requests);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            schedulerSelectionLeaseReleaseRequest: _releaseRequest(
              runID: 'run-other',
            ),
            schedulerSelectionLeaseReleaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseReleaseIdempotencyKey:
                'release-scope-key-00000001',
            enableSchedulerSelectionLeaseReleaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path ==
              '/api/v1/device-placement/scheduler-lease/release',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'claim candidate stays request-free when selected instance hides the Conversation',
    (tester) async {
      final store = await _credentialStore('claim-instance-scope-token');
      final requests = <http.Request>[];
      final client = _ownerClient(requests);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-hidden',
            clientInstanceSessionViewPreview: _hiddenInstanceView(),
            schedulerSelectionLeaseRequest: _claimRequest(runID: 'run-001'),
            schedulerSelectionLeaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseIdempotencyKey:
                'claim-instance-scope-key-00000001',
            enableSchedulerSelectionLeaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-lease',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'renewal candidate stays request-free when selected instance hides the Conversation',
    (tester) async {
      final store = await _credentialStore('renew-instance-scope-token');
      final requests = <http.Request>[];
      final client = _ownerClient(requests);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-hidden',
            clientInstanceSessionViewPreview: _hiddenInstanceView(),
            schedulerSelectionLeaseRenewalRequest: _renewalRequest(
              conversationID: 'conversation-001',
            ),
            schedulerSelectionLeaseRenewalCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseRenewalIdempotencyKey:
                'renew-instance-scope-key-00000001',
            enableSchedulerSelectionLeaseRenewalCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path ==
              '/api/v1/device-placement/scheduler-lease/renew',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'release candidate stays request-free when selected instance hides the Conversation',
    (tester) async {
      final store = await _credentialStore('release-instance-scope-token');
      final requests = <http.Request>[];
      final client = _ownerClient(requests);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-hidden',
            clientInstanceSessionViewPreview: _hiddenInstanceView(),
            schedulerSelectionLeaseReleaseRequest: _releaseRequest(
              runID: 'run-001',
            ),
            schedulerSelectionLeaseReleaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseReleaseIdempotencyKey:
                'release-instance-scope-key-00000001',
            enableSchedulerSelectionLeaseReleaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path ==
              '/api/v1/device-placement/scheduler-lease/release',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

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

MockClient _ownerClient(List<http.Request> requests) => MockClient((request) {
  requests.add(request);
  switch ('${request.method} ${request.url.path}') {
    case 'GET /api/v1/conversations':
      return Future.value(
        _json({
          'conversations': [_conversation()],
          'has_more': false,
        }),
      );
    case 'GET /api/v1/conversations/conversation-001/prompts':
      return Future.value(
        _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        }),
      );
    case 'GET /api/v1/conversations/conversation-001/runs':
      return Future.value(
        _json({
          'conversation_id': 'conversation-001',
          'runs': [_runSummary()],
          'has_more': false,
        }),
      );
    case 'GET /api/v1/conversations/conversation-001/runs/run-001/timeline':
      return Future.value(
        _json({
          'conversation_id': 'conversation-001',
          'run_id': 'run-001',
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        }),
      );
    default:
      if (request.url.path.contains('/device-placement/scheduler-lease')) {
        throw StateError(
          'Scheduler lease candidate must stay closed on selected-scope drift.',
        );
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
  }
});

ForgeSchedulerSelectionLeaseRequest _claimRequest({required String runID}) =>
    ForgeSchedulerSelectionLeaseRequest(
      conversationID: 'conversation-001',
      runID: runID,
      attemptID: 'attempt-001',
      requirements: _requirements(),
      ttlMS: 30000,
    );

ForgeSchedulerSelectionLeaseRenewalRequest _renewalRequest({
  required String conversationID,
}) => ForgeSchedulerSelectionLeaseRenewalRequest(
  conversationID: conversationID,
  runID: 'run-001',
  attemptID: 'attempt-001',
  targetID: 'runner-a',
  epoch: 1,
  fencingToken: 'token-a',
  ttlMS: 30000,
);

ForgeSchedulerSelectionLeaseReleaseRequest _releaseRequest({
  required String runID,
}) => ForgeSchedulerSelectionLeaseReleaseRequest(
  conversationID: 'conversation-001',
  runID: runID,
  attemptID: 'attempt-001',
  targetID: 'runner-a',
  epoch: 2,
  fencingToken: 'token-b',
);

ForgeDevicePlacementRequirements _requirements() =>
    const ForgeDevicePlacementRequirements(
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

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Scheduler lease scope test',
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

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

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
