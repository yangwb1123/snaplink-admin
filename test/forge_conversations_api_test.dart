import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _conversation({
  String id = 'conversation-1',
  String title = 'Build release',
}) => {
  'id': id,
  'scope': {'kind': 'global'},
  'title': title,
  'created_at_ms': 10,
  'updated_at_ms': 20,
};

Map<String, dynamic> _prompt({
  String id = 'prompt-1',
  String content = 'run tests',
}) => {
  'id': id,
  'conversation_id': 'conversation-1',
  'role': 'user',
  'content': content,
  'created_at_ms': 30,
};

void main() {
  test('reads dense owner-scoped conversation changes by cursor', () async {
    late http.Request request;
    final client = MockClient((value) async {
      request = value;
      return _json({
        'after_cursor': 4,
        'scanned_through_cursor': 6,
        'has_more': true,
        'changes': [
          {
            'cursor': 5,
            'schema_version': 1,
            'conversation_id': 'conversation-1',
            'entity_id': 'prompt-2',
            'aggregate_version': 2,
            'kind': 'prompt_appended',
            'created_at_ms': 30,
          },
          {
            'cursor': 6,
            'schema_version': 1,
            'conversation_id': 'conversation-1',
            'entity_id': 'prompt-3',
            'aggregate_version': 3,
            'kind': 'prompt_appended',
            'created_at_ms': 40,
          },
        ],
      });
    });
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: client,
    );
    addTearDown(api.close);

    final page = await api.conversationChanges(afterCursor: 4, limit: 2);

    expect(page.scannedThroughCursor, 6);
    expect(page.changes.first.cursor, 5);
    expect(page.changes.first.kind, 'prompt_appended');
    expect(request.method, 'GET');
    expect(request.url.path, '/api/v1/conversation-changes');
    expect(request.url.queryParameters, {'after_cursor': '4', 'limit': '2'});
    expect(request.headers['authorization'], 'Bearer forge-bearer');
  });

  test(
    'rejects owner-change responses that regress or expose bad cursors',
    () async {
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'token',
        httpClient: MockClient(
          (_) async => _json({
            'after_cursor': 4,
            'scanned_through_cursor': 9,
            'has_more': false,
            'changes': [
              {
                'cursor': 8,
                'schema_version': 1,
                'conversation_id': 'conversation-1',
                'entity_id': 'prompt-2',
                'aggregate_version': 2,
                'kind': 'prompt_appended',
                'created_at_ms': 30,
              },
              {
                'cursor': 7,
                'schema_version': 1,
                'conversation_id': 'foreign-conversation',
                'entity_id': 'prompt-1',
                'aggregate_version': 1,
                'kind': 'prompt_appended',
                'created_at_ms': 20,
              },
            ],
          }),
        ),
      );
      addTearDown(api.close);

      await expectLater(
        api.conversationChanges(afterCursor: 4),
        throwsFormatException,
      );
    },
  );

  test(
    'uses Forge conversation endpoints, bearer, cursor, and write keys',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [
              for (var index = 1; index <= 128; index++)
                {
                  'conversation': _conversation(
                    id: 'conversation-${index.toString().padLeft(3, '0')}',
                  ),
                  'aggregate_version': index,
                },
            ],
            'next_after_id': 'conversation-128',
            'has_more': true,
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/conversations') {
          return _json(_conversation(title: 'new'), status: 201);
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-1/prompts') {
          return _json({
            'conversation_id': 'conversation-1',
            'prompts': [_prompt()],
            'next_cursor': {'created_at_ms': 30, 'prompt_id': 'prompt-1'},
            'has_more': true,
          });
        }
        if (request.method == 'POST' &&
            request.url.path ==
                '/api/v1/conversations/conversation-1/prompts') {
          return _json({
            'prompt': _prompt(id: 'prompt-2', content: 'ship it'),
            'aggregate_version': 2,
            'replayed': false,
          }, status: 201);
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: client,
      );
      addTearDown(api.close);

      final conversations = await api.listConversations(
        afterID: 'conversation-0',
        limit: 999,
      );
      final created = await api.createConversation(
        scope: const ForgeConversationScope(kind: 'global'),
        title: 'new',
        idempotencyKey: 'create-key',
      );
      final prompts = await api.listPrompts(
        conversationID: 'conversation-1',
        before: const ForgePromptCursor(createdAtMS: 30, promptID: 'prompt-1'),
      );
      final appended = await api.appendPrompt(
        conversationID: 'conversation-1',
        content: 'ship it',
        expectedVersion: 1,
        idempotencyKey: 'prompt-key',
      );

      expect(conversations.conversations, hasLength(128));
      expect(conversations.conversations.first.aggregateVersion, 1);
      expect(conversations.nextAfterID, 'conversation-128');
      expect(created.title, 'new');
      expect(prompts.prompts.single.content, 'run tests');
      expect(appended.aggregateVersion, 2);
      expect(requests, hasLength(4));
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer forge-bearer');
        expect(request.headers['cache-control'], 'no-store');
        expect(request.followRedirects, isFalse);
        expect(request.url.queryParameters, isNot(contains('token')));
        expect(request.body, isNot(contains('forge-bearer')));
      }
      expect(requests[0].url.queryParameters, {
        'after_id': 'conversation-0',
        'limit': '128',
      });
      expect(jsonDecode(requests[1].body), {
        'scope': {'kind': 'global'},
        'title': 'new',
      });
      expect(requests[1].headers['idempotency-key'], 'create-key');
      expect(requests[2].url.queryParameters, {
        'before_created_at_ms': '30',
        'before_prompt_id': 'prompt-1',
        'limit': '100',
      });
      expect(jsonDecode(requests[3].body), {
        'content': 'ship it',
        'expected_version': 1,
      });
      expect(requests[3].headers['idempotency-key'], 'prompt-key');
    },
  );

  test(
    'refreshes once after 401 and preserves a prompt write identity',
    () async {
      final requests = <http.Request>[];
      var accessToken = 'old-access';
      var refreshCount = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'old-access',
        accessTokenProvider: () => accessToken,
        refreshAccessToken: (failedToken) async {
          refreshCount++;
          expect(failedToken, 'old-access');
          accessToken = 'new-access';
          return accessToken;
        },
        httpClient: MockClient((request) async {
          requests.add(request);
          if (requests.length == 1) {
            return _json({'code': 'unauthorized'}, status: 401);
          }
          return _json({
            'prompt': _prompt(id: 'prompt-2', content: 'ship it'),
            'aggregate_version': 2,
            'replayed': false,
          }, status: 201);
        }),
      );
      addTearDown(api.close);

      final result = await api.appendPrompt(
        conversationID: 'conversation-1',
        content: 'ship it',
        expectedVersion: 1,
        idempotencyKey: 'stable-prompt-key',
      );

      expect(result.prompt.content, 'ship it');
      expect(refreshCount, 1);
      expect(requests, hasLength(2));
      expect(requests[0].headers['authorization'], 'Bearer old-access');
      expect(requests[1].headers['authorization'], 'Bearer new-access');
      expect(requests[0].headers['idempotency-key'], 'stable-prompt-key');
      expect(requests[1].headers['idempotency-key'], 'stable-prompt-key');
      expect(requests[0].body, requests[1].body);
    },
  );

  test('does not loop when the refreshed token is also rejected', () async {
    var refreshCount = 0;
    var requestCount = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'old-access',
      refreshAccessToken: (_) async {
        refreshCount++;
        return 'new-access';
      },
      httpClient: MockClient((_) async {
        requestCount++;
        return _json({'code': 'unauthorized'}, status: 401);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.listConversations(),
      throwsA(isA<ForgeConversationsApiException>()),
    );

    expect(refreshCount, 1);
    expect(requestCount, 2);

    await expectLater(
      api.listConversations(),
      throwsA(isA<ForgeConversationsApiException>()),
    );
    expect(requestCount, 2);
  });

  test('surfaces Forge conflicts and refuses redirects', () async {
    final conflictApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient(
        (_) async => _json({
          'code': 'conflict',
          'message': 'aggregate version changed',
        }, status: 409),
      ),
    );
    addTearDown(conflictApi.close);
    await expectLater(
      conflictApi.listConversations(),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 409)
            .having((error) => error.code, 'code', 'conflict'),
      ),
    );

    final redirectApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient(
        (_) async => http.Response('', 302, headers: {'location': '/login'}),
      ),
    );
    addTearDown(redirectApi.close);
    await expectLater(
      redirectApi.listConversations(),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 502)
            .having((error) => error.code, 'code', 'redirect_rejected'),
      ),
    );
  });

  test('rejects prompt responses attributed to another conversation', () async {
    final historyApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient(
        (_) async => _json({
          'conversation_id': 'another-conversation',
          'prompts': <Object>[],
          'has_more': false,
        }),
      ),
    );
    addTearDown(historyApi.close);
    await expectLater(
      historyApi.listPrompts(conversationID: 'conversation-1'),
      throwsFormatException,
    );

    final appendApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient(
        (_) async => _json({
          'prompt': {
            ..._prompt(content: 'another prompt'),
            'conversation_id': 'another-conversation',
          },
          'aggregate_version': 2,
          'replayed': false,
        }, status: 201),
      ),
    );
    addTearDown(appendApi.close);
    await expectLater(
      appendApi.appendPrompt(
        conversationID: 'conversation-1',
        content: 'ship it',
        expectedVersion: 1,
        idempotencyKey: 'prompt-key',
      ),
      throwsFormatException,
    );
  });

  test('rejects unsafe origins and malformed bearer values', () {
    expect(
      () => ForgeConversationsApi(
        baseUrl: 'http://forge.example',
        accessToken: 'token',
      ),
      throwsArgumentError,
    );
    expect(
      () => ForgeConversationsApi(
        baseUrl: 'https://forge.example/path',
        accessToken: 'token',
      ),
      throwsArgumentError,
    );
    expect(
      () => ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'bad\ntoken',
      ),
      throwsArgumentError,
    );
  });
}
