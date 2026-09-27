import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _owned(String id, int version) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': 'Shared session',
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': version,
};

Map<String, dynamic> _prompt(String id, String content, int createdAt) => {
  'id': id,
  'conversation_id': 'conversation-1',
  'role': 'user',
  'content': content,
  'created_at_ms': createdAt,
};

Map<String, dynamic> _changePage({
  required int afterCursor,
  required int scannedThroughCursor,
  List<Object> changes = const <Object>[],
}) => {
  'after_cursor': afterCursor,
  'scanned_through_cursor': scannedThroughCursor,
  'has_more': false,
  'changes': changes,
};

String _sse(Object page, int cursor) =>
    'event: conversation_changes\n'
    'id: $cursor\n'
    'data: ${jsonEncode(page)}\n\n';

Map<String, dynamic> _promptChange(int cursor, int version) => {
  'cursor': cursor,
  'schema_version': 1,
  'conversation_id': 'conversation-1',
  'entity_id': 'prompt-new',
  'aggregate_version': version,
  'kind': 'prompt_appended',
  'created_at_ms': 40,
};

String _forgeToken(String subject) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'iss': 'https://issuer.example', 'tenant_id': 'tenant-1', 'sub': subject})}.signature';
}

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 100; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
}

http.Response _emptyRuns(http.Request request) => _json({
  'conversation_id': request.url.pathSegments[3],
  'runs': <Object>[],
  'has_more': false,
});

