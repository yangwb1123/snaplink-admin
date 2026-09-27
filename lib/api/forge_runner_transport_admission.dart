import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';
import 'forge_runner_execution_intent.dart';

/// Caller-supplied value-only request for the authenticated transport
/// admission preview. The transport observation is expected to have been
/// verified by a separately reviewed D3 adapter; this request itself never
/// opens a Runner connection or sends payload bytes.
class ForgeRunnerTransportAdmissionRequest {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String attemptState;
  final ForgeRunnerExecutionCommand command;
  final ForgeRunnerTransportLease lease;
  final ForgeRunnerTransportObservation transport;
  final String expectedPayloadSHA256;
  final int evaluatedAtMS;

  const ForgeRunnerTransportAdmissionRequest({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.attemptState,
    required this.command,
    required this.lease,
    required this.transport,
    required this.expectedPayloadSHA256,
    required this.evaluatedAtMS,
  });

  factory ForgeRunnerTransportAdmissionRequest.fromJson(Object? value) {
    final json = _object(value, 'Runner transport admission request');
    _exactKeys(json, {
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'attempt_state',
      'command',
      'lease',
      'transport',
      'expected_payload_sha256',
      'evaluated_at_ms',
    }, 'Runner transport admission request');
    final conversationID = _identifier(json['conversation_id']);
    final runID = _identifier(json['run_id']);
    final attemptID = _identifier(json['attempt_id']);
    final command = _transportCommand(json['command']);
    if (command.leaseProof.attemptID != attemptID) {
      throw const FormatException(
        'Runner transport admission proof is not bound to the Attempt.',
      );
    }
    final transport = ForgeRunnerTransportObservation.fromJson(
      json['transport'],
    );
    final expectedPayloadSHA256 = _digest(json['expected_payload_sha256']);
    final evaluatedAtMS = _positiveInt(json, 'evaluated_at_ms');
    return ForgeRunnerTransportAdmissionRequest(
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: conversationID,
      runID: runID,
      attemptID: attemptID,
      attemptState: _state(json['attempt_state']),
      command: command,
      lease: ForgeRunnerTransportLease.fromJson(json['lease']),
      transport: transport,
      expectedPayloadSHA256: expectedPayloadSHA256,
      evaluatedAtMS: evaluatedAtMS,
    );
  }

  Map<String, dynamic> toJson() => {
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'attempt_state': attemptState,
    'command': _transportCommandToJson(command),
    'lease': lease.toJson(),
    'transport': transport.toJson(),
    'expected_payload_sha256': expectedPayloadSHA256,
    'evaluated_at_ms': evaluatedAtMS,
  };
}

class ForgeRunnerTransportLease {
  final String targetID;
  final int epoch;
  final int issuedAtMS;
  final int expiresAtMS;
  final bool current;
  final bool active;

  const ForgeRunnerTransportLease({
    required this.targetID,
    required this.epoch,
    required this.issuedAtMS,
    required this.expiresAtMS,
    required this.current,
    required this.active,
  });

  factory ForgeRunnerTransportLease.fromJson(Object? value) {
    final json = _object(value, 'Runner transport admission lease');
    _exactKeys(json, {
      'target_id',
      'epoch',
      'issued_at_ms',
      'expires_at_ms',
      'current',
      'active',
    }, 'Runner transport admission lease');
    final issuedAtMS = _positiveInt(json, 'issued_at_ms');
    final expiresAtMS = _positiveInt(json, 'expires_at_ms');
    if (expiresAtMS <= issuedAtMS) {
      throw const FormatException(
        'Runner transport admission lease window is invalid.',
      );
    }
    return ForgeRunnerTransportLease(
      targetID: _identifier(json['target_id']),
      epoch: _positiveInt(json, 'epoch'),
      issuedAtMS: issuedAtMS,
      expiresAtMS: expiresAtMS,
      current: _bool(json, 'current'),
      active: _bool(json, 'active'),
    );
  }

  Map<String, dynamic> toJson() => {
    'target_id': targetID,
    'epoch': epoch,
    'issued_at_ms': issuedAtMS,
    'expires_at_ms': expiresAtMS,
    'current': current,
    'active': active,
  };
}

class ForgeRunnerTransportObservation {
  static const schema = 'forge.runner-transport-admission/v1';
  static const evaluationMode = 'pure_runner_transport_admission';

  final String method;
  final String path;
  final int timestamp;
  final String nonce;
  final String payloadSHA256;
  final int payloadBytes;
  final bool replayChecked;

  const ForgeRunnerTransportObservation({
    required this.method,
    required this.path,
    required this.timestamp,
    required this.nonce,
    required this.payloadSHA256,
    required this.payloadBytes,
    required this.replayChecked,
  });

