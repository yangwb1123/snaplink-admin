import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

/// The Go harness supplies one real Snaplink JWT and a test-only scheduler
/// candidate mux. The selected client instance must bind the display-only
/// target to the freshly observed owner resource image.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_CLIENT_INSTANCE_SCHEDULER_PREVIEW_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated client instances bind scheduler preview to resources',
    (tester) async {
      if (inputPath == null) return;
      final input = _readInput(inputPath);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final clientKinds = _requiredKinds(input['client_kinds']);
      final expectCard = input['expect_scheduler_preview_card'] == true;
      final expectedDeviceID = _requiredText(input, 'expected_device_id');
      final expectedInstanceID = _requiredText(input, 'expected_instance_id');
      final expectedReason = _requiredText(input, 'expected_selection_reason');
      final request = ForgeSchedulerSelectionPreviewRequest.fromJson(
        input['request'],
      );

      for (final clientKind in clientKinds) {
        final credentialStore = ForgeCredentialStore(
          backend: MemoryForgeCredentialBackend(),
          forcePersistentStorage: true,
        );
        expect(await credentialStore.store(accessToken: accessToken), isTrue);
        tester.view.physicalSize = const Size(1280, 2400);
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsGate(
              credentialStore: credentialStore,
              initialConversationID: request.conversationID,
              initialClientInstanceID: 'client-$clientKind-001',
              clientInstanceSessionViewOwner: owner,
              clientInstanceSessionViewCandidateApiOrigin: apiURL,
              enableClientInstanceSessionViewCandidate: true,
              clientInstanceResourceViewOwner: owner,
              clientInstanceResourceViewCandidateApiOrigin: apiURL,
              enableClientInstanceResourceViewCandidate: true,
              deviceInventoryOwner: owner,
              deviceInventoryV2CandidateApiOrigin: apiURL,
              enableDeviceInventoryV2Candidate: true,
              schedulerSelectionPreviewRequest: request,
              schedulerSelectionPreviewCandidateApiOrigin: apiURL,
              enableSchedulerSelectionPreviewCandidate: true,
            ),
          ),
        );

        if (expectCard) {
          await _pumpUntil(
            tester,
            () => find
                .byKey(
                  const ValueKey('forge-scheduler-selection-preview-panel'),
                )
                .evaluate()
                .isNotEmpty,
          );
        } else {
          for (var index = 0; index < 120; index++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 10)),
            );
            await tester.pump();
          }
        }
        final panel = find.byKey(
          const ValueKey('forge-scheduler-selection-preview-panel'),
        );
        if (expectCard) {
          expect(panel, findsOneWidget);
          expect(
            find.text('$expectedDeviceID / $expectedInstanceID'),
            findsOneWidget,
          );
          expect(find.text(expectedReason), findsOneWidget);
          expect(
            find.textContaining('all false · preview-only'),
            findsOneWidget,
          );
          expect(find.textContaining('fencing_token'), findsNothing);
          expect(find.textContaining('token-'), findsNothing);
        } else {
          expect(panel, findsNothing);
        }
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await credentialStore.clear();
      }
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid Forge client-instance scheduler preview Gate input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing scheduler preview Gate $key.');
  }
  return value;
}

List<String> _requiredKinds(Object? value) {
  if (value is! List || value.isEmpty) {
    throw const FormatException('Missing scheduler preview Gate client kinds.');
  }
  final kinds = value.whereType<String>().toList(growable: false);
  if (kinds.length != value.length ||
      kinds.any((kind) => !{'web', 'app', 'mobile'}.contains(kind))) {
    throw const FormatException('Invalid scheduler preview Gate client kinds.');
  }
  return kinds;
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() condition) async {
  for (var index = 0; index < 360; index++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for scheduler preview.',
  );
}
