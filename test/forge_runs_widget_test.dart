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

Map<String, Object> _ownedConversation() => {
  'conversation': {
    'id': 'conversation-1',
    'scope': {'kind': 'global'},
    'title': 'Shared work',
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': 1,
};

Map<String, Object> _run(
  String id,
  int createdAtMS, {
  int latestSequence = 3,
  String status = 'nonterminal',
}) => {
  'run_id': id,
  'prompt_id': 'prompt-$id',
  'created_at_ms': createdAtMS,
  'latest_sequence': latestSequence,
  'status': status,
};

Map<String, Object> _event(int sequence, String type) => {
  'seq': sequence,
  'emitted_at_ms': 1000 + sequence,
  'type': type,
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

  testWidgets('loads metadata-only Runs and paginates both views', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_ownedConversation()],
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
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        if (request.url.queryParameters.containsKey('before_run_id')) {
          expect(request.url.queryParameters['before_run_id'], 'run-a');
          return _json({
            'conversation_id': 'conversation-1',
            'runs': [_run('run-older', 10)],
            'has_more': false,
          });
        }
        return _json({
          'conversation_id': 'conversation-1',
          'runs': [_run('run-b', 20), _run('run-a', 19)],
          'next_cursor': {'created_at_ms': 19, 'run_id': 'run-a'},
          'has_more': true,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-1/runs/run-b/timeline') {
        final after = request.url.queryParameters['after_sequence'];
        if (after == '2') {
          return _json({
            'conversation_id': 'conversation-1',
            'run_id': 'run-b',
            'after_sequence': 2,
            'scanned_through_sequence': 3,
            'has_more': false,
            'events': [_event(3, 'run_finished')],
          });
        }
        return _json({
          'conversation_id': 'conversation-1',
          'run_id': 'run-b',
          'after_sequence': 0,
          'scanned_through_sequence': 2,
          'has_more': true,
          'events': [_event(1, 'run_started'), _event(2, 'activity')],
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

    await tester.scrollUntilVisible(
      find.text('Runs'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('run-b'), findsWidgets);
    expect(find.text('activity'), findsOneWidget);
    expect(find.textContaining('secret-run-content'), findsNothing);
    await tester.scrollUntilVisible(
      find.text('Load older runs'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load older runs'));
    await _pumpRequests(tester);
    expect(find.text('run-older'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byTooltip('Reload timeline'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Reload timeline'));
    await _pumpRequests(tester);

    await tester.scrollUntilVisible(
      find.text('Load more timeline markers'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Load more timeline markers'));
    await _pumpRequests(tester);
    expect(find.text('run_finished'), findsOneWidget);
    expect(
      requests
          .where((request) => request.url.path.endsWith('/timeline'))
          .map((request) => request.url.queryParameters['after_sequence']),
      ['0', '0', '2'],
    );
  });

  testWidgets('periodically refreshes selected Run metadata and timeline', (
    tester,
  ) async {
    final requests = <http.Request>[];
    var runPageRequests = 0;
    var timelineAfterOneRequests = 0;
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_ownedConversation()],
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
        final after = int.parse(request.url.queryParameters['after_cursor']!);
        return _json({
          'after_cursor': after,
          'scanned_through_cursor': after,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        runPageRequests++;
        final isInitialPage = runPageRequests == 1;
        return _json({
          'conversation_id': 'conversation-1',
          'runs': [
            _run(
              'run-live',
              20,
              latestSequence: isInitialPage ? 1 : 2,
              status: isInitialPage ? 'nonterminal' : 'completed',
            ),
          ],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-1/runs/run-live/timeline') {
        final after = request.url.queryParameters['after_sequence'];
        if (after == '0') {
          return _json({
            'conversation_id': 'conversation-1',
            'run_id': 'run-live',
            'after_sequence': 0,
            'scanned_through_sequence': 1,
            'has_more': false,
            'events': [_event(1, 'run_started')],
          });
        }
        if (after == '1' && timelineAfterOneRequests++ == 0) {
          // A malformed page must leave the stored sequence at 1 for retry.
          return _json({
            'conversation_id': 'conversation-1',
            'run_id': 'run-live',
            'after_sequence': 1,
            'scanned_through_sequence': 2,
            'has_more': false,
            'events': [_event(3, 'run_finished')],
          });
        }
        if (after == '1') {
          return _json({
            'conversation_id': 'conversation-1',
            'run_id': 'run-live',
            'after_sequence': 1,
            'scanned_through_sequence': 2,
            'has_more': false,
            'events': [_event(2, 'run_finished')],
          });
        }
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
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-run-live')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('run_started'), findsOneWidget);
    expect(find.text('run_finished'), findsNothing);

    await tester.pump(const Duration(seconds: 15));
    await _pumpRequests(tester);
    expect(find.textContaining('completed'), findsOneWidget);
    expect(find.text('run_finished'), findsNothing);

    await tester.pump(const Duration(seconds: 15));
    await _pumpRequests(tester);
    expect(find.text('run_finished'), findsOneWidget);
    expect(
      requests
          .where((request) => request.url.path.endsWith('/timeline'))
          .map((request) => request.url.queryParameters['after_sequence']),
      ['0', '1', '1'],
    );
    expect(runPageRequests, 3);
    expect(requests.every((request) => request.method == 'GET'), isTrue);
    expect(
      requests.every(
        (request) => request.headers['authorization'] == 'Bearer forge-bearer',
      ),
      isTrue,
    );
  });
}
