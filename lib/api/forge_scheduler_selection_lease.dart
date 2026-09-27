import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_device_placement.dart';

/// The explicit request body for a durable scheduler lease claim. The
/// idempotency key is transported in the HTTP header and is intentionally not
/// duplicated in this value.
class ForgeSchedulerSelectionLeaseRequest {
  final String conversationID;
  final String runID;
  final String attemptID;
  final ForgeDevicePlacementRequirements requirements;
  final int ttlMS;

  const ForgeSchedulerSelectionLeaseRequest({
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.requirements,
    required this.ttlMS,
  });

  factory ForgeSchedulerSelectionLeaseRequest.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'conversation_id',
      'run_id',
      'attempt_id',
      'requirements',
      'ttl_ms',
    });
    final ttl = _leaseBoundedInt(json['ttl_ms'], 600000);
    if (ttl < 1000) {
      throw const FormatException('Invalid Forge scheduler lease duration.');
    }
    return ForgeSchedulerSelectionLeaseRequest(
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: _leaseIdentifier(json['attempt_id']),
      requirements: ForgeDevicePlacementRequirements.fromJson(
        json['requirements'],
      ),
      ttlMS: ttl,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'requirements': requirements.toJson(),
    'ttl_ms': ttlMS,
  };
}

/// The explicit proof packet for renewing one current scheduler lease. The
/// fencing token is required by the transport but is never rendered by the
/// Sessions UI.
class ForgeSchedulerSelectionLeaseRenewalRequest {
  final String conversationID;
  final String runID;
  final String attemptID;
  final String targetID;
  final int epoch;
  final String fencingToken;
  final int ttlMS;

  const ForgeSchedulerSelectionLeaseRenewalRequest({
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
    required this.ttlMS,
  });

  factory ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'conversation_id',
      'run_id',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
      'ttl_ms',
    });
    final epoch = _leasePositiveInt(json['epoch']);
    final ttl = _leaseBoundedInt(json['ttl_ms'], 600000);
    if (ttl < 1000) {
      throw const FormatException(
        'Invalid Forge scheduler lease renewal duration.',
      );
    }
    return ForgeSchedulerSelectionLeaseRenewalRequest(
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: _leaseIdentifier(json['attempt_id']),
      targetID: _leaseIdentifier(json['target_id']),
      epoch: epoch,
      fencingToken: _leaseIdentifier(json['fencing_token'], maxLength: 256),
      ttlMS: ttl,
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': epoch,
    'fencing_token': fencingToken,
    'ttl_ms': ttlMS,
  };
}

/// The explicit proof packet for releasing one current scheduler lease. The
/// fencing token is required by the transport and is never rendered by the
/// Sessions UI.
class ForgeSchedulerSelectionLeaseReleaseRequest {
  final String conversationID;
  final String runID;
  final String attemptID;
  final String targetID;
  final int epoch;
  final String fencingToken;

  const ForgeSchedulerSelectionLeaseReleaseRequest({
    required this.conversationID,
    required this.runID,
    required this.attemptID,
    required this.targetID,
    required this.epoch,
    required this.fencingToken,
  });

  factory ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'conversation_id',
      'run_id',
      'attempt_id',
      'target_id',
      'epoch',
      'fencing_token',
    });
    return ForgeSchedulerSelectionLeaseReleaseRequest(
      conversationID: _leaseIdentifier(json['conversation_id']),
      runID: _leaseIdentifier(json['run_id']),
      attemptID: _leaseIdentifier(json['attempt_id']),
      targetID: _leaseIdentifier(json['target_id']),
      epoch: _leasePositiveInt(json['epoch']),
      fencingToken: _leaseIdentifier(json['fencing_token'], maxLength: 256),
    );
  }

  Map<String, dynamic> toJson() => {
    'conversation_id': conversationID,
    'run_id': runID,
    'attempt_id': attemptID,
    'target_id': targetID,
    'epoch': epoch,
    'fencing_token': fencingToken,
  };
}

