part of 'forge_runner_execution_intent.dart';

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
