import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_pending_run_intent.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _owned() => {
  'conversations': [
    {
      'conversation': {
        'id': 'conversation-1',
        'scope': {'kind': 'global'},
        'title': 'Pending intent session',
        'created_at_ms': 10,
        'updated_at_ms': 20,
      },
      'aggregate_version': 4,
    },
  ],
  'has_more': false,
};

Map<String, dynamic> _emptyRuns(http.Request request) => {
  'conversation_id': request.url.pathSegments[3],
  'runs': <Object>[],
  'has_more': false,
};

Map<String, dynamic> _intent({String conversationID = 'conversation-1'}) => {
  'intent_id': 'intent-1',
  'conversation_id': conversationID,
  'prompt_id': 'prompt-secret',
  'project_id': 'project-1',
  'profile_id': 'profile-1',
  'submitted_at_ms': 200,
  'aggregate_version': 5,
  'latest_sequence': 1,
  'status': 'pending',
};

ForgePendingRunIntentListPage _page({
  String conversationID = 'conversation-1',
}) => ForgePendingRunIntentListPage.fromJson({
  'conversation_id': conversationID,
  'intents': [_intent(conversationID: conversationID)],
  'has_more': false,
}, requestedConversationID: conversationID);

ForgePendingRunIntentListPage _emptyPage(String conversationID) =>
    ForgePendingRunIntentListPage.fromJson({
      'conversation_id': conversationID,
      'intents': <Object>[],
      'has_more': false,
    }, requestedConversationID: conversationID);

Map<String, dynamic> _pagedIntent(int ordinal) => {
  'intent_id': 'intent-$ordinal',
  'conversation_id': 'conversation-1',
  'prompt_id': 'prompt-$ordinal',
  'project_id': 'project-1',
  'profile_id': 'profile-1',
  'submitted_at_ms': 100000 - ordinal,
  'aggregate_version': ordinal + 5,
  'latest_sequence': 1,
  'status': 'pending',
};

ForgePendingRunIntentListPage _pagedPage({
  required int offset,
  required bool hasMore,
}) {
  final intents = List.generate(
    25,
    (index) => _pagedIntent(offset + index),
    growable: false,
  );
  return ForgePendingRunIntentListPage.fromJson({
    'conversation_id': 'conversation-1',
    'intents': intents,
    'has_more': hasMore,
    if (hasMore)
      'next_cursor': {
        'submitted_at_ms': intents.last['submitted_at_ms'],
        'intent_id': intents.last['intent_id'],
      },
  }, requestedConversationID: 'conversation-1');
}

ForgePendingRunIntentTimelinePage _timeline({
  String conversationID = 'conversation-1',
  String intentID = 'intent-1',
  String eventType = 'submitted',
}) => ForgePendingRunIntentTimelinePage(
  conversationID: conversationID,
  intentID: intentID,
  afterSequence: 0,
  scannedThroughSequence: 1,
  hasMore: false,
  events: [
    ForgePendingRunIntentEvent(
      eventID: 'event-1',
      sequence: 1,
      emittedAtMS: 200,
      type: eventType,
    ),
  ],
);

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 8; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _expandTimeline(WidgetTester tester) async {
  final list = find.byType(ListView);
  await tester.drag(list, const Offset(0, -500));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Timeline metadata'));
}

http.Client _sessionsClient({
  required bool allowRefresh,
  bool emitChange = false,
}) {
  var changeReads = 0;
  return MockClient((request) async {
    final path = request.url.path;
    if (request.method == 'GET' && path == '/api/v1/conversations') {
      return _json(_owned());
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
      return _json(_emptyRuns(request));
    }
    if (allowRefresh &&
        request.method == 'GET' &&
        path == '/api/v1/conversation-changes') {
      final cursor = int.parse(
        request.url.queryParameters['after_cursor'] ?? '0',
      );
      changeReads++;
      return _json({
        'after_cursor': cursor,
        'scanned_through_cursor': emitChange && cursor == 0 ? 1 : cursor,
        'has_more': false,
        'changes': emitChange && cursor == 0 && changeReads == 1
            ? [
                {
                  'cursor': 1,
                  'schema_version': 1,
                  'conversation_id': 'conversation-1',
                  'entity_id': 'prompt-new',
                  'aggregate_version': 5,
                  'kind': 'prompt_appended',
                  'created_at_ms': 300,
                },
              ]
            : <Object>[],
      });
    }
    throw StateError('Unexpected Forge request: ${request.method} $path');
  });
}

