import 'dart:convert';

import 'forge_device_inventory_placement_batch_evaluation.dart';
import 'forge_device_inventory_declaration.dart';
import 'forge_device_inventory_v2_models.dart';
import 'forge_device_placement.dart';

part 'forge_device_inventory_placement_evaluation_v2_projection.dart';
part 'forge_device_inventory_placement_evaluation_v2_codec.dart';

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
