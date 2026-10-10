part of 'forge_device_inventory_persistence.dart';

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
