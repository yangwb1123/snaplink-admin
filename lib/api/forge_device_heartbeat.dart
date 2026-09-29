import 'dart:convert';

part 'forge_device_heartbeat_codec.dart';
part 'forge_device_heartbeat_capability_validation.dart';
part 'forge_device_heartbeat_fixture.dart';

/// Pure Runner-heartbeat sequencing values for the future Forge inventory
/// boundary. No clock, network, persistence, retry, or authority is used.
const forgeDeviceHeartbeatSchema = 'forge.device-heartbeat-contract/v1';
const forgeDeviceHeartbeatEvaluationMode = 'pure_reference_only';
const forgeDeviceHeartbeatReferenceMinLeaseTTLMS = 1000;
const forgeDeviceHeartbeatReferenceMaxLeaseTTLMS = 600000;
const forgeDeviceHeartbeatNotice =
    'This fixture checks caller-supplied heartbeat sequencing only. It does not authenticate a device, read a clock, persist a heartbeat, publish authoritative inventory, reserve capacity, authorize execution, or dispatch a task.';
final _forgeHeartbeatMaxUint64 = (BigInt.one << 64) - BigInt.one;

class ForgeDeviceHeartbeatAuthority {
  final bool identityVerified;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool executionAuthorized;
  final bool reservationCreated;
  final bool dispatchPerformed;

  const ForgeDeviceHeartbeatAuthority({
    required this.identityVerified,
    required this.heartbeatPersisted,
    required this.inventoryAuthoritative,
    required this.executionAuthorized,
    required this.reservationCreated,
    required this.dispatchPerformed,
  });

  bool get anyGranted =>
      identityVerified ||
      heartbeatPersisted ||
      inventoryAuthoritative ||
      executionAuthorized ||
      reservationCreated ||
      dispatchPerformed;

  factory ForgeDeviceHeartbeatAuthority.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    _heartbeatReferenceExactKeys(json, {
      'identity_verified',
      'heartbeat_persisted',
      'inventory_authoritative',
      'execution_authorized',
      'reservation_created',
      'dispatch_performed',
    });
    final authority = ForgeDeviceHeartbeatAuthority(
      identityVerified: _heartbeatReferenceBool(json['identity_verified']),
      heartbeatPersisted: _heartbeatReferenceBool(json['heartbeat_persisted']),
      inventoryAuthoritative: _heartbeatReferenceBool(
        json['inventory_authoritative'],
      ),
      executionAuthorized: _heartbeatReferenceBool(
        json['execution_authorized'],
      ),
      reservationCreated: _heartbeatReferenceBool(json['reservation_created']),
      dispatchPerformed: _heartbeatReferenceBool(json['dispatch_performed']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge heartbeat reference authority must remain false.',
      );
    }
    return authority;
  }
}

class ForgeDeviceHeartbeatReferenceDevice {
  final String deviceID;
  final String tenantID;
  final String approvalState;

  const ForgeDeviceHeartbeatReferenceDevice({
    required this.deviceID,
    required this.tenantID,
    required this.approvalState,
  });

  factory ForgeDeviceHeartbeatReferenceDevice.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    _heartbeatReferenceExactKeys(json, {
      'device_id',
      'tenant_id',
      'approval_state',
    });
    final approval = _heartbeatReferenceText(json['approval_state']);
    if (!const {'approved', 'pending', 'revoked'}.contains(approval)) {
      throw const FormatException('Invalid Forge heartbeat approval state.');
    }
    return ForgeDeviceHeartbeatReferenceDevice(
      deviceID: _heartbeatReferenceIdentifier(json['device_id']),
      tenantID: _heartbeatReferenceIdentifier(json['tenant_id']),
      approvalState: approval,
    );
  }
}

class ForgeDeviceHeartbeatSignal {
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt sequence;
  final ForgeDeviceHeartbeatReferenceCapabilities? capabilities;

  const ForgeDeviceHeartbeatSignal({
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.sequence,
    this.capabilities,
  });

