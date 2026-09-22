import 'dart:convert';

import 'forge_device_inventory_declaration.dart';
import 'forge_device_placement.dart';

part 'forge_device_inventory_placement_batch_evaluation_codec.dart';

/// Strict display values for a bounded persisted-inventory placement dry run.
/// The model performs no request, registration, heartbeat, target selection,
/// reservation, scheduling, dispatch, persistence, or Runner execution.
const forgeDeviceInventoryPlacementBatchEvaluationSchema =
    'forge.device-inventory-placement-batch-evaluation/v1';
const forgeDeviceInventoryPlacementBatchEvaluationMode =
    'pure_persisted_inventory_placement_dry_run';
const forgeDeviceInventoryPlacementBatchEvaluationSourceFixture =
    'forge-device-inventory-placement-input-v1.json';
const forgeDeviceInventoryPlacementBatchEvaluationMaxCases = 128;
const _forgeDeviceInventoryPlacementBatchEvaluationMaxInputBytes =
    2 * 1024 * 1024;

/// Bounded local reader seam for the persisted-inventory placement batch
/// preview. The default Sessions surface uses the platform workspace picker.
typedef ForgeDeviceInventoryPlacementBatchEvaluationFileReader =
    Future<String?> Function();

class ForgeDeviceInventoryPlacementBatchEvaluationFixture {
  final String schemaVersion;
  final String evaluationMode;
  final String sourceFixture;
  final ForgeDeviceOwner evaluationOwner;
  final int evaluatedAtMS;
  final ForgeDevicePlacementRequirements requirements;
  final List<ForgeDeviceInventoryPlacementBatchCase> cases;
  final bool emptyInputsAllowed;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeDeviceInventoryPlacementBatchAuthority authority;
  final List<ForgeDeviceInventoryPlacementBatchErrorCase> errorCases;

  const ForgeDeviceInventoryPlacementBatchEvaluationFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.sourceFixture,
    required this.evaluationOwner,
    required this.evaluatedAtMS,
    required this.requirements,
    required this.cases,
    required this.emptyInputsAllowed,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
    required this.errorCases,
  });

  /// Decodes one bounded JSON document without allowing duplicate object
  /// members to be silently replaced by [dart:convert].
  factory ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJsonText(
    String source,
  ) {
    if (utf8.encode(source).length >
        _forgeDeviceInventoryPlacementBatchEvaluationMaxInputBytes) {
      throw const FormatException(
        'Forge placement-batch evaluation document is too large.',
      );
    }
    _batchEvaluationRejectDuplicateKeys(source);
    return ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
      jsonDecode(source),
    );
  }

  factory ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
    Object? value,
  ) {
    final json = _batchEvaluationObject(value);
    _batchEvaluationExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'source_fixture',
      'evaluation_owner',
      'evaluated_at_ms',
      'requirements',
      'cases',
      'empty_inputs_allowed',
      'selected_device_id',
      'selected_instance_id',
      'authority',
      'error_cases',
    });
    _batchEvaluationValidateEnvelope(json);
    final cases = _batchEvaluationCases(json['cases']);
    final errorCases = _batchEvaluationErrorCases(json['error_cases']);
    return ForgeDeviceInventoryPlacementBatchEvaluationFixture(
      schemaVersion: forgeDeviceInventoryPlacementBatchEvaluationSchema,
      evaluationMode: forgeDeviceInventoryPlacementBatchEvaluationMode,
      sourceFixture: forgeDeviceInventoryPlacementBatchEvaluationSourceFixture,
      evaluationOwner: ForgeDeviceOwner.fromJson(json['evaluation_owner']),
      evaluatedAtMS: _batchEvaluationPositiveSafeInt(json['evaluated_at_ms']),
      requirements: ForgeDevicePlacementRequirements.fromJson(
        json['requirements'],
      ),
      cases: cases,
      emptyInputsAllowed: true,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: ForgeDeviceInventoryPlacementBatchAuthority.fromJson(
        json['authority'],
      ),
      errorCases: errorCases,
    );
  }
}

class ForgeDeviceInventoryPlacementBatchCase {
  final String name;
  final String sourceCase;
  final String deviceID;
  final String instanceID;
  final int? snapshotObservedAtMS;
  final int? capabilityLeaseExpiresAtMS;
  final ForgeDeviceInventoryPlacementBatchDecision expected;

  const ForgeDeviceInventoryPlacementBatchCase({
    required this.name,
    required this.sourceCase,
    required this.deviceID,
    required this.instanceID,
    required this.snapshotObservedAtMS,
    required this.capabilityLeaseExpiresAtMS,
    required this.expected,
  });

