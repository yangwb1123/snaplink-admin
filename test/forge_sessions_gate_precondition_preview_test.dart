import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_attempt_request_preview.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_evaluation_v2.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';
import 'package:sso_admin/api/forge_preflight_fixture.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/agent/forge_preflight_fixture_card.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

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

  setUp(() => BrowserNavigation.resetForTest());

  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets(
    'Gate forwards the offline Attempt precondition to the real Sessions screen',
    (tester) async {
      final backend = MemoryForgeCredentialBackend();
      final credentialStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: 'gate-token'), isTrue);

      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/conversations');
        return _json({'conversations': <Object>[], 'has_more': false});
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            attemptRequestPreview: _attemptFixture(),
            pendingRunIntentPreview: _pendingFixture(),
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(
        find.byKey(const ValueKey('forge-attempt-request-preview-card')),
        findsOneWidget,
      );
      expect(find.text('Attempt request preview'), findsOneWidget);
      expect(find.text('gate-visible'), findsOneWidget);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -1200));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('forge-pending-run-intent-card')),
        findsOneWidget,
      );
      expect(find.text('Pending Run-intent preview'), findsOneWidget);
      expect(requests, hasLength(1));
    },
  );

  testWidgets(
    'Gate forwards the v2 placement precondition without a device request',
    (tester) async {
      final path = Platform.environment['FORGE_INVENTORY_PLACEMENT_V2_FIXTURE'];
      if (path == null) return;
      final evaluation = ForgeDeviceInventoryPlacementEvaluationV2.fromJson(
        jsonDecode(File(path).readAsStringSync()),
      );
      final backend = MemoryForgeCredentialBackend();
      final credentialStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: 'gate-token'), isTrue);

      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        if (request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            deviceInventoryPlacementEvaluationV2Preview: evaluation,
          ),
        ),
      );
      await _pumpRequests(tester);

      final panel = find.byKey(
        const ValueKey('forge-device-inventory-placement-evaluation-v2-panel'),
      );
      expect(panel, findsOneWidget);
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(
            const ValueKey('forge-placement-evaluation-v2-device-a-runner-a'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
      expect(requests, hasLength(1));
    },
  );

  testWidgets(
    'Gate forwards the Run-Attempt lease preflight without a dispatch request',
    (tester) async {
      final path = Platform
          .environment['FORGE_RUN_ATTEMPT_LEASE_DISPATCH_PREFLIGHT_FIXTURE'];
      if (path == null || path.isEmpty) return;
      final fixture = ForgePreflightFixture.fromJsonText(
        File(path).readAsStringSync(),
      );
      final backend = MemoryForgeCredentialBackend();
      final credentialStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: 'gate-token'), isTrue);

      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/conversations');
        return _json({'conversations': <Object>[], 'has_more': false});
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            runAttemptLeaseDispatchPreflightPreview: fixture,
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(find.byType(ForgePreflightFixtureCard), findsOneWidget);
      expect(find.text('Forge preflight preview'), findsOneWidget);
      expect(find.text('Preview only · no dispatch performed'), findsOneWidget);
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
      expect(requests, hasLength(1));
    },
  );

  testWidgets(
    'Gate keeps the preflight candidate request-free until a typed request is injected',
    (tester) async {
      final backend = MemoryForgeCredentialBackend();
      final credentialStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: 'gate-token'), isTrue);

      var readerCalls = 0;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/conversations');
        return _json({'conversations': <Object>[], 'has_more': false});
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            runAttemptLeaseDispatchPreflightReader:
                (ForgeRunAttemptLeaseDispatchPreflightRequest request) async {
                  readerCalls++;
                  throw StateError(
                    'reader must stay disabled without a request',
                  );
                },
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(readerCalls, 0);
      expect(
        requests.where(
          (request) =>
              request.url.path.contains('attempt-lease-dispatch-preflight'),
        ),
        isEmpty,
      );
      expect(requests, hasLength(1));
    },
  );
}

