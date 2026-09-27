import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/api/forge_runner_dispatch_plan_preview.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

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

  testWidgets('explicit Gate posts one bound Runner dispatch-plan preview', (
    tester,
  ) async {
    final requestPath = Platform
        .environment['FORGE_RUN_ATTEMPT_LEASE_DISPATCH_PREFLIGHT_REQUEST_FIXTURE'];
    final previewPath =
        Platform.environment['FORGE_RUNNER_DISPATCH_PLAN_FIXTURE'];
    if (requestPath == null || previewPath == null) return;
    final request = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
      jsonDecode(File(requestPath).readAsStringSync()),
    );
    final preview = ForgeRunnerDispatchPlanPreview.fromJsonText(
      File(previewPath).readAsStringSync(),
    );
    final credentialStore = await _credentialStore('candidate-token');
    final requests = <http.Request>[];
    final client = MockClient((http.Request httpRequest) async {
      requests.add(httpRequest);
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation(request.conversationID)],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/prompts') {
        return _json({
          'conversation_id': request.conversationID,
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/runs') {
        return _json({
          'conversation_id': request.conversationID,
          'runs': [_run(request.runID)],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/runs/${request.runID}/timeline') {
        return _json({
          'conversation_id': request.conversationID,
          'run_id': request.runID,
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      if (httpRequest.method == 'POST' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/runs/${request.runID}/runner-dispatch-plan-preview') {
        expect(httpRequest.headers['authorization'], 'Bearer candidate-token');
        expect(jsonDecode(httpRequest.body), request.dispatchPlan.toJson());
        // The canonical response fixture is independent of the preflight
        // request fixture's command digest. Bind that one response field to
        // the request so the Gate's strict display projection can accept it.
        return _json(
          preview.toJson()
            ..['command_sha256'] =
                request.dispatchPlan.runnerExecutionIntent.commandSHA256,
        );
      }
      throw StateError(
        'Unexpected Forge request: ${httpRequest.method} ${httpRequest.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          runnerDispatchPlanPreviewRequest: request,
          enableRunnerDispatchPlanPreviewCandidate: true,
          runnerDispatchPlanPreviewCandidateApiOrigin:
              'https://candidate.example',
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Runner dispatch-plan preview'), findsOneWidget);
    expect(find.text('Preview only · no dispatch performed'), findsOneWidget);
    final previewRequests = requests
        .where(
          (value) => value.url.path.endsWith('runner-dispatch-plan-preview'),
        )
        .toList();
    expect(previewRequests, hasLength(1));
  });

  testWidgets('default Gate keeps Runner dispatch-plan preview request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted a candidate route: $request');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (request) => request.url.path.endsWith('runner-dispatch-plan-preview'),
      ),
      isEmpty,
    );
  });

  testWidgets('dispatch-plan candidate re-reads the selected instance before POST', (
    tester,
  ) async {
    final requestPath = Platform
        .environment['FORGE_RUN_ATTEMPT_LEASE_DISPATCH_PREFLIGHT_REQUEST_FIXTURE'];
    final previewPath =
        Platform.environment['FORGE_RUNNER_DISPATCH_PLAN_FIXTURE'];
    if (requestPath == null || previewPath == null) return;
    final request = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
      jsonDecode(File(requestPath).readAsStringSync()),
    );
    final preview = ForgeRunnerDispatchPlanPreview.fromJsonText(
      File(previewPath).readAsStringSync(),
    );
    final credentialStore = await _credentialStore(
      'dispatch-instance-refresh-token',
    );
    final requests = <http.Request>[];
    final client = MockClient((http.Request httpRequest) async {
      requests.add(httpRequest);
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation(request.conversationID)],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/prompts') {
        return _json({
          'conversation_id': request.conversationID,
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/runs') {
        return _json({
          'conversation_id': request.conversationID,
          'runs': [_run(request.runID)],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/runs/${request.runID}/timeline') {
        return _json({
          'conversation_id': request.conversationID,
          'run_id': request.runID,
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      if (httpRequest.method == 'POST' &&
          httpRequest.url.path ==
              '/api/v1/conversations/${request.conversationID}/runs/${request.runID}/runner-dispatch-plan-preview') {
        throw StateError(
          'Dispatch-plan candidate must stay closed after instance drift.',
        );
      }
      throw StateError(
        'Unexpected Forge request: ${httpRequest.method} ${httpRequest.url}',
      );
    });
    addTearDown(client.close);

    var sessionReads = 0;
    var resourceReads = 0;
    final owner = request.owner;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          initialClientInstanceID: 'client-cli-001',
          clientInstanceSessionViewOwner: owner,
          clientInstanceSessionViewReader: (_) async {
            sessionReads++;
            return _sessionView(
              owner,
              sessionReads == 1 ? request.conversationID : 'other-session',
            );
          },
          clientInstanceResourceViewOwner: owner,
          clientInstanceResourceViewReader: (_) async {
            resourceReads++;
            return _resourceView(
              owner,
              resourceReads == 1 ? request.conversationID : 'other-session',
            );
          },
          runnerDispatchPlanPreviewRequest: request,
          enableRunnerDispatchPlanPreviewCandidate: true,
          runnerDispatchPlanPreviewCandidateApiOrigin:
              'https://candidate.example',
        ),
      ),
    );
    await _settle(tester);

    expect(sessionReads, greaterThanOrEqualTo(2));
    expect(resourceReads, greaterThanOrEqualTo(2));
    expect(
      requests.where(
        (value) => value.url.path.endsWith('runner-dispatch-plan-preview'),
      ),
      isEmpty,
    );
    // Keep the fixture referenced so this test continues to validate the
    // exact candidate response shape when the contract harness is enabled.
    expect(preview.isDisplayOnly, isTrue);
  });

  testWidgets(
    'independent client-instance readers keep owner conversations visible without a selected instance',
    (tester) async {
      final credentialStore = await _credentialStore(
        'independent-pair-owner-token',
      );
      final owner = ForgeDeviceOwner.fromJson({
        'issuer': 'https://id.example',
        'subject': 'user-a',
        'tenant_id': 'tenant-a',
      });
      final requests = <http.Request>[];
      final client = MockClient((http.Request request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-pair')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-pair/prompts') {
          return _json({
            'conversation_id': 'conversation-pair',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-pair/runs') {
          return _json({
            'conversation_id': 'conversation-pair',
            'runs': <Object>[],
            'has_more': false,
          });
        }
        throw StateError('Unexpected Forge request: $request');
      });
      addTearDown(client.close);

      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async =>
                _sessionView(owner, 'conversation-pair'),
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async =>
                _resourceView(owner, 'conversation-pair'),
          ),
        ),
      );
      await _settle(tester);

      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-pair')),
        findsOneWidget,
      );
      expect(
        requests.where(
          (request) => request.url.path == '/api/v1/conversations',
        ),
        isNotEmpty,
      );
    },
  );
}

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Map<String, dynamic> _conversation(String id) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': 'Shared work',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run(String id) => {
  'run_id': id,
  'prompt_id': 'prompt-001',
  'created_at_ms': 10,
  'latest_sequence': 1,
  'status': 'nonterminal',
};

ForgeClientInstanceSessionView _sessionView(
  ForgeDeviceOwner owner,
  String sessionID,
) => ForgeClientInstanceSessionView.fromJson({
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-cli-001',
      'client_kind': 'cli',
      'session_ids': [sessionID],
      'observed_at_ms': 1,
      'status': 'active',
    },
  ],
  'read_only': true,
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
});

ForgeClientInstanceResourceView _resourceView(
  ForgeDeviceOwner owner,
  String sessionID,
) => ForgeClientInstanceResourceView.fromJson({
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-cli-001',
      'client_kind': 'cli',
      'session_ids': [sessionID],
      'observed_at_ms': 1,
      'status': 'active',
    },
  ],
  'devices': <Object>[],
  'device_attributes_unverified': true,
  'read_only': true,
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
});
