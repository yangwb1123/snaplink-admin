import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';
import 'package:sso_admin/screens/forge/forge_execution_reconciliation_observation_card.dart';

void main() {
  testWidgets('renders the display-only reconciliation classification', (
    tester,
  ) async {
    final input = ForgeExecutionReconciliationInput.fromJson({
      'owner': {
        'issuer': 'https://id.example.test',
        'subject': 'user-1',
        'tenant_id': 'tenant-1',
      },
      'conversation_id': 'conversation-1',
      'run_id': 'run-1',
      'attempt_id': 'attempt-1',
      'command_id': 'command-1',
      'target_id': 'runner-1',
      'run_status': 'nonterminal',
      'attempt_state': 'running',
      'lease': {
        'v': 1,
        'attempt_id': 'attempt-1',
        'target_id': 'runner-1',
        'epoch': 1,
        'fencing_token': 'fence-1',
        'issued_at_ms': 100,
        'expires_at_ms': 10100,
      },
      'observed_at_ms': 200,
      'terminal': null,
    });
    final observation = observeForgeExecutionReconciliation(input);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForgeExecutionReconciliationObservationCard(
              observation: observation,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey('forge-execution-reconciliation-observation-card'),
      ),
      findsOneWidget,
    );
    expect(find.text('Execution reconciliation preview'), findsOneWidget);
    expect(find.text('await_terminal'), findsOneWidget);
    expect(find.text('Automatic retry'), findsOneWidget);
    expect(find.text('false'), findsWidgets);
    expect(find.text('conversation-1'), findsOneWidget);
    expect(find.text('runner-1'), findsOneWidget);
  });
}
