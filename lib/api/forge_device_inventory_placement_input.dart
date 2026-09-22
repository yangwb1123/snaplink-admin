import 'forge_device_heartbeat.dart';
import 'forge_device_inventory_declaration.dart';

part 'forge_device_inventory_placement_input_codec.dart';

/// The canonical value-only persisted-inventory placement-input fixture.
///
/// This module is a strict display and contract boundary. It does not read a
/// clock, contact a service, register a device, select a target, reserve
/// capacity, dispatch a task, or execute a Runner.
const forgeDeviceInventoryPlacementInputSchema =
    'forge.device-inventory-placement-input/v1';
const forgeDeviceInventoryPlacementInputEvaluationMode =
    'pure_persisted_inventory_to_placement_input';
const forgeDeviceInventoryPlacementInputMaxCases = 128;
final _placementInputMaxUint64 = (BigInt.one << 64) - BigInt.one;

class ForgeDeviceInventoryPlacementInputFixture {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner evaluationOwner;
  final ForgeDeviceInventoryPlacementPolicy policyRequirements;
  final ForgeDeviceInventoryPlacementAuthority authority;
  final ForgeDeviceInventoryPlacementState state;
  final List<ForgeDeviceInventoryPlacementCase> cases;

  const ForgeDeviceInventoryPlacementInputFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.evaluationOwner,
    required this.policyRequirements,
    required this.authority,
    required this.state,
    required this.cases,
  });

  factory ForgeDeviceInventoryPlacementInputFixture.fromJson(Object? value) {
    final json = _placementInputObject(value);
    _placementInputExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'evaluation_owner',
      'policy_requirements',
      'authority',
      'state',
      'cases',
    });
    if (json['schema_version'] != forgeDeviceInventoryPlacementInputSchema ||
        json['evaluation_mode'] !=
            forgeDeviceInventoryPlacementInputEvaluationMode) {
      throw const FormatException(
        'Invalid Forge persisted placement-input envelope.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['evaluation_owner']);
    final policy = ForgeDeviceInventoryPlacementPolicy.fromJson(
      json['policy_requirements'],
    );
    final authority = ForgeDeviceInventoryPlacementAuthority.fromJson(
      json['authority'],
    );
    final state = ForgeDeviceInventoryPlacementState.fromJson(json['state']);
    _placementInputValidateState(owner, state);
    final cases = _placementInputCases(json['cases']);
    return ForgeDeviceInventoryPlacementInputFixture(
      schemaVersion: forgeDeviceInventoryPlacementInputSchema,
      evaluationMode: forgeDeviceInventoryPlacementInputEvaluationMode,
      evaluationOwner: owner,
      policyRequirements: policy,
      authority: authority,
      state: state,
      cases: List.unmodifiable(cases),
    );
  }
}

class ForgeDeviceInventoryPlacementPolicy {
  final List<String> dataResidencyZones;
  final String minimumTrustZone;
  final String sandboxFloor;
  final int concurrencySlots;

  const ForgeDeviceInventoryPlacementPolicy({
    required this.dataResidencyZones,
    required this.minimumTrustZone,
    required this.sandboxFloor,
    required this.concurrencySlots,
  });

  factory ForgeDeviceInventoryPlacementPolicy.fromJson(Object? value) {
    final json = _placementInputObject(value);
    _placementInputExactKeys(json, {
      'data_residency_zones',
      'minimum_trust_zone',
      'sandbox_floor',
      'concurrency_slots',
    });
    final zones = _placementInputZones(json['data_residency_zones']);
    if (zones.isEmpty ||
        !_placementInputSortedUnique(zones) ||
        !_placementInputOneOf(json['minimum_trust_zone'], {
          'untrusted',
          'low',
          'standard',
          'high',
          'restricted',
        }) ||
        !_placementInputOneOf(json['sandbox_floor'], {
          'process',
          'container',
          'microvm',
        })) {
      throw const FormatException('Invalid Forge placement-input policy.');
    }
    return ForgeDeviceInventoryPlacementPolicy(
      dataResidencyZones: List.unmodifiable(zones),
      minimumTrustZone: json['minimum_trust_zone'] as String,
      sandboxFloor: json['sandbox_floor'] as String,
      concurrencySlots: _placementInputBoundedInt(
        json['concurrency_slots'],
        0xffff,
        positive: true,
      ),
    );
  }
}

