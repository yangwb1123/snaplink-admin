import 'dart:convert';

import 'forge_device_heartbeat.dart';
import 'forge_device_inventory_declaration.dart';

export 'forge_device_heartbeat.dart';
export 'forge_device_inventory_declaration.dart';

part 'forge_device_inventory_persistence_fixtures.dart';
part 'forge_device_inventory_persistence_projection.dart';
part 'forge_device_inventory_persistence_codec.dart';

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
