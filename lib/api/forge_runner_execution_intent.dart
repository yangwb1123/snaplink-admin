import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';

part 'forge_runner_execution_intent_observation.dart';
part 'forge_runner_execution_intent_projection.dart';

const forgeRunnerExecutionIntentSchema = 'forge.runner-execution-intent/v1';
const forgeRunnerExecutionIntentEvaluationMode = 'pure_runner_binding_only';
const forgeRunnerExecutionIntentMaxSafeInteger = 9007199254740991;

class ForgeRunnerExecutionPromptReceipt {
  final String promptID;
  final String conversationID;
  final String role;
  final int acceptedAtMS;
  final String intentID;
  final String initialEventID;
  final int initialEventSequence;
  final String initialEventType;
  final bool replayed;

  const ForgeRunnerExecutionPromptReceipt({
    required this.promptID,
    required this.conversationID,
    required this.role,
    required this.acceptedAtMS,
    required this.intentID,
    required this.initialEventID,
    required this.initialEventSequence,
    required this.initialEventType,
    required this.replayed,
  });

  factory ForgeRunnerExecutionPromptReceipt.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'prompt receipt');
    _runnerExecutionExactKeys(json, {
      'prompt_id',
      'conversation_id',
      'role',
      'accepted_at_ms',
      'intent_id',
      'initial_event_id',
      'initial_event_sequence',
      'initial_event_type',
      'replayed',
    });
    return ForgeRunnerExecutionPromptReceipt(
      promptID: _runnerExecutionIdentifier(json['prompt_id']),
      conversationID: _runnerExecutionIdentifier(json['conversation_id']),
      role: _runnerExecutionText(json['role'], 32),
      acceptedAtMS: _runnerExecutionInteger(json['accepted_at_ms']),
      intentID: _runnerExecutionIdentifier(json['intent_id']),
      initialEventID: _runnerExecutionIdentifier(json['initial_event_id']),
      initialEventSequence: _runnerExecutionInteger(
        json['initial_event_sequence'],
      ),
      initialEventType: _runnerExecutionText(json['initial_event_type'], 64),
      replayed: _runnerExecutionBool(json['replayed']),
    );
  }
}

class ForgeRunnerExecutionRunReference {
  final String runID;
  final String conversationID;
  final String promptID;
  final int createdAtMS;
  final int latestSequence;
  final String status;

  const ForgeRunnerExecutionRunReference({
    required this.runID,
    required this.conversationID,
    required this.promptID,
    required this.createdAtMS,
    required this.latestSequence,
    required this.status,
  });

  factory ForgeRunnerExecutionRunReference.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'run reference');
    _runnerExecutionExactKeys(json, {
      'run_id',
      'conversation_id',
      'prompt_id',
      'created_at_ms',
      'latest_sequence',
      'status',
    });
    return ForgeRunnerExecutionRunReference(
      runID: _runnerExecutionIdentifier(json['run_id']),
      conversationID: _runnerExecutionIdentifier(json['conversation_id']),
      promptID: _runnerExecutionIdentifier(json['prompt_id']),
      createdAtMS: _runnerExecutionInteger(json['created_at_ms']),
      latestSequence: _runnerExecutionInteger(json['latest_sequence']),
      status: _runnerExecutionText(json['status'], 32),
    );
  }
}

class ForgeRunnerExecutionLeaseProof {
  final String attemptID;
  final String targetID;
  final int epoch;
  final String fencingToken;

  const ForgeRunnerExecutionLeaseProof({
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
  });

  factory ForgeRunnerExecutionLeaseProof.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'lease proof');
    _runnerExecutionExactKeys(json, {
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
    });
    return ForgeRunnerExecutionLeaseProof(
      attemptID: _runnerExecutionIdentifier(json['attempt_id']),
      targetID: _runnerExecutionIdentifier(json['target_id']),
      epoch: _runnerExecutionInteger(json['epoch']),
      fencingToken: _runnerExecutionText(json['fencing_token'], 256),
    );
  }
}

