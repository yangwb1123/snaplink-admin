import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;

import 'forge_device_inventory_declaration.dart';

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
}

class ForgeRunnerExecutionIntentAuthority {
  final bool deviceIdentityVerified;
  final bool commandPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeRunnerExecutionIntentAuthority.offline()
    : deviceIdentityVerified = false,
      commandPersisted = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  factory ForgeRunnerExecutionIntentAuthority.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'authority');
    _runnerExecutionExactKeys(json, {
      'device_identity_verified',
      'command_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    for (final key in json.keys) {
      if (json[key] is! bool || json[key] == true) {
        throw const FormatException(
          'Forge Runner execution intent claims authority.',
        );
      }
    }
    return const ForgeRunnerExecutionIntentAuthority.offline();
  }

  Map<String, dynamic> toJson() => {
    'device_identity_verified': deviceIdentityVerified,
    'command_persisted': commandPersisted,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };

  bool get isOffline =>
      !deviceIdentityVerified &&
      !commandPersisted &&
      !reservationCreated &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;
}

class ForgeRunnerExecutionIntentObservation {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String promptID;
  final String runID;
  final String attemptID;
  final String commandID;
  final String targetID;
  final String commandSHA256;
  final String idempotencyKey;
  final bool promptRunBindingValid;
  final bool runnerCommandBindingValid;
  final bool previewOnly;
  final String? selectedTargetID;
  final ForgeRunnerExecutionIntentAuthority authority;

  const ForgeRunnerExecutionIntentObservation({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.promptID,
    required this.runID,
    required this.attemptID,
    required this.commandID,
    required this.targetID,
    required this.commandSHA256,
    required this.idempotencyKey,
    required this.promptRunBindingValid,
    required this.runnerCommandBindingValid,
    required this.previewOnly,
    required this.selectedTargetID,
    required this.authority,
  });

  /// Consumes the canonical metadata-only observation emitted by the Go/Rust
  /// pure binding consumers. The envelope contains no argv or output and is
  /// accepted only while it remains a display-only preview.
  factory ForgeRunnerExecutionIntentObservation.fromJson(Object? value) {
    final json = _runnerExecutionObject(value, 'observation');
    _runnerExecutionExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'prompt_id',
      'run_id',
      'attempt_id',
      'command_id',
      'target_id',
      'command_sha256',
      'idempotency_key',
      'prompt_run_binding_valid',
      'runner_command_binding_valid',
      'preview_only',
      'selected_target_id',
      'authority',
    });
    final observation = ForgeRunnerExecutionIntentObservation(
      schemaVersion: _runnerExecutionSchema(json['schema_version']),
      evaluationMode: _runnerExecutionMode(json['evaluation_mode']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _runnerExecutionIdentifier(json['conversation_id']),
      promptID: _runnerExecutionIdentifier(json['prompt_id']),
      runID: _runnerExecutionIdentifier(json['run_id']),
      attemptID: _runnerExecutionIdentifier(json['attempt_id']),
      commandID: _runnerExecutionIdentifier(json['command_id']),
      targetID: _runnerExecutionIdentifier(json['target_id']),
      commandSHA256: _runnerExecutionDigest(json['command_sha256']),
      idempotencyKey: _runnerExecutionText(json['idempotency_key'], 256),
      promptRunBindingValid: _runnerExecutionBool(
        json['prompt_run_binding_valid'],
      ),
      runnerCommandBindingValid: _runnerExecutionBool(
        json['runner_command_binding_valid'],
      ),
      previewOnly: _runnerExecutionBool(json['preview_only']),
      selectedTargetID: _runnerExecutionNullableIdentifier(
        json['selected_target_id'],
      ),
      authority: ForgeRunnerExecutionIntentAuthority.fromJson(
        json['authority'],
      ),
    );
    if (!observation.isDisplayOnly) {
      throw const FormatException(
        'Forge Runner execution intent is not display-only.',
      );
    }
    return observation;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'prompt_id': promptID,
    'run_id': runID,
    'attempt_id': attemptID,
    'command_id': commandID,
    'target_id': targetID,
    'command_sha256': commandSHA256,
    'idempotency_key': idempotencyKey,
    'prompt_run_binding_valid': promptRunBindingValid,
    'runner_command_binding_valid': runnerCommandBindingValid,
    'preview_only': previewOnly,
    'selected_target_id': selectedTargetID,
    'authority': authority.toJson(),
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  bool get isDisplayOnly =>
      schemaVersion == forgeRunnerExecutionIntentSchema &&
      evaluationMode == forgeRunnerExecutionIntentEvaluationMode &&
      promptRunBindingValid &&
      runnerCommandBindingValid &&
      previewOnly &&
      selectedTargetID == null &&
      idempotencyKey == '$runID:$attemptID:$commandID' &&
      authority.isOffline;
}

class ForgeRunnerExecutionIntentError implements Exception {
  final String code;

  const ForgeRunnerExecutionIntentError(this.code);
}

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
