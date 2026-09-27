import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';
import 'package:sso_admin/screens/forge/forge_runner_transport_admission_card.dart';
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

  testWidgets('explicit Gate posts one transport admission preview', (
    tester,
  ) async {
    final request = _request();
    final store = await _credentialStore('transport-token');
    final requests = <http.Request>[];
    final client = MockClient((httpRequest) async {
      requests.add(httpRequest);
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation()],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/conversation-001/prompts') {
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/conversation-001/runs') {
        return _json({
          'conversation_id': 'conversation-001',
          'runs': [_run()],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
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
      if (httpRequest.method == 'POST' &&
          httpRequest.url.path ==
              '/api/v1/conversations/conversation-001/runs/run-001/'
                  'runner-transport-admission/preview') {
        expect(httpRequest.headers['authorization'], 'Bearer transport-token');
        expect(
          ForgeRunnerTransportAdmissionRequest.fromJson(
            jsonDecode(httpRequest.body),
          ).toJson(),
          request.toJson(),
        );
        return _json(_response(request).toJson());
      }
      throw StateError(
        'Unexpected Forge request: ${httpRequest.method} ${httpRequest.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          runnerTransportAdmissionRequest: request,
          runnerTransportAdmissionCandidateApiOrigin:
              'https://candidate.example',
          enableRunnerTransportAdmissionCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Runner transport admission preview'), findsOneWidget);
    expect(find.text('fence-a'), findsNothing);
    expect(
      requests.where(
        (value) =>
            value.url.path.endsWith('runner-transport-admission/preview'),
      ),
      hasLength(1),
    );
  });

  testWidgets('default Gate keeps transport admission request-free', (
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
          runnerTransportAdmissionRequest: _request(),
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path.endsWith('runner-transport-admission/preview'),
      ),
      isEmpty,
    );
  });

  testWidgets('transport card keeps proof material out of display', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeRunnerTransportAdmissionCard(
            admission: _response(_request()),
          ),
        ),
      ),
    );
    expect(find.text('runner-a'), findsOneWidget);
    expect(find.text('fence-a'), findsNothing);
    expect(find.textContaining('payload'), findsWidgets);
  });
}

ForgeRunnerTransportAdmissionRequest _request() {
  const digest =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return const ForgeRunnerTransportAdmissionRequest(
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
        targetID: 'runner-a',
        epoch: 1,
        fencingToken: 'fence-a',
      ),
      idempotencyKey: 'run-001:attempt-001:command-001',
      workspaceRef: 'workspace-001',
      argv: ['forge-task', '--prompt-ref', 'prompt-001'],
      timeoutMS: 5000,
      maxOutputBytes: 65536,
    ),
    lease: ForgeRunnerTransportLease(
      targetID: 'runner-a',
      epoch: 1,
      issuedAtMS: 100,
      expiresAtMS: 1000,
      current: true,
      active: true,
    ),
    transport: ForgeRunnerTransportObservation(
      method: 'POST',
      path: '/api/v1/runners/runner-a/dispatch',
      timestamp: 300,
      nonce: 'nonce-a',
      payloadSHA256: digest,
      payloadBytes: 256,
      replayChecked: true,
    ),
    expectedPayloadSHA256: digest,
    evaluatedAtMS: 300,
  );
}

ForgeRunnerTransportAdmission _response(
  ForgeRunnerTransportAdmissionRequest request,
) => ForgeRunnerTransportAdmission.fromJson({
  'schema_version': ForgeRunnerTransportAdmission.schema,
  'evaluation_mode': ForgeRunnerTransportAdmission.evaluationMode,
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'attempt_id': request.attemptID,
  'attempt_state': request.attemptState,
  'attempt_state_admissible': true,
  'command_id': request.command.commandID,
  'command_sha256': request.command.commandSHA256(),
  'target_id': request.command.leaseProof.targetID,
  'lease_epoch': request.lease.epoch,
  'lease_issued_at_ms': request.lease.issuedAtMS,
  'lease_expires_at_ms': request.lease.expiresAtMS,
  'evaluated_at_ms': request.evaluatedAtMS,
  'transport_method': request.transport.method,
  'transport_path': request.transport.path,
  'transport_timestamp': request.transport.timestamp,
  'transport_nonce': request.transport.nonce,
  'transport_payload_sha256': request.transport.payloadSHA256,
  'transport_payload_bytes': request.transport.payloadBytes,
  'transport_replay_checked': request.transport.replayChecked,
  'lease_proof_current': true,
  'lease_active': true,
  'command_binding_valid': true,
  'transport_binding_valid': true,
  'admission_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'device_identity_verified': false,
    'transport_authenticated': false,
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
    'title': 'Transport admission test',
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

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}
