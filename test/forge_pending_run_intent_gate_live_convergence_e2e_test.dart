import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform
      .environment['FORGE_PENDING_RUN_INTENT_LIVE_CONVERGENCE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'open Sessions Gate converges after an external Runtime CLI write',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final conversationID = _requiredText(input, 'conversation_id');
      final issuer = _requiredText(input, 'issuer');
      final subject = _requiredText(input, 'subject');
      final tenantID = _requiredText(input, 'tenant_id');
      final runtimeExecutable = _requiredText(input, 'runtime_executable');
      final expectedVersion = _requiredInt(input, 'expected_version');
      final existingPendingCount = _requiredInt(
        input,
        'existing_pending_count',
      );
      final content = _requiredText(input, 'content');
      final idempotencyKey = _requiredText(input, 'idempotency_key');
      if (expectedVersion < 1 ||
          existingPendingCount < 1 ||
          content.trim().isEmpty) {
        throw const FormatException(
          'Invalid live pending Run-intent Gate E2E input values.',
        );
      }

      final credentialStore = ForgeCredentialStore(
        backend: MemoryForgeCredentialBackend(),
        forcePersistentStorage: true,
      );
      expect(await credentialStore.store(accessToken: accessToken), isTrue);
      addTearDown(credentialStore.clear);

      final owner = ForgeDeviceOwner(
        issuer: issuer,
        subject: subject,
        tenantID: tenantID,
      );
      tester.view.physicalSize = const Size(1280, 2600);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            executionConsentPreviewOwner: owner,
            enableExecutionConsentPreviewCandidate: true,
            executionConsentPreviewCandidateApiOrigin: apiURL,
            pendingRunIntentOwner: owner,
            pendingRunIntentCandidateApiOrigin: apiURL,
            enablePendingRunIntentCandidate: true,
          ),
        ),
      );

      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-request-scheduling-review'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'pending Run-intent scheduling-review action',
      );
      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-execution-consent-preview-card'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'execution-consent preview card',
      );
      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-pending-run-intent-metadata-card'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'initial pending Run-intent metadata',
      );

      final external = await tester.runAsync(
        () => _submitExternalRunIntent(
          runtimeExecutable: runtimeExecutable,
          apiURL: apiURL,
          accessToken: accessToken,
          conversationID: conversationID,
          expectedVersion: expectedVersion,
          content: content,
          idempotencyKey: idempotencyKey,
        ),
      );
      if (external == null) {
        throw StateError('External Runtime CLI write did not complete.');
      }
      final externalIntentID = external['intent_id'];
      if (externalIntentID is! String || externalIntentID.isEmpty) {
        throw const FormatException(
          'Runtime CLI did not return a pending Run-intent ID.',
        );
      }

      // The production timer uses a bounded 15-second owner change-feed
      // cadence. Advance the widget clock once, then let the HTTP future and
      // the resulting Prompt/pending reads settle through the normal poll.
      await tester.pump(const Duration(seconds: 16));
      await _pumpUntil(tester, () {
        final metadata = find.byKey(
          const ValueKey('forge-pending-run-intent-metadata-card'),
        );
        final authorities = find.descendant(
          of: metadata,
          matching: find.text('metadata-only · all execution flags false'),
        );
        return find.text(content).evaluate().isNotEmpty &&
            authorities.evaluate().length >= existingPendingCount + 1;
      }, waitFor: 'live external Prompt and pending Run-intent convergence');

      final metadataCard = find.byKey(
        const ValueKey('forge-pending-run-intent-metadata-card'),
      );
      expect(metadataCard, findsOneWidget);
      expect(
        find.descendant(of: metadataCard, matching: find.text(content)),
        findsNothing,
      );
      expect(
        find.byKey(ValueKey('forge-pending-run-intent-$externalIntentID')),
        findsOneWidget,
      );
      final externalCard = find.byKey(
        ValueKey('forge-pending-run-intent-$externalIntentID'),
      );
      final timelineTitle = find.byKey(
        ValueKey('forge-pending-run-intent-timeline-$externalIntentID'),
      );
      await tester.ensureVisible(timelineTitle);
      await tester.tap(timelineTitle);
      await _pumpUntil(
        tester,
        () => find
            .descendant(
              of: externalCard,
              matching: find.text('Scanned through'),
            )
            .evaluate()
            .isNotEmpty,
        waitFor: 'live external pending Run-intent timeline metadata',
      );
      expect(
        find.descendant(of: metadataCard, matching: find.text('submitted')),
        findsWidgets,
      );
      expect(
        find.byKey(const ValueKey('forge-pending-run-intent-submission-card')),
        findsNothing,
      );

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
      'Invalid live pending Run-intent Gate E2E input.',
    );
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing live pending Run-intent Gate E2E $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! int) {
    throw FormatException('Missing live pending Run-intent Gate E2E $key.');
  }
  return value;
}

Future<Map<String, dynamic>> _submitExternalRunIntent({
  required String runtimeExecutable,
  required String apiURL,
  required String accessToken,
  required String conversationID,
  required int expectedVersion,
  required String content,
  required String idempotencyKey,
}) async {
  final home = await Directory.systemTemp.createTemp(
    'forge-live-pending-run-intent-',
  );
  try {
    final environment = Map<String, String>.from(Platform.environment)
      ..['FORGE_API_URL'] = apiURL
      ..['FORGE_ACCESS_TOKEN'] = accessToken
      ..['HOME'] = home.path
      ..['USERPROFILE'] = home.path
      ..['XDG_CONFIG_HOME'] = '${home.path}/config';
    final result = await Process.run(
      runtimeExecutable,
      [
        '--json',
        '--idempotency-key',
        idempotencyKey,
        'remote',
        'run-intents',
        'submit',
        conversationID,
        '--expected-version',
        '$expectedVersion',
        content,
      ],
      workingDirectory: home.path,
      environment: environment,
    );
    if (result.exitCode != 0) {
      throw StateError(
        'Runtime CLI pending Run-intent failed: '
        'stdout=${result.stdout} stderr=${result.stderr}',
      );
    }
    final decoded = jsonDecode(result.stdout.toString());
    if (decoded is! Map) {
      throw const FormatException(
        'Runtime CLI pending Run-intent response was not an object.',
      );
    }
    final submission = Map<String, dynamic>.from(decoded);
    final prompt = submission['prompt'];
    final intent = submission['intent'];
    final initialEvent = submission['initial_event'];
    if (prompt is! Map ||
        intent is! Map ||
        initialEvent is! Map ||
        prompt['content'] != content ||
        intent['status'] != 'pending' ||
        initialEvent['type'] != 'submitted') {
      throw const FormatException(
        'Runtime CLI pending Run-intent response did not match the external write.',
      );
    }
    return Map<String, dynamic>.from(intent);
  } finally {
    await home.delete(recursive: true);
  }
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String waitFor,
}) async {
  for (var count = 0; count < 400; count++) {
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
