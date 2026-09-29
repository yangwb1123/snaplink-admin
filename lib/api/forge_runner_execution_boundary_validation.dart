part of 'forge_runner_execution_boundary.dart';

Map<String, dynamic> _boundaryObject(Object? value, String label) {
  if (value is! Map) throw FormatException('$label must be an object.');
  return value.map((key, value) => MapEntry(key.toString(), value));
}

void _boundaryExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
  String label,
) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw FormatException('$label contains unknown or missing fields.');
  }
}

String _boundaryText(Object? value, String label) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('$label is invalid.');
  }
  return value;
}

String _boundaryIdentifier(Object? value, {int maxLength = 256}) {
  final text = _boundaryText(value, 'identifier');
  if (text.length > maxLength ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+/-]*$').hasMatch(text)) {
    throw const FormatException('Identifier is invalid.');
  }
  return text;
}

String _boundaryDigest(Object? value) {
  final text = _boundaryText(value, 'digest');
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw const FormatException('Digest is invalid.');
  }
  return text;
}

int _boundaryPositiveInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int ||
      value <= 0 ||
      value > ForgeRunnerExecutionBoundaryObservation.maxSafeInteger) {
    throw FormatException('$key is invalid.');
  }
  return value;
}

bool _boundaryBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('$key is invalid.');
  return value;
}

String _boundaryState(Object? value) {
  final state = _boundaryText(value, 'attempt_state');
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

String _boundaryEffectState(Object? value) {
  final state = _boundaryText(value, 'effect_state');
  if (!{
    'not_started',
    'started',
    'completed',
    'failed',
    'uncertain',
    'reconciled',
  }.contains(state)) {
    throw const FormatException('Effect state is invalid.');
  }
  return state;
}

String _boundaryMode(Object? value) {
  final mode = _boundaryText(value, 'mode');
  if (!{
    'off',
    'inventory',
    'observe',
    'execute',
    'migrate',
    'federate',
  }.contains(mode)) {
    throw const FormatException('Runner execution mode is invalid.');
  }
  return mode;
}

bool _boundaryStartable(String state) =>
    state == 'not_started' || state == 'reconciled';

List<String> _boundaryReasons(Object? value) {
  if (value is! List || value.any((item) => item is! String)) {
    throw const FormatException('Rejection reasons are invalid.');
  }
  final reasons = value.cast<String>().toList(growable: false);
  final sorted = [...reasons]..sort();
  if (reasons.toSet().length != reasons.length ||
      reasons.join('|') != sorted.join('|') ||
      reasons.any((reason) => !_boundaryValidIdentifier(reason))) {
    throw const FormatException('Rejection reasons are not sorted.');
  }
  return List.unmodifiable(reasons);
}

bool _boundaryValidIdentifier(String value) =>
    value.isNotEmpty &&
    value.length <= 256 &&
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+/-]*$').hasMatch(value);

ForgeRunnerExecutionCommand _boundaryCommand(Object? value) {
  final json = _boundaryObject(value, 'command');
  _boundaryExactKeys(json, {
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
    throw const FormatException('Runner command version is invalid.');
  }
  final proof = _boundaryObject(json['lease_proof'], 'lease_proof');
  _boundaryExactKeys(proof, {
    'attempt_id',
    'target_id',
    'epoch',
    'fencing_token',
  }, 'lease_proof');
  final argv = json['argv'];
  if (argv is! List || argv.isEmpty || argv.length > 64) {
    throw const FormatException('Runner command argv is invalid.');
  }
  final arguments = argv
      .map((item) => _boundaryText(item, 'argv'))
      .toList(growable: false);
  if (arguments.fold<int>(0, (sum, value) => sum + value.length) > 65536) {
    throw const FormatException('Runner command argv is too large.');
  }
  return ForgeRunnerExecutionCommand(
    version: 1,
    commandID: _boundaryIdentifier(json['command_id']),
    leaseProof: ForgeRunnerExecutionLeaseProof(
      attemptID: _boundaryIdentifier(proof['attempt_id']),
      targetID: _boundaryIdentifier(proof['target_id']),
      epoch: _boundaryPositiveInt(proof, 'epoch'),
      fencingToken: _boundaryIdentifier(proof['fencing_token'], maxLength: 256),
    ),
    idempotencyKey: _boundaryIdentifier(
      json['idempotency_key'],
      maxLength: 256,
    ),
    workspaceRef: _boundaryIdentifier(json['workspace_ref'], maxLength: 256),
    argv: arguments,
    timeoutMS: _boundaryPositiveInt(json, 'timeout_ms'),
    maxOutputBytes: _boundaryPositiveInt(json, 'max_output_bytes'),
  );
}

Map<String, dynamic> _boundaryCommandToJson(
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
