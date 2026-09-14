import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';

import 'fixtures/agent_workspace_fixture.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 6; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Map<String, dynamic> _task(String state) => {
  'task_id': 'task-1',
  'session_id': 's-1',
  'instance_id': 'i-1',
  'turn_id': '',
  'actor': 'alice',
  'project_id': 'project-1',
  'state': state,
  'device_id': 'device-1',
  'device_instance_id': 'i-1',
  'argv': ['echo', 'hello world'],
  'workdir': '.',
  'timeout': 60,
  'resources': {'cpu_cores': 1, 'memory_bytes': 0},
  'requirements': {'os': '', 'architecture': '', 'runtimes': []},
  'created_at': '2026-09-12T12:00:00Z',
  'updated_at': '2026-09-12T12:00:00Z',
  'error': '',
  'result': {},
  'archive_state': 'disabled',
  'artifact_ref': {},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in ['cpu', 'gpu', 'workspace']) {
    final gpuEnabled = mode == 'gpu';
    final workspaceEnabled = mode == 'workspace';
    testWidgets(
      'task retries retain key and accepted cancellation (compute mode: $mode)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final writes = <http.Request>[];
        final acceptedKeys = <String, Map<String, dynamic>>{};
        var loseFirstWriteResponse = true;
        var taskState = 'queued';
        final client = MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/snapshots')) {
            return _json({
              'data': [workspaceSnapshot()],
            });
          }
          if (path.endsWith('/instances')) {
            return _json({
              'data': [
                {'instance_id': 'i-1', 'name': 'Runner', 'online': true},
              ],
            });
          }
          if (path.endsWith('/sessions')) {
            return _json({
              'data': [
                {
                  'session_id': 's-1',
                  'instance_id': 'i-1',
                  'local_session_id': 'local-1',
                  'name': 'Session one',
                  'project_id': 'project-1',
                  'controllable': true,
                  'status': 'idle',
                },
              ],
            });
          }
          if (path.endsWith('/devices')) {
            return _json({
              'data': [
                {
                  'device_id': 'device-1',
                  'instance_id': 'i-1',
                  'name': 'Worker',
                  'online': true,
                  'schedulable': true,
                  'workspace_supported': true,
                  'lifecycle_state': 'active',
                  'os': 'linux',
                  'architecture': 'x86_64',
                  'cpu_cores': 8,
                  'total_memory_bytes': 8589934592,
                  'available_memory_bytes': 4294967296,
                  'reserved_cpu_cores': 2,
                  'reserved_memory_bytes': 4294967296,
                  'runtimes': ['python'],
                  'running_tasks': 1,
                  'project_ids': ['project-1'],
                  'last_seen': '2026-09-12T12:00:00Z',
                },
              ],
            });
          }
          if (path.endsWith('/sessions/s-1')) {
            return _json({
              'data': {
                'session_id': 's-1',
                'instance_id': 'i-1',
                'local_session_id': 'local-1',
                'name': 'Session one',
                'project_id': 'project-1',
                'controllable': true,
                'status': 'idle',
              },
            });
          }
          if (path.endsWith('/events')) {
            return _json({'data': [], 'next_cursor': 0});
          }
          if (path.endsWith('/sessions/s-1/tasks')) {
            writes.add(request);
            final key = request.headers['idempotency-key']!;
            final saved = acceptedKeys.putIfAbsent(key, () => _task(taskState));
            if (loseFirstWriteResponse) {
              loseFirstWriteResponse = false;
              throw http.ClientException('response lost', request.url);
            }
            return _json({'data': saved}, status: 202);
          }
          if (path.endsWith('/tasks/task-1/cancel')) {
            taskState = 'cancel_requested';
            return _json({'data': _task(taskState)}, status: 202);
          }
          if (path.endsWith('/tasks/task-1')) {
            return _json({'data': _task(taskState)});
          }
          if (path.endsWith('/tasks')) {
            return _json({
              'data': [_task(taskState)],
            });
          }
          throw StateError('Unexpected request: ${request.url}');
        });
        addTearDown(client.close);

        await tester.pumpWidget(
          MaterialApp(
            home: AgentOperationsScreen(
              accessToken: 'token',
              apiOrigin: 'https://hub.example',
              httpClient: client,
            ),
          ),
        );
        await _pumpRequests(tester);
        await tester.tap(find.text('Session one').first);
        await _pumpRequests(tester);
        await tester.tap(find.text('Compute tasks').first);
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(TextField).first,
          '["echo", "hello world"]',
        );
        if (workspaceEnabled) {
          await tester.enterText(
            find.widgetWithText(TextField, 'Relative workdir'),
            'src',
          );
          await _reveal(tester, find.text('Use a workspace snapshot'));
          await tester.tap(find.text('Use a workspace snapshot'));
          await _pumpRequests(tester);
          await tester.pumpAndSettle();
          await _reveal(tester, find.text('Queue task'));
          await tester.pumpAndSettle();
          await _reveal(tester, find.text('Queue task'));
          await tester.tap(find.text('Queue task'));
          await tester.pump();
          expect(writes, isEmpty);
          expect(find.text('Choose a workspace snapshot.'), findsOneWidget);
          final picker = find.widgetWithText(
            DropdownButtonFormField<String>,
            'Workspace snapshot',
          );
          await _reveal(tester, picker);
          await tester.tap(picker);
          await tester.pumpAndSettle();
          await tester.tap(find.text('snap-1 · 2').last);
          await tester.pumpAndSettle();
          await tester.enterText(
            find.widgetWithText(TextField, 'Output file paths'),
            'out.txt',
          );
        }
        if (gpuEnabled) {
          final countField = find.widgetWithText(TextField, 'GPU count');
          final memoryField = find.widgetWithText(
            TextField,
            'Minimum GPU memory (MiB/card)',
          );
          await tester.enterText(countField, '1.5');
          await _reveal(tester, find.text('Queue task'));
          await tester.tap(find.text('Queue task'));
          await tester.pump();
          expect(writes, isEmpty);
          expect(
            find.text('GPU count must be a whole number.'),
            findsOneWidget,
          );
          await tester.enterText(countField, '2');
          await tester.enterText(memoryField, '8192');
        }
        await _reveal(tester, find.text('Queue task'));
        await tester.tap(find.text('Queue task'));
        await _pumpRequests(tester);
        await tester.tap(find.text('Queue task'));
        await _pumpRequests(tester);

        expect(writes, hasLength(2));
        expect(
          writes.map((request) => request.headers['idempotency-key']).toSet(),
          hasLength(1),
        );
        expect(jsonDecode(writes.first.body)['argv'], ['echo', 'hello world']);
        expect(writes.first.url.path, '/api/v1/agent/sessions/s-1/tasks');
        expect(jsonDecode(writes.first.body)['resources'], {
          'cpu_cores': 1,
          'memory_bytes': 0,
          if (gpuEnabled) 'gpu_count': 2,
          if (gpuEnabled) 'gpu_memory_bytes': 8192 * 1024 * 1024,
        });
        if (workspaceEnabled) {
          expect(jsonDecode(writes.first.body)['workspace'], {
            'snapshot_id': 'snap-1',
            'outputs': ['out.txt'],
          });
          expect(jsonDecode(writes.first.body)['workdir'], '.');
        } else {
          expect(
            jsonDecode(writes.first.body).containsKey('workspace'),
            isFalse,
          );
        }
        expect(writes.first.body, writes.last.body);
        expect(acceptedKeys, hasLength(1));
        expect(find.textContaining('Task task-1'), findsOneWidget);

        await tester.tap(find.byTooltip('Cancel task'));
        await _pumpRequests(tester);
        expect(find.textContaining('Cancellation requested'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'device scope prompt remains inside its tab and keeps sessions visible',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final client = MockClient((request) async {
        if (request.url.path.endsWith('/instances')) return _json({'data': []});
        if (request.url.path.endsWith('/sessions')) {
          return _json({
            'data': [
              {
                'session_id': 's-1',
                'instance_id': 'i-1',
                'local_session_id': 'local-1',
                'name': 'Session one',
              },
            ],
          });
        }
        if (request.url.path.endsWith('/devices')) {
          return _json({
            'error': {
              'code': 'insufficient_scope',
              'message': 'device scope required',
            },
          }, status: 403);
        }
        return _json({'data': []});
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: AgentOperationsScreen(
            accessToken: 'token',
            apiOrigin: 'https://hub.example',
            httpClient: client,
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(find.text('Session one'), findsOneWidget);
      await tester.tap(find.text('Compute devices').first);
      await tester.pumpAndSettle();
      await _pumpRequests(tester);
      expect(
        find.text('Device access requires additional Agent permissions.'),
        findsOneWidget,
      );
      expect(find.text('Sign in for Agent access'), findsOneWidget);
      await tester.tap(find.text('Sessions').first);
      await tester.pumpAndSettle();
      expect(find.text('Session one'), findsOneWidget);
    },
  );
}
