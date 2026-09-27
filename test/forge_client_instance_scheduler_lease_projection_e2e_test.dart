import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

/// Real-JWT acceptance for the shared Web/App/Mobile Sessions Gate. The Go
/// harness mounts all four read/write candidates only on its private test mux;
/// ordinary Gate construction and the production Core assembler remain closed.
void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_SCHEDULER_LEASE_PROJECTION_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets(
    'web app and mobile converge both observation pairs before lease claim',
    (tester) async {
      final input = _readInput(inputPath);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final request = ForgeSchedulerSelectionLeaseRequest.fromJson(
        input['request'],
      );
      final idempotencyKey = _requiredText(input, 'idempotency_key');
      final expectedDeviceID = _requiredText(input, 'expected_device_id');
      final expectedInstanceID = _requiredText(input, 'expected_instance_id');
      final hiddenConversationID = _requiredText(
        input,
        'hidden_conversation_id',
      );
      if (hiddenConversationID == request.conversationID) {
        throw const FormatException(
          'Hidden scheduler lease conversation must differ from the visible request.',
        );
      }

      tester.view.physicalSize = const Size(1280, 3000);
      tester.view.devicePixelRatio = 1;
      for (final clientKind in const ['web', 'app', 'mobile']) {
        final credentialStore = await _credentialStore(accessToken);
        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsGate(
              credentialStore: credentialStore,
              initialConversationID: request.conversationID,
              initialClientInstanceID: 'client-$clientKind-001',
              deviceInventoryResourceConvergenceOwner: owner,
              deviceInventoryResourceConvergenceCandidateApiOrigin: apiURL,
              enableDeviceInventoryResourceConvergenceCandidate: true,
              clientInstanceSessionResourceConvergenceOwner: owner,
              clientInstanceSessionResourceConvergenceCandidateApiOrigin:
                  apiURL,
              enableClientInstanceSessionResourceConvergenceCandidate: true,
              schedulerSelectionLeaseRequest: request,
              schedulerSelectionLeaseCandidateApiOrigin: apiURL,
              schedulerSelectionLeaseIdempotencyKey: idempotencyKey,
              enableSchedulerSelectionLeaseCandidate: true,
            ),
          ),
        );

        await _pumpUntilVisible(
          tester,
          const ValueKey('forge-scheduler-selection-lease-panel'),
          waitFor: '$clientKind authenticated scheduler lease',
        );
        expect(
          find.text('Target: $expectedDeviceID/$expectedInstanceID'),
          findsOneWidget,
        );
        expect(find.textContaining('Lease issued;'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 21));
        await credentialStore.clear();
        Session.clearForClient(ForgeConversationsOAuth.clientId);
      }

      // The selected Web instance does not declare this Conversation. It must
      // still authenticate and refresh the session/resource pair, then stop
      // locally without reaching inventory authority or the lease POST.
      final hiddenRequestJSON = Map<String, dynamic>.from(request.toJson())
        ..['conversation_id'] = hiddenConversationID
        ..['run_id'] = 'run-hidden-console-lease';
      final hiddenStore = await _credentialStore(accessToken);
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: hiddenStore,
            initialClientInstanceID: 'client-web-001',
            deviceInventoryResourceConvergenceOwner: owner,
            deviceInventoryResourceConvergenceCandidateApiOrigin: apiURL,
            enableDeviceInventoryResourceConvergenceCandidate: true,
            clientInstanceSessionResourceConvergenceOwner: owner,
            clientInstanceSessionResourceConvergenceCandidateApiOrigin: apiURL,
            enableClientInstanceSessionResourceConvergenceCandidate: true,
            schedulerSelectionLeaseRequest:
                ForgeSchedulerSelectionLeaseRequest.fromJson(hiddenRequestJSON),
            schedulerSelectionLeaseCandidateApiOrigin: apiURL,
            schedulerSelectionLeaseIdempotencyKey:
                '$idempotencyKey-hidden-console',
            enableSchedulerSelectionLeaseCandidate: true,
          ),
        ),
      );
      await _pumpUntilVisible(
        tester,
        const ValueKey('forge-client-instance-session-view-panel'),
        waitFor: 'hidden Web instance session/resource observation',
      );
      expect(
        find.byKey(const ValueKey('forge-scheduler-selection-lease-panel')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
      await hiddenStore.clear();
      Session.clearForClient(ForgeConversationsOAuth.clientId);
    },
    skip: inputPath == null,
  );
}

Future<ForgeCredentialStore> _credentialStore(String accessToken) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: accessToken), isTrue);
  Session.clearForClient(ForgeConversationsOAuth.clientId);
  return store;
}

Map<String, dynamic> _readInput(String? path) {
  if (path == null || path.isEmpty) {
    throw const FormatException(
      'Missing client-instance scheduler lease projection E2E input.',
    );
  }
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Client-instance scheduler lease projection E2E input must be an object.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException(
      'Missing client-instance scheduler lease projection field $key.',
    );
  }
  return value;
}

Future<void> _pumpUntilVisible(
  WidgetTester tester,
  Key key, {
  required String waitFor,
}) async {
  final target = find.byKey(key);
  for (var count = 0; count < 300; count++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
    final lists = find.byType(ListView);
    if (lists.evaluate().isNotEmpty) {
      await tester.drag(lists.first, const Offset(0, -300));
      await tester.pump();
    }
  }
  expect(
    target,
    findsOneWidget,
    reason: 'Timed out waiting for $waitFor from the authenticated Forge API.',
  );
}