ForgeAttemptRequestPreviewFixture _attemptFixture() =>
    ForgeAttemptRequestPreviewFixture.fromJson({
      'schema_version': forgeAttemptRequestSchema,
      'evaluation_mode': forgeAttemptRequestEvaluationMode,
      'authority': {
        'device_identity_verified': false,
        'references_resolved': false,
        'request_persisted': false,
        'reservation_created': false,
        'execution_authorized': false,
        'dispatch_performed': false,
        'audit_published': false,
      },
      'cases': [
        {
          'name': 'gate-visible',
          'request': {
            'scope_ref': {
              'action_id': null,
              'attempt_id': 'attempt',
              'change_id': 'change',
              'objective_id': 'objective',
              'project_id': 'project',
              'project_snapshot_id': 'snapshot',
              'session_id': null,
              'space_id': 'space',
              'turn_id': null,
              'work_graph_id': 'graph',
              'work_item_id': 'item',
            },
            'attempt_ref': {'entity_id': 'attempt', 'entity_type': 'attempt'},
            'work_item_ref': {'entity_id': 'item', 'entity_type': 'work_item'},
            'project_ref': {'entity_id': 'project', 'entity_type': 'project'},
            'project_snapshot_ref': {
              'entity_id': 'snapshot',
              'entity_type': 'project_snapshot',
            },
            'control_versions': {
              'objective_version': 1,
              'change_version': 1,
              'work_graph_version': 1,
              'work_item_version': 1,
            },
            'executor': {
              'actor_ref': {'actor_id': 'actor', 'actor_type': 'agent'},
              'adapter_id': 'adapter',
              'adapter_version': '1',
            },
            'context_artifact_ref': null,
            'workspace_capability_ref': null,
            'grant_ref': null,
            'approval_refs': [
              {
                'record_id': 'approval.a',
                'record_sha256': 'digest',
                'record_type': 'approval',
              },
            ],
            'requested_effects': ['read.repo'],
            'budget': {
              'max_duration_ms': 1,
              'max_cost_usd_micros': 1,
              'max_model_calls': 1,
              'max_tool_calls': 1,
              'max_input_tokens': 1,
              'max_output_tokens': 1,
              'max_output_bytes': 1,
              'max_network_bytes': 1,
            },
            'timeout_ms': 1,
            'idempotency_key': 'attempt-key',
          },
          'expected': {
            'accepted': true,
            'error': '',
            'initial_state': 'requested',
            'requested_effects': ['read.repo'],
            'approval_record_ids': ['approval.a'],
          },
        },
      ],
    });

ForgePendingRunIntentFixture _pendingFixture() =>
    ForgePendingRunIntentFixture.fromJson({
      'schema_version': forgePendingRunIntentSchema,
      'evaluation_mode': forgePendingRunIntentEvaluationMode,
      'authority': {
        'device_identity_verified': false,
        'inventory_authoritative': false,
        'reservation_created': false,
        'execution_authorized': false,
        'dispatch_performed': false,
        'run_created': false,
        'audit_published': false,
      },
      'owner': {
        'issuer': 'https://id.example',
        'subject': 'user-1',
        'tenant_id': 'tenant-1',
      },
      'conversation_id': 'conversation-001',
      'submission': {
        'prompt': {
          'id': 'prompt-001',
          'conversation_id': 'conversation-001',
          'role': 'user',
          'content': 'prepare the report',
          'created_at_ms': 200,
        },
        'intent': {
          'intent_id': 'intent-001',
          'conversation_id': 'conversation-001',
          'prompt_id': 'prompt-001',
          'project_id': 'project-001',
          'profile_id': 'profile-001',
          'submitted_at_ms': 200,
          'aggregate_version': 4,
          'latest_sequence': 1,
          'status': 'pending',
        },
        'initial_event': {
          'event_id': 'event-001',
          'seq': 1,
          'emitted_at_ms': 200,
          'type': 'submitted',
        },
        'replayed': false,
      },
      'page': {
        'conversation_id': 'conversation-001',
        'intents': [
          {
            'intent_id': 'intent-001',
            'conversation_id': 'conversation-001',
            'prompt_id': 'prompt-001',
            'project_id': 'project-001',
            'profile_id': 'profile-001',
            'submitted_at_ms': 200,
            'aggregate_version': 4,
            'latest_sequence': 1,
            'status': 'pending',
          },
        ],
        'next_cursor': null,
        'has_more': false,
      },
      'timeline': {
        'conversation_id': 'conversation-001',
        'intent_id': 'intent-001',
        'after_sequence': 0,
        'scanned_through_sequence': 1,
        'has_more': false,
        'events': [
          {
            'event_id': 'event-001',
            'seq': 1,
            'emitted_at_ms': 200,
            'type': 'submitted',
          },
        ],
      },
      'expected': {
        'prompt_role': 'user',
        'intent_status': 'pending',
        'initial_event_type': 'submitted',
        'timeline_event_count': 1,
        'replayed': false,
      },
    });
