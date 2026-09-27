import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';

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
  test(
    'posts one owner and path-bound Runner execution-intent preview',
    () async {
      final request = _request();
      final expected = observeForgeRunnerExecutionIntent(request);
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((http.Request httpRequest) async {
          calls++;
          expect(httpRequest.method, 'POST');
          expect(
            httpRequest.url.path,
            '/api/v1/conversations/conversation-001/runs/run-001/'
            'runner-execution-intent/preview',
          );
          expect(httpRequest.url.query, isEmpty);
          expect(httpRequest.headers['authorization'], 'Bearer forge-bearer');
          expect(jsonDecode(httpRequest.body), _requestJson(request));
          return _json(expected.toJson());
        }),
      );
      addTearDown(api.close);

      final result = await api.previewRunnerExecutionIntent(
        request: request,
        candidateOrigin: 'https://candidate.example/',
      );
      expect(calls, 1);
      expect(result.isFor('conversation-001', 'run-001'), isTrue);
      expect(result.isDisplayOnly, isTrue);
      expect(result.selectedTargetID, isNull);
      expect(result.authority.isOffline, isTrue);
    },
  );

  test(
    'does not replay or issue a POST after origin or response drift',
    () async {
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async {
          calls++;
          final body = _requestResponse().toJson()..['run_id'] = 'run-foreign';
          return _json(body);
        }),
      );
      addTearDown(api.close);
      await expectLater(
        api.previewRunnerExecutionIntent(
          request: _request(),
          candidateOrigin: 'https://other.example',
        ),
        throwsFormatException,
      );
      expect(calls, 0);
      await expectLater(
        api.previewRunnerExecutionIntent(
          request: _request(),
          candidateOrigin: 'https://candidate.example',
        ),
        throwsFormatException,
      );
      expect(calls, 1);
    },
  );
}

ForgeRunnerExecutionIntentRequest _request() {
  const conversationID = 'conversation-001';
  const promptID = 'prompt-001';
  const runID = 'run-001';
  const attemptID = 'attempt-001';
  const commandID = 'command-001';
  const targetID = 'runner-1';
  final idempotencyKey = '$runID:$attemptID:$commandID';
  final command = ForgeRunnerExecutionCommand(
    version: 1,
    commandID: commandID,
    leaseProof: const ForgeRunnerExecutionLeaseProof(
      attemptID: attemptID,
      targetID: targetID,
      epoch: 1,
      fencingToken: 'fence-001',
    ),
    idempotencyKey: idempotencyKey,
    workspaceRef: 'workspace-001',
    argv: const ['forge-task', '--prompt-ref', promptID],
    timeoutMS: 5000,
    maxOutputBytes: 65536,
  );
  return ForgeRunnerExecutionIntentRequest(
    owner: _owner,
    conversationID: conversationID,
    prompt: const ForgeRunnerExecutionPromptReceipt(
      promptID: promptID,
      conversationID: conversationID,
      role: 'user',
      acceptedAtMS: 200,
      intentID: 'intent-001',
      initialEventID: 'event-001',
      initialEventSequence: 1,
      initialEventType: 'submitted',
      replayed: false,
    ),
    run: const ForgeRunnerExecutionRunReference(
      runID: runID,
      conversationID: conversationID,
      promptID: promptID,
      createdAtMS: 200,
      latestSequence: 5,
      status: 'nonterminal',
    ),
    binding: ForgeRunnerExecutionIntentBinding(
      conversationID: conversationID,
      promptID: promptID,
      runID: runID,
      attemptID: attemptID,
      commandID: commandID,
      targetID: targetID,
      commandSHA256: command.commandSHA256(),
      idempotencyKey: idempotencyKey,
      selectedTargetID: null,
    ),
    command: command,
  );
}

ForgeRunnerExecutionIntentObservation _requestResponse() =>
    observeForgeRunnerExecutionIntent(_request());

Map<String, dynamic> _requestJson(ForgeRunnerExecutionIntentRequest request) =>
    {
      'owner': request.owner.toJson(),
      'conversation_id': request.conversationID,
      'prompt_receipt': {
        'prompt_id': request.prompt.promptID,
        'conversation_id': request.prompt.conversationID,
        'role': request.prompt.role,
        'accepted_at_ms': request.prompt.acceptedAtMS,
        'intent_id': request.prompt.intentID,
        'initial_event_id': request.prompt.initialEventID,
        'initial_event_sequence': request.prompt.initialEventSequence,
        'initial_event_type': request.prompt.initialEventType,
        'replayed': request.prompt.replayed,
      },
      'run_reference': {
        'run_id': request.run.runID,
        'conversation_id': request.run.conversationID,
        'prompt_id': request.run.promptID,
        'created_at_ms': request.run.createdAtMS,
        'latest_sequence': request.run.latestSequence,
        'status': request.run.status,
      },
      'execution_intent': {
        'conversation_id': request.binding.conversationID,
        'prompt_id': request.binding.promptID,
        'run_id': request.binding.runID,
        'attempt_id': request.binding.attemptID,
        'command_id': request.binding.commandID,
        'target_id': request.binding.targetID,
        'command_sha256': request.binding.commandSHA256,
        'idempotency_key': request.binding.idempotencyKey,
        'selected_target_id': request.binding.selectedTargetID,
      },
      'command': {
        'v': request.command.version,
        'command_id': request.command.commandID,
        'lease_proof': {
          'attempt_id': request.command.leaseProof.attemptID,
          'target_id': request.command.leaseProof.targetID,
          'epoch': request.command.leaseProof.epoch,
          'fencing_token': request.command.leaseProof.fencingToken,
        },
        'idempotency_key': request.command.idempotencyKey,
        'workspace_ref': request.command.workspaceRef,
        'argv': request.command.argv,
        'timeout_ms': request.command.timeoutMS,
        'max_output_bytes': request.command.maxOutputBytes,
      },
    };
