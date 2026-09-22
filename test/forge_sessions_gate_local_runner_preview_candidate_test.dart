import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_local_runner_preview.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() => BrowserNavigation.resetForTest());

  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('explicit Gate posts one local Runner preview', (tester) async {
    final request = _request();
    final credentialStore = await _credentialStore('candidate-token');
    final requests = <http.Request>[];
    final client = MockClient((http.Request httpRequest) async {
      requests.add(httpRequest);
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation()],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/conversation-001/prompts') {
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/conversation-001/runs') {
        return _json({
          'conversation_id': 'conversation-001',
          'runs': [_run()],
          'has_more': false,
        });
      }
      if (httpRequest.method == 'GET' &&
          httpRequest.url.path ==
              '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
        return _json({
          'conversation_id': 'conversation-001',
          'run_id': 'run-001',
          'after_sequence': 0,
          'scanned_through_sequence': 1,
          'has_more': false,
          'events': <Object>[],
        });
      }
      if (httpRequest.method == 'POST' &&
          httpRequest.url.path ==
              '/api/v1/conversations/conversation-001/run-intents/intent-001/execution-readiness-preview') {
        expect(httpRequest.headers['authorization'], 'Bearer candidate-token');
        expect(jsonDecode(httpRequest.body), request.toJson());
        return _json(_response(request));
      }
      throw StateError(
        'Unexpected Forge request: ${httpRequest.method} ${httpRequest.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          localRunnerPreviewRequest: request,
          enableLocalRunnerPreviewCandidate: true,
          localRunnerPreviewCandidateApiOrigin: 'https://candidate.example',
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.text('Local Runner execution-readiness preview'),
      findsOneWidget,
    );
    expect(
      find.text('Preview only · no execution authority granted'),
      findsOneWidget,
    );
    expect(
      requests.where(
        (value) => value.url.path.endsWith('execution-readiness-preview'),
      ),
      hasLength(1),
    );
  });

  testWidgets('default Gate keeps local Runner preview request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted a candidate route: $request');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
        ),
      ),
    );
    await _settle(tester);

    expect(
      requests.where(
        (request) => request.url.path.endsWith('execution-readiness-preview'),
      ),
      isEmpty,
    );
  });
}

ForgeLocalRunnerPreviewRequest _request() {
  final command = ForgeRunnerExecutionCommand(
    version: 1,
    commandID: 'command-001',
    leaseProof: const ForgeRunnerExecutionLeaseProof(
      attemptID: 'attempt-001',
      targetID: 'runner-1',
      epoch: 1,
      fencingToken: 'fence-001',
    ),
    idempotencyKey: 'run-001:attempt-001:command-001',
    workspaceRef: 'workspace-001',
    argv: const ['forge-task', '--prompt-ref', 'prompt-001'],
    timeoutMS: 5000,
    maxOutputBytes: 65536,
  );
  return ForgeLocalRunnerPreviewRequest(
    intent: ForgeRunnerExecutionIntentRequest(
      owner: _owner,
      conversationID: 'conversation-001',
      prompt: const ForgeRunnerExecutionPromptReceipt(
        promptID: 'prompt-001',
        conversationID: 'conversation-001',
        role: 'user',
        acceptedAtMS: 200,
        intentID: 'intent-001',
        initialEventID: 'event-001',
        initialEventSequence: 1,
        initialEventType: 'submitted',
        replayed: false,
      ),
      run: const ForgeRunnerExecutionRunReference(
        runID: 'run-001',
        conversationID: 'conversation-001',
        promptID: 'prompt-001',
        createdAtMS: 200,
        latestSequence: 5,
        status: 'nonterminal',
      ),
      binding: ForgeRunnerExecutionIntentBinding(
        conversationID: 'conversation-001',
        promptID: 'prompt-001',
        runID: 'run-001',
        attemptID: 'attempt-001',
        commandID: 'command-001',
        targetID: 'runner-1',
        commandSHA256: command.commandSHA256(),
        idempotencyKey: 'run-001:attempt-001:command-001',
        selectedTargetID: null,
      ),
      command: command,
    ),
    grant: const ForgeRunnerTerminalReceiptGrant(
      version: 1,
      attemptID: 'attempt-001',
      targetID: 'runner-1',
      epoch: 1,
      fencingToken: 'fence-001',
      issuedAtMS: 100,
      expiresAtMS: 10100,
    ),
    observedAtMS: 300,
  );
}

Map<String, dynamic> _response(ForgeLocalRunnerPreviewRequest request) {
  final intent = observeForgeRunnerExecutionIntent(request.intent);
  final receipt = ForgeRunnerTerminalReceiptObservation(
    schemaVersion: forgeRunnerTerminalReceiptSchema,
    evaluationMode: forgeRunnerTerminalReceiptEvaluationMode,
    commandID: intent.commandID,
    commandSHA256: intent.commandSHA256,
    attemptID: intent.attemptID,
    targetID: intent.targetID,
    dispositionKind: 'completed',
    observedAtMS: request.observedAtMS,
    receiptValid: true,
    previewOnly: true,
    uncertain: false,
    reconciliationRequired: false,
    manualReviewRequired: false,
    automaticRetry: false,
    followUp: 'none',
    authority: const ForgeRunnerTerminalReceiptAuthority.offline(),
  );
  final session = ForgeSessionRunnerReceiptObservation(
    schemaVersion: forgeSessionRunnerReceiptObservationSchema,
    evaluationMode: forgeSessionRunnerReceiptObservationEvaluationMode,
    owner: _owner,
    conversationID: intent.conversationID,
    promptID: intent.promptID,
    runID: intent.runID,
    receiptObservation: receipt,
    promptRunBindingValid: true,
    receiptBindingValid: true,
    previewOnly: true,
    selectedTargetID: null,
    authority: const ForgeSessionRunnerReceiptObservationAuthority.offline(),
  );
  return ForgeLocalRunnerPreviewObservation(
    schemaVersion: forgeLocalRunnerPreviewSchema,
    evaluationMode: forgeLocalRunnerPreviewEvaluationMode,
    runnerExecutionIntent: intent,
    sessionRunnerReceipt: session,
    commandID: intent.commandID,
    attemptID: intent.attemptID,
    targetID: intent.targetID,
    commandSHA256: intent.commandSHA256,
    dispositionKind: 'completed',
    observedAtMS: request.observedAtMS,
    outputBytes: 8,
    exitCode: 0,
    executorInvoked: true,
    previewOnly: true,
    authority: const ForgeRunnerExecutionIntentAuthority.offline(),
  ).toJson();
}

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Shared work',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run() => {
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 200,
  'latest_sequence': 5,
  'status': 'nonterminal',
};

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
