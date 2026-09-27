import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';
import 'package:sso_admin/screens/forge/forge_runner_execution_boundary_card.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
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

  testWidgets('explicit Gate posts one execution-boundary preview', (
    tester,
  ) async {
    final request = _request();
    final store = await _credentialStore('boundary-token');
    final requests = <http.Request>[];
    final client = MockClient((incoming) async {
      requests.add(incoming);
      if (incoming.method == 'GET' &&
          incoming.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation()],
          'has_more': false,
        });
      }
      if (incoming.method == 'GET' &&
          incoming.url.path ==
              '/api/v1/conversations/conversation-001/prompts') {
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (incoming.method == 'GET' &&
          incoming.url.path == '/api/v1/conversations/conversation-001/runs') {
        return _json({
          'conversation_id': 'conversation-001',
          'runs': [_run()],
          'has_more': false,
        });
      }
      if (incoming.method == 'GET' &&
          incoming.url.path ==
              '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
        return _json({
          'conversation_id': 'conversation-001',
          'run_id': 'run-001',
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      if (incoming.method == 'POST' &&
          incoming.url.path ==
              '/api/v1/conversations/conversation-001/runs/run-001/'
                  'runner-execution-boundary/preview') {
        expect(incoming.headers['authorization'], 'Bearer boundary-token');
        expect(
          ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(
            jsonDecode(incoming.body),
          ).toJson(),
          request.toJson(),
        );
        return _json(_response(request).toJson());
      }
      throw StateError(
        'Unexpected Forge request: ${incoming.method} ${incoming.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          runnerExecutionBoundaryRequest: request,
          runnerExecutionBoundaryCandidateApiOrigin:
              'https://candidate.example',
          enableRunnerExecutionBoundaryCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Runner execution boundary preview'), findsOneWidget);
    expect(find.text('fence-a'), findsNothing);
    expect(
      requests.where(
        (value) => value.url.path.endsWith('runner-execution-boundary/preview'),
      ),
      hasLength(1),
    );
  });

  testWidgets(
    'selected Web App and Mobile instances bind execution boundary to resources',
    (tester) async {
      for (final clientKind in const ['web', 'app', 'mobile']) {
        final request = _request();
        final store = await _credentialStore('boundary-$clientKind-token');
        final pair = _clientInstancePair(clientKind);
        final requests = <http.Request>[];
        final client = _boundaryClient(
          request: request,
          token: 'boundary-$clientKind-token',
          requests: requests,
        );
        addTearDown(client.close);

        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsGate(
              credentialStore: store,
              httpClient: client,
              initialClientInstanceID: 'client-$clientKind-001',
              clientInstanceSessionResourceConvergenceOwner: _owner,
              clientInstanceSessionResourceConvergenceReader: (_) async => pair,
              runnerExecutionBoundaryRequest: request,
              runnerExecutionBoundaryCandidateApiOrigin:
                  'https://candidate.example',
              enableRunnerExecutionBoundaryCandidate: true,
            ),
          ),
        );
        await _settle(tester);

        expect(
          requests.where(
            (value) =>
                value.url.path.endsWith('runner-execution-boundary/preview'),
          ),
          hasLength(1),
          reason: clientKind,
        );
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
      }
    },
  );

  testWidgets(
    'selected mobile instance rejects a foreign boundary target before POST',
    (tester) async {
      final request = _request(targetID: 'runner-foreign');
      final store = await _credentialStore('foreign-boundary-token');
      final requests = <http.Request>[];
      final client = _boundaryClient(
        request: request,
        token: 'foreign-boundary-token',
        requests: requests,
      );
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-mobile-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async =>
                _clientInstancePair('mobile'),
            runnerExecutionBoundaryRequest: request,
            runnerExecutionBoundaryCandidateApiOrigin:
                'https://candidate.example',
            enableRunnerExecutionBoundaryCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(
        requests.where(
          (value) =>
              value.url.path.endsWith('runner-execution-boundary/preview'),
        ),
        isEmpty,
      );
      expect(find.text('Runner execution boundary preview'), findsNothing);
    },
  );

  testWidgets(
    'selected mobile resource drift revokes execution boundary before POST',
    (tester) async {
      final request = _request();
      final store = await _credentialStore('drift-boundary-token');
      final requests = <http.Request>[];
      var pairReads = 0;
      final client = _boundaryClient(
        request: request,
        token: 'drift-boundary-token',
        requests: requests,
      );
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-mobile-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async {
              pairReads++;
              return _clientInstancePair(
                'mobile',
                sessionIDs: pairReads == 1
                    ? const ['conversation-001']
                    : const [],
              );
            },
            runnerExecutionBoundaryRequest: request,
            runnerExecutionBoundaryCandidateApiOrigin:
                'https://candidate.example',
            enableRunnerExecutionBoundaryCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(pairReads, greaterThanOrEqualTo(2));
      expect(
        requests.where(
          (value) =>
              value.url.path.endsWith('runner-execution-boundary/preview'),
        ),
        isEmpty,
      );
      expect(find.text('Runner execution boundary preview'), findsNothing);
    },
  );

  testWidgets('default Gate keeps execution boundary request-free', (
    tester,
  ) async {
    final store = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted candidate: $request');
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          runnerExecutionBoundaryRequest: _request(),
        ),
      ),
    );
    await _settle(tester);
    expect(
      requests.where(
        (request) =>
            request.url.path.endsWith('runner-execution-boundary/preview'),
      ),
      isEmpty,
    );
  });

  testWidgets('boundary card keeps proof material out of display', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeRunnerExecutionBoundaryCard(
            observation: _response(_request()),
          ),
        ),
      ),
    );
    expect(find.text('runner-a'), findsOneWidget);
    expect(find.text('fence-a'), findsNothing);
    expect(find.textContaining('Preview only'), findsOneWidget);
  });
}