void main() {
  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('opt-in stream merges a page before persisting its cursor', (
    tester,
  ) async {
    var streamReads = 0;
    var pollingReads = 0;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 2)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': [_prompt('prompt-new', 'from stream', 40)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversations/conversation-1/runs') {
        return _emptyRuns(request);
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversation-changes/stream') {
        streamReads++;
        if (streamReads == 1) {
          expect(request.headers['accept'], 'text/event-stream');
          expect(request.url.queryParameters['after_cursor'], '0');
          return http.Response(
            _sse(
              _changePage(
                afterCursor: 0,
                scannedThroughCursor: 1,
                changes: [_promptChange(1, 3)],
              ),
              1,
            ),
            200,
            headers: const {'content-type': 'text/event-stream'},
          );
        }
        // Stop the opt-in stream after proving its error fallback. The
        // screen must use the ordinary JSON feed afterward.
        return _json({'error': 'stream unavailable'}, status: 503);
      }
      if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
        pollingReads++;
        final after = int.parse(request.url.queryParameters['after_cursor']!);
        expect(after, 1);
        return _json(_changePage(afterCursor: after, scannedThroughCursor: 1));
      }
      throw StateError('Unexpected Forge request: ${request.method} $path');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('stream-merge-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
          enableConversationChangesStream: true,
          conversationChangesStreamWaitMS: 100,
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(find.text('from stream'), findsOneWidget);
    expect(streamReads, greaterThanOrEqualTo(2));
    expect(pollingReads, greaterThanOrEqualTo(1));
  });

  testWidgets('a 204 stream timeout reconnects without advancing the cursor', (
    tester,
  ) async {
    var streamReads = 0;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 2)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': [_prompt('prompt-new', 'reconnected', 40)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversations/conversation-1/runs') {
        return _emptyRuns(request);
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversation-changes/stream') {
        streamReads++;
        if (streamReads == 1) return http.Response('', 204);
        expect(request.url.queryParameters['after_cursor'], '0');
        return http.Response(
          _sse(
            _changePage(
              afterCursor: 0,
              scannedThroughCursor: 1,
              changes: [_promptChange(1, 3)],
            ),
            1,
          ),
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }
      throw StateError('Unexpected Forge request: ${request.method} $path');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('stream-reconnect-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
          enableConversationChangesStream: true,
          conversationChangesStreamWaitMS: 100,
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(streamReads, greaterThanOrEqualTo(2));
    expect(find.text('reconnected'), findsOneWidget);
  });

  testWidgets('malformed stream falls back to the JSON polling feed', (
    tester,
  ) async {
    var streamReads = 0;
    var pollingReads = 0;
    final client = MockClient((request) async {
      final path = request.url.path;
      if (request.method == 'GET' && path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 2)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': pollingReads == 0
              ? <Object>[]
              : [_prompt('prompt-fallback', 'polling fallback', 50)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversations/conversation-1/runs') {
        return _emptyRuns(request);
      }
      if (request.method == 'GET' &&
          path == '/api/v1/conversation-changes/stream') {
        streamReads++;
        return http.Response(
          'event: conversation_changes\nid: 1\ndata: {broken}\n\n',
          200,
          headers: const {'content-type': 'text/event-stream'},
        );
      }
      if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
        pollingReads++;
        final after = int.parse(request.url.queryParameters['after_cursor']!);
        return _json(
          _changePage(
            afterCursor: after,
            scannedThroughCursor: 1,
            changes: [_promptChange(1, 3)],
          ),
        );
      }
      throw StateError('Unexpected Forge request: ${request.method} $path');
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('stream-parse-fallback-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
          enableConversationChangesStream: true,
          conversationChangesStreamWaitMS: 100,
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(streamReads, 1);
    expect(pollingReads, greaterThanOrEqualTo(1));
    expect(find.text('polling fallback'), findsOneWidget);
  });

  testWidgets(
    'revoked selected instance blocks the change feed before cursor progress',
    (tester) async {
      var sessionViewReads = 0;
      var streamReads = 0;
      var pollingReads = 0;
      final owner = ForgeDeviceOwner(
        issuer: 'https://issuer.example',
        subject: 'stream-revocation-user',
        tenantID: 'tenant-1',
      );
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return _json({
            'conversations': [_owned('conversation-1', 1)],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversations/conversation-1/prompts') {
          return _json({
            'conversation_id': 'conversation-1',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversations/conversation-1/runs') {
          return _emptyRuns(request);
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversation-changes/stream') {
          streamReads++;
          throw StateError('revoked instance must block the stream request');
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          pollingReads++;
          throw StateError('revoked instance must block the polling request');
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      final visible = ForgeClientInstanceSessionView.fromJson(
        _sessionViewFixture(includeWeb: true),
      );
      final revoked = ForgeClientInstanceSessionView.fromJson(
        _sessionViewFixture(includeWeb: false),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: _forgeToken('stream-revocation-user'),
            apiOrigin: 'https://forge.example',
            httpClient: client,
            initialConversationID: 'conversation-1',
            initialClientInstanceID: 'client-web-001',
            enableConversationChangesStream: true,
            conversationChangesStreamWaitMS: 0,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async {
              sessionViewReads++;
              return sessionViewReads == 1 ? visible : revoked;
            },
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(sessionViewReads, greaterThanOrEqualTo(2));
      expect(streamReads, 0);
      expect(pollingReads, 0);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'selected instance advances across hidden change rows without private hydration',
    (tester) async {
      var streamReads = 0;
      var conversationReads = 0;
      var promptReads = 0;
      var runReads = 0;
      var sessionViewReads = 0;
      final secondStream = Completer<http.Response>();
      final owner = ForgeDeviceOwner(
        issuer: 'https://issuer.example',
        subject: 'stream-hidden-user',
        tenantID: 'tenant-1',
      );
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          conversationReads++;
          return _json({
            'conversations': [_owned('conversation-1', 1)],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversations/conversation-1/prompts') {
          promptReads++;
          return _json({
            'conversation_id': 'conversation-1',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversations/conversation-1/runs') {
          runReads++;
          return _emptyRuns(request);
        }
        if (request.method == 'GET' &&
            path == '/api/v1/conversation-changes/stream') {
          streamReads++;
          if (streamReads == 1) {
            expect(request.url.queryParameters['after_cursor'], '0');
            return http.Response(
              _sse(
                _changePage(
                  afterCursor: 0,
                  scannedThroughCursor: 1,
                  changes: [
                    {
                      ..._promptChange(1, 2),
                      'conversation_id': 'conversation-hidden',
                    },
                  ],
                ),
                1,
              ),
              200,
              headers: const {'content-type': 'text/event-stream'},
            );
          }
          return secondStream.future;
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          final after = int.parse(request.url.queryParameters['after_cursor']!);
          return _json(
            _changePage(afterCursor: after, scannedThroughCursor: after),
          );
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: _forgeToken('stream-hidden-user'),
            apiOrigin: 'https://forge.example',
            httpClient: client,
            initialConversationID: 'conversation-1',
            initialClientInstanceID: 'client-web-001',
            enableConversationChangesStream: true,
            conversationChangesStreamWaitMS: 0,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async {
              sessionViewReads++;
              return ForgeClientInstanceSessionView.fromJson(
                _sessionViewFixture(
                  includeWeb: true,
                  subject: 'stream-hidden-user',
                ),
              );
            },
          ),
        ),
      );
      for (var count = 0; count < 80 && streamReads == 0; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(streamReads, greaterThanOrEqualTo(1));
      expect(sessionViewReads, greaterThanOrEqualTo(2));
      expect(conversationReads, 1);
      expect(promptReads, 1);
      expect(runReads, 1);
      secondStream.complete(http.Response('', 503));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}

Map<String, dynamic> _sessionViewFixture({
  required bool includeWeb,
  String subject = 'stream-revocation-user',
}) => {
  'schema_version': 'forge.client-instance-session-view/v1',
  'evaluation_mode': 'owner_bound_session_view_only',
  'owner_declaration': {
    'issuer': 'https://issuer.example',
    'subject': subject,
    'tenant_id': 'tenant-1',
  },
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-cli-001',
      'client_kind': 'cli',
      'session_ids': ['conversation-1'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
    if (includeWeb)
      {
        'instance_id': 'client-web-001',
        'client_kind': 'web',
        'session_ids': ['conversation-1'],
        'observed_at_ms': 200500,
        'status': 'idle',
      },
  ],
  'read_only': true,
  'authority': {
    'owner_authenticated': false,
    'session_read_authorized': false,
    'prompt_write_authorized': false,
    'device_identity_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
