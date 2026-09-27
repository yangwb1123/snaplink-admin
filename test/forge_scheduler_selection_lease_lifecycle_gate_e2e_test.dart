import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';

import 'support/memory_forge_credential_backend.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_SCHEDULER_SELECTION_LEASE_LIFECYCLE_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate releases one renewed scheduler lease',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final idempotencyKey = _requiredText(input, 'idempotency_key');
      final request = ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(
        input['release_request'],
      );
      final expectedDeviceID = _requiredText(input, 'expected_device_id');
      final expectedInstanceID = _requiredText(input, 'expected_instance_id');
      final expectedEpoch = _requiredInt(input, 'expected_epoch');
      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      tester.view.physicalSize = const Size(1280, 2200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            schedulerSelectionLeaseReleaseRequest: request,
            schedulerSelectionLeaseReleaseCandidateApiOrigin: apiURL,
            schedulerSelectionLeaseReleaseIdempotencyKey: idempotencyKey,
            enableSchedulerSelectionLeaseReleaseCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(
              const ValueKey('forge-scheduler-selection-lease-release-panel'),
            )
            .evaluate()
            .isNotEmpty,
        waitFor: 'authenticated scheduler lease release panel',
      );

      expect(
        find.byKey(
          const ValueKey('forge-scheduler-selection-lease-release-panel'),
        ),
        findsOneWidget,
      );
      expect(
        find.text('Target: $expectedDeviceID/$expectedInstanceID'),
        findsOneWidget,
      );
      expect(find.text('Epoch: $expectedEpoch'), findsOneWidget);
      expect(find.text('Replay: false'), findsOneWidget);
      expect(find.textContaining('reservation is inactive'), findsOneWidget);
      expect(find.text(request.fencingToken), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 21));
    },
    skip: inputPath == null,
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  if (decoded is! Map) {
    throw const FormatException(
      'Invalid scheduler lease lifecycle Gate E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing scheduler lease lifecycle Gate $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! int || value <= 0) {
    throw FormatException('Missing scheduler lease lifecycle Gate $key.');
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
