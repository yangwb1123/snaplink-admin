part of 'forge_device_heartbeat_persistence.dart';

/// The authority declaration carried by the persistence contract is always
/// offline. Keeping it as a value makes accidental authority claims visible.
class ForgeDeviceHeartbeatPersistenceAuthority {
  final bool identityVerified;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeDeviceHeartbeatPersistenceAuthority({
    required this.identityVerified,
    required this.heartbeatPersisted,
    required this.inventoryAuthoritative,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  const ForgeDeviceHeartbeatPersistenceAuthority.offline()
    : identityVerified = false,
      heartbeatPersisted = false,
      inventoryAuthoritative = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false;

  factory ForgeDeviceHeartbeatPersistenceAuthority.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    _heartbeatExactKeys(json, {
      'identity_verified',
      'heartbeat_persisted',
      'inventory_authoritative',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    final authority = ForgeDeviceHeartbeatPersistenceAuthority(
      identityVerified: _heartbeatBool(json['identity_verified']),
      heartbeatPersisted: _heartbeatBool(json['heartbeat_persisted']),
      inventoryAuthoritative: _heartbeatBool(json['inventory_authoritative']),
      reservationCreated: _heartbeatBool(json['reservation_created']),
      executionAuthorized: _heartbeatBool(json['execution_authorized']),
      dispatchPerformed: _heartbeatBool(json['dispatch_performed']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge heartbeat persistence authority must be offline.',
      );
    }
    return authority;
  }

  bool get anyGranted =>
      identityVerified ||
      heartbeatPersisted ||
      inventoryAuthoritative ||
      reservationCreated ||
      executionAuthorized ||
      dispatchPerformed;
}

class ForgeDeviceHeartbeatPersistenceDevice {
  final String deviceID;
  final String tenantID;
  final String approvalState;

  const ForgeDeviceHeartbeatPersistenceDevice({
    required this.deviceID,
    required this.tenantID,
    required this.approvalState,
  });

  factory ForgeDeviceHeartbeatPersistenceDevice.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    _heartbeatExactKeys(json, {'device_id', 'tenant_id', 'approval_state'});
    final approval = _heartbeatText(json['approval_state']);
    if (!const {'approved', 'pending', 'revoked'}.contains(approval)) {
      throw const FormatException('Invalid Forge heartbeat device approval.');
    }
    return ForgeDeviceHeartbeatPersistenceDevice(
      deviceID: _heartbeatIdentifier(json['device_id']),
      tenantID: _heartbeatIdentifier(json['tenant_id']),
      approvalState: approval,
    );
  }
}

class ForgeDeviceHeartbeat {
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt sequence;
  final ForgeDeviceHeartbeatReferenceCapabilities? capabilities;

  const ForgeDeviceHeartbeat({
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.sequence,
    this.capabilities,
  });

  factory ForgeDeviceHeartbeat.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    final expectedKeys = {'device_id', 'instance_id', 'generation', 'sequence'};
    if (json.containsKey('capabilities')) expectedKeys.add('capabilities');
    _heartbeatExactKeys(json, expectedKeys);
    return ForgeDeviceHeartbeat(
      deviceID: _heartbeatIdentifier(json['device_id']),
      instanceID: _heartbeatIdentifier(json['instance_id']),
      generation: _heartbeatPositiveUint64(json['generation']),
      sequence: _heartbeatPositiveUint64(json['sequence']),
      capabilities: json.containsKey('capabilities')
          ? ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
              json['capabilities'],
            )
          : null,
    );
  }

  ForgeDeviceHeartbeat withCapabilities(
    ForgeDeviceHeartbeatReferenceCapabilities value,
  ) => ForgeDeviceHeartbeat(
    deviceID: deviceID,
    instanceID: instanceID,
    generation: generation,
    sequence: sequence,
    capabilities: value,
  );
}

/// A complete server-observed replacement state. `revision` is the CAS
/// version; the other fields are the value returned by the pure transition.
class ForgeDeviceHeartbeatPersistenceState {
  final BigInt revision;
  final String deviceID;
  final String instanceID;
  final BigInt generation;
  final BigInt heartbeatSequence;
  final BigInt serverObservedAtMS;
  final BigInt capabilityLeaseExpiresAtMS;
  final ForgeDeviceHeartbeatReferenceCapabilities? capabilities;

  const ForgeDeviceHeartbeatPersistenceState({
    required this.revision,
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
    this.capabilities,
  });

