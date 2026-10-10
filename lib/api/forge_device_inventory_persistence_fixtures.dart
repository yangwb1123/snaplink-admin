part of 'forge_device_inventory_persistence.dart';

class ForgeDeviceInventoryPersistenceExpected {
  final bool accepted;
  final String? error;
  final BigInt? revision;
  final String? deviceID;
  final String? instanceID;
  final BigInt? heartbeatSequence;
  final BigInt? serverObservedAtMS;
  final BigInt? capabilityLeaseExpiresAtMS;
  final String? status;
  final bool? fresh;
  final bool? declaredEligible;

  const ForgeDeviceInventoryPersistenceExpected._({
    required this.accepted,
    required this.error,
    required this.revision,
    required this.deviceID,
    required this.instanceID,
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
    required this.status,
    required this.fresh,
    required this.declaredEligible,
  });

  factory ForgeDeviceInventoryPersistenceExpected.fromJson(
    Object? value,
    String operation,
  ) {
    final json = _inventoryPersistenceObject(value);
    final accepted = _inventoryPersistenceBool(json['accepted']);
    if (!accepted) {
      _inventoryPersistenceExactKeys(json, {'accepted', 'error'});
      final error = _inventoryPersistenceText(json['error']);
      if (!_forgeDeviceInventoryPersistenceErrors.contains(error)) {
        throw const FormatException('Unknown Forge persisted inventory error.');
      }
      return ForgeDeviceInventoryPersistenceExpected._(
        accepted: false,
        error: error,
        revision: null,
        deviceID: null,
        instanceID: null,
        heartbeatSequence: null,
        serverObservedAtMS: null,
        capabilityLeaseExpiresAtMS: null,
        status: null,
        fresh: null,
        declaredEligible: null,
      );
    }
    final expectedKeys = <String>{'accepted'};
    if (operation == 'commit') {
      expectedKeys.addAll({
        'revision',
        'heartbeat_sequence',
        'server_observed_at_ms',
        'capability_lease_expires_at_ms',
      });
    } else if (operation == 'project') {
      expectedKeys.addAll({
        'revision',
        'device_id',
        'instance_id',
        'status',
        'fresh',
        'declared_eligible',
      });
    }
    _inventoryPersistenceExactKeys(json, expectedKeys);
    return ForgeDeviceInventoryPersistenceExpected._(
      accepted: true,
      error: null,
      revision: json.containsKey('revision')
          ? _inventoryPersistenceUint64(json['revision'])
          : null,
      deviceID: json.containsKey('device_id')
          ? _inventoryPersistenceIdentifier(json['device_id'])
          : null,
      instanceID: json.containsKey('instance_id')
          ? _inventoryPersistenceIdentifier(json['instance_id'])
          : null,
      heartbeatSequence: json.containsKey('heartbeat_sequence')
          ? _inventoryPersistencePositiveUint64(json['heartbeat_sequence'])
          : null,
      serverObservedAtMS: json.containsKey('server_observed_at_ms')
          ? _inventoryPersistenceUint64(json['server_observed_at_ms'])
          : null,
      capabilityLeaseExpiresAtMS:
          json.containsKey('capability_lease_expires_at_ms')
          ? _inventoryPersistenceUint64(json['capability_lease_expires_at_ms'])
          : null,
      status: json.containsKey('status')
          ? _inventoryPersistenceText(json['status'])
          : null,
      fresh: json.containsKey('fresh')
          ? _inventoryPersistenceBool(json['fresh'])
          : null,
      declaredEligible: json.containsKey('declared_eligible')
          ? _inventoryPersistenceBool(json['declared_eligible'])
          : null,
    );
  }
}

class ForgeDeviceInventoryPersistenceReplacement {
  final BigInt? heartbeatSequence;
  final BigInt? serverObservedAtMS;
  final BigInt? capabilityLeaseExpiresAtMS;

  const ForgeDeviceInventoryPersistenceReplacement({
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
  });

