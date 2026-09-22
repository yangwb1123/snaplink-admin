import 'dart:convert';

/// Strict local consumer for the cross-runtime execution-lease checkpoint
/// value. This module does not restore a lease, persist a receipt, reserve a
/// device, contact a Runner, or authorize execution.
const forgeExecutionLeaseCheckpointSchema =
    'forge.execution-lease-checkpoint/v1';
const forgeExecutionLeaseCheckpointEvaluationMode =
    'pure_execution_lease_checkpoint_only';
const forgeExecutionLeaseCheckpointMinTTLMS = 1000;
const forgeExecutionLeaseCheckpointMaxTTLMS = 600000;

/// File reader seam used by the shared Web/App/Mobile local preview. The
/// default Sessions screen uses the platform workspace picker; tests and
/// native shells can inject a bounded reader without opening a network route.
typedef ForgeExecutionLeaseCheckpointFileReader = Future<String?> Function();

final _checkpointMaxUint64 = (BigInt.one << 64) - BigInt.one;

class ForgeExecutionLeaseCheckpointAuthority {
  final bool leaseIssued;
  final bool terminalPersisted;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeExecutionLeaseCheckpointAuthority({
    required this.leaseIssued,
    required this.terminalPersisted,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeExecutionLeaseCheckpointAuthority.fromJson(Object? value) {
    final json = _checkpointObject(value, 'authority');
    _checkpointExactKeys(json, {
      'lease_issued',
      'terminal_persisted',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeExecutionLeaseCheckpointAuthority(
      leaseIssued: _checkpointBool(json['lease_issued']),
      terminalPersisted: _checkpointBool(json['terminal_persisted']),
      executionAuthorized: _checkpointBool(json['execution_authorized']),
      dispatchPerformed: _checkpointBool(json['dispatch_performed']),
      auditPublished: _checkpointBool(json['audit_published']),
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Execution lease checkpoint claims authority.',
      );
    }
    return authority;
  }

  const ForgeExecutionLeaseCheckpointAuthority.offline()
    : leaseIssued = false,
      terminalPersisted = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  bool get isOffline =>
      !leaseIssued &&
      !terminalPersisted &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'lease_issued': leaseIssued,
    'terminal_persisted': terminalPersisted,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeExecutionLeaseCheckpointGrant {
  final int version;
  final String attemptID;
  final String targetID;
  final BigInt epoch;
  final String fencingToken;
  final BigInt issuedAtMS;
  final BigInt expiresAtMS;

  const ForgeExecutionLeaseCheckpointGrant({
    required this.version,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory ForgeExecutionLeaseCheckpointGrant.fromJson(Object? value) {
    final json = _checkpointObject(value, 'grant');
    _checkpointExactKeys(json, {
      'v',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
      'issued_at_ms',
      'expires_at_ms',
    });
    final grant = ForgeExecutionLeaseCheckpointGrant(
      version: _checkpointVersion(json['v']),
      attemptID: _checkpointIdentity(json['attempt_id']),
      targetID: _checkpointIdentity(json['target_id']),
      epoch: _checkpointPositiveUint64(json['epoch']),
      fencingToken: _checkpointToken(json['fencing_token']),
      issuedAtMS: _checkpointUint64(json['issued_at_ms']),
      expiresAtMS: _checkpointUint64(json['expires_at_ms']),
    );
    grant.validate();
    return grant;
  }

  void validate() {
    if (version != 1) {
      throw const FormatException('Unsupported execution lease version.');
    }
    if (expiresAtMS <= issuedAtMS) {
      throw const FormatException('Invalid execution lease window.');
    }
    final ttl = expiresAtMS - issuedAtMS;
    if (ttl < BigInt.from(forgeExecutionLeaseCheckpointMinTTLMS) ||
        ttl > BigInt.from(forgeExecutionLeaseCheckpointMaxTTLMS)) {
      throw const FormatException('Invalid execution lease duration.');
    }
  }

  bool isActive(BigInt observedAtMS) =>
      observedAtMS >= issuedAtMS && observedAtMS < expiresAtMS;

  Map<String, dynamic> toJson() => {
    'v': version,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': _checkpointJsonUint64(epoch),
    'fencing_token': fencingToken,
    'issued_at_ms': _checkpointJsonUint64(issuedAtMS),
    'expires_at_ms': _checkpointJsonUint64(expiresAtMS),
  };
}

class ForgeExecutionLeaseCheckpointProof {
  final String attemptID;
  final String targetID;
  final BigInt epoch;
  final String fencingToken;

  const ForgeExecutionLeaseCheckpointProof({
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
  });

  factory ForgeExecutionLeaseCheckpointProof.fromJson(Object? value) {
    final json = _checkpointObject(value, 'proof');
    _checkpointExactKeys(json, {
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
    });
    return ForgeExecutionLeaseCheckpointProof(
      attemptID: _checkpointIdentity(json['attempt_id']),
      targetID: _checkpointIdentity(json['target_id']),
      epoch: _checkpointPositiveUint64(json['epoch']),
      fencingToken: _checkpointToken(json['fencing_token']),
    );
  }

  Map<String, dynamic> toJson() => {
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': _checkpointJsonUint64(epoch),
    'fencing_token': fencingToken,
  };
}

class ForgeExecutionLeaseCheckpointDisposition {
  final String kind;
  final String? receiptSHA256;
  final String? reason;

  const ForgeExecutionLeaseCheckpointDisposition({
    required this.kind,
    this.receiptSHA256,
    this.reason,
  });

  factory ForgeExecutionLeaseCheckpointDisposition.fromJson(Object? value) {
    final json = _checkpointObject(value, 'disposition');
    final kind = _checkpointOneOf(json['kind'], const {
      'completed',
      'failed',
      'uncertain',
    });
    final expected = <String>{'kind'};
    if (json.containsKey('receipt_sha256')) expected.add('receipt_sha256');
    if (json.containsKey('reason')) expected.add('reason');
    _checkpointExactKeys(json, expected);
    if (kind == 'completed') {
      if (!json.containsKey('receipt_sha256') ||
          json.containsKey('reason') ||
          json['receipt_sha256'] == null) {
        throw const FormatException(
          'Invalid completed checkpoint disposition.',
        );
      }
      return ForgeExecutionLeaseCheckpointDisposition(
        kind: kind,
        receiptSHA256: _checkpointDigest(json['receipt_sha256']),
      );
    }
    if (!json.containsKey('reason') ||
        json.containsKey('receipt_sha256') ||
        json['reason'] == null) {
      throw const FormatException('Invalid terminal checkpoint disposition.');
    }
    return ForgeExecutionLeaseCheckpointDisposition(
      kind: kind,
      reason: _checkpointReason(json['reason']),
    );
  }

  bool get isUncertain => kind == 'uncertain';

  Map<String, dynamic> toJson() => {
    'kind': kind,
    if (receiptSHA256 != null) 'receipt_sha256': receiptSHA256,
    if (reason != null) 'reason': reason,
  };
}

class ForgeExecutionLeaseCheckpointTerminal {
  final int version;
  final ForgeExecutionLeaseCheckpointProof proof;
  final ForgeExecutionLeaseCheckpointDisposition disposition;
  final BigInt observedAtMS;

  const ForgeExecutionLeaseCheckpointTerminal({
    required this.version,
    required this.proof,
    required this.disposition,
    required this.observedAtMS,
  });

  factory ForgeExecutionLeaseCheckpointTerminal.fromJson(Object? value) {
    final json = _checkpointObject(value, 'terminal');
    _checkpointExactKeys(json, {'v', 'proof', 'disposition', 'observed_at_ms'});
    final version = _checkpointVersion(json['v']);
    if (version != 1) {
      throw const FormatException('Unsupported terminal checkpoint version.');
    }
    return ForgeExecutionLeaseCheckpointTerminal(
      version: version,
      proof: ForgeExecutionLeaseCheckpointProof.fromJson(json['proof']),
      disposition: ForgeExecutionLeaseCheckpointDisposition.fromJson(
        json['disposition'],
      ),
      observedAtMS: _checkpointUint64(json['observed_at_ms']),
    );
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'proof': proof.toJson(),
    'disposition': disposition.toJson(),
    'observed_at_ms': _checkpointJsonUint64(observedAtMS),
  };
}

class ForgeExecutionLeaseCheckpoint {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeExecutionLeaseCheckpointGrant grant;
  final ForgeExecutionLeaseCheckpointTerminal? terminal;

  const ForgeExecutionLeaseCheckpoint({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.grant,
    required this.terminal,
  });

  factory ForgeExecutionLeaseCheckpoint.fromJson(Object? value) {
    final json = _checkpointObject(value, 'checkpoint');
    _checkpointExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'grant',
      'terminal',
    });
    final schemaVersion = _checkpointSchema(json['schema_version']);
    final evaluationMode = _checkpointMode(json['evaluation_mode']);
    final terminalValue = json['terminal'];
    if (terminalValue != null && terminalValue is! Map) {
      throw const FormatException(
        'Checkpoint terminal must be an object or null.',
      );
    }
    return ForgeExecutionLeaseCheckpoint(
      schemaVersion: schemaVersion,
      evaluationMode: evaluationMode,
      grant: ForgeExecutionLeaseCheckpointGrant.fromJson(json['grant']),
      terminal: terminalValue == null
          ? null
          : ForgeExecutionLeaseCheckpointTerminal.fromJson(terminalValue),
    );
  }

  /// True when this value can be restored into the pure in-memory state
  /// machine. A false result is retained for the canonical foreign-proof case
  /// so the fixture can show a bounded rejection without exposing proof data.
  bool get isValid {
    if (schemaVersion != forgeExecutionLeaseCheckpointSchema ||
        evaluationMode != forgeExecutionLeaseCheckpointEvaluationMode) {
      return false;
    }
    try {
      grant.validate();
    } on FormatException {
      return false;
    }
    final receipt = terminal;
    if (receipt == null) return true;
    if (receipt.version != 1 ||
        receipt.proof.attemptID != grant.attemptID ||
        receipt.proof.targetID != grant.targetID ||
        receipt.proof.epoch != grant.epoch ||
        receipt.proof.fencingToken != grant.fencingToken) {
      return false;
    }
    return grant.isActive(receipt.observedAtMS);
  }

  bool get isUncertain => terminal?.disposition.isUncertain == true;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'grant': grant.toJson(),
    'terminal': terminal?.toJson(),
  };
}

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

Map<String, dynamic> _checkpointObject(Object? value, String label) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw FormatException(
      'Execution lease checkpoint $label must be an object.',
    );
  }
  return Map<String, dynamic>.from(value);
}

void _checkpointExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected execution lease checkpoint fields.',
    );
  }
}