  factory ForgeDeviceHeartbeatPersistenceState.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    final expectedKeys = {
      'revision',
      'device_id',
      'instance_id',
      'generation',
      'heartbeat_sequence',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
    };
    if (json.containsKey('capabilities')) expectedKeys.add('capabilities');
    _heartbeatExactKeys(json, expectedKeys);
    return ForgeDeviceHeartbeatPersistenceState(
      revision: _heartbeatUint64(json['revision']),
      deviceID: _heartbeatIdentifier(json['device_id']),
      instanceID: _heartbeatIdentifier(json['instance_id']),
      generation: _heartbeatPositiveUint64(json['generation']),
      heartbeatSequence: _heartbeatPositiveUint64(json['heartbeat_sequence']),
      serverObservedAtMS: _heartbeatUint64(json['server_observed_at_ms']),
      capabilityLeaseExpiresAtMS: _heartbeatUint64(
        json['capability_lease_expires_at_ms'],
      ),
      capabilities: json.containsKey('capabilities')
          ? ForgeDeviceHeartbeatReferenceCapabilities.fromJson(
              json['capabilities'],
            )
          : null,
    );
  }

  ForgeDeviceHeartbeatPersistenceState withCapabilities(
    ForgeDeviceHeartbeatReferenceCapabilities value,
  ) => ForgeDeviceHeartbeatPersistenceState(
    revision: revision,
    deviceID: deviceID,
    instanceID: instanceID,
    generation: generation,
    heartbeatSequence: heartbeatSequence,
    serverObservedAtMS: serverObservedAtMS,
    capabilityLeaseExpiresAtMS: capabilityLeaseExpiresAtMS,
    capabilities: value,
  );
}

class ForgeDeviceHeartbeatPersistenceExpected {
  final bool accepted;
  final String? error;
  final BigInt? revision;
  final BigInt? generation;
  final BigInt? heartbeatSequence;
  final BigInt? serverObservedAtMS;
  final BigInt? capabilityLeaseExpiresAtMS;

  const ForgeDeviceHeartbeatPersistenceExpected._({
    required this.accepted,
    required this.error,
    required this.revision,
    required this.generation,
    required this.heartbeatSequence,
    required this.serverObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
  });

  factory ForgeDeviceHeartbeatPersistenceExpected.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    final accepted = _heartbeatBool(json['accepted']);
    if (!accepted) {
      _heartbeatExactKeys(json, {'accepted', 'error'});
      return ForgeDeviceHeartbeatPersistenceExpected._(
        accepted: false,
        error: _heartbeatText(json['error']),
        revision: null,
        generation: null,
        heartbeatSequence: null,
        serverObservedAtMS: null,
        capabilityLeaseExpiresAtMS: null,
      );
    }
    _heartbeatExactKeys(json, {
      'accepted',
      'revision',
      'generation',
      'heartbeat_sequence',
      'server_observed_at_ms',
      'capability_lease_expires_at_ms',
    });
    return ForgeDeviceHeartbeatPersistenceExpected._(
      accepted: true,
      error: null,
      revision: _heartbeatPositiveUint64(json['revision']),
      generation: _heartbeatPositiveUint64(json['generation']),
      heartbeatSequence: _heartbeatPositiveUint64(json['heartbeat_sequence']),
      serverObservedAtMS: _heartbeatUint64(json['server_observed_at_ms']),
      capabilityLeaseExpiresAtMS: _heartbeatUint64(
        json['capability_lease_expires_at_ms'],
      ),
    );
  }
}

class ForgeDeviceHeartbeatPersistenceCase {
  final String name;
  final BigInt expectedRevision;
  final String? deviceApprovalState;
  final ForgeDeviceHeartbeatPersistenceState? current;
  final ForgeDeviceHeartbeat heartbeat;
  final BigInt serverObservedAtMS;
  final BigInt leaseTTLMS;
  final ForgeDeviceHeartbeatPersistenceExpected expected;

  const ForgeDeviceHeartbeatPersistenceCase({
    required this.name,
    required this.expectedRevision,
    required this.deviceApprovalState,
    required this.current,
    required this.heartbeat,
    required this.serverObservedAtMS,
    required this.leaseTTLMS,
    required this.expected,
  });

  ForgeDeviceHeartbeatPersistenceCase withCapabilities(
    ForgeDeviceHeartbeatReferenceCapabilities capabilities,
  ) => ForgeDeviceHeartbeatPersistenceCase(
    name: name,
    expectedRevision: expectedRevision,
    deviceApprovalState: deviceApprovalState,
    current: current?.withCapabilities(capabilities),
    heartbeat: heartbeat.withCapabilities(capabilities),
    serverObservedAtMS: serverObservedAtMS,
    leaseTTLMS: leaseTTLMS,
    expected: expected,
  );

