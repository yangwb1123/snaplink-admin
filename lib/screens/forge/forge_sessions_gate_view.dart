part of 'forge_sessions_gate.dart';

extension _ForgeSessionsGateView on _ForgeSessionsGateState {
  Widget _buildGate(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final token = _token;
    if (token == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final testScreenBuilderWithRoute = widget.testScreenBuilderWithRoute;
    if (testScreenBuilderWithRoute != null) {
      return testScreenBuilderWithRoute(token, _resolvedInitialConversationID);
    }
    final testScreenBuilder = widget.testScreenBuilder;
    if (testScreenBuilder != null) return testScreenBuilder(token);
    final runObservedReader =
        widget.runObservedReader ?? _runObservedCandidateReader;
    final runExecutionEvidenceReader =
        widget.runExecutionEvidenceReader ??
        _runExecutionEvidenceCandidateReader;
    final sessionRunnerReceiptHistoryReader =
        widget.sessionRunnerReceiptHistoryReader ??
        _sessionRunnerReceiptHistoryCandidateReader;
    final sessionRunnerReconciliationProjectionReader =
        widget.sessionRunnerReconciliationProjectionReader ??
        _sessionRunnerReconciliationProjectionCandidateReader;
    final deviceInventoryReader =
        widget.deviceInventoryReader ?? _deviceInventoryCandidateReader;
    final deviceInventoryV2Reader =
        widget.deviceInventoryV2Reader ?? _deviceInventoryV2CandidateReader;
    final deviceInventoryResourceConvergenceReader =
        widget.deviceInventoryResourceConvergenceReader ??
        _deviceInventoryResourceConvergenceCandidateReader;
    final deviceInventoryRegistryPlacementPreviewReader =
        widget.deviceInventoryRegistryPlacementPreviewReader ??
        _deviceInventoryRegistryPlacementPreviewCandidateReader;
    final schedulerSelectionPreviewReader =
        widget.schedulerSelectionPreviewReader ??
        _schedulerSelectionPreviewCandidateReader;
    final schedulerSelectionLeaseReader =
        widget.schedulerSelectionLeaseReader ??
        _schedulerSelectionLeaseCandidateReader;
    final schedulerSelectionLeaseRenewalReader =
        widget.schedulerSelectionLeaseRenewalReader ??
        _schedulerSelectionLeaseRenewalCandidateReader;
    final schedulerSelectionLeaseReleaseReader =
        widget.schedulerSelectionLeaseReleaseReader ??
        _schedulerSelectionLeaseReleaseCandidateReader;
    final clientInstanceResourceViewReader =
        widget.clientInstanceResourceViewReader ??
        _clientInstanceResourceViewCandidateReader;
    final clientInstanceSessionViewReader =
        widget.clientInstanceSessionViewReader ??
        _clientInstanceSessionViewCandidateReader;
    final clientInstanceSessionResourceConvergenceReader =
        widget.clientInstanceSessionResourceConvergenceReader ??
        _clientInstanceSessionResourceConvergenceCandidateReader;
    final runAttemptLeaseDispatchPreflightReader =
        widget.runAttemptLeaseDispatchPreflightReader ??
        _runAttemptLeaseDispatchPreflightCandidateReader;
    final runnerDispatchPlanPreviewReader =
        widget.runnerDispatchPlanPreviewReader ??
        _runnerDispatchPlanPreviewCandidateReader;
    final runnerExecutionIntentReader =
        widget.runnerExecutionIntentReader ??
        _runnerExecutionIntentCandidateReader;
    final runnerDispatchAdmissionReader =
        widget.runnerDispatchAdmissionReader ??
        _runnerDispatchAdmissionCandidateReader;
    final runnerTransportAdmissionReader =
        widget.runnerTransportAdmissionReader ??
        _runnerTransportAdmissionCandidateReader;
    final runnerExecutionBoundaryReader =
        widget.runnerExecutionBoundaryReader ??
        _runnerExecutionBoundaryCandidateReader;
    final runnerAttemptBoundaryReader =
        widget.runnerAttemptBoundaryReader ??
        _runnerAttemptBoundaryCandidateReader;
    final localRunnerPreviewReader =
        widget.localRunnerPreviewReader ?? _localRunnerPreviewCandidateReader;
    final executionReconciliationReader =
        widget.executionReconciliationReader ??
        _executionReconciliationCandidateReader;
    final executionConsentPreviewReader =
        widget.executionConsentPreviewReader ??
        _executionConsentPreviewCandidateReader;
    final lifecycleRegistryReader =
        widget.lifecycleRegistryReader ?? _lifecycleRegistryCandidateReader;
    final deviceCredentialCandidateReader =
        widget.deviceCredentialCandidateReader ??
        _deviceCredentialCandidateReader;
    final pendingRunIntentReader =
        widget.pendingRunIntentReader ?? _pendingRunIntentCandidateReader;
    final pendingRunIntentPageReader =
        widget.pendingRunIntentPageReader ??
        _pendingRunIntentCandidatePageReader;
    final pendingRunIntentTimelineReader =
        widget.pendingRunIntentTimelineReader ??
        _pendingRunIntentCandidateTimelineReader;
    final pendingRunIntentSubmitter = _pendingRunIntentCandidateSubmitter;
    final promptAppendReceiptSubmitter =
        widget.promptAppendReceiptSubmitter ??
        _promptAppendReceiptCandidateSubmitter;
    return ForgeSessionsScreen(
      accessToken: token,
      apiOrigin: ForgeConversationsApiOrigin.baseUrl,
      enableConversationChangesStream: widget.enableConversationChangesStream,
      conversationChangesStreamWaitMS: widget.conversationChangesStreamWaitMS,
      initialConversationID: _resolvedInitialConversationID,
      initialClientInstanceID: widget.initialClientInstanceID,
      httpClient: widget.httpClient,
      deviceObservation: widget.deviceObservation,
      deviceObservationRequest: widget.deviceObservationRequest,
      runIntentObservation: widget.runIntentObservation,
      runnerExecutionIntentObservation: widget.runnerExecutionIntentObservation,
      runnerExecutionIntentRequest: widget.runnerExecutionIntentRequest,
      runnerExecutionIntentReader: runnerExecutionIntentReader,
      localRunnerPreview: widget.localRunnerPreview,
      localRunnerPreviewRequest: widget.localRunnerPreviewRequest,
      localRunnerPreviewReader: localRunnerPreviewReader,
      runObserved: widget.runObserved,
      runObservedReader: runObservedReader,
      sessionRunnerReceiptObservationReader:
          widget.sessionRunnerReceiptObservationReader,
      runExecutionEvidence: widget.runExecutionEvidence,
      sessionRunnerReceiptObservation: widget.sessionRunnerReceiptObservation,
      sessionRunnerReceiptVectorsPreview:
          widget.sessionRunnerReceiptVectorsPreview,
      sessionRunnerReceiptVectorsFileReader:
          widget.sessionRunnerReceiptVectorsFileReader,
      sessionRunnerReceiptHistoryPreview:
          widget.sessionRunnerReceiptHistoryPreview,
      sessionRunnerReceiptHistoryFileReader:
          widget.sessionRunnerReceiptHistoryFileReader,
      sessionRunnerReconciliationProjectionPreview:
          widget.sessionRunnerReconciliationProjectionPreview,
      sessionRunnerReconciliationProjectionFileReader:
          widget.sessionRunnerReconciliationProjectionFileReader,
      sessionRunnerReceiptHistoryRequest:
          widget.sessionRunnerReceiptHistoryRequest,
      sessionRunnerReceiptHistoryReader: sessionRunnerReceiptHistoryReader,
      sessionRunnerReconciliationProjectionRequest:
          widget.sessionRunnerReconciliationProjectionRequest,
      sessionRunnerReconciliationProjectionReader:
          sessionRunnerReconciliationProjectionReader,
      runExecutionEvidenceReader: runExecutionEvidenceReader,
      executionReconciliationObservation:
          widget.executionReconciliationObservation,
      executionReconciliationInput: widget.executionReconciliationInput,
      executionReconciliationReader: executionReconciliationReader,
      executionConsentPreviewOwner: widget.executionConsentPreviewOwner,
      executionConsentPreviewReader: executionConsentPreviewReader,
      lifecycleRegistryOwner: widget.lifecycleRegistryOwner,
      lifecycleRegistryReader: lifecycleRegistryReader,
      deviceCredentialCandidateOwner: widget.deviceCredentialCandidateOwner,
      deviceCredentialCandidateRequest: widget.deviceCredentialCandidateRequest,
      deviceCredentialCandidateReader: deviceCredentialCandidateReader,
      attemptRequestPreview: widget.attemptRequestPreview,
      runnerAttemptBoundaryPreview: widget.runnerAttemptBoundaryPreview,
      runnerAttemptBoundaryScope: widget.runnerAttemptBoundaryScope,
      runnerAttemptBoundaryFileReader: widget.runnerAttemptBoundaryFileReader,
      runnerAttemptBoundaryRequest: widget.runnerAttemptBoundaryRequest,
      runnerAttemptBoundaryReader: runnerAttemptBoundaryReader,
      enableRunnerAttemptBoundaryProjection:
          widget.enableRunnerAttemptBoundaryProjection,
      pendingRunIntentPreview: widget.pendingRunIntentPreview,
      pendingRunIntentOwner: widget.pendingRunIntentOwner,
      pendingRunIntentSubmitter: pendingRunIntentSubmitter,
      promptAppendReceiptOwner: widget.promptAppendReceiptOwner,
      promptAppendReceiptSubmitter: promptAppendReceiptSubmitter,
      requireDeviceInventoryResourceConvergenceForPromptAppend:
          widget.requireDeviceInventoryResourceConvergenceForPromptAppend,
      deviceInventoryOwner: widget.deviceInventoryOwner,
      deviceInventoryReader: deviceInventoryReader,
      deviceInventoryV2Reader: deviceInventoryV2Reader,
      deviceInventoryResourceConvergenceOwner:
          widget.deviceInventoryResourceConvergenceOwner,
      deviceInventoryResourceConvergenceReader:
          deviceInventoryResourceConvergenceReader,
      deviceInventoryRegistryPlacementRequirements:
          widget.deviceInventoryRegistryPlacementRequirements,
      deviceInventoryRegistryPlacementPreviewReader:
          deviceInventoryRegistryPlacementPreviewReader,
      schedulerSelectionPreviewRequest: widget.schedulerSelectionPreviewRequest,
      schedulerSelectionPreviewReader: schedulerSelectionPreviewReader,
      schedulerSelectionLeaseRequest: widget.schedulerSelectionLeaseRequest,
      schedulerSelectionLeaseReader: schedulerSelectionLeaseReader,
      schedulerSelectionLeaseIdempotencyKey:
          widget.schedulerSelectionLeaseIdempotencyKey,
      schedulerSelectionLeaseRenewalRequest:
          widget.schedulerSelectionLeaseRenewalRequest,
      schedulerSelectionLeaseRenewalReader:
          schedulerSelectionLeaseRenewalReader,
      schedulerSelectionLeaseRenewalIdempotencyKey:
          widget.schedulerSelectionLeaseRenewalIdempotencyKey,
      schedulerSelectionLeaseReleaseRequest:
          widget.schedulerSelectionLeaseReleaseRequest,
      schedulerSelectionLeaseReleaseReader:
          schedulerSelectionLeaseReleaseReader,
      schedulerSelectionLeaseReleaseIdempotencyKey:
          widget.schedulerSelectionLeaseReleaseIdempotencyKey,
      deviceInventoryV2Preview: widget.deviceInventoryV2Preview,
      deviceInventoryV2FileReader: widget.deviceInventoryV2FileReader,
      deviceInventoryPlacementEvaluationV2Preview:
          widget.deviceInventoryPlacementEvaluationV2Preview,
      deviceInventoryPlacementEvaluationV2FileReader:
          widget.deviceInventoryPlacementEvaluationV2FileReader,
      deviceInventoryPlacementEvaluationPreview:
          widget.deviceInventoryPlacementEvaluationPreview,
      deviceInventoryPlacementEvaluationFileReader:
          widget.deviceInventoryPlacementEvaluationFileReader,
      deviceInventoryPlacementBatchEvaluationPreview:
          widget.deviceInventoryPlacementBatchEvaluationPreview,
      deviceInventoryPlacementBatchEvaluationFileReader:
          widget.deviceInventoryPlacementBatchEvaluationFileReader,
      pendingRunIntentReader: pendingRunIntentReader,
      pendingRunIntentPageReader: pendingRunIntentPageReader,
      pendingRunIntentTimelineReader: pendingRunIntentTimelineReader,
      runnerLeaseFencingPreview: widget.runnerLeaseFencingPreview,
      runnerLeaseFencingFileReader: widget.runnerLeaseFencingFileReader,
      executionLeaseCheckpointPreview: widget.executionLeaseCheckpointPreview,
      executionLeaseCheckpointFileReader:
          widget.executionLeaseCheckpointFileReader,
      clientInstanceSessionViewPreview: widget.clientInstanceSessionViewPreview,
      clientInstanceResourceViewPreview:
          widget.clientInstanceResourceViewPreview,
      clientInstanceResourceViewOwner: widget.clientInstanceResourceViewOwner,
      clientInstanceResourceViewReader: clientInstanceResourceViewReader,
      clientInstanceSessionViewOwner: widget.clientInstanceSessionViewOwner,
      clientInstanceSessionViewReader: clientInstanceSessionViewReader,
      clientInstanceSessionResourceConvergenceOwner:
          widget.clientInstanceSessionResourceConvergenceOwner,
      clientInstanceSessionResourceConvergenceReader:
          clientInstanceSessionResourceConvergenceReader,
      runAttemptLeaseDispatchPreflightPreview:
          widget.runAttemptLeaseDispatchPreflightPreview,
      runAttemptLeaseDispatchPreflightRequest:
          widget.runAttemptLeaseDispatchPreflightRequest,
      runAttemptLeaseDispatchPreflightReader:
          runAttemptLeaseDispatchPreflightReader,
      runnerDispatchPlanPreview: widget.runnerDispatchPlanPreview,
      runnerDispatchPlanPreviewRequest: widget.runnerDispatchPlanPreviewRequest,
      runnerDispatchPlanPreviewReader: runnerDispatchPlanPreviewReader,
      runnerDispatchAdmissionRequest: widget.runnerDispatchAdmissionRequest,
      runnerDispatchAdmissionReader: runnerDispatchAdmissionReader,
      runnerDispatchAdmission: widget.runnerDispatchAdmission,
      runnerTransportAdmissionRequest: widget.runnerTransportAdmissionRequest,
      runnerTransportAdmissionReader: runnerTransportAdmissionReader,
      runnerTransportAdmission: widget.runnerTransportAdmission,
      runnerExecutionBoundaryRequest: widget.runnerExecutionBoundaryRequest,
      runnerExecutionBoundaryReader: runnerExecutionBoundaryReader,
      runnerExecutionBoundary: widget.runnerExecutionBoundary,
    );
  }
}
