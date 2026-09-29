part of 'forge_runner_dispatch_admission.dart';

ForgeRunnerExecutionCommand _admissionCommand(Object? value) {
  final json = _admissionObject(value, 'command');
  _admissionExactKeys(json, {
    'v',
    'command_id',
    'lease_proof',
    'idempotency_key',
    'workspace_ref',
    'argv',
    'timeout_ms',
    'max_output_bytes',
  });
  final proof = _admissionObject(json['lease_proof'], 'lease_proof');
  _admissionExactKeys(proof, {
    'attempt_id',
    'target_id',
    'epoch',
    'fencing_token',
  });
  final argvValue = json['argv'];
  if (argvValue is! List || argvValue.isEmpty || argvValue.length > 64) {
    throw const FormatException('Invalid Runner dispatch admission argv.');
  }
  final argv = argvValue.map(_admissionText).toList(growable: false);
  if (argv.fold<int>(0, (sum, value) => sum + value.length) > 65536) {
    throw const FormatException('Runner dispatch admission argv is too large.');
  }
  return ForgeRunnerExecutionCommand(
    version: _admissionInt(json['v'], 'v') == 1
        ? 1
        : (throw const FormatException(
            'Invalid Runner dispatch admission version.',
          )),
    commandID: _admissionIdentifier(json['command_id']),
    leaseProof: ForgeRunnerExecutionLeaseProof(
      attemptID: _admissionIdentifier(proof['attempt_id']),
      targetID: _admissionIdentifier(proof['target_id']),
      epoch: _admissionPositiveInt(proof['epoch']),
      fencingToken: _admissionIdentifier(
        proof['fencing_token'],
        maxLength: 256,
      ),
    ),
    idempotencyKey: _admissionIdentifier(
      json['idempotency_key'],
      maxLength: 256,
    ),
    workspaceRef: _admissionIdentifier(json['workspace_ref'], maxLength: 256),
    argv: argv,
    timeoutMS: _admissionBoundedPositiveInt(json['timeout_ms'], 600000),
    maxOutputBytes: _admissionBoundedPositiveInt(
      json['max_output_bytes'],
      8 * 1024 * 1024,
    ),
  );
}

Map<String, dynamic> _admissionObject(Object? value, String label) {
  if (value is! Map) throw FormatException('Invalid $label.');
  return Map<String, dynamic>.from(value);
}

void _admissionExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length ||
      !value.keys.toSet().containsAll(expected)) {
    throw const FormatException(
      'Unknown or missing Runner dispatch admission fields.',
    );
  }
}

String _admissionText(Object? value) =>
    value is String &&
        value.isNotEmpty &&
        value.length <= 4096 &&
        !value.contains(RegExp(r'[\x00-\x1f\x7f-\x9f]'))
    ? value
    : (throw const FormatException('Invalid Runner dispatch admission text.'));

String _admissionIdentifier(Object? value, {int maxLength = 256}) {
  final text = _admissionText(value);
  if (text.length > maxLength ||
      !RegExp(r'^[A-Za-z0-9][A-Za-z0-9._:+/-]*$').hasMatch(text)) {
    throw const FormatException(
      'Invalid Runner dispatch admission identifier.',
    );
  }
  return text;
}

int _admissionInt(Object? value, String label) =>
    value is int && value >= 0 && value <= 9007199254740991
    ? value
    : (throw FormatException('Invalid Runner dispatch admission $label.'));

int _admissionPositiveInt(Object? value) {
  final result = _admissionInt(value, 'number');
  if (result == 0) {
    throw const FormatException('Invalid Runner dispatch admission number.');
  }
  return result;
}

int _admissionBoundedPositiveInt(Object? value, int max) {
  final result = _admissionPositiveInt(value);
  if (result > max) {
    throw const FormatException(
      'Runner dispatch admission number is out of bounds.',
    );
  }
  return result;
}

bool _admissionBool(Object? value) => value is bool
    ? value
    : (throw const FormatException(
        'Invalid Runner dispatch admission boolean.',
      ));

String _admissionDigest(Object? value) {
  final text = _admissionText(value);
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(text)) {
    throw const FormatException('Invalid Runner dispatch admission digest.');
  }
  return text;
}

String _admissionState(Object? value) {
  final state = _admissionIdentifier(value);
  if (!const {
    'requested',
    'accepted',
    'starting',
    'running',
    'interrupted',
    'completed',
    'failed',
    'uncertain',
  }.contains(state)) {
    throw const FormatException('Invalid Runner dispatch admission state.');
  }
  return state;
}

List<String> _admissionReasons(Object? value) {
  if (value is! List) {
    throw const FormatException('Invalid Runner dispatch admission reasons.');
  }
  final values = value.map(_admissionIdentifier).toList(growable: false);
  final sorted = [...values]..sort();
  if (values.join('|') != sorted.join('|') ||
      values.toSet().length != values.length) {
    throw const FormatException(
      'Runner dispatch admission reasons are not sorted uniquely.',
    );
  }
  return values;
}

List<String> _admissionReasonsFor(
  bool command,
  bool current,
  bool active,
  bool state,
) {
  final values = <String>[];
  if (!command) values.add('command_binding_invalid');
  if (!current) values.add('lease_proof_not_current');
  if (!active) values.add('lease_inactive_at_evaluated_time');
  if (!state) values.add('attempt_state_not_dispatchable');
  return values;
}
