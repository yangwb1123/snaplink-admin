import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

/// Opt-in integration entry for the shared Web/App/Mobile Sessions Gate. It
/// selects the seeded owner Conversation and Run through Core HTTP, then
/// enables the explicit two-step history-to-reconciliation candidate.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate renders the session Runner reconciliation chain',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final historyValue = input['history'];
      if (historyValue is! Map) {
        throw const FormatException(
          'Missing session Runner reconciliation Gate history.',
        );
      }
      final history = ForgeSessionRunnerReceiptHistory.fromJson(historyValue);
      final conversationID = _requiredText(input, 'conversation_id');
      final promptID = _requiredText(input, 'prompt_id');
      final runID = _requiredText(input, 'run_id');
      if (!history.isDisplayOnly ||
          !history.hasUncertainTerminal ||
          !history.isFor(conversationID, runID) ||
          history.promptID != promptID) {
        throw const FormatException(
          'Session Runner reconciliation Gate history binding is invalid.',
        );
      }
      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      tester.view.physicalSize = const Size(1280, 2600);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            sessionRunnerReconciliationProjectionRequest: history,
            sessionRunnerReconciliationProjectionCandidateApiOrigin: apiURL,
            enableSessionRunnerReconciliationProjectionHistoryChainCandidate:
                true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(
              const ValueKey(
                'forge-session-runner-reconciliation-projection-remote-panel',
              ),
            )
            .evaluate()
            .isNotEmpty,
        waitFor: 'authenticated session Runner reconciliation panel',
      );

      await tester.scrollUntilVisible(
        find.byKey(
          const ValueKey(
            'forge-session-runner-reconciliation-projection-remote-panel',
          ),
        ),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        find.byKey(
          const ValueKey(
            'forge-session-runner-reconciliation-projection-latest',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Session Runner reconciliation'), findsOneWidget);
      expect(
        find.text('Manual review · automatic retry disabled'),
        findsOneWidget,
      );
      expect(
        find.text('Latest attempt: ${history.latestAttemptID} · uncertain'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Reason: uncertain_terminal_receipt · follow-up: reconciliation_manual',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Selected target: none · authority: disabled'),
        findsOneWidget,
      );
      expect(find.text('fencing_token'), findsNothing);
      expect(find.text('receipt_sha256'), findsNothing);
      expect(find.textContaining('argv'), findsNothing);
      expect(find.textContaining('workspace'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid session Runner reconciliation Gate E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing session Runner reconciliation Gate $key.');
  }
  return value;
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String waitFor,
}) async {
  for (var count = 0; count < 300; count++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for $waitFor from the accepted Forge Gate.',
  );
}
