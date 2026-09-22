import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_run_intent_observation.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
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
  final inputPath =
      Platform.environment['FORGE_RUN_OBSERVATION_WIDGET_E2E_INPUT'];
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'Forge native screen observes an owner-scoped completed Run',
    (tester) async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final conversationID = input['conversation_id'];
      final runID = input['run_id'];
      final rawRunObserved = input['run_observed'];
      final rawRunIntent = input['run_intent_observation'];
      final rawRunnerExecution = input['runner_execution_intent_observation'];
      final rawSessionRunnerReceipt =
          input['session_runner_receipt_observation'];
      final rawSessionObservation = input['session_device_observation_request'];
      if (apiURL is! String ||
          accessToken is! String ||
          conversationID is! String ||
          runID is! String ||
          apiURL.isEmpty ||
          accessToken.isEmpty ||
          conversationID.isEmpty ||
          runID.isEmpty) {
        throw const FormatException(
          'Invalid Forge native Run observation input.',
        );
      }
      if (rawRunObserved is! Map) {
        throw const FormatException(
          'Populated Run observation is required for the native E2E.',
        );
      }
      final runObserved = ForgeRunObserved.fromJson(rawRunObserved);
      if (!runObserved.isFor(conversationID, runID) ||
          !runObserved.isDisplayOnly) {
        throw const FormatException(
          'Populated Run observer is not a display-only selected Run value.',
        );
      }
      final runIntent = rawRunIntent == null
          ? null
          : ForgeRunIntentObservation.fromJson(rawRunIntent);
      final runnerExecution = rawRunnerExecution == null
          ? null
          : ForgeRunnerExecutionIntentObservation.fromJson(rawRunnerExecution);
      final sessionRunnerReceipt = rawSessionRunnerReceipt == null
          ? null
          : ForgeSessionRunnerReceiptObservation.fromJson(
              rawSessionRunnerReceipt,
            );
      final sessionObservationRequest = rawSessionObservation == null
          ? null
          : _sessionPlacementRequestFromInput(rawSessionObservation);
      if (sessionObservationRequest != null &&
          (sessionObservationRequest.conversationID != conversationID ||
              sessionObservationRequest.runID != runID ||
              sessionObservationRequest.candidates.length != 9)) {
        throw const FormatException(
          'Forge native session observation is not bound to the Run.',
        );
      }
      if (runIntent != null &&
          (!runIntent.isFor(conversationID, runID) ||
              !runIntent.isDisplayOnly)) {
        throw const FormatException(
          'Forge native Run intent observation is not bound to the Run.',
        );
      }
      if (runnerExecution != null &&
          (!runnerExecution.isFor(conversationID, runID) ||
              !runnerExecution.isDisplayOnly)) {
        throw const FormatException(
          'Forge native Runner execution observation is not bound to the Run.',
        );
      }
      if (sessionRunnerReceipt != null &&
          (!sessionRunnerReceipt.isFor(conversationID, runID) ||
              !sessionRunnerReceipt.isDisplayOnly)) {
        throw const FormatException(
          'Forge native session Runner receipt observation is not bound to the Run.',
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

      tester.view.physicalSize = const Size(1280, 2200);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            deviceObservationRequest: sessionObservationRequest,
            runObserved: runObserved,
            runIntentObservation: runIntent,
            runnerExecutionIntentObservation: runnerExecution,
            sessionRunnerReceiptObservation: sessionRunnerReceipt,
          ),
        ),
      );
      await _pumpUntil(
        tester,
        () => find.text('Shared from client A').evaluate().isNotEmpty,
        waitFor: 'shared conversation',
      );
      await _pumpUntil(
        tester,
        () => find.text(runID).evaluate().isNotEmpty,
        waitFor: 'completed Run',
      );
      await _pumpUntil(
        tester,
        () =>
            find.text('run_started').evaluate().isNotEmpty &&
            find.text('run_finished').evaluate().isNotEmpty,
        waitFor: 'Run timeline markers',
      );
      if (sessionRunnerReceipt != null) {
        final uncertain =
            sessionRunnerReceipt.receiptObservation.dispositionKind ==
            'uncertain';
        expect(sessionRunnerReceipt.receiptObservation.uncertain, uncertain);
        expect(
          sessionRunnerReceipt.receiptObservation.reconciliationRequired,
          uncertain,
        );
        expect(
          sessionRunnerReceipt.receiptObservation.manualReviewRequired,
          uncertain,
        );
        expect(sessionRunnerReceipt.receiptObservation.automaticRetry, isFalse);
        expect(
          sessionRunnerReceipt.receiptObservation.followUp,
          uncertain ? 'reconciliation_manual' : 'none',
        );

        await tester.runAsync(() async {
          final receiptAPI = ForgeConversationsApi(
            baseUrl: apiURL,
            accessToken: accessToken,
          );
          try {
            final returned = await receiptAPI
                .previewSessionRunnerReceiptObservation(
                  conversationID: conversationID,
                  runID: runID,
                  observation: sessionRunnerReceipt,
                );
            expect(returned.toJson(), sessionRunnerReceipt.toJson());
            expect(returned.receiptObservation.uncertain, uncertain);
            expect(
              returned.receiptObservation.reconciliationRequired,
              uncertain,
            );
            expect(returned.receiptObservation.manualReviewRequired, uncertain);
            expect(returned.receiptObservation.automaticRetry, isFalse);
            expect(
              returned.receiptObservation.followUp,
              uncertain ? 'reconciliation_manual' : 'none',
            );
          } finally {
            receiptAPI.close();
          }
        });
      }
      if (runIntent != null) {
        await _scrollUntilFinder(
          tester,
          find.byKey(const ValueKey('forge-run-intent-observation-card')),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('forge-run-intent-observation-card'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'Run-intent observation card',
        );
        expect(find.text('Run intent preview'), findsOneWidget);
        expect(find.text('Execution authorized'), findsOneWidget);
      }
      if (runnerExecution != null) {
        await _scrollUntilFinder(
          tester,
          find.byKey(const ValueKey('forge-runner-execution-intent-card')),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('forge-runner-execution-intent-card'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'Runner execution intent observation card',
        );
        expect(find.text('Runner execution intent preview'), findsOneWidget);
        final runnerCard = find.byKey(
          const ValueKey('forge-runner-execution-intent-card'),
        );
        expect(
          find.descendant(of: runnerCard, matching: find.text('attempt-1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: runnerCard, matching: find.text('command-1')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: runnerCard, matching: find.text('runner-1')),
          findsOneWidget,
        );
        expect(find.text('private event payload'), findsNothing);
      }
      if (sessionRunnerReceipt != null) {
        await _scrollUntilFinder(
          tester,
          find.byKey(
            const ValueKey('forge-session-runner-receipt-observation-card'),
          ),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(
                const ValueKey('forge-session-runner-receipt-observation-card'),
              )
              .evaluate()
              .isNotEmpty,
          waitFor: 'session Runner receipt observation card',
        );
        expect(find.text('Session Runner receipt preview'), findsOneWidget);
        expect(find.text('attempt-1'), findsWidgets);
        expect(find.text('command-1'), findsWidgets);
        expect(find.text('runner-1'), findsWidgets);
        expect(
          find.text(sessionRunnerReceipt.receiptObservation.dispositionKind),
          findsWidgets,
        );
        expect(
          find.text(sessionRunnerReceipt.receiptObservation.followUp),
          findsWidgets,
        );
        expect(find.text('private event payload'), findsNothing);
      }

      if (sessionObservationRequest != null) {
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
        await tester.pump();
        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('forge-session-device-observation'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'session device observation panel',
        );
        expect(find.text('Devices: 9 · Runner instances: 9'), findsOneWidget);
        expect(
          find.text(
            'Declared totals: CPU 66 · memory 135168 B · storage 67584 B',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Eligible declared devices: 2 · instances: 2'),
          findsOneWidget,
        );
        expect(find.text('Device: candidate-a'), findsOneWidget);
        expect(find.text('Device: candidate-i'), findsOneWidget);
      }

      expect(find.textContaining('Prompt ID:'), findsOneWidget);
      expect(find.text('run_started'), findsOneWidget);
      expect(find.text('run_finished'), findsOneWidget);
      expect(find.text('deterministic Run observation fixture'), findsNothing);
      expect(find.text('private event payload'), findsNothing);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-run-observed-card')),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await _pumpUntil(
        tester,
        () => find
            .byKey(const ValueKey('forge-run-observed-card'))
            .evaluate()
            .isNotEmpty,
        waitFor: 'selected Run metadata observation card',
      );
      expect(find.text('Run metadata observation'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('forge-run-observed-card')),
          matching: find.text(runID),
        ),
        findsOneWidget,
      );

      final foreign = _copyObserved(runObserved, runID: '$runID-foreign');
      final content = _copyObserved(runObserved, contentIncluded: true);
      final authority = _copyObserved(
        runObserved,
        authority: const ForgeRunObservedAuthority(
          identityVerified: false,
          ownerAuthorized: false,
          runAuthoritative: false,
          persistenceAttested: false,
          contentProvenanceVerified: false,
          reservationCreated: false,
          executionAuthorized: true,
          dispatchPerformed: false,
        ),
      );
      expect(foreign.isFor(conversationID, runID), isFalse);
      expect(foreign.isDisplayOnly, isTrue);
      expect(content.isFor(conversationID, runID), isTrue);
      expect(content.isDisplayOnly, isFalse);
      expect(authority.isFor(conversationID, runID), isTrue);
      expect(authority.isDisplayOnly, isFalse);
      await _assertObserverHidden(tester, conversationID, runID, foreign);
      await _assertObserverHidden(tester, conversationID, runID, content);
      await _assertObserverHidden(tester, conversationID, runID, authority);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();

      // Recreate the native route with the same credential store. The first
      // screen has persisted its validated timeline sequence; the second
      // screen deliberately receives no caller-supplied device observation so
      // this remount proves Run resume independently from the P3a preview.
      await tester.pumpWidget(
        MaterialApp(home: ForgeSessionsGate(credentialStore: credentialStore)),
      );
      await _pumpUntil(
        tester,
        () => find.text('Shared from client A').evaluate().isNotEmpty,
        waitFor: 'shared conversation after remount',
      );
      await _pumpUntil(
        tester,
        () => find.text(runID).evaluate().isNotEmpty,
        waitFor: 'completed Run after remount',
      );
      await _pumpUntil(
        tester,
        () => find.text('No timeline markers to show.').evaluate().isNotEmpty,
        waitFor: 'checkpoint-resumed empty Run timeline page',
      );
      expect(find.text('run_started'), findsNothing);
      expect(find.text('run_finished'), findsNothing);
      expect(
        find.byKey(const ValueKey('forge-session-device-observation')),
        findsNothing,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
    skip: inputPath == null,
  );
}

ForgeSessionPlacementRequest _sessionPlacementRequestFromInput(Object? raw) {
  if (raw is! Map) {
    throw const FormatException('Invalid native session observation input.');
  }
  final json = Map<String, dynamic>.from(raw);
  final owner = ForgeDeviceOwner.fromJson(json['owner']);
  final conversationID = json['conversation_id'];
  final runID = json['run_id'];
  final placement = ForgeDevicePlacementRequest.fromJson(json['placement']);
  final rawCandidates = json['candidates'];
  if (conversationID is! String ||
      runID is! String ||
      rawCandidates is! List ||
      rawCandidates.length != placement.devices.length) {
    throw const FormatException('Invalid native session observation input.');
  }
  final candidates = rawCandidates
      .map((value) {
        final candidate = Map<String, dynamic>.from(value as Map);
        return ForgeSessionPlacementCandidate(
          instanceID: candidate['instance_id'] as String,
          device: ForgeDeviceDeclaration.fromJson(candidate['device']),
        );
      })
      .toList(growable: false);
  if (owner != placement.owner) {
    throw const FormatException('Native session observation owner drifted.');
  }
  return ForgeSessionPlacementRequest(
    owner: owner,
    conversationID: conversationID,
    runID: runID,
    placement: placement,
    candidates: candidates,
  );
}

ForgeRunObserved _copyObserved(
  ForgeRunObserved value, {
  String? runID,
  bool? contentIncluded,
  ForgeRunObservedAuthority? authority,
}) => ForgeRunObserved(
  ownerRef: value.ownerRef,
  conversationID: value.conversationID,
  runID: runID ?? value.runID,
  promptID: value.promptID,
  createdAtMS: value.createdAtMS,
  latestSequence: value.latestSequence,
  status: value.status,
  metadataObserved: value.metadataObserved,
  contentIncluded: contentIncluded ?? value.contentIncluded,
  authority: authority ?? value.authority,
);

Future<void> _assertObserverHidden(
  WidgetTester tester,
  String conversationID,
  String runID,
  ForgeRunObserved candidate,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: ForgeSessionsScreen(
        accessToken: 'probe-bearer',
        apiOrigin: 'https://forge.example',
        httpClient: _observerProbeClient(conversationID, runID),
        runObserved: candidate,
      ),
    ),
  );
  await _pumpUntil(tester, () {
    if (find.byType(CircularProgressIndicator).evaluate().isNotEmpty) {
      return false;
    }
    return find.text(runID).evaluate().isNotEmpty;
  }, waitFor: 'probe selected Run');
  expect(find.byKey(const ValueKey('forge-run-observed-card')), findsNothing);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}