class ForgeDeviceInventoryPlacementAuthority {
  final bool identityVerified;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool placementSelected;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeDeviceInventoryPlacementAuthority({
    required this.identityVerified,
    required this.heartbeatPersisted,
    required this.inventoryAuthoritative,
    required this.placementSelected,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  bool get anyGranted =>
      identityVerified ||
      heartbeatPersisted ||
      inventoryAuthoritative ||
      placementSelected ||
      reservationCreated ||
      executionAuthorized ||
      dispatchPerformed;

  factory ForgeDeviceInventoryPlacementAuthority.fromJson(Object? value) {
    final json = _placementInputObject(value);
    _placementInputExactKeys(json, {
      'identity_verified',
      'heartbeat_persisted',
      'inventory_authoritative',
      'placement_selected',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    final authority = ForgeDeviceInventoryPlacementAuthority(
      identityVerified: _placementInputBool(json['identity_verified']),
      heartbeatPersisted: _placementInputBool(json['heartbeat_persisted']),
      inventoryAuthoritative: _placementInputBool(
        json['inventory_authoritative'],
      ),
      placementSelected: _placementInputBool(json['placement_selected']),
      reservationCreated: _placementInputBool(json['reservation_created']),
      executionAuthorized: _placementInputBool(json['execution_authorized']),
      dispatchPerformed: _placementInputBool(json['dispatch_performed']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge persisted placement-input authority must remain false.',
      );
    }
    return authority;
  }
}

class ForgeDeviceInventoryPlacementState {
  final BigInt revision;
  final ForgeDeviceInventoryPlacementDevice device;
  final ForgeDeviceInventoryPlacementRunner runner;

  const ForgeDeviceInventoryPlacementState({
    required this.revision,
    required this.device,
    required this.runner,
  });

  factory ForgeDeviceInventoryPlacementState.fromJson(Object? value) {
    final json = _placementInputObject(value);
    _placementInputExactKeys(json, {'revision', 'device', 'runner'});
    return ForgeDeviceInventoryPlacementState(
      revision: _placementInputPositiveUint64(json['revision']),
      device: ForgeDeviceInventoryPlacementDevice.fromJson(json['device']),
      runner: ForgeDeviceInventoryPlacementRunner.fromJson(json['runner']),
    );
  }
}

class ForgeDeviceInventoryPlacementDevice {
  final String deviceID;
  final ForgeDeviceOwner owner;
  final String approvalState;
  final String cordonState;
  final String reservationState;

  const ForgeDeviceInventoryPlacementDevice({
    required this.deviceID,
    required this.owner,
    required this.approvalState,
    required this.cordonState,
    required this.reservationState,
  });

  factory ForgeDeviceInventoryPlacementDevice.fromJson(Object? value) {
    final json = _placementInputObject(value);
    _placementInputExactKeys(json, {
      'device_id',
      'owner',
      'approval_state',
      'cordon_state',
      'reservation_state',
    });
    return ForgeDeviceInventoryPlacementDevice(
      deviceID: _placementInputIdentifier(json['device_id']),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      approvalState: _placementInputOneOfText(json['approval_state'], {
        'approved',
        'pending',
        'revoked',
      }),
      cordonState: _placementInputOneOfText(json['cordon_state'], {
        'clear',
        'cordoned',
      }),
      reservationState: _placementInputOneOfText(json['reservation_state'], {
        'none',
        'reserved',
      }),
    );
  }
}

class ForgeDeviceInventoryPlacementRunner {
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt heartbeatSequence;
  final BigInt serverObservedAtMS;
  final BigInt capabilityLeaseExpiresAtMS;
  final String liveness;
  final ForgeDeviceHeartbeatReferenceCapabilities capabilities;

  const ForgeDeviceInventoryPlacementRunner({
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
    required this.liveness,
    required this.capabilities,
  });

  factory ForgeDeviceInventoryPlacementRunner.fromJson(Object? value) {
    final json = _placementInputObject(value);
    _placementInputExactKeys(json, {
      'device_id',
      'instance_id',
      'generation',
      'heartbeat_sequence',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
      'liveness',
      'capabilities',
    });
    return ForgeDeviceInventoryPlacementRunner(
      deviceID: _placementInputIdentifier(json['device_id']),
      instanceID: _placementInputIdentifier(json['instance_id']),
      generation: _placementInputPositiveUint64(json['generation']),
      heartbeatSequence: _placementInputPositiveUint64(
        json['heartbeat_sequence'],
      ),
      serverObservedAtMS: _placementInputUint64(json['server_observed_at_ms']),
      capabilityLeaseExpiresAtMS: _placementInputUint64(
        json['capability_lease_expires_at_ms'],
      ),
      liveness: _placementInputOneOfText(json['liveness'], {
        'online',
        'offline',
      }),
      capabilities: ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
        json['capabilities'],
      ),
    );
  }
}

class ForgeDeviceInventoryPlacementCase {
  final String name;
  final ForgeDeviceOwner? evaluationOwner;
  final String? runnerDeviceID;
  final String? approvalState;
  final String? cordonState;
  final String? liveness;
  final BigInt? serverObservedAtMS;
  final BigInt? capabilityLeaseExpiresAtMS;
  final ForgeDeviceInventoryPlacementExpected expected;

  const ForgeDeviceInventoryPlacementCase({
    required this.name,
    required this.evaluationOwner,
    required this.runnerDeviceID,
    required this.approvalState,
    required this.cordonState,
    required this.liveness,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
    required this.expected,
  });

  factory ForgeDeviceInventoryPlacementCase.fromJson(Object? value) {
    final json = _placementInputObject(value);
    const allowed = {
      'name',
      'evaluation_owner',
      'runner_device_id',
      'approval_state',
      'cordon_state',
      'liveness',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
      'expected',
    };
    if (json.length < 2 || json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unexpected Forge placement-input case.');
    }
    return ForgeDeviceInventoryPlacementCase(
      name: _placementInputIdentifier(json['name']),
      evaluationOwner: json.containsKey('evaluation_owner')
          ? ForgeDeviceOwner.fromJson(json['evaluation_owner'])
          : null,
      runnerDeviceID: json.containsKey('runner_device_id')
          ? _placementInputIdentifier(json['runner_device_id'])
          : null,
      approvalState: json.containsKey('approval_state')
          ? _placementInputOneOfText(json['approval_state'], {
              'approved',
              'pending',
              'revoked',
            })
          : null,
      cordonState: json.containsKey('cordon_state')
          ? _placementInputOneOfText(json['cordon_state'], {
              'clear',
              'cordoned',
            })
          : null,
      liveness: json.containsKey('liveness')
          ? _placementInputOneOfText(json['liveness'], {'online', 'offline'})
          : null,
      serverObservedAtMS: json.containsKey('server_observed_at_ms')
          ? _placementInputUint64(json['server_observed_at_ms'])
          : null,
      capabilityLeaseExpiresAtMS:
          json.containsKey('capability_lease_expires_at_ms')
          ? _placementInputUint64(json['capability_lease_expires_at_ms'])
          : null,
      expected: ForgeDeviceInventoryPlacementExpected.fromJson(
        json['expected'],
      ),
    );
  }
}