ForgeRunnerExecutionBoundaryPreviewRequest _request({
  String targetID = 'runner-a',
}) {
  const digest =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return ForgeRunnerExecutionBoundaryPreviewRequest(
    owner: _owner,
    conversationID: 'conversation-001',
    runID: 'run-001',
    attemptID: 'attempt-001',
    attemptState: 'accepted',
    command: ForgeRunnerExecutionCommand(
      version: 1,
      commandID: 'command-001',
      leaseProof: ForgeRunnerExecutionLeaseProof(
        attemptID: 'attempt-001',
        targetID: targetID,
        epoch: 1,
        fencingToken: 'fence-a',
      ),
      idempotencyKey: 'run-001:attempt-001:command-001',
      workspaceRef: 'workspace-001',
      argv: ['forge-task', '--prompt-ref', 'prompt-001'],
      timeoutMS: 5000,
      maxOutputBytes: 65536,
    ),
    transport: ForgeRunnerTransportObservation(
      method: 'POST',
      path: '/api/v1/runners/$targetID/dispatch',
      timestamp: 300,
      nonce: 'nonce-a',
      payloadSHA256: digest,
      payloadBytes: 256,
      replayChecked: true,
    ),
    expectedPayloadSHA256: digest,
    effectState: 'not_started',
    cancellationRequested: false,
  );
}

