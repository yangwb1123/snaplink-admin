part of 'forge_local_runner_preview.dart';

Map<String, dynamic> _intentRequestJson(
  ForgeRunnerExecutionIntentRequest request,
) => {
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

bool _sameIntent(
  ForgeRunnerExecutionIntentObservation actual,
  ForgeRunnerExecutionIntentObservation expected,
) => jsonEncode(actual.toJson()) == jsonEncode(expected.toJson());
