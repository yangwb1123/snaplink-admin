import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_dispatch_admission.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/screens/forge/forge_runner_dispatch_admission_card.dart';
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

  testWidgets('explicit Gate posts one admission preview', (tester) async {
    final request = _request();
    final store = await _credentialStore('admission-token');
    final requests = <http.Request>[];
    final client = MockClient((http.Request httpRequest) async {
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
              '/api/v1/conversations/conversation-001/runs/run-001/runner-dispatch-admission/preview') {
        expect(httpRequest.headers['authorization'], 'Bearer admission-token');
        expect(
          ForgeRunnerDispatchAdmissionRequest.fromJson(
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
          runnerDispatchAdmissionRequest: request,
          runnerDispatchAdmissionCandidateApiOrigin:
              'https://candidate.example',
          enableRunnerDispatchAdmissionCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('Runner dispatch admission preview'), findsOneWidget);
    expect(find.textContaining('fencing token'), findsOneWidget);
    expect(
      requests.where(
        (value) => value.url.path.endsWith('runner-dispatch-admission/preview'),
      ),
      hasLength(1),
    );
  });

  testWidgets('default Gate keeps admission request-free', (tester) async {
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
          runnerDispatchAdmissionRequest: _request(),
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path.endsWith('runner-dispatch-admission/preview'),
      ),
      isEmpty,
    );
  });

  testWidgets('admission card does not expose the fencing token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeRunnerDispatchAdmissionCard(
            admission: _response(_request()),
          ),
        ),
      ),
    );
    expect(find.text('runner-a'), findsOneWidget);
    expect(find.text('fence-a'), findsNothing);
    expect(find.textContaining('fencing token'), findsOneWidget);
  });
}

ForgeRunnerDispatchAdmissionRequest _request() {
  final command = ForgeRunnerExecutionCommand(
    version: 1,
    commandID: 'command-001',
    leaseProof: const ForgeRunnerExecutionLeaseProof(
      attemptID: 'attempt-001',
      targetID: 'runner-a',
      epoch: 1,
      fencingToken: 'fence-a',
    ),
    idempotencyKey: 'run-001:attempt-001:command-001',
    workspaceRef: 'workspace-001',
    argv: const ['forge-task', '--prompt-ref', 'prompt-001'],
    timeoutMS: 5000,
    maxOutputBytes: 65536,
  );
  return ForgeRunnerDispatchAdmissionRequest(
    owner: _owner,
    conversationID: 'conversation-001',
    runID: 'run-001',
    attemptID: 'attempt-001',
    attemptState: 'accepted',
    command: command,
    evaluatedAtMS: 300,
  );
}

ForgeRunnerDispatchAdmission _response(
  ForgeRunnerDispatchAdmissionRequest request,
) => ForgeRunnerDispatchAdmission(
  schemaVersion: ForgeRunnerDispatchAdmission.schema,
  mode: ForgeRunnerDispatchAdmission.evaluationMode,
  owner: request.owner,
  conversationID: request.conversationID,
  runID: request.runID,
  attemptID: request.attemptID,
  attemptState: request.attemptState,
  attemptStateAdmissible: true,
  commandID: request.command.commandID,
  commandSHA256: request.command.commandSHA256(),
  targetID: request.command.leaseProof.targetID,
  leaseEpoch: request.command.leaseProof.epoch,
  leaseIssuedAtMS: 100,
  leaseExpiresAtMS: 1000,
  evaluatedAtMS: request.evaluatedAtMS,
  leaseProofCurrent: true,
  leaseActive: true,
  commandBindingValid: true,
  admissionReady: true,
  rejectionReasons: const [],
  previewOnly: true,
  authority: const ForgeRunnerDispatchAdmissionAuthority(
    deviceIdentityVerified: false,
    reservationCreated: false,
    executionAuthorized: false,
    dispatchPerformed: false,
    auditPublished: false,
  ),
);

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Admission test',
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
