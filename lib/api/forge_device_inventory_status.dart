// Effect-free display projection for the Forge inventory status contract.
//
// This module consumes caller-declared values at a fixed evaluation time. It
// never reads a clock, persists a heartbeat, reserves capacity, or authorizes
// execution.

const forgeDeviceInventoryDefaultStaleAfterMS = 90000;
const forgeDeviceInventoryMaxStaleAfterMS = 24 * 60 * 60 * 1000;

const forgeDeviceInventoryStatusOnline = 'online';
const forgeDeviceInventoryStatusPending = 'pending';
const forgeDeviceInventoryStatusStale = 'stale';
const forgeDeviceInventoryStatusOffline = 'offline';
const forgeDeviceInventoryStatusReserved = 'reserved';
const forgeDeviceInventoryStatusCordoned = 'cordoned';
const forgeDeviceInventoryStatusRevoked = 'revoked';

const _maxSafeForgeDeviceInteger = 9007199254740991;

class ForgeDeviceInventoryStatusObservation {
  final String approvalState;
  final String cordonState;
  final String liveness;
  final String reservationState;
  final int snapshotObservedAtMS;
  final int leaseExpiresAtMS;
  final int evaluatedAtMS;

  const ForgeDeviceInventoryStatusObservation({
    required this.approvalState,
    required this.cordonState,
    required this.liveness,
    required this.reservationState,
    required this.snapshotObservedAtMS,
    required this.leaseExpiresAtMS,
    required this.evaluatedAtMS,
  });

  factory ForgeDeviceInventoryStatusObservation.fromJson(Object? value) {
    final json = _object(value);
    _exactKeys(json, {
      'approval_state',
      'cordon_state',
      'liveness',
      'reservation_state',
      'snapshot_observed_at_ms',
      'lease_expires_at_ms',
      'evaluated_at_ms',
    });
    return ForgeDeviceInventoryStatusObservation(
      approvalState: _text(json['approval_state']),
      cordonState: _text(json['cordon_state']),
      liveness: _text(json['liveness']),
      reservationState: _text(json['reservation_state']),
      snapshotObservedAtMS: _uint64(json['snapshot_observed_at_ms']),
      leaseExpiresAtMS: _uint64(json['lease_expires_at_ms']),
      evaluatedAtMS: _uint64(json['evaluated_at_ms']),
    );
  }
}

class ForgeDeviceInventoryStatusProjection {
  final String status;
  final bool fresh;
  final bool declaredEligible;

  const ForgeDeviceInventoryStatusProjection({
    required this.status,
    required this.fresh,
    required this.declaredEligible,
  });
}

class ForgeDeviceInventoryStatusError implements Exception {
  final String code;

  const ForgeDeviceInventoryStatusError(this.code);

  @override
  String toString() => code;
}

/// Classifies one inventory declaration without reading a clock or mutating
/// state. `declaredEligible` is a display projection only; it is not a
/// scheduler, reservation, or execution decision.
ForgeDeviceInventoryStatusProjection projectForgeDeviceInventoryStatus(
  ForgeDeviceInventoryStatusObservation observation, {
  int staleAfterMS = forgeDeviceInventoryDefaultStaleAfterMS,
}) {
  if (observation.evaluatedAtMS == 0) {
    throw const ForgeDeviceInventoryStatusError('invalid_evaluation_time');
  }
  if (staleAfterMS <= 0 || staleAfterMS > forgeDeviceInventoryMaxStaleAfterMS) {
    throw const ForgeDeviceInventoryStatusError('invalid_stale_after');
  }
  if (observation.snapshotObservedAtMS > observation.evaluatedAtMS) {
    throw const ForgeDeviceInventoryStatusError('snapshot_from_future');
  }
  if (observation.leaseExpiresAtMS < observation.snapshotObservedAtMS) {
    throw const ForgeDeviceInventoryStatusError('lease_before_snapshot');
  }
  if (!_oneOf(observation.approvalState, {'approved', 'pending', 'revoked'})) {
    throw const ForgeDeviceInventoryStatusError('unknown_approval');
  }
  if (!_oneOf(observation.cordonState, {'clear', 'cordoned'})) {
    throw const ForgeDeviceInventoryStatusError('unknown_cordon');
  }
  if (!_oneOf(observation.liveness, {'online', 'offline'})) {
    throw const ForgeDeviceInventoryStatusError('unknown_liveness');
  }
  if (!_oneOf(observation.reservationState, {'none', 'reserved'})) {
    throw const ForgeDeviceInventoryStatusError('unknown_reservation');
  }

  final age = observation.evaluatedAtMS - observation.snapshotObservedAtMS;
  final fresh =
      age <= staleAfterMS &&
      observation.leaseExpiresAtMS > observation.evaluatedAtMS;
  var status = forgeDeviceInventoryStatusOnline;
  if (observation.approvalState == 'revoked') {
    status = forgeDeviceInventoryStatusRevoked;
  } else if (observation.cordonState == 'cordoned') {
    status = forgeDeviceInventoryStatusCordoned;
  } else if (observation.liveness == 'offline') {
    status = forgeDeviceInventoryStatusOffline;
  } else if (!fresh) {
    status = forgeDeviceInventoryStatusStale;
  } else if (observation.approvalState == 'pending') {
    status = forgeDeviceInventoryStatusPending;
  } else if (observation.reservationState == 'reserved') {
    status = forgeDeviceInventoryStatusReserved;
  }
  return ForgeDeviceInventoryStatusProjection(
    status: status,
    fresh: fresh,
    declaredEligible: status == forgeDeviceInventoryStatusOnline,
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge inventory status object.');
  }
  return Map<String, dynamic>.from(value);
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge inventory status fields.');
  }
}

String _text(Object? value) {
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw const FormatException('Invalid Forge inventory status text.');
  }
  return value;
}

int _uint64(Object? value) {
  if (value is! int || value < 0 || value > _maxSafeForgeDeviceInteger) {
    throw const FormatException('Invalid Forge inventory status timestamp.');
  }
  return value;
}

bool _oneOf(String value, Set<String> allowed) => allowed.contains(value);
