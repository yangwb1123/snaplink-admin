import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
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

/// Real-JWT acceptance for the read-only Run/Attempt/lease preflight candidate.
/// The Go harness supplies the private test mux. Each visible Web/App/Mobile
/// instance must refresh the client-instance pair and inventory/resource image
/// before one metadata POST; a hidden Run remains request-free.
void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_RUN_ATTEMPT_LEASE_DISPATCH_PREFLIGHT_PROJECTION_E2E_INPUT'];

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
    'Web App and Mobile preflight joins observations before one POST',
    (tester) async {
      final input = _readInput(inputPath);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final request = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
        input['request'],
      );
      if (request.owner != owner) {
        throw const FormatException(
          'Preflight E2E owner must match the authenticated input owner.',
        );
      }
      final clientKinds = _clientKinds(input);
      final expectPreflight = input['expect_preflight'] != false;

      tester.view.physicalSize = const Size(1280, 3000);
      tester.view.devicePixelRatio = 1;
      for (final clientKind in clientKinds) {
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
              runAttemptLeaseDispatchPreflightRequest: request,
              runAttemptLeaseDispatchPreflightCandidateApiOrigin: apiURL,
              enableRunAttemptLeaseDispatchPreflightCandidate: true,
            ),
          ),
        );

        if (expectPreflight) {
          await _pumpUntilText(
            tester,
            'Forge preflight preview',
            waitFor: '$clientKind authenticated Run/Attempt/lease preflight',
          );
          expect(
            find.text('Preview only · no dispatch performed'),
            findsOneWidget,
          );
          expect(find.text('Selected target'), findsOneWidget);
        } else {
          // The selected instance does not expose the requested Conversation;
          // allow owner/session refresh to settle, then prove the preflight
          // card never appears.
          await _pumpUntilText(
            tester,
            'No conversations are visible from this client instance.',
            waitFor: 'hidden client-instance projection',
          );
          expect(find.text('Forge preflight preview'), findsNothing);
        }

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 21));
        await credentialStore.clear();
        Session.clearForClient(ForgeConversationsOAuth.clientId);
      }
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
    throw const FormatException('Missing preflight projection E2E input.');
  }
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Preflight projection E2E input must be an object.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing preflight projection field $key.');
  }
  return value;
}

List<String> _clientKinds(Map<String, dynamic> input) {
  final value = input['client_kinds'];
  if (value == null) return const ['web', 'app', 'mobile'];
  if (value is! List || value.isEmpty || value.any((item) => item is! String)) {
    throw const FormatException('Invalid preflight projection client kinds.');
  }
  return value.cast<String>();
}

Future<void> _pumpUntilText(
  WidgetTester tester,
  String text, {
  required String waitFor,
}) async {
  final target = find.text(text);
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
