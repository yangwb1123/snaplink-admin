import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/api/agent_session_close_models.dart';
import 'package:sso_admin/screens/agent/agent_session_closure.dart';

import 'agent_session_creation_test.dart' show apiFor, response;

Map<String, dynamic> closeData({
  String status = 'queued',
  String session = 's-1',
}) => {
  'request_id': 'r-1',
  'instance_id': 'i-1',
  'session_id': session,
  'status': status,
  'error_code': status == 'failed'
      ? 'session_close_failed'
      : status == 'lost'
      ? 'owner_replaced'
      : '',
  'created_at': 1,
  'updated_at': 2,
};

http.Response closeError(String code, {int status = 409}) => http.Response(
  jsonEncode({
    'error': {'code': code, 'message': 'raw-private-error'},
  }),
  status,
);

void main() {
  test(
    'close capability defaults false independently of creation capacity',
    () {
      expect(
        AgentInstance.fromJson({
          'instance_id': 'old',
          'session_capacity': 8,
        }).sessionCloseSupported,
        false,
      );
      expect(
        AgentInstance.fromJson({
          'instance_id': 'new',
          'session_close_supported': true,
        }).sessionCloseSupported,
        true,
      );
      for (final value in [1, 'true', <Object>[]]) {
        expect(
          () => AgentInstance.fromJson({
            'instance_id': 'bad',
            'session_close_supported': value,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test('close DTO requires exact safe identity, outcomes and timestamps', () {
    for (final status in ['queued', 'closed', 'failed', 'lost']) {
      expect(
        AgentSessionCloseRequest.fromJson(closeData(status: status)).status,
        status,
      );
    }
    for (final patch in <String, dynamic>{
      'request_id': '',
      'instance_id': 'x\n',
      'session_id': '机' * 257,
      'status': 'created',
      'error_code': 'unexpected',
      'created_at': double.infinity,
      'updated_at': -1,
      'extra': 'override',
    }.entries) {
      expect(
        () => AgentSessionCloseRequest.fromJson({
          ...closeData(),
          patch.key: patch.value,
        }),
        throwsFormatException,
      );
    }
    for (final status in ['failed', 'lost']) {
      expect(
        () => AgentSessionCloseRequest.fromJson({
          ...closeData(status: status),
          'error_code': '',
        }),
        throwsFormatException,
      );
    }
    expect(
      () =>
          AgentSessionCloseRequest.fromJson(closeData()..remove('session_id')),
      throwsFormatException,
    );
    expect(
      () => AgentSessionCloseRequest.fromJson({
        ...closeData(status: 'lost'),
        'error_code': 'session_close_failed',
      }),
      throwsFormatException,
    );
  });

  test(
    'wire close uses exact empty JSON and tracking is an authenticated GET',
    () async {
      final sent = <http.Request>[];
      final api = apiFor((request) async {
        sent.add(request);
        return response(
          closeData(status: request.method == 'POST' ? 'queued' : 'closed'),
          status: request.method == 'POST' ? 202 : 200,
        );
      });
      addTearDown(api.close);
      await api.closeSession(sessionId: 's-1', idempotencyKey: 'stable-key');
      expect((await api.sessionCloseRequest('r-1')).status, 'closed');
      expect(sent[0].url.path, '/api/v1/agent/sessions/s-1/close');
      expect(sent[0].body, '{}');
      expect(sent[0].headers['idempotency-key'], 'stable-key');
      expect(
        sent[0].headers['authorization'],
        'Bearer never-display-this-token',
      );
      expect(sent[0].followRedirects, false);
      expect(sent[1].method, 'GET');
      expect(sent[1].url.path, '/api/v1/agent/session-close-requests/r-1');
      expect(sent[1].body, '');
      expect(sent.every((item) => item.url.query.isEmpty), true);
    },
  );

  test(
    'API rejects wrong status, target, redirected and oversized responses without retry',
    () async {
      for (final result in [
        response(closeData(), status: 200),
        response(closeData(session: 'other'), status: 202),
        response({...closeData(), 'extra': 'x' * 32768}, status: 202),
        response(closeData(), status: 302),
      ]) {
        var calls = 0;
        final api = apiFor((_) async {
          calls++;
          return result;
        });
        await expectLater(
          api.closeSession(sessionId: 's-1', idempotencyKey: 'key'),
          throwsA(isA<Exception>()),
        );
        expect(calls, 1);
        api.close();
      }
      final api = apiFor(
        (_) async => response({...closeData(), 'request_id': 'other'}),
      );
      addTearDown(api.close);
      await expectLater(api.sessionCloseRequest('r-1'), throwsFormatException);
    },
  );

  test('invalid IDs and keys are rejected before transport', () async {
    final api = apiFor((_) async => throw StateError('must not send'));
    addTearDown(api.close);
    for (final key in ['', 'a b', 'a\r', '中', 'k' * 257]) {
      await expectLater(
        api.closeSession(sessionId: 's-1', idempotencyKey: key),
        throwsFormatException,
      );
    }
    for (final id in ['', ' padded ', 'bad\n', '\ud800']) {
      await expectLater(
        api.closeSession(sessionId: id, idempotencyKey: 'key'),
        throwsFormatException,
      );
    }
  });

  test(
    'close identifiers follow Hub character limits rather than UTF-8 name limits',
    () {
      final instance = '${'机' * 254}\u0085x';
      expect(
        AgentSessionCloseRequest.fromJson({
          ...closeData(),
          'instance_id': instance,
        }).instanceId,
        instance,
      );
      expect(() => validateAgentCloseId('机' * 257), throwsFormatException);
      expect(() => validateAgentCloseId('bad\u007f'), throwsFormatException);
      expect(validateAgentCloseId('机' * 256), '机' * 256);
    },
  );

  test(
    'unknown retry through later denial retains exact target/key; queued uses GET only',
    () async {
      final sent = <http.Request>[];
      final api = apiFor((request) async {
        sent.add(request);
        if (sent.length == 1) throw http.ClientException('raw-private-error');
        if (sent.length == 2) {
          return closeError('insufficient_scope', status: 403);
        }
        if (sent.length == 4) return closeError('unavailable', status: 503);
        return response(
          closeData(status: request.method == 'GET' ? 'closed' : 'queued'),
          status: request.method == 'GET' ? 200 : 202,
        );
      });
      final closure = AgentSessionClosure(
        api,
        pollInterval: const Duration(days: 1),
      );
      addTearDown(closure.dispose);
      addTearDown(api.close);
      await closure.submit('s-1', 'i-1', 'First');
      final key = closure.idempotencyKey;
      expect(closure.error, isNot(contains('raw-private')));
      await closure.submit('s-2', 'i-1', 'Other');
      expect(sent.length, 1);
      await closure.submit('s-1', 'i-1', 'First');
      expect(closure.idempotencyKey, key);
      await closure.submit('s-2', 'i-1', 'Other');
      expect(sent.length, 2);
      await closure.submit('s-1', 'i-1', 'First');
      expect(
        sent
            .take(3)
            .every(
              (item) =>
                  item.headers['idempotency-key'] == key &&
                  item.body == '{}' &&
                  item.url.path.endsWith('/s-1/close'),
            ),
        true,
      );
      await closure.submit('s-1', 'i-1', 'First');
      expect(sent.length, 3);
      await closure.refresh();
      expect(closure.queued, true);
      expect(closure.error, isNotNull);
      await closure.refresh();
      expect(closure.request!.status, 'closed');
      expect(sent.skip(3).every((item) => item.method == 'GET'), true);
      await closure.refresh();
      expect(sent.length, 5);
    },
  );

  test(
    'fresh definitive refusal releases key, but authentication ambiguity retains it',
    () async {
      for (final code in [
        'session_busy',
        'session_close_unsupported',
        'session_close_failed',
        'unauthorized',
      ]) {
        final api = apiFor(
          (_) async =>
              closeError(code, status: code == 'unauthorized' ? 401 : 409),
        );
        final closure = AgentSessionClosure(api);
        await closure.submit('s-1', 'i-1', 'First');
        expect(closure.hasInput, code == 'unauthorized');
        expect(closure.error, isNot(contains('raw-private')));
        closure.dispose();
        api.close();
      }
    },
  );

  test(
    'wrong instance and polling target cannot replace the fixed workflow',
    () async {
      var calls = 0;
      final api = apiFor((_) async {
        calls++;
        return response({
          ...closeData(),
          if (calls == 1) 'instance_id': 'other',
          if (calls == 3) 'session_id': 'other',
        }, status: calls <= 2 ? 202 : 200);
      });
      final closure = AgentSessionClosure(
        api,
        pollInterval: const Duration(days: 1),
      );
      addTearDown(closure.dispose);
      addTearDown(api.close);
      await closure.submit('s-1', 'i-1', 'First');
      expect(closure.request, null);
      expect(closure.hasInput, true);
      await closure.submit('s-1', 'i-1', 'First');
      await closure.refresh();
      expect(closure.request!.sessionId, 's-1');
      expect(closure.error, isNotNull);
    },
  );

  test(
    'disposing with an in-flight close does not notify or schedule polling',
    () async {
      final delayed = Completer<http.Response>();
      final api = apiFor((_) => delayed.future);
      final closure = AgentSessionClosure(api);
      var notifications = 0;
      closure.addListener(() => notifications++);
      final pending = closure.submit('s-1', 'i-1', 'First');
      closure.dispose();
      delayed.complete(response(closeData(), status: 202));
      await pending;
      expect(notifications, 1);
      api.close();
    },
  );
}
