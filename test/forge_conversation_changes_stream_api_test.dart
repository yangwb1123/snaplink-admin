import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';

const _change = {
  'cursor': 5,
  'schema_version': 1,
  'conversation_id': 'conversation-1',
  'entity_id': 'prompt-1',
  'aggregate_version': 2,
  'kind': 'prompt_appended',
  'created_at_ms': 30,
};

Map<String, dynamic> _page({
  int afterCursor = 4,
  int scannedThroughCursor = 5,
}) => {
  'after_cursor': afterCursor,
  'scanned_through_cursor': scannedThroughCursor,
  'has_more': false,
  'changes': [_change],
};

http.Response _sse(String body, {int status = 200, String? contentType}) =>
    http.Response(body, status, headers: {'content-type': ?contentType});

String _event({String id = '5', String? data}) =>
    'event: conversation_changes\n'
    'id: $id\n'
    'data: ${data ?? jsonEncode(_page())}\n\n';

void main() {
  test('reads one owner-scoped change page from the SSE boundary', () async {
    late http.BaseRequest request;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((incoming) async {
        request = incoming;
        return _sse(_event(), contentType: 'text/event-stream; charset=utf-8');
      }),
    );
    addTearDown(api.close);

    final page = await api.conversationChangesStream(
      afterCursor: 4,
      limit: 2,
      waitMS: 7000,
    );

    expect(page, isNotNull);
    expect(page!.afterCursor, 4);
    expect(page.scannedThroughCursor, 5);
    expect(page.changes.single.cursor, 5);
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/conversation-changes/stream');
    expect(request.url.queryParameters, {
      'after_cursor': '4',
      'limit': '2',
      'wait_ms': '7000',
    });
    expect(request.headers['accept'], 'text/event-stream');
    expect(request.headers['authorization'], 'Bearer forge-bearer');
    expect(request.headers['cache-control'], 'no-store');
  });

  test('maps an empty long-poll timeout to null on HTTP 204', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        expect(request.url.queryParameters['after_cursor'], '9');
        expect(request.url.queryParameters['wait_ms'], '15000');
        return _sse('', status: 204, contentType: 'text/event-stream');
      }),
    );
    addTearDown(api.close);

    expect(await api.conversationChangesStream(afterCursor: 9), isNull);
  });

  test('rejects a non-empty HTTP 204 response', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient(
        (_) async => _sse('\n', status: 204, contentType: 'text/event-stream'),
      ),
    );
    addTearDown(api.close);

    await expectLater(
      api.conversationChangesStream(afterCursor: 4),
      throwsFormatException,
    );
  });

  test(
    'rejects malformed, unknown, duplicate, and cursor-drifting SSE',
    () async {
      final malformedEvents = <String>[
        'event: conversation_changes\nid: 5\ndata: ${jsonEncode(_page())}\n',
        'event: other\nid: 5\ndata: ${jsonEncode(_page())}\n\n',
        'event: conversation_changes\n'
            'event: conversation_changes\n'
            'id: 5\n'
            'data: ${jsonEncode(_page())}\n\n',
        'event: conversation_changes\n'
            'id: 5\n'
            'id: 5\n'
            'data: ${jsonEncode(_page())}\n\n',
        'event: conversation_changes\n'
            'id: 5\n'
            'data: ${jsonEncode(_page())}\n'
            'data: {}\n\n',
        'event: conversation_changes\n'
            'id: 6\n'
            'data: ${jsonEncode(_page())}\n\n',
        'event: conversation_changes\n'
            'id: 05\n'
            'data: ${jsonEncode(_page())}\n\n',
        'event: conversation_changes\n'
            'id: 5\n'
            'retry: 10\n'
            'data: ${jsonEncode(_page())}\n\n',
      ];
      for (final body in malformedEvents) {
        final api = ForgeConversationsApi(
          baseUrl: 'https://forge.example',
          accessToken: 'forge-bearer',
          httpClient: MockClient(
            (_) async => _sse(body, contentType: 'text/event-stream'),
          ),
        );
        addTearDown(api.close);
        await expectLater(
          api.conversationChangesStream(afterCursor: 4),
          throwsFormatException,
        );
      }
    },
  );

  test('rejects duplicate JSON fields and non JSON-safe page values', () async {
    final duplicateJSON =
        '{"after_cursor":4,"scanned_through_cursor":5,"has_more":false,'
        '"changes":[],"changes":[]}';
    final unsafeJSON = jsonEncode({
      'after_cursor': 4,
      'scanned_through_cursor': 9007199254740992,
      'has_more': false,
      'changes': <Object>[],
    });
    for (final body in [
      _event(data: duplicateJSON),
      _event(data: unsafeJSON),
    ]) {
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient(
          (_) async => _sse(body, contentType: 'text/event-stream'),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.conversationChangesStream(afterCursor: 4),
        throwsFormatException,
      );
    }
  });

  test('rejects an SSE response with the wrong content type', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async => _sse(_event())),
    );
    addTearDown(api.close);

    await expectLater(
      api.conversationChangesStream(afterCursor: 4),
      throwsFormatException,
    );
  });

  test(
    'validates cursor and wait arguments before opening the stream',
    () async {
      var requests = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async {
          requests++;
          return _sse(_event(), contentType: 'text/event-stream');
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.conversationChangesStream(afterCursor: -1),
        throwsArgumentError,
      );
      await expectLater(
        api.conversationChangesStream(
          afterCursor: 0,
          waitMS: _forgeWaitTooLarge,
        ),
        throwsArgumentError,
      );
      await expectLater(
        api.conversationChangesStream(afterCursor: 0, waitMS: -1),
        throwsArgumentError,
      );
      expect(requests, 0);
    },
  );
}

const _forgeWaitTooLarge = 30001;