  factory ForgeDeviceHeartbeatPersistenceCase.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    final keys = {
      'name',
      'expected_revision',
      'current',
      'heartbeat',
      'server_observed_at_ms',
      'lease_ttl_ms',
      'expected',
    };
    if (json.containsKey('device_approval_state')) {
      keys.add('device_approval_state');
    }
    _heartbeatExactKeys(json, keys);
    final rawApproval = json['device_approval_state'];
    final approval = rawApproval == null ? null : _heartbeatText(rawApproval);
    if (approval != null &&
        !const {'approved', 'pending', 'revoked'}.contains(approval)) {
      throw const FormatException('Invalid Forge heartbeat approval override.');
    }
    final rawCurrent = json['current'];
    if (rawCurrent != null && rawCurrent is! Map) {
      throw const FormatException('Invalid Forge heartbeat current state.');
    }
    return ForgeDeviceHeartbeatPersistenceCase(
      name: _heartbeatIdentifier(json['name']),
      expectedRevision: _heartbeatUint64(json['expected_revision']),
      deviceApprovalState: approval,
      current: rawCurrent == null
          ? null
          : ForgeDeviceHeartbeatPersistenceState.fromJson(rawCurrent),
      heartbeat: ForgeDeviceHeartbeat.fromJson(json['heartbeat']),
      serverObservedAtMS: _heartbeatUint64(json['server_observed_at_ms']),
      leaseTTLMS: _heartbeatUint64(json['lease_ttl_ms']),
      expected: ForgeDeviceHeartbeatPersistenceExpected.fromJson(
        json['expected'],
      ),
    );
  }
}

class ForgeDeviceHeartbeatPersistenceFixture {
  final ForgeDeviceHeartbeatPersistenceAuthority authority;
  final ForgeDeviceHeartbeatPersistenceDevice device;
  final ForgeDeviceHeartbeatReferenceCapabilities capabilities;
  final List<ForgeDeviceHeartbeatPersistenceCase> cases;

  const ForgeDeviceHeartbeatPersistenceFixture({
    required this.authority,
    required this.device,
    required this.capabilities,
    required this.cases,
  });

  /// Decodes the shared contract while preserving a JSON uint64 literal that
  /// exceeds Dart VM's signed 64-bit `int` range. `jsonDecode` converts that
  /// literal to a rounded double, so the marker is restored as [BigInt] before
  /// strict object parsing starts.
  factory ForgeDeviceHeartbeatPersistenceFixture.fromJsonText(String source) {
    final marked = source.replaceAll(
      _forgeDeviceHeartbeatMaxUint64Literal,
      '"$_forgeDeviceHeartbeatMaxUint64Marker"',
    );
    return ForgeDeviceHeartbeatPersistenceFixture.fromJson(
      _restoreHeartbeatUint64Markers(jsonDecode(marked)),
    );
  }

  factory ForgeDeviceHeartbeatPersistenceFixture.fromJson(Object? value) {
    final json = _heartbeatObject(value);
    _heartbeatExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'authority',
      'device',
      'cases',
    });
    if (json['schema_version'] != forgeDeviceHeartbeatPersistenceSchema ||
        json['evaluation_mode'] !=
            forgeDeviceHeartbeatPersistenceEvaluationMode) {
      throw const FormatException(
        'Invalid Forge heartbeat persistence envelope.',
      );
    }
    final rawCases = json['cases'];
    if (rawCases is! List || rawCases.length != 10) {
      throw const FormatException('Invalid Forge heartbeat persistence cases.');
    }
    final capabilities = _forgePersistenceContractCapabilities();
    final cases = rawCases
        .map(ForgeDeviceHeartbeatPersistenceCase.fromJson)
        .map((testCase) => testCase.withCapabilities(capabilities))
        .toList(growable: false);
    final names = cases.map((testCase) => testCase.name).toSet();
    if (names.length != cases.length) {
      throw const FormatException(
        'Duplicate Forge heartbeat persistence case name.',
      );
    }
    return ForgeDeviceHeartbeatPersistenceFixture(
      authority: ForgeDeviceHeartbeatPersistenceAuthority.fromJson(
        json['authority'],
      ),
      device: ForgeDeviceHeartbeatPersistenceDevice.fromJson(json['device']),
      capabilities: capabilities,
      cases: List.unmodifiable(cases),
    );
  }
}

ForgeDeviceHeartbeatReferenceCapabilities
_forgePersistenceContractCapabilities() {
  return ForgeDeviceHeartbeatReferenceCapabilities.fromJson({
    'os': 'linux',
    'architecture': 'amd64',
    'cpu_cores': 8,
    'available_cpu_cores': 8,
    'memory_bytes': 16384,
    'available_memory_bytes': 16384,
    'storage_bytes': 8192,
    'available_storage_bytes': 8192,
    'runtimes': ['oci'],
  });
}