class ForgeSchedulerSelectionLeaseAuthority {
  final bool placementSelected;
  final bool reservationCreated;
  final bool leaseIssued;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeSchedulerSelectionLeaseAuthority({
    required this.placementSelected,
    required this.reservationCreated,
    required this.leaseIssued,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeSchedulerSelectionLeaseAuthority.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'placement_selected',
      'reservation_created',
      'lease_issued',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeSchedulerSelectionLeaseAuthority(
      placementSelected: _leaseBool(json['placement_selected']),
      reservationCreated: _leaseBool(json['reservation_created']),
      leaseIssued: _leaseBool(json['lease_issued']),
      executionAuthorized: _leaseBool(json['execution_authorized']),
      dispatchPerformed: _leaseBool(json['dispatch_performed']),
      auditPublished: _leaseBool(json['audit_published']),
    );
    if (!authority.placementSelected ||
        !authority.reservationCreated ||
        !authority.leaseIssued ||
        authority.executionAuthorized ||
        authority.dispatchPerformed ||
        authority.auditPublished) {
      throw const FormatException('Invalid Forge scheduler lease authority.');
    }
    return authority;
  }

  Map<String, dynamic> toJson() => {
    'placement_selected': placementSelected,
    'reservation_created': reservationCreated,
    'lease_issued': leaseIssued,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeSchedulerSelectionLeaseReleaseAuthority {
  final bool placementSelected;
  final bool reservationCreated;
  final bool leaseIssued;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeSchedulerSelectionLeaseReleaseAuthority({
    required this.placementSelected,
    required this.reservationCreated,
    required this.leaseIssued,
    required this.executionAuthorized,
    required this.dispatchPerformed,
    required this.auditPublished,
  });

  factory ForgeSchedulerSelectionLeaseReleaseAuthority.fromJson(Object? value) {
    final json = _leaseObject(value);
    _leaseExactKeys(json, {
      'placement_selected',
      'reservation_created',
      'lease_issued',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    final authority = ForgeSchedulerSelectionLeaseReleaseAuthority(
      placementSelected: _leaseBool(json['placement_selected']),
      reservationCreated: _leaseBool(json['reservation_created']),
      leaseIssued: _leaseBool(json['lease_issued']),
      executionAuthorized: _leaseBool(json['execution_authorized']),
      dispatchPerformed: _leaseBool(json['dispatch_performed']),
      auditPublished: _leaseBool(json['audit_published']),
    );
    if (authority.placementSelected ||
        authority.reservationCreated ||
        authority.leaseIssued ||
        authority.executionAuthorized ||
        authority.dispatchPerformed ||
        authority.auditPublished) {
      throw const FormatException(
        'Invalid Forge scheduler lease release authority.',
      );
    }
    return authority;
  }

  Map<String, dynamic> toJson() => {
    'placement_selected': placementSelected,
    'reservation_created': reservationCreated,
    'lease_issued': leaseIssued,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

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

Map<String, dynamic> _leaseObject(Object? value) {
  if (value is! Map)
    throw const FormatException('Invalid Forge scheduler lease object.');
  return Map<String, dynamic>.from(value);
}

void _leaseExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge scheduler lease fields.');
  }
}

bool _leaseBool(Object? value) {
  if (value is! bool)
    throw const FormatException('Invalid Forge scheduler lease boolean.');
  return value;
}

int _leasePositiveInt(Object? value) {
  final parsed = _leaseBoundedInt(value, 9007199254740991);
  if (parsed <= 0)
    throw const FormatException('Invalid Forge scheduler lease integer.');
  return parsed;
}

int _leaseBoundedInt(Object? value, int maximum) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Invalid Forge scheduler lease integer.');
  }
  return value;
}

String _leaseIdentifier(Object? value, {int maxLength = 128}) {
  if (value is! String ||
      value.isEmpty ||
      value.length > maxLength ||
      value.trim() != value) {
    throw const FormatException('Invalid Forge scheduler lease identifier.');
  }
  for (var index = 0; index < value.length; index++) {
    final code = value.codeUnitAt(index);
    final valid =
        code >= 48 && code <= 57 ||
        code >= 65 && code <= 90 ||
        code >= 97 && code <= 122 ||
        index > 0 && '.:_+/-'.codeUnits.contains(code);
    if (!valid)
      throw const FormatException('Invalid Forge scheduler lease identifier.');
  }
  return value;
}

class _LeaseDuplicateScanner {
  final String source;
  var index = 0;
  _LeaseDuplicateScanner(this.source);

  void scan() {
    _value();
    _space();
    if (index != source.length)
      throw const FormatException('Trailing Forge scheduler lease JSON.');
  }

  void _value() {
    _space();
    if (index >= source.length)
      throw const FormatException('Invalid Forge scheduler lease JSON.');
    switch (source.codeUnitAt(index)) {
      case 123:
        _object();
        return;
      case 91:
        _array();
        return;
      case 34:
        _string();
        return;
      default:
        _primitive();
        return;
    }
  }

  void _object() {
    index++;
    _space();
    final keys = <String>{};
    if (_take(125)) return;
    while (true) {
      _space();
      final start = index;
      _string();
      final key = jsonDecode(source.substring(start, index)) as String;
      if (!keys.add(key))
        throw const FormatException('Duplicate Forge scheduler lease key.');
      _space();
      if (!_take(58))
        throw const FormatException('Invalid Forge scheduler lease object.');
      _value();
      _space();
      if (_take(125)) return;
      if (!_take(44))
        throw const FormatException('Invalid Forge scheduler lease object.');
    }
  }

  void _array() {
    index++;
    _space();
    if (_take(93)) return;
    while (true) {
      _value();
      _space();
      if (_take(93)) return;
      if (!_take(44))
        throw const FormatException('Invalid Forge scheduler lease array.');
    }
  }

  void _string() {
    final start = index;
    if (!_take(34))
      throw const FormatException('Invalid Forge scheduler lease string.');
    while (index < source.length) {
      final code = source.codeUnitAt(index++);
      if (code == 92) {
        if (index >= source.length)
          throw const FormatException('Invalid Forge scheduler lease escape.');
        index++;
      } else if (code == 34) {
        return;
      } else if (code < 32) {
        throw const FormatException('Invalid Forge scheduler lease string.');
      }
    }
    index = start;
    throw const FormatException('Unterminated Forge scheduler lease string.');
  }

  void _primitive() {
    final start = index;
    while (index < source.length && !' \t\r\n,]}'.contains(source[index]))
      index++;
    if (start == index)
      throw const FormatException('Invalid Forge scheduler lease value.');
  }

  void _space() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) index++;
  }

  bool _take(int code) {
    if (index < source.length && source.codeUnitAt(index) == code) {
      index++;
      return true;
    }
    return false;
  }
}
