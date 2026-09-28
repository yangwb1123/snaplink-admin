import 'dart:convert';

import 'forge_runner_execution_intent.dart';
import 'forge_runner_terminal_receipt.dart';
import 'forge_session_runner_receipt_observation.dart';

part 'forge_local_runner_preview_wire.dart';

/// Wire schema for the explicitly injected, test-only local Runner preview.
///
/// The preview is a metadata-only binding check. It does not select a device,
/// reserve capacity, persist a Run or receipt, or grant execution authority.
const forgeLocalRunnerPreviewSchema = 'forge.runner-local-execution-preview/v1';
const forgeLocalRunnerPreviewEvaluationMode =
    'injected_local_runner_preview_only';
const forgeLocalRunnerPreviewMaxSafeInteger = 9007199254740991;

/// The request sent to the private local Runner preview candidate.
///
/// [intent] is an already accepted Prompt/Run/command declaration. [grant] is
/// a caller supplied lease observation; this model never issues, renews, or
/// adopts it. [observedAtMS] is explicit so the consumer never reads a clock
/// while validating the test-only seam.
class ForgeLocalRunnerPreviewRequest {
  final ForgeRunnerExecutionIntentRequest intent;
  final ForgeRunnerTerminalReceiptGrant grant;
  final int observedAtMS;

  const ForgeLocalRunnerPreviewRequest({
    required this.intent,
    required this.grant,
    required this.observedAtMS,
  });

  /// Serializes exactly the request envelope accepted by Forge Core.
  ///
  /// The command argv and workspace are caller supplied test input. They are
  /// sent only to the explicitly injected candidate and are never included in
  /// the response or human-facing observation.
  Map<String, dynamic> toJson() => {
    'intent': _intentRequestJson(intent),
    'grant': {
      'v': grant.version,
      'attempt_id': grant.attemptID,
      'target_id': grant.targetID,
      'epoch': grant.epoch,
      'fencing_token': grant.fencingToken,
      'issued_at_ms': grant.issuedAtMS,
      'expires_at_ms': grant.expiresAtMS,
    },
    'observed_at_ms': observedAtMS,
  };

  /// Validates the request before any network call and binds both URL
  /// segments to the request's existing Conversation and Prompt intent.
  void validateForPath(String conversationID, String intentID) {
    if (!_previewIdentifier(conversationID) ||
        !_previewIdentifier(intentID) ||
        intent.conversationID != conversationID ||
        intent.prompt.intentID != intentID ||
        observedAtMS <= 0 ||
        observedAtMS > forgeLocalRunnerPreviewMaxSafeInteger) {
      throw const FormatException(
        'Local Runner preview request does not match its URL path.',
      );
    }
    final expected = observeForgeRunnerExecutionIntent(intent);
    if (expected.conversationID != conversationID ||
        expected.promptID != intent.prompt.promptID ||
        expected.runID != intent.run.runID ||
        expected.commandID != intent.binding.commandID ||
        expected.attemptID != intent.binding.attemptID ||
        expected.targetID != intent.binding.targetID ||
        expected.commandSHA256 != intent.binding.commandSHA256) {
      throw const FormatException('Invalid local Runner preview intent.');
    }

    // Reuse the existing terminal receipt domain validator to check the
    // supplied grant, proof, and observation window without producing or
    // persisting a receipt. The synthetic failed disposition is local-only
    // validation input and never crosses the wire.
    observeForgeRunnerTerminalReceipt(
      ForgeRunnerTerminalReceiptRequest(
        command: intent.command,
        grant: grant,
        receipt: ForgeRunnerTerminalReceipt(
          version: forgeRunnerTerminalReceiptABI,
          commandID: intent.command.commandID,
          commandSHA256: intent.command.commandSHA256(),
          proof: intent.command.leaseProof,
          disposition: const ForgeRunnerTerminalReceiptDisposition.failed(
            'preview_request_validation',
          ),
          observedAtMS: observedAtMS,
        ),
      ),
    );
  }
}

