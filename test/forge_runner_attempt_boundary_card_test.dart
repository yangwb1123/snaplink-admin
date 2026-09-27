import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';
import 'package:sso_admin/screens/forge/forge_runner_attempt_boundary_card.dart';

void main() {
  testWidgets('renders a metadata-only Attempt boundary card', (tester) async {
    final observation = ForgeRunnerAttemptBoundaryObservation.fromJson(
      _fixture(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeRunnerAttemptBoundaryCard(observation: observation),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
      findsOneWidget,
    );
    expect(find.text('Runner Attempt boundary preview'), findsOneWidget);
    expect(find.text('Lifecycle'), findsOneWidget);
    expect(find.textContaining('accepted → starting'), findsOneWidget);
    expect(find.textContaining('begin_starting'), findsOneWidget);
    expect(find.textContaining('Preview only'), findsOneWidget);
    expect(find.textContaining('argv execution'), findsOneWidget);
    expect(find.text('token-a'), findsNothing);
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgeRunnerAttemptBoundarySchema,
  'evaluation_mode': forgeRunnerAttemptBoundaryEvaluationMode,
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'attempt_id': 'attempt-1',
  'command_id': 'command-1',
  'target_id': 'runner-1',
  'lease_epoch': 1,
  'current_attempt_state': 'accepted',
  'next_attempt_state': 'starting',
  'transition': 'begin_starting',
  'execution_boundary_ready': true,
  'attempt_transition_valid': true,
  'attempt_transition_dispatchable': true,
  'attempt_boundary_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'attempt_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
