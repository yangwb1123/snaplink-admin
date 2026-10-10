part of 'forge_device_placement.dart';

class ForgeDevicePlacementDeviceResult {
  final String deviceID;
  final bool attributesUnverified;
  final bool matchesRequirements;
  final List<String> exclusionReasons;

  const ForgeDevicePlacementDeviceResult({
    required this.deviceID,
    required this.attributesUnverified,
    required this.matchesRequirements,
    required this.exclusionReasons,
  });

  factory ForgeDevicePlacementDeviceResult.fromJson(Object? value) {
    final json = _placementObject(value);
    _placementExactKeys(json, {
      'device_id',
      'attributes_unverified',
      'matches_requirements',
      'exclusion_reasons',
    });
    final attributesUnverified = json['attributes_unverified'];
    final matchesRequirements = json['matches_requirements'];
    if (attributesUnverified is! bool ||
        !attributesUnverified ||
        matchesRequirements is! bool) {
      throw const FormatException('Invalid Forge placement result flags.');
    }
    final rawReasons = json['exclusion_reasons'];
    if (rawReasons is! List || rawReasons.length > 64) {
      throw const FormatException('Invalid Forge placement result reasons.');
    }
    final reasons = rawReasons.map(_placementToken).toList(growable: false);
    for (var index = 1; index < reasons.length; index++) {
      if (_placementCompareIDs(reasons[index - 1], reasons[index]) >= 0) {
        throw const FormatException('Unsorted Forge placement reasons.');
      }
    }
    if (matchesRequirements != reasons.isEmpty) {
      throw const FormatException('Inconsistent Forge placement result.');
    }
    return ForgeDevicePlacementDeviceResult(
      deviceID: _placementIdentifier(json['device_id']),
      attributesUnverified: true,
      matchesRequirements: matchesRequirements,
      exclusionReasons: List.unmodifiable(reasons),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceID,
    'attributes_unverified': attributesUnverified,
    'matches_requirements': matchesRequirements,
    'exclusion_reasons': exclusionReasons,
  };
}

class ForgeDevicePlacementResult {
  final String schemaVersion;
  final String evaluationMode;
  final int evaluatedAtMS;
  final ForgeDeviceOwner owner;
  final bool ownerDeclarationUnverified;
  final bool deviceAttributesUnverified;
  final String notice;
  final List<ForgeDevicePlacementDeviceResult> deviceResults;
  final bool executionAuthorized;
  final bool reservationCreated;
  final bool dispatchPerformed;

  const ForgeDevicePlacementResult({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.evaluatedAtMS,
    required this.owner,
    required this.ownerDeclarationUnverified,
    required this.deviceAttributesUnverified,
    required this.notice,
    required this.deviceResults,
    required this.executionAuthorized,
    required this.reservationCreated,
    required this.dispatchPerformed,
  });

  factory ForgeDevicePlacementResult.fromJson(Object? value) {
    final json = _placementObject(value);
    _placementExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'evaluated_at_ms',
      'owner_declaration',
      'owner_declaration_unverified',
      'device_attributes_unverified',
      'notice',
      'device_results',
      'execution_authorized',
      'reservation_created',
      'dispatch_performed',
    });
    if (json['schema_version'] != forgeDevicePlacementResultSchema ||
        json['evaluation_mode'] != forgeDevicePlacementEvaluationMode ||
        json['notice'] != forgeDevicePlacementNotice) {
      throw const FormatException('Invalid Forge placement result schema.');
    }
    final ownerDeclarationUnverified = json['owner_declaration_unverified'];
    final deviceAttributesUnverified = json['device_attributes_unverified'];
    final executionAuthorized = json['execution_authorized'];
    final reservationCreated = json['reservation_created'];
    final dispatchPerformed = json['dispatch_performed'];
    if (ownerDeclarationUnverified is! bool ||
        !ownerDeclarationUnverified ||
        deviceAttributesUnverified is! bool ||
        !deviceAttributesUnverified ||
        executionAuthorized is! bool ||
        executionAuthorized ||
        reservationCreated is! bool ||
        reservationCreated ||
        dispatchPerformed is! bool ||
        dispatchPerformed) {
      throw const FormatException('Forge placement result claims authority.');
    }
    final rawResults = json['device_results'];
    if (rawResults is! List ||
        rawResults.length > forgeDevicePlacementMaxDevices) {
      throw const FormatException('Invalid Forge placement result devices.');
    }
    final results = rawResults
        .map(ForgeDevicePlacementDeviceResult.fromJson)
        .toList(growable: false);
    for (var index = 1; index < results.length; index++) {
      if (_placementCompareIDs(
            results[index - 1].deviceID,
            results[index].deviceID,
          ) >=
          0) {
        throw const FormatException('Unsorted Forge placement results.');
      }
    }
    return ForgeDevicePlacementResult(
      schemaVersion: forgeDevicePlacementResultSchema,
      evaluationMode: forgeDevicePlacementEvaluationMode,
      evaluatedAtMS: _placementPositiveInt(json['evaluated_at_ms']),
      owner: ForgeDeviceOwner.fromJson(json['owner_declaration']),
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
      notice: forgeDevicePlacementNotice,
      deviceResults: List.unmodifiable(results),
      executionAuthorized: false,
      reservationCreated: false,
      dispatchPerformed: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'evaluated_at_ms': evaluatedAtMS,
    'owner_declaration': {
      'issuer': owner.issuer,
      'subject': owner.subject,
      'tenant_id': owner.tenantID,
    },
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'device_attributes_unverified': deviceAttributesUnverified,
    'notice': notice,
    'device_results': deviceResults.map((result) => result.toJson()).toList(),
    'execution_authorized': executionAuthorized,
    'reservation_created': reservationCreated,
    'dispatch_performed': dispatchPerformed,
  };
}

class ForgeDevicePlacementError implements Exception {
  final String code;

  const ForgeDevicePlacementError(this.code);
}
