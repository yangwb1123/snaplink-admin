part of 'forge_device_inventory_placement_input.dart';

class ForgeDeviceInventoryPlacementExpected {
  final bool accepted;
  final String error;
  final BigInt? revision;
  final String? deviceID;
  final String? instanceID;
  final BigInt? generation;
  final BigInt? heartbeatSequence;
  final String? approvalState;
  final String? cordonState;
  final String? reservationState;
  final String? liveness;
  final BigInt? snapshotObservedAtMS;
  final BigInt? leaseExpiresAtMS;
  final bool? ownerDeclarationUnverified;
  final bool? policyAttributesUnverified;
  final List<String>? dataResidencyZones;
  final String? trustZone;
  final List<String>? sandboxLevels;
  final int? concurrencyLimit;
  final int? activeConcurrency;
  final bool? policyRequirementsMet;

  const ForgeDeviceInventoryPlacementExpected({
    required this.accepted,
    required this.error,
    required this.revision,
    required this.deviceID,
    required this.instanceID,
    required this.generation,
    required this.heartbeatSequence,
    required this.approvalState,
    required this.cordonState,
    required this.reservationState,
    required this.liveness,
    required this.snapshotObservedAtMS,
    required this.leaseExpiresAtMS,
    required this.ownerDeclarationUnverified,
    required this.policyAttributesUnverified,
    required this.dataResidencyZones,
    required this.trustZone,
    required this.sandboxLevels,
    required this.concurrencyLimit,
    required this.activeConcurrency,
    required this.policyRequirementsMet,
  });

  factory ForgeDeviceInventoryPlacementExpected.fromJson(Object? value) {
    final json = _placementInputObject(value);
    final accepted = _placementInputBool(json['accepted']);
    final error = _placementInputError(json['error']);
    return accepted
        ? _placementInputAcceptedExpected(json, error)
        : _placementInputRejectedExpected(json, error);
  }
}

ForgeDeviceInventoryPlacementExpected _placementInputRejectedExpected(
  Map<String, dynamic> json,
  String error,
) {
  _placementInputExactKeys(json, {'accepted', 'error'});
  if (!const {
    'owner_mismatch',
    'runner_device_mismatch',
    'invalid_persisted_inventory_placement_input',
  }.contains(error)) {
    throw const FormatException('Unknown Forge placement-input error.');
  }
  return ForgeDeviceInventoryPlacementExpected(
    accepted: false,
    error: error,
    revision: null,
    deviceID: null,
    instanceID: null,
    generation: null,
    heartbeatSequence: null,
    approvalState: null,
    cordonState: null,
    reservationState: null,
    liveness: null,
    snapshotObservedAtMS: null,
    leaseExpiresAtMS: null,
    ownerDeclarationUnverified: null,
    policyAttributesUnverified: null,
    dataResidencyZones: null,
    trustZone: null,
    sandboxLevels: null,
    concurrencyLimit: null,
    activeConcurrency: null,
    policyRequirementsMet: null,
  );
}

ForgeDeviceInventoryPlacementExpected _placementInputAcceptedExpected(
  Map<String, dynamic> json,
  String error,
) {
  _placementInputExactAcceptedKeys(json);
  final values = _placementInputAcceptedValues(json, error);
  return ForgeDeviceInventoryPlacementExpected(
    accepted: true,
    error: error,
    revision: values['revision'] as BigInt,
    deviceID: values['device_id'] as String,
    instanceID: values['instance_id'] as String,
    generation: values['generation'] as BigInt,
    heartbeatSequence: values['heartbeat_sequence'] as BigInt,
    approvalState: values['approval_state'] as String,
    cordonState: values['cordon_state'] as String,
    reservationState: values['reservation_state'] as String,
    liveness: values['liveness'] as String,
    snapshotObservedAtMS: values['snapshot_observed_at_ms'] as BigInt,
    leaseExpiresAtMS: values['lease_expires_at_ms'] as BigInt,
    ownerDeclarationUnverified: true,
    policyAttributesUnverified: true,
    dataResidencyZones: const [],
    trustZone: 'unknown',
    sandboxLevels: const [],
    concurrencyLimit: values['concurrency_limit'] as int,
    activeConcurrency: values['active_concurrency'] as int,
    policyRequirementsMet: false,
  );
}

