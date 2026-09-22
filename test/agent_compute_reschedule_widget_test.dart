import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/screens/agent/agent_compute_task_tile.dart';

AgentComputeTask _queuedTask() => AgentComputeTask.fromJson({
  'task_id': 'task-1',
  'session_id': 'session-1',
  'state': 'queued',
  'target_device_id': 'device-1',
});

AgentComputeTask _lostTask() => AgentComputeTask.fromJson({
  'task_id': 'task-lost',
  'session_id': 'session-1',
  'state': 'lost',
});

void main() {
  testWidgets('queued task exposes the reschedule action', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AgentComputeTaskTile(
          task: _queuedTask(),
          loadingDetails: false,
          cancelling: false,
          cancelScopeMissing: false,
          rescheduling: false,
          rescheduleScopeMissing: false,
          onCancel: () {},
          onReschedule: () => calls++,
          onExpansionChanged: (_) {},
          onSignIn: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.alt_route), findsOneWidget);
    await tester.tap(find.byIcon(Icons.alt_route));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('lost task exposes an explicit duplicate-risk retry action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: AgentComputeTaskTile(
          task: _lostTask(),
          loadingDetails: false,
          cancelling: false,
          cancelScopeMissing: false,
          rescheduling: false,
          rescheduleScopeMissing: false,
          onCancel: () {},
          onReschedule: () {},
          retrying: false,
          retryScopeMissing: false,
          onRetry: () => calls++,
          onExpansionChanged: (_) {},
          onSignIn: () {},
        ),
      ),
    );
    expect(find.byIcon(Icons.replay_circle_filled_outlined), findsOneWidget);
    await tester.tap(find.byIcon(Icons.replay_circle_filled_outlined));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
