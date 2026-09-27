import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
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

  testWidgets('explicit Gate renders the scoped local boundary projection', (
    tester,
  ) async {
    final observation = ForgeRunnerAttemptBoundaryObservation.fromJson(
      _fixture(),
    );
    final requests = <http.Request>[];
    final client = _sessionClient(requests);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: await _credentialStore('attempt-token'),
          httpClient: client,
          runnerAttemptBoundaryPreview: observation,
          runnerAttemptBoundaryScope: _scope(),
          enableRunnerAttemptBoundaryProjection: true,
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-import-card')),
      findsOneWidget,
    );
    expect(find.textContaining('accepted → starting'), findsOneWidget);
    expect(requests.where((request) => request.method != 'GET'), isEmpty);
  });

  testWidgets('default Gate keeps the boundary projection closed', (
    tester,
  ) async {
    var readerCalls = 0;
    final requests = <http.Request>[];
    final client = _sessionClient(requests, empty: true);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: await _credentialStore('default-token'),
          httpClient: client,
          runnerAttemptBoundaryPreview:
              ForgeRunnerAttemptBoundaryObservation.fromJson(_fixture()),
          runnerAttemptBoundaryScope: _scope(),
          runnerAttemptBoundaryFileReader: () async {
            readerCalls++;
            return jsonEncode(_fixture());
          },
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-import-card')),
      findsNothing,
    );
    expect(readerCalls, 0);
    expect(requests.where((request) => request.method != 'GET'), isEmpty);
  });

  testWidgets('import rejects scope drift and clears the old projection', (
    tester,
  ) async {
    var source = jsonEncode(_fixture());
    final client = _sessionClient(<http.Request>[]);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'local-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          runnerAttemptBoundaryScope: _scope(),
          runnerAttemptBoundaryFileReader: () async => source,
          enableRunnerAttemptBoundaryProjection: true,
        ),
      ),
    );
    await _settle(tester);

    await tester.tap(
      find.byKey(const ValueKey('forge-import-runner-attempt-boundary')),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
      findsOneWidget,
    );

    final drifted = _fixture()..['run_id'] = 'run-other';
    source = jsonEncode(drifted);
    await tester.tap(
      find.byKey(const ValueKey('forge-import-runner-attempt-boundary')),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
      findsNothing,
    );
    expect(
      find.text('Invalid or stale Runner Attempt boundary projection.'),
      findsOneWidget,
    );
  });
}

ForgeRunnerAttemptBoundaryScope _scope() =>
    const ForgeRunnerAttemptBoundaryScope(
      owner: _owner,
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
    );

Map<String, dynamic> _fixture() => {
  'schema_version': forgeRunnerAttemptBoundarySchema,
  'evaluation_mode': forgeRunnerAttemptBoundaryEvaluationMode,
  'owner': _owner.toJson(),
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'attempt_id': 'attempt-1',
  'command_id': 'command-1',
  'target_id': 'runner-1',
  'lease_epoch': 1,
  'current_attempt_state': 'accepted',
  'next_attempt_state': 'starting',
  'transition': 'begin_starting',
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

MockClient _sessionClient(
  List<http.Request> requests, {
  bool empty = false,
}) => MockClient((request) async {
  requests.add(request);
  if (request.method == 'GET' && request.url.path == '/api/v1/conversations') {
    return _json(
      empty
          ? {'conversations': <Object>[], 'has_more': false}
          : {
              'conversations': [_conversation()],
              'has_more': false,
            },
    );
  }
  if (empty) throw StateError('Unexpected request in empty session: $request');
  if (request.url.path == '/api/v1/conversations/conversation-1/prompts') {
    return _json({
      'conversation_id': 'conversation-1',
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (request.url.path == '/api/v1/conversations/conversation-1/runs') {
    return _json({
      'conversation_id': 'conversation-1',
      'runs': [_run()],
      'has_more': false,
    });
  }
  if (request.url.path ==
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
  throw StateError('Unexpected session request: $request');
});

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