  factory ForgeRunnerTransportObservation.fromJson(Object? value) {
    final json = _object(value, 'Runner transport observation');
    _exactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'method',
      'path',
      'timestamp',
      'nonce',
      'payload_sha256',
      'payload_bytes',
      'replay_checked',
      'preview_only',
      'authority',
    }, 'Runner transport observation');
    if (json['schema_version'] != schema ||
        json['evaluation_mode'] != evaluationMode ||
        json['method'] != 'POST' ||
        json['preview_only'] != true) {
      throw const FormatException('Invalid Runner transport observation.');
    }
    final authority = _object(json['authority'], 'Runner transport authority');
    _exactKeys(authority, {
      'identity_verified',
      'heartbeat_accepted',
      'lease_issued',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    }, 'Runner transport authority');
    if (authority.values.any((value) => value != false)) {
      throw const FormatException(
        'Runner transport observation claims authority.',
      );
    }
    final timestamp = _positiveInt(json, 'timestamp');
    final payloadBytes = _boundedInt(json, 'payload_bytes', 1 << 20);
    if (_text(json['path'], 'path').length > 2048 ||
        _text(json['nonce'], 'nonce').length > 128 ||
        _bool(json, 'replay_checked') != true) {
      throw const FormatException(
        'Runner transport observation bounds are invalid.',
      );
    }
    return ForgeRunnerTransportObservation(
      method: 'POST',
      path: _text(json['path'], 'path'),
      timestamp: timestamp,
      nonce: _text(json['nonce'], 'nonce'),
      payloadSHA256: _digest(json['payload_sha256']),
      payloadBytes: payloadBytes,
      replayChecked: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schema,
    'evaluation_mode': evaluationMode,
    'method': method,
    'path': path,
    'timestamp': timestamp,
    'nonce': nonce,
    'payload_sha256': payloadSHA256,
    'payload_bytes': payloadBytes,
    'replay_checked': replayChecked,
    'preview_only': true,
    'authority': {
      'identity_verified': false,
      'heartbeat_accepted': false,
      'lease_issued': false,
      'reservation_created': false,
      'execution_authorized': false,
      'dispatch_performed': false,
      'audit_published': false,
    },
  };
}

Map<String, dynamic> _transportCommandToJson(
  ForgeRunnerExecutionCommand command,
) => {
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
};

ForgeRunnerExecutionCommand _transportCommand(Object? value) {
  final json = _object(value, 'command');
  _exactKeys(json, {
    'v',
    'command_id',
    'lease_proof',
    'idempotency_key',
    'workspace_ref',
    'argv',
    'timeout_ms',
    'max_output_bytes',
  }, 'command');
  if (json['v'] != 1) {
    throw const FormatException('Runner transport command version is invalid.');
  }
  final proof = _object(json['lease_proof'], 'lease_proof');
  _exactKeys(proof, {
    'attempt_id',
    'target_id',
    'epoch',
    'fencing_token',
  }, 'lease_proof');
  final argv = json['argv'];
  if (argv is! List || argv.isEmpty || argv.length > 64) {
    throw const FormatException('Runner transport command argv is invalid.');
  }
  final arguments = argv
      .map((item) => _text(item, 'argv'))
      .toList(growable: false);
  if (arguments.fold<int>(0, (sum, value) => sum + value.length) > 65536) {
    throw const FormatException('Runner transport command argv is too large.');
  }
  return ForgeRunnerExecutionCommand(
    version: 1,
    commandID: _identifier(json['command_id']),
    leaseProof: ForgeRunnerExecutionLeaseProof(
      attemptID: _identifier(proof['attempt_id']),
      targetID: _identifier(proof['target_id']),
      epoch: _positiveInt(proof, 'epoch'),
      fencingToken: _identifier(proof['fencing_token'], maxLength: 256),
    ),
    idempotencyKey: _identifier(json['idempotency_key'], maxLength: 256),
    workspaceRef: _identifier(json['workspace_ref'], maxLength: 256),
    argv: arguments,
    timeoutMS: _positiveInt(json, 'timeout_ms'),
    maxOutputBytes: _boundedInt(json, 'max_output_bytes', 8 * 1024 * 1024),
  );
}

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

Map<String, dynamic> _object(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected, String label) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw FormatException('$label contains unknown or missing fields.');
  }
}

String _text(Object? value, String label) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$label is invalid.');
  }
  return value;
}

String _identifier(Object? value, {int maxLength = 128}) {
  final text = _text(value, 'identifier');
  if (text.length > maxLength ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+/-]*$').hasMatch(text)) {
    throw const FormatException('Identifier is invalid.');
  }
  return text;
}

String _digest(Object? value) {
  final text = _text(value, 'digest');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw const FormatException('Digest is invalid.');
  }
  return text;
}

int _positiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int ||
      value <= 0 ||
      value > ForgeRunnerTransportAdmission._maxSafeInteger) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

int _boundedInt(Map<String, dynamic> json, String key, int max) {
  final value = json[key];
  if (value is! int || value <= 0 || value > max) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

bool _bool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is invalid.');
  return value;
}

String _state(Object? value) {
  final state = _text(value, 'attempt_state');
  if (!{
    'requested',
    'accepted',
    'starting',
    'running',
    'interrupted',
    'completed',
    'failed',
    'uncertain',
  }.contains(state)) {
    throw const FormatException('Attempt state is invalid.');
  }
  return state;
}

bool _dispatchable(String state) =>
    {'accepted', 'starting', 'running'}.contains(state);

List<String> _reasons(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Rejection reasons are invalid.');
  }
  final reasons = value.cast<String>().toList(growable: false);
  final sorted = [...reasons]..sort();
  if (reasons.toSet().length != reasons.length ||
      reasons.join('|') != sorted.join('|')) {
    throw const FormatException('Rejection reasons are not sorted.');
  }
  return List.unmodifiable(reasons);
}
