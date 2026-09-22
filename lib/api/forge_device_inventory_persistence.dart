import 'dart:convert';

import 'forge_device_heartbeat.dart';
import 'forge_device_inventory_declaration.dart';

export 'forge_device_heartbeat.dart';
export 'forge_device_inventory_declaration.dart';

/// Pure value-level restore, replacement, and fixed-time projection for a
/// future persisted inventory store. It performs no I/O, clock read, retry,
/// authentication, reservation, or execution.
const forgeDeviceInventoryPersistenceSchema =
    'forge.device-inventory-persistence/v1';
const forgeDeviceInventoryPersistenceEvaluationMode =
    'pure_persisted_inventory_cas_projection';
const forgeDeviceInventoryPersistenceDefaultStaleAfterMS = 90000;
const forgeDeviceInventoryPersistenceMaxCases = 12;

final _forgeDeviceInventoryPersistenceMaxUint64 =
    (BigInt.one << 64) - BigInt.one;
final _forgeDeviceInventoryPersistenceMinLeaseTTLMS = BigInt.from(1000);
final _forgeDeviceInventoryPersistenceMaxLeaseTTLMS = BigInt.from(600000);
const _forgeDeviceInventoryPersistenceMaxUint64Marker =
    '__forge_inventory_persistence_u64_max__';

