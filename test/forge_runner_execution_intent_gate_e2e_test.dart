import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
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
      Platform.environment['FORGE_RUNNER_EXECUTION_INTENT_GATE_E2E_INPUT'];

  testWidgets(
    'authenticated Sessions Gate renders one Runner execution-intent preview',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final request = ForgeRunnerExecutionIntentRequest.fromJson(
        input['request'],
      );
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
            runnerExecutionIntentRequest: request,
            runnerExecutionIntentCandidateApiOrigin: apiURL,
            enableRunnerExecutionIntentCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-runner-execution-intent-card'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'authenticated Runner execution-intent card',
      );

      expect(
        find.byKey(const ValueKey('forge-runner-execution-intent-card')),
        findsOneWidget,
      );
      expect(find.text('Runner execution intent preview'), findsOneWidget);
      expect(find.text(request.conversationID), findsWidgets);
      expect(find.text(request.run.runID), findsWidgets);
      expect(find.text(request.binding.targetID), findsOneWidget);
      expect(find.text('Selected target'), findsOneWidget);
      expect(find.text('none'), findsOneWidget);
      expect(find.text('Authority granted'), findsOneWidget);
      expect(find.text('false'), findsWidgets);
      expect(find.text(request.command.leaseProof.fencingToken), findsNothing);
      expect(find.text(request.command.workspaceRef), findsNothing);
      expect(find.text(request.command.argv.first), findsNothing);

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
      'Invalid Runner execution-intent Gate E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Runner execution-intent Gate $key.');
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
    final list = find.byType(ListView);
    if (list.evaluate().isNotEmpty) {
      await tester.drag(list.first, const Offset(0, -900));
    }
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
