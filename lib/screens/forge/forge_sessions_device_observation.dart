import 'package:flutter/material.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/api/forge_session_device_observation_wire.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'forge_device_inventory_panel.dart';

/// A caller-supplied, offline-only device observation bound to one Forge Run.
///
/// The factory evaluates the existing pure placement and resource-summary
/// functions. It does not read a clock, make a request, persist inventory, or
/// select a target. A session page must match both IDs before it renders this
/// value.
class ForgeSessionDeviceObservation {
  final String conversationID;
  final String runID;
  final ForgeDeviceInventoryPage page;
  final ForgeDeviceInventorySnapshot? snapshot;
  final ForgeDevicePlacementResult placement;
  final ForgeSessionPlacementObservation placementObservation;
  final ForgeDeviceResourceSummary resourceSummary;
  final Map<String, ForgeDeviceInventoryStatusProjection>
  statusByDeviceInstance;

  const ForgeSessionDeviceObservation._({
    required this.conversationID,
    required this.runID,
    required this.page,
    required this.snapshot,
    required this.placement,
    required this.placementObservation,
    required this.resourceSummary,
    required this.statusByDeviceInstance,
  });

  /// Builds a display observation from explicit caller declarations.
  ///
  /// [candidates] must be the same device/Runner pairs as [page]. The
  /// requirements and evaluation time are caller inputs; this method never
  /// obtains either value from the selected session or from a token.
  factory ForgeSessionDeviceObservation.fromOfflineDeclarations({
    required String conversationID,
    required String runID,
    required ForgeDeviceInventoryPage page,
    required ForgeDevicePlacementRequirements requirements,
    required int maxSnapshotAgeMS,
    required List<ForgeSessionPlacementCandidate> candidates,
    ForgeDeviceInventorySnapshot? snapshot,
  }) {
    final safePage = _copyPage(page);
    _validatePage(safePage);
    if (snapshot != null) {
      final canonical = canonicalizeForgeDeviceInventorySnapshot(snapshot);
      if (canonical.owner != safePage.owner) {
        throw const ForgeSessionDeviceObservationError('snapshot_owner');
      }
      final pageRows = {
        for (final candidate in safePage.devices)
          '${candidate.device.deviceID}::${candidate.instanceID}',
      };
      if (canonical.rows.any(
        (row) => !pageRows.contains('${row.deviceID}::${row.instanceID}'),
      )) {
        throw const ForgeSessionDeviceObservationError('snapshot_binding');
      }
      snapshot = canonical;
    }
    _validateCandidates(safePage, candidates);
    final placementRequest = ForgeDevicePlacementRequest(
      schemaVersion: forgeDevicePlacementRequestSchema,
      evaluatedAtMS: safePage.evaluatedAtMS,
      owner: safePage.owner,
      maxSnapshotAgeMS: maxSnapshotAgeMS,
      requirements: requirements,
      devices: safePage.devices
          .map((candidate) => candidate.device)
          .toList(growable: false),
    );
    try {
      final placement = dryRunForgeDevicePlacement(placementRequest);
      final placementObservation = observeForgeSessionPlacement(
        ForgeSessionPlacementRequest(
          owner: safePage.owner,
          conversationID: conversationID,
          runID: runID,
          placement: placementRequest,
          candidates: candidates,
        ),
      );
      final resourceSummary = observeForgeDeviceResourceSummary(
        ForgeDeviceResourceSummaryRequest(
          owner: safePage.owner,
          inventory: safePage.devices,
          placement: placementObservation,
        ),
      );
      return ForgeSessionDeviceObservation._(
        conversationID: conversationID,
        runID: runID,
        page: safePage,
        snapshot: snapshot,
        placement: placement,
        placementObservation: placementObservation,
        resourceSummary: resourceSummary,
        statusByDeviceInstance: _statusProjections(safePage),
      );
    } on ForgeSessionDeviceObservationError {
      rethrow;
    } catch (_) {
      throw const ForgeSessionDeviceObservationError('invalid_declaration');
    }
  }

