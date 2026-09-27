import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';
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

  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];

  testWidgets(
    'explicit Gate reads one selected Run receipt-history preview',
    (tester) async {
      final history = ForgeSessionRunnerReceiptHistory.fromJson(_fixture());
      final store = await _credentialStore('history-token');
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
          case 'POST /api/v1/conversations/conversation-001/runs/run-001/runner-receipt-history/preview':
            expect(request.headers['authorization'], 'Bearer history-token');
            expect(jsonDecode(request.body), history.toJson());
            return _json(history.toJson());
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
            sessionRunnerReceiptHistoryRequest: history,
            sessionRunnerReceiptHistoryCandidateApiOrigin:
                'https://candidate.example',
            enableSessionRunnerReceiptHistoryCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-history-panel'),
        ),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-history-summary'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'forge-session-runner-receipt-history-manual-reconciliation',
          ),
        ),
        findsOneWidget,
      );
      expect(
        requests.where(
          (request) =>
              request.url.path.endsWith('runner-receipt-history/preview'),
        ),
        hasLength(1),
      );
    },
    skip: fixturePath == null,
  );

  testWidgets(
    'default Gate keeps receipt-history preview request-free',
    (tester) async {
      final history = ForgeSessionRunnerReceiptHistory.fromJson(_fixture());
      final store = await _credentialStore('default-history-token');
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        throw StateError('History candidate contacted: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            sessionRunnerReceiptHistoryRequest: history,
          ),
        ),
      );
      await _settle(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path.endsWith('runner-receipt-history/preview'),
        ),
        isEmpty,
      );
    },
    skip: fixturePath == null,
  );
}

Map<String, dynamic> _fixture() {
  final path =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];
  if (path == null) throw StateError('fixture path is required');
  return Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
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

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Receipt history test',
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

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);
