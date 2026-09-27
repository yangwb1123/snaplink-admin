import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';
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
      Platform.environment['FORGE_RUNNER_ATTEMPT_BOUNDARY_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'shared Web App Mobile Sessions Gate renders Attempt boundary preview',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final request = ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(
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
            runnerAttemptBoundaryRequest: request,
            runnerAttemptBoundaryCandidateApiOrigin: apiURL,
            enableRunnerAttemptBoundaryCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-runner-attempt-boundary-card'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'authenticated Runner Attempt boundary card',
      );

      expect(
        find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
        findsOneWidget,
      );
      expect(find.text('Runner Attempt boundary preview'), findsOneWidget);
      expect(find.textContaining('accepted → starting'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('forge-runner-attempt-boundary-card')),
          matching: find.text(
            '${request.command.commandID} / ${request.command.leaseProof.targetID}',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('Preview only'), findsOneWidget);
      expect(find.text(request.command.leaseProof.fencingToken), findsNothing);
      expect(find.text(request.command.argv.first), findsNothing);
      expect(find.text(request.command.workspaceRef), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('Invalid Runner Attempt boundary Gate input.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Runner Attempt boundary Gate $key.');
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
