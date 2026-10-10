import 'dart:convert';

import 'forge_device_inventory_placement_batch_evaluation.dart';
import 'forge_device_inventory_declaration.dart';

part 'forge_device_registry_placement_preview_validation.dart';
part 'forge_device_registry_placement_preview_json.dart';

/// Strict response projection for the authenticated registry-backed
/// placement-preview candidate.
///
/// The HTTP response deliberately does not contain the caller fixture's
/// observation or requirements. It is a read-only comparison over the
/// owner-scoped persisted observation and never selects, reserves, schedules,
/// dispatches, or executes work.
const forgeDeviceRegistryPlacementPreviewSchema =
    'forge.device-inventory-placement-evaluation/v2';
const forgeDeviceRegistryPlacementPreviewEvaluationMode = 'offline_static_only';
const forgeDeviceRegistryPlacementPreviewSourceSchema =
    'forge.device-inventory-observation/v2';
const forgeDeviceRegistryPlacementPreviewNotice =
    'Every owner, state, timestamp, resource, GPU, reservation, residency, trust, sandbox, and concurrency value is an unverified caller declaration. This read-only comparison selects no target and grants no execution authority.';
const forgeDeviceRegistryPlacementPreviewMaxDecisions = 128;
const _forgeDeviceRegistryPlacementPreviewMaxSafeInteger = 9007199254740991;

class ForgeDeviceRegistryPlacementPreview {
  final String schemaVersion;
  final String evaluationMode;
  final String sourceSchemaVersion;
  final ForgeDeviceOwner evaluationOwner;
  final int evaluatedAtMS;
  final String notice;
  final List<ForgeDeviceRegistryPlacementDecision> decisions;
  final int eligibleCandidateCount;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeDeviceInventoryPlacementBatchAuthority authority;

  const ForgeDeviceRegistryPlacementPreview({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.sourceSchemaVersion,
    required this.evaluationOwner,
    required this.evaluatedAtMS,
    required this.notice,
    required this.decisions,
    required this.eligibleCandidateCount,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
  });

  factory ForgeDeviceRegistryPlacementPreview.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Forge registry placement preview is too large.',
      );
    }
    _rejectDuplicateRegistryPlacementKeys(source);
    return ForgeDeviceRegistryPlacementPreview.fromJson(jsonDecode(source));
  }

  factory ForgeDeviceRegistryPlacementPreview.fromJson(Object? value) {
    final json = _registryPlacementObject(value);
    _registryPlacementExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'source_schema_version',
      'evaluation_owner',
      'evaluated_at_ms',
      'notice',
      'decisions',
      'eligible_candidate_count',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    });
    if (json['schema_version'] != forgeDeviceRegistryPlacementPreviewSchema ||
        json['evaluation_mode'] !=
            forgeDeviceRegistryPlacementPreviewEvaluationMode ||
        json['source_schema_version'] !=
            forgeDeviceRegistryPlacementPreviewSourceSchema ||
        json['notice'] != forgeDeviceRegistryPlacementPreviewNotice) {
      throw const FormatException(
        'Invalid Forge registry placement preview envelope.',
      );
    }
    if (json['selected_device_id'] != null ||
        json['selected_instance_id'] != null) {
      throw const FormatException(
        'Forge registry placement preview selected a device.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['evaluation_owner']);
    final evaluatedAt = _registryPlacementSafePositiveInt(
      json['evaluated_at_ms'],
    );
    final decisions = _registryPlacementDecisions(json['decisions']);
    final eligible = _registryPlacementSafeNonNegativeInt(
      json['eligible_candidate_count'],
    );
    if (eligible !=
        decisions.where((decision) => decision.matchesRequirements).length) {
      throw const FormatException(
        'Forge registry placement eligible count drifted.',
      );
    }
    final authority = ForgeDeviceInventoryPlacementBatchAuthority.fromJson(
      json['authority'],
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge registry placement preview grants authority.',
      );
    }
    return ForgeDeviceRegistryPlacementPreview(
      schemaVersion: forgeDeviceRegistryPlacementPreviewSchema,
      evaluationMode: forgeDeviceRegistryPlacementPreviewEvaluationMode,
      sourceSchemaVersion: forgeDeviceRegistryPlacementPreviewSourceSchema,
      evaluationOwner: owner,
      evaluatedAtMS: evaluatedAt,
      notice: forgeDeviceRegistryPlacementPreviewNotice,
      decisions: List.unmodifiable(decisions),
      eligibleCandidateCount: eligible,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: authority,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'source_schema_version': sourceSchemaVersion,
    'evaluation_owner': evaluationOwner.toJson(),
    'evaluated_at_ms': evaluatedAtMS,
    'notice': notice,
    'decisions': decisions.map((decision) => decision.toJson()).toList(),
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

class ForgeDeviceRegistryPlacementDecision {
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

  const ForgeDeviceRegistryPlacementDecision({
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

  factory ForgeDeviceRegistryPlacementDecision.fromJson(Object? value) {
    final json = _registryPlacementObject(value);
    _registryPlacementExactKeys(json, {
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
      'owner_declaration_unverified',
      'device_attributes_unverified',
    });
    final matches = json['matches_requirements'];
    if (matches is! bool) {
      throw const FormatException('Invalid Forge registry placement match.');
    }
    final ownerUnverified = json['owner_declaration_unverified'];
    final deviceUnverified = json['device_attributes_unverified'];
    if (ownerUnverified is! bool ||
        !ownerUnverified ||
        deviceUnverified is! bool ||
        !deviceUnverified) {
      throw const FormatException(
        'Forge registry placement declaration became authoritative.',
      );
    }
    final reasons = _registryPlacementReasons(json['exclusion_reasons']);
    if (matches != reasons.isEmpty) {
      throw const FormatException(
        'Forge registry placement match/reasons drifted.',
      );
    }
    final reservation = json['reservation_state'];
    if (reservation is! String ||
        !const {'none', 'reserved'}.contains(reservation)) {
      throw const FormatException(
        'Invalid Forge registry placement reservation state.',
      );
    }
    return ForgeDeviceRegistryPlacementDecision(
      revision: _registryPlacementSafePositiveInt(json['revision']),
      generation: _registryPlacementSafePositiveInt(json['generation']),
      heartbeatSequence: _registryPlacementSafePositiveInt(
        json['heartbeat_sequence'],
      ),
      deviceID: _registryPlacementIdentifier(json['device_id']),
      instanceID: _registryPlacementIdentifier(json['instance_id']),
      reservationState: reservation,
      gpuCount: _registryPlacementBoundedInt(json['gpu_count'], 32),
      availableGPUMemoryBytes: _registryPlacementSafeNonNegativeInt(
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
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'device_attributes_unverified': deviceAttributesUnverified,
  };
}