  factory ForgeDeviceInventoryPersistenceReplacement.fromJson(Object? value) {
    final json = _inventoryPersistenceObject(value);
    final expected = <String>{};
    if (json.containsKey('heartbeat_sequence')) {
      expected.add('heartbeat_sequence');
    }
    if (json.containsKey('server_observed_at_ms')) {
      expected.add('server_observed_at_ms');
    }
    if (json.containsKey('capability_lease_expires_at_ms')) {
      expected.add('capability_lease_expires_at_ms');
    }
    _inventoryPersistenceExactKeys(json, expected);
    return ForgeDeviceInventoryPersistenceReplacement(
      heartbeatSequence: json.containsKey('heartbeat_sequence')
          ? _inventoryPersistencePositiveUint64(json['heartbeat_sequence'])
          : null,
      serverObservedAtMS: json.containsKey('server_observed_at_ms')
          ? _inventoryPersistenceUint64(json['server_observed_at_ms'])
          : null,
      capabilityLeaseExpiresAtMS:
          json.containsKey('capability_lease_expires_at_ms')
          ? _inventoryPersistenceUint64(json['capability_lease_expires_at_ms'])
          : null,
    );
  }
}

class ForgeDeviceInventoryPersistenceCase {
  final String name;
  final String operation;
  final String? evaluationOwner;
  final BigInt? evaluatedAtMS;
  final BigInt? expectedRevision;
  final BigInt? stateRevision;
  final String? runnerDeviceID;
  final String? deviceApprovalState;
  final String? deviceCordonState;
  final String? runnerLiveness;
  final ForgeDeviceInventoryPersistenceReplacement? replacement;
  final ForgeDeviceInventoryPersistenceExpected expected;

  const ForgeDeviceInventoryPersistenceCase({
    required this.name,
    required this.operation,
    required this.evaluationOwner,
    required this.evaluatedAtMS,
    required this.expectedRevision,
    required this.stateRevision,
    required this.runnerDeviceID,
    required this.deviceApprovalState,
    required this.deviceCordonState,
    required this.runnerLiveness,
    required this.replacement,
    required this.expected,
  });

  factory ForgeDeviceInventoryPersistenceCase.fromJson(Object? value) {
    final json = _inventoryPersistenceObject(value);
    final expectedKeys = {'name', 'operation', 'expected'};
    for (final key in const [
      'evaluation_owner',
      'evaluated_at_ms',
      'expected_revision',
      'state_revision',
      'runner_device_id',
      'device_approval_state',
      'device_cordon_state',
      'runner_liveness',
      'replacement',
    ]) {
      if (json.containsKey(key)) expectedKeys.add(key);
    }
    _inventoryPersistenceExactKeys(json, expectedKeys);
    final operation = _inventoryPersistenceOneOf(json['operation'], const {
      'restore',
      'commit',
      'project',
    });
    final rawEvaluationOwner = json['evaluation_owner'];
    if (json.containsKey('evaluation_owner') && rawEvaluationOwner == null) {
      throw const FormatException(
        'Invalid Forge persisted inventory evaluation owner.',
      );
    }
    final evaluationOwner = rawEvaluationOwner == null
        ? null
        : _inventoryPersistenceOneOf(rawEvaluationOwner, const {
            'same',
            'foreign',
            'invalid',
          });
    final rawReplacement = json['replacement'];
    if (json.containsKey('replacement') && rawReplacement == null) {
      throw const FormatException(
        'Invalid Forge persisted inventory replacement.',
      );
    }
    if (rawReplacement != null && rawReplacement is! Map) {
      throw const FormatException(
        'Invalid Forge persisted inventory replacement.',
      );
    }
    return ForgeDeviceInventoryPersistenceCase(
      name: _inventoryPersistenceIdentifier(json['name']),
      operation: operation,
      evaluationOwner: evaluationOwner,
      evaluatedAtMS: !json.containsKey('evaluated_at_ms')
          ? null
          : _inventoryPersistenceUint64(json['evaluated_at_ms']),
      expectedRevision: !json.containsKey('expected_revision')
          ? null
          : _inventoryPersistenceUint64(json['expected_revision']),
      stateRevision: !json.containsKey('state_revision')
          ? null
          : _inventoryPersistenceUint64(json['state_revision']),
      runnerDeviceID: json.containsKey('runner_device_id')
          ? _inventoryPersistenceIdentifier(json['runner_device_id'])
          : null,
      deviceApprovalState: json.containsKey('device_approval_state')
          ? _inventoryPersistenceOneOf(json['device_approval_state'], const {
              'approved',
              'pending',
              'revoked',
            })
          : null,
      deviceCordonState: json.containsKey('device_cordon_state')
          ? _inventoryPersistenceOneOf(json['device_cordon_state'], const {
              'clear',
              'cordoned',
            })
          : null,
      runnerLiveness: json.containsKey('runner_liveness')
          ? _inventoryPersistenceOneOf(json['runner_liveness'], const {
              'online',
              'offline',
            })
          : null,
      replacement: rawReplacement == null
          ? null
          : ForgeDeviceInventoryPersistenceReplacement.fromJson(rawReplacement),
      expected: ForgeDeviceInventoryPersistenceExpected.fromJson(
        json['expected'],
        operation,
      ),
    );
  }
}

