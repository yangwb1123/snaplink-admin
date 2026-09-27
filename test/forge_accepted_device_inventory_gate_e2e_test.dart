import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
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
      Platform.environment['FORGE_ACCEPTED_DEVICE_INVENTORY_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate renders inventory, instance sessions, and resources',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final livePromptConversationID = _optionalText(
        input,
        'live_prompt_conversation_id',
      );
      final owner = ForgeDeviceOwner(
        issuer: _requiredText(input, 'issuer'),
        subject: _requiredText(input, 'subject'),
        tenantID: _requiredText(input, 'tenant_id'),
      );
      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      // Keep every read-only acceptance panel mounted while the test checks
      // the owner-scoped projections. Production viewports still use the
      // normal scrollable layout.
      tester.view.physicalSize = const Size(1280, 10000);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            deviceInventoryOwner: owner,
            deviceInventoryCandidateApiOrigin: apiURL,
            enableDeviceInventoryCandidate: true,
            deviceInventoryV2CandidateApiOrigin: apiURL,
            enableDeviceInventoryV2Candidate: true,
            initialConversationID: livePromptConversationID.isEmpty
                ? null
                : livePromptConversationID,
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewCandidateApiOrigin: apiURL,
            enableClientInstanceResourceViewCandidate: true,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewCandidateApiOrigin: apiURL,
            enableClientInstanceSessionViewCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () =>
            find
                .byKey(const ValueKey('forge-authenticated-device-inventory'))
                .evaluate()
                .isNotEmpty &&
            find
                .byKey(
                  const ValueKey('forge-client-instance-resource-view-panel'),
                )
                .evaluate()
                .isNotEmpty &&
            find
                .byKey(
                  const ValueKey('forge-client-instance-session-view-panel'),
                )
                .evaluate()
                .isNotEmpty,
        waitFor: 'authenticated inventory and instance resource panels',
      );

      expect(
        find.byKey(const ValueKey('forge-authenticated-device-inventory')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
        findsOneWidget,
      );

      for (final instanceID in const [
        'client-cli-001',
        'client-tui-001',
        'client-web-001',
        'client-app-001',
        'client-mobile-001',
      ]) {
        expect(
          find.byKey(
            ValueKey('forge-client-instance-resource-view-$instanceID'),
          ),
          findsOneWidget,
        );
        final sessionRow = find.byKey(
          ValueKey('forge-client-instance-session-view-$instanceID'),
        );
        expect(sessionRow, findsOneWidget);
        expect(
          find.descendant(
            of: sessionRow,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text && (widget.data ?? '').contains('sessions='),
            ),
          ),
          findsOneWidget,
        );
      }
      for (final deviceID in const ['device-a', 'device-b']) {
        expect(
          find.byKey(ValueKey('forge-client-instance-resource-view-$deviceID')),
          findsOneWidget,
        );
      }
      expect(
        find.byKey(const ValueKey('forge-inventory-device-a-runner-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-inventory-v2-device-a-runner-a')),
        findsOneWidget,
      );
      expect(find.text('Execution authorized: false'), findsWidgets);
      expect(find.text('Reservation created: false'), findsWidgets);
      expect(find.text('Dispatch performed: false'), findsWidgets);

      final livePromptInstanceBefore = _optionalText(
        input,
        'live_prompt_instance_before',
      );
      final livePromptInstanceAfter = _optionalText(
        input,
        'live_prompt_instance_after',
      );
      final livePromptContent = _optionalText(input, 'live_prompt_content');
      final livePromptEnabled =
          livePromptConversationID.isNotEmpty &&
          livePromptInstanceBefore.isNotEmpty &&
          livePromptInstanceAfter.isNotEmpty &&
          livePromptContent.isNotEmpty;
      if (livePromptEnabled) {
        final filterMenu = find.byKey(
          const ValueKey('forge-client-instance-session-filter-menu'),
        );
        expect(filterMenu, findsOneWidget);
        await tester.ensureVisible(filterMenu);
        await tester.tap(filterMenu);
        await tester.pump(const Duration(milliseconds: 300));
        final instanceItem = find.text(livePromptInstanceBefore);
        expect(instanceItem, findsWidgets);
        await tester.tap(instanceItem.last);
        await tester.pump(const Duration(milliseconds: 300));
        await _pumpUntil(
          tester,
          () => find
              .byKey(ValueKey('forge-conversation-$livePromptConversationID'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'pre-refresh client-instance Prompt conversation',
        );
      }

      final registryPath = input['registry_path'];
      final updatedRegistryJSON = input['updated_registry_json'];
      final expectedRefreshMarker = input['expected_refresh_marker'];
      final clientInstancePath = input['client_instance_path'];
      final updatedClientInstanceJSON = input['updated_client_instance_json'];
      final expectedResourceRefreshMarker =
          input['expected_resource_refresh_marker'];
      final expectedResourceInstanceMarker =
          input['expected_resource_instance_marker'];
      if (registryPath is String &&
          registryPath.isNotEmpty &&
          updatedRegistryJSON is String &&
          updatedRegistryJSON.isNotEmpty &&
          expectedRefreshMarker is String &&
          expectedRefreshMarker.isNotEmpty &&
          clientInstancePath is String &&
          clientInstancePath.isNotEmpty &&
          updatedClientInstanceJSON is String &&
          updatedClientInstanceJSON.isNotEmpty &&
          expectedResourceRefreshMarker is String &&
          expectedResourceRefreshMarker.isNotEmpty &&
          expectedResourceInstanceMarker is String &&
          expectedResourceInstanceMarker.isNotEmpty) {
        _replaceRegistryImage(registryPath, updatedRegistryJSON);
        _replaceRegistryImage(clientInstancePath, updatedClientInstanceJSON);
        final refreshedResourceRow = find.byKey(
          ValueKey(
            'forge-client-instance-resource-view-$expectedResourceInstanceMarker',
          ),
        );
        final refreshedResourceMarker = find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data ?? '').contains(expectedResourceRefreshMarker),
        );
        // Advance past the bounded poll cadence so the owner-scoped reader
        // observes the atomically replaced image without a manual refresh.
        await tester.pump(const Duration(seconds: 16));
        await _pumpUntil(
          tester,
          () =>
              find.text(expectedRefreshMarker).evaluate().isNotEmpty &&
              refreshedResourceMarker.evaluate().isNotEmpty &&
              refreshedResourceRow.evaluate().isNotEmpty,
          waitFor: 'live accepted inventory refresh',
        );
        expect(find.text(expectedRefreshMarker), findsOneWidget);
        expect(refreshedResourceRow, findsOneWidget);
        final refreshedSessionRow = find.byKey(
          ValueKey(
            'forge-client-instance-session-view-$expectedResourceInstanceMarker',
          ),
        );
        expect(refreshedSessionRow, findsOneWidget);
        expect(
          find.descendant(
            of: refreshedSessionRow,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text && (widget.data ?? '').contains('sessions='),
            ),
          ),
          findsOneWidget,
        );
        final refreshedDeviceRow = find.byKey(
          const ValueKey('forge-client-instance-resource-view-device-a'),
        );
        expect(
          find.descendant(
            of: refreshedDeviceRow,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  (widget.data ?? '').contains(expectedResourceRefreshMarker),
            ),
          ),
          findsOneWidget,
        );

        if (livePromptEnabled) {
          final filterMenu = find.byKey(
            const ValueKey('forge-client-instance-session-filter-menu'),
          );
          await _pumpUntil(
            tester,
            () =>
                filterMenu.evaluate().isNotEmpty &&
                tester.widget<PopupMenuButton<String>>(filterMenu).enabled,
            waitFor: 'refreshed client-instance session filter',
          );
          await tester.ensureVisible(filterMenu);
          await tester.tap(filterMenu);
          await tester.pump(const Duration(milliseconds: 300));
          final refreshedInstanceItem = find.text(livePromptInstanceAfter);
          expect(refreshedInstanceItem, findsWidgets);
          await tester.tap(refreshedInstanceItem.last);
          await tester.pump(const Duration(milliseconds: 300));
          await _pumpUntil(
            tester,
            () => find
                .byKey(ValueKey('forge-conversation-$livePromptConversationID'))
                .evaluate()
                .isNotEmpty,
            waitFor: 'post-refresh client-instance Prompt conversation',
          );

          final promptField = find.byType(TextField).last;
          await tester.ensureVisible(promptField);
          await tester.enterText(promptField, livePromptContent);
          await tester.ensureVisible(find.text('Append prompt'));
          await tester.tap(find.text('Append prompt'));
          await _pumpUntil(
            tester,
            () =>
                find.text(livePromptContent).evaluate().isNotEmpty &&
                find
                    .text('Prompt stored. It has not started a task.')
                    .evaluate()
                    .isNotEmpty &&
                tester
                        .widget<TextField>(promptField)
                        .controller
                        ?.text
                        .isEmpty ==
                    true,
            waitFor: 'post-refresh Console Prompt append',
          );
          expect(find.text(livePromptContent), findsOneWidget);
        }
      }

      await tester.pumpWidget(const SizedBox.shrink());
      // The authenticated Sessions screen starts a bounded change-feed poll;
      // allow any in-flight request to settle after disposal.
      await tester.pump(const Duration(seconds: 21));
    },
    skip: inputPath == null,
  );
}

void _replaceRegistryImage(String path, String imageJSON) {
  final temporaryPath = '$path.live-refresh';
  File(temporaryPath).writeAsStringSync(imageJSON);
  final chmod = Process.runSync('chmod', <String>['0600', temporaryPath]);
  if (chmod.exitCode != 0) {
    throw StateError('Could not preserve lifecycle image permissions: $chmod');
  }
  File(temporaryPath).renameSync(path);
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid accepted device inventory Gate E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing accepted device inventory Gate $key.');
  }
  return value;
}

String _optionalText(Map<String, dynamic> input, String key) {
  final value = input[key];
  return value is String ? value : '';
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
    reason:
        "Timed out waiting for $waitFor from the accepted Forge Gate. "
        "inventory=${find.byKey(const ValueKey('forge-authenticated-device-inventory')).evaluate().length} "
        "inventory_v2=${find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')).evaluate().length} "
        "resource=${find.byKey(const ValueKey('forge-client-instance-resource-view-panel')).evaluate().length} "
        "session=${find.byKey(const ValueKey('forge-client-instance-session-view-panel')).evaluate().length}",
  );
}