String _checkpointSchema(Object? value) {
  final text = _checkpointText(value, 128);
  if (text != forgeExecutionLeaseCheckpointSchema) {
    throw const FormatException('Invalid execution lease checkpoint schema.');
  }
  return text;
}

String _checkpointMode(Object? value) {
  final text = _checkpointText(value, 128);
  if (text != forgeExecutionLeaseCheckpointEvaluationMode) {
    throw const FormatException('Invalid execution lease checkpoint mode.');
  }
  return text;
}

String _checkpointText(Object? value, int maximum) {
  if (value is! String || !_checkpointValidUnicode(value)) {
    throw const FormatException('Invalid execution lease checkpoint text.');
  }
  final byteLength = utf8.encode(value).length;
  if (value.isEmpty ||
      byteLength > maximum ||
      value.trim() != value ||
      value.codeUnits.any(
        (unit) => unit <= 0x1f || (unit >= 0x7f && unit <= 0x9f),
      )) {
    throw const FormatException('Invalid execution lease checkpoint text.');
  }
  return value;
}

String _checkpointIdentity(Object? value) => _checkpointText(value, 128);

String _checkpointToken(Object? value) => _checkpointText(value, 256);

String _checkpointReason(Object? value) => _checkpointText(value, 256);

String _checkpointDigest(Object? value) {
  final text = _checkpointText(value, 64);
  if (text.length != 64 ||
      text.codeUnits.any(
        (code) =>
            !((code >= 0x30 && code <= 0x39) || (code >= 0x61 && code <= 0x66)),
      )) {
    throw const FormatException('Invalid execution lease checkpoint digest.');
  }
  return text;
}