  factory ForgeDeviceInventoryPlacementBatchCase.fromJson(Object? value) {
    final json = _batchEvaluationObject(value);
    const allowed = {
      'name',
      'source_case',
      'device_id',
      'instance_id',
      'snapshot_observed_at_ms',
      'capability_lease_expires_at_ms',
      'expected',
    };
    if (json.length < 5 || json.keys.any((key) => !allowed.contains(key))) {
      throw const FormatException('Unexpected Forge placement-batch case.');
    }
    return ForgeDeviceInventoryPlacementBatchCase(
      name: _batchEvaluationCaseName(json['name']),
      sourceCase: _batchEvaluationSourceCase(json['source_case']),
      deviceID: _batchEvaluationIdentifier(json['device_id']),
      instanceID: _batchEvaluationIdentifier(json['instance_id']),
      snapshotObservedAtMS: json.containsKey('snapshot_observed_at_ms')
          ? _batchEvaluationPositiveSafeInt(json['snapshot_observed_at_ms'])
          : null,
      capabilityLeaseExpiresAtMS:
          json.containsKey('capability_lease_expires_at_ms')
          ? _batchEvaluationPositiveSafeInt(
              json['capability_lease_expires_at_ms'],
            )
          : null,
      expected: ForgeDeviceInventoryPlacementBatchDecision.fromJson(
        json['expected'],
      ),
    );
  }
}

class ForgeDeviceInventoryPlacementBatchDecision {
  final int revision;
  final String deviceID;
  final String instanceID;
  final bool matchesRequirements;
  final List<String> exclusionReasons;

  const ForgeDeviceInventoryPlacementBatchDecision({
    required this.revision,
    required this.deviceID,
    required this.instanceID,
    required this.matchesRequirements,
    required this.exclusionReasons,
  });

  factory ForgeDeviceInventoryPlacementBatchDecision.fromJson(Object? value) {
    final json = _batchEvaluationObject(value);
    _batchEvaluationExactKeys(json, {
      'revision',
      'device_id',
      'instance_id',
      'matches_requirements',
      'exclusion_reasons',
    });
    final reasons = _batchEvaluationReasons(json['exclusion_reasons']);
    final matches = _batchEvaluationBool(json['matches_requirements']);
    if (matches != reasons.isEmpty) {
      throw const FormatException(
        'Inconsistent Forge placement-batch decision.',
      );
    }
    return ForgeDeviceInventoryPlacementBatchDecision(
      revision: _batchEvaluationPositiveSafeInt(json['revision']),
      deviceID: _batchEvaluationIdentifier(json['device_id']),
      instanceID: _batchEvaluationIdentifier(json['instance_id']),
      matchesRequirements: matches,
      exclusionReasons: List.unmodifiable(reasons),
    );
  }
}

class ForgeDeviceInventoryPlacementBatchAuthority {
  final bool identityVerified;
  final bool heartbeatPersisted;
  final bool inventoryAuthoritative;
  final bool placementSelected;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeDeviceInventoryPlacementBatchAuthority({
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

  factory ForgeDeviceInventoryPlacementBatchAuthority.fromJson(Object? value) {
    final json = _batchEvaluationObject(value);
    _batchEvaluationExactKeys(json, {
      'identity_verified',
      'heartbeat_persisted',
      'inventory_authoritative',
      'placement_selected',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    final authority = ForgeDeviceInventoryPlacementBatchAuthority(
      identityVerified: _batchEvaluationBool(json['identity_verified']),
      heartbeatPersisted: _batchEvaluationBool(json['heartbeat_persisted']),
      inventoryAuthoritative: _batchEvaluationBool(
        json['inventory_authoritative'],
      ),
      placementSelected: _batchEvaluationBool(json['placement_selected']),
      reservationCreated: _batchEvaluationBool(json['reservation_created']),
      executionAuthorized: _batchEvaluationBool(json['execution_authorized']),
      dispatchPerformed: _batchEvaluationBool(json['dispatch_performed']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge placement-batch authority must remain false.',
      );
    }
    return authority;
  }
}

class ForgeDeviceInventoryPlacementBatchErrorCase {
  final String name;
  final String error;

  const ForgeDeviceInventoryPlacementBatchErrorCase({
    required this.name,
    required this.error,
  });

  factory ForgeDeviceInventoryPlacementBatchErrorCase.fromJson(Object? value) {
    final json = _batchEvaluationObject(value);
    _batchEvaluationExactKeys(json, {'name', 'error'});
    final name = _batchEvaluationErrorCaseName(json['name']);
    final error = _batchEvaluationError(json['error']);
    if (!_batchEvaluationKnownError(error)) {
      throw const FormatException('Unknown Forge placement-batch error.');
    }
    return ForgeDeviceInventoryPlacementBatchErrorCase(
      name: name,
      error: error,
    );
  }
}
