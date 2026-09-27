import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_resource_convergence.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';
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

  testWidgets('opt-in Gate posts one Attempt boundary preview', (tester) async {
    final request = _request();
    final requests = <http.Request>[];
    final client = _client(requests, request: request);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: await _credentialStore('attempt-token'),
          httpClient: client,
          runnerAttemptBoundaryRequest: request,
          runnerAttemptBoundaryCandidateApiOrigin: 'https://candidate.example',
          enableRunnerAttemptBoundaryCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
      findsOneWidget,
    );
    expect(find.textContaining('accepted → starting'), findsOneWidget);
    expect(find.text('fence-1'), findsNothing);
    expect(
      requests.where(
        (value) => value.url.path.endsWith('runner-attempt-boundary/preview'),
      ),
      hasLength(1),
    );
  });

  testWidgets('default Gate keeps Attempt boundary request-free', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = _client(requests, empty: true);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: await _credentialStore('default-token'),
          httpClient: client,
          runnerAttemptBoundaryRequest: _request(),
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (value) => value.url.path.endsWith('runner-attempt-boundary/preview'),
      ),
      isEmpty,
    );
  });

  testWidgets(
    'Attempt boundary candidate refreshes the selected client-instance pair',
    (tester) async {
      final request = _request(targetID: 'runner-a');
      final requests = <http.Request>[];
      var pairReads = 0;
      final client = _client(requests, request: request);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: await _credentialStore('attempt-pair-token'),
            httpClient: client,
            initialConversationID: 'conversation-1',
            initialClientInstanceID: 'client-cli-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async {
              pairReads++;
              return _attemptClientInstancePair();
            },
            runnerAttemptBoundaryRequest: request,
            runnerAttemptBoundaryCandidateApiOrigin:
                'https://candidate.example',
            enableRunnerAttemptBoundaryCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(pairReads, greaterThan(0));
      expect(
        requests.where(
          (value) => value.url.path.endsWith('runner-attempt-boundary/preview'),
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'Attempt boundary blocks a foreign target before the candidate POST',
    (tester) async {
      final request = _request(targetID: 'runner-foreign');
      final requests = <http.Request>[];
      var posts = 0;
      final client = _client(requests, request: request);
      final store = await _credentialStore('attempt-resource-token');
      addTearDown(store.clear);
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-1',
            initialClientInstanceID: 'client-cli-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async =>
                _attemptClientInstancePair(),
            deviceInventoryResourceConvergenceOwner: _owner,
            deviceInventoryResourceConvergenceReader: (_) async =>
                _attemptInventoryResourceConvergence(),
            runnerAttemptBoundaryRequest: request,
            runnerAttemptBoundaryCandidateApiOrigin:
                'https://candidate.example',
            enableRunnerAttemptBoundaryCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      posts = requests
          .where(
            (value) =>
                value.url.path.endsWith('runner-attempt-boundary/preview'),
          )
          .length;
      expect(posts, 0);
      expect(
        find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
        findsNothing,
      );
    },
  );
}

ForgeClientInstanceSessionResourceConvergence _attemptClientInstancePair() {
  final source = File(
    'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json',
  ).readAsStringSync();
  return ForgeClientInstanceSessionResourceConvergence.fromJsonText(
    source
        .replaceAll('conversation-001', 'conversation-1')
        .replaceAll('conversation-002', 'conversation-2'),
  );
}

ForgeDeviceInventoryResourceConvergence _attemptInventoryResourceConvergence() {
  return ForgeDeviceInventoryResourceConvergence.fromJsonText(
    File(
      'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
    ).readAsStringSync(),
  );
}

MockClient _client(
  List<http.Request> requests, {
  ForgeRunnerAttemptBoundaryPreviewRequest? request,
  bool empty = false,
}) => MockClient((incoming) async {
  requests.add(incoming);
  if (incoming.method == 'GET' &&
      incoming.url.path == '/api/v1/conversations') {
    return _json(
      empty
          ? {'conversations': <Object>[], 'has_more': false}
          : {
              'conversations': [_conversation()],
              'has_more': false,
            },
    );
  }
  if (empty) throw StateError('Unexpected default Gate request: $incoming');
  if (incoming.method == 'GET' &&
      incoming.url.path == '/api/v1/conversations/conversation-1/prompts') {
    return _json({
      'conversation_id': 'conversation-1',
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (incoming.method == 'GET' &&
      incoming.url.path == '/api/v1/conversations/conversation-1/runs') {
    return _json({
      'conversation_id': 'conversation-1',
      'runs': [_run()],
      'has_more': false,
    });
  }
  if (incoming.method == 'GET' &&
      incoming.url.path ==
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
  if (incoming.method == 'POST' &&
      incoming.url.path ==
          '/api/v1/conversations/conversation-1/runs/run-1/'
              'runner-attempt-boundary/preview') {
    expect(request, isNotNull);
    final received = ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(
      jsonDecode(incoming.body),
    );
    expect(received.toJson(), request!.toJson());
    return _json(_response(request));
  }
  throw StateError('Unexpected Forge request: $incoming');
});

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

ForgeRunnerAttemptBoundaryPreviewRequest _request({
  String targetID = 'runner-1',
}) {
  const digest =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return ForgeRunnerAttemptBoundaryPreviewRequest(
    executionBoundary: ForgeRunnerExecutionBoundaryPreviewRequest(
      owner: _owner,
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      attemptState: 'accepted',
      command: ForgeRunnerExecutionCommand(
        version: 1,
        commandID: 'command-1',
        leaseProof: ForgeRunnerExecutionLeaseProof(
          attemptID: 'attempt-1',
          targetID: targetID,
          epoch: 1,
          fencingToken: 'fence-1',
        ),
        idempotencyKey: 'run-1:attempt-1:command-1',
        workspaceRef: 'workspace-1',
        argv: ['forge-task', '--prompt-ref', 'prompt-1'],
        timeoutMS: 5000,
        maxOutputBytes: 65536,
      ),
      transport: ForgeRunnerTransportObservation(
        method: 'POST',
        path: '/api/v1/runners/$targetID/dispatch',
        timestamp: 300,
        nonce: 'nonce-1',
        payloadSHA256: digest,
        payloadBytes: 256,
        replayChecked: true,
      ),
      expectedPayloadSHA256: digest,
      effectState: 'not_started',
      cancellationRequested: false,
    ),
    transition: 'begin_starting',
  );
}

Map<String, dynamic> _response(
  ForgeRunnerAttemptBoundaryPreviewRequest request,
) => {
  'schema_version': ForgeRunnerAttemptBoundaryObservation.schema,
  'evaluation_mode': ForgeRunnerAttemptBoundaryObservation.evaluationMode,
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'attempt_id': request.attemptID,
  'command_id': request.command.commandID,
  'target_id': request.command.leaseProof.targetID,
  'lease_epoch': request.command.leaseProof.epoch,
  'current_attempt_state': request.attemptState,
  'next_attempt_state': 'starting',
  'transition': request.transition,
  'execution_boundary_ready': true,
  'attempt_transition_valid': true,
  'attempt_transition_dispatchable': true,
  'attempt_boundary_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'attempt_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-1',
    'scope': {'kind': 'global'},
    'title': 'Attempt boundary test',
    'created_at_ms': 100,
    'updated_at_ms': 100,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run() => {
  'run_id': 'run-1',
  'prompt_id': 'prompt-1',
  'created_at_ms': 200,
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

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
