import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_change_cursor_store.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

/// Host-side proof of the native cold-start path used by Android/iOS.
///
/// The injected backend stands in for the platform secure credential store;
/// this test does not claim to have run on a physical Android or iOS device.
/// An explicit `android-host` or `ios-host` marker is required in the private
/// input so a runner cannot accidentally report this as physical-device
/// instrumentation.
void main() {
  final inputPath = Platform.environment['FORGE_MOBILE_E2E_INPUT'];
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() => Session.clear());
  tearDown(() => Session.clear());

  test(
    'host-side native cold start shares a Conversation and replays one Prompt',
    () async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final platform = input['platform'];
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final rotatedAccessToken = input['rotated_access_token'];
      final conversationID = input['conversation_id'];
      final expectedVersion = input['expected_version'];
      final afterCursor = input['after_cursor'];
      final prompt = input['prompt'];
      final idempotencyKey = input['idempotency_key'];
      if (!(platform == 'android-host' || platform == 'ios-host') ||
          apiURL is! String ||
          accessToken is! String ||
          rotatedAccessToken is! String ||
          conversationID is! String ||
          expectedVersion is! int ||
          afterCursor is! int ||
          prompt is! String ||
          idempotencyKey is! String ||
          conversationID.isEmpty ||
          rotatedAccessToken.isEmpty ||
          rotatedAccessToken == accessToken ||
          prompt.isEmpty ||
          idempotencyKey.isEmpty) {
        throw const FormatException('Invalid host-side native E2E input.');
      }

      // The memory backend is the test double for the native secure store.
      // Keeping it alive across store instances models two independently
      // started native clients reading the same platform record.
      final secureBackend = MemoryForgeCredentialBackend();
      final loginStore = ForgeCredentialStore(
        backend: secureBackend,
        forcePersistentStorage: true,
      );
      expect(
        await loginStore.store(
          accessToken: accessToken,
          sessionId: 'host-native-session',
          refreshToken: 'host-native-refresh',
        ),
        isTrue,
      );

      // Seed the owner-local cursor as if the previous native process had
      // already consumed the current feed. The two cold starts below then
      // prove that the cursor is restored and advanced through the same
      // persisted platform record as the bearer credential.
      final seededCursorStore = ForgeChangeCursorStore(
        accessToken: accessToken,
        apiOrigin: apiURL,
        clientId: ForgeConversationsOAuth.clientId,
        resource: ForgeConversationsOAuth.resource,
      );
      expect(await seededCursorStore.save(afterCursor), isTrue);

      // Cold start #1: no in-memory Session slot is available to the API.
      Session.clearForClient(ForgeConversationsOAuth.clientId);
      final firstColdStore = ForgeCredentialStore(
        backend: secureBackend,
        forcePersistentStorage: true,
      );
      final firstToken = await firstColdStore.restore();
      expect(firstToken, accessToken);
      final firstAPI = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: firstToken!,
        httpClient: http.Client(),
      );

      try {
        final firstPage = await firstAPI.listConversations(limit: 50);
        final firstConversation = firstPage.conversations.singleWhere(
          (entry) => entry.conversation.id == conversationID,
        );
        expect(firstConversation.aggregateVersion, expectedVersion);

        final firstCursorStore = ForgeChangeCursorStore(
          accessToken: firstToken,
          apiOrigin: apiURL,
          clientId: ForgeConversationsOAuth.clientId,
          resource: ForgeConversationsOAuth.resource,
        );
        final restoredFirstCursor = await firstCursorStore.load();
        expect(restoredFirstCursor, afterCursor);
        final baselineChanges = await firstAPI.conversationChanges(
          afterCursor: restoredFirstCursor,
          limit: 128,
        );
        expect(baselineChanges.changes, isEmpty);
        expect(baselineChanges.scannedThroughCursor, restoredFirstCursor);
        expect(
          await firstCursorStore.save(baselineChanges.scannedThroughCursor),
          isTrue,
        );

        final existingHistory = await firstAPI.listPrompts(
          conversationID: conversationID,
          limit: 100,
        );
        expect(existingHistory.prompts, isNotEmpty);

        final appended = await firstAPI.appendPrompt(
          conversationID: conversationID,
          content: prompt,
          expectedVersion: expectedVersion,
          idempotencyKey: idempotencyKey,
        );
        expect(appended.prompt.conversationID, conversationID);
        expect(appended.prompt.content, prompt);
        expect(appended.aggregateVersion, expectedVersion + 1);
        expect(appended.replayed, isFalse);
      } finally {
        firstAPI.close();
      }

      // A second native client may rotate the shared OAuth record while this
      // process is backgrounded. Replace the persistent tuple before the
      // second cold start, then clear only the in-memory slot. This models an
      // iOS Keychain rotation without claiming that this host test touched a
      // physical device or the platform plugin itself.
      expect(
        await loginStore.store(
          accessToken: rotatedAccessToken,
          sessionId: 'host-native-session-rotated',
          refreshToken: 'host-native-refresh-rotated',
        ),
        isTrue,
      );

      // Cold start #2: clear the process slot again and restore from the
      // rotated persisted record before replaying the write.
      Session.clearForClient(ForgeConversationsOAuth.clientId);
      final secondColdStore = ForgeCredentialStore(
        backend: secureBackend,
        forcePersistentStorage: true,
      );
      final secondToken = await secondColdStore.restore();
      expect(secondToken, rotatedAccessToken);
      final secondAPI = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: secondToken!,
        httpClient: http.Client(),
      );
      try {
        final secondPage = await secondAPI.listConversations(limit: 50);
        final secondConversation = secondPage.conversations.singleWhere(
          (entry) => entry.conversation.id == conversationID,
        );
        expect(secondConversation.aggregateVersion, expectedVersion + 1);

        final secondCursorStore = ForgeChangeCursorStore(
          accessToken: secondToken,
          apiOrigin: apiURL,
          clientId: ForgeConversationsOAuth.clientId,
          resource: ForgeConversationsOAuth.resource,
        );
        final restoredSecondCursor = await secondCursorStore.load();
        expect(restoredSecondCursor, afterCursor);

        final replayed = await secondAPI.appendPrompt(
          conversationID: conversationID,
          content: prompt,
          expectedVersion: expectedVersion,
          idempotencyKey: idempotencyKey,
        );
        expect(replayed.prompt.id, isNotEmpty);
        expect(replayed.prompt.content, prompt);
        expect(replayed.aggregateVersion, expectedVersion + 1);
        expect(replayed.replayed, isTrue);

        final history = await secondAPI.listPrompts(
          conversationID: conversationID,
          limit: 100,
        );
        final matching = history.prompts
            .where((value) => value.content == prompt)
            .toList(growable: false);
        expect(matching, hasLength(1));
        expect(matching.single.id, replayed.prompt.id);

        final changes = await secondAPI.conversationChanges(
          afterCursor: restoredSecondCursor,
          limit: 128,
        );
        expect(changes.afterCursor, restoredSecondCursor);
        expect(changes.scannedThroughCursor, greaterThan(restoredSecondCursor));
        final promptChanges = changes.changes
            .where(
              (change) =>
                  change.conversationID == conversationID &&
                  change.kind == 'prompt_appended' &&
                  change.aggregateVersion == expectedVersion + 1,
            )
            .toList(growable: false);
        expect(promptChanges, hasLength(1));
        expect(
          promptChanges.single.cursor,
          lessThanOrEqualTo(changes.scannedThroughCursor),
        );
        expect(
          await secondCursorStore.save(changes.scannedThroughCursor),
          isTrue,
        );
      } finally {
        secondAPI.close();
      }
    },
    skip: inputPath == null
        ? 'Run through scripts/test-forge-shared-session-e2e.sh.'
        : false,
  );
}