String _checkpointOneOf(Object? value, Set<String> allowed) {
  final text = _checkpointText(value, 64);
  if (!allowed.contains(text)) {
    throw FormatException('Invalid execution lease checkpoint value: $text');
  }
  return text;
}

int _checkpointVersion(Object? value) {
  if (value is! int || value != 1) {
    throw const FormatException(
      'Unsupported execution lease checkpoint version.',
    );
  }
  return value;
}

bool _checkpointBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid execution lease checkpoint boolean.');
  }
  return value;
}

BigInt _checkpointUint64(Object? value) {
  final number = switch (value) {
    int value => BigInt.from(value),
    BigInt value => value,
    String value => BigInt.tryParse(value),
    _ => null,
  };
  if (number == null || number.isNegative || number > _checkpointMaxUint64) {
    throw const FormatException('Invalid execution lease checkpoint uint64.');
  }
  return number;
}

BigInt _checkpointPositiveUint64(Object? value) {
  final number = _checkpointUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException('Invalid execution lease checkpoint epoch.');
  }
  return number;
}

Object _checkpointJsonUint64(BigInt value) =>
    value <= BigInt.from(9007199254740991) ? value.toInt() : value.toString();

bool _checkpointGrantEquals(
  ForgeExecutionLeaseCheckpointGrant left,
  ForgeExecutionLeaseCheckpointGrant right,
) =>
    left.version == right.version &&
    left.attemptID == right.attemptID &&
    left.targetID == right.targetID &&
    left.epoch == right.epoch &&
    left.fencingToken == right.fencingToken &&
    left.issuedAtMS == right.issuedAtMS &&
    left.expiresAtMS == right.expiresAtMS;

bool _checkpointValidUnicode(String value) {
  for (var index = 0; index < value.length; index++) {
    final unit = value.codeUnitAt(index);
    if (unit >= 0xd800 && unit <= 0xdbff) {
      if (index + 1 >= value.length) return false;
      final next = value.codeUnitAt(++index);
      if (next < 0xdc00 || next > 0xdfff) return false;
    } else if (unit >= 0xdc00 && unit <= 0xdfff) {
      return false;
    }
  }
  return true;
}

/// Dart's JSON decoder keeps the last value when an object repeats a key.
/// Cross-runtime fixtures reject that ambiguity before map materialization.
void _checkpointRejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate execution lease checkpoint JSON key.',
            );
          }
        }
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      stringStart = index;
    } else if (char == '{') {
      objects.add(<String>{});
    } else if (char == '}') {
      if (objects.isEmpty) {
        throw const FormatException('Invalid execution lease checkpoint JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty || escaped) {
    throw const FormatException('Invalid execution lease checkpoint JSON.');
  }
}
