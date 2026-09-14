import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/agent/agent_compute_tasks_panel.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';

import 'fixtures/agent_workspace_fixture.dart';

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

Map<String, dynamic> _task(bool ready) => {
  'task_id': 'task-1',
  'session_id': 's-1',
  'instance_id': 'i-1',
  'state': 'completed',
  'updated_at': 1789238410.5,
  'workspace_result': workspaceResult(state: ready ? 'ready' : 'pending'),
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
  for (final lateDetails in [false, true]) {
    testWidgets(
      'polling exposes ready workspace with unchanged task timestamp despite old details (late: $lateDetails)',
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
          expect(find.text('Workspace artifact: pending'), findsOneWidget);
        }
        assigned = true;
        await tester.pump(const Duration(seconds: 2));
        await _requests(tester);
        if (lateDetails) {
          oldResponse.complete(_json({'data': _task(false)}));
          await _requests(tester);
        }
        await tester.pumpAndSettle();
        expect(find.text('View workspace JSON'), findsOneWidget);
        expect(find.text('Workspace artifact: pending'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
