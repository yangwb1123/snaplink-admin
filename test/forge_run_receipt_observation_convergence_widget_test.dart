import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/api/forge_run_receipt_observation_convergence.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  test('default Gate leaves the receipt reader request-free', () {
    const gate = ForgeSessionsGate();
    expect(gate.sessionRunnerReceiptObservationReader, isNull);
  });

  test('validates every field in one converged metadata snapshot', () {
    final convergence = ForgeRunReceiptObservationConvergence.fromObservations(
      runObserved: _runObserved(),
      receiptObserved: _receipt(),
      conversationID: 'conversation-1',
      runID: 'run-1',
      promptID: 'prompt-1',
      runCreatedAtMS: 10,
      runLatestSequence: 2,
      runStatus: 'completed',
    );

    expect(convergence.metadataFingerprint, contains('attempt-1'));
    expect(convergence.metadataFingerprint, contains('command-1'));
    expect(convergence.metadataFingerprint, contains('runner-1'));
    expect(convergence.metadataFingerprint, contains('observed_at_ms'));
    expect(
      convergence.metadataFingerprint,
      contains('reconciliation_required'),
    );

    expect(
      () => ForgeRunReceiptObservationConvergence.fromObservations(
        runObserved: _runObserved(ownerRef: '0' * 64),
        receiptObserved: _receipt(),
        conversationID: 'conversation-1',
        runID: 'run-1',
        promptID: 'prompt-1',
        runCreatedAtMS: 10,
        runLatestSequence: 2,
        runStatus: 'completed',
      ),
      throwsFormatException,
    );
  });

  testWidgets('Gate forwards independently injected converged readers', (
    tester,
  ) async {
    final store = ForgeCredentialStore(
      backend: MemoryForgeCredentialBackend(),
      forcePersistentStorage: true,
    );
    expect(await store.store(accessToken: 'paired-reader-token'), isTrue);
    var runReads = 0;
    var receiptReads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: _client(),
          runObservedReader: (_, _) async {
            runReads++;
            return _runObserved();
          },
          sessionRunnerReceiptObservationReader: (_, _) async {
            receiptReads++;
            return _receipt();
          },
        ),
      ),
    );
    await _settle(tester);
    expect(runReads, 1);
    expect(receiptReads, 1);
    expect(
      find.text(
        'Could not converge Run and Runner receipt observations.',
        skipOffstage: false,
      ),
      findsNothing,
    );
    await _scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('forge-run-observed-card')),
    );

    expect(
      find.byKey(const ValueKey('forge-run-observed-card')),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('paired refresh failure revokes both projections', (
    tester,
  ) async {
    var receiptReads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'paired-reader-token',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObservedReader: (_, _) async => _runObserved(),
          sessionRunnerReceiptObservationReader: (_, _) async {
            receiptReads++;
            if (receiptReads > 1) throw StateError('receipt unavailable');
            return _receipt();
          },
        ),
      ),
    );
    await _settle(tester);
    await _scrollUntilBuilt(
      tester,
      find.byKey(const ValueKey('forge-run-observed-card')),
    );
    expect(
      find.byKey(const ValueKey('forge-run-observed-card')),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.refresh).last);
    await _settle(tester);

    expect(find.byKey(const ValueKey('forge-run-observed-card')), findsNothing);
    expect(
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
      findsNothing,
    );
    expect(receiptReads, greaterThan(1));
  });

  testWidgets('late paired response cannot replace the current snapshot', (
    tester,
  ) async {
    final lateRun = Completer<ForgeRunObserved>();
    const screenKey = ValueKey('paired-reader-screen');
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          key: screenKey,
          accessToken: 'paired-reader-token',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObservedReader: (_, _) => lateRun.future,
          sessionRunnerReceiptObservationReader: (_, _) async =>
              _receipt(commandID: 'command-late'),
        ),
      ),
    );
    await _pumpFor(tester);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          key: screenKey,
          accessToken: 'paired-reader-token',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObservedReader: (_, _) async => _runObserved(),
          sessionRunnerReceiptObservationReader: (_, _) async =>
              _receipt(commandID: 'command-current'),
        ),
      ),
    );
    await _settle(tester);
    await _scrollUntilBuilt(
      tester,
      find.byKey(
        const ValueKey('forge-session-runner-receipt-observation-card'),
      ),
    );
    expect(find.text('command-current'), findsOneWidget);

    lateRun.complete(_runObserved());
    await _settle(tester);
    expect(find.text('command-current'), findsOneWidget);
    expect(find.text('command-late'), findsNothing);
  });
}

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

ForgeRunObserved _runObserved({
  String ownerRef =
      '21444e9222fa722f4b05e8a353e2e840594863c941bba4c2222b3c22bb198ba5',
}) => ForgeRunObserved(
  ownerRef: ownerRef,
  conversationID: 'conversation-1',
  runID: 'run-1',
  promptID: 'prompt-1',
  createdAtMS: 10,
  latestSequence: 2,
  status: 'completed',
  metadataObserved: true,
  contentIncluded: false,
  authority: const ForgeRunObservedAuthority.offline(),
);

ForgeSessionRunnerReceiptObservation _receipt({
  String commandID = 'command-1',
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
    commandID: commandID,
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
  authority: const ForgeSessionRunnerReceiptObservationAuthority.offline(),
);

http.Client _client() => MockClient((request) async {
  switch ('${request.method} ${request.url.path}') {
    case 'GET /api/v1/conversations':
      return _json({
        'conversations': [
          {
            'conversation': {
              'id': 'conversation-1',
              'scope': {'kind': 'global'},
              'title': 'Convergence test',
              'created_at_ms': 1,
              'updated_at_ms': 2,
            },
            'aggregate_version': 1,
          },
        ],
        'has_more': false,
      });
    case 'GET /api/v1/conversations/conversation-1/prompts':
      return _json({
        'conversation_id': 'conversation-1',
        'prompts': <Object>[],
        'has_more': false,
      });
    case 'GET /api/v1/conversations/conversation-1/runs':
      return _json({
        'conversation_id': 'conversation-1',
        'runs': [
          {
            'run_id': 'run-1',
            'prompt_id': 'prompt-1',
            'created_at_ms': 10,
            'latest_sequence': 2,
            'status': 'completed',
          },
        ],
        'has_more': false,
      });
    case 'GET /api/v1/conversations/conversation-1/runs/run-1/timeline':
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
    default:
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
  }
});

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Future<void> _pumpFor(WidgetTester tester) async {
  for (var index = 0; index < 40; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> _settle(WidgetTester tester) async {
  await _pumpFor(tester);
}

Future<void> _scrollUntilBuilt(WidgetTester tester, Finder target) async {
  final scrollable = find.byType(Scrollable).first;
  for (var index = 0; index < 30 && target.evaluate().isEmpty; index++) {
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump();
  }
  expect(target, findsOneWidget);
}
