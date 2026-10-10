part of 'forge_runner_transport_admission.dart';

/// Metadata-only join of a verified D3 Runner envelope with a fenced lease.
/// It never carries fencing material, argv, workspace bytes, or execution
/// authority and is intentionally separate from a live Runner transport.
class ForgeRunnerTransportAdmission {
  static const schema = 'forge.runner-transport-admission/v1';
  static const evaluationMode = 'fenced_runner_transport_admission_preview';
  static const _maxSafeInteger = 9007199254740991;
  static const _fields = {
    'schema_version',
    'evaluation_mode',
    'owner',
    'conversation_id',
    'run_id',
    'attempt_id',
    'attempt_state',
    'attempt_state_admissible',
    'command_id',
    'command_sha256',
    'target_id',
    'lease_epoch',
    'lease_issued_at_ms',
    'lease_expires_at_ms',
    'evaluated_at_ms',
    'transport_method',
    'transport_path',
    'transport_timestamp',
    'transport_nonce',
    'transport_payload_sha256',
    'transport_payload_bytes',
    'transport_replay_checked',
    'lease_proof_current',
    'lease_active',
    'command_binding_valid',
    'transport_binding_valid',
    'admission_ready',
    'rejection_reasons',
    'preview_only',
    'authority',
  };
  static const _authorityFields = {
    'device_identity_verified',
    'transport_authenticated',
    'reservation_created',
    'execution_authorized',
    'dispatch_performed',
    'audit_published',
  };

  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String attemptState;
  final bool attemptStateAdmissible;
  final String commandID;
  final String commandSHA256;
  final String targetID;
  final int leaseEpoch;
  final int leaseIssuedAtMS;
  final int leaseExpiresAtMS;
  final int evaluatedAtMS;
  final String transportMethod;
  final String transportPath;
  final int transportTimestamp;
  final String transportNonce;
  final String transportPayloadSHA256;
  final int transportPayloadBytes;
  final bool transportReplayChecked;
  final bool leaseProofCurrent;
  final bool leaseActive;
  final bool commandBindingValid;
  final bool transportBindingValid;
  final bool admissionReady;
  final List<String> rejectionReasons;
  final bool previewOnly;
  final Map<String, bool> authority;

  const ForgeRunnerTransportAdmission({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.attemptState,
    required this.attemptStateAdmissible,
    required this.commandID,
    required this.commandSHA256,
    required this.targetID,
    required this.leaseEpoch,
    required this.leaseIssuedAtMS,
    required this.leaseExpiresAtMS,
    required this.evaluatedAtMS,
    required this.transportMethod,
    required this.transportPath,
    required this.transportTimestamp,
    required this.transportNonce,
    required this.transportPayloadSHA256,
    required this.transportPayloadBytes,
    required this.transportReplayChecked,
    required this.leaseProofCurrent,
    required this.leaseActive,
    required this.commandBindingValid,
    required this.transportBindingValid,
    required this.admissionReady,
    required this.rejectionReasons,
    required this.previewOnly,
    required this.authority,
  });

  factory ForgeRunnerTransportAdmission.fromJsonText(String source) {
    rejectDuplicateForgeJsonKeys(source);
    return ForgeRunnerTransportAdmission.fromJson(jsonDecode(source));
  }

