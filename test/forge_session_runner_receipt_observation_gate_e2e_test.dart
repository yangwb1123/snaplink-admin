import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate renders one session Runner receipt observation',
    (tester) async {
      final input = _readInput(inputPath!);
      final accessToken = _requiredText(input, 'access_token');
      final conversationID = _requiredText(input, 'conversation_id');
      final promptID = _requiredText(input, 'prompt_id');
      final runID = _requiredText(input, 'run_id');
      final rawObservation = input['observation'];
      if (rawObservation is! Map) {
        throw const FormatException(
          'Missing session Runner receipt Gate observation.',
        );
      }
      final observation = ForgeSessionRunnerReceiptObservation.fromJson(
        rawObservation,
      );
      if (!observation.isFor(conversationID, runID) ||
          observation.promptID != promptID ||
          !observation.isDisplayOnly) {
        throw const FormatException(
          'Session Runner receipt Gate observation binding is invalid.',
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
            sessionRunnerReceiptObservation: observation,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(
              const ValueKey('forge-session-runner-receipt-observation-card'),
            )
            .evaluate()
            .isNotEmpty,
        waitFor: 'authenticated session Runner receipt card',
      );

      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-observation-card'),
        ),
        findsOneWidget,
      );
      expect(find.text('Session Runner receipt preview'), findsOneWidget);
      expect(find.text('Session binding'), findsOneWidget);
      expect(find.text(conversationID), findsOneWidget);
      expect(find.text(promptID), findsOneWidget);
      expect(find.text(runID), findsWidgets);
      expect(find.text('Terminal receipt'), findsOneWidget);
      expect(find.text('Disposition'), findsOneWidget);
      expect(find.text('completed'), findsOneWidget);
      expect(find.text('Receipt valid'), findsOneWidget);
      expect(find.text('Follow-up'), findsOneWidget);
      expect(find.text('none'), findsWidgets);
      expect(find.text('Selected target'), findsOneWidget);
      expect(find.text('Authority'), findsOneWidget);
      expect(find.text('Receipt persisted'), findsOneWidget);
      expect(find.text('Execution authorized'), findsOneWidget);
      expect(find.text('Dispatch performed'), findsOneWidget);
      expect(find.text('Audit published'), findsOneWidget);
      expect(find.text('fence-001'), findsNothing);
      expect(find.text('forge-task'), findsNothing);
      expect(find.textContaining('no receipt is persisted'), findsOneWidget);

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
      'Invalid session Runner receipt Gate E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing session Runner receipt Gate $key.');
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
