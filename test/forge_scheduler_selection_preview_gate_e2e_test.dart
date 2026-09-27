import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

/// Opt-in accepted EXECUTE Gate journey for the metadata-only scheduler
/// selection preview. It does not claim a lease or enable Runner effects.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_SCHEDULER_SELECTION_PREVIEW_GATE_E2E_INPUT'];

  testWidgets(
    'authenticated Sessions Gate renders one scheduler selection preview',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final owner = ForgeDeviceOwner.fromJson(input['owner']);
      final request = ForgeSchedulerSelectionPreviewRequest.fromJson(
        input['request'],
      );
      final expectedConversationID = _requiredText(
        input,
        'expected_conversation_id',
      );
      final expectedRunID = _requiredText(input, 'expected_run_id');
      final expectedAttemptID = _requiredText(input, 'expected_attempt_id');
      final expectedSelectionAvailable = _requiredBool(
        input,
        'expected_selection_available',
      );
      final expectedSelectionReason = _requiredText(
        input,
        'expected_selection_reason',
      );
      final expectedDeviceID = _optionalText(input, 'expected_device_id');
      final expectedInstanceID = _optionalText(input, 'expected_instance_id');
      if (!request.isFor(expectedConversationID, expectedRunID) ||
          request.attemptID != expectedAttemptID) {
        throw const FormatException(
          'Scheduler selection Gate input has inconsistent Run binding.',
        );
      }
      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            initialConversationID: expectedConversationID,
            deviceInventoryOwner: owner,
            deviceInventoryV2CandidateApiOrigin: apiURL,
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewCandidateApiOrigin: apiURL,
            schedulerSelectionPreviewRequest: request,
            schedulerSelectionPreviewCandidateApiOrigin: apiURL,
            enableSchedulerSelectionPreviewCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-scheduler-selection-preview-panel'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'authenticated scheduler selection preview panel',
      );
      expect(
        find.byKey(const ValueKey('forge-scheduler-selection-preview-panel')),
        findsOneWidget,
      );
      expect(find.text('Scheduler selection preview'), findsOneWidget);
      expect(find.text('Selected'), findsOneWidget);
      if (expectedSelectionAvailable) {
        expect(
          find.text('$expectedDeviceID / $expectedInstanceID'),
          findsOneWidget,
        );
      } else {
        expect(find.text('none'), findsOneWidget);
      }
      expect(find.text(expectedSelectionReason), findsOneWidget);
      expect(find.text('Authority'), findsOneWidget);
      expect(find.textContaining('all false · preview-only'), findsOneWidget);
      expect(find.textContaining('fencing_token'), findsNothing);
      expect(find.textContaining('token-'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException('Invalid scheduler selection Gate E2E input.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing scheduler selection Gate E2E $key.');
  }
  return value;
}

bool _requiredBool(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! bool) {
    throw FormatException('Missing Forge scheduler selection Gate $key.');
  }
  return value;
}

String? _optionalText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value == null || value == '') return null;
  if (value is! String) {
    throw FormatException('Invalid Forge scheduler selection Gate $key.');
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
