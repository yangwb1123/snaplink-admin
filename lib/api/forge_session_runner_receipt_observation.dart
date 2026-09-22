import 'forge_device_inventory_declaration.dart';
import 'forge_runner_terminal_receipt.dart';

/// Canonical metadata-only bridge between an existing session Run and a
/// Runner terminal receipt observation.
const forgeSessionRunnerReceiptObservationSchema =
    'forge.session-runner-receipt-observation/v1';
const forgeSessionRunnerReceiptObservationEvaluationMode =
    'pure_session_runner_receipt_binding_only';
const forgeSessionRunnerReceiptObservationMaxSafeInteger = 9007199254740991;

class ForgeSessionRunnerReceiptObservationAuthority {
  final bool identityVerified;
  final bool receiptPersisted;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeSessionRunnerReceiptObservationAuthority.offline()
    : identityVerified = false,
      receiptPersisted = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  const ForgeSessionRunnerReceiptObservationAuthority({
    required this.identityVerified,
    required this.receiptPersisted,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  const ForgeSessionRunnerReceiptObservationAuthority._({
    required this.identityVerified,
    required this.receiptPersisted,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeSessionRunnerReceiptObservationAuthority.fromJson(
    Object? value,
  ) {
    final json = _sessionRunnerReceiptObject(value, 'authority');
    _sessionRunnerReceiptExactKeys(json, {
      'identity_verified',
      'receipt_persisted',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeSessionRunnerReceiptObservationAuthority._(
      identityVerified: _sessionRunnerReceiptBool(json['identity_verified']),
      receiptPersisted: _sessionRunnerReceiptBool(json['receipt_persisted']),
      executionAuthorized: _sessionRunnerReceiptBool(
        json['execution_authorized'],
      ),
      dispatchPerformed: _sessionRunnerReceiptBool(json['dispatch_performed']),
      auditPublished: _sessionRunnerReceiptBool(json['audit_published']),
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Session Runner receipt observation claims authority.',
      );
    }
    return authority;
  }

  Map<String, dynamic> toJson() => {
    'identity_verified': identityVerified,
    'receipt_persisted': receiptPersisted,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };

  bool get isOffline =>
      !identityVerified &&
      !receiptPersisted &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;
}

/// Strict consumer for the session-bound Runner receipt envelope.
///
/// This object is display-only. It does not establish ownership, persist a
/// receipt, select a target, authorize execution, dispatch a process, or
/// publish audit data.
class ForgeSessionRunnerReceiptObservation {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String promptID;
  final String runID;
  final ForgeRunnerTerminalReceiptObservation receiptObservation;
  final bool promptRunBindingValid;
  final bool receiptBindingValid;
  final bool previewOnly;
  final String? selectedTargetID;
  final ForgeSessionRunnerReceiptObservationAuthority authority;

  const ForgeSessionRunnerReceiptObservation({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.promptID,
    required this.runID,
    required this.receiptObservation,
    required this.promptRunBindingValid,
    required this.receiptBindingValid,
    required this.previewOnly,
    required this.selectedTargetID,
    required this.authority,
  });

  factory ForgeSessionRunnerReceiptObservation.fromJson(Object? value) {
    final json = _sessionRunnerReceiptObject(value, 'observation');
    _sessionRunnerReceiptExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'prompt_id',
      'run_id',
      'receipt_observation',
      'prompt_run_binding_valid',
      'receipt_binding_valid',
      'preview_only',
      'selected_target_id',
      'authority',
    });
    final observation = ForgeSessionRunnerReceiptObservation(
      schemaVersion: _sessionRunnerReceiptSchema(json['schema_version']),
      evaluationMode: _sessionRunnerReceiptMode(json['evaluation_mode']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _sessionRunnerReceiptIdentifier(json['conversation_id']),
      promptID: _sessionRunnerReceiptIdentifier(json['prompt_id']),
      runID: _sessionRunnerReceiptIdentifier(json['run_id']),
      receiptObservation: ForgeRunnerTerminalReceiptObservation.fromJson(
        json['receipt_observation'],
      ),
      promptRunBindingValid: _sessionRunnerReceiptBool(
        json['prompt_run_binding_valid'],
      ),
      receiptBindingValid: _sessionRunnerReceiptBool(
        json['receipt_binding_valid'],
      ),
      previewOnly: _sessionRunnerReceiptBool(json['preview_only']),
      selectedTargetID: _sessionRunnerReceiptNullableIdentifier(
        json['selected_target_id'],
      ),
      authority: ForgeSessionRunnerReceiptObservationAuthority.fromJson(
        json['authority'],
      ),
    );
    if (!observation.isDisplayOnly) {
      throw const FormatException(
        'Session Runner receipt observation is not display-only.',
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
    'receipt_observation': receiptObservation.toJson(),
    'prompt_run_binding_valid': promptRunBindingValid,
    'receipt_binding_valid': receiptBindingValid,
    'preview_only': previewOnly,
    'selected_target_id': selectedTargetID,
    'authority': authority.toJson(),
  };

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  bool get isDisplayOnly =>
      schemaVersion == forgeSessionRunnerReceiptObservationSchema &&
      evaluationMode == forgeSessionRunnerReceiptObservationEvaluationMode &&
      promptRunBindingValid &&
      receiptBindingValid &&
      previewOnly &&
      selectedTargetID == null &&
      authority.isOffline &&
      receiptObservation.isDisplayOnly;
}

Map<String, dynamic> _sessionRunnerReceiptObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Expected session Runner receipt $label object.');
  }
  return Map<String, dynamic>.from(value);
}

void _sessionRunnerReceiptExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (!json.keys.toSet().containsAll(expected) ||
      json.keys.toSet().difference(expected).isNotEmpty) {
    throw const FormatException(
      'Unknown or missing session Runner receipt observation field.',
    );
  }
}

String _sessionRunnerReceiptSchema(Object? value) {
  if (value != forgeSessionRunnerReceiptObservationSchema) {
    throw const FormatException(
      'Invalid session Runner receipt observation schema.',
    );
  }
  return forgeSessionRunnerReceiptObservationSchema;
}

String _sessionRunnerReceiptMode(Object? value) {
  if (value != forgeSessionRunnerReceiptObservationEvaluationMode) {
    throw const FormatException(
      'Invalid session Runner receipt observation mode.',
    );
  }
  return forgeSessionRunnerReceiptObservationEvaluationMode;
}

bool _sessionRunnerReceiptBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid session Runner receipt boolean.');
  }
  return value;
}

String _sessionRunnerReceiptIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_sessionRunnerReceiptToken(value)) {
    throw const FormatException('Invalid session Runner receipt identifier.');
  }
  return value;
}

String? _sessionRunnerReceiptNullableIdentifier(Object? value) {
  if (value == null) return null;
  return _sessionRunnerReceiptIdentifier(value);
}

bool _sessionRunnerReceiptToken(String value) {
  for (var index = 0; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    final alphaNumeric =
        (code >= 0x30 && code <= 0x39) ||
        (code >= 0x41 && code <= 0x5a) ||
        (code >= 0x61 && code <= 0x7a);
    if (!alphaNumeric &&
        !(index > 0 &&
            (code == 0x2e ||
                code == 0x5f ||
                code == 0x3a ||
                code == 0x2b ||
                code == 0x2f ||
                code == 0x2d))) {
      return false;
    }
  }
  return true;
}
