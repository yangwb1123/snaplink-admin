import 'dart:convert';

import 'forge_device_placement.dart';

part 'forge_device_inventory_placement_evaluation_codec.dart';

/// Strict offline display values for the persisted-inventory placement
/// evaluation contract. This module has no request, registration, selection,
/// reservation, dispatch, persistence, or Runner execution behavior.
const forgeDeviceInventoryPlacementEvaluationSchema =
    'forge.device-inventory-placement-evaluation/v1';
const forgeDeviceInventoryPlacementEvaluationMode =
    'pure_persisted_inventory_offline_evaluation';
const forgeDeviceInventoryPlacementEvaluationSourceFixture =
    'forge-device-inventory-placement-input-v1.json';
const forgeDeviceInventoryPlacementEvaluationSourceCase = 'online';
const _forgeDeviceInventoryPlacementEvaluationMaxInputBytes = 2 * 1024 * 1024;

/// Bounded local reader seam for the persisted-inventory placement evaluation.
/// The default Sessions surface uses the platform workspace picker.
typedef ForgeDeviceInventoryPlacementEvaluationFileReader =
    Future<String?> Function();

class ForgeDeviceInventoryPlacementEvaluationFixture {
  final String schemaVersion;
  final String evaluationMode;
  final String sourceFixture;
  final String sourceCase;
  final int evaluatedAtMS;
  final ForgeDevicePlacementRequirements policyRequirements;
  final ForgeDeviceInventoryPlacementEvaluationAuthority authority;
  final ForgeDeviceInventoryPlacementEvaluationExpected expected;

  const ForgeDeviceInventoryPlacementEvaluationFixture({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.sourceFixture,
    required this.sourceCase,
    required this.evaluatedAtMS,
    required this.policyRequirements,
    required this.authority,
    required this.expected,
  });

  /// Decodes one bounded JSON document without allowing duplicate object
  /// members to be silently replaced by [dart:convert].
  factory ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(
    String source,
  ) {
    if (utf8.encode(source).length >
        _forgeDeviceInventoryPlacementEvaluationMaxInputBytes) {
      throw const FormatException(
        'Forge placement-evaluation document is too large.',
      );
    }
    _inventoryEvaluationRejectDuplicateKeys(source);
    return ForgeDeviceInventoryPlacementEvaluationFixture.fromJson(
      jsonDecode(source),
    );
  }

  factory ForgeDeviceInventoryPlacementEvaluationFixture.fromJson(
    Object? value,
  ) {
    final json = _inventoryEvaluationObject(value);
    _inventoryEvaluationExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'source_fixture',
      'source_case',
      'evaluated_at_ms',
      'policy_requirements',
      'authority',
      'expected',
    });
    if (json['schema_version'] !=
            forgeDeviceInventoryPlacementEvaluationSchema ||
        json['evaluation_mode'] !=
            forgeDeviceInventoryPlacementEvaluationMode ||
        json['source_fixture'] !=
            forgeDeviceInventoryPlacementEvaluationSourceFixture ||
        json['source_case'] !=
            forgeDeviceInventoryPlacementEvaluationSourceCase) {
      throw const FormatException(
        'Invalid Forge persisted placement-evaluation envelope.',
      );
    }
    return ForgeDeviceInventoryPlacementEvaluationFixture(
      schemaVersion: forgeDeviceInventoryPlacementEvaluationSchema,
      evaluationMode: forgeDeviceInventoryPlacementEvaluationMode,
      sourceFixture: forgeDeviceInventoryPlacementEvaluationSourceFixture,
      sourceCase: forgeDeviceInventoryPlacementEvaluationSourceCase,
      evaluatedAtMS: _inventoryEvaluationSafePositiveInt(
        json['evaluated_at_ms'],
      ),
      policyRequirements: ForgeDevicePlacementRequirements.fromJson(
        json['policy_requirements'],
      ),
      authority: ForgeDeviceInventoryPlacementEvaluationAuthority.fromJson(
        json['authority'],
      ),
      expected: ForgeDeviceInventoryPlacementEvaluationExpected.fromJson(
        json['expected'],
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'source_fixture': sourceFixture,
    'source_case': sourceCase,
    'evaluated_at_ms': evaluatedAtMS,
    'policy_requirements': policyRequirements.toJson(),
    'authority': authority.toJson(),
    'expected': expected.toJson(),
  };
}

class ForgeDeviceInventoryPlacementEvaluationAuthority {
  final bool placementEvaluated;
  final bool placementSelected;
  final bool reservationCreated;
  final bool executionAuthorized;
  final bool dispatchPerformed;

  const ForgeDeviceInventoryPlacementEvaluationAuthority({
    required this.placementEvaluated,
    required this.placementSelected,
    required this.reservationCreated,
    required this.executionAuthorized,
    required this.dispatchPerformed,
  });

