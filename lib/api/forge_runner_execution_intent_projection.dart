part of 'forge_runner_execution_intent.dart';

/// Binds one accepted Prompt and existing Run reference to a direct-argv
/// Runner command declaration. This pure projection never selects, reserves,
/// authorizes, dispatches, or executes a target.
ForgeRunnerExecutionIntentObservation observeForgeRunnerExecutionIntent(
  ForgeRunnerExecutionIntentRequest request,
) {
  if (!_validOwner(request.owner) || !_identifier(request.conversationID)) {
    throw const ForgeRunnerExecutionIntentError('invalid_owner');
  }
  _validatePrompt(request.prompt, request.conversationID);
  _validateRun(request.run, request.prompt, request.conversationID);
  _validateBinding(request);
  return ForgeRunnerExecutionIntentObservation(
    schemaVersion: forgeRunnerExecutionIntentSchema,
    evaluationMode: forgeRunnerExecutionIntentEvaluationMode,
    owner: request.owner,
    conversationID: request.conversationID,
    promptID: request.prompt.promptID,
    runID: request.run.runID,
    attemptID: request.binding.attemptID,
    commandID: request.binding.commandID,
    targetID: request.binding.targetID,
    commandSHA256: request.binding.commandSHA256,
    idempotencyKey: request.binding.idempotencyKey,
    promptRunBindingValid: true,
    runnerCommandBindingValid: true,
    previewOnly: true,
    selectedTargetID: null,
    authority: const ForgeRunnerExecutionIntentAuthority.offline(),
  );
}

void _validatePrompt(
  ForgeRunnerExecutionPromptReceipt prompt,
  String conversationID,
) {
  if (!_identifier(prompt.promptID) ||
      prompt.conversationID != conversationID ||
      prompt.role != 'user' ||
      prompt.acceptedAtMS < 0 ||
      prompt.acceptedAtMS > forgeRunnerExecutionIntentMaxSafeInteger ||
      !_identifier(prompt.intentID) ||
      !_identifier(prompt.initialEventID) ||
      prompt.initialEventSequence != 1 ||
      prompt.initialEventType != 'submitted') {
    throw const ForgeRunnerExecutionIntentError('invalid_prompt');
  }
}

void _validateRun(
  ForgeRunnerExecutionRunReference run,
  ForgeRunnerExecutionPromptReceipt prompt,
  String conversationID,
) {
  if (!_identifier(run.runID) ||
      run.conversationID != conversationID ||
      run.promptID != prompt.promptID ||
      run.createdAtMS < prompt.acceptedAtMS ||
      run.createdAtMS > forgeRunnerExecutionIntentMaxSafeInteger ||
      run.latestSequence < 1 ||
      run.latestSequence > forgeRunnerExecutionIntentMaxSafeInteger ||
      !_runStatus(run.status)) {
    throw const ForgeRunnerExecutionIntentError('invalid_run');
  }
}

void _validateBinding(ForgeRunnerExecutionIntentRequest request) {
  final binding = request.binding;
  final command = request.command;
  if (binding.conversationID != request.conversationID ||
      binding.promptID != request.prompt.promptID ||
      binding.runID != request.run.runID ||
      binding.selectedTargetID != null ||
      !_identifier(binding.attemptID) ||
      !_identifier(binding.commandID) ||
      !_identifier(binding.targetID) ||
      !_digest(binding.commandSHA256) ||
      binding.idempotencyKey !=
          '${request.run.runID}:${binding.attemptID}:${binding.commandID}' ||
      command.version != 1 ||
      command.commandID != binding.commandID ||
      command.leaseProof.attemptID != binding.attemptID ||
      command.leaseProof.targetID != binding.targetID ||
      command.leaseProof.epoch == 0 ||
      !_text(command.leaseProof.fencingToken, 256, trimmed: true) ||
      command.idempotencyKey != binding.idempotencyKey ||
      command.commandSHA256() != binding.commandSHA256 ||
      !_text(command.workspaceRef, 256, trimmed: true) ||
      command.argv.isEmpty ||
      command.argv.length > 64 ||
      command.timeoutMS < 1 ||
      command.timeoutMS > 600000 ||
      command.maxOutputBytes < 1 ||
      command.maxOutputBytes > 8 * 1024 * 1024 ||
      !_validArguments(command.argv)) {
    throw const ForgeRunnerExecutionIntentError('invalid_binding');
  }
}

bool _validArguments(List<String> arguments) {
  var total = 0;
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (!_text(argument, 4096, allowEmpty: index != 0) ||
        total > 65536 - argument.length) {
      return false;
    }
    total += argument.length;
  }
  return true;
}

bool _validOwner(ForgeDeviceOwner owner) =>
    _text(owner.issuer, 512, trimmed: true) &&
    _text(owner.subject, 512, trimmed: true) &&
    _text(owner.tenantID, 512, trimmed: true);

bool _text(
  String value,
  int maximum, {
  bool allowEmpty = false,
  bool trimmed = false,
}) {
  if ((!allowEmpty && value.isEmpty) ||
      value.length > maximum ||
      (trimmed && value.trim() != value)) {
    return false;
  }
  return value.codeUnits.every(
    (unit) => unit > 0x1f && !(unit >= 0x7f && unit <= 0x9f),
  );
}

bool _identifier(String value) {
  if (value.isEmpty || value.length > 128) return false;
  final codes = value.codeUnits;
  bool first(int code) =>
      (code >= 0x30 && code <= 0x39) ||
      (code >= 0x41 && code <= 0x5a) ||
      (code >= 0x61 && code <= 0x7a);
  return first(codes.first) &&
      codes
          .skip(1)
          .every(
            (code) =>
                first(code) ||
                const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
          );
}

bool _digest(String value) =>
    value.length == 64 &&
    value.codeUnits.every(
      (code) =>
          (code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66),
    );

bool _runStatus(String value) => const {
  'nonterminal',
  'completed',
  'cancelled',
  'limit_exceeded',
  'failed',
}.contains(value);

Map<String, dynamic> _runnerExecutionObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Expected Forge Runner execution $label object.');
  }
  return Map<String, dynamic>.from(value);
}

void _runnerExecutionExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge Runner execution intent fields.',
    );
  }
}

String _runnerExecutionSchema(Object? value) {
  if (value != forgeRunnerExecutionIntentSchema) {
    throw const FormatException('Invalid Forge Runner execution schema.');
  }
  return forgeRunnerExecutionIntentSchema;
}

String _runnerExecutionMode(Object? value) {
  if (value != forgeRunnerExecutionIntentEvaluationMode) {
    throw const FormatException('Invalid Forge Runner execution mode.');
  }
  return forgeRunnerExecutionIntentEvaluationMode;
}

String _runnerExecutionIdentifier(Object? value) {
  if (value is! String || !_identifier(value)) {
    throw const FormatException('Invalid Forge Runner execution identifier.');
  }
  return value;
}

String? _runnerExecutionNullableIdentifier(Object? value) {
  if (value == null) return null;
  return _runnerExecutionIdentifier(value);
}

String _runnerExecutionDigest(Object? value) {
  if (value is! String || !_digest(value)) {
    throw const FormatException('Invalid Forge Runner execution digest.');
  }
  return value;
}

String _runnerExecutionText(Object? value, int maximum) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maximum ||
      value.trim() != value ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid Forge Runner execution text.');
  }
  return value;
}

bool _runnerExecutionBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge Runner execution flag.');
  }
  return value;
}

int _runnerExecutionInteger(Object? value) {
  if (value is! int) {
    throw const FormatException('Invalid Forge Runner execution integer.');
  }
  return value;
}
