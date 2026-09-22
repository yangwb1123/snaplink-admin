import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_intent_observation.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders a matching display-only Run intent observation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runIntentObservation: _observation(),
          runnerExecutionIntentObservation: _runnerObservation(),
          sessionRunnerReceiptObservation: _sessionRunnerReceiptObservation(),
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-intent-observation-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(
      find.byKey(const ValueKey('forge-run-intent-observation-card')),
      findsOneWidget,
    );
    expect(find.text('Run intent preview'), findsOneWidget);
    expect(find.text('conversation-1'), findsOneWidget);
    expect(find.text('prompt-1'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('forge-run-intent-observation-card')),
        matching: find.text('run-1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Execution authorized'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-runner-execution-intent-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('forge-runner-execution-intent-card')),
      findsOneWidget,
    );
    expect(find.text('Runner execution intent preview'), findsOneWidget);
    expect(find.text('attempt-1'), findsOneWidget);
    expect(find.text('command-1'), findsOneWidget);
    expect(find.text('runner-1'), findsOneWidget);
    expect(find.text('none'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
      findsOneWidget,
    );
    expect(find.text('Session Runner receipt preview'), findsOneWidget);
    expect(find.text('reconciliation_manual'), findsNothing);
  });

  testWidgets('does not render a foreign Run observation', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runIntentObservation: _observation(runID: 'run-foreign'),
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-run-intent-observation-card')),
      findsNothing,
    );
  });

  testWidgets('imports a matching Runner observation without a POST', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-import-runner-execution-observation')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-import-runner-execution-observation')),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const ValueKey('forge-runner-execution-observation-json')),
      jsonEncode(_runnerObservation().toJson()),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('forge-import-runner-execution-observation-submit'),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-runner-execution-intent-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('forge-runner-execution-intent-card')),
      findsOneWidget,
    );
  });

  testWidgets('does not render a mutated authoritative observation', (
    tester,
  ) async {
    final unsafe = _observation(
      authority: const ForgeSessionPlacementAuthority(
        identityVerified: false,
        heartbeatPersisted: false,
        inventoryAuthoritative: false,
        reservationCreated: false,
        executionAuthorized: true,
        dispatchPerformed: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runIntentObservation: unsafe,
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-run-intent-observation-card')),
      findsNothing,
    );
  });

  testWidgets('does not render a selected or non-preview observation', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runIntentObservation: _observation(
            previewOnly: false,
            selectedDeviceID: 'device-1',
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-run-intent-observation-card')),
      findsNothing,
    );
  });

  testWidgets('imports a matching session Runner receipt without a POST', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('forge-import-session-runner-receipt-observation'),
      ),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(
      find.byKey(
        const ValueKey('forge-import-session-runner-receipt-observation'),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-json'),
      ),
      jsonEncode(_sessionRunnerReceiptObservation().toJson()),
    );
    await tester.tap(
      find.byKey(
        const ValueKey(
          'forge-import-session-runner-receipt-observation-submit',
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'clears imported Runner observations when the selected Conversation changes',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: _twoConversationClient(),
          ),
        ),
      );
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-import-runner-execution-observation')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-import-runner-execution-observation')),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(const ValueKey('forge-runner-execution-observation-json')),
        jsonEncode(_runnerObservation().toJson()),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('forge-import-runner-execution-observation-submit'),
        ),
      );
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('forge-import-session-runner-receipt-observation'),
        ),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('forge-import-session-runner-receipt-observation'),
        ),
      );
      await tester.pump();
      await tester.enterText(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-observation-json'),
        ),
        jsonEncode(_sessionRunnerReceiptObservation().toJson()),
      );
      await tester.tap(
        find.byKey(
          const ValueKey(
            'forge-import-session-runner-receipt-observation-submit',
          ),
        ),
      );
      await _settle(tester);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-runner-execution-intent-card')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-observation-card'),
        ),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(const ValueKey('forge-runner-execution-intent-card')),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-observation-card'),
        ),
        findsOneWidget,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-conversation-conversation-2')),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-conversation-conversation-2')),
      );
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('forge-runner-execution-intent-card')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-observation-card'),
        ),
        findsNothing,
      );

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-conversation-conversation-1')),
        -500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-conversation-conversation-1')),
      );
      await _settle(tester);
      expect(
        find.byKey(const ValueKey('forge-runner-execution-intent-card')),
        findsNothing,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-observation-card'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets('does not render a mutated session Runner authority', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          sessionRunnerReceiptObservation: _sessionRunnerReceiptObservation(
            authority: const ForgeSessionRunnerReceiptObservationAuthority(
              identityVerified: true,
              receiptPersisted: false,
              executionAuthorized: false,
              dispatchPerformed: false,
              auditPublished: false,
            ),
          ),
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
      findsNothing,
    );
  });
}

ForgeRunnerExecutionIntentObservation _runnerObservation({
  String conversationID = 'conversation-1',
  String runID = 'run-1',
  ForgeRunnerExecutionIntentAuthority authority =
      const ForgeRunnerExecutionIntentAuthority.offline(),
}) => ForgeRunnerExecutionIntentObservation(
  schemaVersion: forgeRunnerExecutionIntentSchema,
  evaluationMode: forgeRunnerExecutionIntentEvaluationMode,
  owner: _owner,
  conversationID: conversationID,
  promptID: 'prompt-1',
  runID: runID,
  attemptID: 'attempt-1',
  commandID: 'command-1',
  targetID: 'runner-1',
  commandSHA256: 'a' * 64,
  idempotencyKey: '$runID:attempt-1:command-1',
  promptRunBindingValid: true,
  runnerCommandBindingValid: true,
  previewOnly: true,
  selectedTargetID: null,
  authority: authority,
);

