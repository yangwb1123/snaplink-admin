import 'dart:convert';

import 'forge_device_inventory_placement_batch_evaluation.dart';
import 'forge_device_inventory_declaration.dart';
import 'forge_device_inventory_v2_models.dart';
import 'forge_device_placement.dart';

/// Bounded local reader seam for the v2 placement comparison preview. The
/// default Sessions surface uses the platform workspace picker; tests and
/// native shells can inject a reader without opening a placement route.
typedef ForgeDeviceInventoryPlacementEvaluationV2FileReader =
    Future<String?> Function();

/// Strict, offline-only projection of the lossless v2 placement comparison.
/// It is a value decoder: it never reads a device service or grants authority.
const forgeDeviceInventoryPlacementEvaluationV2Schema =
    'forge.device-inventory-placement-evaluation/v2';
const forgeDeviceInventoryPlacementEvaluationV2Mode = 'offline_static_only';
const forgeDeviceInventoryPlacementEvaluationV2SourceSchema =
    'forge.device-inventory-observation/v2';
const forgeDeviceInventoryPlacementEvaluationV2Notice =
    'Every owner, state, timestamp, resource, GPU, reservation, residency, trust, sandbox, and concurrency value is an unverified caller declaration. This read-only comparison selects no target and grants no execution authority.';
const forgeDeviceInventoryPlacementEvaluationV2MaxDecisions = 128;
const forgeDeviceInventoryPlacementEvaluationV2MaxSafeInteger =
    9007199254740991;
const _forgeDeviceInventoryPlacementEvaluationV2StaleAfterMS = 90000;
const _forgeDeviceInventoryPlacementEvaluationV2MinLeaseTTLMS = 1000;
const _forgeDeviceInventoryPlacementEvaluationV2MaxLeaseTTLMS = 600000;

class ForgeDeviceInventoryPlacementEvaluationV2 {
  final String schemaVersion;
  final String evaluationMode;
  final String sourceSchemaVersion;
  final ForgeDeviceOwner evaluationOwner;
  final int evaluatedAtMS;
  final String notice;
  final ForgeDevicePlacementRequirements requirements;
  final ForgeDeviceInventoryPageV2 observation;
  final List<ForgeDeviceInventoryPlacementDecisionV2> decisions;
  final int eligibleCandidateCount;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeDeviceInventoryPlacementBatchAuthority authority;

  const ForgeDeviceInventoryPlacementEvaluationV2({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.sourceSchemaVersion,
    required this.evaluationOwner,
    required this.evaluatedAtMS,
    required this.notice,
    required this.requirements,
    required this.observation,
    required this.decisions,
    required this.eligibleCandidateCount,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
  });

