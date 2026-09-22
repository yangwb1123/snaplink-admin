import 'forge_device_inventory_declaration.dart';
import 'forge_device_placement.dart';

const forgeSessionPlacementObservationSchema =
    'forge.session-placement-observation/v1';
const forgeSessionPlacementObservationEvaluationMode = 'offline_static_only';
const forgeSessionPlacementEvaluationMode =
    forgeSessionPlacementObservationEvaluationMode;
const forgeSessionPlacementObservationMaxDecisions = 128;
const forgeSessionPlacementObservationMaxSafeInteger = 9007199254740991;

/// One caller-declared Runner instance paired with its device declaration.
/// The pair is a display value and carries no identity proof.
class ForgeSessionPlacementCandidate {
  final String instanceID;
  final ForgeDeviceDeclaration device;

  const ForgeSessionPlacementCandidate({
    required this.instanceID,
    required this.device,
  });

  Map<String, dynamic> toJson() => {
    'instance_id': instanceID,
    'device': device.toJson(),
  };
}

/// Pure owner/Conversation/Run binding for an offline placement comparison.
class ForgeSessionPlacementRequest {
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final ForgeDevicePlacementRequest placement;
  final List<ForgeSessionPlacementCandidate> candidates;

  const ForgeSessionPlacementRequest({
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.placement,
    required this.candidates,
  });

  Map<String, dynamic> toJson() => {
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'placement': placement.toJson(),
    'candidates': candidates.map((candidate) => candidate.toJson()).toList(),
  };
}