class ForgeDeviceInventoryPersistenceAuthority {
  final bool identityVerified;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeDeviceInventoryPersistenceAuthority({
    required this.identityVerified,
    required this.heartbeatPersisted,
    required this.inventoryAuthoritative,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  const ForgeDeviceInventoryPersistenceAuthority.offline()
    : identityVerified = false,
      heartbeatPersisted = false,
      inventoryAuthoritative = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false;

  bool get anyGranted =>
      identityVerified ||
      heartbeatPersisted ||
      inventoryAuthoritative ||
      reservationCreated ||
      executionAuthorized ||
      dispatchPerformed;

  factory ForgeDeviceInventoryPersistenceAuthority.fromJson(Object? value) {
    final json = _inventoryPersistenceObject(value);
    _inventoryPersistenceExactKeys(json, {
      'identity_verified',
      'heartbeat_persisted',
      'inventory_authoritative',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    final authority = ForgeDeviceInventoryPersistenceAuthority(
      identityVerified: _inventoryPersistenceBool(json['identity_verified']),
      heartbeatPersisted: _inventoryPersistenceBool(
        json['heartbeat_persisted'],
      ),
      inventoryAuthoritative: _inventoryPersistenceBool(
        json['inventory_authoritative'],
      ),
      reservationCreated: _inventoryPersistenceBool(
        json['reservation_created'],
      ),
      executionAuthorized: _inventoryPersistenceBool(
        json['execution_authorized'],
      ),
      dispatchPerformed: _inventoryPersistenceBool(json['dispatch_performed']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge persisted inventory authority must remain false.',
      );
    }
    return authority;
  }
}

class ForgeDeviceInventoryPersistenceDevice {
  final String deviceID;
  final ForgeDeviceOwner owner;
  final String approvalState;
  final String cordonState;
  final String reservationState;

  const ForgeDeviceInventoryPersistenceDevice({
    required this.deviceID,
    required this.owner,
    required this.approvalState,
    required this.cordonState,
    required this.reservationState,
  });

  factory ForgeDeviceInventoryPersistenceDevice.fromJson(Object? value) {
    final json = _inventoryPersistenceObject(value);
    _inventoryPersistenceExactKeys(json, {
      'device_id',
      'owner',
      'approval_state',
      'cordon_state',
      'reservation_state',
    });
    return ForgeDeviceInventoryPersistenceDevice(
      deviceID: _inventoryPersistenceIdentifier(json['device_id']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      approvalState: _inventoryPersistenceOneOf(json['approval_state'], const {
        'approved',
        'pending',
        'revoked',
      }),
      cordonState: _inventoryPersistenceOneOf(json['cordon_state'], const {
        'clear',
        'cordoned',
      }),
      reservationState: _inventoryPersistenceOneOf(
        json['reservation_state'],
        const {'none', 'reserved'},
      ),
    );
  }

  ForgeDeviceInventoryPersistenceDevice withOverrides({
    String? approvalState,
    String? cordonState,
    String? reservationState,
  }) => ForgeDeviceInventoryPersistenceDevice(
    deviceID: deviceID,
    owner: owner,
    approvalState: approvalState ?? this.approvalState,
    cordonState: cordonState ?? this.cordonState,
    reservationState: reservationState ?? this.reservationState,
  );
}

class ForgeDeviceInventoryPersistenceRunner {
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt heartbeatSequence;
  final BigInt serverObservedAtMS;
  final BigInt capabilityLeaseExpiresAtMS;
  final String liveness;
  final ForgeDeviceHeartbeatReferenceCapabilities capabilities;

  const ForgeDeviceInventoryPersistenceRunner({
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
    required this.liveness,
    required this.capabilities,
  });

  factory ForgeDeviceInventoryPersistenceRunner.fromJson(Object? value) {
    final json = _inventoryPersistenceObject(value);
    _inventoryPersistenceExactKeys(json, {
      'device_id',
      'instance_id',
      'generation',
      'heartbeat_sequence',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
      'liveness',
      'capabilities',
    });
    final capabilities = ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
      json['capabilities'],
    );
    if (!_inventoryPersistenceCapabilitiesCanonical(
      json['capabilities'],
      capabilities,
    )) {
      throw const FormatException(
        'Non-canonical Forge persisted inventory capabilities.',
      );
    }
    return ForgeDeviceInventoryPersistenceRunner(
      deviceID: _inventoryPersistenceIdentifier(json['device_id']),
      instanceID: _inventoryPersistenceIdentifier(json['instance_id']),
      generation: _inventoryPersistencePositiveUint64(json['generation']),
      heartbeatSequence: _inventoryPersistencePositiveUint64(
        json['heartbeat_sequence'],
      ),
      serverObservedAtMS: _inventoryPersistenceUint64(
        json['server_observed_at_ms'],
      ),
      capabilityLeaseExpiresAtMS: _inventoryPersistenceUint64(
        json['capability_lease_expires_at_ms'],
      ),
      liveness: _inventoryPersistenceOneOf(json['liveness'], const {
        'online',
        'offline',
      }),
      capabilities: capabilities,
    );
  }

  ForgeDeviceInventoryPersistenceRunner withOverrides({
    String? deviceID,
    BigInt? heartbeatSequence,
    BigInt? serverObservedAtMS,
    BigInt? capabilityLeaseExpiresAtMS,
    String? liveness,
  }) => ForgeDeviceInventoryPersistenceRunner(
    deviceID: deviceID ?? this.deviceID,
    instanceID: instanceID,
    generation: generation,
    heartbeatSequence: heartbeatSequence ?? this.heartbeatSequence,
    serverObservedAtMS: serverObservedAtMS ?? this.serverObservedAtMS,
    capabilityLeaseExpiresAtMS:
        capabilityLeaseExpiresAtMS ?? this.capabilityLeaseExpiresAtMS,
    liveness: liveness ?? this.liveness,
    capabilities: capabilities,
  );
}

class ForgeDeviceInventoryPersistenceState {
  final BigInt revision;
  final ForgeDeviceInventoryPersistenceDevice device;
  final ForgeDeviceInventoryPersistenceRunner runner;

  const ForgeDeviceInventoryPersistenceState({
    required this.revision,
    required this.device,
    required this.runner,
  });

  factory ForgeDeviceInventoryPersistenceState.fromJson(Object? value) {
    final json = _inventoryPersistenceObject(value);
    _inventoryPersistenceExactKeys(json, {'revision', 'device', 'runner'});
    return ForgeDeviceInventoryPersistenceState(
      revision: _inventoryPersistenceUint64(json['revision']),
      device: ForgeDeviceInventoryPersistenceDevice.fromJson(json['device']),
      runner: ForgeDeviceInventoryPersistenceRunner.fromJson(json['runner']),
    );
  }

  ForgeDeviceInventoryPersistenceState withOverrides({
    BigInt? revision,
    String? runnerDeviceID,
    String? deviceApprovalState,
    String? deviceCordonState,
    String? runnerLiveness,
  }) => ForgeDeviceInventoryPersistenceState(
    revision: revision ?? this.revision,
    device: device.withOverrides(
      approvalState: deviceApprovalState,
      cordonState: deviceCordonState,
    ),
    runner: runner.withOverrides(
      deviceID: runnerDeviceID,
      liveness: runnerLiveness,
    ),
  );
}

class ForgeDeviceInventoryPersistenceProjection {
  final BigInt revision;
  final String deviceID;
  final String instanceID;
  final String status;
  final bool fresh;
  final bool declaredEligible;

  const ForgeDeviceInventoryPersistenceProjection({
    required this.revision,
    required this.deviceID,
    required this.instanceID,
    required this.status,
    required this.fresh,
    required this.declaredEligible,
  });
}

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

ForgeDeviceInventoryPersistenceEvaluation restoreForgeDeviceInventory({
  required BigInt revision,
  required ForgeDeviceInventoryPersistenceDevice device,
  required ForgeDeviceInventoryPersistenceRunner runner,
}) {
  if (revision == BigInt.zero) {
    return const ForgeDeviceInventoryPersistenceEvaluation.rejected(
      'invalid_persisted_state',
    );
  }
  final runnerError = _validateForgeDeviceInventoryRunner(runner);
  if (runnerError != null) {
    return ForgeDeviceInventoryPersistenceEvaluation.rejected(runnerError);
  }
  final deviceError = _validateForgeDeviceInventoryDevice(device);
  if (deviceError != null) {
    return ForgeDeviceInventoryPersistenceEvaluation.rejected(deviceError);
  }
  if (runner.deviceID != device.deviceID) {
    return const ForgeDeviceInventoryPersistenceEvaluation.rejected(
      'runner_device_mismatch',
    );
  }
  return ForgeDeviceInventoryPersistenceEvaluation.acceptedState(
    ForgeDeviceInventoryPersistenceState(
      revision: revision,
      device: device,
      runner: runner,
    ),
  );
}

ForgeDeviceInventoryPersistenceEvaluation commitForgeDeviceInventory({
  required ForgeDeviceInventoryPersistenceState? current,
  required BigInt expectedRevision,
  required ForgeDeviceInventoryPersistenceDevice device,
  required ForgeDeviceInventoryPersistenceRunner runner,
}) {
  if (current != null) {
    final currentError = _validateForgeDeviceInventoryState(current);
    if (currentError != null) {
      return ForgeDeviceInventoryPersistenceEvaluation.rejected(currentError);
    }
  }
  final actualRevision = current?.revision ?? BigInt.zero;
  if (expectedRevision != actualRevision) {
    return const ForgeDeviceInventoryPersistenceEvaluation.rejected(
      'revision_conflict',
    );
  }
  if (actualRevision == _forgeDeviceInventoryPersistenceMaxUint64) {
    return const ForgeDeviceInventoryPersistenceEvaluation.rejected(
      'revision_overflow',
    );
  }
  if (current != null &&
      (device.deviceID != current.device.deviceID ||
          device.owner != current.device.owner ||
          runner.deviceID != current.runner.deviceID)) {
    return const ForgeDeviceInventoryPersistenceEvaluation.rejected(
      'device_binding_changed',
    );
  }
  final runnerError = _validateForgeDeviceInventoryRunner(runner);
  if (runnerError != null) {
    return ForgeDeviceInventoryPersistenceEvaluation.rejected(runnerError);
  }
  final next = ForgeDeviceInventoryPersistenceState(
    revision: actualRevision + BigInt.one,
    device: device,
    runner: runner,
  );
  final nextError = _validateForgeDeviceInventoryState(next);
  if (nextError != null) {
    return ForgeDeviceInventoryPersistenceEvaluation.rejected(nextError);
  }
  return ForgeDeviceInventoryPersistenceEvaluation.acceptedState(next);
}

ForgeDeviceInventoryPersistenceEvaluation projectForgeDeviceInventory({
  required ForgeDeviceInventoryPersistenceState value,
  required ForgeDeviceOwner evaluationOwner,
  required BigInt evaluatedAtMS,
  required BigInt staleAfterMS,
}) {
  final stateError = _validateForgeDeviceInventoryState(value);
  if (stateError != null) {
    return ForgeDeviceInventoryPersistenceEvaluation.rejected(stateError);
  }
  if (!_inventoryPersistenceOwnerValid(evaluationOwner)) {
    return const ForgeDeviceInventoryPersistenceEvaluation.rejected(
      'invalid_evaluation_owner',
    );
  }
  if (value.device.owner != evaluationOwner) {
    return const ForgeDeviceInventoryPersistenceEvaluation.rejected(
      'owner_mismatch',
    );
  }
  final status = _projectForgePersistedInventoryStatus(
    approvalState: value.device.approvalState,
    cordonState: value.device.cordonState,
    liveness: value.runner.liveness,
    reservationState: value.device.reservationState,
    snapshotObservedAtMS: value.runner.serverObservedAtMS,
    leaseExpiresAtMS: value.runner.capabilityLeaseExpiresAtMS,
    evaluatedAtMS: evaluatedAtMS,
    staleAfterMS: staleAfterMS,
  );
  if (status.error != null) {
    return ForgeDeviceInventoryPersistenceEvaluation.rejected(status.error);
  }
  return ForgeDeviceInventoryPersistenceEvaluation.acceptedProjection(
    ForgeDeviceInventoryPersistenceProjection(
      revision: value.revision,
      deviceID: value.device.deviceID,
      instanceID: value.runner.instanceID,
      status: status.status!,
      fresh: status.fresh!,
      declaredEligible: status.declaredEligible!,
    ),
  );
}

ForgeDeviceInventoryPersistenceEvaluation
evaluateForgeDeviceInventoryPersistenceCase(
  ForgeDeviceInventoryPersistenceFixture fixture,
  ForgeDeviceInventoryPersistenceCase testCase,
) {
  final state = fixture.state.withOverrides(
    revision: testCase.stateRevision,
    runnerDeviceID: testCase.runnerDeviceID,
    deviceApprovalState: testCase.deviceApprovalState,
    deviceCordonState: testCase.deviceCordonState,
    runnerLiveness: testCase.runnerLiveness,
  );
  switch (testCase.operation) {
    case 'restore':
      return restoreForgeDeviceInventory(
        revision: state.revision,
        device: state.device,
        runner: state.runner,
      );
    case 'commit':
      final replacement = testCase.replacement;
      final runner = state.runner.withOverrides(
        heartbeatSequence: replacement?.heartbeatSequence,
        serverObservedAtMS: replacement?.serverObservedAtMS,
        capabilityLeaseExpiresAtMS: replacement?.capabilityLeaseExpiresAtMS,
      );
      return commitForgeDeviceInventory(
        current: state,
        expectedRevision: testCase.expectedRevision!,
        device: state.device,
        runner: runner,
      );
    case 'project':
      final owner = switch (testCase.evaluationOwner) {
        'foreign' => ForgeDeviceOwner(
          issuer: state.device.owner.issuer,
          subject: 'other-user',
          tenantID: state.device.owner.tenantID,
        ),
        'invalid' => const ForgeDeviceOwner(
          issuer: '',
          subject: '',
          tenantID: '',
        ),
        _ => state.device.owner,
      };
      return projectForgeDeviceInventory(
        value: state,
        evaluationOwner: owner,
        evaluatedAtMS: testCase.evaluatedAtMS!,
        staleAfterMS: fixture.staleAfterMS,
      );
  }
  throw StateError('Unsupported persisted inventory operation.');
}

String? _validateForgeDeviceInventoryState(
  ForgeDeviceInventoryPersistenceState value,
) {
  if (value.revision == BigInt.zero) return 'invalid_persisted_state';
  final deviceError = _validateForgeDeviceInventoryDevice(value.device);
  if (deviceError != null) return deviceError;
  final runnerError = _validateForgeDeviceInventoryRunner(value.runner);
  if (runnerError != null) return runnerError;
  if (value.runner.deviceID != value.device.deviceID) {
    return 'runner_device_mismatch';
  }
  return null;
}

String? _validateForgeDeviceInventoryDevice(
  ForgeDeviceInventoryPersistenceDevice value,
) {
  if (!_inventoryPersistenceIdentifierValid(value.deviceID) ||
      !_inventoryPersistenceOwnerValid(value.owner) ||
      !_inventoryPersistenceAllowed(value.approvalState, const {
        'approved',
        'pending',
        'revoked',
      }) ||
      !_inventoryPersistenceAllowed(value.cordonState, const {
        'clear',
        'cordoned',
      }) ||
      !_inventoryPersistenceAllowed(value.reservationState, const {
        'none',
        'reserved',
      })) {
    return 'invalid_device_record';
  }
  return null;
}

String? _validateForgeDeviceInventoryRunner(
  ForgeDeviceInventoryPersistenceRunner value,
) {
  if (!_inventoryPersistenceIdentifierValid(value.deviceID) ||
      !_inventoryPersistenceIdentifierValid(value.instanceID) ||
      value.generation == BigInt.zero ||
      value.heartbeatSequence == BigInt.zero ||
      value.capabilityLeaseExpiresAtMS < value.serverObservedAtMS) {
    return 'invalid_runner_record';
  }
  final lease = value.capabilityLeaseExpiresAtMS - value.serverObservedAtMS;
  if (lease < _forgeDeviceInventoryPersistenceMinLeaseTTLMS ||
      lease > _forgeDeviceInventoryPersistenceMaxLeaseTTLMS ||
      !_inventoryPersistenceAllowed(value.liveness, const {
        'online',
        'offline',
      })) {
    return 'invalid_runner_record';
  }
  try {
    value.capabilities.canonicalized();
  } on FormatException {
    return 'invalid_runner_record';
  }
  return null;
}

class _ForgePersistedInventoryStatusResult {
  final String? error;
  final String? status;
  final bool? fresh;
  final bool? declaredEligible;

  const _ForgePersistedInventoryStatusResult.error(this.error)
    : status = null,
      fresh = null,
      declaredEligible = null;

  const _ForgePersistedInventoryStatusResult.value({
    required this.status,
    required this.fresh,
    required this.declaredEligible,
  }) : error = null;
}

_ForgePersistedInventoryStatusResult _projectForgePersistedInventoryStatus({
  required String approvalState,
  required String cordonState,
  required String liveness,
  required String reservationState,
  required BigInt snapshotObservedAtMS,
  required BigInt leaseExpiresAtMS,
  required BigInt evaluatedAtMS,
  required BigInt staleAfterMS,
}) {
  if (evaluatedAtMS == BigInt.zero) {
    return const _ForgePersistedInventoryStatusResult.error(
      'invalid_evaluation_time',
    );
  }
  if (staleAfterMS <= BigInt.zero ||
      staleAfterMS > BigInt.from(24 * 60 * 60 * 1000)) {
    return const _ForgePersistedInventoryStatusResult.error(
      'invalid_stale_after',
    );
  }
  if (snapshotObservedAtMS > evaluatedAtMS) {
    return const _ForgePersistedInventoryStatusResult.error(
      'snapshot_from_future',
    );
  }
  if (leaseExpiresAtMS < snapshotObservedAtMS) {
    return const _ForgePersistedInventoryStatusResult.error(
      'lease_before_snapshot',
    );
  }
  if (!_inventoryPersistenceAllowed(approvalState, const {
    'approved',
    'pending',
    'revoked',
  })) {
    return const _ForgePersistedInventoryStatusResult.error('unknown_approval');
  }
  if (!_inventoryPersistenceAllowed(cordonState, const {'clear', 'cordoned'})) {
    return const _ForgePersistedInventoryStatusResult.error('unknown_cordon');
  }
  if (!_inventoryPersistenceAllowed(liveness, const {'online', 'offline'})) {
    return const _ForgePersistedInventoryStatusResult.error('unknown_liveness');
  }
  if (!_inventoryPersistenceAllowed(reservationState, const {
    'none',
    'reserved',
  })) {
    return const _ForgePersistedInventoryStatusResult.error(
      'unknown_reservation',
    );
  }
  final age = evaluatedAtMS - snapshotObservedAtMS;
  final fresh = age <= staleAfterMS && leaseExpiresAtMS > evaluatedAtMS;
  var status = 'online';
  if (approvalState == 'revoked') {
    status = 'revoked';
  } else if (cordonState == 'cordoned') {
    status = 'cordoned';
  } else if (liveness == 'offline') {
    status = 'offline';
  } else if (!fresh) {
    status = 'stale';
  } else if (approvalState == 'pending') {
    status = 'pending';
  } else if (reservationState == 'reserved') {
    status = 'reserved';
  }
  return _ForgePersistedInventoryStatusResult.value(
    status: status,
    fresh: fresh,
    declaredEligible: status == 'online',
  );
}

const _forgeDeviceInventoryPersistenceErrors = {
  'revision_conflict',
  'invalid_persisted_state',
  'revision_overflow',
  'invalid_device_record',
  'invalid_runner_record',
  'runner_device_mismatch',
  'owner_mismatch',
  'device_binding_changed',
  'invalid_evaluation_owner',
};

Map<String, dynamic> _inventoryPersistenceObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge persisted inventory object.');
  }
  return Map<String, dynamic>.from(value);
}

void _inventoryPersistenceExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge persisted inventory fields.');
  }
}

