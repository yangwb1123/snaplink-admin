import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

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

  testWidgets('explicit Gate posts one Run execution-evidence preview', (
    tester,
  ) async {
    final run = ForgeRunObserved.fromJson(_run());
    final receipt = ForgeSessionRunnerReceiptObservation.fromJson(_receipt());
    final store = await _credentialStore('evidence-token');
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
        case 'POST /api/v1/conversations/conversation-001/runs/run-001/execution-evidence/preview':
          expect(request.headers['authorization'], 'Bearer evidence-token');
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['run_observed'], run.toJson());
          expect(body['session_receipt_observed'], receipt.toJson());
          return _json(_evidence());
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
          runObserved: run,
          sessionRunnerReceiptObservation: receipt,
          runExecutionEvidenceCandidateApiOrigin: 'https://candidate.example',
          enableRunExecutionEvidenceCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    await tester.scrollUntilVisible(
      find.text('Run execution evidence preview'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Run execution evidence preview'), findsOneWidget);
    expect(
      requests.where(
        (request) => request.url.path.endsWith('execution-evidence/preview'),
      ),
      hasLength(1),
    );
  });

  testWidgets('default Gate keeps Run execution evidence request-free', (
    tester,
  ) async {
    final store = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Evidence candidate contacted: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          runObserved: ForgeRunObserved.fromJson(_run()),
          sessionRunnerReceiptObservation:
              ForgeSessionRunnerReceiptObservation.fromJson(_receipt()),
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (request) => request.url.path.endsWith('execution-evidence/preview'),
      ),
      isEmpty,
    );
  });
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

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

Map<String, dynamic> _run() =>
    _readFixture('FORGE_RUN_OBSERVED_CONTRACT_FIXTURE');

Map<String, dynamic> _receipt() =>
    _readFixture('FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE');

Map<String, dynamic> _evidence() =>
    _readFixture('FORGE_RUN_EXECUTION_EVIDENCE_CONTRACT_FIXTURE');

Map<String, dynamic> _readFixture(String variable) {
  final path = Platform.environment[variable];
  if (path == null) throw StateError('$variable is required');
  return Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
}

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Evidence test',
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
