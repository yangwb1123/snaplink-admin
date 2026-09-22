import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _intent({
  String intentID = 'intent-1',
  int submittedAtMS = 200,
}) => {
  'intent_id': intentID,
  'conversation_id': 'conversation-1',
  'prompt_id': 'prompt-1',
  'project_id': 'project-1',
  'profile_id': 'profile-1',
  'submitted_at_ms': submittedAtMS,
  'aggregate_version': 2,
  'latest_sequence': 1,
  'status': 'pending',
};

Map<String, dynamic> _event() => {
  'event_id': 'event-1',
  'seq': 1,
  'emitted_at_ms': 200,
  'type': 'submitted',
};

Map<String, dynamic> _submission({String content = 'run this'}) => {
  'prompt': {
    'id': 'prompt-1',
    'conversation_id': 'conversation-1',
    'role': 'user',
    'content': content,
    'created_at_ms': 200,
  },
  'intent': {..._intent(), 'submitted_at_ms': 200, 'aggregate_version': 3},
  'initial_event': _event(),
  'replayed': false,
};

void main() {
  test('submits a pending Run-intent with an idempotent inert write', () async {
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/conversations/conversation-1/run-intents',
        );
        expect(request.headers['authorization'], 'Bearer forge-bearer');
        expect(request.headers['idempotency-key'], 'intent-key');
        expect(jsonDecode(request.body), {
          'content': 'run this',
          'expected_version': 7,
        });
        return _json(_submission(), status: 201);
      }),
    );
    addTearDown(api.close);

    final result = await api.submitPendingRunIntent(
      conversationID: 'conversation-1',
      content: 'run this',
      expectedVersion: 7,
      idempotencyKey: 'intent-key',
    );

    expect(result.prompt.content, 'run this');
    expect(result.intent.status, 'pending');
    expect(result.replayed, isFalse);
    expect(requests, hasLength(1));
  });

  test(
    'candidate submit does not replay a 401 with a refreshed bearer',
    () async {
      var requests = 0;
      var refreshes = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'old-bearer',
        refreshAccessToken: (token) async {
          refreshes++;
          return 'new-bearer';
        },
        httpClient: MockClient((request) async {
          requests++;
          expect(request.method, 'POST');
          expect(request.headers['authorization'], 'Bearer old-bearer');
          return _json({
            'code': 'unauthorized',
            'message': 'expired',
          }, status: 401);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.submitPendingRunIntent(
          conversationID: 'conversation-1',
          content: 'run this',
          expectedVersion: 1,
          idempotencyKey: 'intent-key',
        ),
        throwsA(isA<ForgeConversationsApiException>()),
      );
      expect(requests, 1);
      expect(refreshes, 0);
    },
  );

  test(
    'rejects unsafe pending Run-intent submit inputs before transport',
    () async {
      var requests = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'token',
        httpClient: MockClient((_) async {
          requests++;
          return _json({});
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.submitPendingRunIntent(
          conversationID: 'conversation-1',
          content: 'run this',
          expectedVersion: 0,
          idempotencyKey: 'intent-key',
        ),
        throwsArgumentError,
      );
      await expectLater(
        api.submitPendingRunIntent(
          conversationID: 'conversation-1',
          content: 'run this',
          expectedVersion: 1,
          idempotencyKey: 'bad\nkey',
        ),
        throwsArgumentError,
      );
      expect(requests, 0);
    },
  );

  test('rejects pending Run-intent submission binding drift', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient((_) async => _json(_submission(content: 'other'))),
    );
    addTearDown(api.close);

    await expectLater(
      api.submitPendingRunIntent(
        conversationID: 'conversation-1',
        content: 'run this',
        expectedVersion: 1,
        idempotencyKey: 'intent-key',
      ),
      throwsFormatException,
    );
  });

  test('uses authenticated pending-intent list and timeline endpoints', () async {
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-1/run-intents') {
          return _json({
            'conversation_id': 'conversation-1',
            'intents': [_intent()],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-1/run-intents/intent-1/timeline') {
          final after = request.url.queryParameters['after_sequence'];
          if (after == '1') {
            return _json({
              'conversation_id': 'conversation-1',
              'intent_id': 'intent-1',
              'after_sequence': 1,
              'scanned_through_sequence': 1,
              'has_more': false,
              'events': <Object>[],
            });
          }
          return _json({
            'conversation_id': 'conversation-1',
            'intent_id': 'intent-1',
            'after_sequence': 0,
            'scanned_through_sequence': 1,
            'has_more': false,
            'events': [_event()],
          });
        }
        throw StateError('Unexpected pending Run-intent request: $request');
      }),
    );
    addTearDown(api.close);

    final list = await api.listPendingRunIntents(
      conversationID: 'conversation-1',
      limit: 25,
    );
    final initialTimeline = await api.listPendingRunIntentTimeline(
      conversationID: 'conversation-1',
      intentID: 'intent-1',
    );
    final emptyTimeline = await api.listPendingRunIntentTimeline(
      conversationID: 'conversation-1',
      intentID: 'intent-1',
      afterSequence: 1,
    );

    expect(list.intents.single.intentID, 'intent-1');
    expect(initialTimeline.events.single.type, 'submitted');
    expect(emptyTimeline.events, isEmpty);
    expect(requests, hasLength(3));
    expect(requests[0].url.queryParameters, {'limit': '25'});
    expect(requests[1].url.queryParameters, {
      'after_sequence': '0',
      'limit': '25',
    });
    expect(requests[2].url.queryParameters, {
      'after_sequence': '1',
      'limit': '25',
    });
    for (final request in requests) {
      expect(request.headers['authorization'], 'Bearer forge-bearer');
      expect(request.headers['cache-control'], 'no-store');
      expect(request.followRedirects, isFalse);
    }
  });

  test('rejects unsafe pending-intent inputs before transport', () async {
    var requests = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient((_) async {
        requests++;
        return _json({});
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.listPendingRunIntents(
        conversationID: 'conversation-1',
        before: const ForgePendingRunIntentCursor(
          submittedAtMS: 9007199254740992,
          intentID: 'intent-1',
        ),
      ),
      throwsArgumentError,
    );
    await expectLater(
      api.listPendingRunIntentTimeline(
        conversationID: 'conversation-1',
        intentID: 'intent/foreign',
      ),
      throwsArgumentError,
    );
    await expectLater(
      api.listPendingRunIntents(conversationID: 'conversation-1', limit: 26),
      throwsArgumentError,
    );
    await expectLater(
      api.listPendingRunIntentTimeline(
        conversationID: 'conversation-1',
        intentID: 'intent-1',
        limit: 0,
      ),
      throwsArgumentError,
    );

    expect(requests, 0);
  });

  test('rejects response binding drift and duplicate fields', () async {
    final bindingApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient(
        (_) async => _json({
          'conversation_id': 'conversation-other',
          'intents': [_intent()],
          'has_more': false,
        }),
      ),
    );
    addTearDown(bindingApi.close);
    await expectLater(
      bindingApi.listPendingRunIntents(conversationID: 'conversation-1'),
      throwsFormatException,
    );

    final duplicateApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"conversation_id":"conversation-1","intents":[],'
          '"has_more":false,"has_more":false}',
          200,
          headers: const {'content-type': 'application/json'},
        ),
      ),
    );
    addTearDown(duplicateApi.close);
    await expectLater(
      duplicateApi.listPendingRunIntents(conversationID: 'conversation-1'),
      throwsA(
        isA<ForgeConversationsApiException>().having(
          (error) => error.code,
          'code',
          'invalid_response',
        ),
      ),
    );
  });
}