  /// Decodes one bounded raw JSON document without allowing duplicate object
  /// keys to be silently replaced by `dart:convert`.
  factory ForgeDeviceInventoryPlacementEvaluationV2.fromJsonText(
    String source,
  ) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Forge v2 placement-evaluation document is too large.',
      );
    }
    _placementV2RejectDuplicateKeys(source);
    return ForgeDeviceInventoryPlacementEvaluationV2.fromJson(
      jsonDecode(source),
    );
  }

  factory ForgeDeviceInventoryPlacementEvaluationV2.fromJson(Object? value) {
    final json = _placementV2Object(value);
    _placementV2ExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'source_schema_version',
      'evaluation_owner',
      'evaluated_at_ms',
      'notice',
      'requirements',
      'observation',
      'expected',
      'eligible_candidate_count',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    });
    if (json['schema_version'] !=
            forgeDeviceInventoryPlacementEvaluationV2Schema ||
        json['evaluation_mode'] !=
            forgeDeviceInventoryPlacementEvaluationV2Mode ||
        json['source_schema_version'] !=
            forgeDeviceInventoryPlacementEvaluationV2SourceSchema ||
        json['notice'] != forgeDeviceInventoryPlacementEvaluationV2Notice) {
      throw const FormatException(
        'Invalid Forge v2 placement-evaluation envelope.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['evaluation_owner']);
    final evaluatedAt = _placementV2PositiveInt(json['evaluated_at_ms']);
    final requirements = ForgeDevicePlacementRequirements.fromJson(
      json['requirements'],
    );
    if (requirements.gpu.runtime.isNotEmpty) {
      throw const FormatException(
        'Forge v2 placement does not carry an accelerator runtime claim.',
      );
    }
    final observation = ForgeDeviceInventoryPageV2.fromJson(
      json['observation'],
    );
    if (observation.owner != owner ||
        observation.evaluatedAtMS != evaluatedAt) {
      throw const FormatException(
        'Forge v2 placement observation owner/time mismatch.',
      );
    }
    if (json['selected_device_id'] != null ||
        json['selected_instance_id'] != null) {
      throw const FormatException(
        'Forge v2 placement evaluation selected a device.',
      );
    }
    final decisions = _placementV2Decisions(
      json['expected'],
      observation,
      requirements,
      evaluatedAt,
    );
    final eligible = _placementV2PositiveOrZeroInt(
      json['eligible_candidate_count'],
    );
    if (eligible !=
        decisions.where((decision) => decision.matchesRequirements).length) {
      throw const FormatException('Forge v2 placement eligible count drifted.');
    }
    return ForgeDeviceInventoryPlacementEvaluationV2(
      schemaVersion: forgeDeviceInventoryPlacementEvaluationV2Schema,
      evaluationMode: forgeDeviceInventoryPlacementEvaluationV2Mode,
      sourceSchemaVersion:
          forgeDeviceInventoryPlacementEvaluationV2SourceSchema,
      evaluationOwner: owner,
      evaluatedAtMS: evaluatedAt,
      notice: forgeDeviceInventoryPlacementEvaluationV2Notice,
      requirements: requirements,
      observation: observation,
      decisions: List.unmodifiable(decisions),
      eligibleCandidateCount: eligible,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: ForgeDeviceInventoryPlacementBatchAuthority.fromJson(
        json['authority'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'source_schema_version': sourceSchemaVersion,
    'evaluation_owner': evaluationOwner.toJson(),
    'evaluated_at_ms': evaluatedAtMS,
    'notice': notice,
    'requirements': requirements.toJson(),
    'observation': observation.toJson(),
    'expected': decisions.map((decision) => decision.toJson()).toList(),
    'eligible_candidate_count': eligibleCandidateCount,
    'selected_device_id': selectedDeviceID,
    'selected_instance_id': selectedInstanceID,
    'authority': {
      'identity_verified': authority.identityVerified,
      'heartbeat_persisted': authority.heartbeatPersisted,
      'inventory_authoritative': authority.inventoryAuthoritative,
      'placement_selected': authority.placementSelected,
      'reservation_created': authority.reservationCreated,
      'execution_authorized': authority.executionAuthorized,
      'dispatch_performed': authority.dispatchPerformed,
    },
  };
}

class ForgeDeviceInventoryPlacementDecisionV2 {
  final int revision;
  final int generation;
  final int heartbeatSequence;
  final String deviceID;
  final String instanceID;
  final String reservationState;
  final int gpuCount;
  final int availableGPUMemoryBytes;
  final bool matchesRequirements;
  final List<String> exclusionReasons;
  final bool ownerDeclarationUnverified;
  final bool deviceAttributesUnverified;

  const ForgeDeviceInventoryPlacementDecisionV2({
    required this.revision,
    required this.generation,
    required this.heartbeatSequence,
    required this.deviceID,
    required this.instanceID,
    required this.reservationState,
    required this.gpuCount,
    required this.availableGPUMemoryBytes,
    required this.matchesRequirements,
    required this.exclusionReasons,
    required this.ownerDeclarationUnverified,
    required this.deviceAttributesUnverified,
  });

  factory ForgeDeviceInventoryPlacementDecisionV2.fromJson(Object? value) {
    final json = _placementV2Object(value);
    _placementV2ExactKeys(json, {
      'revision',
      'generation',
      'heartbeat_sequence',
      'device_id',
      'instance_id',
      'reservation_state',
      'gpu_count',
      'available_gpu_memory_bytes',
      'matches_requirements',
      'exclusion_reasons',
    });
    final matches = json['matches_requirements'];
    if (matches is! bool) {
      throw const FormatException(
        'Forge v2 placement decision claims authority.',
      );
    }
    final reasons = _placementV2Reasons(json['exclusion_reasons']);
    if (matches != reasons.isEmpty) {
      throw const FormatException(
        'Forge v2 placement decision matches/reasons drifted.',
      );
    }
    final reservation = json['reservation_state'];
    if (reservation is! String ||
        !const {'none', 'reserved'}.contains(reservation)) {
      throw const FormatException('Invalid Forge v2 reservation state.');
    }
    return ForgeDeviceInventoryPlacementDecisionV2(
      revision: _placementV2PositiveInt(json['revision']),
      generation: _placementV2PositiveInt(json['generation']),
      heartbeatSequence: _placementV2PositiveInt(json['heartbeat_sequence']),
      deviceID: _placementV2Identifier(json['device_id']),
      instanceID: _placementV2Identifier(json['instance_id']),
      reservationState: reservation,
      gpuCount: _placementV2BoundedInt(json['gpu_count'], 32),
      availableGPUMemoryBytes: _placementV2SafeInt(
        json['available_gpu_memory_bytes'],
      ),
      matchesRequirements: matches,
      exclusionReasons: List.unmodifiable(reasons),
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'generation': generation,
    'heartbeat_sequence': heartbeatSequence,
    'device_id': deviceID,
    'instance_id': instanceID,
    'reservation_state': reservationState,
    'gpu_count': gpuCount,
    'available_gpu_memory_bytes': availableGPUMemoryBytes,
    'matches_requirements': matchesRequirements,
    'exclusion_reasons': exclusionReasons,
  };
}

List<ForgeDeviceInventoryPlacementDecisionV2> _placementV2Decisions(
  Object? value,
  ForgeDeviceInventoryPageV2 observation,
  ForgeDevicePlacementRequirements requirements,
  int evaluatedAtMS,
) {
  if (value is! List ||
      value.length > forgeDeviceInventoryPlacementEvaluationV2MaxDecisions) {
    throw const FormatException('Invalid Forge v2 placement decisions.');
  }
  final decisions = value
      .map(ForgeDeviceInventoryPlacementDecisionV2.fromJson)
      .toList(growable: false);
  final candidates = <String, ForgeDeviceInventoryCandidateV2>{
    for (final candidate in observation.devices)
      candidate.device.deviceID: candidate,
  };
  final instances = <String>{};
  for (var index = 0; index < decisions.length; index++) {
    final decision = decisions[index];
    final candidate = candidates[decision.deviceID];
    if (candidate == null ||
        candidate.instanceID != decision.instanceID ||
        candidate.revision != decision.revision ||
        candidate.generation != decision.generation ||
        candidate.heartbeatSequence != decision.heartbeatSequence ||
        candidate.device.reservationState != decision.reservationState ||
        candidate.device.gpus.length != decision.gpuCount ||
        _placementV2GpuTotal(candidate.device) !=
            decision.availableGPUMemoryBytes ||
        !instances.add(decision.instanceID)) {
      throw const FormatException(
        'Forge v2 placement decision is not bound to its observation.',
      );
    }
    _placementV2ValidateLease(candidate.device);
    final computedReasons = _placementV2ComputedReasons(
      candidate.device,
      requirements,
      evaluatedAtMS,
    );
    if (decision.matchesRequirements != computedReasons.isEmpty ||
        !_placementV2SameStrings(decision.exclusionReasons, computedReasons)) {
      throw const FormatException(
        'Forge v2 placement decision does not match the observation.',
      );
    }
    if (index > 0) {
      final previous = decisions[index - 1];
      if (_placementV2Compare(previous.deviceID, decision.deviceID) > 0 ||
          (previous.deviceID == decision.deviceID &&
              _placementV2Compare(previous.instanceID, decision.instanceID) >=
                  0)) {
        throw const FormatException(
          'Forge v2 placement decisions are unsorted.',
        );
      }
    }
  }
  if (decisions.length != observation.devices.length) {
    throw const FormatException(
      'Forge v2 placement decision set is incomplete.',
    );
  }
  return decisions;
}

void _placementV2ValidateLease(ForgeDeviceV2 device) {
  final ttl = device.leaseExpiresAtMS - device.snapshotObservedAtMS;
  if (ttl < _forgeDeviceInventoryPlacementEvaluationV2MinLeaseTTLMS ||
      ttl > _forgeDeviceInventoryPlacementEvaluationV2MaxLeaseTTLMS) {
    throw const FormatException('Invalid Forge v2 capability lease.');
  }
}

List<String> _placementV2ComputedReasons(
  ForgeDeviceV2 device,
  ForgeDevicePlacementRequirements requirements,
  int evaluatedAtMS,
) {
  final reasons = <String>[];
  switch (device.approvalState) {
    case 'pending':
      reasons.add('approval_pending');
      break;
    case 'revoked':
      reasons.add('device_revoked');
      break;
    case 'approved':
      break;
  }
  if (device.cordonState == 'cordoned') reasons.add('device_cordoned');
  if (device.liveness == 'offline') reasons.add('declared_offline');
  if (device.snapshotObservedAtMS > evaluatedAtMS) {
    reasons.add('snapshot_declared_from_future');
  } else if (evaluatedAtMS - device.snapshotObservedAtMS >
      _forgeDeviceInventoryPlacementEvaluationV2StaleAfterMS) {
    reasons.add('snapshot_stale');
  }
  if (device.leaseExpiresAtMS <= evaluatedAtMS) {
    reasons.add('declared_lease_expired');
  }
  if (device.reservationState == 'reserved') reasons.add('device_reserved');

  if (device.os != requirements.os) reasons.add('os_mismatch');
  if (device.architecture != requirements.architecture) {
    reasons.add('architecture_mismatch');
  }
  if (device.availableCPUCores < requirements.minCPUCores) {
    reasons.add('cpu_cores_insufficient');
  }
  if (device.availableMemoryBytes < requirements.minMemoryBytes) {
    reasons.add('memory_insufficient');
  }
  if (device.availableStorageBytes < requirements.minStorageBytes) {
    reasons.add('storage_insufficient');
  }
  if (!device.runtimes.contains(requirements.runtime)) {
    reasons.add('runtime_missing');
  }
  if (requirements.gpu.required) {
    if (device.gpus.isEmpty) {
      reasons.add('gpu_missing');
    } else if (device.gpus
        .where(
          (gpu) => gpu.availableMemoryBytes >= requirements.gpu.minMemoryBytes,
        )
        .isEmpty) {
      reasons.add('gpu_memory_insufficient');
    }
  }
  if (!requirements.dataResidencyZones.any(
    device.dataResidencyZones.contains,
  )) {
    reasons.add('data_residency_zone_mismatch');
  }
  final declaredTrust = _placementV2TrustRank(device.trustZone);
  final minimumTrust = _placementV2TrustRank(requirements.minimumTrustZone);
  if (declaredTrust == null) {
    reasons.add('trust_zone_unconfirmed');
  } else if (minimumTrust == null || declaredTrust < minimumTrust) {
    reasons.add('trust_zone_below_minimum');
  }
  if (!_placementV2SandboxFloorMet(
    requirements.sandboxFloor,
    device.sandboxLevels,
  )) {
    reasons.add('sandbox_floor_unmet');
  }
  if (device.activeConcurrency > device.concurrencyLimit ||
      requirements.concurrencySlots >
          device.concurrencyLimit - device.activeConcurrency) {
    reasons.add('concurrency_capacity_insufficient');
  }
  reasons.sort(_placementV2Compare);
  return reasons;
}

int? _placementV2TrustRank(String value) => switch (value) {
  'untrusted' => 0,
  'low' => 1,
  'standard' => 2,
  'high' => 3,
  'restricted' => 4,
  _ => null,
};

bool _placementV2SandboxFloorMet(String floor, List<String> declared) {
  final minimum = _placementV2SandboxRank(floor);
  if (minimum == null) return false;
  return declared.any((level) {
    final actual = _placementV2SandboxRank(level);
    return actual != null && actual >= minimum;
  });
}

int? _placementV2SandboxRank(String value) => switch (value) {
  'process' => 1,
  'container' => 2,
  'microvm' => 3,
  _ => null,
};

bool _placementV2SameStrings(List<String> left, List<String> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}

int _placementV2GpuTotal(ForgeDeviceV2 device) {
  var total = 0;
  for (final gpu in device.gpus) {
    total += gpu.availableMemoryBytes;
    if (total > forgeDeviceInventoryPlacementEvaluationV2MaxSafeInteger) {
      throw const FormatException('Forge v2 GPU total exceeds safe integer.');
    }
  }
  return total;
}

List<String> _placementV2Reasons(Object? value) {
  const allowed = {
    'approval_pending',
    'architecture_mismatch',
    'concurrency_capacity_insufficient',
    'cpu_cores_insufficient',
    'data_residency_zone_mismatch',
    'declared_lease_expired',
    'declared_lease_invalid',
    'declared_offline',
    'device_cordoned',
    'device_reserved',
    'device_revoked',
    'gpu_memory_insufficient',
    'gpu_missing',
    'memory_insufficient',
    'os_mismatch',
    'runtime_missing',
    'sandbox_floor_unmet',
    'snapshot_declared_from_future',
    'snapshot_stale',
    'storage_insufficient',
    'trust_zone_below_minimum',
    'trust_zone_unconfirmed',
  };
  if (value is! List || value.length > 64) {
    throw const FormatException('Invalid Forge v2 placement reasons.');
  }
  final reasons = value
      .map((reason) {
        if (reason is! String || !allowed.contains(reason)) {
          throw const FormatException('Unknown Forge v2 placement reason.');
        }
        return reason;
      })
      .toList(growable: false);
  for (var index = 1; index < reasons.length; index++) {
    if (_placementV2Compare(reasons[index - 1], reasons[index]) >= 0) {
      throw const FormatException('Forge v2 placement reasons are unsorted.');
    }
  }
  return reasons;
}

Map<String, dynamic> _placementV2Object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge v2 placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _placementV2ExactKeys(Map<String, dynamic> value, Set<String> expected) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge v2 placement fields.');
  }
}

int _placementV2PositiveInt(Object? value) {
  final integer = _placementV2SafeInt(value);
  if (integer == 0) {
    throw const FormatException(
      'Expected positive Forge v2 placement integer.',
    );
  }
  return integer;
}

int _placementV2PositiveOrZeroInt(Object? value) {
  return _placementV2SafeInt(value);
}

int _placementV2SafeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > forgeDeviceInventoryPlacementEvaluationV2MaxSafeInteger) {
    throw const FormatException('Invalid Forge v2 placement integer.');
  }
  return value;
}

int _placementV2BoundedInt(Object? value, int maximum) {
  final integer = _placementV2SafeInt(value);
  if (integer > maximum) {
    throw const FormatException('Invalid Forge v2 placement bound.');
  }
  return integer;
}

String _placementV2Identifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_placementV2ASCIIIdentifier(value)) {
    throw const FormatException('Invalid Forge v2 placement identifier.');
  }
  return value;
}

bool _placementV2ASCIIIdentifier(String value) {
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
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

int _placementV2Compare(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final comparison = left
        .codeUnitAt(index)
        .compareTo(right.codeUnitAt(index));
    if (comparison != 0) return comparison;
  }
  return left.length.compareTo(right.length);
}

void _placementV2RejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && _placementV2Whitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException('Invalid Forge v2 JSON object key.');
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException(
              'Duplicate Forge v2 placement-evaluation JSON key.',
            );
          }
        }
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      stringStart = index;
    } else if (char == '{') {
      objects.add(<String>{});
    } else if (char == '}') {
      if (objects.isEmpty) {
        throw const FormatException('Invalid Forge v2 placement JSON.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge v2 placement JSON.');
  }
}

bool _placementV2Whitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