/// Metadata-only response from the injected local Runner preview candidate.
///
/// Parsing is strict and rechecks the owner, Conversation, intent, Prompt,
/// Run, command, lease identity, receipt identity, and all authority flags
/// against the request that produced the response.
class ForgeLocalRunnerPreviewObservation {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeRunnerExecutionIntentObservation runnerExecutionIntent;
  final ForgeSessionRunnerReceiptObservation sessionRunnerReceipt;
  final String commandID;
  final String attemptID;
  final String targetID;
  final String commandSHA256;
  final String dispositionKind;
  final int observedAtMS;
  final int outputBytes;
  final int exitCode;
  final bool executorInvoked;
  final bool previewOnly;
  final ForgeRunnerExecutionIntentAuthority authority;

  const ForgeLocalRunnerPreviewObservation({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.runnerExecutionIntent,
    required this.sessionRunnerReceipt,
    required this.commandID,
    required this.attemptID,
    required this.targetID,
    required this.commandSHA256,
    required this.dispositionKind,
    required this.observedAtMS,
    required this.outputBytes,
    required this.exitCode,
    required this.executorInvoked,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgeLocalRunnerPreviewObservation.fromJson(
    Object? value, {
    required ForgeLocalRunnerPreviewRequest request,
    required String conversationID,
    required String intentID,
  }) {
    request.validateForPath(conversationID, intentID);
    final json = _localRunnerPreviewObject(value, 'observation');
    _localRunnerPreviewExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'runner_execution_intent',
      'session_runner_receipt',
      'command_id',
      'attempt_id',
      'target_id',
      'command_sha256',
      'disposition_kind',
      'observed_at_ms',
      'output_bytes',
      'exit_code',
      'executor_invoked',
      'preview_only',
      'authority',
    });
    final intent = ForgeRunnerExecutionIntentObservation.fromJson(
      json['runner_execution_intent'],
    );
    final session = ForgeSessionRunnerReceiptObservation.fromJson(
      json['session_runner_receipt'],
    );
    final observation = ForgeLocalRunnerPreviewObservation(
      schemaVersion: _localRunnerPreviewSchema(json['schema_version']),
      evaluationMode: _localRunnerPreviewMode(json['evaluation_mode']),
      runnerExecutionIntent: intent,
      sessionRunnerReceipt: session,
      commandID: _localRunnerPreviewIdentifier(json['command_id']),
      attemptID: _localRunnerPreviewIdentifier(json['attempt_id']),
      targetID: _localRunnerPreviewIdentifier(json['target_id']),
      commandSHA256: _localRunnerPreviewDigest(json['command_sha256']),
      dispositionKind: _localRunnerPreviewText(json['disposition_kind']),
      observedAtMS: _localRunnerPreviewInteger(json['observed_at_ms']),
      outputBytes: _localRunnerPreviewInteger(json['output_bytes']),
      exitCode: _localRunnerPreviewInteger(json['exit_code']),
      executorInvoked: _localRunnerPreviewBool(json['executor_invoked']),
      previewOnly: _localRunnerPreviewBool(json['preview_only']),
      authority: ForgeRunnerExecutionIntentAuthority.fromJson(
        json['authority'],
      ),
    );
    observation._validateBinding(request, conversationID, intentID);
    return observation;
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'runner_execution_intent': runnerExecutionIntent.toJson(),
    'session_runner_receipt': sessionRunnerReceipt.toJson(),
    'command_id': commandID,
    'attempt_id': attemptID,
    'target_id': targetID,
    'command_sha256': commandSHA256,
    'disposition_kind': dispositionKind,
    'observed_at_ms': observedAtMS,
    'output_bytes': outputBytes,
    'exit_code': exitCode,
    'executor_invoked': executorInvoked,
    'preview_only': previewOnly,
    'authority': authority.toJson(),
  };

