import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_session_operation_models.dart';
import 'package:sso_admin/screens/agent/agent_session_history.dart';
import 'agent_session_creation_test.dart' show apiFor, response;

Map<String, dynamic> operationData({
  String operation = 'create',
  String status = 'queued',
  String id = 'r-1',
  String instance = 'i-1',
}) => {
  'operation': operation,
  'request_id': id,
  'instance_id': instance,
  'name': operation == 'create' ? 'Remote session' : '',
  'status': status,
  'session_id': operation == 'close' || status == 'created' ? 's-1' : '',
  'error_code': status == 'lost'
      ? 'owner_replaced'
      : status == 'failed'
      ? 'session_${operation == 'create' ? 'creation' : 'close'}_failed'
      : '',
  'created_at': 12,
  'updated_at': 14,
};

http.Response operationPage(
  List<Map<String, dynamic>> rows, {
  String cursor = '',
}) => http.Response(
  jsonEncode({'data': rows, 'next_cursor': cursor}),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  test(
    'history page is one bounded authenticated GET with opaque cursor',
    () async {
      final requests = <http.Request>[];
      final api = apiFor((request) async {
        requests.add(request);
        return operationPage([operationData()], cursor: 'next_A-1');
      });
      addTearDown(api.close);
      final page = await api.sessionOperations(
        instanceId: 'i-1',
        before: 'older',
        limit: 1,
      );
      expect(page.nextCursor, 'next_A-1');
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/agent/session-operations');
      expect(requests.single.url.queryParameters, {
        'instance_id': 'i-1',
        'before': 'older',
        'limit': '1',
      });
      expect(requests.single.body, isEmpty);
      expect(requests.single.headers['authorization'], startsWith('Bearer '));
      expect(requests.single.headers['idempotency-key'], isNull);
    },
  );

  for (final operation in ['create', 'close']) {
    for (final status in [
      'queued',
      operation == 'create' ? 'created' : 'closed',
      'failed',
      'lost',
    ]) {
      test('valid $operation $status receipt including C1 identifiers', () {
        final data = operationData(
          operation: operation,
          status: status,
          instance: 'host\u0080',
        );
        expect(AgentSessionOperation.fromJson(data).instanceId, 'host\u0080');
      });
    }
  }

  final invalidRecords = <String, Map<String, dynamic>>{
    'key leakage': {...operationData(), 'idempotency_key': 'private'},
    'missing name': {...operationData()}..remove('name'),
    'unknown operation': {...operationData(), 'operation': 'delete'},
    'wrong status': {...operationData(), 'status': 'closed'},
    'unknown error': {
      ...operationData(status: 'failed'),
      'error_code': 'private',
    },
    'uncreated session': {...operationData(), 'session_id': 's-1'},
    'close name': {...operationData(operation: 'close'), 'name': 'unexpected'},
    'close no target': {...operationData(operation: 'close'), 'session_id': ''},
    'padded identifier': {...operationData(), 'instance_id': ' i-1'},
    'C0 identifier': {...operationData(), 'instance_id': 'i\n1'},
    'DEL identifier': {...operationData(), 'request_id': 'r\u007f'},
    'long identifier': {...operationData(), 'request_id': 'x' * 257},
    'name controls': {...operationData(), 'name': 'name\u0085'},
    'long UTF8 name': {...operationData(), 'name': '界' * 86},
    'boolean time': {...operationData(), 'updated_at': true},
    'infinite time': {...operationData(), 'updated_at': double.infinity},
    'negative time': {...operationData(), 'created_at': -1},
  };
  for (final entry in invalidRecords.entries) {
    test('rejects ${entry.key}', () {
      expect(
        () => AgentSessionOperation.fromJson(entry.value),
        throwsFormatException,
      );
    });
  }

  final invalidPages = <String, Object>{
    'extra envelope': {'data': [], 'next_cursor': '', 'key': 'private'},
    'missing cursor': {'data': []},
    'empty with cursor': {'data': [], 'next_cursor': 'next'},
    'bad cursor': {
      'data': [operationData()],
      'next_cursor': 'with=',
    },
    'oversized cursor': {
      'data': [operationData()],
      'next_cursor': 'x' * 2049,
    },
    'repeat cursor': {
      'data': [operationData()],
      'next_cursor': 'old',
    },
    'wrong instance': {
      'data': [operationData(instance: 'other')],
      'next_cursor': '',
    },
    'duplicate': {
      'data': [operationData(), operationData()],
      'next_cursor': '',
    },
    'too many': {
      'data': List.generate(21, (i) => operationData(id: 'r-$i')),
      'next_cursor': '',
    },
  };
  for (final entry in invalidPages.entries) {
    test('page rejects ${entry.key}', () async {
      final api = apiFor(
        (_) async => http.Response(jsonEncode(entry.value), 200),
      );
      addTearDown(api.close);
      await expectLater(
        api.sessionOperations(instanceId: 'i-1', before: 'old'),
        throwsFormatException,
      );
    });
  }

  test('response cap and extreme JSON time fail closed', () async {
    for (final body in [
      'x' * (256 * 1024 + 1),
      jsonEncode({
        'data': [operationData()],
        'next_cursor': '',
      }).replaceFirst('12', '1e999'),
    ]) {
      final api = apiFor((_) async => http.Response(body, 200));
      await expectLater(
        api.sessionOperations(instanceId: 'i-1'),
        throwsA(isA<Exception>()),
      );
      api.close();
    }
  });

  test('bad input sends no network request', () async {
    var calls = 0;
    final api = apiFor((_) async {
      calls++;
      return operationPage([]);
    });
    addTearDown(api.close);
    await expectLater(
      api.sessionOperations(instanceId: 'i-1', before: 'invalid='),
      throwsFormatException,
    );
    await expectLater(
      api.sessionOperations(instanceId: '', limit: 20),
      throwsFormatException,
    );
    for (final limit in [0, 51]) {
      await expectLater(
        api.sessionOperations(instanceId: 'i-1', limit: limit),
        throwsFormatException,
      );
    }
    expect(calls, 0);
  });

  for (final operation in ['create', 'close']) {
    test(
      '$operation refresh uses original GET and binds immutable identity',
      () async {
        final current = AgentSessionOperation.fromJson(
          operationData(operation: operation, instance: 'i\u0080'),
        );
        final data = operationData(
          operation: operation,
          status: operation == 'create' ? 'created' : 'closed',
          instance: 'i\u0080',
        )..remove('operation');
        if (operation == 'close') data.remove('name');
        final api = apiFor((request) async {
          expect(request.method, 'GET');
          expect(
            request.url.path,
            endsWith(
              operation == 'create'
                  ? '/session-requests/r-1'
                  : '/session-close-requests/r-1',
            ),
          );
          return response(data);
        });
        addTearDown(api.close);
        expect((await api.refreshSessionOperation(current)).sessionId, 's-1');
        for (final change in [
          {'instance_id': 'other'},
          {'request_id': 'other'},
          {'created_at': 13},
          if (operation == 'create')
            {'name': 'other'}
          else
            {'session_id': 'other'},
          {'idempotency_key': 'private'},
        ]) {
          final bad = apiFor((_) async => response({...data, ...change}));
          await expectLater(
            bad.refreshSessionOperation(current),
            throwsFormatException,
          );
          bad.close();
        }
      },
    );
  }

  test(
    'controller replaces page, preserves cursor for retry, never auto polls',
    () async {
      final requests = <http.Request>[];
      var fail = true;
      final api = apiFor((request) async {
        requests.add(request);
        if (request.url.queryParameters['before'] == 'old') {
          if (fail) throw http.ClientException('private');
          return operationPage([operationData(id: 'older')]);
        }
        return operationPage([operationData()], cursor: 'old');
      });
      final history = AgentSessionHistory(api, 'i-1');
      addTearDown(() {
        history.dispose();
        api.close();
      });
      await history.load();
      expect(history.selected, isNull);
      await history.load(before: 'old');
      expect(history.error, isNot(contains('private')));
      fail = false;
      await history.retryPage();
      expect(history.page!.items.single.requestId, 'older');
      expect(requests.map((r) => r.method).toSet(), {'GET'});
      expect(requests.length, 3);
    },
  );

  test(
    'late detail cannot overwrite a newer selection or disposed controller',
    () async {
      final delayed = Completer<http.Response>();
      final api = apiFor(
        (request) async => request.url.path.endsWith('/session-operations')
            ? operationPage([operationData(), operationData(id: 'r-2')])
            : delayed.future,
      );
      final history = AgentSessionHistory(api, 'i-1');
      await history.load();
      history.select(history.page!.items.first);
      final pending = history.refreshSelected();
      history.select(history.page!.items.last);
      delayed.complete(
        response(operationData(status: 'created')..remove('operation')),
      );
      await pending;
      expect(history.selected!.requestId, 'r-2');
      expect(history.selected!.status, 'queued');
      history.dispose();
      api.close();
    },
  );
}
