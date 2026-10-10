part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenPreviewValidation on _ForgeSessionsScreenState {
  ForgeRunnerLeaseFencingFixture? _safeRunnerLeaseFencingPreview(
    ForgeRunnerLeaseFencingFixture? candidate,
  ) {
    if (candidate == null ||
        candidate.schemaVersion != forgeRunnerLeaseFencingSchema ||
        candidate.evaluationMode != forgeRunnerLeaseFencingEvaluationMode ||
        !candidate.authority.isOffline ||
        candidate.cases.length != 16) {
      return null;
    }
    return candidate;
  }

  ForgeRunnerAttemptBoundaryObservation? _safeRunnerAttemptBoundaryPreview(
    ForgeRunnerAttemptBoundaryObservation? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeRunnerAttemptBoundaryObservation.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeExecutionLeaseCheckpointFixture? _safeExecutionLeaseCheckpointPreview(
    ForgeExecutionLeaseCheckpointFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeExecutionLeaseCheckpointFixture.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeSessionRunnerReceiptVectors? _safeSessionRunnerReceiptVectorsPreview(
    ForgeSessionRunnerReceiptVectors? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSessionRunnerReceiptVectors.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeSessionRunnerReceiptHistory? _safeSessionRunnerReceiptHistoryPreview(
    ForgeSessionRunnerReceiptHistory? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSessionRunnerReceiptHistory.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeSessionRunnerReconciliationProjection?
  _safeSessionRunnerReconciliationProjectionPreview(
    ForgeSessionRunnerReconciliationProjection? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeSessionRunnerReconciliationProjection.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPageV2? _safeDeviceInventoryV2Preview(
    ForgeDeviceInventoryPageV2? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryPageV2.fromJson(candidate.toJson());
      return validated;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceResourceSummaryFixture? _safeDeviceResourceSummaryPreview(
    ForgeDeviceResourceSummaryFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceResourceSummaryFixture.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceResourceView? _safeClientInstanceResourceViewPreview(
    ForgeClientInstanceResourceView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeClientInstanceResourceView.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeClientInstanceSessionView? _safeClientInstanceSessionViewPreview(
    ForgeClientInstanceSessionView? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeClientInstanceSessionView.fromJson(
        candidate.toJson(),
      );
      return validated.isDisplayOnly ? validated : null;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPlacementEvaluationV2?
  _safeDeviceInventoryPlacementEvaluationV2Preview(
    ForgeDeviceInventoryPlacementEvaluationV2? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryPlacementEvaluationV2.fromJson(
        candidate.toJson(),
      );
      return validated.authority.anyGranted ||
              validated.selectedDeviceID != null ||
              validated.selectedInstanceID != null
          ? null
          : validated;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPlacementEvaluationFixture?
  _safeDeviceInventoryPlacementEvaluationPreview(
    ForgeDeviceInventoryPlacementEvaluationFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated = ForgeDeviceInventoryPlacementEvaluationFixture.fromJson(
        _placementEvaluationJson(candidate),
      );
      return validated.authority.anyGranted ? null : validated;
    } on FormatException {
      return null;
    }
  }

  ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  _safeDeviceInventoryPlacementBatchEvaluationPreview(
    ForgeDeviceInventoryPlacementBatchEvaluationFixture? candidate,
  ) {
    if (candidate == null) return null;
    try {
      final validated =
          ForgeDeviceInventoryPlacementBatchEvaluationFixture.fromJson(
            _batchEvaluationJson(candidate),
          );
      return validated.authority.anyGranted ||
              validated.selectedDeviceID != null ||
              validated.selectedInstanceID != null
          ? null
          : validated;
    } on FormatException {
      return null;
    }
  }

  Map<String, dynamic> _batchEvaluationJson(
    ForgeDeviceInventoryPlacementBatchEvaluationFixture value,
  ) => {
    'schema_version': value.schemaVersion,
    'evaluation_mode': value.evaluationMode,
    'source_fixture': value.sourceFixture,
    'evaluation_owner': value.evaluationOwner.toJson(),
    'evaluated_at_ms': value.evaluatedAtMS,
    'requirements': value.requirements.toJson(),
    'cases': value.cases
        .map(
          (item) => {
            'name': item.name,
            'source_case': item.sourceCase,
            'device_id': item.deviceID,
            'instance_id': item.instanceID,
            if (item.snapshotObservedAtMS != null)
              'snapshot_observed_at_ms': item.snapshotObservedAtMS,
            if (item.capabilityLeaseExpiresAtMS != null)
              'capability_lease_expires_at_ms': item.capabilityLeaseExpiresAtMS,
            'expected': {
              'revision': item.expected.revision,
              'device_id': item.expected.deviceID,
              'instance_id': item.expected.instanceID,
              'matches_requirements': item.expected.matchesRequirements,
              'exclusion_reasons': item.expected.exclusionReasons,
            },
          },
        )
        .toList(growable: false),
    'empty_inputs_allowed': value.emptyInputsAllowed,
    'selected_device_id': value.selectedDeviceID,
    'selected_instance_id': value.selectedInstanceID,
    'authority': {
      'identity_verified': value.authority.identityVerified,
      'heartbeat_persisted': value.authority.heartbeatPersisted,
      'inventory_authoritative': value.authority.inventoryAuthoritative,
      'placement_selected': value.authority.placementSelected,
      'reservation_created': value.authority.reservationCreated,
      'execution_authorized': value.authority.executionAuthorized,
      'dispatch_performed': value.authority.dispatchPerformed,
    },
    'error_cases': value.errorCases
        .map((item) => {'name': item.name, 'error': item.error})
        .toList(growable: false),
  };

  Map<String, dynamic> _placementEvaluationJson(
    ForgeDeviceInventoryPlacementEvaluationFixture value,
  ) => {
    'schema_version': value.schemaVersion,
    'evaluation_mode': value.evaluationMode,
    'source_fixture': value.sourceFixture,
    'source_case': value.sourceCase,
    'evaluated_at_ms': value.evaluatedAtMS,
    'policy_requirements': value.policyRequirements.toJson(),
    'authority': value.authority.toJson(),
    'expected': value.expected.toJson(),
  };
}