  bool get anyGranted =>
      placementEvaluated ||
      placementSelected ||
      reservationCreated ||
      executionAuthorized ||
      dispatchPerformed;

  Map<String, dynamic> toJson() => {
    'placement_evaluated': placementEvaluated,
    'placement_selected': placementSelected,
    'reservation_created': reservationCreated,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
  };

  factory ForgeDeviceInventoryPlacementEvaluationAuthority.fromJson(
    Object? value,
  ) {
    final json = _inventoryEvaluationObject(value);
    _inventoryEvaluationExactKeys(json, {
      'placement_evaluated',
      'placement_selected',
      'reservation_created',
      'execution_authorized',
      'dispatch_performed',
    });
    final authority = ForgeDeviceInventoryPlacementEvaluationAuthority(
      placementEvaluated: _inventoryEvaluationBool(json['placement_evaluated']),
      placementSelected: _inventoryEvaluationBool(json['placement_selected']),
      reservationCreated: _inventoryEvaluationBool(json['reservation_created']),
      executionAuthorized: _inventoryEvaluationBool(
        json['execution_authorized'],
      ),
      dispatchPerformed: _inventoryEvaluationBool(json['dispatch_performed']),
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge persisted placement-evaluation authority must remain false.',
      );
    }
    return authority;
  }
}

class ForgeDeviceInventoryPlacementEvaluationExpected {
  final bool accepted;
  final String error;
  final int? revision;
  final String? deviceID;
  final String? instanceID;
  final bool? matchesRequirements;
  final List<String>? exclusionReasons;
  final bool? ownerDeclarationUnverified;
  final bool? deviceAttributesUnverified;

  const ForgeDeviceInventoryPlacementEvaluationExpected({
    required this.accepted,
    required this.error,
    required this.revision,
    required this.deviceID,
    required this.instanceID,
    required this.matchesRequirements,
    required this.exclusionReasons,
    required this.ownerDeclarationUnverified,
    required this.deviceAttributesUnverified,
  });

  Map<String, dynamic> toJson() => {
    'accepted': accepted,
    'error': error,
    if (accepted) ...{
      'revision': revision,
      'device_id': deviceID,
      'instance_id': instanceID,
      'matches_requirements': matchesRequirements,
      'exclusion_reasons': exclusionReasons,
      'owner_declaration_unverified': ownerDeclarationUnverified,
      'device_attributes_unverified': deviceAttributesUnverified,
    },
  };

  factory ForgeDeviceInventoryPlacementEvaluationExpected.fromJson(
    Object? value,
  ) {
    final json = _inventoryEvaluationObject(value);
    final accepted = _inventoryEvaluationBool(json['accepted']);
    final error = _inventoryEvaluationError(json['error']);
    if (!accepted) {
      _inventoryEvaluationExactKeys(json, {'accepted', 'error'});
      if (!_inventoryEvaluationKnownError(error)) {
        throw const FormatException(
          'Unknown Forge persisted placement-evaluation error.',
        );
      }
      return ForgeDeviceInventoryPlacementEvaluationExpected(
        accepted: false,
        error: error,
        revision: null,
        deviceID: null,
        instanceID: null,
        matchesRequirements: null,
        exclusionReasons: null,
        ownerDeclarationUnverified: null,
        deviceAttributesUnverified: null,
      );
    }
    _inventoryEvaluationExactKeys(json, {
      'accepted',
      'error',
      'revision',
      'device_id',
      'instance_id',
      'matches_requirements',
      'exclusion_reasons',
      'owner_declaration_unverified',
      'device_attributes_unverified',
    });
    if (error.isNotEmpty) {
      throw const FormatException(
        'Accepted Forge placement evaluation has an error.',
      );
    }
    final matches = _inventoryEvaluationBool(json['matches_requirements']);
    final reasons = _inventoryEvaluationReasons(json['exclusion_reasons']);
    if (matches != reasons.isEmpty) {
      throw const FormatException(
        'Inconsistent Forge placement-evaluation decision.',
      );
    }
    final ownerUnverified = _inventoryEvaluationBool(
      json['owner_declaration_unverified'],
    );
    final attributesUnverified = _inventoryEvaluationBool(
      json['device_attributes_unverified'],
    );
    if (!ownerUnverified || !attributesUnverified) {
      throw const FormatException(
        'Forge placement-evaluation declarations must remain unverified.',
      );
    }
    return ForgeDeviceInventoryPlacementEvaluationExpected(
      accepted: true,
      error: error,
      revision: _inventoryEvaluationSafePositiveInt(json['revision']),
      deviceID: _inventoryEvaluationIdentifier(json['device_id']),
      instanceID: _inventoryEvaluationIdentifier(json['instance_id']),
      matchesRequirements: matches,
      exclusionReasons: List.unmodifiable(reasons),
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
    );
  }
}
