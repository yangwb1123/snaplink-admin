const forgeAttemptLifecycleSchema = 'forge.attempt-lifecycle/v1';
const forgeAttemptLifecycleEvaluationMode = 'pure_attempt_lifecycle_only';

const _forgeAttemptLifecycleStates = {
  'requested',
  'accepted',
  'starting',
  'running',
  'interrupted',
  'completed',
  'failed',
  'uncertain',
};

class ForgeAttemptLifecycleAuthority {
  final bool deviceIdentityVerified;
  final bool commandPersisted;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeAttemptLifecycleAuthority.offline()
    : deviceIdentityVerified = false,
      commandPersisted = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  factory ForgeAttemptLifecycleAuthority.fromJson(Object? value) {
    final json = _attemptLifecycleObject(value, 'authority');
    _attemptLifecycleExactKeys(json, {
      'device_identity_verified',
      'command_persisted',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    for (final entry in json.entries) {
      if (entry.value is! bool || entry.value == true) {
        throw const FormatException(
          'Attempt lifecycle fixture claims execution authority.',
        );
      }
    }
    return const ForgeAttemptLifecycleAuthority.offline();
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

class ForgeAttemptLifecycleCase {
  final String name;
  final String fromState;
  final String toState;
  final bool accepted;
  final String? error;

  const ForgeAttemptLifecycleCase({
    required this.name,
    required this.fromState,
    required this.toState,
    required this.accepted,
    required this.error,
  });

  factory ForgeAttemptLifecycleCase.fromJson(Object? value) {
    final json = _attemptLifecycleObject(value, 'case');
    final accepted = _attemptLifecycleBool(json['accepted']);
    _attemptLifecycleExactKeys(
      json,
      accepted
          ? {'name', 'from', 'to', 'accepted'}
          : {'name', 'from', 'to', 'accepted', 'error'},
    );
    final fromState = _attemptLifecycleState(json['from']);
    final toState = _attemptLifecycleState(json['to']);
    final error = accepted ? null : _attemptLifecycleText(json['error']);
    if (accepted &&
        !ForgeAttemptLifecycleFixture.isTransitionAllowed(fromState, toState)) {
      throw const FormatException(
        'Accepted Attempt lifecycle edge is invalid.',
      );
    }
    if (!accepted &&
        error != 'pc_transition_invalid' &&
        !(fromState == 'unknown' && error == 'pc_state_invalid')) {
      throw const FormatException(
        'Rejected Attempt lifecycle edge has invalid error.',
      );
    }
    return ForgeAttemptLifecycleCase(
      name: _attemptLifecycleText(json['name']),
      fromState: fromState,
      toState: toState,
      accepted: accepted,
      error: error,
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'from': fromState,
    'to': toState,
    'accepted': accepted,
    if (!accepted) 'error': error,
  };
}

class ForgeAttemptLifecycleFixture {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeAttemptLifecycleAuthority authority;
  final List<ForgeAttemptLifecycleCase> cases;

  const ForgeAttemptLifecycleFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.authority,
    required this.cases,
  });

  factory ForgeAttemptLifecycleFixture.fromJson(Object? value) {
    final json = _attemptLifecycleObject(value, 'fixture');
    _attemptLifecycleExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'authority',
      'cases',
    });
    final rawCases = json['cases'];
    if (rawCases is! List || rawCases.isEmpty) {
      throw const FormatException('Attempt lifecycle fixture has no cases.');
    }
    return ForgeAttemptLifecycleFixture(
      schemaVersion: _attemptLifecycleSchema(json['schema_version']),
      evaluationMode: _attemptLifecycleMode(json['evaluation_mode']),
      authority: ForgeAttemptLifecycleAuthority.fromJson(json['authority']),
      cases: List.unmodifiable(
        rawCases.map(ForgeAttemptLifecycleCase.fromJson),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'authority': authority.toJson(),
    'cases': cases.map((value) => value.toJson()).toList(growable: false),
  };

  static bool isTransitionAllowed(String fromState, String toState) =>
      switch (fromState) {
        'requested' => toState == 'accepted',
        'accepted' =>
          toState == 'starting' ||
              toState == 'interrupted' ||
              toState == 'failed' ||
              toState == 'uncertain',
        'starting' =>
          toState == 'running' ||
              toState == 'interrupted' ||
              toState == 'failed' ||
              toState == 'uncertain',
        'running' =>
          toState == 'interrupted' ||
              toState == 'completed' ||
              toState == 'failed' ||
              toState == 'uncertain',
        _ => false,
      };
}

Map<String, dynamic> _attemptLifecycleObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException('Attempt lifecycle $label must be an object.');
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _attemptLifecycleExactKeys(
  Map<String, dynamic> value,
  Set<String> expected,
) {
  if (!value.keys.toSet().containsAll(expected) ||
      !expected.containsAll(value.keys)) {
    throw const FormatException(
      'Attempt lifecycle fixture has unknown fields.',
    );
  }
}

String _attemptLifecycleText(Object? value) {
  if (value is! String || value.isEmpty || value.length > 128) {
    throw const FormatException('Invalid Attempt lifecycle text.');
  }
  return value;
}

String _attemptLifecycleState(Object? value) {
  final state = _attemptLifecycleText(value);
  if (!_forgeAttemptLifecycleStates.contains(state)) {
    // Keep the unknown state available for the fixture's explicit rejection
    // case while rejecting every other malformed value.
    if (state != 'unknown') {
      throw const FormatException('Invalid Attempt lifecycle state.');
    }
  }
  return state;
}

bool _attemptLifecycleBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Attempt lifecycle flag must be boolean.');
  }
  return value;
}

String _attemptLifecycleSchema(Object? value) {
  final schema = _attemptLifecycleText(value);
  if (schema != forgeAttemptLifecycleSchema) {
    throw const FormatException('Unsupported Attempt lifecycle schema.');
  }
  return schema;
}

String _attemptLifecycleMode(Object? value) {
  final mode = _attemptLifecycleText(value);
  if (mode != forgeAttemptLifecycleEvaluationMode) {
    throw const FormatException('Unsupported Attempt lifecycle mode.');
  }
  return mode;
}
