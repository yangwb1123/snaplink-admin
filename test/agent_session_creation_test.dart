import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/api/agent_session_creation_models.dart';
import 'package:sso_admin/screens/agent/agent_session_creation.dart';

Map<String, dynamic> requestData({String status = 'queued'}) => {
  'request_id': 'r-1',
  'instance_id': 'i-1',
  'name': '分析任务',
  'status': status,
  'session_id': status == 'created' ? 's-1' : '',
  'error_code': status == 'failed' ? 'session_creation_failed' : '',
  'created_at': 1,
  'updated_at': 2,
};
http.Response response(Object data, {int status = 200}) => http.Response(
  jsonEncode({'data': data}),
  status,
  headers: {'content-type': 'application/json'},
);
AgentHubApi apiFor(Future<http.Response> Function(http.Request) send) =>
    AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'never-display-this-token',
      httpClient: MockClient(send),
    );

void main() {
  test(
    'capacity defaults to unsupported and rejects malformed advertisements',
    () {
      expect(AgentInstance.fromJson({'instance_id': 'old'}).sessionCapacity, 0);
      expect(
        AgentInstance.fromJson({
          'instance_id': 'new',
          'session_capacity': 8,
        }).sessionCapacity,
        8,
      );
      for (final invalid in [-1, 9, 1.5, true, '8']) {
        expect(
          () => AgentInstance.fromJson({
            'instance_id': 'bad',
            'session_capacity': invalid,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('name uses UTF-8 bound and rejects controls and malformed Unicode', () {
    expect(validateAgentSessionName('  分析任务  '), '分析任务');
    expect(validateAgentSessionName('é' * 128), 'é' * 128);
    for (final invalid in [
      '',
      ' ',
      '界' * 86,
      'a\u0000b',
      'a\u0085b',
      '\nname',
      'name\t',
      '\u200bname',
      '\u202ename',
      '\ud800',
    ]) {
      expect(() => validateAgentSessionName(invalid), throwsFormatException);
    }
  });

  test('request response rejects missing, contradictory or unsafe fields', () {
    for (final patch in <String, dynamic>{
      'request_id': '',
      'instance_id': 1,
      'name': ' padded ',
      'status': 'running',
      'session_id': 'unexpected',
      'error_code': 'untrusted',
      'created_at': double.nan,
      'updated_at': -1,
    }.entries) {
      expect(
        () => AgentSessionCreationRequest.fromJson({
          ...requestData(),
          patch.key: patch.value,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => AgentSessionCreationRequest.fromJson(
        requestData(status: 'created')..['session_id'] = '',
      ),
      throwsFormatException,
    );
    for (final status in ['failed', 'lost']) {
      expect(
        () => AgentSessionCreationRequest.fromJson({
          ...requestData(status: status),
          'error_code': '',
        }),
        throwsFormatException,
      );
    }
    final unicodeId = '机' * 256;
    expect(
      AgentSessionCreationRequest.fromJson({
        ...requestData(),
        'instance_id': unicodeId,
      }).instanceId,
      unicodeId,
    );
    final c1ID = 'runner\u0090';
    expect(
      AgentSessionCreationRequest.fromJson({
        ...requestData(),
        'instance_id': c1ID,
      }).instanceId,
      c1ID,
    );
    expect(
      () => AgentSessionCreationRequest.fromJson({
        ...requestData(),
        'instance_id': '机' * 257,
      }),
      throwsFormatException,
    );
    expect(
      () => AgentSessionCreationRequest.fromJson({
        ...requestData(),
        'private_retry_key': 'must not cross the history boundary',
      }),
      throwsFormatException,
    );
  });

  test(
    'creation and detail IDs are validated before any network request',
    () async {
      var calls = 0;
      final api = apiFor((_) async {
        calls++;
        return response(requestData(), status: 202);
      });
      addTearDown(api.close);
      for (final invalid in [' ', 'id\u0000', 'id\u007f', 'x' * 257]) {
        await expectLater(
          api.createSession(
            instanceId: invalid,
            name: '分析任务',
            idempotencyKey: 'key',
          ),
          throwsFormatException,
        );
        await expectLater(api.sessionRequest(invalid), throwsFormatException);
      }
      expect(calls, 0);
    },
  );

  test(
    'wire contract sends only the fixed name and GET tracks exact request',
    () async {
      final sent = <http.Request>[];
      final api = apiFor((request) async {
        sent.add(request);
        return response(
          requestData(status: request.method == 'GET' ? 'created' : 'queued'),
          status: request.method == 'POST' ? 202 : 200,
        );
      });
      addTearDown(api.close);
      await api.createSession(
        instanceId: 'i-1',
        name: ' 分析任务 ',
        idempotencyKey: 'key',
      );
      expect((await api.sessionRequest('r-1')).sessionId, 's-1');
      expect(sent[0].url.path, '/api/v1/agent/instances/i-1/sessions');
      expect(sent[0].headers['idempotency-key'], 'key');
      expect(
        sent[0].headers['authorization'],
        'Bearer never-display-this-token',
      );
      expect(sent[0].followRedirects, false);
      expect(jsonDecode(sent[0].body), {'name': '分析任务'});
      expect(sent[1].url.path, '/api/v1/agent/session-requests/r-1');
      expect(sent[1].body, '');
      expect(sent[1].url.query, '');
    },
  );

  test(
    'creation rejects non-202, mismatched input and oversized response',
    () async {
      for (final result in [
        response(requestData(), status: 200),
        response({...requestData(), 'instance_id': 'other'}, status: 202),
        response({...requestData(), 'extra': 'x' * 32768}, status: 202),
        response(requestData(), status: 302),
      ]) {
        var calls = 0;
        final api = apiFor((_) async {
          calls++;
          return result;
        });
        await expectLater(
          api.createSession(
            instanceId: 'i-1',
            name: '分析任务',
            idempotencyKey: 'key',
          ),
          throwsA(isA<Exception>()),
        );
        expect(calls, 1);
        api.close();
      }
    },
  );

  test(
    'unknown POST retry retains input/key and never automatically repeats',
    () async {
      final sent = <http.Request>[];
      final api = apiFor((request) async {
        sent.add(request);
        if (sent.length == 1) throw http.ClientException('raw-token-error');
        if (sent.length == 2) {
          return http.Response(
            jsonEncode({
              'error': {'code': 'insufficient_scope', 'message': 'raw-secret'},
            }),
            403,
          );
        }
        return response(requestData(), status: 202);
      });
      final creation = AgentSessionCreation(
        api,
        pollInterval: const Duration(days: 1),
      );
      addTearDown(creation.dispose);
      addTearDown(api.close);
      await creation.submit('i-1', '分析任务');
      final key = creation.idempotencyKey;
      expect(creation.error, isNot(contains('raw-token-error')));
      await creation.submit('i-2', 'other');
      expect(sent.length, 1);
      await creation.submit('i-1', '分析任务');
      expect(sent.length, 2);
      expect(sent[1].headers['idempotency-key'], key);
      expect(sent[0].body, sent[1].body);
      expect(creation.idempotencyKey, key);
      await creation.submit('i-2', 'other');
      expect(sent.length, 2);
      await creation.submit('i-1', '分析任务');
      expect(sent.length, 3);
      expect(sent[2].headers['idempotency-key'], key);
      expect(sent[2].body, sent[0].body);
      await creation.submit('i-1', '分析任务');
      expect(sent.length, 3);
    },
  );

  test(
    'definite capacity rejection releases input but 401 keeps key',
    () async {
      for (final status in [409, 401]) {
        final api = apiFor(
          (_) async => http.Response(
            jsonEncode({
              'error': {
                'code': status == 409 ? 'session_capacity' : 'unauthorized',
                'message': 'raw-secret',
              },
            }),
            status,
          ),
        );
        final creation = AgentSessionCreation(api);
        await creation.submit('i-1', '分析任务');
        expect(creation.hasInput, status == 401);
        expect(creation.error, isNot(contains('raw-secret')));
        creation.dispose();
        api.close();
      }
    },
  );

  test(
    'concurrent submits single flight and known read failures only retry GET',
    () async {
      final accepted = Completer<http.Response>();
      final methods = <String>[];
      final api = apiFor((request) async {
        methods.add(request.method);
        if (request.method == 'POST') return accepted.future;
        if (methods.length == 2) throw http.ClientException('private-error');
        return response(requestData(status: 'created'));
      });
      final creation = AgentSessionCreation(
        api,
        pollInterval: const Duration(days: 1),
      );
      addTearDown(creation.dispose);
      addTearDown(api.close);
      final first = creation.submit('i-1', '分析任务');
      await creation.submit('i-1', '分析任务');
      accepted.complete(response(requestData(), status: 202));
      await first;
      await creation.refresh();
      expect(creation.request!.status, 'queued');
      expect(creation.error, isNot(contains('private-error')));
      await creation.refresh();
      expect(creation.request!.status, 'created');
      expect(methods, ['POST', 'GET', 'GET']);
      creation.reset();
      expect(creation.hasInput, false);
    },
  );

  testWidgets('terminal result stops polling', (tester) async {
    final methods = <String>[];
    final api = apiFor((request) async {
      methods.add(request.method);
      return response(
        requestData(status: request.method == 'GET' ? 'created' : 'queued'),
        status: request.method == 'POST' ? 202 : 200,
      );
    });
    final creation = AgentSessionCreation(api);
    await tester.runAsync(() => creation.submit('i-1', '分析任务'));
    // The HTTP completion schedules the timer in runAsync's real zone.
    await tester.runAsync(() => creation.refresh());
    await tester.pump(const Duration(seconds: 10));
    expect(methods, ['POST', 'GET']);
    creation.dispose();
    api.close();
  });
}
