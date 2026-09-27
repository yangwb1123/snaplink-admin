import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

/// The Go harness supplies a real Snaplink JWT and a test-only candidate mux.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_DISPATCH_PLAN_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate binds client-instance pair before dispatch preview',
    (tester) async {
      if (inputPath == null) return;
      final input = _readInput(inputPath);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final instanceID = _requiredText(input, 'instance_id');
      final expectCard = input['expect_dispatch_card'] == true;
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final request = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
        input['request'],
      );
      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      tester.view.physicalSize = const Size(1280, 10000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            initialConversationID: request.conversationID,
            initialClientInstanceID: instanceID,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewCandidateApiOrigin: apiURL,
            enableClientInstanceSessionViewCandidate: true,
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewCandidateApiOrigin: apiURL,
            enableClientInstanceResourceViewCandidate: true,
            runnerDispatchPlanPreviewRequest: request,
            runnerDispatchPlanPreviewCandidateApiOrigin: apiURL,
            enableRunnerDispatchPlanPreviewCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-runner-dispatch-plan-preview-card'))
            .evaluate()
            .isNotEmpty,
      );
      final card = find.byKey(
        const ValueKey('forge-runner-dispatch-plan-preview-card'),
      );
      if (expectCard) {
        expect(card, findsOneWidget);
        expect(
          find.text('Preview only · no dispatch performed'),
          findsOneWidget,
        );
      } else {
        expect(card, findsNothing);
      }
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge client-instance dispatch Gate input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Forge dispatch Gate $key.');
  }
  return value;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var index = 0; index < 360; index++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}
