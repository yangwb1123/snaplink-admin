import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_json_strict.dart';
import 'forge_runner_execution_intent.dart';

part 'forge_runner_transport_admission_observation.dart';
part 'forge_runner_transport_admission_validation.dart';

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
