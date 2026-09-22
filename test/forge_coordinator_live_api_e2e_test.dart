import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform.environment['FORGE_CONSOLE_E2E_INPUT'];
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'Console API shares an owned session with Forge clients over HTTP',
    () async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final conversationID = input['conversation_id'];
      final expectedVersion = input['expected_version'];
      final idempotencyKey = input['idempotency_key'];
      final prompt = input['prompt'];
      final existingPrompt = input['existing_prompt'];
      final afterCursor = input['after_cursor'];
      final placementRequest = input['placement_request'];
      final pendingIntentID = input['pending_intent_id'];
      final pendingIntentPrompt = input['pending_intent_prompt'];
      final pendingIntentExpectedVersion =
          input['pending_intent_expected_version'];
      final pendingIntentKey = input['pending_intent_key'];
      final pendingIntentFresh = input['pending_intent_fresh'] ?? false;
      if (apiURL is! String ||
          accessToken is! String ||
          conversationID is! String ||
          expectedVersion is! int ||
          idempotencyKey is! String ||
          prompt is! String ||
          existingPrompt is! String ||
          afterCursor is! int ||
          placementRequest is! Map ||
          (pendingIntentID != null && pendingIntentID is! String) ||
          (pendingIntentPrompt != null && pendingIntentPrompt is! String) ||
          (pendingIntentExpectedVersion != null &&
              pendingIntentExpectedVersion is! int) ||
          (pendingIntentKey != null && pendingIntentKey is! String) ||
          pendingIntentFresh is! bool ||
          (pendingIntentID is String && pendingIntentID.isNotEmpty) &&
              (pendingIntentPrompt is! String ||
                  pendingIntentExpectedVersion is! int ||
                  pendingIntentKey is! String)) {
        throw const FormatException('Invalid Forge Console E2E input.');
      }

      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        httpClient: http.Client(),
      );
      try {
        final conversations = await api.listConversations(limit: 50);
        expect(
          conversations.conversations.any(
            (owned) => owned.conversation.id == conversationID,
          ),
          isTrue,
        );

        final history = await api.listPrompts(
          conversationID: conversationID,
          limit: 100,
        );
        expect(history.prompts, isNotEmpty);
        expect(
          history.prompts.any((value) => value.content == existingPrompt),
          isTrue,
        );

        if (pendingIntentID is String && pendingIntentID.isNotEmpty) {
          final submitted = await api.submitPendingRunIntent(
            conversationID: conversationID,
            content: pendingIntentPrompt as String,
            expectedVersion: pendingIntentExpectedVersion as int,
            idempotencyKey: pendingIntentKey as String,
          );
          final submittedIntentID = submitted.intent.intentID;
          if (pendingIntentFresh) {
            expect(submittedIntentID, isNot(pendingIntentID));
          } else {
            expect(submittedIntentID, pendingIntentID);
          }
          expect(submitted.prompt.content, pendingIntentPrompt);
          expect(submitted.replayed, pendingIntentFresh ? isFalse : isTrue);

          final pending = await api.listPendingRunIntents(
            conversationID: conversationID,
            limit: 25,
          );
          expect(pending.conversationID, conversationID);
          expect(
            pending.intents.length,
            pendingIntentFresh ? greaterThanOrEqualTo(2) : 1,
          );
          expect(pending.hasMore, isFalse);
          final existingIntent = pending.intents.singleWhere(
            (value) => value.intentID == pendingIntentID,
          );
          expect(existingIntent.status, 'pending');

          if (pendingIntentFresh) {
            final freshIntent = pending.intents.singleWhere(
              (value) => value.intentID == submittedIntentID,
            );
            expect(freshIntent.status, 'pending');
            expect(freshIntent.promptID, submitted.prompt.id);
          }

          final timeline = await api.listPendingRunIntentTimeline(
            conversationID: conversationID,
            intentID: pendingIntentID,
            afterSequence: 0,
            limit: 25,
          );
          expect(timeline.conversationID, conversationID);
          expect(timeline.intentID, pendingIntentID);
          expect(timeline.events, hasLength(1));
          expect(timeline.events.single.type, 'submitted');
          expect(timeline.hasMore, isFalse);

          if (pendingIntentFresh) {
            final freshTimeline = await api.listPendingRunIntentTimeline(
              conversationID: conversationID,
              intentID: submittedIntentID,
              afterSequence: 0,
              limit: 25,
            );
            expect(freshTimeline.conversationID, conversationID);
            expect(freshTimeline.intentID, submittedIntentID);
            expect(freshTimeline.events, hasLength(1));
            expect(freshTimeline.events.single.type, 'submitted');
            expect(freshTimeline.hasMore, isFalse);
          }
        }

        final appended = await api.appendPrompt(
          conversationID: conversationID,
          content: prompt,
          expectedVersion: expectedVersion,
          idempotencyKey: idempotencyKey,
        );
        expect(appended.prompt.conversationID, conversationID);
        expect(appended.prompt.content, prompt);
        expect(appended.prompt.role, 'user');
        expect(appended.aggregateVersion, expectedVersion + 1);
        expect(appended.replayed, isFalse);

        final replayed = await api.appendPrompt(
          conversationID: conversationID,
          content: prompt,
          expectedVersion: expectedVersion,
          idempotencyKey: idempotencyKey,
        );
        expect(replayed.prompt.id, appended.prompt.id);
        expect(replayed.prompt.content, prompt);
        expect(replayed.aggregateVersion, appended.aggregateVersion);
        expect(replayed.replayed, isTrue);

        final changes = await api.conversationChanges(
          afterCursor: afterCursor,
          limit: 128,
        );
        final promptChanges = changes.changes
            .where(
              (change) =>
                  change.conversationID == conversationID &&
                  change.kind == 'prompt_appended',
            )
            .toList(growable: false);
        expect(promptChanges, hasLength(1));
        expect(promptChanges.single.aggregateVersion, expectedVersion + 1);

        final placementInput = ForgeDevicePlacementRequest.fromJson(
          Map<String, dynamic>.from(placementRequest),
        );
        final placement = await api.previewDevicePlacement(
          request: placementInput,
        );
        expect(placement.owner.issuer, placementInput.owner.issuer);
        expect(placement.owner.subject, placementInput.owner.subject);
        expect(placement.owner.tenantID, placementInput.owner.tenantID);
        expect(placement.evaluatedAtMS, placementInput.evaluatedAtMS);
        expect(placement.deviceResults, hasLength(1));
        expect(placement.deviceResults.single.deviceID, 'device-1');
        expect(placement.executionAuthorized, isFalse);
        expect(placement.reservationCreated, isFalse);
        expect(placement.dispatchPerformed, isFalse);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through scripts/test-forge-shared-session-e2e.sh.'
        : false,
  );

  testWidgets(
    'Forge session gate reads the shared session and submits a Prompt over HTTP',
    (tester) async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final conversationID = input['conversation_id'];
      final previousPrompt = input['prompt'];
      final widgetPrompt = input['widget_prompt'];
      if (apiURL is! String ||
          accessToken is! String ||
          conversationID is! String ||
          previousPrompt is! String ||
          widgetPrompt is! String) {
        throw const FormatException('Invalid Forge Console E2E input.');
      }

      final credentialBackend = MemoryForgeCredentialBackend();
      final credentialStore = ForgeCredentialStore(
        backend: credentialBackend,
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      // Exercise the same cold-start path used by native clients: the gate
      // must restore from the injected secure backend rather than a prefilled
      // in-memory Session slot.
      Session.clearForClient(ForgeConversationsOAuth.clientId);
      addTearDown(() async {
        Session.clearForClient(ForgeConversationsOAuth.clientId);
        await credentialStore.clear();
      });
      tester.view.physicalSize = const Size(1280, 1800);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(home: ForgeSessionsGate(credentialStore: credentialStore)),
      );
      await _pumpUntil(
        tester,
        () => find.text('Shared from client A').evaluate().isNotEmpty,
        waitFor: 'shared conversation',
      );
      await _pumpUntil(
        tester,
        () =>
            find.text(input['existing_prompt'] as String).evaluate().isNotEmpty,
        waitFor: 'shared Prompt history',
      );

      final renderedText = tester
          .widgetList<Text>(find.byType(Text))
          .map((value) => value.data)
          .toList();
      expect(
        find.text('Shared from client A'),
        findsWidgets,
        reason: 'Rendered Forge screen text: $renderedText',
      );
      expect(find.text(input['existing_prompt'] as String), findsOneWidget);
      expect(find.text(previousPrompt), findsOneWidget);
      await tester.ensureVisible(find.byType(TextField).last);
      await tester.enterText(find.byType(TextField).last, widgetPrompt);
      await tester.ensureVisible(find.text('Append prompt'));
      await tester.tap(find.text('Append prompt'));
      await _pumpUntil(tester, () {
        final promptInput = tester.widget<TextField>(
          find.byType(TextField).last,
        );
        return promptInput.controller?.text.isEmpty == true &&
            find.text(widgetPrompt).evaluate().isNotEmpty &&
            find
                .text('Prompt stored. It has not started a task.')
                .evaluate()
                .isNotEmpty;
      }, waitFor: 'successful Prompt append');

      expect(find.text(widgetPrompt), findsOneWidget);
      expect(
        find.text('Prompt stored. It has not started a task.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    skip: inputPath == null,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String waitFor,
}) async {
  for (var count = 0; count < 250; count++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for $waitFor from the live API.',
  );
}
