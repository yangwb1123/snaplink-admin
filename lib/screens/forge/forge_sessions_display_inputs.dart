part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayInputs on _ForgeSessionsScreenState {
  _ForgeSessionInputs _projectInputs() {
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    final schedulerSelectionLeaseCandidateEnabled =
        (widget.schedulerSelectionLeaseRequest != null &&
            widget.schedulerSelectionLeaseReader != null) ||
        (widget.schedulerSelectionLeaseRenewalRequest != null &&
            widget.schedulerSelectionLeaseRenewalReader != null);
    final schedulerSelectionLeaseReleaseCandidateEnabled =
        widget.schedulerSelectionLeaseReleaseRequest != null &&
        widget.schedulerSelectionLeaseReleaseReader != null;
    final staticObservation = widget.deviceObservation;
    final runIntentObservation = widget.runIntentObservation;
    final runnerExecutionIntentObservation =
        widget.runnerExecutionIntentObservation ??
        _fetchedRunnerExecutionIntent;
    final runObserved = _strictRunObserved(widget.runObserved);
    final fetchedRunObserved = _strictRunObserved(_fetchedRunObserved);
    final runExecutionEvidence =
        _strictRunExecutionEvidence(widget.runExecutionEvidence) ??
        _strictRunExecutionEvidence(_fetchedRunExecutionEvidence);
    final clientInstanceSessionView =
        _strictClientInstanceSessionView(
          widget.clientInstanceSessionViewPreview,
        ) ??
        _strictClientInstanceSessionView(_fetchedClientInstanceSessionView) ??
        _strictClientInstanceSessionView(_clientInstanceSessionViewPreview);
    final inventoryResourceConvergence =
        _strictDeviceInventoryResourceConvergence(
          _fetchedDeviceInventoryResourceConvergence,
        );
    final clientInstanceResourceView =
        _strictClientInstanceResourceView(
          widget.clientInstanceResourceViewPreview,
        ) ??
        _strictClientInstanceResourceView(_fetchedClientInstanceResourceView) ??
        _strictClientInstanceResourceView(_clientInstanceResourceViewPreview) ??
        inventoryResourceConvergence?.resourceView;
    final executionLeaseCheckpoint = _strictExecutionLeaseCheckpoint(
      _executionLeaseCheckpointPreview,
    );
    final sessionRunnerReceiptVectors = _safeSessionRunnerReceiptVectorsPreview(
      _sessionRunnerReceiptVectorsPreview,
    );
    final sessionRunnerReceiptHistory = _safeSessionRunnerReceiptHistoryPreview(
      _sessionRunnerReceiptHistoryPreview,
    );
    final sessionRunnerReconciliationProjection =
        _safeSessionRunnerReconciliationProjectionPreview(
          _sessionRunnerReconciliationProjectionPreview,
        );
    final fetchedSessionRunnerReconciliationProjection =
        _safeSessionRunnerReconciliationProjectionPreview(
          _fetchedSessionRunnerReconciliationProjection,
        );
    final deviceInventoryV2Preview = _safeDeviceInventoryV2Preview(
      _deviceInventoryV2Preview,
    );
    final deviceResourceSummaryPreview = _safeDeviceResourceSummaryPreview(
      _deviceResourceSummaryPreview,
    );
    final deviceInventoryPlacementEvaluationV2Preview =
        _safeDeviceInventoryPlacementEvaluationV2Preview(
          _deviceInventoryPlacementEvaluationV2Preview,
        );
    final deviceInventoryPlacementEvaluationPreview =
        _safeDeviceInventoryPlacementEvaluationPreview(
          _deviceInventoryPlacementEvaluationPreview,
        );
    final deviceInventoryPlacementBatchEvaluationPreview =
        _safeDeviceInventoryPlacementBatchEvaluationPreview(
          _deviceInventoryPlacementBatchEvaluationPreview,
        );
    final lifecycleRegistry = _strictLifecycleRegistry(
      _fetchedLifecycleRegistry,
    );
    final deviceCredentialCandidate = _strictDeviceCredentialCandidate(
      _fetchedDeviceCredentialCandidate,
    );
    final registryPlacementPreview = _strictRegistryPlacementPreview(
      _fetchedDeviceInventoryRegistryPlacementPreview,
    );
    return (
      selectedConversationID: selectedConversationID,
      selectedRunID: selectedRunID,
      schedulerSelectionLeaseCandidateEnabled:
          schedulerSelectionLeaseCandidateEnabled,
      schedulerSelectionLeaseReleaseCandidateEnabled:
          schedulerSelectionLeaseReleaseCandidateEnabled,
      staticObservation: staticObservation,
      runIntentObservation: runIntentObservation,
      runnerExecutionIntentObservation: runnerExecutionIntentObservation,
      runObserved: runObserved,
      fetchedRunObserved: fetchedRunObserved,
      runExecutionEvidence: runExecutionEvidence,
      clientInstanceSessionView: clientInstanceSessionView,
      inventoryResourceConvergence: inventoryResourceConvergence,
      clientInstanceResourceView: clientInstanceResourceView,
      executionLeaseCheckpoint: executionLeaseCheckpoint,
      sessionRunnerReceiptVectors: sessionRunnerReceiptVectors,
      sessionRunnerReceiptHistory: sessionRunnerReceiptHistory,
      sessionRunnerReconciliationProjection:
          sessionRunnerReconciliationProjection,
      fetchedSessionRunnerReconciliationProjection:
          fetchedSessionRunnerReconciliationProjection,
      deviceInventoryV2Preview: deviceInventoryV2Preview,
      deviceResourceSummaryPreview: deviceResourceSummaryPreview,
      deviceInventoryPlacementEvaluationV2Preview:
          deviceInventoryPlacementEvaluationV2Preview,
      deviceInventoryPlacementEvaluationPreview:
          deviceInventoryPlacementEvaluationPreview,
      deviceInventoryPlacementBatchEvaluationPreview:
          deviceInventoryPlacementBatchEvaluationPreview,
      lifecycleRegistry: lifecycleRegistry,
      deviceCredentialCandidate: deviceCredentialCandidate,
      registryPlacementPreview: registryPlacementPreview,
    );
  }
}
