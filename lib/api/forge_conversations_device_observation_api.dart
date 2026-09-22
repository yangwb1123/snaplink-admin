part of 'forge_conversations_api.dart';

extension ForgeConversationsApiDeviceInventory on ForgeConversationsApi {
  /// Reads the owner-scoped inventory candidate when an explicitly injected
  /// test or future reviewed source is available. Production Forge keeps
  /// `/devices` unregistered until the ADR-0114/P3b gate is accepted.
  ///
  /// The response is still an unverified declaration. This method never
  /// enrolls or heartbeats a Runner, and it cannot select, reserve, schedule,
  /// dispatch, or execute work.
  Future<ForgeDeviceInventoryPage> readDeviceInventoryCandidate({
    required ForgeDeviceOwner owner,
  }) async {
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    // Candidate resource reads remain one-shot at the authorization
    // boundary. Refresh/replay belongs to the ordinary owner session and
    // must not silently cross this opt-in inventory route.
    final root = await _requestJson(
      'GET',
      '/devices',
      retryUnauthorized: false,
    );
    final page = ForgeDeviceInventoryPage.fromJson(root);
    if (page.owner != expectedOwner) {
      throw const FormatException(
        'Forge returned device inventory for another owner.',
      );
    }
    return page;
  }

  /// Reads the lossless owner-bound v2 inventory candidate when an explicitly
  /// injected test or future reviewed source is available. Production Forge
  /// keeps this route unregistered until the ADR-0114/P3b decision is
  /// accepted.
  ///
  /// The response is still an unverified declaration. This method preserves
  /// reservation and multi-GPU values for display and never enrolls,
  /// heartbeats, selects, reserves, schedules, dispatches, or executes work.
  Future<ForgeDeviceInventoryPageV2> readDeviceInventoryCandidateV2({
    required ForgeDeviceOwner owner,
  }) async {
    final expectedOwner = ForgeDeviceOwner.fromJson(owner.toJson());
    final root = await _requestJson(
      'GET',
      '/devices/observations/v2',
      retryUnauthorized: false,
    );
    final page = ForgeDeviceInventoryPageV2.fromJson(root);
    if (page.owner != expectedOwner) {
      throw const FormatException(
        'Forge returned v2 device inventory for another owner.',
      );
    }
    return page;
  }
}

extension ForgeConversationsApiDeviceObservation on ForgeConversationsApi {
  /// Submits caller-supplied inventory and placement declarations for one
  /// owner-scoped Run. The response remains an unverified offline preview.
  Future<ForgeSessionDeviceObservationWire> previewSessionDeviceObservation({
    required ForgeSessionPlacementRequest request,
  }) async {
    // Run the same pure checks locally before sending the declaration. This
    // does not read a clock or infer any server-owned device state.
    final expectedPlacement = observeForgeSessionPlacement(request);
    final root = await _requestJson(
      'POST',
      '/conversations/${Uri.encodeComponent(request.conversationID)}'
          '/runs/${Uri.encodeComponent(request.runID)}'
          '/device-observation/preview',
      body: request.toJson(),
    );
    final wire = ForgeSessionDeviceObservationWire.fromJson(root);
    if (wire.owner != request.owner ||
        wire.conversationID != request.conversationID ||
        wire.runID != request.runID ||
        wire.evaluatedAtMS != request.placement.evaluatedAtMS ||
        !_sameSessionPlacementObservation(
          wire.placementObservation,
          expectedPlacement,
        ) ||
        !_sameSessionCandidates(wire, request.candidates)) {
      throw const FormatException(
        'Forge returned another session device observation.',
      );
    }
    return wire;
  }
}

bool _sameSessionPlacementObservation(
  ForgeSessionPlacementObservation actual,
  ForgeSessionPlacementObservation expected,
) {
  if (actual.schemaVersion != expected.schemaVersion ||
      actual.evaluationMode != expected.evaluationMode ||
      actual.owner != expected.owner ||
      actual.conversationID != expected.conversationID ||
      actual.runID != expected.runID ||
      actual.evaluatedAtMS != expected.evaluatedAtMS ||
      actual.ownerDeclarationUnverified !=
          expected.ownerDeclarationUnverified ||
      actual.deviceAttributesUnverified !=
          expected.deviceAttributesUnverified ||
      actual.selectedDeviceID != expected.selectedDeviceID ||
      actual.selectedInstanceID != expected.selectedInstanceID ||
      jsonEncode(actual.authority.toJson()) !=
          jsonEncode(expected.authority.toJson()) ||
      actual.decisions.length != expected.decisions.length) {
    return false;
  }
  for (var index = 0; index < actual.decisions.length; index++) {
    final left = actual.decisions[index];
    final right = expected.decisions[index];
    if (left.deviceID != right.deviceID ||
        left.instanceID != right.instanceID ||
        left.matchesRequirements != right.matchesRequirements ||
        left.exclusionReasons.length != right.exclusionReasons.length) {
      return false;
    }
    for (
      var reasonIndex = 0;
      reasonIndex < left.exclusionReasons.length;
      reasonIndex++
    ) {
      if (left.exclusionReasons[reasonIndex] !=
          right.exclusionReasons[reasonIndex]) {
        return false;
      }
    }
  }
  return true;
}

bool _sameSessionCandidates(
  ForgeSessionDeviceObservationWire wire,
  List<ForgeSessionPlacementCandidate> expected,
) {
  final actual = [...wire.inventory.devices]
    ..sort(
      (left, right) => left.device.deviceID.compareTo(right.device.deviceID),
    );
  final declared = [...expected]
    ..sort(
      (left, right) => left.device.deviceID.compareTo(right.device.deviceID),
    );
  if (actual.length != declared.length) return false;
  for (var index = 0; index < actual.length; index++) {
    final actualCandidate = actual[index];
    final declaredCandidate = declared[index];
    if (actualCandidate.instanceID != declaredCandidate.instanceID ||
        jsonEncode(actualCandidate.device.toJson()) !=
            jsonEncode(declaredCandidate.device.toJson())) {
      return false;
    }
  }
  return true;
}