bool _inventoryPersistenceBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge persisted inventory bool.');
  }
  return value;
}

String _inventoryPersistenceText(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge persisted inventory text.');
  }
  return value;
}

String _inventoryPersistenceIdentifier(Object? value) {
  final text = _inventoryPersistenceText(value);
  if (!_inventoryPersistenceIdentifierValid(text)) {
    throw const FormatException(
      'Invalid Forge persisted inventory identifier.',
    );
  }
  return text;
}

bool _inventoryPersistenceIdentifierValid(String value) {
  if (value.isEmpty || value.length > 128) return false;
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x3a ||
      code == 0x2d;
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

bool _inventoryPersistenceOwnerValid(ForgeDeviceOwner owner) {
  bool validPart(String value) =>
      value.isNotEmpty &&
      utf8.encode(value).length <= 512 &&
      value.trim() == value &&
      !value.runes.any(
        (rune) => rune <= 0x1f || (rune >= 0x7f && rune <= 0x9f),
      );
  return validPart(owner.issuer) &&
      validPart(owner.subject) &&
      validPart(owner.tenantID);
}

String _inventoryPersistenceOneOf(Object? value, Set<String> allowed) {
  final text = _inventoryPersistenceText(value);
  if (!allowed.contains(text)) {
    throw const FormatException('Invalid Forge persisted inventory state.');
  }
  return text;
}

bool _inventoryPersistenceAllowed(String value, Set<String> allowed) =>
    allowed.contains(value);

bool _inventoryPersistenceCapabilitiesCanonical(
  Object? rawValue,
  ForgeDeviceHeartbeatReferenceCapabilities canonical,
) {
  final json = _inventoryPersistenceObject(rawValue);
  if (json['os'] != canonical.os ||
      json['architecture'] != canonical.architecture ||
      !_inventoryPersistenceSameUint64(json['cpu_cores'], canonical.cpuCores) ||
      !_inventoryPersistenceSameUint64(
        json['available_cpu_cores'],
        canonical.availableCPUCores,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['memory_bytes'],
        canonical.memoryBytes,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['available_memory_bytes'],
        canonical.availableMemoryBytes,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['storage_bytes'],
        canonical.storageBytes,
      ) ||
      !_inventoryPersistenceSameUint64(
        json['available_storage_bytes'],
        canonical.availableStorageBytes,
      )) {
    return false;
  }
  final rawRuntimes = json['runtimes'];
  if (rawRuntimes is! List || rawRuntimes.length != canonical.runtimes.length) {
    return false;
  }
  for (var index = 0; index < rawRuntimes.length; index++) {
    if (rawRuntimes[index] != canonical.runtimes[index]) return false;
  }
  if (!json.containsKey('gpus')) return canonical.gpus.isEmpty;
  final rawGPUs = json['gpus'];
  if (rawGPUs is! List || rawGPUs.length != canonical.gpus.length) {
    return false;
  }
  for (var index = 0; index < rawGPUs.length; index++) {
    final rawGPU = _inventoryPersistenceObject(rawGPUs[index]);
    final canonicalGPU = canonical.gpus[index];
    if (rawGPU['id'] != canonicalGPU.id ||
        rawGPU['vendor'] != canonicalGPU.vendor ||
        !_inventoryPersistenceSameUint64(
          rawGPU['memory_bytes'],
          canonicalGPU.memoryBytes,
        ) ||
        !_inventoryPersistenceSameUint64(
          rawGPU['available_memory_bytes'],
          canonicalGPU.availableMemoryBytes,
        )) {
      return false;
    }
  }
  return true;
}

bool _inventoryPersistenceSameUint64(Object? raw, BigInt canonical) {
  try {
    return _inventoryPersistenceUint64(raw) == canonical;
  } on FormatException {
    return false;
  }
}

BigInt _inventoryPersistenceUint64(Object? value) {
  final number = value is BigInt
      ? value
      : value is int
      ? BigInt.from(value)
      : null;
  if (number == null ||
      number < BigInt.zero ||
      number > _forgeDeviceInventoryPersistenceMaxUint64) {
    throw const FormatException('Invalid Forge persisted inventory uint64.');
  }
  return number;
}

BigInt _inventoryPersistencePositiveUint64(Object? value) {
  final number = _inventoryPersistenceUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException(
      'Invalid Forge persisted inventory positive uint64.',
    );
  }
  return number;
}

Object? _restoreForgeDeviceInventoryPersistenceUint64Markers(Object? value) {
  if (value is String &&
      value == _forgeDeviceInventoryPersistenceMaxUint64Marker) {
    return _forgeDeviceInventoryPersistenceMaxUint64;
  }
  if (value is List) {
    return value
        .map(_restoreForgeDeviceInventoryPersistenceUint64Markers)
        .toList(growable: false);
  }
  if (value is Map) {
    return Map<String, dynamic>.fromEntries(
      value.entries.map(
        (entry) => MapEntry(
          entry.key as String,
          _restoreForgeDeviceInventoryPersistenceUint64Markers(entry.value),
        ),
      ),
    );
  }
  return value;
}
