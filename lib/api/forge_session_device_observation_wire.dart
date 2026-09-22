import 'forge_device_inventory_models.dart';
import 'forge_session_placement.dart';

/// Canonical, caller-supplied P3a envelope shared by Forge clients.
///
/// This value is deliberately a display contract. It contains no registry
/// state, heartbeat proof, target selection, reservation, or execution grant.
const forgeSessionDeviceObservationSchema =
    'forge.session-device-observation/v1';
const forgeSessionDeviceObservationEvaluationMode = 'offline_static_only';
const forgeSessionDeviceObservationMaxSafeInteger = 9007199254740991;

class ForgeSessionDeviceObservationWire {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final int evaluatedAtMS;
  final bool ownerDeclarationUnverified;
  final ForgeDeviceInventoryPage inventory;
  final ForgeSessionPlacementObservation placementObservation;
  final ForgeDeviceResourceSummary resourceSummary;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeSessionPlacementAuthority authority;

  const ForgeSessionDeviceObservationWire({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.evaluatedAtMS,
    required this.ownerDeclarationUnverified,
    required this.inventory,
    required this.placementObservation,
    required this.resourceSummary,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
  });

  factory ForgeSessionDeviceObservationWire.fromJson(Object? value) {
    final json = _wireObject(value);
    _wireExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'evaluated_at_ms',
      'owner_declaration_unverified',
      'inventory',
      'placement_observation',
      'resource_summary',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    });
    if (json['schema_version'] != forgeSessionDeviceObservationSchema ||
        json['evaluation_mode'] !=
            forgeSessionDeviceObservationEvaluationMode ||
        json['owner_declaration_unverified'] != true ||
        json['selected_device_id'] != null ||
        json['selected_instance_id'] != null) {
      throw const FormatException(
        'Invalid Forge session device observation envelope.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final conversationID = _wireIdentifier(json['conversation_id']);
    final runID = _wireIdentifier(json['run_id']);
    final evaluatedAtMS = _wirePositiveInt(json['evaluated_at_ms']);
    final inventory = ForgeDeviceInventoryPage.fromJson(json['inventory']);
    final placement = ForgeSessionPlacementObservation.fromJson(
      json['placement_observation'],
    );
    final resourceSummary = ForgeDeviceResourceSummary.fromJson(
      json['resource_summary'],
    );
    final authority = ForgeSessionPlacementAuthority.fromJson(
      json['authority'],
    );
    if (inventory.owner != owner ||
        inventory.evaluatedAtMS != evaluatedAtMS ||
        placement.owner != owner ||
        placement.conversationID != conversationID ||
        placement.runID != runID ||
        placement.evaluatedAtMS != evaluatedAtMS ||
        resourceSummary.owner != owner ||
        resourceSummary.conversationID != conversationID ||
        resourceSummary.runID != runID ||
        resourceSummary.evaluatedAtMS != evaluatedAtMS ||
        !_wireOfflineAuthority(authority)) {
      throw const FormatException(
        'Forge session device observation binding or authority mismatch.',
      );
    }
    final recomputed = observeForgeDeviceResourceSummary(
      ForgeDeviceResourceSummaryRequest(
        owner: owner,
        inventory: inventory.devices,
        placement: placement,
      ),
    );
    if (!_wireMapsEqual(recomputed.toJson(), resourceSummary.toJson())) {
      throw const FormatException(
        'Forge session device resource summary drifted from declarations.',
      );
    }
    return ForgeSessionDeviceObservationWire(
      schemaVersion: forgeSessionDeviceObservationSchema,
      evaluationMode: forgeSessionDeviceObservationEvaluationMode,
      owner: owner,
      conversationID: conversationID,
      runID: runID,
      evaluatedAtMS: evaluatedAtMS,
      ownerDeclarationUnverified: true,
      inventory: inventory,
      placementObservation: placement,
      resourceSummary: resourceSummary,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: authority,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': owner.toJson(),
    'conversation_id': conversationID,
    'run_id': runID,
    'evaluated_at_ms': evaluatedAtMS,
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'inventory': inventory.toJson(),
    'placement_observation': placementObservation.toJson(),
    'resource_summary': resourceSummary.toJson(),
    'selected_device_id': selectedDeviceID,
    'selected_instance_id': selectedInstanceID,
    'authority': authority.toJson(),
  };
}

Map<String, dynamic> _wireObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge session device object.');
  }
  return Map<String, dynamic>.from(value);
}

void _wireExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge session device fields.');
  }
}

String _wireIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_wireIdentifierValue(value)) {
    throw const FormatException('Invalid Forge session device identifier.');
  }
  return value;
}

bool _wireIdentifierValue(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) || const [0x2e, 0x5f, 0x3a, 0x2d].contains(code);
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

int _wirePositiveInt(Object? value) {
  if (value is! int ||
      value <= 0 ||
      value > forgeSessionDeviceObservationMaxSafeInteger) {
    throw const FormatException('Invalid Forge session device integer.');
  }
  return value;
}

bool _wireOfflineAuthority(ForgeSessionPlacementAuthority authority) =>
    !authority.identityVerified &&
    !authority.heartbeatPersisted &&
    !authority.inventoryAuthoritative &&
    !authority.reservationCreated &&
    !authority.executionAuthorized &&
    !authority.dispatchPerformed;

bool _wireMapsEqual(Map<String, dynamic> left, Map<String, dynamic> right) {
  if (left.length != right.length ||
      left.keys.any((key) => !right.containsKey(key))) {
    return false;
  }
  for (final key in left.keys) {
    final leftValue = left[key];
    final rightValue = right[key];
    if (leftValue is Map && rightValue is Map) {
      if (!_wireMapsEqual(
        Map<String, dynamic>.from(leftValue),
        Map<String, dynamic>.from(rightValue),
      )) {
        return false;
      }
    } else if (leftValue is List && rightValue is List) {
      if (leftValue.length != rightValue.length) return false;
      for (var index = 0; index < leftValue.length; index++) {
        final a = leftValue[index];
        final b = rightValue[index];
        if (a is Map && b is Map) {
          if (!_wireMapsEqual(
            Map<String, dynamic>.from(a),
            Map<String, dynamic>.from(b),
          )) {
            return false;
          }
        } else if (a != b) {
          return false;
        }
      }
    } else if (leftValue != rightValue) {
      return false;
    }
  }
  return true;
}