  factory ForgeDeviceHeartbeatSignal.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    final expectedKeys = {'device_id', 'instance_id', 'generation', 'sequence'};
    if (json.containsKey('capabilities')) expectedKeys.add('capabilities');
    _heartbeatReferenceExactKeys(json, expectedKeys);
    return ForgeDeviceHeartbeatSignal(
      deviceID: _heartbeatReferenceIdentifier(json['device_id']),
      instanceID: _heartbeatReferenceIdentifier(json['instance_id']),
      generation: _heartbeatReferencePositiveUint64(json['generation']),
      sequence: _heartbeatReferencePositiveUint64(json['sequence']),
      capabilities: json.containsKey('capabilities')
          ? ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
              json['capabilities'],
            )
          : null,
    );
  }

  ForgeDeviceHeartbeatSignal withCapabilities(
    ForgeDeviceHeartbeatReferenceCapabilities value,
  ) => ForgeDeviceHeartbeatSignal(
    deviceID: deviceID,
    instanceID: instanceID,
    generation: generation,
    sequence: sequence,
    capabilities: value,
  );
}

class ForgeDeviceHeartbeatInstance {
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt heartbeatSequence;
  final BigInt serverObservedAtMS;
  final BigInt capabilityLeaseExpiresAtMS;
  final ForgeDeviceHeartbeatReferenceCapabilities? capabilities;

  const ForgeDeviceHeartbeatInstance({
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
    this.capabilities,
  });

  factory ForgeDeviceHeartbeatInstance.fromJson(Object? value) {
    final json = _heartbeatReferenceObject(value);
    final expectedKeys = {
      'device_id',
      'instance_id',
      'generation',
      'heartbeat_sequence',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
    };
    if (json.containsKey('capabilities')) expectedKeys.add('capabilities');
    _heartbeatReferenceExactKeys(json, expectedKeys);
    return ForgeDeviceHeartbeatInstance(
      deviceID: _heartbeatReferenceIdentifier(json['device_id']),
      instanceID: _heartbeatReferenceIdentifier(json['instance_id']),
      generation: _heartbeatReferencePositiveUint64(json['generation']),
      heartbeatSequence: _heartbeatReferencePositiveUint64(
        json['heartbeat_sequence'],
      ),
      serverObservedAtMS: _heartbeatReferenceUint64(
        json['server_observed_at_ms'],
      ),
      capabilityLeaseExpiresAtMS: _heartbeatReferenceUint64(
        json['capability_lease_expires_at_ms'],
      ),
      capabilities: json.containsKey('capabilities')
          ? ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
              json['capabilities'],
            )
          : null,
    );
  }

  ForgeDeviceHeartbeatInstance withCapabilities(
    ForgeDeviceHeartbeatReferenceCapabilities value,
  ) => ForgeDeviceHeartbeatInstance(
    deviceID: deviceID,
    instanceID: instanceID,
    generation: generation,
    heartbeatSequence: heartbeatSequence,
    serverObservedAtMS: serverObservedAtMS,
    capabilityLeaseExpiresAtMS: capabilityLeaseExpiresAtMS,
    capabilities: value,
  );
}

class ForgeDeviceHeartbeatOutcome {
  final bool accepted;
  final String? error;
  final ForgeDeviceHeartbeatInstance? instance;

  const ForgeDeviceHeartbeatOutcome.accepted(this.instance)
    : accepted = true,
      error = null;

  const ForgeDeviceHeartbeatOutcome.rejected(this.error)
    : accepted = false,
      instance = null;
}

