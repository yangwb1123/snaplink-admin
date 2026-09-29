import 'dart:convert';

import 'forge_device_inventory_persistence.dart';

part 'forge_device_enrollment_heartbeat_lifecycle_registry_validation.dart';

/// The complete owner-scoped lifecycle registry envelope returned by the
/// candidate Core reader. It is a read-only observation: the client does not
/// enroll a device, accept a heartbeat, publish inventory, reserve capacity,
/// schedule, dispatch, or execute work.
const forgeDeviceEnrollmentHeartbeatLifecycleRegistrySchema =
    'forge.device-enrollment-heartbeat-lifecycle-file-set/v1';
const forgeDeviceEnrollmentHeartbeatLifecycleRegistryMaxStates = 128;
const forgeDeviceEnrollmentHeartbeatLifecycleRegistryMaxSafeInteger =
    9007199254740991;

/// A bounded, owner-bound lifecycle row. Core owns the complete nested state
/// schema; Flutter validates the stable row envelope and identity/revision
/// joins, then preserves the nested value for a later read-only projection.
/// Keeping the row opaque here avoids duplicating lifecycle transition logic
/// in each Web/App/Mobile client while still rejecting ambiguous or foreign
/// rows at the transport boundary.
class ForgeLifecycleRegistryStateRow {
  final BigInt revision;
  final ForgeDeviceOwner owner;
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt heartbeatSequence;
  final String approvalState;
  final String credentialState;
  final String cordonState;
  final String reservationState;
  final String liveness;
  final Map<String, dynamic> _value;

  const ForgeLifecycleRegistryStateRow._({
    required this.revision,
    required this.owner,
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.heartbeatSequence,
    required this.approvalState,
    required this.credentialState,
    required this.cordonState,
    required this.reservationState,
    required this.liveness,
    required Map<String, dynamic> value,
  }) : _value = value;

  factory ForgeLifecycleRegistryStateRow.fromJson(Object? value) {
    final json = _lifecycleRegistryObject(value, 'state');
    _lifecycleRegistryExactKeys(json, {
      'revision',
      'owner',
      'device',
      'heartbeat',
      'inventory',
    });

    final revision = _lifecycleRegistryPositiveSafeInteger(
      json['revision'],
      'state revision',
    );
    final owner = ForgeDeviceOwner.fromJson(json['owner']);

    final deviceJSON = _lifecycleRegistryObject(json['device'], 'device');
    _lifecycleRegistryExactKeys(deviceJSON, {
      'device_id',
      'owner',
      'key_id',
      'public_key_sha256',
      'approval_state',
      'credential_state',
    });
    final deviceOwner = ForgeDeviceOwner.fromJson(deviceJSON['owner']);
    final deviceID = _lifecycleRegistryIdentifier(
      deviceJSON['device_id'],
      'device ID',
    );
    if (deviceOwner != owner) {
      throw const FormatException(
        'Forge lifecycle state device owner does not match envelope owner.',
      );
    }
    _lifecycleRegistryIdentifier(deviceJSON['key_id'], 'key ID');
    _lifecycleRegistryDigest(
      deviceJSON['public_key_sha256'],
      'public key digest',
    );
    final approvalState = _lifecycleRegistryOneOf(
      deviceJSON['approval_state'],
      const {'pending', 'approved', 'revoked'},
      'approval state',
    );
    final credentialState = _lifecycleRegistryOneOf(
      deviceJSON['credential_state'],
      const {'active', 'expired', 'revoked'},
      'credential state',
    );

    final heartbeatJSON = _lifecycleRegistryObject(
      json['heartbeat'],
      'heartbeat',
    );
    _lifecycleRegistryExactKeys(heartbeatJSON, {'revision', 'instance'});
    final heartbeatRevision = _lifecycleRegistryPositiveSafeInteger(
      heartbeatJSON['revision'],
      'heartbeat revision',
    );
    final instanceJSON = _lifecycleRegistryObject(
      heartbeatJSON['instance'],
      'heartbeat instance',
    );
    _lifecycleRegistryExactKeys(instanceJSON, {
      'device_id',
      'instance_id',
      'generation',
      'heartbeat_sequence',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
      'capabilities',
    });
    final heartbeatDeviceID = _lifecycleRegistryIdentifier(
      instanceJSON['device_id'],
      'heartbeat device ID',
    );
    final instanceID = _lifecycleRegistryIdentifier(
      instanceJSON['instance_id'],
      'Runner instance ID',
    );
    final generation = _lifecycleRegistryPositiveSafeInteger(
      instanceJSON['generation'],
      'Runner generation',
    );
    final heartbeatSequence = _lifecycleRegistryPositiveSafeInteger(
      instanceJSON['heartbeat_sequence'],
      'heartbeat sequence',
    );
    final serverObservedAtMS = _lifecycleRegistrySafeInteger(
      instanceJSON['server_observed_at_ms'],
      'server observed time',
    );
    final capabilityLeaseExpiresAtMS = _lifecycleRegistrySafeInteger(
      instanceJSON['capability_lease_expires_at_ms'],
      'capability lease expiry',
    );
    if (capabilityLeaseExpiresAtMS < serverObservedAtMS ||
        capabilityLeaseExpiresAtMS - serverObservedAtMS < BigInt.from(1000) ||
        capabilityLeaseExpiresAtMS - serverObservedAtMS > BigInt.from(600000)) {
      throw const FormatException(
        'Forge lifecycle state has an invalid capability lease.',
      );
    }
    final heartbeatCapabilities =
        ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
          instanceJSON['capabilities'],
        );
    _lifecycleRegistryRequireCanonicalCapabilities(
      instanceJSON['capabilities'],
      heartbeatCapabilities,
    );

