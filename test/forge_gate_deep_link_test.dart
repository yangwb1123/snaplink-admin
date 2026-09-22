import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, Object> _owned(String id, String title, int version) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': title,
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': version,
};

String _credentialRecord() => jsonEncode({
  'version': 1,
  'client_id': ForgeConversationsOAuth.clientId,
  'access_token': 'gate-access',
  'session_id': 'gate-session',
  'refresh_token': 'gate-refresh',
});

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 8; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(BrowserNavigation.resetForTest);
  tearDown(BrowserNavigation.resetForTest);
  setUp(Session.clear);
  tearDown(Session.clear);

  testWidgets(
    're-reads a deep link that changes while credential restore is pending',
    (tester) async {
      final backend = MemoryForgeCredentialBackend()
        ..value = _credentialRecord();
      final restoreBarrier = Completer<void>();
      backend.readBarrier = restoreBarrier.future;
      final credentialStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_owned('conversation-first', 'First page', 1)],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations/conversation-linked') {
          return _json(_owned('conversation-linked', 'Linked work', 4));
        }
        final segments = request.url.pathSegments;
        if (request.method == 'GET' &&
            segments.length == 5 &&
            segments[0] == 'api' &&
            segments[1] == 'v1' &&
            segments[2] == 'conversations' &&
            segments[4] == 'prompts') {
          return _json({
            'conversation_id': segments[3],
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            segments.length == 5 &&
            segments[0] == 'api' &&
            segments[1] == 'v1' &&
            segments[2] == 'conversations' &&
            segments[4] == 'runs') {
          return _json({
            'conversation_id': segments[3],
            'runs': <Object>[],
            'has_more': false,
          });
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });
      addTearDown(client.close);

      BrowserNavigation.replaceState('/forge');
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            initialConversationID: 'conversation-stale',
            httpClient: client,
          ),
        ),
      );
      await tester.pump();

      BrowserNavigation.pushState('/forge/conversations/conversation-linked');
      restoreBarrier.complete();
      await _pumpRequests(tester);

      expect(find.text('Linked work'), findsWidgets);
      expect(find.text('First page'), findsWidgets);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/conversations',
        '/api/v1/conversations/conversation-linked',
        '/api/v1/conversations/conversation-linked/prompts',
        '/api/v1/conversations/conversation-linked/runs',
      ]);
      expect(
        requests
            .where(
              (request) =>
                  request.url.path ==
                  '/api/v1/conversations/conversation-linked',
            )
            .length,
        1,
      );
      expect(
        requests
            .where(
              (request) =>
                  request.url.path.endsWith('/conversation-linked/prompts'),
            )
            .length,
        1,
      );
      expect(
        requests
            .where(
              (request) =>
                  request.url.path.endsWith('/conversation-linked/runs'),
            )
            .length,
        1,
      );
    },
  );

  testWidgets(
    're-reads the Forge root and drops a stale deep-link selection before restore',
    (tester) async {
      final backend = MemoryForgeCredentialBackend()
        ..value = _credentialRecord();
      final restoreBarrier = Completer<void>();
      backend.readBarrier = restoreBarrier.future;
      final credentialStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [
              _owned('conversation-current', 'Current work', 2),
            ],
            'has_more': false,
          });
        }
        final segments = request.url.pathSegments;
        if (request.method == 'GET' &&
            segments.length == 5 &&
            segments[0] == 'api' &&
            segments[1] == 'v1' &&
            segments[2] == 'conversations' &&
            segments[4] == 'prompts') {
          return _json({
            'conversation_id': segments[3],
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            segments.length == 5 &&
            segments[0] == 'api' &&
            segments[1] == 'v1' &&
            segments[2] == 'conversations' &&
            segments[4] == 'runs') {
          return _json({
            'conversation_id': segments[3],
            'runs': <Object>[],
            'has_more': false,
          });
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });
      addTearDown(client.close);

      BrowserNavigation.replaceState('/forge/conversations/conversation-stale');
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            initialConversationID: 'conversation-stale',
            httpClient: client,
          ),
        ),
      );
      await tester.pump();

      BrowserNavigation.replaceState('/forge');
      restoreBarrier.complete();
      await _pumpRequests(tester);

      expect(find.text('Current work'), findsWidgets);
      expect(find.text('conversation-stale'), findsNothing);
      expect(requests.map((request) => request.url.path), [
        '/api/v1/conversations',
        '/api/v1/conversations/conversation-current/prompts',
        '/api/v1/conversations/conversation-current/runs',
      ]);
      expect(
        requests.any(
          (request) => request.url.path.contains('conversation-stale'),
        ),
        isFalse,
      );
      expect(
        requests
            .where(
              (request) =>
                  request.url.path.endsWith('/conversation-current/prompts'),
            )
            .length,
        1,
      );
      expect(
        requests
            .where(
              (request) =>
                  request.url.path.endsWith('/conversation-current/runs'),
            )
            .length,
        1,
      );
    },
  );
}