ForgeSessionRunnerReceiptObservation _sessionRunnerReceiptObservation({
  ForgeSessionRunnerReceiptObservationAuthority authority =
      const ForgeSessionRunnerReceiptObservationAuthority.offline(),
}) => ForgeSessionRunnerReceiptObservation(
  schemaVersion: forgeSessionRunnerReceiptObservationSchema,
  evaluationMode: forgeSessionRunnerReceiptObservationEvaluationMode,
  owner: _owner,
  conversationID: 'conversation-1',
  promptID: 'prompt-1',
  runID: 'run-1',
  receiptObservation: ForgeRunnerTerminalReceiptObservation(
    schemaVersion: forgeRunnerTerminalReceiptSchema,
    evaluationMode: forgeRunnerTerminalReceiptEvaluationMode,
    commandID: 'command-1',
    commandSHA256: 'a' * 64,
    attemptID: 'attempt-1',
    targetID: 'runner-1',
    dispositionKind: 'completed',
    observedAtMS: 300,
    receiptValid: true,
    previewOnly: true,
    uncertain: false,
    reconciliationRequired: false,
    manualReviewRequired: false,
    automaticRetry: false,
    followUp: 'none',
    authority: const ForgeRunnerTerminalReceiptAuthority.offline(),
  ),
  promptRunBindingValid: true,
  receiptBindingValid: true,
  previewOnly: true,
  selectedTargetID: null,
  authority: authority,
);

ForgeRunIntentObservation _observation({
  String runID = 'run-1',
  bool previewOnly = true,
  String? selectedDeviceID,
  ForgeSessionPlacementAuthority authority =
      const ForgeSessionPlacementAuthority.offline(),
}) => ForgeRunIntentObservation(
  schemaVersion: forgeRunIntentObservationSchema,
  evaluationMode: 'offline_static_only',
  owner: _owner,
  conversationID: 'conversation-1',
  promptID: 'prompt-1',
  intentID: 'intent-1',
  runID: runID,
  promptAccepted: true,
  runReferenceObserved: true,
  promptRunBindingValid: true,
  placementObservationBound: true,
  previewOnly: previewOnly,
  intentReplayed: false,
  runStatus: 'completed',
  runLatestSequence: 2,
  promptAcceptedAtMS: 10,
  placementEvaluatedAtMS: 20,
  placementDecisionCount: 1,
  eligibleInstanceCount: 1,
  ownerDeclarationUnverified: true,
  deviceAttributesUnverified: true,
  selectedDeviceID: selectedDeviceID,
  selectedInstanceID: null,
  authority: authority,
);

MockClient _client() => MockClient((request) async {
  if (request.method == 'GET' && request.url.path == '/api/v1/conversations') {
    return _json({
      'conversations': [_conversation()],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      request.url.path == '/api/v1/conversations/conversation-1/prompts') {
    return _json({
      'conversation_id': 'conversation-1',
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      request.url.path == '/api/v1/conversations/conversation-1/runs') {
    return _json({
      'conversation_id': 'conversation-1',
      'runs': [_run()],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      request.url.path ==
          '/api/v1/conversations/conversation-1/runs/run-1/timeline') {
    return _json({
      'conversation_id': 'conversation-1',
      'run_id': 'run-1',
      'after_sequence': 0,
      'scanned_through_sequence': 2,
      'has_more': false,
      'events': [
        {'seq': 1, 'emitted_at_ms': 11, 'type': 'run_started'},
        {'seq': 2, 'emitted_at_ms': 12, 'type': 'run_finished'},
      ],
    });
  }
  throw StateError(
    'Unexpected Forge request: ${request.method} ${request.url}',
  );
});

MockClient _twoConversationClient() => MockClient((request) async {
  final segments = request.url.pathSegments;
  if (request.method == 'GET' && request.url.path == '/api/v1/conversations') {
    return _json({
      'conversations': [
        _conversation(),
        _conversation(id: 'conversation-2', title: 'Other work'),
      ],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      segments.length == 5 &&
      segments[0] == 'api' &&
      segments[1] == 'v1' &&
      segments[2] == 'conversations' &&
      segments[4] == 'prompts') {
    return _json({
      'conversation_id': segments[3],
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      segments.length == 5 &&
      segments[0] == 'api' &&
      segments[1] == 'v1' &&
      segments[2] == 'conversations' &&
      segments[4] == 'runs') {
    final conversationID = segments[3];
    return _json({
      'conversation_id': conversationID,
      'runs': [
        _run(
          conversationID: conversationID,
          runID: conversationID == 'conversation-1' ? 'run-1' : 'run-2',
        ),
      ],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      segments.length == 7 &&
      segments[0] == 'api' &&
      segments[1] == 'v1' &&
      segments[2] == 'conversations' &&
      segments[4] == 'runs' &&
      segments[6] == 'timeline') {
    return _json({
      'conversation_id': segments[3],
      'run_id': segments[5],
      'after_sequence': 0,
      'scanned_through_sequence': 2,
      'has_more': false,
      'events': [
        {'seq': 1, 'emitted_at_ms': 11, 'type': 'run_started'},
        {'seq': 2, 'emitted_at_ms': 12, 'type': 'run_finished'},
      ],
    });
  }
  throw StateError(
    'Unexpected Forge request: ${request.method} ${request.url}',
  );
});

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

Map<String, Object> _conversation({
  String id = 'conversation-1',
  String title = 'Shared work',
}) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': title,
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, Object> _run({
  String conversationID = 'conversation-1',
  String runID = 'run-1',
}) => {
  'run_id': runID,
  'prompt_id': conversationID == 'conversation-1' ? 'prompt-1' : 'prompt-2',
  'created_at_ms': 10,
  'latest_sequence': 2,
  'status': 'completed',
};