  /// Consumes a strict, caller-supplied wire envelope without adding any
  /// authority. The envelope is recomputed against its inventory and
  /// placement declarations before it reaches the widget.
  factory ForgeSessionDeviceObservation.fromWire(
    ForgeSessionDeviceObservationWire wire,
  ) {
    try {
      final safePage = _copyPage(wire.inventory);
      _validatePage(safePage);
      if (wire.schemaVersion != forgeSessionDeviceObservationSchema ||
          wire.evaluationMode != forgeSessionDeviceObservationEvaluationMode ||
          !wire.ownerDeclarationUnverified ||
          wire.selectedDeviceID != null ||
          wire.selectedInstanceID != null ||
          !_offlineAuthority(wire.authority) ||
          wire.owner != safePage.owner ||
          wire.inventory.evaluatedAtMS != wire.evaluatedAtMS ||
          wire.placementObservation.owner != wire.owner ||
          wire.placementObservation.conversationID != wire.conversationID ||
          wire.placementObservation.runID != wire.runID ||
          wire.placementObservation.evaluatedAtMS != wire.evaluatedAtMS) {
        throw const ForgeSessionDeviceObservationError('wire_binding');
      }
      final resourceSummary = observeForgeDeviceResourceSummary(
        ForgeDeviceResourceSummaryRequest(
          owner: wire.owner,
          inventory: safePage.devices,
          placement: wire.placementObservation,
        ),
      );
      if (!_sameResourceSummary(resourceSummary, wire.resourceSummary)) {
        throw const ForgeSessionDeviceObservationError('wire_summary');
      }
      return ForgeSessionDeviceObservation._(
        conversationID: wire.conversationID,
        runID: wire.runID,
        page: safePage,
        snapshot: null,
        placement: _placementResult(wire.placementObservation),
        placementObservation: wire.placementObservation,
        resourceSummary: resourceSummary,
        statusByDeviceInstance: _statusProjections(safePage),
      );
    } on ForgeSessionDeviceObservationError {
      rethrow;
    } catch (_) {
      throw const ForgeSessionDeviceObservationError('invalid_wire');
    }
  }

  bool isFor(String conversationID, String runID) =>
      this.conversationID == conversationID && this.runID == runID;

  static void _validatePage(ForgeDeviceInventoryPage page) {
    if (page.evaluationMode != forgeDeviceInventoryEvaluationMode ||
        !page.ownerDeclarationUnverified ||
        !page.inventoryDeclarationsUnverified ||
        page.notice != forgeDeviceInventoryNotice ||
        page.executionAuthorized ||
        page.reservationCreated ||
        page.dispatchPerformed) {
      throw const ForgeSessionDeviceObservationError('page_authority');
    }
    final devices = <String>{};
    final instances = <String>{};
    for (final candidate in page.devices) {
      if (!devices.add(candidate.device.deviceID) ||
          !instances.add(candidate.instanceID) ||
          candidate.device.owner != page.owner) {
        throw const ForgeSessionDeviceObservationError('page_binding');
      }
    }
  }

  static ForgeDeviceInventoryPage _copyPage(ForgeDeviceInventoryPage page) =>
      ForgeDeviceInventoryPage(
        evaluationMode: page.evaluationMode,
        evaluatedAtMS: page.evaluatedAtMS,
        owner: page.owner,
        ownerDeclarationUnverified: page.ownerDeclarationUnverified,
        inventoryDeclarationsUnverified: page.inventoryDeclarationsUnverified,
        notice: page.notice,
        devices: List.unmodifiable(
          page.devices.map(
            (candidate) => ForgeDeviceInventoryCandidate(
              instanceID: candidate.instanceID,
              device: _copyDevice(candidate.device),
            ),
          ),
        ),
        executionAuthorized: page.executionAuthorized,
        reservationCreated: page.reservationCreated,
        dispatchPerformed: page.dispatchPerformed,
      );