  factory ForgeRunnerTransportAdmission.fromJson(Object? value) {
    final json = _object(value, 'Runner transport admission');
    _exactKeys(json, _fields, 'Runner transport admission');
    if (json['schema_version'] != schema ||
        json['evaluation_mode'] != evaluationMode ||
        json['preview_only'] != true) {
      throw const FormatException(
        'Invalid Runner transport admission envelope.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final attemptState = _state(json['attempt_state']);
    final attemptStateAdmissible = _bool(json, 'attempt_state_admissible');
    final commandBindingValid = _bool(json, 'command_binding_valid');
    final leaseProofCurrent = _bool(json, 'lease_proof_current');
    final leaseActive = _bool(json, 'lease_active');
    final transportBindingValid = _bool(json, 'transport_binding_valid');
    final admissionReady = _bool(json, 'admission_ready');
    final reasons = _reasons(json['rejection_reasons']);
    final targetID = _identifier(json['target_id']);
    final result = ForgeRunnerTransportAdmission(
      owner: owner,
      conversationID: _identifier(json['conversation_id']),
      runID: _identifier(json['run_id']),
      attemptID: _identifier(json['attempt_id']),
      attemptState: attemptState,
      attemptStateAdmissible: attemptStateAdmissible,
      commandID: _identifier(json['command_id']),
      commandSHA256: _digest(json['command_sha256']),
      targetID: targetID,
      leaseEpoch: _positiveInt(json, 'lease_epoch'),
      leaseIssuedAtMS: _positiveInt(json, 'lease_issued_at_ms'),
      leaseExpiresAtMS: _positiveInt(json, 'lease_expires_at_ms'),
      evaluatedAtMS: _positiveInt(json, 'evaluated_at_ms'),
      transportMethod: _text(json['transport_method'], 'transport_method'),
      transportPath: _text(json['transport_path'], 'transport_path'),
      transportTimestamp: _positiveInt(json, 'transport_timestamp'),
      transportNonce: _text(json['transport_nonce'], 'transport_nonce'),
      transportPayloadSHA256: _digest(json['transport_payload_sha256']),
      transportPayloadBytes: _boundedInt(
        json,
        'transport_payload_bytes',
        1 << 20,
      ),
      transportReplayChecked: _bool(json, 'transport_replay_checked'),
      leaseProofCurrent: leaseProofCurrent,
      leaseActive: leaseActive,
      commandBindingValid: commandBindingValid,
      transportBindingValid: transportBindingValid,
      admissionReady: admissionReady,
      rejectionReasons: reasons,
      previewOnly: true,
      authority: _authority(json['authority']),
    );
    final expectedReasons = _expectedReasons(
      commandBindingValid,
      leaseProofCurrent,
      leaseActive,
      attemptStateAdmissible,
      transportBindingValid,
    );
    if (result.attemptStateAdmissible != _dispatchable(attemptState) ||
        result.leaseExpiresAtMS <= result.leaseIssuedAtMS ||
        result.evaluatedAtMS > _maxSafeInteger ||
        result.transportTimestamp <= 0 ||
        result.transportMethod != 'POST' ||
        result.transportPath != '/api/v1/runners/$targetID/dispatch' ||
        result.admissionReady !=
            (commandBindingValid &&
                leaseProofCurrent &&
                leaseActive &&
                attemptStateAdmissible &&
                transportBindingValid) ||
        reasons.join('|') != expectedReasons.join('|') ||
        result.admissionReady && reasons.isNotEmpty) {
      throw const FormatException(
        'Invalid Runner transport admission binding.',
      );
    }
    return result;
  }

  bool get isDisplayOnly =>
      previewOnly && authority.values.every((value) => !value);

  bool isFor(String conversationID, String runID, String attemptID) =>
      this.conversationID == conversationID &&
      this.runID == runID &&
      this.attemptID == attemptID;

  Map<String, dynamic> toJson() => {
    'schema_version': schema,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'attempt_state': attemptState,
    'attempt_state_admissible': attemptStateAdmissible,
    'command_id': commandID,
    'command_sha256': commandSHA256,
    'target_id': targetID,
    'lease_epoch': leaseEpoch,
    'lease_issued_at_ms': leaseIssuedAtMS,
    'lease_expires_at_ms': leaseExpiresAtMS,
    'evaluated_at_ms': evaluatedAtMS,
    'transport_method': transportMethod,
    'transport_path': transportPath,
    'transport_timestamp': transportTimestamp,
    'transport_nonce': transportNonce,
    'transport_payload_sha256': transportPayloadSHA256,
    'transport_payload_bytes': transportPayloadBytes,
    'transport_replay_checked': transportReplayChecked,
    'lease_proof_current': leaseProofCurrent,
    'lease_active': leaseActive,
    'command_binding_valid': commandBindingValid,
    'transport_binding_valid': transportBindingValid,
    'admission_ready': admissionReady,
    'rejection_reasons': rejectionReasons,
    'preview_only': previewOnly,
    'authority': authority,
  };

  static Map<String, bool> _authority(Object? value) {
    final json = _object(value, 'authority');
    _exactKeys(json, _authorityFields, 'authority');
    final authority = <String, bool>{};
    for (final key in _authorityFields) {
      if (json[key] != false) {
        throw FormatException('authority.$key must be false');
      }
      authority[key] = false;
    }
    return Map.unmodifiable(authority);
  }

  static List<String> _expectedReasons(
    bool commandBindingValid,
    bool leaseCurrent,
    bool leaseActive,
    bool attemptStateAdmissible,
    bool transportBindingValid,
  ) {
    final reasons = <String>[];
    if (!commandBindingValid) reasons.add('command_binding_invalid');
    if (!leaseCurrent) reasons.add('lease_proof_not_current');
    if (!leaseActive) reasons.add('lease_inactive_at_evaluated_time');
    if (!attemptStateAdmissible) reasons.add('attempt_state_not_dispatchable');
    if (!transportBindingValid) reasons.add('transport_binding_invalid');
    reasons.sort();
    return reasons;
  }
}