http.Client _observerProbeClient(String conversationID, String runID) =>
    MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _observerProbeJSON({
          'conversations': [
            {
              'conversation': {
                'id': conversationID,
                'scope': {'kind': 'global'},
                'title': 'Shared from client A',
                'created_at_ms': 1,
                'updated_at_ms': 2,
              },
              'aggregate_version': 1,
            },
          ],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/$conversationID') {
        return _observerProbeJSON({
          'conversation': {
            'id': conversationID,
            'scope': {'kind': 'global'},
            'title': 'Shared from client A',
            'created_at_ms': 1,
            'updated_at_ms': 2,
          },
          'aggregate_version': 1,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/$conversationID/prompts') {
        return _observerProbeJSON({
          'conversation_id': conversationID,
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/$conversationID/runs') {
        return _observerProbeJSON({
          'conversation_id': conversationID,
          'runs': [
            {
              'run_id': runID,
              'prompt_id': 'prompt-live-probe',
              'created_at_ms': 10,
              'latest_sequence': 2,
              'status': 'completed',
            },
          ],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/$conversationID/runs/$runID/timeline') {
        return _observerProbeJSON({
          'conversation_id': conversationID,
          'run_id': runID,
          'after_sequence': 0,
          'scanned_through_sequence': 2,
          'has_more': false,
          'events': [
            {'seq': 1, 'emitted_at_ms': 11, 'type': 'run_started'},
            {'seq': 2, 'emitted_at_ms': 12, 'type': 'run_finished'},
          ],
        });
      }
      throw StateError(
        'Unexpected observer probe request: ${request.method} ${request.url}',
      );
    });

http.Response _observerProbeJSON(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Future<void> _scrollUntilFinder(WidgetTester tester, Finder finder) async {
  for (var count = 0; count < 16; count++) {
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder);
      return;
    }
    final scrollable = find.byType(Scrollable);
    if (scrollable.evaluate().isEmpty) break;
    await tester.drag(scrollable.first, const Offset(0, -700));
    await tester.pump();
  }
  expect(finder, findsOneWidget);
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