http.Client _twoConversationSessionsClient() => MockClient((request) async {
  final path = request.url.path;
  if (request.method == 'GET' && path == '/api/v1/conversations') {
    return _json({
      'conversations': [
        {
          'conversation': {
            'id': 'conversation-1',
            'scope': {'kind': 'global'},
            'title': 'Pending intent session',
            'created_at_ms': 10,
            'updated_at_ms': 20,
          },
          'aggregate_version': 4,
        },
        {
          'conversation': {
            'id': 'conversation-2',
            'scope': {'kind': 'global'},
            'title': 'Second session',
            'created_at_ms': 11,
            'updated_at_ms': 21,
          },
          'aggregate_version': 1,
        },
      ],
      'has_more': false,
    });
  }
  if (request.method == 'GET' && path.endsWith('/prompts')) {
    return _json({
      'conversation_id': request.url.pathSegments[3],
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (request.method == 'GET' && path.endsWith('/runs')) {
    return _json(_emptyRuns(request));
  }
  throw StateError('Unexpected Forge request: ${request.method} $path');
});

void main() {
  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders owner-scoped pending metadata without Prompt content', (
    tester,
  ) async {
    var readerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentReader: (conversationID) async {
            readerCalls++;
            expect(conversationID, 'conversation-1');
            return _page();
          },
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(readerCalls, 1);
    final panel = find.byKey(
      const ValueKey('forge-pending-run-intent-metadata-card'),
    );
    expect(panel, findsOneWidget);
    expect(find.text('intent-1'), findsOneWidget);
    expect(find.text('prompt-secret'), findsOneWidget);
    expect(find.text('project-1'), findsOneWidget);
    expect(find.text('profile-1'), findsOneWidget);
    expect(find.text('pending'), findsOneWidget);
    expect(find.text('secret prompt body'), findsNothing);
    expect(
      find.descendant(of: panel, matching: find.byType(FilledButton)),
      findsNothing,
    );
  });

  testWidgets('refresh performs one additional pending metadata read', (
    tester,
  ) async {
    var readerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: true),
          pendingRunIntentReader: (_) async {
            readerCalls++;
            return _page();
          },
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(readerCalls, 1);

    await tester.tap(find.byIcon(Icons.refresh));
    await _pumpRequests(tester);
    expect(readerCalls, 2);
    expect(
      find.byKey(const ValueKey('forge-pending-run-intent-metadata-card')),
      findsOneWidget,
    );
  });

  testWidgets('scheduled change sync refreshes pending metadata reader', (
    tester,
  ) async {
    var readerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: true),
          pendingRunIntentReader: (_) async {
            readerCalls++;
            return _page();
          },
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(readerCalls, 1);

    // Scheduled polling bypasses _refreshAndSync. The explicit reader must
    // still refresh when the owner feed has no changes.
    await tester.pump(const Duration(seconds: 16));
    await _pumpRequests(tester);

    expect(readerCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('paged reader loads older pending receipts with its cursor', (
    tester,
  ) async {
    var readerCalls = 0;
    ForgePendingRunIntentCursor? requestedBefore;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentPageReader: (conversationID, before) async {
            expect(conversationID, 'conversation-1');
            readerCalls++;
            requestedBefore = before;
            return before == null
                ? _pagedPage(offset: 0, hasMore: true)
                : _pagedPage(offset: 25, hasMore: false);
          },
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(readerCalls, 1);
    final loadMore = find.byKey(
      const ValueKey('forge-pending-run-intent-load-more'),
    );
    expect(loadMore, findsOneWidget);
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pumpAndSettle();
    await tester.tap(loadMore);
    await _pumpRequests(tester);

    expect(readerCalls, 2);
    expect(requestedBefore, isNotNull);
    expect(requestedBefore!.intentID, 'intent-24');
    expect(find.text('intent-25'), findsOneWidget);
    expect(loadMore, findsNothing);
  });

  testWidgets('timeline is read only after its receipt is expanded', (
    tester,
  ) async {
    var timelineCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentReader: (_) async => _page(),
          pendingRunIntentTimelineReader: (conversationID, intentID) async {
            timelineCalls++;
            expect(conversationID, 'conversation-1');
            expect(intentID, 'intent-1');
            return _timeline();
          },
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(timelineCalls, 0);
    final tile = find.text('Timeline metadata');
    expect(tile, findsOneWidget);
    await _expandTimeline(tester);
    await _pumpRequests(tester);
    expect(timelineCalls, 1);
    expect(find.text('event-1'), findsOneWidget);
    expect(find.text('submitted'), findsWidgets);

    await tester.tap(tile);
    await _pumpRequests(tester);
    expect(timelineCalls, 1);
  });

  testWidgets(
    'change-feed refresh reads metadata once and keeps an expanded timeline',
    (tester) async {
      var metadataCalls = 0;
      var timelineCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: _sessionsClient(allowRefresh: true, emitChange: true),
            pendingRunIntentReader: (_) async {
              metadataCalls++;
              return _page();
            },
            pendingRunIntentTimelineReader: (conversationID, intentID) async {
              timelineCalls++;
              return _timeline();
            },
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(metadataCalls, 1);
      await _expandTimeline(tester);
      await _pumpRequests(tester);
      expect(timelineCalls, 1);
      expect(find.text('event-1'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.refresh));
      await _pumpRequests(tester);
      expect(metadataCalls, 2);
      expect(timelineCalls, 1);
      expect(find.text('event-1'), findsOneWidget);
    },
  );

  testWidgets('switching sessions clears and reloads pending timelines', (
    tester,
  ) async {
    final metadataConversations = <String>[];
    var timelineCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _twoConversationSessionsClient(),
          pendingRunIntentReader: (conversationID) async {
            metadataConversations.add(conversationID);
            return conversationID == 'conversation-1'
                ? _page()
                : _emptyPage(conversationID);
          },
          pendingRunIntentTimelineReader: (conversationID, intentID) async {
            timelineCalls++;
            expect(conversationID, 'conversation-1');
            expect(intentID, 'intent-1');
            return _timeline();
          },
        ),
      ),
    );
    await _pumpRequests(tester);
    await _expandTimeline(tester);
    await _pumpRequests(tester);
    expect(find.text('event-1'), findsOneWidget);
    expect(timelineCalls, 1);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-conversation-conversation-2')),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-conversation-conversation-2')),
    );
    await _pumpRequests(tester);
    expect(metadataConversations, contains('conversation-2'));
    expect(find.text('intent-1'), findsNothing);
    expect(find.text('event-1'), findsNothing);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-conversation-conversation-1')),
      -500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-conversation-conversation-1')),
    );
    await _pumpRequests(tester);
    expect(metadataConversations, contains('conversation-1'));
    expect(find.text('event-1'), findsNothing);

    await _expandTimeline(tester);
    await _pumpRequests(tester);
    expect(timelineCalls, 2);
    expect(find.text('event-1'), findsOneWidget);
  });

  testWidgets('foreign timeline binding fails closed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentReader: (_) async => _page(),
          pendingRunIntentTimelineReader: (conversationID, intentID) async =>
              _timeline(conversationID: 'conversation-foreign'),
        ),
      ),
    );
    await _pumpRequests(tester);
    await _expandTimeline(tester);
    await _pumpRequests(tester);

    expect(find.text('event-1'), findsNothing);
    expect(find.text('Forge returned an invalid response.'), findsOneWidget);
  });

  testWidgets('foreign timeline intent fails closed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentReader: (_) async => _page(),
          pendingRunIntentTimelineReader: (conversationID, intentID) async =>
              _timeline(intentID: 'intent-foreign'),
        ),
      ),
    );
    await _pumpRequests(tester);
    await _expandTimeline(tester);
    await _pumpRequests(tester);

    expect(find.text('event-1'), findsNothing);
    expect(find.text('Forge returned an invalid response.'), findsOneWidget);
  });

  testWidgets('timeline event type drift fails closed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentReader: (_) async => _page(),
          pendingRunIntentTimelineReader: (conversationID, intentID) async =>
              _timeline(eventType: 'run_started'),
        ),
      ),
    );
    await _pumpRequests(tester);
    await _expandTimeline(tester);
    await _pumpRequests(tester);

    expect(find.text('event-1'), findsNothing);
    expect(find.text('Forge returned an invalid response.'), findsOneWidget);
  });

  testWidgets('foreign conversation metadata fails closed', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentReader: (_) async =>
              _page(conversationID: 'conversation-foreign'),
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-pending-run-intent-metadata-card')),
      findsNothing,
    );
    expect(
      find.text('Forge returned unexpected response fields.'),
      findsNothing,
    );
    expect(find.text('Forge returned an invalid response.'), findsOneWidget);
  });

  testWidgets('authorization failure clears pending metadata', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
          pendingRunIntentReader: (_) async {
            throw const ForgeConversationsApiException(
              statusCode: 401,
              code: 'unauthorized',
              message: 'expired',
            );
          },
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-pending-run-intent-metadata-card')),
      findsNothing,
    );
    expect(find.text('intent-1'), findsNothing);
  });

  testWidgets('default screen never requests pending Run-intent metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: _sessionsClient(allowRefresh: false),
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-pending-run-intent-metadata-card')),
      findsNothing,
    );
  });
}
