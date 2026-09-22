import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

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

  testWidgets('selects an owner session addressed by a deep link', (
    tester,
  ) async {
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
        return _json(_owned('conversation-linked', 'Deep linked work', 4));
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-linked/prompts') {
        return _json({
          'conversation_id': 'conversation-linked',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-linked/runs') {
        return _json({
          'conversation_id': 'conversation-linked',
          'runs': <Object>[],
          'has_more': false,
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          initialConversationID: 'conversation-linked',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(find.text('Deep linked work'), findsWidgets);
    expect(find.text('First page'), findsWidgets);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/conversations',
      '/api/v1/conversations/conversation-linked',
      '/api/v1/conversations/conversation-linked/prompts',
      '/api/v1/conversations/conversation-linked/runs',
    ]);
  });

  testWidgets(
    'updates the same-document route when selecting another session',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [
              _owned('conversation-first', 'First page', 1),
              _owned('conversation-second', 'Second page', 1),
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

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(
        BrowserNavigation.currentUri.path,
        isNot('/forge/conversations/conversation-second'),
      );

      final requestsBeforeSelection = requests.length;
      await tester.tap(find.text('Second page'));

      expect(
        BrowserNavigation.currentUri.path,
        '/forge/conversations/conversation-second',
      );
      expect(
        requests
            .skip(requestsBeforeSelection)
            .where((request) => request.method != 'GET'),
        isEmpty,
      );
      await _pumpRequests(tester);
    },
  );

  testWidgets(
    'restores a same-document session selection without duplicate reads',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [
              _owned('conversation-first', 'First page', 1),
              _owned('conversation-second', 'Second page', 1),
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

      BrowserNavigation.replaceState('/forge');
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      final requestsBeforeLocation = requests.length;

      BrowserNavigation.pushState('/forge/conversations/conversation-second');
      await _pumpRequests(tester);

      expect(
        BrowserNavigation.currentUri.path,
        '/forge/conversations/conversation-second',
      );
      expect(find.text('Second page'), findsWidgets);
      expect(
        requests
            .skip(requestsBeforeLocation)
            .map((request) => request.url.path),
        [
          '/api/v1/conversations/conversation-second/prompts',
          '/api/v1/conversations/conversation-second/runs',
        ],
      );

      final requestsAfterFirstLocation = requests.length;
      BrowserNavigation.replaceState(
        '/forge/conversations/conversation-second',
      );
      await _pumpRequests(tester);
      expect(requests.length, requestsAfterFirstLocation);

      expect(BrowserNavigation.back(), isTrue);
      await _pumpRequests(tester);
      expect(BrowserNavigation.currentUri.path, '/forge');
      expect(find.text('Prompt history'), findsNothing);
    },
  );

  testWidgets(
    'uses the owner-scoped detail fallback for a same-document deep link',
    (tester) async {
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
          return _json(_owned('conversation-linked', 'Deep linked work', 4));
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

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      final requestsBeforeLocation = requests.length;

      BrowserNavigation.pushState('/forge/conversations/conversation-linked');
      await _pumpRequests(tester);

      expect(find.text('Deep linked work'), findsWidgets);
      expect(
        requests
            .skip(requestsBeforeLocation)
            .map((request) => request.url.path),
        [
          '/api/v1/conversations',
          '/api/v1/conversations/conversation-linked',
          '/api/v1/conversations/conversation-linked/prompts',
          '/api/v1/conversations/conversation-linked/runs',
        ],
      );
      final requestsAfterFallback = requests.length;
      BrowserNavigation.pushState('/forge/conversations/conversation-linked');
      await _pumpRequests(tester);
      expect(requests.length, requestsAfterFallback);
    },
  );

  testWidgets(
    'failed same-document detail lookup preserves the current session',
    (tester) async {
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
            request.url.path ==
                '/api/v1/conversations/conversation-first/prompts') {
          return _json({
            'conversation_id': 'conversation-first',
            'prompts': [
              {
                'id': 'prompt-first',
                'conversation_id': 'conversation-first',
                'role': 'user',
                'content': 'keep the current prompt visible',
                'created_at_ms': 10,
              },
            ],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-first/runs') {
          return _json({
            'conversation_id': 'conversation-first',
            'runs': [
              {
                'run_id': 'run-first',
                'prompt_id': 'prompt-first',
                'created_at_ms': 10,
                'latest_sequence': 1,
                'status': 'nonterminal',
              },
            ],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-first/runs/run-first/timeline') {
          return _json({
            'conversation_id': 'conversation-first',
            'run_id': 'run-first',
            'after_sequence': 0,
            'scanned_through_sequence': 1,
            'has_more': false,
            'events': [
              {'seq': 1, 'emitted_at_ms': 11, 'type': 'run_started'},
            ],
          });
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations/conversation-missing') {
          return _json({
            'code': 'not_found',
            'message': 'Conversation not found.',
          }, status: 404);
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      BrowserNavigation.replaceState('/forge/conversations/conversation-first');
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(find.text('keep the current prompt visible'), findsOneWidget);
      final scrollable = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-run-run-first')),
        300,
        scrollable: scrollable,
      );
      expect(find.text('run-first'), findsWidgets);
      expect(
        find.byKey(const ValueKey('forge-run-event-run-first-1')),
        findsOneWidget,
      );
      final requestsBeforeLocation = requests.length;

      BrowserNavigation.pushState('/forge/conversations/conversation-missing');
      await _pumpRequests(tester);

      expect(find.text('First page'), findsWidgets);
      expect(find.text('run-first'), findsWidgets);
      expect(
        find.byKey(const ValueKey('forge-run-event-run-first-1')),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.text('keep the current prompt visible'),
        -300,
        scrollable: scrollable,
      );
      expect(find.text('keep the current prompt visible'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Conversation not found.'),
        -300,
        scrollable: scrollable,
      );
      expect(find.text('Conversation not found.'), findsOneWidget);
      expect(
        BrowserNavigation.currentUri.path,
        '/forge/conversations/conversation-missing',
      );
      expect(
        requests
            .skip(requestsBeforeLocation)
            .map((request) => request.url.path),
        ['/api/v1/conversations', '/api/v1/conversations/conversation-missing'],
      );
    },
  );

  testWidgets('disposes the same-document listener with the screen', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    final requestCountAfterDispose = requests.length;

    BrowserNavigation.pushState('/forge/conversations/conversation-first');
    await _pumpRequests(tester);
    expect(requests.length, requestCountAfterDispose);
  });
}