/// Applies one caller-supplied heartbeat to an optional observed instance.
/// This computes a value only; it never persists or publishes the result.
ForgeDeviceHeartbeatOutcome applyForgeDeviceHeartbeat({
  required ForgeDeviceHeartbeatReferenceDevice device,
  required ForgeDeviceHeartbeatInstance? current,
  required ForgeDeviceHeartbeatSignal heartbeat,
  required BigInt serverObservedAtMS,
  required BigInt leaseTTLMS,
}) {
  final heartbeatCapabilities = heartbeat.capabilities;
  if (heartbeatCapabilities == null) {
    return const ForgeDeviceHeartbeatOutcome.rejected(
      'invalid_capability_value',
    );
  }
  try {
    final capabilities = heartbeatCapabilities.canonicalized();
    if (current != null && current.capabilities == null) {
      return const ForgeDeviceHeartbeatOutcome.rejected(
        'invalid_capability_value',
      );
    }
    current?.capabilities?.canonicalized();
    return _applyForgeDeviceHeartbeatWithCapabilities(
      capabilities: capabilities,
      device: device,
      current: current,
      heartbeat: heartbeat,
      serverObservedAtMS: serverObservedAtMS,
      leaseTTLMS: leaseTTLMS,
    );
  } on FormatException {
    return const ForgeDeviceHeartbeatOutcome.rejected(
      'invalid_capability_value',
    );
  }
}

ForgeDeviceHeartbeatOutcome _applyForgeDeviceHeartbeatWithCapabilities({
  required ForgeDeviceHeartbeatReferenceCapabilities capabilities,
  required ForgeDeviceHeartbeatReferenceDevice device,
  required ForgeDeviceHeartbeatInstance? current,
  required ForgeDeviceHeartbeatSignal heartbeat,
  required BigInt serverObservedAtMS,
  required BigInt leaseTTLMS,
}) {
  if (heartbeat.deviceID != device.deviceID) {
    return const ForgeDeviceHeartbeatOutcome.rejected('device_mismatch');
  }
  if (device.approvalState == 'revoked') {
    return const ForgeDeviceHeartbeatOutcome.rejected('device_revoked');
  }
  final ttl = BigInt.from(forgeDeviceHeartbeatReferenceMinLeaseTTLMS);
  final maxTTL = BigInt.from(forgeDeviceHeartbeatReferenceMaxLeaseTTLMS);
  if (leaseTTLMS < ttl || leaseTTLMS > maxTTL) {
    return const ForgeDeviceHeartbeatOutcome.rejected('invalid_lease_duration');
  }
  final error = _heartbeatReferenceIncarnationError(
    device: device,
    current: current,
    heartbeat: heartbeat,
    serverObservedAtMS: serverObservedAtMS,
  );
  if (error != null) {
    return ForgeDeviceHeartbeatOutcome.rejected(error);
  }
  if (serverObservedAtMS > _forgeHeartbeatMaxUint64 - leaseTTLMS) {
    return const ForgeDeviceHeartbeatOutcome.rejected('lease_expiry_overflow');
  }
  return ForgeDeviceHeartbeatOutcome.accepted(
    ForgeDeviceHeartbeatInstance(
      deviceID: heartbeat.deviceID,
      instanceID: heartbeat.instanceID,
      generation: heartbeat.generation,
      heartbeatSequence: heartbeat.sequence,
      serverObservedAtMS: serverObservedAtMS,
      capabilityLeaseExpiresAtMS: serverObservedAtMS + leaseTTLMS,
      capabilities: capabilities,
    ),
  );
}

String? _heartbeatReferenceIncarnationError({
  required ForgeDeviceHeartbeatReferenceDevice device,
  required ForgeDeviceHeartbeatInstance? current,
  required ForgeDeviceHeartbeatSignal heartbeat,
  required BigInt serverObservedAtMS,
}) {
  if (current == null) {
    if (heartbeat.generation != BigInt.one) {
      return 'generation_must_start_at_one';
    }
    if (heartbeat.sequence != BigInt.one) {
      return 'sequence_must_start_at_one';
    }
    return null;
  }
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
    return null;
  }
  if (current.generation == _forgeHeartbeatMaxUint64 ||
      heartbeat.generation != current.generation + BigInt.one) {
    return 'generation_skipped';
  }
  if (heartbeat.sequence != BigInt.one) {
    return 'sequence_must_start_at_one';
  }
  return null;
}

/// Decodes heartbeat JSON while preserving the contract's full uint64 range.
Object? decodeForgeDeviceHeartbeatJSON(String source) {
  return _restoreForgeHeartbeatUint64Markers(
    jsonDecode(_markForgeHeartbeatMaxUint64(source)),
  );
}
