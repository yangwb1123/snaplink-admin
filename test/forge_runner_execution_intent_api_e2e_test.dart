import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';

/// Opt-in integration entry for the accepted EXECUTE + P4 Runner
/// execution-intent preview. It consumes the same metadata-only binding as
/// Core and Runtime without selecting, reserving, or executing a target.
class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_RUNNER_EXECUTION_INTENT_E2E_INPUT'];

  test(
    'Flutter consumes one authenticated Runner execution-intent preview',
    () async {
      final input = _readInput(inputPath!);
      final apiURL = _requiredText(input, 'api_url');
      final accessToken = _requiredText(input, 'access_token');
      final request = _requestFromJson(input['request']);
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
        timeout: const Duration(seconds: 5),
      );
      try {
        final observation = await api.previewRunnerExecutionIntent(
          request: request,
          candidateOrigin: apiURL,
        );
        expect(observation.owner, request.owner);
        expect(observation.conversationID, request.conversationID);
        expect(observation.runID, request.run.runID);
        expect(observation.promptID, request.prompt.promptID);
        expect(observation.commandID, request.command.commandID);
        expect(observation.targetID, request.command.leaseProof.targetID);
        expect(observation.isDisplayOnly, isTrue);
        expect(observation.selectedTargetID, isNull);
        expect(observation.authority.isOffline, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null
        ? 'Run through the accepted EXECUTE + P4 Runner execution-intent harness.'
        : false,
  );
}

ForgeRunnerExecutionIntentRequest _requestFromJson(Object? value) {
  final json = _object(value, 'request');
  _exact(json, {
    'owner',
    'conversation_id',
    'prompt_receipt',
    'run_reference',
    'execution_intent',
    'command',
  });
  final prompt = _object(json['prompt_receipt'], 'prompt_receipt');
  _exact(prompt, {
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
  final run = _object(json['run_reference'], 'run_reference');
  _exact(run, {
    'run_id',
    'conversation_id',
    'prompt_id',
    'created_at_ms',
    'latest_sequence',
    'status',
  });
  final binding = _object(json['execution_intent'], 'execution_intent');
  _exact(binding, {
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
  final command = _object(json['command'], 'command');
  _exact(command, {
    'v',
    'command_id',
    'lease_proof',
    'idempotency_key',
    'workspace_ref',
    'argv',
    'timeout_ms',
    'max_output_bytes',
  });
  final proof = _object(command['lease_proof'], 'lease_proof');
  _exact(proof, {'attempt_id', 'target_id', 'epoch', 'fencing_token'});
  final argv = command['argv'];
  if (argv is! List || argv.any((value) => value is! String)) {
    throw const FormatException('Invalid command argv.');
  }
  return ForgeRunnerExecutionIntentRequest(
    owner: ForgeDeviceOwner.fromJson(json['owner']),
    conversationID: _text(json['conversation_id']),
    prompt: ForgeRunnerExecutionPromptReceipt(
      promptID: _text(prompt['prompt_id']),
      conversationID: _text(prompt['conversation_id']),
      role: _text(prompt['role']),
      acceptedAtMS: _int(prompt['accepted_at_ms']),
      intentID: _text(prompt['intent_id']),
      initialEventID: _text(prompt['initial_event_id']),
      initialEventSequence: _int(prompt['initial_event_sequence']),
      initialEventType: _text(prompt['initial_event_type']),
      replayed: _bool(prompt['replayed']),
    ),
    run: ForgeRunnerExecutionRunReference(
      runID: _text(run['run_id']),
      conversationID: _text(run['conversation_id']),
      promptID: _text(run['prompt_id']),
      createdAtMS: _int(run['created_at_ms']),
      latestSequence: _int(run['latest_sequence']),
      status: _text(run['status']),
    ),
    binding: ForgeRunnerExecutionIntentBinding(
      conversationID: _text(binding['conversation_id']),
      promptID: _text(binding['prompt_id']),
      runID: _text(binding['run_id']),
      attemptID: _text(binding['attempt_id']),
      commandID: _text(binding['command_id']),
      targetID: _text(binding['target_id']),
      commandSHA256: _text(binding['command_sha256']),
      idempotencyKey: _text(binding['idempotency_key']),
      selectedTargetID: binding['selected_target_id'] as String?,
    ),
    command: ForgeRunnerExecutionCommand(
      version: _int(command['v']),
      commandID: _text(command['command_id']),
      leaseProof: ForgeRunnerExecutionLeaseProof(
        attemptID: _text(proof['attempt_id']),
        targetID: _text(proof['target_id']),
        epoch: _int(proof['epoch']),
        fencingToken: _text(proof['fencing_token']),
      ),
      idempotencyKey: _text(command['idempotency_key']),
      workspaceRef: _text(command['workspace_ref']),
      argv: List<String>.from(argv),
      timeoutMS: _int(command['timeout_ms']),
      maxOutputBytes: _int(command['max_output_bytes']),
    ),
  );
}

Map<String, dynamic> _readInput(String path) {
  final decoded = jsonDecode(File(path).readAsStringSync());
  return _object(decoded, 'E2E input');
}

String _requiredText(Map<String, dynamic> input, String key) {
  final value = input[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Missing Runner execution-intent $key.');
  }
  return value;
}

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Invalid Runner execution-intent $label.');
  }
  return Map<String, dynamic>.from(value);
}

void _exact(Map<String, dynamic> value, Set<String> keys) {
  if (value.length != keys.length ||
      value.keys.any((key) => !keys.contains(key))) {
    throw const FormatException('Unexpected Runner execution-intent fields.');
  }
}

String _text(Object? value) {
  if (value is! String || value.isEmpty) {
    throw const FormatException('Invalid Runner execution-intent text.');
  }
  return value;
}

int _int(Object? value) {
  if (value is! int) {
    throw const FormatException('Invalid Runner execution-intent integer.');
  }
  return value;
}

bool _bool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Runner execution-intent boolean.');
  }
  return value;
}
