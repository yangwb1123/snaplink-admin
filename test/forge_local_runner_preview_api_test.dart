import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_local_runner_preview.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_terminal_receipt.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

void main() {
  final canonicalFixturePath =
      Platform.environment['FORGE_LOCAL_RUNNER_PREVIEW_FIXTURE'];

  test(
    'consumes the canonical local Runner preview observation fixture',
    () {
      final source = File(canonicalFixturePath!).readAsStringSync();
      final root = jsonDecode(source) as Map<String, dynamic>;
      final observation = ForgeLocalRunnerPreviewObservation.fromJson(
        root,
        request: _request(),
        conversationID: 'conversation-001',
        intentID: 'intent-001',
      );
      expect(observation.schemaVersion, forgeLocalRunnerPreviewSchema);
      expect(observation.evaluationMode, forgeLocalRunnerPreviewEvaluationMode);
      expect(observation.runnerExecutionIntent.runID, 'run-001');
      expect(observation.targetID, 'runner-1');
      expect(observation.dispositionKind, 'completed');
      expect(observation.outputBytes, 8);
      expect(observation.exitCode, 0);
      expect(observation.sessionRunnerReceipt.selectedTargetID, isNull);
      expect(observation.authority.isOffline, isTrue);
      expect(jsonEncode(observation.toJson()), jsonEncode(root));
    },
    skip: canonicalFixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('canonical local Runner preview rejects authority and unknown drift', () {
    final root = _response(_request());
    expect(
      () => ForgeLocalRunnerPreviewObservation.fromJson(
        {...root, 'unexpected': true},
        request: _request(),
        conversationID: 'conversation-001',
        intentID: 'intent-001',
      ),
      throwsA(isA<FormatException>()),
    );
    final authority = Map<String, dynamic>.from(root['authority'] as Map)
      ..['execution_authorized'] = true;
    expect(
      () => ForgeLocalRunnerPreviewObservation.fromJson(
        {...root, 'authority': authority},
        request: _request(),
        conversationID: 'conversation-001',
        intentID: 'intent-001',
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('serializes the path-bound local Runner preview request', () {
    final request = _request();
    request.validateForPath('conversation-001', 'intent-001');

    expect(request.toJson(), {
      'intent': {
        'owner': _owner.toJson(),
        'conversation_id': 'conversation-001',
        'prompt_receipt': {
          'prompt_id': 'prompt-001',
          'conversation_id': 'conversation-001',
          'role': 'user',
          'accepted_at_ms': 200,
          'intent_id': 'intent-001',
          'initial_event_id': 'event-001',
          'initial_event_sequence': 1,
          'initial_event_type': 'submitted',
          'replayed': false,
        },
        'run_reference': {
          'run_id': 'run-001',
          'conversation_id': 'conversation-001',
          'prompt_id': 'prompt-001',
          'created_at_ms': 200,
          'latest_sequence': 5,
          'status': 'nonterminal',
        },
        'execution_intent': {
          'conversation_id': 'conversation-001',
          'prompt_id': 'prompt-001',
          'run_id': 'run-001',
          'attempt_id': 'attempt-001',
          'command_id': 'command-001',
          'target_id': 'runner-1',
          'command_sha256': request.intent.binding.commandSHA256,
          'idempotency_key': 'run-001:attempt-001:command-001',
          'selected_target_id': null,
        },
        'command': {
          'v': 1,
          'command_id': 'command-001',
          'lease_proof': {
            'attempt_id': 'attempt-001',
            'target_id': 'runner-1',
            'epoch': 1,
            'fencing_token': 'fence-001',
          },
          'idempotency_key': 'run-001:attempt-001:command-001',
          'workspace_ref': 'workspace-001',
          'argv': ['forge-task', '--prompt-ref', 'prompt-001'],
          'timeout_ms': 5000,
          'max_output_bytes': 65536,
        },
      },
      'grant': {
        'v': 1,
        'attempt_id': 'attempt-001',
        'target_id': 'runner-1',
        'epoch': 1,
        'fencing_token': 'fence-001',
        'issued_at_ms': 100,
        'expires_at_ms': 10100,
      },
      'observed_at_ms': 300,
    });
  });

  test('posts exactly once and validates the full metadata binding', () async {
    final request = _request();
    final response = _response(request);
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((value) async {
        requests.add(value);
        return _json(response);
      }),
    );
    addTearDown(api.close);

    final observation = await api.previewLocalRunnerExecutionReadiness(
      conversationID: 'conversation-001',
      intentID: 'intent-001',
      request: request,
    );

    expect(observation.runnerExecutionIntent.owner, _owner);
    expect(observation.sessionRunnerReceipt.runID, 'run-001');
    expect(observation.commandID, 'command-001');
    expect(
      observation.sessionRunnerReceipt.receiptObservation.dispositionKind,
      'completed',
    );
    expect(observation.authority.isOffline, isTrue);
    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(
      requests.single.url.path,
      '/api/v1/conversations/conversation-001/run-intents/intent-001/'
      'execution-readiness-preview',
    );
    expect(requests.single.headers['authorization'], 'Bearer forge-bearer');
    expect(jsonDecode(requests.single.body), request.toJson());
  });

  test('does not replay the POST after an unauthorized response', () async {
    var calls = 0;
    var refreshes = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      refreshAccessToken: (_) async {
        refreshes++;
        return 'rotated-token';
      },
      httpClient: MockClient((_) async {
        calls++;
        return _json({
          'code': 'unauthorized',
          'message': 'private',
        }, status: 401);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewLocalRunnerExecutionReadiness(
        conversationID: 'conversation-001',
        intentID: 'intent-001',
        request: _request(),
      ),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 401)
            .having((error) => error.message, 'message', contains('private')),
      ),
    );
    expect(calls, 1);
    expect(refreshes, 0);
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
  final intent = ForgeRunnerExecutionIntentRequest(
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
  );
  return ForgeLocalRunnerPreviewRequest(
    intent: intent,
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

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);
