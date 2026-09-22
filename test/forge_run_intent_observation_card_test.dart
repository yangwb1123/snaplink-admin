import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_intent_observation.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/screens/forge/forge_run_intent_observation_card.dart';

void main() {
  testWidgets('renders a read-only Run intent observation', (tester) async {
    const observation = ForgeRunIntentObservation(
      schemaVersion: forgeRunIntentObservationSchema,
      evaluationMode: 'offline_static_only',
      owner: ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-1',
        tenantID: 'tenant-1',
      ),
      conversationID: 'conversation-1',
      promptID: 'prompt-1',
      intentID: 'intent-1',
      runID: 'run-1',
      promptAccepted: true,
      runReferenceObserved: true,
      promptRunBindingValid: true,
      placementObservationBound: true,
      previewOnly: true,
      intentReplayed: false,
      runStatus: 'nonterminal',
      runLatestSequence: 3,
      promptAcceptedAtMS: 1000,
      placementEvaluatedAtMS: 2000,
      placementDecisionCount: 4,
      eligibleInstanceCount: 2,
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: ForgeSessionPlacementAuthority.offline(),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: SingleChildScrollView(
          child: ForgeRunIntentObservationCard(observation: observation),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('forge-run-intent-observation-card')),
      findsOneWidget,
    );
    expect(find.text('Conversation ID'), findsOneWidget);
    expect(find.text('conversation-1'), findsOneWidget);
    expect(find.text('Prompt ID'), findsOneWidget);
    expect(find.text('prompt-1'), findsOneWidget);
    expect(find.text('Run ID'), findsOneWidget);
    expect(find.text('run-1'), findsOneWidget);
    expect(find.text('Run status'), findsOneWidget);
    expect(find.text('nonterminal'), findsOneWidget);
    expect(find.text('Run sequence'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Eligible instances'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Preview only'), findsOneWidget);
    expect(find.text('true'), findsNWidgets(3));
    expect(find.text('Owner declaration unverified'), findsOneWidget);
    expect(find.text('Device attributes unverified'), findsOneWidget);
    expect(find.text('Authority granted'), findsOneWidget);
    expect(find.text('false'), findsNWidgets(7));
    expect(find.byType(IconButton), findsNothing);
    expect(find.byType(TextButton), findsNothing);
  });
}
