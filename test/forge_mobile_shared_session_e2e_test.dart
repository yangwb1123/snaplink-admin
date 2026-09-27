import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';
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
      final clientInstanceID = input['client_instance_id'];
      final sessionViewJSON = input['session_view'];
      final resourceViewJSON = input['resource_view'];
      final inventoryV2JSON = input['inventory_v2'];
      final expectedVersion = input['expected_version'];
      final afterCursor = input['after_cursor'];
      final prompt = input['prompt'];
      final idempotencyKey = input['idempotency_key'];
      if (!(platform == 'android-host' || platform == 'ios-host') ||
          apiURL is! String ||
          accessToken is! String ||
          rotatedAccessToken is! String ||
          conversationID is! String ||
          clientInstanceID is! String ||
          sessionViewJSON is! Map ||
          resourceViewJSON is! Map ||
          inventoryV2JSON is! Map ||
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
      final expectedSessionView = ForgeClientInstanceSessionView.fromJson(
        sessionViewJSON,
      );
      final expectedResourceView = ForgeClientInstanceResourceView.fromJson(
        resourceViewJSON,
      );
      final expectedInventoryV2 = ForgeDeviceInventoryPageV2.fromJson(
        inventoryV2JSON,
      );
      final expectedPair = ForgeClientInstanceSessionResourceConvergence.fromJson({
        'schema_version': forgeClientInstanceSessionResourceConvergenceSchema,
        'evaluation_mode':
            forgeClientInstanceSessionResourceConvergenceEvaluationMode,
        'session_view': expectedSessionView.toJson(),
        'resource_view': expectedResourceView.toJson(),
        'converged': true,
        'read_only': true,
        'authority':
            const ForgeClientInstanceSessionResourceConvergenceAuthority.offline()
                .toJson(),
      });
      final owner = expectedPair.owner;
      expect(expectedPair.isDisplayOnly, isTrue);
      _expectSelectedMobileInstance(
        expectedPair,
        clientInstanceID,
        conversationID,
      );
      _expectInventoryV2Observation(
        expectedInventoryV2,
        expectedResourceView,
        owner,
      );

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
        final firstPair = await firstAPI.readConvergedClientInstanceViews(
          owner: owner,
        );
        expect(firstPair.isDisplayOnly, isTrue);
        expect(firstPair.sessionView.toJson(), expectedSessionView.toJson());
        expect(firstPair.resourceView.toJson(), expectedResourceView.toJson());
        _expectSelectedMobileInstance(
          firstPair,
          clientInstanceID,
          conversationID,
        );
        final firstInventoryV2 = await firstAPI.readDeviceInventoryCandidateV2(
          owner: owner,
        );
        _expectInventoryV2Observation(
          firstInventoryV2,
          firstPair.resourceView,
          owner,
        );
        expect(
          jsonEncode(firstInventoryV2.toJson()),
          jsonEncode(expectedInventoryV2.toJson()),
        );
        final firstSchedulerPreview = await firstAPI.previewSchedulerSelection(
          request: _schedulerPreviewRequest(conversationID),
          candidateOrigin: apiURL,
        );
        _expectSchedulerPreview(
          firstSchedulerPreview,
          owner: owner,
          conversationID: conversationID,
        );

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
        final secondPair = await secondAPI.readConvergedClientInstanceViews(
          owner: owner,
        );
        expect(secondPair.isDisplayOnly, isTrue);
        expect(secondPair.sessionView.toJson(), expectedSessionView.toJson());
        expect(secondPair.resourceView.toJson(), expectedResourceView.toJson());
        _expectSelectedMobileInstance(
          secondPair,
          clientInstanceID,
          conversationID,
        );
        final secondInventoryV2 = await secondAPI
            .readDeviceInventoryCandidateV2(owner: owner);
        _expectInventoryV2Observation(
          secondInventoryV2,
          secondPair.resourceView,
          owner,
        );
        expect(
          jsonEncode(secondInventoryV2.toJson()),
          jsonEncode(expectedInventoryV2.toJson()),
        );
        final secondSchedulerPreview = await secondAPI
            .previewSchedulerSelection(
              request: _schedulerPreviewRequest(conversationID),
              candidateOrigin: apiURL,
            );
        _expectSchedulerPreview(
          secondSchedulerPreview,
          owner: owner,
          conversationID: conversationID,
        );

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

        // Native cold start #2 uses the explicit authenticated SSE transport
        // once the owner cursor has been restored. The normal Sessions Gate
        // remains polling/default-off; this is evidence for the shared mobile
        // API path only.
        final changes = await secondAPI.conversationChangesStream(
          afterCursor: restoredSecondCursor,
          limit: 128,
          waitMS: 0,
        );
        expect(changes, isNotNull);
        expect(changes!.afterCursor, restoredSecondCursor);
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

ForgeSchedulerSelectionPreviewRequest _schedulerPreviewRequest(
  String conversationID,
) => ForgeSchedulerSelectionPreviewRequest(
  conversationID: conversationID,
  runID: 'native-scheduler-run',
  attemptID: 'native-scheduler-attempt',
  requirements: const ForgeDevicePlacementRequirements(
    os: 'linux',
    architecture: 'amd64',
    minCPUCores: 1,
    minMemoryBytes: 1,
    minStorageBytes: 1,
    runtime: 'go',
    gpu: ForgeDevicePlacementGpuRequirement(
      required: false,
      minMemoryBytes: 0,
      runtime: '',
    ),
    dataResidencyZones: ['us-west'],
    minimumTrustZone: 'untrusted',
    sandboxFloor: 'process',
    concurrencySlots: 1,
  ),
);

void _expectSchedulerPreview(
  ForgeSchedulerSelectionPreview preview, {
  required ForgeDeviceOwner owner,
  required String conversationID,
}) {
  expect(preview.owner.toJson(), owner.toJson());
  expect(preview.conversationID, conversationID);
  expect(preview.runID, 'native-scheduler-run');
  expect(preview.attemptID, 'native-scheduler-attempt');
  expect(preview.evaluatedAtMS, 300000);
  expect(preview.candidateCount, 1);
  expect(preview.eligibleCandidateCount, 1);
  expect(preview.selectionAvailable, isTrue);
  expect(preview.selectionReason, 'first_sorted_eligible_candidate');
  expect(preview.selectedDeviceID, 'device-a');
  expect(preview.selectedInstanceID, 'runner-a');
  expect(preview.previewOnly, isTrue);
  expect(preview.authority.anyGranted, isFalse);
}

void _expectSelectedMobileInstance(
  ForgeClientInstanceSessionResourceConvergence pair,
  String clientInstanceID,
  String conversationID,
) {
  final sessionMatches = pair.sessionView.instances
      .where((value) => value.instanceID == clientInstanceID)
      .toList(growable: false);
  final resourceMatches = pair.resourceView.instances
      .where((value) => value.instanceID == clientInstanceID)
      .toList(growable: false);
  expect(sessionMatches, hasLength(1));
  expect(resourceMatches, hasLength(1));
  expect(sessionMatches.single.clientKind, 'mobile');
  expect(sessionMatches.single.sessionIDs, contains(conversationID));
  expect(resourceMatches.single.toJson(), sessionMatches.single.toJson());
}

void _expectInventoryV2Observation(
  ForgeDeviceInventoryPageV2 inventory,
  ForgeClientInstanceResourceView resourceView,
  ForgeDeviceOwner owner,
) {
  expect(resourceView.isDisplayOnly, isTrue);
  expect(resourceView.owner.toJson(), owner.toJson());
  expect(inventory.owner.toJson(), owner.toJson());
  expect(inventory.ownerDeclarationUnverified, isTrue);
  expect(inventory.inventoryDeclarationsUnverified, isTrue);
  expect(inventory.executionAuthorized, isFalse);
  expect(inventory.reservationCreated, isFalse);
  expect(inventory.dispatchPerformed, isFalse);
  expect(inventory.devices, hasLength(1));
  final candidate = inventory.devices.single;
  expect(candidate.instanceID, 'runner-a');
  expect(candidate.revision, 1);
  expect(candidate.generation, 1);
  expect(candidate.heartbeatSequence, 1);
  expect(candidate.device.owner.toJson(), owner.toJson());
  expect(candidate.device.deviceID, 'device-a');
  expect(candidate.device.reservationState, 'reserved');
  expect(candidate.device.gpus, hasLength(2));
  final resourceDevice = resourceView.devices.singleWhere(
    (device) => device.runnerInstanceID == candidate.instanceID,
  );
  expect(resourceDevice.deviceID, candidate.device.deviceID);
  expect(resourceDevice.owner.toJson(), owner.toJson());
  expect(resourceDevice.revision, candidate.revision);
  expect(resourceDevice.generation, candidate.generation);
  expect(resourceDevice.heartbeatSequence, candidate.heartbeatSequence);
}