http.Client _boundaryClient({
  required ForgeRunnerExecutionBoundaryPreviewRequest request,
  required String token,
  required List<http.Request> requests,
}) => MockClient((incoming) async {
  requests.add(incoming);
  if (incoming.method == 'GET' &&
      incoming.url.path == '/api/v1/conversations') {
    return _json({
      'conversations': [_conversation()],
      'has_more': false,
    });
  }
  if (incoming.method == 'GET' &&
      incoming.url.path == '/api/v1/conversations/conversation-001/prompts') {
    return _json({
      'conversation_id': 'conversation-001',
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (incoming.method == 'GET' &&
      incoming.url.path == '/api/v1/conversations/conversation-001/runs') {
    return _json({
      'conversation_id': 'conversation-001',
      'runs': [_run()],
      'has_more': false,
    });
  }
  if (incoming.method == 'GET' &&
      incoming.url.path ==
          '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
    return _json({
      'conversation_id': 'conversation-001',
      'run_id': 'run-001',
      'after_sequence': 0,
      'scanned_through_sequence': 0,
      'has_more': false,
      'events': <Object>[],
    });
  }
  if (incoming.method == 'POST' &&
      incoming.url.path ==
          '/api/v1/conversations/conversation-001/runs/run-001/'
              'runner-execution-boundary/preview') {
    expect(incoming.headers['authorization'], 'Bearer $token');
    expect(
      ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(
        jsonDecode(incoming.body),
      ).toJson(),
      request.toJson(),
    );
    return _json(_response(request).toJson());
  }
  throw StateError(
    'Unexpected Forge request: ${incoming.method} ${incoming.url}',
  );
});

ForgeClientInstanceSessionResourceConvergence _clientInstancePair(
  String clientKind, {
  List<String> sessionIDs = const ['conversation-001'],
}) => ForgeClientInstanceSessionResourceConvergence.fromJson({
  'schema_version': 'forge.client-instance-session-resource-convergence/v1',
  'evaluation_mode':
      'owner_bound_client_instance_session_resource_convergence_only',
  'session_view': {
    'schema_version': 'forge.client-instance-session-view/v1',
    'evaluation_mode': 'owner_bound_session_view_only',
    'owner_declaration': _owner.toJson(),
    'owner_declaration_unverified': true,
    'instances': [
      {
        'instance_id': 'client-$clientKind-001',
        'client_kind': clientKind,
        'session_ids': sessionIDs,
        'observed_at_ms': 200500,
        'status': 'active',
      },
    ],
    'read_only': true,
    'authority': _offlineAuthority(),
  },
  'resource_view': {
    'schema_version': 'forge.client-instance-resource-view/v1',
    'evaluation_mode': 'owner_bound_instance_resource_view_only',
    'owner_declaration': _owner.toJson(),
    'owner_declaration_unverified': true,
    'instances': [
      {
        'instance_id': 'client-$clientKind-001',
        'client_kind': clientKind,
        'session_ids': sessionIDs,
        'observed_at_ms': 200500,
        'status': 'active',
      },
    ],
    'devices': [
      {
        'device_id': 'device-a',
        'runner_instance_id': 'runner-a',
        'owner': _owner.toJson(),
        'revision': 1,
        'generation': 1,
        'heartbeat_sequence': 1,
        'observed_at_ms': 200500,
        'approval_state': 'approved',
        'cordon_state': 'clear',
        'reservation_state': 'none',
        'liveness': 'online',
        'os': 'linux',
        'architecture': 'amd64',
        'cpu_cores': 4,
        'available_cpu_cores': 4,
        'memory_bytes': 8192,
        'available_memory_bytes': 8192,
        'storage_bytes': 65536,
        'available_storage_bytes': 65536,
        'gpu_count': 0,
        'available_gpu_memory_bytes': 0,
      },
    ],
    'device_attributes_unverified': true,
    'read_only': true,
    'authority': _offlineAuthority(),
  },
  'converged': true,
  'read_only': true,
  'authority': {
    'owner_authenticated': false,
    'session_read_authorized': false,
    'prompt_write_authorized': false,
    'device_identity_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
});

Map<String, dynamic> _offlineAuthority() => {
  'owner_authenticated': false,
  'session_read_authorized': false,
  'prompt_write_authorized': false,
  'device_identity_verified': false,
  'reservation_created': false,
  'execution_authorized': false,
  'dispatch_performed': false,
  'audit_published': false,
};

ForgeRunnerExecutionBoundaryObservation _response(
  ForgeRunnerExecutionBoundaryPreviewRequest request,
) => ForgeRunnerExecutionBoundaryObservation.fromJson({
  'schema_version': ForgeRunnerExecutionBoundaryObservation.schema,
  'evaluation_mode': ForgeRunnerExecutionBoundaryObservation.evaluationMode,
  'mode': 'execute',
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'attempt_id': request.attemptID,
  'attempt_state': request.attemptState,
  'command_id': request.command.commandID,
  'command_sha256': request.command.commandSHA256(),
  'target_id': request.command.leaseProof.targetID,
  'lease_epoch': request.command.leaseProof.epoch,
  'activation_allowed': true,
  'runner_authority_accepted': true,
  'dispatch_admission_ready': true,
  'transport_admission_ready': true,
  'effect_state': request.effectState,
  'effect_state_startable': true,
  'cancellation_clear': true,
  'execution_boundary_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'device_identity_verified': false,
    'command_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
});

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Boundary test',
    'created_at_ms': 100,
    'updated_at_ms': 100,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run() => {
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 200,
  'latest_sequence': 5,
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

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