class ForgeDeviceInventoryPersistenceFixture {
  final ForgeDeviceInventoryPersistenceAuthority authority;
  final BigInt staleAfterMS;
  final ForgeDeviceInventoryPersistenceState state;
  final List<ForgeDeviceInventoryPersistenceCase> cases;

  const ForgeDeviceInventoryPersistenceFixture({
    required this.authority,
    required this.staleAfterMS,
    required this.state,
    required this.cases,
  });

  factory ForgeDeviceInventoryPersistenceFixture.fromJsonText(String source) {
    final marked = source.replaceAllMapped(
      RegExp(r'(:\s*)18446744073709551615(?=\s*[,}\]])'),
      (match) =>
          '${match.group(1)}"$_forgeDeviceInventoryPersistenceMaxUint64Marker"',
    );
    return ForgeDeviceInventoryPersistenceFixture.fromJson(
      _restoreForgeDeviceInventoryPersistenceUint64Markers(jsonDecode(marked)),
    );
  }

  factory ForgeDeviceInventoryPersistenceFixture.fromJson(Object? value) {
    final json = _inventoryPersistenceObject(value);
    _inventoryPersistenceExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'stale_after_ms',
      'authority',
      'state',
      'cases',
    });
    if (json['schema_version'] != forgeDeviceInventoryPersistenceSchema ||
        json['evaluation_mode'] !=
            forgeDeviceInventoryPersistenceEvaluationMode) {
      throw const FormatException(
        'Invalid Forge persisted inventory envelope.',
      );
    }
    final staleAfterMS = _inventoryPersistenceUint64(json['stale_after_ms']);
    final rawCases = json['cases'];
    if (rawCases is! List ||
        rawCases.length != forgeDeviceInventoryPersistenceMaxCases) {
      throw const FormatException(
        'Invalid Forge persisted inventory case count.',
      );
    }
    final cases = rawCases
        .map(ForgeDeviceInventoryPersistenceCase.fromJson)
        .toList(growable: false);
    final names = cases.map((testCase) => testCase.name).toSet();
    if (names.length != cases.length) {
      throw const FormatException(
        'Duplicate Forge persisted inventory case name.',
      );
    }
    return ForgeDeviceInventoryPersistenceFixture(
      authority: ForgeDeviceInventoryPersistenceAuthority.fromJson(
        json['authority'],
      ),
      staleAfterMS: staleAfterMS,
      state: ForgeDeviceInventoryPersistenceState.fromJson(json['state']),
      cases: List.unmodifiable(cases),
    );
  }
}

class ForgeDeviceInventoryPersistenceEvaluation {
  final bool accepted;
  final String? error;
  final ForgeDeviceInventoryPersistenceState? state;
  final ForgeDeviceInventoryPersistenceProjection? projection;

  const ForgeDeviceInventoryPersistenceEvaluation.acceptedState(this.state)
    : accepted = true,
      error = null,
      projection = null;

  const ForgeDeviceInventoryPersistenceEvaluation.acceptedProjection(
    this.projection,
  ) : accepted = true,
      error = null,
      state = null;

  const ForgeDeviceInventoryPersistenceEvaluation.rejected(this.error)
    : accepted = false,
      state = null,
      projection = null;
}
