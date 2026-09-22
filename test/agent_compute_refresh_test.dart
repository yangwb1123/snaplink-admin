import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/agent/agent_compute_tasks_panel.dart';
import 'package:sso_admin/screens/agent/agent_device_directory.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';

const _uuid = 'GPU-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const _session = {
  'session_id': 's-1',
  'instance_id': 'i-1',
  'name': 'Session one',
  'project_id': 'project-1',
  'controllable': true,
  'status': 'idle',
};

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _task(bool assigned) => {
  'task_id': 'task-1',
  'session_id': 's-1',
  'instance_id': 'i-1',
  'state': assigned ? 'running' : 'queued',
  'resources': {'gpu_count': 1, 'gpu_memory_bytes': 0},
  'updated_at': assigned ? 1789238410.5 : 1789238410.25,
  if (assigned)
    'gpu_assignment': {
      'vendor': 'nvidia',
      'mode': 'physical',
      'uuids': [_uuid],
      'gpu_memory_bytes': 0,
      'assigned_at': 1789238410.5,
      'observed_at': 1789238400,
    },
};

Future<void> _requests(WidgetTester tester) async {
  for (var count = 0; count < 6; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

void main() {
  testWidgets('device load-more intent survives a concurrent refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    final refreshResponse = Completer<http.Response>();
    var deviceRequestCount = 0;

    Map<String, dynamic> device(String id) => {
      'device_id': id,
      'instance_id': 'i-1',
      'name': id,
      'online': true,
      'schedulable': true,
      'lifecycle_state': 'ready',
      'cpu_cores': 8,
      'total_memory_bytes': 1024,
      'available_memory_bytes': 1024,
      'reserved_cpu_cores': 0,
      'reserved_memory_bytes': 0,
      'running_tasks': 0,
      'project_ids': ['project-1'],
      'runtimes': <String>[],
    };

    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/instances')) return _json({'data': []});
      if (path.endsWith('/sessions')) {
        return _json({
          'data': [_session],
        });
      }
      if (path.endsWith('/sessions/s-1')) return _json({'data': _session});
      if (path.endsWith('/events')) {
        return _json({'data': [], 'next_cursor': 0});
      }
      if (path.endsWith('/tasks')) return _json({'data': []});
      if (path.endsWith('/devices')) {
        requests.add(request.url);
        deviceRequestCount++;
        if (deviceRequestCount == 3) return refreshResponse.future;
        final after = request.url.queryParameters['after'];
        return _json({
          'data': [device(after == null ? 'device-1' : 'device-2')],
          'next_cursor': after == null ? 'device-1' : 'device-2',
        });
      }
      throw StateError('Unexpected request: $path');
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
    await _requests(tester);
    await tester.tap(find.text('Session one').first);
    await _requests(tester);
    await tester.tap(find.text('Compute devices').first);
    await tester.pumpAndSettle();
    expect(find.text('Load more devices'), findsOneWidget);

    final directory = find.byType(AgentDeviceDirectory);
    await tester.tap(
      find.descendant(of: directory, matching: find.byTooltip('Refresh')),
    );
    await tester.pump();
    await tester.tap(find.text('Load more devices'));
    await tester.pump();
    refreshResponse.complete(
      _json({
        'data': [device('device-1')],
        'next_cursor': 'device-1',
      }),
    );
    await _requests(tester);

    expect(requests.map((uri) => uri.queryParameters['after']).toList(), [
      null,
      null,
      null,
      'device-1',
    ]);
    expect(find.text('device-2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task load-more intent survives a concurrent refresh', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final requests = <Uri>[];
    final refreshResponse = Completer<http.Response>();
    var taskRequestCount = 0;

    Map<String, dynamic> task(String id) => {
      'task_id': id,
      'session_id': 's-1',
      'instance_id': 'i-1',
      'state': 'queued',
      'argv': ['echo', id],
      'workdir': '.',
      'timeout': 60,
      'resources': {'cpu_cores': 1, 'memory_bytes': 0},
      'requirements': {'os': '', 'architecture': '', 'runtimes': <String>[]},
      'created_at': '2026-09-12T12:00:00Z',
      'updated_at': '2026-09-12T12:00:00Z',
      'error': '',
      'result': {},
      'archive_state': 'disabled',
      'artifact_ref': {},
    };

    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/instances')) return _json({'data': []});
      if (path.endsWith('/sessions')) {
        return _json({
          'data': [_session],
        });
      }
      if (path.endsWith('/sessions/s-1')) return _json({'data': _session});
      if (path.endsWith('/events')) {
        return _json({'data': [], 'next_cursor': 0});
      }
      if (path.endsWith('/devices')) return _json({'data': []});
      if (path.endsWith('/tasks')) {
        requests.add(request.url);
        taskRequestCount++;
        if (taskRequestCount == 2) return refreshResponse.future;
        final after = request.url.queryParameters['after'];
        return _json({
          'data': [task(after == null ? 'task-1' : 'task-2')],
          'next_cursor': after == null ? 'task-1' : 'task-2',
        });
      }
      throw StateError('Unexpected request: $path');
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
    await _requests(tester);
    await tester.tap(find.text('Session one').first);
    await _requests(tester);
    await tester.tap(find.text('Compute tasks').first);
    await tester.pumpAndSettle();
    final tasksPanel = find.byType(AgentComputeTasksPanel);
    await tester.tap(
      find.descendant(of: tasksPanel, matching: find.byTooltip('Refresh')),
    );
    await tester.pump();
    await tester.drag(tasksPanel, const Offset(0, -800));
    await tester.pumpAndSettle();
    expect(find.text('Load more tasks'), findsOneWidget);
    await tester.tap(find.text('Load more tasks'));
    await tester.pump();
    refreshResponse.complete(
      _json({
        'data': [task('task-1')],
        'next_cursor': 'task-1',
      }),
    );
    await _requests(tester);

    expect(requests.map((uri) => uri.queryParameters['after']).toList(), [
      null,
      null,
      'task-1',
    ]);
    expect(find.textContaining('Task task-2'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('task reset supersedes a delayed request from the old session', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const workspaceFileChannel = MethodChannel(
      'site.ywbsd.sso/agent_workspace_files',
    );
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.defaultBinaryMessenger.setMockMethodCallHandler(
      workspaceFileChannel,
      (_) async => {'version': 1, 'pick': false, 'save': false},
    );
    addTearDown(
      () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
        workspaceFileChannel,
        null,
      ),
    );
    final oldTaskResponse = Completer<http.Response>();
    final taskRequests = <String>[];
    var taskRequestCount = 0;
    final secondSession = {
      ..._session,
      'session_id': 's-2',
      'name': 'Session two',
    };

    Map<String, dynamic> task(String id, String sessionId) => {
      'task_id': id,
      'session_id': sessionId,
      'instance_id': 'i-1',
      'state': 'queued',
      'argv': ['echo', id],
      'workdir': '.',
      'timeout': 60,
      'resources': {'cpu_cores': 1, 'memory_bytes': 0},
      'requirements': {'os': '', 'architecture': '', 'runtimes': <String>[]},
      'created_at': '2026-09-12T12:00:00Z',
      'updated_at': '2026-09-12T12:00:00Z',
      'error': '',
      'result': {},
      'archive_state': 'disabled',
      'artifact_ref': {},
    };

    final client = MockClient((request) async {
      final path = request.url.path;
      if (path.endsWith('/instances')) return _json({'data': []});
      if (path.endsWith('/sessions')) {
        return _json({
          'data': [_session, secondSession],
        });
      }
      if (path.endsWith('/sessions/s-1')) return _json({'data': _session});
      if (path.endsWith('/sessions/s-2')) {
        return _json({'data': secondSession});
      }
      if (path.endsWith('/events')) {
        return _json({'data': [], 'next_cursor': 0});
      }
      if (path.endsWith('/devices')) return _json({'data': []});
      if (path.endsWith('/tasks')) {
        taskRequestCount++;
        final sessionId = request.url.queryParameters['session_id']!;
        taskRequests.add(sessionId);
        if (taskRequestCount == 1) return oldTaskResponse.future;
        return _json({
          'data': [task('task-2', sessionId)],
        });
      }
      throw StateError('Unexpected request: $path');
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
    await _requests(tester);
    await tester.tap(find.text('Session one').first);
    await tester.pump();
    await tester.tap(find.text('Session two').first);
    await tester.pump();
    oldTaskResponse.complete(
      _json({
        'data': [task('task-1', 's-1')],
      }),
    );
    await _requests(tester);
    await tester.tap(find.text('Compute tasks').first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.textContaining('Task task-2'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(AgentComputeTasksPanel),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(taskRequests.take(2).toList(), ['s-1', 's-2']);
    expect(find.textContaining('Task task-2'), findsWidgets);
    expect(find.textContaining('Task task-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final lateDetails in [false, true]) {
    testWidgets(
      'polling exposes GPU assignment despite old details (late: $lateDetails)',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var assigned = false;
        var detailsRead = false;
        final oldResponse = Completer<http.Response>();
        final client = MockClient((request) async {
          final path = request.url.path;
          if (path.endsWith('/instances')) return _json({'data': []});
          if (path.endsWith('/sessions')) {
            return _json({
              'data': [_session],
            });
          }
          if (path.endsWith('/sessions/s-1')) return _json({'data': _session});
          if (path.endsWith('/devices')) return _json({'data': []});
          if (path.endsWith('/events')) {
            return _json({'data': [], 'next_cursor': 0});
          }
          if (path.endsWith('/tasks')) {
            return _json({
              'data': [_task(assigned)],
            });
          }
          if (path.endsWith('/tasks/task-1')) {
            detailsRead = true;
            return lateDetails
                ? oldResponse.future
                : _json({'data': _task(false)});
          }
          throw StateError('Unexpected request: $path');
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
        await _requests(tester);
        await tester.tap(find.text('Session one').first);
        await _requests(tester);
        await tester.tap(find.text('Compute tasks').first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('Task task-1'),
          300,
          scrollable: find
              .descendant(
                of: find.byType(AgentComputeTasksPanel),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(find.textContaining('Task task-1'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Task task-1'));
        await _requests(tester);
        expect(detailsRead, isTrue);
        if (!lateDetails) {
          expect(
            find.text('GPU assignment has not been reported.'),
            findsOneWidget,
          );
        }
        assigned = true;
        await tester.pump(const Duration(seconds: 2));
        await _requests(tester);
        if (lateDetails) {
          oldResponse.complete(_json({'data': _task(false)}));
          await _requests(tester);
        }
        await tester.pumpAndSettle();
        expect(find.text('GPU UUID: $_uuid'), findsOneWidget);
        expect(
          find.text('GPU assignment has not been reported.'),
          findsNothing,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
