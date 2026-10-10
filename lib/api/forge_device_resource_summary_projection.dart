part of 'forge_device_resource_summary.dart';

/// Aggregates caller-supplied inventory and an already observed placement
/// declaration. This pure projection has no clock, network, persistence,
/// target selection, reservation, authorization, or execution effect.
ForgeDeviceResourceSummary observeForgeDeviceResourceSummary(
  ForgeDeviceResourceSummaryRequest request,
) {
  if (request.inventory.length > forgeDeviceResourceSummaryMaxDeclarations ||
      !_validOwner(request.owner) ||
      !_validPlacement(request.placement, request.owner)) {
    throw const ForgeDeviceResourceSummaryError('invalid_binding');
  }

  final byDevice = <String, ForgeDeviceInventoryCandidate>{};
  final instances = <String>{};
  for (final candidate in request.inventory) {
    if (!_identifier(candidate.device.deviceID) ||
        !_identifier(candidate.instanceID) ||
        !_validOwner(candidate.device.owner) ||
        candidate.device.owner != request.owner ||
        byDevice.containsKey(candidate.device.deviceID) ||
        !instances.add(candidate.instanceID)) {
      throw const ForgeDeviceResourceSummaryError('invalid_inventory');
    }
    byDevice[candidate.device.deviceID] = candidate;
  }
  if (request.placement.decisions.length != request.inventory.length) {
    throw const ForgeDeviceResourceSummaryError('invalid_binding');
  }

  final decisions = [...request.placement.decisions]
    ..sort((left, right) {
      final device = _compareIDs(left.deviceID, right.deviceID);
      return device == 0
          ? _compareIDs(left.instanceID, right.instanceID)
          : device;
    });
  final devices = <String>{};
  final decisionInstances = <String>{};
  var eligibleDevices = 0;
  var eligibleInstances = 0;
  for (final decision in decisions) {
    if (!_identifier(decision.deviceID) ||
        !_identifier(decision.instanceID) ||
        !devices.add(decision.deviceID) ||
        !decisionInstances.add(decision.instanceID)) {
      throw const ForgeDeviceResourceSummaryError('invalid_placement');
    }
    final candidate = byDevice[decision.deviceID];
    if (candidate == null || candidate.instanceID != decision.instanceID) {
      throw const ForgeDeviceResourceSummaryError('invalid_binding');
    }
    if (decision.matchesRequirements) {
      eligibleDevices++;
      eligibleInstances++;
    }
  }

  var availableCPUCores = 0;
  var availableMemoryBytes = 0;
  var availableStorageBytes = 0;
  var availableGPUCount = 0;
  var availableGPUMemoryBytes = 0;
  for (final candidate in request.inventory) {
    final device = candidate.device;
    availableCPUCores = _add(availableCPUCores, device.availableCPUCores);
    availableMemoryBytes = _add(
      availableMemoryBytes,
      device.availableMemoryBytes,
    );
    availableStorageBytes = _add(
      availableStorageBytes,
      device.availableStorageBytes,
    );
    if (device.gpu.present) {
      availableGPUCount++;
      availableGPUMemoryBytes = _add(
        availableGPUMemoryBytes,
        device.gpu.memoryBytes,
      );
    }
  }
  final count = request.inventory.length;
  return ForgeDeviceResourceSummary(
    schemaVersion: forgeDeviceResourceSummarySchema,
    evaluationMode: forgeDeviceResourceSummaryEvaluationMode,
    owner: request.owner,
    conversationID: request.placement.conversationID,
    runID: request.placement.runID,
    evaluatedAtMS: request.placement.evaluatedAtMS,
    ownerDeclarationUnverified: true,
    inventoryDeclarationsUnverified: true,
    placementDeclarationUnverified: true,
    notice: forgeDeviceResourceSummaryNotice,
    deviceCount: count,
    runnerInstanceCount: count,
    availableCPUCores: availableCPUCores,
    availableMemoryBytes: availableMemoryBytes,
    availableStorageBytes: availableStorageBytes,
    availableGPUCount: availableGPUCount,
    availableGPUMemoryBytes: availableGPUMemoryBytes,
    eligibleDeviceCount: eligibleDevices,
    eligibleInstanceCount: eligibleInstances,
    selectedDeviceID: null,
    selectedInstanceID: null,
    authority: const ForgeSessionPlacementAuthority.offline(),
  );
}

bool _validOwner(ForgeDeviceOwner owner) =>
    _validOwnerPart(owner.issuer) &&
    _validOwnerPart(owner.subject) &&
    _validOwnerPart(owner.tenantID);

bool _validOwnerPart(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      utf8.encode(value).length > 512) {
    return false;
  }
  return value.codeUnits.every(
    (unit) => unit > 0x1f && !(unit >= 0x7f && unit <= 0x9f),
  );
}

bool _validPlacement(
  ForgeSessionPlacementObservation placement,
  ForgeDeviceOwner owner,
) {
  return placement.schemaVersion == forgeSessionPlacementObservationSchema &&
      placement.evaluationMode == forgeDeviceResourceSummaryEvaluationMode &&
      placement.owner == owner &&
      _identifier(placement.conversationID) &&
      _identifier(placement.runID) &&
      placement.evaluatedAtMS > 0 &&
      placement.evaluatedAtMS <= forgeDeviceResourceSummaryMaxSafeInteger &&
      placement.ownerDeclarationUnverified &&
      placement.deviceAttributesUnverified &&
      placement.selectedDeviceID == null &&
      placement.selectedInstanceID == null &&
      _offlineAuthority(placement.authority);
}

bool _offlineAuthority(ForgeSessionPlacementAuthority authority) =>
    !authority.identityVerified &&
    !authority.heartbeatPersisted &&
    !authority.inventoryAuthoritative &&
    !authority.reservationCreated &&
    !authority.executionAuthorized &&
    !authority.dispatchPerformed;

bool _identifier(String value) {
  if (value.isEmpty || value.length > 128) return false;
  final codes = value.codeUnits;
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  if (!first(codes.first)) return false;
  return codes
      .skip(1)
      .every(
        (code) =>
            first(code) ||
            const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
      );
}

int _add(int left, int right) {
  if (right < 0 || left > forgeDeviceResourceSummaryMaxSafeInteger - right) {
    throw const ForgeDeviceResourceSummaryError('resource_overflow');
  }
  return left + right;
}

int _compareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