    final inventory = ForgeDeviceInventoryPersistenceState.fromJson(
      json['inventory'],
    );
    final inventoryOwner = inventory.device.owner;
    if (inventoryOwner != owner) {
      throw const FormatException(
        'Forge lifecycle state inventory owner does not match envelope owner.',
      );
    }
    if (revision != heartbeatRevision || revision != inventory.revision) {
      throw const FormatException(
        'Forge lifecycle state revisions are not joined.',
      );
    }
    if (heartbeatDeviceID != deviceID ||
        inventory.device.deviceID != deviceID ||
        inventory.runner.deviceID != deviceID ||
        inventory.runner.instanceID != instanceID ||
        inventory.runner.generation != generation ||
        inventory.runner.heartbeatSequence != heartbeatSequence ||
        inventory.runner.serverObservedAtMS != serverObservedAtMS ||
        inventory.runner.capabilityLeaseExpiresAtMS !=
            capabilityLeaseExpiresAtMS ||
        inventory.device.approvalState != approvalState ||
        !_sameLifecycleCapabilities(
          heartbeatCapabilities,
          inventory.runner.capabilities,
        )) {
      throw const FormatException(
        'Forge lifecycle state identity or observation join changed.',
      );
    }
    final cordonState = inventory.device.cordonState;
    final reservationState = inventory.device.reservationState;
    final liveness = inventory.runner.liveness;

    return ForgeLifecycleRegistryStateRow._(
      revision: revision,
      owner: owner,
      deviceID: deviceID,
      instanceID: instanceID,
      generation: generation,
      heartbeatSequence: heartbeatSequence,
      approvalState: approvalState,
      credentialState: credentialState,
      cordonState: cordonState,
      reservationState: reservationState,
      liveness: liveness,
      value: _lifecycleRegistryDeepCopy(json),
    );
  }

  /// Returns a defensive copy of the Core row. The row remains display-only;
  /// callers cannot use this value to perform a lifecycle replacement.
  Map<String, dynamic> toJson() => _lifecycleRegistryDeepCopy(_value);
}

class ForgeDeviceEnrollmentHeartbeatLifecycleRegistry {
  final String schemaVersion;
  final ForgeDeviceOwner owner;
  final List<ForgeLifecycleRegistryStateRow> states;

  const ForgeDeviceEnrollmentHeartbeatLifecycleRegistry({
    required this.schemaVersion,
    required this.owner,
    required this.states,
  });

  factory ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
    Object? value,
  ) {
    final json = _lifecycleRegistryObject(value, 'envelope');
    _lifecycleRegistryExactKeys(json, {'schema_version', 'owner', 'states'});
    if (json['schema_version'] !=
        forgeDeviceEnrollmentHeartbeatLifecycleRegistrySchema) {
      throw const FormatException(
        'Unsupported Forge lifecycle registry schema.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final rawStates = json['states'];
    if (rawStates is! List ||
        rawStates.length >
            forgeDeviceEnrollmentHeartbeatLifecycleRegistryMaxStates) {
      throw const FormatException('Invalid Forge lifecycle registry states.');
    }
    final states = rawStates
        .map(ForgeLifecycleRegistryStateRow.fromJson)
        .toList(growable: false);
    final seenDevices = <String>{};
    final seenInstances = <String>{};
    String? priorDevice;
    String? priorInstance;
    for (final state in states) {
      if (state.owner != owner) {
        throw const FormatException(
          'Forge lifecycle registry state owner does not match envelope owner.',
        );
      }
      if (!seenDevices.add(state.deviceID) ||
          !seenInstances.add(state.instanceID)) {
        throw const FormatException(
          'Forge lifecycle registry contains duplicate identities.',
        );
      }
      if (priorDevice != null &&
          (state.deviceID.compareTo(priorDevice) < 0 ||
              (state.deviceID == priorDevice &&
                  state.instanceID.compareTo(priorInstance!) < 0))) {
        throw const FormatException(
          'Forge lifecycle registry states are not canonical.',
        );
      }
      priorDevice = state.deviceID;
      priorInstance = state.instanceID;
    }
    return ForgeDeviceEnrollmentHeartbeatLifecycleRegistry(
      schemaVersion: forgeDeviceEnrollmentHeartbeatLifecycleRegistrySchema,
      owner: owner,
      states: List.unmodifiable(states),
    );
  }

  factory ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJsonText(
    String source,
  ) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException('Forge lifecycle registry is too large.');
    }
    _lifecycleRegistryRejectDuplicateKeys(source);
    try {
      return ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        jsonDecode(source),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Invalid Forge lifecycle registry JSON.');
    }
  }

  /// The candidate is a read-only observation. No authority is encoded by
  /// the envelope, and the model exposes no replacement or mutation method.
  bool get isDisplayOnly => true;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'owner': owner.toJson(),
    'states': states.map((state) => state.toJson()).toList(growable: false),
  };
}