void _placementInputExactAcceptedKeys(Map<String, dynamic> json) {
  _placementInputExactKeys(json, {
    'accepted',
    'error',
    'revision',
    'device_id',
    'instance_id',
    'generation',
    'heartbeat_sequence',
    'approval_state',
    'cordon_state',
    'reservation_state',
    'liveness',
    'snapshot_observed_at_ms',
    'lease_expires_at_ms',
    'owner_declaration_unverified',
    'policy_attributes_unverified',
    'data_residency_zones',
    'trust_zone',
    'sandbox_levels',
    'concurrency_limit',
    'active_concurrency',
    'policy_requirements_met',
  });
}

Map<String, Object> _placementInputAcceptedValues(
  Map<String, dynamic> json,
  String error,
) {
  _placementInputValidateAcceptedDefaults(json, error);
  return {
    'revision': _placementInputPositiveUint64(json['revision']),
    'device_id': _placementInputIdentifier(json['device_id']),
    'instance_id': _placementInputIdentifier(json['instance_id']),
    'generation': _placementInputPositiveUint64(json['generation']),
    'heartbeat_sequence': _placementInputPositiveUint64(
      json['heartbeat_sequence'],
    ),
    'approval_state': _placementInputOneOfText(json['approval_state'], {
      'approved',
      'pending',
      'revoked',
    }),
    'cordon_state': _placementInputOneOfText(json['cordon_state'], {
      'clear',
      'cordoned',
    }),
    'reservation_state': _placementInputOneOfText(json['reservation_state'], {
      'none',
      'reserved',
    }),
    'liveness': _placementInputOneOfText(json['liveness'], {
      'online',
      'offline',
    }),
    'snapshot_observed_at_ms': _placementInputSafeInteger(
      json['snapshot_observed_at_ms'],
    ),
    'lease_expires_at_ms': _placementInputSafeInteger(
      json['lease_expires_at_ms'],
    ),
    'concurrency_limit': _placementInputBoundedInt(
      json['concurrency_limit'],
      0xffff,
    ),
    'active_concurrency': _placementInputBoundedInt(
      json['active_concurrency'],
      0xffff,
    ),
  };
}

void _placementInputValidateAcceptedDefaults(
  Map<String, dynamic> json,
  String error,
) {
  final residency = _placementInputTokens(json['data_residency_zones']);
  final sandbox = _placementInputTokens(json['sandbox_levels']);
  final ownerUnverified = _placementInputBool(
    json['owner_declaration_unverified'],
  );
  final policyUnverified = _placementInputBool(
    json['policy_attributes_unverified'],
  );
  final policyMet = _placementInputBool(json['policy_requirements_met']);
  if (error.isNotEmpty ||
      !ownerUnverified ||
      !policyUnverified ||
      residency.isNotEmpty ||
      json['trust_zone'] != 'unknown' ||
      sandbox.isNotEmpty ||
      json['concurrency_limit'] != 0 ||
      json['active_concurrency'] != 0 ||
      policyMet) {
    throw const FormatException(
      'Invalid Forge persisted placement-input defaults.',
    );
  }
}

void _placementInputValidateState(
  ForgeDeviceOwner owner,
  ForgeDeviceInventoryPlacementState state,
) {
  if (state.device.owner != owner ||
      state.device.deviceID != state.runner.deviceID) {
    throw const FormatException(
      'Invalid Forge persisted placement-input state binding.',
    );
  }
}

List<ForgeDeviceInventoryPlacementCase> _placementInputCases(Object? value) {
  if (value is! List ||
      value.isEmpty ||
      value.length > forgeDeviceInventoryPlacementInputMaxCases) {
    throw const FormatException('Invalid Forge placement-input cases.');
  }
  final cases = value
      .map(ForgeDeviceInventoryPlacementCase.fromJson)
      .toList(growable: false);
  final names = <String>{};
  for (final testCase in cases) {
    if (!names.add(testCase.name)) {
      throw const FormatException('Duplicate Forge placement-input case.');
    }
  }
  return List.unmodifiable(cases);
}

