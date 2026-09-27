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
  final inputPath =
      Platform.environment['FORGE_PENDING_RUN_INTENT_GATE_E2E_INPUT'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'authenticated Sessions Gate submits or observes one inert pending Run-intent',
    (tester) async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final conversationID = _requiredText(input, 'conversation_id');
      final issuer = _requiredText(input, 'issuer');
      final subject = _requiredText(input, 'subject');
      final tenantID = _requiredText(input, 'tenant_id');
      final expectedVersion = _requiredInt(input, 'expected_version');
      final content = _requiredText(input, 'content');
      final idempotencyKey = _requiredText(input, 'idempotency_key');
      final submitValue = input['submit'];
      final submit = submitValue is! bool || submitValue;
      final pendingIntentID = input['pending_intent_id'];
      if (!submit && (pendingIntentID is! String || pendingIntentID.isEmpty)) {
        throw const FormatException(
          'Read-only pending Run-intent Gate E2E input requires an intent ID.',
        );
      }
      if (expectedVersion < 1 || content.trim().isEmpty) {
        throw const FormatException(
          'Invalid pending Run-intent Gate E2E input values.',
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
      expect(find.text('Execution consent preview'), findsOneWidget);
      expect(
        find.textContaining('Preview only · consent has not been granted'),
        findsOneWidget,
      );

      if (submit) {
        final inputField = find.byType(TextField).last;
        await tester.ensureVisible(inputField);
        await tester.enterText(inputField, content);
        await tester.tap(
          find.byKey(const ValueKey('forge-request-scheduling-review')),
        );

        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('forge-pending-run-intent-submission-card'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'pending Run-intent scheduling-review receipt',
        );

        expect(
          find.byKey(
            const ValueKey('forge-pending-run-intent-submission-card'),
          ),
          findsOneWidget,
        );
        expect(find.text('Scheduling review requested'), findsOneWidget);
        expect(find.text(conversationID), findsWidgets);
        expect(find.text('pending'), findsOneWidget);
        expect(find.text('created'), findsOneWidget);
        expect(find.text('${expectedVersion + 1}'), findsOneWidget);
        expect(
          find.text('offline · all execution flags false'),
          findsOneWidget,
        );
        expect(find.textContaining('No Run was created'), findsOneWidget);
        expect(find.textContaining('no device was selected'), findsOneWidget);
        expect(find.text('forge-task'), findsNothing);
        expect(find.text('fencing_token'), findsNothing);
        expect(find.text(idempotencyKey), findsNothing);
      }

      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-pending-run-intent-metadata-card'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'pending Run-intent metadata readback',
      );
      final metadataCard = find.byKey(
        const ValueKey('forge-pending-run-intent-metadata-card'),
      );
      expect(metadataCard, findsOneWidget);
      expect(
        find.descendant(
          of: metadataCard,
          matching: find.text('metadata-only · all execution flags false'),
        ),
        submit ? findsOneWidget : findsWidgets,
      );
      expect(
        find.descendant(of: metadataCard, matching: find.text(content)),
        findsNothing,
      );
      if (!submit) {
        // The Prompt history is allowed to render the body, while the
        // receipt card above must remain metadata-only. This proves that the
        // content came from the external client's write and was then read by
        // the fresh Gate.
        expect(find.text(content), findsWidgets);
      }
      final timelineTitle = submit
          ? find
                .descendant(
                  of: metadataCard,
                  matching: find.text('Timeline metadata'),
                )
                .first
          : find.byKey(
              ValueKey('forge-pending-run-intent-timeline-$pendingIntentID'),
            );
      await tester.ensureVisible(timelineTitle);
      await tester.tap(timelineTitle);
      await _pumpUntil(
        tester,
        () => find
            .descendant(
              of: metadataCard,
              matching: find.text('Scanned through'),
            )
            .evaluate()
            .isNotEmpty,
        waitFor: 'pending Run-intent timeline metadata',
      );
      expect(
        find.descendant(
          of: metadataCard,
          matching: find.text('Scanned through'),
        ),
        submit ? findsOneWidget : findsWidgets,
      );
      expect(
        find.descendant(of: metadataCard, matching: find.text('submitted')),
        findsWidgets,
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
    throw const FormatException('Invalid pending Run-intent Gate E2E input.');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing pending Run-intent Gate E2E $key.');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! int) {
    throw FormatException('Missing pending Run-intent Gate E2E $key.');
  }
  return value;
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