class ForgeRunnerExecutionCommand {
  final int version;
  final String commandID;
  final ForgeRunnerExecutionLeaseProof leaseProof;
  final String idempotencyKey;
  final String workspaceRef;
  final List<String> argv;
  final int timeoutMS;
  final int maxOutputBytes;

  const ForgeRunnerExecutionCommand({
    required this.version,
    required this.commandID,
    required this.leaseProof,
    required this.idempotencyKey,
    required this.workspaceRef,
    required this.argv,
    required this.timeoutMS,
    required this.maxOutputBytes,
  });

  factory ForgeRunnerExecutionCommand.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'command');
    _runnerExecutionExactKeys(json, {
      'v',
      'command_id',
      'lease_proof',
      'idempotency_key',
      'workspace_ref',
      'argv',
      'timeout_ms',
      'max_output_bytes',
    });
    final rawArgv = json['argv'];
    if (rawArgv is! List || rawArgv.any((value) => value is! String)) {
      throw const FormatException('Invalid Runner execution command argv.');
    }
    return ForgeRunnerExecutionCommand(
      version: _runnerExecutionInteger(json['v']),
      commandID: _runnerExecutionIdentifier(json['command_id']),
      leaseProof: ForgeRunnerExecutionLeaseProof.fromJson(json['lease_proof']),
      idempotencyKey: _runnerExecutionText(json['idempotency_key'], 256),
      workspaceRef: _runnerExecutionText(json['workspace_ref'], 256),
      argv: List<String>.from(rawArgv),
      timeoutMS: _runnerExecutionInteger(json['timeout_ms']),
      maxOutputBytes: _runnerExecutionInteger(json['max_output_bytes']),
    );
  }

  /// Reproduces the Runtime RunnerCommand digest without granting any
  /// execution authority. The map insertion order is the frozen serde JSON
  /// field order used by the Rust ABI.
  String commandSHA256() {
    final value = jsonEncode({
      'v': version,
      'command_id': commandID,
      'lease_proof': {
        'attempt_id': leaseProof.attemptID,
        'target_id': leaseProof.targetID,
        'epoch': leaseProof.epoch,
        'fencing_token': leaseProof.fencingToken,
      },
      'idempotency_key': idempotencyKey,
      'workspace_ref': workspaceRef,
      'argv': argv,
      'timeout_ms': timeoutMS,
      'max_output_bytes': maxOutputBytes,
    });
    final bytes = <int>[
      ...utf8.encode('forge.runtime.runner-command.v1\u0000'),
      ...utf8.encode(value),
    ];
    return crypto.sha256.convert(bytes).toString();
  }
}

class ForgeRunnerExecutionIntentBinding {
  final String conversationID;
  final String promptID;
  final String runID;
  final String attemptID;
  final String commandID;
  final String targetID;
  final String commandSHA256;
  final String idempotencyKey;
  final String? selectedTargetID;

  const ForgeRunnerExecutionIntentBinding({
    required this.conversationID,
    required this.promptID,
    required this.runID,
    required this.attemptID,
    required this.commandID,
    required this.targetID,
    required this.commandSHA256,
    required this.idempotencyKey,
    required this.selectedTargetID,
  });

  factory ForgeRunnerExecutionIntentBinding.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'execution intent');
    _runnerExecutionExactKeys(json, {
      'conversation_id',
      'prompt_id',
      'run_id',
      'attempt_id',
      'command_id',
      'target_id',
      'command_sha256',
      'idempotency_key',
      'selected_target_id',
    });
    final selectedTargetID = json['selected_target_id'];
    if (selectedTargetID != null && selectedTargetID is! String) {
      throw const FormatException(
        'Invalid Runner execution selected target identifier.',
      );
    }
    return ForgeRunnerExecutionIntentBinding(
      conversationID: _runnerExecutionIdentifier(json['conversation_id']),
      promptID: _runnerExecutionIdentifier(json['prompt_id']),
      runID: _runnerExecutionIdentifier(json['run_id']),
      attemptID: _runnerExecutionIdentifier(json['attempt_id']),
      commandID: _runnerExecutionIdentifier(json['command_id']),
      targetID: _runnerExecutionIdentifier(json['target_id']),
      commandSHA256: _runnerExecutionDigest(json['command_sha256']),
      idempotencyKey: _runnerExecutionText(json['idempotency_key'], 256),
      selectedTargetID: selectedTargetID as String?,
    );
  }
}

