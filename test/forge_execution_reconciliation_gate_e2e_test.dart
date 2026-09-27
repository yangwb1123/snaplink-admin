import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';
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
      Platform.environment['FORGE_EXECUTION_RECONCILIATION_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate renders one execution reconciliation preview',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final request = ForgeExecutionReconciliationInput.fromJson(
        input['request'],
      );
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
            executionReconciliationInput: request,
            executionReconciliationCandidateApiOrigin: apiURL,
            enableExecutionReconciliationCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(
              const ValueKey('forge-execution-reconciliation-observation-card'),
            )
            .evaluate()
            .isNotEmpty,
        waitFor: 'authenticated execution reconciliation card',
      );

      expect(
        find.byKey(
          const ValueKey('forge-execution-reconciliation-observation-card'),
        ),
        findsOneWidget,
      );
      expect(find.text('Execution reconciliation preview'), findsOneWidget);
      expect(find.text('Run binding'), findsOneWidget);
      expect(find.text(request.conversationID), findsOneWidget);
      expect(find.text(request.runID), findsWidgets);
      expect(find.text('Lease and terminal evidence'), findsOneWidget);
      expect(find.text('Classification'), findsOneWidget);
      expect(find.text('Next observation'), findsOneWidget);
      expect(find.text('terminal_uncertain'), findsOneWidget);
      expect(find.text('Reconciliation required'), findsOneWidget);
      expect(find.text('Manual review required'), findsOneWidget);
      expect(find.text('Automatic retry'), findsOneWidget);
      expect(find.text('Authority'), findsOneWidget);
      expect(find.text('Execution authorized'), findsOneWidget);
      expect(find.text('Audit published'), findsOneWidget);
      expect(find.text('transport ended after effect boundary'), findsNothing);
      expect(find.text(request.lease.fencingToken), findsNothing);
      expect(find.textContaining('does not retry'), findsOneWidget);

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
      'Invalid execution reconciliation Gate E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing execution reconciliation Gate $key.');
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