class ForgeSessionPlacementAuthority {
  final bool identityVerified;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeSessionPlacementAuthority({
    required this.identityVerified,
    required this.heartbeatPersisted,
    required this.inventoryAuthoritative,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  const ForgeSessionPlacementAuthority.offline()
    : identityVerified = false,
      heartbeatPersisted = false,
      inventoryAuthoritative = false,
      reservationCreated = false,
      executionAuthorized = false,
      dispatchPerformed = false;

  factory ForgeSessionPlacementAuthority.fromJson(Object? value) {
    final json = _sessionPlacementObject(value);
    _sessionPlacementExactKeys(json, {
      'identity_verified',
      'heartbeat_persisted',
      'inventory_authoritative',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    for (final key in json.keys) {
      final flag = json[key];
      if (flag is! bool || flag) {
        throw const FormatException(
          'Forge session placement observation claims authority.',
        );
      }
    }
    return const ForgeSessionPlacementAuthority.offline();
  }

  Map<String, dynamic> toJson() => {
    'identity_verified': identityVerified,
    'heartbeat_persisted': heartbeatPersisted,
    'inventory_authoritative': inventoryAuthoritative,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
  };
}

class ForgeSessionPlacementDecision {
  final String deviceID;
  final String instanceID;
  final bool matchesRequirements;
  final List<String> exclusionReasons;

  const ForgeSessionPlacementDecision({
    required this.deviceID,
    required this.instanceID,
    required this.matchesRequirements,
    required this.exclusionReasons,
  });

  factory ForgeSessionPlacementDecision.fromJson(Object? value) {
    final json = _sessionPlacementObject(value);
    _sessionPlacementExactKeys(json, {
      'device_id',
      'instance_id',
      'matches_requirements',
      'exclusion_reasons',
    });
    final matchesRequirements = json['matches_requirements'];
    final rawReasons = json['exclusion_reasons'];
    if (matchesRequirements is! bool ||
        rawReasons is! List ||
        rawReasons.length > 64) {
      throw const FormatException('Invalid Forge session placement decision.');
    }
    final reasons = rawReasons
        .map(_sessionPlacementParseToken)
        .toList(growable: false);
    for (var index = 1; index < reasons.length; index++) {
      if (_sessionPlacementCompareIDs(reasons[index - 1], reasons[index]) >=
          0) {
        throw const FormatException(
          'Unsorted Forge session placement reasons.',
        );
      }
    }
    if (matchesRequirements != reasons.isEmpty) {
      throw const FormatException(
        'Inconsistent Forge session placement decision.',
      );
    }
    return ForgeSessionPlacementDecision(
      deviceID: _sessionPlacementParseIdentifier(json['device_id']),
      instanceID: _sessionPlacementParseIdentifier(json['instance_id']),
      matchesRequirements: matchesRequirements,
      exclusionReasons: List.unmodifiable(reasons),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceID,
    'instance_id': instanceID,
    'matches_requirements': matchesRequirements,
    'exclusion_reasons': exclusionReasons,
  };
}

class ForgeSessionPlacementObservation {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final int evaluatedAtMS;
  final bool ownerDeclarationUnverified;
  final bool deviceAttributesUnverified;
  final List<ForgeSessionPlacementDecision> decisions;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeSessionPlacementAuthority authority;

  const ForgeSessionPlacementObservation({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.evaluatedAtMS,
    required this.ownerDeclarationUnverified,
    required this.deviceAttributesUnverified,
    required this.decisions,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
  });

  factory ForgeSessionPlacementObservation.fromJson(Object? value) {
    final json = _sessionPlacementObject(value);
    _sessionPlacementExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'evaluated_at_ms',
      'owner_declaration_unverified',
      'device_attributes_unverified',
      'decisions',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    });
    if (json['schema_version'] != forgeSessionPlacementObservationSchema ||
        json['evaluation_mode'] !=
            forgeSessionPlacementObservationEvaluationMode ||
        json['owner_declaration_unverified'] != true ||
        json['device_attributes_unverified'] != true ||
        json['selected_device_id'] != null ||
        json['selected_instance_id'] != null) {
      throw const FormatException(
        'Invalid Forge session placement observation envelope.',
      );
    }
    final rawDecisions = json['decisions'];
    if (rawDecisions is! List ||
        rawDecisions.length > forgeSessionPlacementObservationMaxDecisions) {
      throw const FormatException(
        'Invalid Forge session placement observation decisions.',
      );
    }
    final decisions = rawDecisions
        .map(ForgeSessionPlacementDecision.fromJson)
        .toList(growable: false);
    final deviceIDs = <String>{};
    final instanceIDs = <String>{};
    for (var index = 1; index < decisions.length; index++) {
      final previous = decisions[index - 1];
      final current = decisions[index];
      if (_sessionPlacementCompareIDs(previous.deviceID, current.deviceID) >=
          0) {
        throw const FormatException(
          'Unsorted Forge session placement observation decisions.',
        );
      }
    }
    for (final decision in decisions) {
      if (!deviceIDs.add(decision.deviceID) ||
          !instanceIDs.add(decision.instanceID)) {
        throw const FormatException(
          'Duplicate Forge session placement observation binding.',
        );
      }
    }
    return ForgeSessionPlacementObservation(
      schemaVersion: forgeSessionPlacementObservationSchema,
      evaluationMode: forgeSessionPlacementObservationEvaluationMode,
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _sessionPlacementParseIdentifier(json['conversation_id']),
      runID: _sessionPlacementParseIdentifier(json['run_id']),
      evaluatedAtMS: _sessionPlacementPositiveSafeInteger(
        json['evaluated_at_ms'],
      ),
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
      decisions: List.unmodifiable(decisions),
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: ForgeSessionPlacementAuthority.fromJson(json['authority']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': {
      'issuer': owner.issuer,
      'subject': owner.subject,
      'tenant_id': owner.tenantID,
    },
    'conversation_id': conversationID,
    'run_id': runID,
    'evaluated_at_ms': evaluatedAtMS,
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'device_attributes_unverified': deviceAttributesUnverified,
    'decisions': decisions.map((decision) => decision.toJson()).toList(),
    'selected_device_id': selectedDeviceID,
    'selected_instance_id': selectedInstanceID,
    'authority': authority.toJson(),
  };
}

class ForgeSessionPlacementError implements Exception {
  final String code;

  const ForgeSessionPlacementError(this.code);
}

/// Produces a deterministic, metadata-only placement observation for one Run.
/// It has no clock, network, persistence, target selection, reservation, or
/// execution effect.
ForgeSessionPlacementObservation observeForgeSessionPlacement(
  ForgeSessionPlacementRequest request,
) {
  if (!_sessionPlacementToken(request.conversationID) ||
      !_sessionPlacementToken(request.runID) ||
      request.owner != request.placement.owner ||
      request.candidates.length > forgeDevicePlacementMaxDevices) {
    throw const ForgeSessionPlacementError('invalid_binding');
  }
  final byDevice = <String, ForgeSessionPlacementCandidate>{};
  final instanceIDs = <String>{};
  for (final candidate in request.candidates) {
    if (!_sessionPlacementToken(candidate.instanceID) ||
        byDevice.containsKey(candidate.device.deviceID) ||
        !instanceIDs.add(candidate.instanceID)) {
      throw const ForgeSessionPlacementError('invalid_candidate');
    }
    byDevice[candidate.device.deviceID] = candidate;
  }
  if (request.placement.devices.length != byDevice.length ||
      request.placement.devices.any(
        (device) => !byDevice.containsKey(device.deviceID),
      )) {
    throw const ForgeSessionPlacementError('candidate_mismatch');
  }

  final placement = dryRunForgeDevicePlacement(request.placement);
  final decisions = placement.deviceResults
      .map((result) {
        final candidate = byDevice[result.deviceID];
        if (candidate == null) {
          throw const ForgeSessionPlacementError('candidate_mismatch');
        }
        return ForgeSessionPlacementDecision(
          deviceID: result.deviceID,
          instanceID: candidate.instanceID,
          matchesRequirements: result.matchesRequirements,
          exclusionReasons: List.unmodifiable(result.exclusionReasons),
        );
      })
      .toList(growable: false);
  return ForgeSessionPlacementObservation(
    schemaVersion: forgeSessionPlacementObservationSchema,
    evaluationMode: forgeSessionPlacementObservationEvaluationMode,
    owner: request.owner,
    conversationID: request.conversationID,
    runID: request.runID,
    evaluatedAtMS: placement.evaluatedAtMS,
    ownerDeclarationUnverified: true,
    deviceAttributesUnverified: true,
    decisions: List.unmodifiable(decisions),
    selectedDeviceID: null,
    selectedInstanceID: null,
    authority: const ForgeSessionPlacementAuthority.offline(),
  );
}

bool _sessionPlacementToken(String value) {
  if (value.isEmpty || value.length > 128) return false;
  final codes = value.codeUnits;
  final first = codes.first;
  if (!((first >= 0x30 && first <= 0x39) ||
      (first >= 0x41 && first <= 0x5a) ||
      (first >= 0x61 && first <= 0x7a))) {
    return false;
  }
  return codes
      .skip(1)
      .every(
        (code) =>
            code >= 0x30 && code <= 0x39 ||
            code >= 0x41 && code <= 0x5a ||
            code >= 0x61 && code <= 0x7a ||
            const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
      );
}

Map<String, dynamic> _sessionPlacementObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected Forge session placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _sessionPlacementExactKeys(
  Map<String, dynamic> json,
  Set<String> expected,
) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge session placement observation fields.',
    );
  }
}

String _sessionPlacementParseIdentifier(Object? value) {
  if (value is! String || !_sessionPlacementToken(value)) {
    throw const FormatException('Invalid Forge session placement identifier.');
  }
  return value;
}

String _sessionPlacementParseToken(Object? value) {
  if (value is! String || !_sessionPlacementToken(value)) {
    throw const FormatException('Invalid Forge session placement token.');
  }
  return value;
}

int _sessionPlacementPositiveSafeInteger(Object? value) {
  if (value is! int ||
      value <= 0 ||
      value > forgeSessionPlacementObservationMaxSafeInteger) {
    throw const FormatException(
      'Invalid Forge session placement observation integer.',
    );
  }
  return value;
}

int _sessionPlacementCompareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
