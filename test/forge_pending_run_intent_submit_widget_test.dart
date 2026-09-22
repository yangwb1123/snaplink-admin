import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_pending_run_intent_submission_card.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _owned() => {
  'conversation': {
    'id': 'conversation-1',
    'scope': {'kind': 'global'},
    'title': 'Shared work',
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _submission({String content = 'compute this'}) {
  final intent = {
    'intent_id': 'intent-1',
    'conversation_id': 'conversation-1',
    'prompt_id': 'prompt-1',
    'project_id': 'project-1',
    'profile_id': 'profile-1',
    'submitted_at_ms': 200,
    'aggregate_version': 2,
    'latest_sequence': 1,
    'status': 'pending',
  };
  return {
    'prompt': {
      'id': 'prompt-1',
      'conversation_id': 'conversation-1',
      'role': 'user',
      'content': content,
      'created_at_ms': 200,
    },
    'intent': intent,
    'initial_event': {
      'event_id': 'event-1',
      'seq': 1,
      'emitted_at_ms': 200,
      'type': 'submitted',
    },
    'replayed': false,
  };
}

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<ForgeCredentialStore> _store(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

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

  setUp(BrowserNavigation.resetForTest);
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('explicit submitter creates a visible inert review receipt', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned()],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/prompts')) {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/runs')) {
        return _json({
          'conversation_id': 'conversation-1',
          'runs': <Object>[],
          'has_more': false,
        });
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    addTearDown(client.close);

    ForgePendingRunIntentSubmission? received;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'screen-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          pendingRunIntentOwner: _owner,
          pendingRunIntentSubmitter:
              ({
                required owner,
                required conversationID,
                required content,
                required expectedVersion,
                required idempotencyKey,
              }) async {
                expect(owner, _owner);
                expect(conversationID, 'conversation-1');
                expect(content, 'compute this');
                expect(expectedVersion, 1);
                expect(idempotencyKey, isNotEmpty);
                received = ForgePendingRunIntentSubmission.fromJson(
                  _submission(content: content),
                );
                return received!;
              },
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('forge-request-scheduling-review')),
      findsOneWidget,
    );
    final promptField = find.byType(TextField).last;
    await tester.enterText(promptField, 'compute this');
    await tester.tap(
      find.byKey(const ValueKey('forge-request-scheduling-review')),
    );
    await _pump(tester);

    expect(received, isNotNull);
    for (var index = 0; index < 5; index++) {
      if (find
          .byType(ForgePendingRunIntentSubmissionCard)
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pump();
    }
    expect(
      find.byKey(const ValueKey('forge-pending-run-intent-submission-card')),
      findsOneWidget,
    );
    expect(find.text('Scheduling review requested'), findsOneWidget);
    expect(find.text('offline · all execution flags false'), findsOneWidget);
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('default Gate has no scheduling-review action or POST', (
    tester,
  ) async {
    final store = await _store('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted a candidate route.');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          pendingRunIntentOwner: _owner,
          pendingRunIntentCandidateApiOrigin: 'https://candidate.example',
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('forge-request-scheduling-review')),
      findsNothing,
    );
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
  });

  testWidgets('explicit Gate candidate binds owner/origin and sends one POST', (
    tester,
  ) async {
    final store = await _store('candidate-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned()],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/prompts')) {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/runs')) {
        return _json({
          'conversation_id': 'conversation-1',
          'runs': <Object>[],
          'has_more': false,
        });
      }
      if (request.url.path ==
          '/api/v1/conversations/conversation-1/run-intents') {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer candidate-token');
        expect(jsonDecode(request.body), {
          'content': 'compute this',
          'expected_version': 1,
        });
        return _json(_submission(), status: 201);
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          pendingRunIntentOwner: _owner,
          pendingRunIntentCandidateApiOrigin: 'https://candidate.example',
          enablePendingRunIntentCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    await tester.enterText(find.byType(TextField).last, 'compute this');
    await tester.tap(
      find.byKey(const ValueKey('forge-request-scheduling-review')),
    );
    await _pump(tester);

    for (var index = 0; index < 5; index++) {
      if (find
          .byType(ForgePendingRunIntentSubmissionCard)
          .evaluate()
          .isNotEmpty) {
        break;
      }
      await tester.drag(find.byType(ListView).first, const Offset(0, -800));
      await tester.pump();
    }
    expect(
      requests.where(
        (request) =>
            request.url.path ==
            '/api/v1/conversations/conversation-1/run-intents',
      ),
      hasLength(1),
    );
    expect(
      find.byKey(const ValueKey('forge-pending-run-intent-submission-card')),
      findsOneWidget,
    );
  });

  testWidgets('candidate flag without owner or origin remains request-free', (
    tester,
  ) async {
    final store = await _store('missing-binding-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Unbound candidate issued a request.');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          enablePendingRunIntentCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('forge-request-scheduling-review')),
      findsNothing,
    );
    expect(requests.where((request) => request.method == 'POST'), isEmpty);
  });
}
