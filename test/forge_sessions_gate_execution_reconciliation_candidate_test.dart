import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

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

  testWidgets('explicit Gate candidate reads one bound reconciliation preview', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('candidate-token');
    final input = _input();
    final expected = observeForgeExecutionReconciliation(input);
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
            'runs': [_run()],
            'has_more': false,
          });
        case 'GET /api/v1/conversations/conversation-001/runs/run-001/timeline':
          return _json({
            'conversation_id': 'conversation-001',
            'run_id': 'run-001',
            'after_sequence': 0,
            'scanned_through_sequence': 1,
            'has_more': false,
            'events': <Object>[],
          });
        case 'POST /api/v1/conversations/conversation-001/runs/run-001/execution-reconciliation/preview':
          expect(request.headers['authorization'], 'Bearer candidate-token');
          expect(jsonDecode(request.body), input.toJson());
          return _json(expected.toJson());
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
          credentialStore: credentialStore,
          httpClient: client,
          executionReconciliationInput: input,
          enableExecutionReconciliationCandidate: true,
          executionReconciliationCandidateApiOrigin:
              'https://candidate.example',
        ),
      ),
    );
    await _settle(tester);

    await tester.scrollUntilVisible(
      find.text('Execution reconciliation preview'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Execution reconciliation preview'), findsOneWidget);
    final reconciliationRequests = requests
        .where(
          (request) => request.url.path.contains('execution-reconciliation'),
        )
        .toList();
    expect(reconciliationRequests, hasLength(1));
    expect(reconciliationRequests.single.method, 'POST');
  });

  testWidgets('candidate flag stays request-free without a typed input', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('disabled-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Candidate route must remain disabled: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          enableExecutionReconciliationCandidate: true,
          executionReconciliationCandidateApiOrigin:
              'https://candidate.example',
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (request) => request.url.path.contains('execution-reconciliation'),
      ),
      isEmpty,
    );
  });
}

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
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

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Shared work',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run() => {
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 10,
  'latest_sequence': 1,
  'status': 'nonterminal',
};

ForgeExecutionReconciliationInput _input() =>
    ForgeExecutionReconciliationInput.fromJson({
      'owner': _owner.toJson(),
      'conversation_id': 'conversation-001',
      'run_id': 'run-001',
      'attempt_id': 'attempt-001',
      'command_id': 'command-001',
      'target_id': 'runner-1',
      'run_status': 'nonterminal',
      'attempt_state': 'running',
      'lease': {
        'v': 1,
        'attempt_id': 'attempt-001',
        'target_id': 'runner-1',
        'epoch': 1,
        'fencing_token': 'fence-001',
        'issued_at_ms': 100,
        'expires_at_ms': 10100,
      },
      'observed_at_ms': 200,
      'terminal': null,
    });
