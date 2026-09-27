import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

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

  setUp(() {
    BrowserNavigation.resetForTest();
  });

  tearDown(() {
    BrowserNavigation.resetForTest();
  });

  testWidgets('Gate keeps Conversation SSE disabled by default', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError('Unexpected default Gate request: ${request.url}');
    });
    final credentialStore = await _credentialStore('gate-default-token');
    addTearDown(() async {
      await credentialStore.clear();
      client.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => requests.any(
        (request) => request.url.path == '/api/v1/conversations',
      ),
      waitFor: 'default Gate owner snapshot',
    );

    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/conversation-changes/stream',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Gate forwards the explicit bounded Conversation SSE option', (
    tester,
  ) async {
    var streamReads = 0;
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path == '/api/v1/conversation-changes/stream') {
        streamReads++;
        expect(request.url.queryParameters['wait_ms'], '0');
        expect(request.headers['accept'], 'text/event-stream');
        if (streamReads == 1) return http.Response('', 204);
        return _json({'error': 'stop test stream'}, status: 503);
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError('Unexpected opt-in Gate request: ${request.url}');
    });
    final credentialStore = await _credentialStore('gate-stream-token');
    addTearDown(() async {
      await credentialStore.clear();
      client.close();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          enableConversationChangesStream: true,
          conversationChangesStreamWaitMS: 0,
        ),
      ),
    );
    await _pumpUntil(
      tester,
      () => streamReads >= 2,
      waitFor: 'Gate opt-in Conversation SSE reads',
    );

    expect(streamReads, greaterThanOrEqualTo(2));
    await _pumpUntil(
      tester,
      () => requests.any(
        (request) => request.url.path == '/api/v1/conversation-changes',
      ),
      waitFor: 'existing JSON polling fallback',
    );
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/conversation-changes',
      ),
      isNotEmpty,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String waitFor,
}) async {
  for (var count = 0; count < 120; count++) {
    if (condition()) {
      // Request capture happens before the API transport has finished
      // draining the MockClient response. Give that continuation one real
      // async turn so its bounded timeout timer is also cancelled before
      // the widget is disposed.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      if (condition()) return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(condition(), isTrue, reason: 'Timed out waiting for $waitFor.');
}
