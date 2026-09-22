import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_compute_models.dart';

http.Response jsonResponse(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  test(
    'uses the Agent Hub contract and unwraps accepted turn envelopes',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/instances')) {
          return jsonResponse({
            'data': [
              {'instance_id': 'i-1', 'name': 'Build host', 'online': true},
            ],
            'next_cursor': 'i-1',
          });
        }
        if (path.endsWith('/sessions')) {
          return jsonResponse({
            'data': [
              {
                'session_id': 's-1',
                'instance_id': 'i-1',
                'local_session_id': 'local-1',
                'controllable': true,
              },
            ],
            'next_cursor': 's-1',
          });
        }
        if (path.endsWith('/events')) {
          return jsonResponse({
            'data': [
              {
                'cursor': 7,
                'event_id': 'e-7',
                'session_id': 's-1',
                'turn_id': 't-1',
                'kind': 'turn.queued',
                'created_at': 1789200000,
                'payload': {'text': 'do work', 'actor': 'alice'},
              },
            ],
            'next_cursor': 7,
          });
        }
        if (path.endsWith('/turns/t-1/cancel')) {
          expect(request.method, 'POST');
          expect(request.body, '{}');
          return jsonResponse({
            'data': {
              'turn_id': 't-1',
              'status': 'cancel_requested',
              'session_id': 's-1',
            },
          }, status: 202);
        }
        if (path.endsWith('/sessions/s-1/turns')) {
          expect(request.method, 'POST');
          expect(
            request.headers['idempotency-key'],
            matches(RegExp(r'^[0-9a-f-]{36}$')),
          );
          expect(jsonDecode(request.body), {'prompt': 'do work'});
          return jsonResponse({
            'data': {'turn_id': 't-1', 'state': 'queued', 'session_id': 's-1'},
          }, status: 202);
        }
        if (path.endsWith('/sessions/s-1')) {
          return jsonResponse({
            'data': {
              'session_id': 's-1',
              'instance_id': 'i-1',
              'local_session_id': 'local-1',
              'controllable': true,
              'active_turn_id': 't-1',
            },
          });
        }
        if (path.endsWith('/turns/t-1')) {
          return jsonResponse({
            'data': {'turn_id': 't-1', 'state': 'running', 'session_id': 's-1'},
          });
        }
        throw StateError('Unexpected request: $request');
      });
      final api = AgentHubApi(
        baseUrl: 'https://hub.example',
        accessToken: 'test-bearer',
        httpClient: client,
      );
      addTearDown(api.close);

      final instances = await api.listInstances();
      expect(instances.items.single.instanceId, 'i-1');
      expect(instances.nextCursor, 'i-1');
      final sessions = await api.listSessions(instanceId: 'i-1');
      expect(sessions.items.single.sessionId, 's-1');
      final detail = await api.getSession('s-1');
      expect(detail.activeTurnId, 't-1');
      final turn = await api.submitPrompt(
        sessionId: 's-1',
        prompt: 'do work',
        idempotencyKey: '2a72c2fd-bf87-42a3-a134-4637108f6c2a',
      );
      expect(turn.state, 'queued');
      final page = await api.listEvents(sessionId: 's-1', after: 0, limit: 500);
      expect(page.events.single.text, 'do work');
      expect(page.events.single.payload['actor'], 'alice');
      expect(page.events.single.createdAt, isNotNull);
      expect(page.nextCursor, 7);
      final loadedTurn = await api.getTurn('t-1');
      expect(loadedTurn.state, 'running');
      expect((await api.cancelTurn('t-1')).state, 'cancel_requested');

      expect(requests, hasLength(7));
      for (final request in requests) {
        expect(request.headers['authorization'], 'Bearer test-bearer');
        expect(request.url.queryParameters, isNot(contains('token')));
        expect(request.followRedirects, isFalse);
      }
      expect(requests[0].url.queryParameters, {'limit': '200'});
      expect(requests[1].url.queryParameters, {
        'instance_id': 'i-1',
        'limit': '200',
      });
      expect(requests[4].url.queryParameters, {'after': '0', 'limit': '100'});
    },
  );

  test('continues opaque list cursors and caps page size at 200', () async {
    late http.Request captured;
    final api = AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      httpClient: MockClient((request) async {
        captured = request;
        return jsonResponse({'data': [], 'next_cursor': null});
      }),
    );
    addTearDown(api.close);

    await api.listSessions(
      instanceId: 'i-1',
      after: 'session-token/opaque',
      limit: 500,
    );
    expect(captured.url.queryParameters, {
      'instance_id': 'i-1',
      'after': 'session-token/opaque',
      'limit': '200',
    });
  });

  test(
    'uses the frozen compute endpoints and preserves task evidence',
    () async {
      final requests = <http.Request>[];
      Map<String, dynamic> task(String state) => {
        'task_id': 'task-1',
        'session_id': 'session-1',
        'instance_id': 'instance-1',
        'turn_id': 'turn-1',
        'actor': 'alice',
        'project_id': 'project-1',
        'state': state,
        'device_id': 'device-1',
        'device_instance_id': 'instance-2',
        'argv': ['python', '-c', "import sys; sys.stdout.write('1\\n')"],
        'workdir': 'src',
        'timeout': 60,
        'resources': {'cpu_cores': 2, 'memory_bytes': 1048576},
        'requirements': {
          'os': 'linux',
          'architecture': 'x86_64',
          'runtimes': ['python'],
        },
        'created_at': '2026-09-12T12:00:00Z',
        'updated_at': '2026-09-12T12:01:00Z',
        'error': '',
        'result': {
          'exit_code': 0,
          'timed_out': false,
          'cancelled': false,
          'stdout': 'ok',
          'stderr': '',
          'output_truncated': true,
          'elapsed': 1.5,
          'evidence_digest': 'sha256:abc',
        },
        'archive_state': 'archived',
        'artifact_ref': {
          'backend': 'aero-vault',
          'key': 'project/task-1',
          'version_id': 'v1',
          'etag': 'e1',
          'sha256': 'sha256:def',
          'size': 2,
          'bucket': 'evidence',
        },
      };
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path.endsWith('/devices')) {
          return jsonResponse({
            'data': [
              {
                'device_id': 'device-1',
                'instance_id': 'instance-2',
                'name': 'GPU host',
                'online': true,
                'schedulable': true,
                'lifecycle_state': 'active',
                'os': 'linux',
                'architecture': 'x86_64',
                'cpu_cores': 8,
                'total_memory_bytes': 4096,
                'available_memory_bytes': 2048,
                'reserved_cpu_cores': 2,
                'reserved_memory_bytes': 2048,
                'runtimes': ['python'],
                'running_tasks': 1,
                'project_ids': ['project-1'],
                'last_seen': 1789214400,
              },
            ],
            'next_cursor': 'device-1',
          });
        }
        if (path.endsWith('/sessions/session-1/tasks')) {
          expect(request.method, 'POST');
          expect(request.headers['idempotency-key'], 'stable-task-key');
          expect(jsonDecode(request.body), {
            'argv': ['python', '-c', "import sys; sys.stdout.write('1\\n')"],
            'workdir': 'src',
            'timeout': 60,
            'resources': {'cpu_cores': 2, 'memory_bytes': 1048576},
            'requirements': {
              'os': 'linux',
              'architecture': 'x86_64',
              'runtimes': ['python'],
            },
            'target_device_id': 'device-1',
            'turn_id': 'turn-1',
          });
          return jsonResponse({'data': task('queued')}, status: 202);
        }
        if (path.endsWith('/tasks/task-1/cancel')) {
          expect(request.method, 'POST');
          expect(request.body, '{}');
          return jsonResponse({'data': task('cancel_requested')}, status: 202);
        }
        if (path.endsWith('/tasks/task-1')) {
          return jsonResponse({'data': task('completed')});
        }
        if (path.endsWith('/tasks')) {
          return jsonResponse({
            'data': [task('queued')],
            'next_cursor': 'task-1',
          });
        }
        throw StateError('Unexpected request: $request');
      });
      final api = AgentHubApi(
        baseUrl: 'https://hub.example',
        accessToken: 'token',
        httpClient: client,
      );
      addTearDown(api.close);

      final devicePage = await api.listDevices(
        projectId: 'project-1',
        after: 'device-cursor',
        limit: 100,
      );
      expect(devicePage.items.single.availability, 'busy');
      expect(devicePage.items.single.freeCpuCores, 6);
      expect(devicePage.nextCursor, 'device-1');
      final request = AgentComputeRequest(
        argv: const ['python', '-c', "import sys; sys.stdout.write('1\\n')"],
        workdir: 'src',
        timeout: 60,
        resources: const AgentTaskResources(cpuCores: 2, memoryBytes: 1048576),
        requirements: const AgentTaskRequirements(
          os: 'linux',
          architecture: 'x86_64',
          runtimes: ['python'],
        ),
        targetDeviceId: 'device-1',
        turnId: 'turn-1',
      );
      final accepted = await api.submitTask(
        sessionId: 'session-1',
        task: request,
        idempotencyKey: 'stable-task-key',
      );
      expect(accepted.state, 'queued');
      final taskPage = await api.listTasks(sessionId: 'session-1');
      expect(taskPage.items.single.result?.evidenceDigest, 'sha256:abc');
      expect(taskPage.items.single.artifactRef?.backend, 'aero-vault');
      expect(taskPage.items.single.archiveState, 'archived');
      expect((await api.getTask('task-1')).state, 'completed');
      expect((await api.cancelTask('task-1')).state, 'cancel_requested');
      expect(requests[0].url.queryParameters, {
        'project_id': 'project-1',
        'after': 'device-cursor',
        'limit': '100',
      });
      expect(requests[2].url.queryParameters, {
        'session_id': 'session-1',
        'limit': '100',
      });
      expect(
        requests.every(
          (request) => request.headers['authorization'] == 'Bearer token',
        ),
        isTrue,
      );
    },
  );

  test('distinguishes 401, 403, unconfigured, and rejects redirects', () async {
    var unauthorizedCalls = 0;
    final statuses = <int>[401, 403, 503, 302];
    final codes = <String>[
      'token_expired',
      'insufficient_scope',
      'agent_hub_unconfigured',
      'redirect',
    ];
    final api = AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      onUnauthorized: (_) => unauthorizedCalls++,
      httpClient: MockClient((request) async {
        final status = statuses.removeAt(0);
        final code = codes.removeAt(0);
        return jsonResponse({
          'error': {'code': code, 'message': 'denied'},
        }, status: status);
      }),
    );
    addTearDown(api.close);

    final unauthorized = await _captureApiError(api.listInstances());
    expect(unauthorized.statusCode, 401);
    expect(unauthorizedCalls, 1);
    final forbidden = await _captureApiError(api.listInstances());
    expect(forbidden.statusCode, 403);
    expect(forbidden.isForbidden, isTrue);
    expect(unauthorizedCalls, 1);
    final unconfigured = await _captureApiError(api.listInstances());
    expect(unconfigured.isUnconfigured, isTrue);
    final redirect = await _captureApiError(api.listInstances());
    expect(redirect.code, 'redirect_rejected');
  });

  test(
    'rejects malformed envelopes and responses over the byte limit',
    () async {
      final api = AgentHubApi(
        baseUrl: 'https://hub.example',
        accessToken: 'token',
        httpClient: MockClient((request) async => http.Response('[]', 200)),
      );
      addTearDown(api.close);
      await expectLater(api.listInstances(), throwsFormatException);

      final oversized = AgentHubApi(
        baseUrl: 'https://hub.example',
        accessToken: 'token',
        httpClient: MockClient((request) async {
          final chunk = String.fromCharCodes(List<int>.filled(8192, 120));
          return http.Response(List<String>.filled(1025, chunk).join(), 200);
        }),
      );
      addTearDown(oversized.close);
      final error = await _captureApiError(oversized.listInstances());
      expect(error.code, 'response_too_large');
    },
  );
  test('reschedules a queued task with the shared compute contract', () async {
    late http.Request request;
    final api = AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      httpClient: MockClient((value) async {
        request = value;
        return jsonResponse({
          'data': {
            'task_id': 'task-1',
            'session_id': 'session-1',
            'state': 'queued',
            'target_device_id': 'device-2',
          },
        }, status: 202);
      }),
    );
    addTearDown(api.close);
    final task = await api.rescheduleTask('task-1', targetDeviceId: 'device-2');
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/agent/tasks/task-1/reschedule');
    expect(request.body, '{"target_device_id":"device-2"}');
    expect(task.taskId, 'task-1');
    expect(task.targetDeviceId, 'device-2');
    expect(task.canReschedule, isTrue);
  });
  test('retries a lost task only with duplicate confirmation', () async {
    late http.Request request;
    final api = AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      httpClient: MockClient((value) async {
        request = value;
        return jsonResponse({
          'data': {
            'task_id': 'task-lost',
            'session_id': 'session-1',
            'state': 'queued',
          },
        }, status: 202);
      }),
    );
    addTearDown(api.close);
    expect(
      () => api.retryLostTask('task-lost', confirmDuplicate: false),
      throwsArgumentError,
    );
    final task = await api.retryLostTask('task-lost', confirmDuplicate: true);
    expect(request.method, 'POST');
    expect(request.url.path, '/api/v1/agent/tasks/task-lost/retry');
    expect(request.body, '{"target_device_id":"","confirm_duplicate":true}');
    expect(task.taskId, 'task-lost');
    expect(task.canRetry, isFalse);
  });
}

Future<AgentHubApiException> _captureApiError(Future<Object?> operation) async {
  try {
    await operation;
  } on AgentHubApiException catch (error) {
    return error;
  }
  throw StateError('Expected AgentHubApiException.');
}