  void _validateBinding(
    ForgeLocalRunnerPreviewRequest request,
    String conversationID,
    String intentID,
  ) {
    final expected = observeForgeRunnerExecutionIntent(request.intent);
    if (schemaVersion != forgeLocalRunnerPreviewSchema ||
        evaluationMode != forgeLocalRunnerPreviewEvaluationMode ||
        !executorInvoked ||
        !previewOnly ||
        !authority.isOffline ||
        observedAtMS != request.observedAtMS ||
        observedAtMS <= 0 ||
        observedAtMS > forgeLocalRunnerPreviewMaxSafeInteger ||
        outputBytes < 0 ||
        outputBytes > forgeLocalRunnerPreviewMaxSafeInteger ||
        exitCode.abs() > forgeLocalRunnerPreviewMaxSafeInteger ||
        !_sameIntent(runnerExecutionIntent, expected) ||
        runnerExecutionIntent.conversationID != conversationID ||
        request.intent.prompt.intentID != intentID ||
        sessionRunnerReceipt.owner != request.intent.owner ||
        sessionRunnerReceipt.conversationID != conversationID ||
        sessionRunnerReceipt.promptID != request.intent.prompt.promptID ||
        sessionRunnerReceipt.runID != request.intent.run.runID ||
        commandID != expected.commandID ||
        attemptID != expected.attemptID ||
        targetID != expected.targetID ||
        commandSHA256 != expected.commandSHA256) {
      throw const FormatException(
        'Forge returned a local Runner preview with a different binding.',
      );
    }

    final receipt = sessionRunnerReceipt.receiptObservation;
    if (receipt.commandID != commandID ||
        receipt.attemptID != attemptID ||
        receipt.targetID != targetID ||
        receipt.commandSHA256 != commandSHA256 ||
        receipt.dispositionKind != dispositionKind ||
        receipt.observedAtMS != observedAtMS) {
      throw const FormatException(
        'Forge returned a local Runner preview with a different receipt.',
      );
    }
  }
}

Map<String, dynamic> _localRunnerPreviewObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException('Expected local Runner preview $label object.');
  }
  return Map<String, dynamic>.from(value);
}

void _localRunnerPreviewExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.toSet().difference(expected).isNotEmpty) {
    throw const FormatException(
      'Unknown or missing local Runner preview observation field.',
    );
  }
}

String _localRunnerPreviewSchema(Object? value) {
  if (value != forgeLocalRunnerPreviewSchema) {
    throw const FormatException('Invalid local Runner preview schema.');
  }
  return forgeLocalRunnerPreviewSchema;
}

String _localRunnerPreviewMode(Object? value) {
  if (value != forgeLocalRunnerPreviewEvaluationMode) {
    throw const FormatException('Invalid local Runner preview mode.');
  }
  return forgeLocalRunnerPreviewEvaluationMode;
}

String _localRunnerPreviewText(Object? value) {
  if (value is! String || value.isEmpty || value.length > 256) {
    throw const FormatException('Invalid local Runner preview text.');
  }
  return value;
}

String _localRunnerPreviewIdentifier(Object? value) {
  final text = _localRunnerPreviewText(value);
  if (!_previewIdentifier(text)) {
    throw const FormatException('Invalid local Runner preview identifier.');
  }
  return text;
}

String _localRunnerPreviewDigest(Object? value) {
  if (value is! String ||
      value.length != 64 ||
      value.codeUnits.any(
        (code) =>
            !((code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66)),
      )) {
    throw const FormatException('Invalid local Runner preview digest.');
  }
  return value;
}

int _localRunnerPreviewInteger(Object? value) {
  if (value is! int ||
      value < -forgeLocalRunnerPreviewMaxSafeInteger ||
      value > forgeLocalRunnerPreviewMaxSafeInteger) {
    throw const FormatException('Invalid local Runner preview integer.');
  }
  return value;
}

bool _localRunnerPreviewBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid local Runner preview boolean.');
  }
  return value;
}

bool _previewIdentifier(String value) {
  if (value.isEmpty || value.length > 128) return false;
  for (var index = 0; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    final alphaNumeric =
        (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5a) ||
        (code >= 0x61 && code <= 0x7a);
    if (!alphaNumeric &&
        !(index > 0 &&
            const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code))) {
      return false;
    }
  }
  return true;
}