  static ForgeDeviceDeclaration _copyDevice(ForgeDeviceDeclaration device) =>
      ForgeDeviceDeclaration(
        deviceID: device.deviceID,
        owner: device.owner,
        approvalState: device.approvalState,
        cordonState: device.cordonState,
        liveness: device.liveness,
        snapshotObservedAtMS: device.snapshotObservedAtMS,
        leaseExpiresAtMS: device.leaseExpiresAtMS,
        os: device.os,
        architecture: device.architecture,
        availableCPUCores: device.availableCPUCores,
        availableMemoryBytes: device.availableMemoryBytes,
        availableStorageBytes: device.availableStorageBytes,
        runtimes: List.unmodifiable(device.runtimes),
        gpu: ForgeDeviceGpu(
          present: device.gpu.present,
          memoryBytes: device.gpu.memoryBytes,
          runtime: device.gpu.runtime,
        ),
        dataResidencyZones: List.unmodifiable(device.dataResidencyZones),
        trustZone: device.trustZone,
        sandboxLevels: List.unmodifiable(device.sandboxLevels),
        concurrencyLimit: device.concurrencyLimit,
        activeConcurrency: device.activeConcurrency,
      );

  static void _validateCandidates(
    ForgeDeviceInventoryPage page,
    List<ForgeSessionPlacementCandidate> candidates,
  ) {
    if (candidates.length != page.devices.length) {
      throw const ForgeSessionDeviceObservationError('candidate_binding');
    }
    final pageByDevice = {
      for (final candidate in page.devices)
        candidate.device.deviceID: candidate,
    };
    for (final candidate in candidates) {
      final pageCandidate = pageByDevice[candidate.device.deviceID];
      if (pageCandidate == null ||
          pageCandidate.instanceID != candidate.instanceID ||
          candidate.device.owner != page.owner ||
          !_sameDevice(candidate.device, pageCandidate.device)) {
        throw const ForgeSessionDeviceObservationError('candidate_binding');
      }
    }
  }

  static bool _sameDevice(
    ForgeDeviceDeclaration left,
    ForgeDeviceDeclaration right,
  ) =>
      left.deviceID == right.deviceID &&
      left.owner == right.owner &&
      left.approvalState == right.approvalState &&
      left.cordonState == right.cordonState &&
      left.liveness == right.liveness &&
      left.snapshotObservedAtMS == right.snapshotObservedAtMS &&
      left.leaseExpiresAtMS == right.leaseExpiresAtMS &&
      left.os == right.os &&
      left.architecture == right.architecture &&
      left.availableCPUCores == right.availableCPUCores &&
      left.availableMemoryBytes == right.availableMemoryBytes &&
      left.availableStorageBytes == right.availableStorageBytes &&
      _sameStrings(left.runtimes, right.runtimes) &&
      left.gpu.present == right.gpu.present &&
      left.gpu.memoryBytes == right.gpu.memoryBytes &&
      left.gpu.runtime == right.gpu.runtime &&
      _sameStrings(left.dataResidencyZones, right.dataResidencyZones) &&
      left.trustZone == right.trustZone &&
      _sameStrings(left.sandboxLevels, right.sandboxLevels) &&
      left.concurrencyLimit == right.concurrencyLimit &&
      left.activeConcurrency == right.activeConcurrency;

  static bool _sameStrings(List<String> left, List<String> right) {
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index++) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  static Map<String, ForgeDeviceInventoryStatusProjection> _statusProjections(
    ForgeDeviceInventoryPage page,
  ) {
    final statuses = <String, ForgeDeviceInventoryStatusProjection>{};
    for (final candidate in page.devices) {
      try {
        statuses[ForgeDeviceInventoryPanel.statusKey(
          candidate.device.deviceID,
          candidate.instanceID,
        )] = projectForgeDeviceInventoryStatus(
          ForgeDeviceInventoryStatusObservation(
            approvalState: candidate.device.approvalState,
            cordonState: candidate.device.cordonState,
            liveness: candidate.device.liveness,
            reservationState: 'none',
            snapshotObservedAtMS: candidate.device.snapshotObservedAtMS,
            leaseExpiresAtMS: candidate.device.leaseExpiresAtMS,
            evaluatedAtMS: page.evaluatedAtMS,
          ),
        );
      } on ForgeDeviceInventoryStatusError {
        // Unknown caller-declared status remains visible as unavailable.
      }
    }
    return Map.unmodifiable(statuses);
  }

