import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

/// Authenticated shared Web/App/Mobile screen acceptance for the client
/// instance session projection candidate.
///
/// The candidate origin and enable flag are deliberately supplied only by
/// this harness. Normal ForgeSessionsGate construction leaves the candidate
/// reader unset and therefore request-free.
void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_SESSION_PROJECTION_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() => Session.clear());

  tearDown(() => Session.clear());

  testWidgets(
    'authenticated Gate filters a client instance and appends a Prompt',
    (tester) async {
      final input = _readInput(inputPath);
      final apiURL = _string(input, 'api_url');
      final accessToken = _string(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final instanceID = _string(input, 'instance_id');
      final visibleConversationID = _string(input, 'visible_conversation_id');
      final hiddenConversationID = _string(input, 'hidden_conversation_id');
      final visibleTitle = _string(input, 'visible_title');
      final hiddenTitle = _string(input, 'hidden_title');
      final prompt = _string(input, 'prompt');
      if (apiURL.isEmpty ||
          accessToken.isEmpty ||
          instanceID.isEmpty ||
          visibleConversationID.isEmpty ||
          hiddenConversationID.isEmpty ||
          visibleTitle.isEmpty ||
          hiddenTitle.isEmpty ||
          prompt.isEmpty ||
          visibleConversationID == hiddenConversationID) {
        throw const FormatException(
          'Invalid client-instance session projection E2E input.',
        );
      }

      final credentialBackend = MemoryForgeCredentialBackend();
      final credentialStore = ForgeCredentialStore(
        backend: credentialBackend,
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      Session.clearForClient(ForgeConversationsOAuth.clientId);
      addTearDown(() async {
        Session.clearForClient(ForgeConversationsOAuth.clientId);
        await credentialStore.clear();
      });

      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewCandidateApiOrigin: apiURL,
            enableClientInstanceSessionViewCandidate: true,
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewCandidateApiOrigin: apiURL,
            enableClientInstanceResourceViewCandidate: true,
            deviceInventoryResourceConvergenceOwner: owner,
            deviceInventoryResourceConvergenceCandidateApiOrigin: apiURL,
            enableDeviceInventoryResourceConvergenceCandidate: true,
            requireDeviceInventoryResourceConvergenceForPromptAppend: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () =>
            find
                .byKey(
                  const ValueKey('forge-client-instance-session-view-panel'),
                )
                .evaluate()
                .isNotEmpty &&
            find
                .byKey(
                  const ValueKey('forge-client-instance-resource-view-panel'),
                )
                .evaluate()
                .isNotEmpty,
        waitFor: 'authenticated client-instance session/resource views',
      );

      expect(
        find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
        findsOneWidget,
      );
      await _scrollUntilConversationVisible(tester, visibleConversationID);
      await _pumpUntil(
        tester,
        () =>
            find
                .byKey(ValueKey('forge-conversation-$visibleConversationID'))
                .evaluate()
                .isNotEmpty &&
            find
                .byKey(ValueKey('forge-conversation-$hiddenConversationID'))
                .evaluate()
                .isNotEmpty,
        waitFor: 'authenticated owner conversations',
      );
      for (final declaredInstanceID in const [
        'client-cli-001',
        'client-tui-001',
        'client-web-001',
        'client-app-001',
        'client-mobile-001',
      ]) {
        expect(
          find.byKey(
            ValueKey('forge-client-instance-session-view-$declaredInstanceID'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text(visibleTitle), findsWidgets);
      expect(find.text(hiddenTitle), findsWidgets);

      final filterMenu = find.byKey(
        const ValueKey('forge-client-instance-session-filter-menu'),
      );
      expect(filterMenu, findsOneWidget);
      await tester.ensureVisible(filterMenu);
      await tester.tap(filterMenu);
      await tester.pumpAndSettle();
      final instanceItem = find.text(instanceID);
      expect(instanceItem, findsWidgets);
      await tester.tap(instanceItem.last);
      // The screen owns a long-lived change-feed poll. Let the local filter
      // callback render once, then use the bounded authenticated wait below;
      // pumpAndSettle would advance the fake clock into the next live poll.
      await tester.pump();

      await _scrollUntilConversationVisible(tester, visibleConversationID);
      await _pumpUntil(
        tester,
        () =>
            find
                .byKey(ValueKey('forge-conversation-$visibleConversationID'))
                .evaluate()
                .isNotEmpty &&
            find
                .byKey(ValueKey('forge-conversation-$hiddenConversationID'))
                .evaluate()
                .isEmpty,
        waitFor: 'local client-instance session filter',
      );
      expect(find.text(visibleTitle), findsWidgets);
      expect(find.text(hiddenTitle), findsNothing);

      final promptField = find.byType(TextField).last;
      await tester.ensureVisible(promptField);
      await tester.enterText(promptField, prompt);
      await tester.ensureVisible(find.text('Append prompt'));
      await tester.tap(find.text('Append prompt'));
      await _pumpUntil(
        tester,
        () =>
            find.text(prompt).evaluate().isNotEmpty &&
            find
                .text('Prompt stored. It has not started a task.')
                .evaluate()
                .isNotEmpty &&
            tester.widget<TextField>(promptField).controller?.text.isEmpty ==
                true,
        waitFor: 'authenticated client-instance Prompt append',
      );
      expect(find.text(prompt), findsOneWidget);
      expect(find.text(hiddenTitle), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      // The screen starts an owner change-feed poll during initialization.
      // Let any in-flight bounded read timeout settle after disposal so a
      // slow mobile candidate cannot leave a fake timer in the test binding.
      await tester.pump(const Duration(seconds: 21));
    },
    skip: inputPath == null,
  );
}

Future<void> _scrollUntilConversationVisible(
  WidgetTester tester,
  String conversationID,
) async {
  final conversation = find.byKey(
    ValueKey('forge-conversation-$conversationID'),
  );
  for (var count = 0; count < 24; count++) {
    if (conversation.evaluate().isNotEmpty) return;
    final lists = find.byType(ListView);
    if (lists.evaluate().isEmpty) {
      await tester.pump();
      continue;
    }
    await tester.drag(lists.first, const Offset(0, -500));
    await tester.pump();
  }
  expect(
    conversation,
    findsOneWidget,
    reason: 'Timed out scrolling to conversation $conversationID.',
  );
}

Map<String, dynamic> _readInput(String? path) {
  if (path == null || path.isEmpty) {
    throw const FormatException('Missing client-instance session E2E input.');
  }
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Client-instance session E2E input must be an object.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _string(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String) {
    throw FormatException('Client-instance session E2E field $key is invalid.');
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
    reason: 'Timed out waiting for $waitFor from the authenticated Forge API.',
  );
}
