import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';

Map<String, Object> _run(
  String id,
  String promptID,
  int createdAtMS, {
  int latestSequence = 2,
  String status = 'nonterminal',
}) => {
  'run_id': id,
  'prompt_id': promptID,
  'created_at_ms': createdAtMS,
  'latest_sequence': latestSequence,
  'status': status,
};

Map<String, Object> _event(int sequence, String type) => {
  'seq': sequence,
  'emitted_at_ms': sequence + 100,
  'type': type,
};

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  group('Forge run response models', () {
    test('accepts bounded short pages with advancing cursors', () {
      final runs = ForgeConversationRunPage.fromJson(
        {
          'conversation_id': 'conversation-1',
          'runs': [
            _run('run-b', 'prompt-b', 20),
            _run('run-a', 'prompt-a', 19),
          ],
          'next_cursor': {'created_at_ms': 19, 'run_id': 'run-a'},
          'has_more': true,
        },
        requestedConversationID: 'conversation-1',
        limit: 25,
      );
      expect(runs.runs, hasLength(2));
      expect(runs.nextCursor?.runID, 'run-a');
      expect(runs.hasMore, isTrue);

      final timeline = ForgeRunTimelinePage.fromJson(
        {
          'conversation_id': 'conversation-1',
          'run_id': 'run-b',
          'after_sequence': 0,
          'scanned_through_sequence': 2,
          'has_more': true,
          'events': [_event(1, 'run_started'), _event(2, 'activity')],
        },
        requestedConversationID: 'conversation-1',
        requestedRunID: 'run-b',
        requestedAfterSequence: 0,
        limit: 128,
      );
      expect(timeline.events.map((event) => event.type), [
        'run_started',
        'activity',
      ]);
      expect(timeline.scannedThroughSequence, 2);
    });

    test('rejects extra fields, content event types, and invalid cursors', () {
      final validRunPage = {
        'conversation_id': 'conversation-1',
        'runs': [_run('run-a', 'prompt-a', 10)],
        'has_more': false,
      };
      expect(
        () => ForgeConversationRunPage.fromJson({
          ...validRunPage,
          'execution_json': 'secret',
        }, requestedConversationID: 'conversation-1'),
        throwsFormatException,
      );
      expect(
        () => ForgeConversationRunPage.fromJson({
          'conversation_id': 'conversation-1',
          'runs': [
            {..._run('run-a', 'prompt-a', 10), 'execution_json': 'secret'},
          ],
          'has_more': false,
        }, requestedConversationID: 'conversation-1'),
        throwsFormatException,
      );
      expect(
        () => ForgeConversationRunPage.fromJson({
          'conversation_id': 'conversation-1',
          'runs': [_run('run-a', 'prompt-a', 10)],
          'has_more': true,
          'next_cursor': {'created_at_ms': 10, 'run_id': 'wrong'},
        }, requestedConversationID: 'conversation-1'),
        throwsFormatException,
      );
      expect(
        () => ForgeConversationRun.fromJson(
          _run('run-a', 'prompt-a', 10, latestSequence: 0),
        ),
        throwsFormatException,
      );

      final timeline = {
        'conversation_id': 'conversation-1',
        'run_id': 'run-a',
        'after_sequence': 0,
        'scanned_through_sequence': 1,
        'has_more': false,
        'events': [_event(1, 'activity')],
      };
      expect(
        () => ForgeRunTimelinePage.fromJson(
          {
            ...timeline,
            'events': [
              {..._event(1, 'activity'), 'content': 'secret'},
            ],
          },
          requestedConversationID: 'conversation-1',
          requestedRunID: 'run-a',
          requestedAfterSequence: 0,
        ),
        throwsFormatException,
      );
      expect(
        () => ForgeRunTimelinePage.fromJson(
          {
            ...timeline,
            'events': [_event(1, 'assistant_delta')],
          },
          requestedConversationID: 'conversation-1',
          requestedRunID: 'run-a',
          requestedAfterSequence: 0,
        ),
        throwsFormatException,
      );
      expect(
        () => ForgeRunTimelinePage.fromJson(
          {...timeline, 'scanned_through_sequence': 3},
          requestedConversationID: 'conversation-1',
          requestedRunID: 'run-a',
          requestedAfterSequence: 0,
        ),
        throwsFormatException,
      );
    });
  });

  test('uses scoped Forge credentials and bounded run endpoints', () async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json({
          'conversation_id': 'conversation-1',
          'runs': [
            _run('run-b', 'prompt-b', 20),
            _run('run-a', 'prompt-a', 19),
          ],
          'next_cursor': {'created_at_ms': 19, 'run_id': 'run-a'},
          'has_more': true,
        });
      }
      if (request.url.path ==
          '/api/v1/conversations/conversation-1/runs/run-b/timeline') {
        return _json({
          'conversation_id': 'conversation-1',
          'run_id': 'run-b',
          'after_sequence': 4,
          'scanned_through_sequence': 5,
          'has_more': false,
          'events': [_event(5, 'run_finished')],
        });
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-scoped-bearer',
      httpClient: client,
    );
    addTearDown(api.close);

    final page = await api.listRuns(
      conversationID: 'conversation-1',
      before: const ForgeRunCursor(createdAtMS: 30, runID: 'run-z'),
      limit: 999,
    );
    final timeline = await api.listRunTimeline(
      conversationID: 'conversation-1',
      runID: 'run-b',
      afterSequence: 4,
      limit: 1000,
    );

    expect(page.runs.map((run) => run.runID), ['run-b', 'run-a']);
    expect(timeline.events.single.type, 'run_finished');
    expect(requests, hasLength(2));
    expect(requests[0].url.queryParameters, {
      'limit': '25',
      'before_created_at_ms': '30',
      'before_run_id': 'run-z',
    });
    expect(requests[1].url.queryParameters, {
      'after_sequence': '4',
      'limit': '128',
    });
    for (final request in requests) {
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer forge-scoped-bearer');
      expect(request.headers['cache-control'], 'no-store');
      expect(request.followRedirects, isFalse);
      expect(request.body, isEmpty);
    }
  });
}
