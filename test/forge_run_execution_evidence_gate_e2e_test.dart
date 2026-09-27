import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
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
      Platform.environment['FORGE_RUN_EXECUTION_EVIDENCE_E2E_INPUT'];
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'Flutter Sessions Gate consumes one authenticated Run execution evidence card',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final conversationID = _requiredText(input, 'conversation_id');
      final runID = _requiredText(input, 'run_id');
      final rawRun = input['run_observed'];
      final rawReceipt = input['session_receipt_observed'];
      if (rawRun is! Map || rawReceipt is! Map) {
        throw const FormatException('Missing Run evidence source values.');
      }
      final run = ForgeRunObserved.fromJson(rawRun);
      final receipt = ForgeSessionRunnerReceiptObservation.fromJson(rawReceipt);
      if (!run.isFor(conversationID, runID) ||
          !receipt.isFor(conversationID, runID) ||
          run.promptID != receipt.promptID ||
          !run.isDisplayOnly ||
          !receipt.isDisplayOnly) {
        throw const FormatException(
          'Run evidence sources are not display-only.',
        );
      }
      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      tester.view.physicalSize = const Size(1280, 2200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            runObserved: run,
            sessionRunnerReceiptObservation: receipt,
            runExecutionEvidenceCandidateApiOrigin: apiURL,
            enableRunExecutionEvidenceCandidate: true,
          ),
        ),
      );

      await _pumpUntilAndRevealEvidenceCard(tester);
      expect(find.text('Run execution evidence preview'), findsOneWidget);
      expect(find.text('true'), findsWidgets);
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('Invalid Run execution evidence E2E input.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Run execution evidence $key.');
  }
  return value;
}

Future<void> _pumpUntilAndRevealEvidenceCard(WidgetTester tester) async {
  final card = find.byKey(const ValueKey('forge-run-execution-evidence-card'));
  final scrollable = find.byType(Scrollable).first;
  for (var attempt = 0; attempt < 120; attempt++) {
    if (card.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(card, 600, scrollable: scrollable);
      return;
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    await tester.drag(scrollable, const Offset(0, -500));
    await tester.pump();
  }
  throw StateError('Timed out waiting for Run execution evidence card.');
}