Map<String, dynamic> _placementInputObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge placement-input object.');
  }
  return Map<String, dynamic>.from(value);
}

void _placementInputExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge placement-input fields.');
  }
}

bool _placementInputBool(Object? value) {
  if (value is! bool) {
    throw const FormatException('Invalid Forge placement-input boolean.');
  }
  return value;
}

String _placementInputError(Object? value) {
  if (value is! String || value.trim() != value || value.length > 128) {
    throw const FormatException('Invalid Forge placement-input error.');
  }
  return value;
}

String _placementInputIdentifier(Object? value) {
  if (value is! String || value.isEmpty || value.length > 128) {
    throw const FormatException('Invalid Forge placement-input identifier.');
  }
  final codes = value.codeUnits;
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x3a ||
      code == 0x2d;
  if (!first(codes.first) || !codes.skip(1).every(rest)) {
    throw const FormatException('Invalid Forge placement-input identifier.');
  }
  return value;
}

String _placementInputOneOfText(Object? value, Set<String> choices) {
  if (value is! String || !choices.contains(value)) {
    throw const FormatException('Invalid Forge placement-input state.');
  }
  return value;
}

bool _placementInputOneOf(Object? value, Set<String> choices) =>
    value is String && choices.contains(value);

List<String> _placementInputTokens(Object? value) {
  if (value is! List || value.length > 32) {
    throw const FormatException('Invalid Forge placement-input token list.');
  }
  final tokens = value
      .map((item) {
        if (item is! String ||
            item.isEmpty ||
            item.length > 128 ||
            item.codeUnits.any(
              (code) =>
                  !((code >= 0x30 && code <= 0x39) ||
                      (code >= 0x41 && code <= 0x5a) ||
                      (code >= 0x61 && code <= 0x7a) ||
                      code == 0x2e ||
                      code == 0x5f ||
                      code == 0x2d ||
                      code == 0x2b),
            )) {
          throw const FormatException('Invalid Forge placement-input token.');
        }
        return item;
      })
      .toList(growable: false);
  return tokens;
}

List<String> _placementInputZones(Object? value) {
  final zones = _placementInputTokens(value);
  for (final zone in zones) {
    if (zone.length > 64 ||
        zone.codeUnits.any(
          (code) =>
              !((code >= 0x30 && code <= 0x39) ||
                  (code >= 0x41 && code <= 0x5a) ||
                  (code >= 0x61 && code <= 0x7a) ||
                  code == 0x2e ||
                  code == 0x5f ||
                  code == 0x2d),
        )) {
      throw const FormatException('Invalid Forge placement-input zone.');
    }
  }
  return zones;
}

bool _placementInputSortedUnique(List<String> values) {
  for (var index = 1; index < values.length; index++) {
    if (values[index - 1].compareTo(values[index]) >= 0) return false;
  }
  return true;
}

BigInt _placementInputUint64(Object? value) {
  final number = value is BigInt
      ? value
      : value is int
      ? BigInt.from(value)
      : null;
  if (number == null ||
      number < BigInt.zero ||
      number > _placementInputMaxUint64) {
    throw const FormatException('Invalid Forge placement-input uint64.');
  }
  return number;
}

BigInt _placementInputPositiveUint64(Object? value) {
  final number = _placementInputUint64(value);
  if (number == BigInt.zero) {
    throw const FormatException(
      'Invalid Forge placement-input positive uint64.',
    );
  }
  return number;
}

BigInt _placementInputSafeInteger(Object? value) {
  final number = _placementInputUint64(value);
  if (number > BigInt.from(9007199254740991)) {
    throw const FormatException('Unsafe Forge placement-input integer.');
  }
  return number;
}

int _placementInputBoundedInt(
  Object? value,
  int maximum, {
  bool positive = false,
}) {
  if (value is! int ||
      value < 0 ||
      value > maximum ||
      (positive && value == 0)) {
    throw const FormatException('Invalid Forge placement-input integer.');
  }
  return value;
}
