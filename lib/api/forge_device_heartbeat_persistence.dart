import 'dart:convert';

import 'forge_device_heartbeat.dart';

export 'forge_device_heartbeat.dart';

part 'forge_device_heartbeat_persistence_codec.dart';
part 'forge_device_heartbeat_persistence_declarations.dart';
part 'forge_device_heartbeat_persistence_fixture.dart';

/// Pure value-level compare-and-swap planning for a future Forge heartbeat
/// store. This module has no clock, network, storage, retry, or authority.

const forgeDeviceHeartbeatPersistenceSchema =
    'forge.device-heartbeat-persistence-contract/v1';
const forgeDeviceHeartbeatPersistenceEvaluationMode =
    'pure_compare_and_swap_plan';
final forgeDeviceHeartbeatMinLeaseTTLMS = BigInt.from(1000);
final forgeDeviceHeartbeatMaxLeaseTTLMS = BigInt.from(600000);
final _forgeDeviceHeartbeatMaxUint64 = (BigInt.one << 64) - BigInt.one;
const _forgeDeviceHeartbeatMaxUint64Literal = '18446744073709551615';
const _forgeDeviceHeartbeatMaxUint64Marker = '__forge_u64_max__';

class ForgeDeviceHeartbeatPersistenceOutcome {
  final bool accepted;
  final String? error;
  final ForgeDeviceHeartbeatPersistenceState? state;

  const ForgeDeviceHeartbeatPersistenceOutcome.accepted(this.state)
    : accepted = true,
      error = null;

  const ForgeDeviceHeartbeatPersistenceOutcome.rejected(this.error)
    : accepted = false,
      state = null;
}

/// Computes the complete replacement value for a future CAS transaction.
/// This function deliberately performs no write, retry, clock read, or auth.
ForgeDeviceHeartbeatPersistenceOutcome commitForgeDeviceHeartbeat({
  required ForgeDeviceHeartbeatPersistenceDevice device,
  required ForgeDeviceHeartbeatPersistenceState? current,
  required BigInt expectedRevision,
  required ForgeDeviceHeartbeat heartbeat,
  required BigInt serverObservedAtMS,
  required BigInt leaseTTLMS,
}) {
  final actualRevision = current?.revision ?? BigInt.zero;
  if (current != null && current.revision == BigInt.zero) {
    return const ForgeDeviceHeartbeatPersistenceOutcome.rejected(
      'invalid_persisted_state',
    );
  }
  if (expectedRevision != actualRevision) {
    return const ForgeDeviceHeartbeatPersistenceOutcome.rejected(
      'revision_conflict',
    );
  }
  if (actualRevision == _forgeDeviceHeartbeatMaxUint64) {
    return const ForgeDeviceHeartbeatPersistenceOutcome.rejected(
      'revision_overflow',
    );
  }
  final heartbeatCapabilities = heartbeat.capabilities;
  if (heartbeatCapabilities == null ||
      (current != null && current.capabilities == null)) {
    return const ForgeDeviceHeartbeatPersistenceOutcome.rejected(
      'invalid_capability_value',
    );
  }
  late final ForgeDeviceHeartbeatReferenceCapabilities capabilities;
  try {
    capabilities = heartbeatCapabilities.canonicalized();
    current?.capabilities?.canonicalized();
  } on FormatException {
    return const ForgeDeviceHeartbeatPersistenceOutcome.rejected(
      'invalid_capability_value',
    );
  }

  final error = _heartbeatApplyError(
    device: device,
    current: current,
    heartbeat: heartbeat,
    serverObservedAtMS: serverObservedAtMS,
    leaseTTLMS: leaseTTLMS,
  );
  if (error != null) {
    return ForgeDeviceHeartbeatPersistenceOutcome.rejected(error);
  }
  final expiresAtMS = serverObservedAtMS + leaseTTLMS;
  return ForgeDeviceHeartbeatPersistenceOutcome.accepted(
    ForgeDeviceHeartbeatPersistenceState(
      revision: actualRevision + BigInt.one,
      deviceID: heartbeat.deviceID,
      instanceID: heartbeat.instanceID,
      generation: heartbeat.generation,
      heartbeatSequence: heartbeat.sequence,
      serverObservedAtMS: serverObservedAtMS,
      capabilityLeaseExpiresAtMS: expiresAtMS,
      capabilities: capabilities,
    ),
  );
}

String? _heartbeatApplyError({
  required ForgeDeviceHeartbeatPersistenceDevice device,
  required ForgeDeviceHeartbeatPersistenceState? current,
  required ForgeDeviceHeartbeat heartbeat,
  required BigInt serverObservedAtMS,
  required BigInt leaseTTLMS,
}) {
  if (heartbeat.deviceID != device.deviceID) return 'device_mismatch';
  if (device.approvalState == 'revoked') return 'device_revoked';
  if (leaseTTLMS < forgeDeviceHeartbeatMinLeaseTTLMS ||
      leaseTTLMS > forgeDeviceHeartbeatMaxLeaseTTLMS) {
    return 'invalid_lease_duration';
  }
  if (current == null) {
    if (heartbeat.generation != BigInt.one) {
      return 'generation_must_start_at_one';
    }
    if (heartbeat.sequence != BigInt.one) {
      return 'sequence_must_start_at_one';
    }
  } else {
    if (current.deviceID != device.deviceID) return 'device_mismatch';
    if (serverObservedAtMS < current.serverObservedAtMS) {
      return 'server_time_went_backwards';
    }
    if (heartbeat.generation < current.generation) return 'old_generation';
    if (heartbeat.generation == current.generation) {
      if (heartbeat.instanceID != current.instanceID) {
        return 'instance_changed_within_generation';
      }
      if (heartbeat.sequence <= current.heartbeatSequence) {
        return 'sequence_not_increasing';
      }
    } else {
      if (current.generation == _forgeDeviceHeartbeatMaxUint64 ||
          heartbeat.generation != current.generation + BigInt.one) {
        return 'generation_skipped';
      }
      if (heartbeat.sequence != BigInt.one) {
        return 'sequence_must_start_at_one';
      }
    }
  }
  if (serverObservedAtMS > _forgeDeviceHeartbeatMaxUint64 - leaseTTLMS) {
    return 'lease_expiry_overflow';
  }
  return null;
}
