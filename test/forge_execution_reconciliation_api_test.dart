import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';

void main() {
  test('posts one path-bound execution reconciliation preview', () async {
    final input = _input();
    final expected = observeForgeExecutionReconciliation(input);
    final sent = <Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        sent.add(request);
        return _json(expected.toJson());
      }),
    );
    addTearDown(api.close);

    final returned = await api.previewExecutionReconciliation(
      conversationID: 'conversation-1',
      runID: 'run-1',
      input: input,
    );

    expect(returned.toJson(), expected.toJson());
    expect(sent, hasLength(1));
    expect(sent.single.method, 'POST');
    expect(
      sent.single.url.path,
      '/api/v1/conversations/conversation-1/runs/run-1/'
      'execution-reconciliation/preview',
    );
    expect(sent.single.headers['authorization'], 'Bearer forge-bearer');
    expect(jsonDecode(sent.single.body), input.toJson());
  });

  test('rejects response classification and binding drift', () async {
    final input = _input();
    final foreign = observeForgeExecutionReconciliation(input).toJson();
    foreign['run_id'] = 'run-foreign';
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient((_) async => _json(foreign)),
    );
    addTearDown(api.close);
    await expectLater(
      api.previewExecutionReconciliation(
        conversationID: 'conversation-1',
        runID: 'run-1',
        input: input,
      ),
      throwsA(isA<FormatException>()),
    );

    final invalid = observeForgeExecutionReconciliation(input).toJson();
    invalid['next_observation'] = 'terminal_uncertain';
    final invalidApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient((_) async => _json(invalid)),
    );
    addTearDown(invalidApi.close);
    await expectLater(
      invalidApi.previewExecutionReconciliation(
        conversationID: 'conversation-1',
        runID: 'run-1',
        input: input,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('does not replay the candidate POST after a 401', () async {
    var calls = 0;
    var refreshes = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      refreshAccessToken: (_) async {
        refreshes++;
        return 'rotated';
      },
      httpClient: MockClient((_) async {
        calls++;
        return _json({
          'code': 'unauthorized',
          'message': 'private',
        }, status: 401);
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.previewExecutionReconciliation(
        conversationID: 'conversation-1',
        runID: 'run-1',
        input: _input(),
      ),
      throwsA(
        isA<ForgeConversationsApiException>().having(
          (error) => error.statusCode,
          'status',
          401,
        ),
      ),
    );
    expect(calls, 1);
    expect(refreshes, 0);
  });

  test(
    'rejects input that is not bound to the selected path before request',
    () async {
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'token',
        httpClient: MockClient((_) async {
          calls++;
          return _json(observeForgeExecutionReconciliation(_input()).toJson());
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.previewExecutionReconciliation(
          conversationID: 'conversation-foreign',
          runID: 'run-1',
          input: _input(),
        ),
        throwsA(isA<FormatException>()),
      );
      expect(calls, 0);
    },
  );
}

Response _json(Object value, {int status = 200}) => Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

ForgeExecutionReconciliationInput _input() =>
    ForgeExecutionReconciliationInput.fromJson({
      'owner': {
        'issuer': 'https://id.example.test',
        'subject': 'user-1',
        'tenant_id': 'tenant-1',
      },
      'conversation_id': 'conversation-1',
      'run_id': 'run-1',
      'attempt_id': 'attempt-1',
      'command_id': 'command-1',
      'target_id': 'runner-1',
      'run_status': 'nonterminal',
      'attempt_state': 'running',
      'lease': {
        'v': 1,
        'attempt_id': 'attempt-1',
        'target_id': 'runner-1',
        'epoch': 1,
        'fencing_token': 'fence-1',
        'issued_at_ms': 100,
        'expires_at_ms': 10100,
      },
      'observed_at_ms': 200,
      'terminal': null,
    });
