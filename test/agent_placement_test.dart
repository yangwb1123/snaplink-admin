import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_placement_models.dart';

Map<String, dynamic> placementDevice([String id = 'device-a']) => {
  'device_id': id,
  'instance_id': 'instance-a',
  'eligible': true,
  'reasons': [],
};

Map<String, dynamic> placementData({
  String state = 'queued',
  String cursor = '',
  List<Object>? devices,
}) => {
  'task_id': 'task-1',
  'state': state,
  'evaluated_at': 1789574400.25,
  'devices': devices ?? [placementDevice()],
  'next_cursor': cursor,
};

http.Response placementResponse(Object data, {int status = 200}) =>
    http.Response(
      jsonEncode({'data': data}),
      status,
      headers: {'content-type': 'application/json'},
    );

AgentHubApi placementApi(Future<http.Response> Function(http.Request) handle) =>
    AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'private-token',
      httpClient: MockClient(handle),
    );

void main() {
  test(
    'one GET binds task, cursor and size without write or retry headers',
    () async {
      final requests = <http.Request>[];
      final api = placementApi((request) async {
        requests.add(request);
        return placementResponse({...placementData(), 'task_id': 'task/一'});
      });
      addTearDown(api.close);
      final page = await api.taskPlacement(
        'task/一',
        after: 'device-0',
        limit: 3,
      );
      expect(page.taskId, 'task/一');
      expect(requests, hasLength(1));
      final request = requests.single;
      expect(request.method, 'GET');
      expect(request.url.pathSegments, [
        'api',
        'v1',
        'agent',
        'tasks',
        'task/一',
        'placement',
      ]);
      expect(request.url.queryParameters, {'after': 'device-0', 'limit': '3'});
      expect(request.body, isEmpty);
      expect(request.headers['authorization'], 'Bearer private-token');
      expect(request.headers.containsKey('idempotency-key'), isFalse);
    },
  );

  final mutations = <String, void Function(Map<String, dynamic>)>{
    'wrong task': (d) => d['task_id'] = 'other',
    'unknown field': (d) => d['private'] = 'hidden',
    'missing field': (d) => d.remove('evaluated_at'),
    'invalid state': (d) => d['state'] = 'ready',
    'boolean timestamp': (d) => d['evaluated_at'] = true,
    'negative timestamp': (d) => d['evaluated_at'] = -1,
    'string timestamp': (d) => d['evaluated_at'] = '1',
    'missing devices': (d) => d['devices'] = null,
    'too many rows': (d) =>
        d['devices'] = List.generate(21, (i) => placementDevice('d-$i')),
    'duplicate device': (d) =>
        d['devices'] = [placementDevice(), placementDevice()],
    'descending device': (d) =>
        d['devices'] = [placementDevice('b'), placementDevice('a')],
    'cursor outside page': (d) => d['next_cursor'] = 'device-b',
    'empty cursor rows': (d) {
      d['devices'] = [];
      d['next_cursor'] = 'device-a';
    },
    'not queued with rows': (d) => d['state'] = 'running',
    'device extra field': (d) =>
        (d['devices'] as List).single['private'] = true,
    'device missing field': (d) =>
        (d['devices'] as List).single.remove('instance_id'),
    'nonbool eligible': (d) => (d['devices'] as List).single['eligible'] = 1,
    'invalid reason': (d) =>
        (d['devices'] as List).single['reasons'] = ['private_error'],
    'duplicate reason': (d) => d['devices'] = [
      {
        ...placementDevice(),
        'eligible': false,
        'reasons': ['device_busy', 'device_busy'],
      },
    ],
    'eligible with reason': (d) =>
        (d['devices'] as List).single['reasons'] = ['device_busy'],
    'ineligible no reason': (d) =>
        (d['devices'] as List).single['eligible'] = false,
    'device control': (d) =>
        (d['devices'] as List).single['device_id'] = 'a\u0000b',
    'instance whitespace': (d) =>
        (d['devices'] as List).single['instance_id'] = ' i',
    'surrogate id': (d) =>
        (d['devices'] as List).single['device_id'] = '\uD800',
  };
  for (final entry in mutations.entries) {
    test('rejects ${entry.key}', () {
      final data = placementData();
      entry.value(data);
      expect(
        () => AgentTaskPlacement.fromJson(data, taskId: 'task-1'),
        throwsFormatException,
      );
    });
  }

  test('all task states accept empty nonqueued observations', () {
    for (final state in [
      'queued',
      'dispatching',
      'running',
      'cancel_requested',
      'completed',
      'failed',
      'cancelled',
      'lost',
    ]) {
      expect(
        AgentTaskPlacement.fromJson(
          placementData(state: state, devices: []),
          taskId: 'task-1',
        ).state,
        state,
      );
    }
  });
  test('all public reasons are accepted once with eligible false', () {
    final data = placementData(
      devices: [
        {
          ...placementDevice(),
          'eligible': false,
          'reasons': agentPlacementReasons.toList(),
        },
      ],
    );
    expect(
      AgentTaskPlacement.fromJson(
        data,
        taskId: 'task-1',
      ).devices.single.reasons,
      hasLength(16),
    );
  });
  test('Unicode scalar ordering and maximum scalar length match Hub', () {
    final high = String.fromCharCode(0x10000);
    final data = placementData(
      devices: [placementDevice('\uE000'), placementDevice(high)],
      cursor: high,
    );
    expect(
      AgentTaskPlacement.fromJson(data, taskId: 'task-1').nextCursor,
      high,
    );
    expect(validateAgentPlacementId(high * 256), high * 256);
    expect(() => validateAgentPlacementId(high * 257), throwsFormatException);
    expect(validateAgentPlacementId('x\u0080x'), 'x\u0080x');
  });
  test('rows must be after requested cursor and respect requested size', () {
    final data = placementData(
      devices: [placementDevice('a'), placementDevice('b')],
    );
    expect(
      () => AgentTaskPlacement.fromJson(data, taskId: 'task-1', after: 'a'),
      throwsFormatException,
    );
    expect(
      () => AgentTaskPlacement.fromJson(data, taskId: 'task-1', limit: 1),
      throwsFormatException,
    );
  });
  test('invalid local arguments never send a request', () async {
    var count = 0;
    final api = placementApi((_) async {
      count++;
      return placementResponse(placementData());
    });
    addTearDown(api.close);
    for (final id in ['', 'x\n', ' x', '\uD800', 'x' * 257]) {
      await expectLater(api.taskPlacement(id), throwsFormatException);
    }
    await expectLater(
      api.taskPlacement('task-1', after: '\u0000'),
      throwsFormatException,
    );
    for (final limit in [0, 21]) {
      await expectLater(
        api.taskPlacement('task-1', limit: limit),
        throwsFormatException,
      );
    }
    expect(count, 0);
  });
  for (final body in [
    '{"data":{},"data":{}}',
    '{"data":${jsonEncode(placementData())},"private":1}',
    jsonEncode({
      'data': {...placementData(), 'evaluated_at': 1},
    }).replaceFirst(
      '"evaluated_at":1',
      '"evaluated_at":1,"evaluated_\\u0061t":1',
    ),
    '{"data":${jsonEncode(placementData()).replaceFirst('"eligible":true', '"eligible":true,"eligible":true')}}',
    '[]',
    '{"data":null}',
    '{"data":${jsonEncode(placementData()).replaceFirst('1789574400.25', '1e999')}}',
  ]) {
    test(
      'rejects malformed or ambiguous wire response ${body.hashCode}',
      () async {
        final api = placementApi((_) async => http.Response(body, 200));
        addTearDown(api.close);
        await expectLater(api.taskPlacement('task-1'), throwsFormatException);
      },
    );
  }
  test(
    'strings containing object punctuation are not mistaken for keys',
    () async {
      final api = placementApi(
        (_) async => placementResponse(
          placementData(devices: [placementDevice('a{"b":1}\\')]),
        ),
      );
      addTearDown(api.close);
      expect((await api.taskPlacement('task-1')).devices, hasLength(1));
    },
  );
  for (final status in [201, 204, 302]) {
    test('rejects unexpected success or redirect $status', () async {
      final api = placementApi(
        (_) async => placementResponse(placementData(), status: status),
      );
      addTearDown(api.close);
      await expectLater(api.taskPlacement('task-1'), throwsA(anything));
    });
  }
  for (final declared in [true, false]) {
    test('64 KiB response cap with contentLength $declared', () async {
      final api = AgentHubApi(
        baseUrl: 'https://hub.example',
        accessToken: 'token',
        httpClient: MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            Stream.fromIterable([
              List.filled(32768, 32),
              List.filled(32769, 32),
            ]),
            200,
            contentLength: declared ? 65537 : null,
          ),
        ),
      );
      addTearDown(api.close);
      await expectLater(
        api.taskPlacement('task-1'),
        throwsA(
          isA<AgentHubApiException>().having(
            (e) => e.code,
            'code',
            'response_too_large',
          ),
        ),
      );
    });
  }
  test('invalid UTF8 is rejected', () async {
    final api = AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      httpClient: MockClient.streaming(
        (_, _) async => http.StreamedResponse(Stream.value([0xff]), 200),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.taskPlacement('task-1'),
      throwsA(isA<AgentHubApiException>()),
    );
  });
  test('401 diagnostic never invokes shared global logout callback', () async {
    var called = false;
    final api = AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'old',
      onUnauthorized: (_) => called = true,
      httpClient: MockClient((_) async => http.Response('private', 401)),
    );
    addTearDown(api.close);
    await expectLater(
      api.taskPlacement('task-1'),
      throwsA(isA<AgentHubApiException>()),
    );
    expect(called, isFalse);
  });
}
