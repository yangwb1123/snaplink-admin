part of 'forge_scheduler_selection_lease.dart';

class ForgeExecutionLeaseGrant {
  final int version;
  final String attemptID;
  final String targetID;
  final int epoch;
  final String fencingToken;
  final int issuedAtMS;
  final int expiresAtMS;

  const ForgeExecutionLeaseGrant({
    required this.version,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
    required this.issuedAtMS,
    required this.expiresAtMS,
  });

  factory ForgeExecutionLeaseGrant.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'v',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
      'issued_at_ms',
      'expires_at_ms',
    });
    final version = _leaseBoundedInt(json['v'], 1);
    final epoch = _leasePositiveInt(json['epoch']);
    final issued = _leasePositiveInt(json['issued_at_ms']);
    final expires = _leasePositiveInt(json['expires_at_ms']);
    if (version != 1 ||
        expires <= issued ||
        expires - issued < 1000 ||
        expires - issued > 600000) {
      throw const FormatException('Invalid Forge execution lease grant.');
    }
    return ForgeExecutionLeaseGrant(
      version: version,
      attemptID: _leaseIdentifier(json['attempt_id']),
      targetID: _leaseIdentifier(json['target_id']),
      epoch: epoch,
      fencingToken: _leaseIdentifier(json['fencing_token'], maxLength: 256),
      issuedAtMS: issued,
      expiresAtMS: expires,
    );
  }

  Map<String, dynamic> toJson() => {
    'v': version,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': epoch,
    'fencing_token': fencingToken,
    'issued_at_ms': issuedAtMS,
    'expires_at_ms': expiresAtMS,
  };
}

class ForgeSchedulerSelectionLease {
  static const schema = 'forge.execution-lease-registry/v1';
  static const evaluationMode = 'durable_scheduler_lease_claim';

  final String schemaVersion;
  final String mode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String deviceID;
  final String instanceID;
  final int inventoryRevision;
  final int generation;
  final int heartbeatSequence;
  final ForgeExecutionLeaseGrant grant;
  final bool replayed;
  final ForgeSchedulerSelectionLeaseAuthority authority;

  const ForgeSchedulerSelectionLease({
    required this.schemaVersion,
    required this.mode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.deviceID,
    required this.instanceID,
    required this.inventoryRevision,
    required this.generation,
    required this.heartbeatSequence,
    required this.grant,
    required this.replayed,
    required this.authority,
  });

  factory ForgeSchedulerSelectionLease.fromJsonText(String source) {
    if (utf8.encode(source).length > 512 * 1024) {
      throw const FormatException('Forge scheduler lease is too large.');
    }
    _LeaseDuplicateScanner(source).scan();
    return ForgeSchedulerSelectionLease.fromJson(jsonDecode(source));
  }

  factory ForgeSchedulerSelectionLease.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'device_id',
      'instance_id',
      'inventory_revision',
      'generation',
      'heartbeat_sequence',
      'grant',
      'replayed',
      'authority',
    });
    if (json['schema_version'] != schema ||
        json['evaluation_mode'] != evaluationMode) {
      throw const FormatException('Invalid Forge scheduler lease envelope.');
    }
    final attemptID = _leaseIdentifier(json['attempt_id']);
    final instanceID = _leaseIdentifier(json['instance_id']);
    final grant = ForgeExecutionLeaseGrant.fromJson(json['grant']);
    if (grant.attemptID != attemptID ||
        grant.targetID != instanceID ||
        json['replayed'] is! bool) {
      throw const FormatException('Forge scheduler lease binding is invalid.');
    }
    return ForgeSchedulerSelectionLease(
      schemaVersion: schema,
      mode: evaluationMode,
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: attemptID,
      deviceID: _leaseIdentifier(json['device_id']),
      instanceID: instanceID,
      inventoryRevision: _leasePositiveInt(json['inventory_revision']),
      generation: _leasePositiveInt(json['generation']),
      heartbeatSequence: _leasePositiveInt(json['heartbeat_sequence']),
      grant: grant,
      replayed: json['replayed'] as bool,
      authority: ForgeSchedulerSelectionLeaseAuthority.fromJson(
        json['authority'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': mode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'device_id': deviceID,
    'instance_id': instanceID,
    'inventory_revision': inventoryRevision,
    'generation': generation,
    'heartbeat_sequence': heartbeatSequence,
    'grant': grant.toJson(),
    'replayed': replayed,
    'authority': authority.toJson(),
  };

  bool isFor(String conversationID, String runID, String attemptID) =>
      this.conversationID == conversationID &&
      this.runID == runID &&
      this.attemptID == attemptID;
}

class ForgeSchedulerSelectionLeaseRelease {
  static const schema = 'forge.execution-lease-registry/v1';
  static const evaluationMode = 'durable_scheduler_lease_release';

  final String schemaVersion;
  final String mode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final String attemptID;
  final String deviceID;
  final String instanceID;
  final int epoch;
  final int releasedAtMS;
  final bool replayed;
  final ForgeSchedulerSelectionLeaseReleaseAuthority authority;

  const ForgeSchedulerSelectionLeaseRelease({
    required this.schemaVersion,
    required this.mode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.deviceID,
    required this.instanceID,
    required this.epoch,
    required this.releasedAtMS,
    required this.replayed,
    required this.authority,
  });

  factory ForgeSchedulerSelectionLeaseRelease.fromJsonText(String source) {
    if (utf8.encode(source).length > 512 * 1024) {
      throw const FormatException(
        'Forge scheduler lease release is too large.',
      );
    }
    _LeaseDuplicateScanner(source).scan();
    return ForgeSchedulerSelectionLeaseRelease.fromJson(jsonDecode(source));
  }

  factory ForgeSchedulerSelectionLeaseRelease.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'attempt_id',
      'device_id',
      'instance_id',
      'epoch',
      'released_at_ms',
      'replayed',
      'authority',
    });
    if (json['schema_version'] != schema ||
        json['evaluation_mode'] != evaluationMode ||
        json['replayed'] is! bool) {
      throw const FormatException(
        'Invalid Forge scheduler lease release envelope.',
      );
    }
    final attemptID = _leaseIdentifier(json['attempt_id']);
    return ForgeSchedulerSelectionLeaseRelease(
      schemaVersion: schema,
      mode: evaluationMode,
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: attemptID,
      deviceID: _leaseIdentifier(json['device_id']),
      instanceID: _leaseIdentifier(json['instance_id']),
      epoch: _leasePositiveInt(json['epoch']),
      releasedAtMS: _leasePositiveInt(json['released_at_ms']),
      replayed: json['replayed'] as bool,
      authority: ForgeSchedulerSelectionLeaseReleaseAuthority.fromJson(
        json['authority'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': mode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'device_id': deviceID,
    'instance_id': instanceID,
    'epoch': epoch,
    'released_at_ms': releasedAtMS,
    'replayed': replayed,
    'authority': authority.toJson(),
  };

  bool isFor(String conversationID, String runID, String attemptID) =>
      this.conversationID == conversationID &&
      this.runID == runID &&
      this.attemptID == attemptID;
}
