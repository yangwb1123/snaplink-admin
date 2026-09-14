import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _owned(String id, String title, int version) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': title,
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': version,
};

Map<String, dynamic> _prompt(
  String id,
  String conversationID,
  String content,
  int createdAt,
) => {
  'id': id,
  'conversation_id': conversationID,
  'role': 'user',
  'content': content,
  'created_at_ms': createdAt,
};

String _forgeToken(String subject) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'iss': 'https://issuer.example', 'tenant_id': 'tenant-1', 'sub': subject})}.signature';
}

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 8; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

http.Response? _emptyRunPageWhenRequested(http.Request request) {
  final segments = request.url.pathSegments;
  if (request.method != 'GET' ||
      segments.length != 5 ||
      segments[0] != 'api' ||
      segments[1] != 'v1' ||
      segments[2] != 'conversations' ||
      segments[4] != 'runs') {
    return null;
  }
  return _json({
    'conversation_id': segments[3],
    'runs': <Object>[],
    'has_more': false,
  });
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('resumes the owner cursor after the screen is recreated', (
    tester,
  ) async {
    final cursors = <int>[];
    var feedRead = false;
    http.Client client() => MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 1)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': feedRead
              ? [
                  _prompt(
                    'prompt-1',
                    'conversation-1',
                    'From another device',
                    30,
                  ),
                ]
              : <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        cursors.add(cursor);
        if (cursor == 0) {
          feedRead = true;
          return _json({
            'after_cursor': 0,
            'scanned_through_cursor': 1,
            'has_more': false,
            'changes': [
              {
                'cursor': 1,
                'schema_version': 1,
                'conversation_id': 'conversation-1',
                'entity_id': 'prompt-1',
                'aggregate_version': 2,
                'kind': 'prompt_appended',
                'created_at_ms': 30,
              },
            ],
          });
        }
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    final token = _forgeToken('checkpoint-resume-user');
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: token,
          apiOrigin: 'https://forge.example',
          httpClient: client(),
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    expect(cursors, [0]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: token,
          apiOrigin: 'https://forge.example',
          httpClient: client(),
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    expect(cursors, [0, 1]);
  });

  testWidgets('refreshes shared sessions when the app returns to foreground', (
    tester,
  ) async {
    var conversationReads = 0;
    var changeReads = 0;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        conversationReads++;
        return _json({
          'conversations': [
            _owned(
              'conversation-1',
              conversationReads == 1 ? 'Shared work' : 'Updated from CLI',
              conversationReads,
            ),
          ],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        changeReads++;
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('foreground-resume-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(conversationReads, 1);
    expect(changeReads, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump(const Duration(seconds: 30));
    expect(changeReads, 0);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _pumpRequests(tester);

    expect(changeReads, 1);
    expect(conversationReads, 2);
    expect(find.text('Updated from CLI'), findsWidgets);
  });

  testWidgets('keeps the cursor when changed prompt history fails to refresh', (
    tester,
  ) async {
    final cursors = <int>[];
    var feedRead = false;
    var failHistoryOnce = true;
    final client = MockClient((request) async {
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 1)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        if (feedRead && failHistoryOnce) {
          failHistoryOnce = false;
          return _json({'error': 'unavailable'}, status: 503);
        }
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': feedRead
              ? [
                  _prompt(
                    'prompt-1',
                    'conversation-1',
                    'From another device',
                    30,
                  ),
                ]
              : <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        final cursor = int.parse(request.url.queryParameters['after_cursor']!);
        cursors.add(cursor);
        feedRead = true;
        return _json({
          'after_cursor': cursor,
          'scanned_through_cursor': cursor == 0 ? 1 : cursor,
          'has_more': false,
          'changes': cursor == 0
              ? [
                  {
                    'cursor': 1,
                    'schema_version': 1,
                    'conversation_id': 'conversation-1',
                    'entity_id': 'prompt-1',
                    'aggregate_version': 2,
                    'kind': 'prompt_appended',
                    'created_at_ms': 30,
                  },
                ]
              : <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: _forgeToken('checkpoint-history-failure-user'),
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);

    expect(cursors, [0, 0]);
  });

  testWidgets('refresh applies another device prompt from the owner feed', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final emptyRuns = _emptyRunPageWhenRequested(request);
      if (emptyRuns != null) return emptyRuns;
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-1', 'Shared work', 2)],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        expect(request.url.queryParameters['after_cursor'], '0');
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 2,
          'has_more': false,
          'changes': [
            {
              'cursor': 1,
              'schema_version': 1,
              'conversation_id': 'conversation-1',
              'entity_id': 'conversation-1',
              'aggregate_version': 1,
              'kind': 'conversation_created',
              'created_at_ms': 10,
            },
            {
              'cursor': 2,
              'schema_version': 1,
              'conversation_id': 'conversation-1',
              'entity_id': 'prompt-2',
              'aggregate_version': 2,
              'kind': 'prompt_appended',
              'created_at_ms': 40,
            },
          ],
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        final refreshed = requests
            .where((value) => value.url.path.endsWith('/conversation-changes'))
            .isNotEmpty;
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': [
            if (refreshed)
              _prompt('prompt-2', 'conversation-1', 'Second device', 40),
            _prompt('prompt-1', 'conversation-1', 'First device', 30),
          ],
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
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(find.text('Second device'), findsNothing);

    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    await tester.scrollUntilVisible(
      find.text('Prompt history'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(
      tester
          .widgetList<SelectableText>(find.byType(SelectableText))
          .any((widget) => widget.data == 'Second device'),
      isTrue,
      reason: 'The current conversation history should be refreshed.',
    );
    expect(
      requests.where(
        (request) => request.url.path == '/api/v1/conversation-changes',
      ),
      hasLength(1),
    );
  });

  testWidgets(
    'browses, creates, and appends with stable idempotency on retry',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final requests = <http.Request>[];
      var appendCount = 0;
      final client = MockClient((request) async {
        requests.add(request);
        final emptyRuns = _emptyRunPageWhenRequested(request);
        if (emptyRuns != null) return emptyRuns;
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_owned('conversation-1', 'Existing work', 5)],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-1/prompts') {
          return _json({
            'conversation_id': 'conversation-1',
            'prompts': [
              _prompt('prompt-1', 'conversation-1', 'Review logs', 30),
            ],
            'has_more': false,
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/conversations') {
          expect(jsonDecode(request.body), {
            'scope': {'kind': 'global'},
            'title': 'New work',
          });
          return _json({
            'id': 'conversation-2',
            'scope': {'kind': 'global'},
            'title': 'New work',
            'created_at_ms': 40,
            'updated_at_ms': 40,
          }, status: 201);
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-2/prompts') {
          return _json({
            'conversation_id': 'conversation-2',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'POST' &&
            request.url.path ==
                '/api/v1/conversations/conversation-2/prompts') {
          appendCount++;
          expect(jsonDecode(request.body), {
            'content': 'Run focused tests',
            'expected_version': 1,
          });
          if (appendCount == 1) throw Exception('connection interrupted');
          return _json({
            'prompt': _prompt(
              'prompt-2',
              'conversation-2',
              'Run focused tests',
              50,
            ),
            'aggregate_version': 2,
            'replayed': false,
          }, status: 201);
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(requests, hasLength(3));
      expect(requests.first.url.path, '/api/v1/conversations');
      expect(
        requests[1].url.path,
        '/api/v1/conversations/conversation-1/prompts',
      );
      expect(requests[2].url.path, '/api/v1/conversations/conversation-1/runs');
      final visibleText = tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => text.data)
          .whereType<String>()
          .toList();
      expect(visibleText, contains('Existing work'), reason: '$visibleText');
      expect(find.text('Existing work'), findsWidgets);
      await tester.enterText(find.byType(TextField).first, 'New work');
      await tester.tap(
        find.widgetWithText(FilledButton, 'Create conversation'),
      );
      await _pumpRequests(tester);

      expect(find.text('New work'), findsWidgets);
      await tester.scrollUntilVisible(
        find.text('Prompt history'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Run focused tests');
      await tester.tap(find.widgetWithText(FilledButton, 'Append prompt'));
      await _pumpRequests(tester);
      expect(find.text('Could not reach Forge.'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Retry prompt'), findsOneWidget);

      await tester.ensureVisible(
        find.widgetWithText(FilledButton, 'Retry prompt'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Retry prompt'));
      await _pumpRequests(tester);

      expect(find.text('Run focused tests'), findsOneWidget);
      expect(
        find.text('Prompt stored. It has not started a task.'),
        findsOneWidget,
      );
      expect(appendCount, 2);
      final appendRequests = requests
          .where(
            (request) =>
                request.method == 'POST' &&
                request.url.path.endsWith('/prompts'),
          )
          .toList();
      expect(appendRequests, hasLength(2));
      expect(
        appendRequests[0].headers['idempotency-key'],
        matches(RegExp(r'^[0-9a-f-]{36}$')),
      );
      expect(
        appendRequests[1].headers['idempotency-key'],
        appendRequests[0].headers['idempotency-key'],
      );
    },
  );
}