class ForgeRunnerExecutionIntentRequest {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final ForgeRunnerExecutionPromptReceipt prompt;
  final ForgeRunnerExecutionRunReference run;
  final ForgeRunnerExecutionIntentBinding binding;
  final ForgeRunnerExecutionCommand command;

  const ForgeRunnerExecutionIntentRequest({
    required this.owner,
    required this.conversationID,
    required this.prompt,
    required this.run,
    required this.binding,
    required this.command,
  });

  factory ForgeRunnerExecutionIntentRequest.fromJsonText(String source) {
    rejectDuplicateForgeJsonKeys(source);
    return ForgeRunnerExecutionIntentRequest.fromJson(jsonDecode(source));
  }

  factory ForgeRunnerExecutionIntentRequest.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'request');
    _runnerExecutionExactKeys(json, {
      'owner',
      'conversation_id',
      'prompt_receipt',
      'run_reference',
      'execution_intent',
      'command',
    });
    final request = ForgeRunnerExecutionIntentRequest(
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _runnerExecutionIdentifier(json['conversation_id']),
      prompt: ForgeRunnerExecutionPromptReceipt.fromJson(
        json['prompt_receipt'],
      ),
      run: ForgeRunnerExecutionRunReference.fromJson(json['run_reference']),
      binding: ForgeRunnerExecutionIntentBinding.fromJson(
        json['execution_intent'],
      ),
      command: ForgeRunnerExecutionCommand.fromJson(json['command']),
    );
    observeForgeRunnerExecutionIntent(request);
    return request;
  }

  Map<String, dynamic> toJson() => {
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'prompt_receipt': {
      'prompt_id': prompt.promptID,
      'conversation_id': prompt.conversationID,
      'role': prompt.role,
      'accepted_at_ms': prompt.acceptedAtMS,
      'intent_id': prompt.intentID,
      'initial_event_id': prompt.initialEventID,
      'initial_event_sequence': prompt.initialEventSequence,
      'initial_event_type': prompt.initialEventType,
      'replayed': prompt.replayed,
    },
    'run_reference': {
      'run_id': run.runID,
      'conversation_id': run.conversationID,
      'prompt_id': run.promptID,
      'created_at_ms': run.createdAtMS,
      'latest_sequence': run.latestSequence,
      'status': run.status,
    },
    'execution_intent': {
      'conversation_id': binding.conversationID,
      'prompt_id': binding.promptID,
      'run_id': binding.runID,
      'attempt_id': binding.attemptID,
      'command_id': binding.commandID,
      'target_id': binding.targetID,
      'command_sha256': binding.commandSHA256,
      'idempotency_key': binding.idempotencyKey,
      'selected_target_id': binding.selectedTargetID,
    },
    'command': {
      'v': command.version,
      'command_id': command.commandID,
      'lease_proof': {
        'attempt_id': command.leaseProof.attemptID,
        'target_id': command.leaseProof.targetID,
        'epoch': command.leaseProof.epoch,
        'fencing_token': command.leaseProof.fencingToken,
      },
      'idempotency_key': command.idempotencyKey,
      'workspace_ref': command.workspaceRef,
      'argv': command.argv,
      'timeout_ms': command.timeoutMS,
      'max_output_bytes': command.maxOutputBytes,
    },
  };
}
