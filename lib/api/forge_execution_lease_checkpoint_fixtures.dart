part of 'forge_execution_lease_checkpoint.dart';

class ForgeExecutionLeaseCheckpointExpected {
  final bool accepted;
  final bool terminal;
  final bool uncertain;
  final String? error;

  const ForgeExecutionLeaseCheckpointExpected({
    required this.accepted,
    required this.terminal,
    required this.uncertain,
    required this.error,
  });

  factory ForgeExecutionLeaseCheckpointExpected.fromJson(Object? value) {
    final json = _checkpointObject(value, 'expected');
    final expectedKeys = {'accepted'};
    for (final key in const ['terminal', 'uncertain', 'error']) {
      if (json.containsKey(key)) expectedKeys.add(key);
    }
    _checkpointExactKeys(json, expectedKeys);
    final accepted = _checkpointBool(json['accepted']);
    final terminal = json.containsKey('terminal')
        ? _checkpointBool(json['terminal'])
        : false;
    final uncertain = json.containsKey('uncertain')
        ? _checkpointBool(json['uncertain'])
        : false;
    final error = json.containsKey('error')
        ? _checkpointText(json['error'], 64)
        : null;
    if (accepted && error != null) {
      throw const FormatException('Accepted checkpoint case has an error.');
    }
    if (!accepted && error != 'invalid_checkpoint') {
      throw const FormatException(
        'Rejected checkpoint case has invalid error.',
      );
    }
    return ForgeExecutionLeaseCheckpointExpected(
      accepted: accepted,
      terminal: terminal,
      uncertain: uncertain,
      error: error,
    );
  }

  Map<String, dynamic> toJson() => {
    'accepted': accepted,
    if (terminal) 'terminal': true,
    if (uncertain) 'uncertain': true,
    if (error != null) 'error': error,
  };
}

class ForgeExecutionLeaseCheckpointCase {
  final String name;
  final ForgeExecutionLeaseCheckpoint checkpoint;
  final ForgeExecutionLeaseCheckpointExpected expected;

  const ForgeExecutionLeaseCheckpointCase({
    required this.name,
    required this.checkpoint,
    required this.expected,
  });

  factory ForgeExecutionLeaseCheckpointCase.fromJson(Object? value) {
    final json = _checkpointObject(value, 'case');
    _checkpointExactKeys(json, {'name', 'checkpoint', 'expected'});
    return ForgeExecutionLeaseCheckpointCase(
      name: _checkpointIdentity(json['name']),
      checkpoint: ForgeExecutionLeaseCheckpoint.fromJson(json['checkpoint']),
      expected: ForgeExecutionLeaseCheckpointExpected.fromJson(
        json['expected'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'checkpoint': checkpoint.toJson(),
    'expected': expected.toJson(),
  };
}

class ForgeExecutionLeaseCheckpointFixture {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeExecutionLeaseCheckpointAuthority authority;
  final List<ForgeExecutionLeaseCheckpointCase> cases;

  const ForgeExecutionLeaseCheckpointFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.authority,
    required this.cases,
  });

  factory ForgeExecutionLeaseCheckpointFixture.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Execution lease checkpoint fixture is too large.',
      );
    }
    _checkpointRejectDuplicateKeys(source);
    return ForgeExecutionLeaseCheckpointFixture.fromJson(jsonDecode(source));
  }

  factory ForgeExecutionLeaseCheckpointFixture.fromJson(Object? value) {
    final json = _checkpointObject(value, 'fixture');
    _checkpointExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'authority',
      'cases',
    });
    final schemaVersion = _checkpointSchema(json['schema_version']);
    final evaluationMode = _checkpointMode(json['evaluation_mode']);
    final rawCases = json['cases'];
    if (rawCases is! List || rawCases.length != 4) {
      throw const FormatException(
        'Invalid execution lease checkpoint case count.',
      );
    }
    final cases = rawCases
        .map(ForgeExecutionLeaseCheckpointCase.fromJson)
        .toList(growable: false);
    const expectedNames = [
      'empty_state',
      'completed_receipt_survives_restart',
      'uncertain_receipt_remains_terminal',
      'foreign_proof_rejected',
    ];
    for (var index = 0; index < expectedNames.length; index++) {
      if (cases[index].name != expectedNames[index]) {
        throw const FormatException(
          'Execution lease checkpoint cases are not canonical.',
        );
      }
    }
    if (cases.map((item) => item.name).toSet().length != cases.length) {
      throw const FormatException('Duplicate execution lease checkpoint case.');
    }
    final firstGrant = cases.first.checkpoint.grant;
    if (cases.any(
      (item) => !_checkpointGrantEquals(item.checkpoint.grant, firstGrant),
    )) {
      throw const FormatException('Execution lease checkpoint grants drift.');
    }
    for (final item in cases) {
      final accepted = item.checkpoint.isValid;
      final terminal = accepted && item.checkpoint.terminal != null;
      final uncertain = terminal && item.checkpoint.isUncertain;
      if (accepted != item.expected.accepted ||
          terminal != item.expected.terminal ||
          uncertain != item.expected.uncertain) {
        throw FormatException(
          'Execution lease checkpoint case ${item.name} expectation drifted.',
        );
      }
    }
    return ForgeExecutionLeaseCheckpointFixture(
      schemaVersion: schemaVersion,
      evaluationMode: evaluationMode,
      authority: ForgeExecutionLeaseCheckpointAuthority.fromJson(
        json['authority'],
      ),
      cases: List.unmodifiable(cases),
    );
  }

  bool get isDisplayOnly =>
      schemaVersion == forgeExecutionLeaseCheckpointSchema &&
      evaluationMode == forgeExecutionLeaseCheckpointEvaluationMode &&
      authority.isOffline;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'authority': authority.toJson(),
    'cases': cases.map((item) => item.toJson()).toList(growable: false),
  };
}