  static bool _offlineAuthority(ForgeSessionPlacementAuthority authority) =>
      !authority.identityVerified &&
      !authority.heartbeatPersisted &&
      !authority.inventoryAuthoritative &&
      !authority.reservationCreated &&
      !authority.executionAuthorized &&
      !authority.dispatchPerformed;

  static ForgeDevicePlacementResult _placementResult(
    ForgeSessionPlacementObservation observation,
  ) => ForgeDevicePlacementResult(
    schemaVersion: forgeDevicePlacementResultSchema,
    evaluationMode: forgeDevicePlacementEvaluationMode,
    evaluatedAtMS: observation.evaluatedAtMS,
    owner: observation.owner,
    ownerDeclarationUnverified: true,
    deviceAttributesUnverified: true,
    notice: forgeDevicePlacementNotice,
    deviceResults: List.unmodifiable(
      observation.decisions.map(
        (decision) => ForgeDevicePlacementDeviceResult(
          deviceID: decision.deviceID,
          attributesUnverified: true,
          matchesRequirements: decision.matchesRequirements,
          exclusionReasons: List.unmodifiable(decision.exclusionReasons),
        ),
      ),
    ),
    executionAuthorized: false,
    reservationCreated: false,
    dispatchPerformed: false,
  );

  static bool _sameResourceSummary(
    ForgeDeviceResourceSummary left,
    ForgeDeviceResourceSummary right,
  ) {
    final a = left.toJson();
    final b = right.toJson();
    if (a.length != b.length || a.keys.any((key) => !b.containsKey(key))) {
      return false;
    }
    for (final key in a.keys) {
      final av = a[key];
      final bv = b[key];
      if (av is Map && bv is Map) {
        if (!_sameMap(
          Map<String, dynamic>.from(av),
          Map<String, dynamic>.from(bv),
        )) {
          return false;
        }
      } else if (av != bv) {
        return false;
      }
    }
    return true;
  }

  static bool _sameMap(Map<String, dynamic> left, Map<String, dynamic> right) {
    if (left.length != right.length ||
        left.keys.any((key) => !right.containsKey(key))) {
      return false;
    }
    for (final key in left.keys) {
      if (left[key] is Map && right[key] is Map) {
        if (!_sameMap(
          Map<String, dynamic>.from(left[key] as Map),
          Map<String, dynamic>.from(right[key] as Map),
        )) {
          return false;
        }
      } else if (left[key] != right[key]) {
        return false;
      }
    }
    return true;
  }
}

class ForgeSessionDeviceObservationError implements Exception {
  final String code;

  const ForgeSessionDeviceObservationError(this.code);

  @override
  String toString() => 'ForgeSessionDeviceObservationError($code)';
}

/// Renders the binding and the existing read-only inventory panel together.
/// The binding card makes it clear which Conversation/Run the declaration is
/// for; all device values remain unverified and no action is offered.
class ForgeSessionDeviceObservationPanel extends StatelessWidget {
  final ForgeSessionDeviceObservation observation;

  const ForgeSessionDeviceObservationPanel({
    super.key,
    required this.observation,
  });

  @override
  Widget build(BuildContext context) => Column(
    key: const ValueKey('forge-session-device-observation'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.tr('Offline device observation'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                context.tr('Conversation: {id}', {
                  'id': observation.conversationID,
                }),
              ),
              Text(context.tr('Run: {id}', {'id': observation.runID})),
              Text(
                context.tr(
                  'This placement is a caller-supplied preview. It selects no target and grants no execution authority.',
                ),
              ),
            ],
          ),
        ),
      ),
      ForgeDeviceInventoryPanel(
        page: observation.page,
        snapshot: observation.snapshot,
        placement: observation.placement,
        resourceSummary: observation.resourceSummary,
        statusByDeviceInstance: observation.statusByDeviceInstance,
      ),
    ],
  );
}
