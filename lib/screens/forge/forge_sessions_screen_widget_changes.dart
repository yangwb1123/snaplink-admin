part of 'forge_sessions_screen.dart';

typedef _ForgeSessionsWidgetChanges = ({
  bool deviceObservationChanged,
  bool deviceInventoryChanged,
  bool deviceInventoryV2Changed,
  bool deviceInventoryResourceConvergenceChanged,
  bool deviceInventoryRegistryPlacementPreviewChanged,
  bool schedulerSelectionPreviewChanged,
  bool schedulerSelectionLeaseChanged,
  bool schedulerSelectionLeaseReleaseChanged,
  bool clientInstanceResourceViewChanged,
  bool clientInstanceResourceViewPreviewChanged,
  bool clientInstanceSessionViewChanged,
  bool clientInstanceSessionViewPreviewChanged,
  bool clientInstanceSessionResourceConvergenceChanged,
  bool lifecycleRegistryChanged,
  bool deviceCredentialCandidateChanged,
  bool runAttemptLeaseDispatchPreflightChanged,
  bool runnerDispatchPlanPreviewChanged,
  bool runnerExecutionIntentChanged,
  bool runnerDispatchAdmissionChanged,
  bool runnerTransportAdmissionChanged,
  bool runnerExecutionBoundaryChanged,
  bool runnerAttemptBoundaryCandidateChanged,
  bool runnerAttemptBoundaryProjectionChanged,
  bool localRunnerPreviewChanged,
  bool executionReconciliationChanged,
  bool executionConsentPreviewChanged,
  bool runObservedReaderChanged,
  bool runExecutionEvidenceChanged,
  bool sessionRunnerReceiptHistoryCandidateChanged,
  bool sessionRunnerReconciliationProjectionCandidateChanged,
  bool pendingRunIntentChanged,
});

extension _ForgeSessionsWidgetChangesProjection on _ForgeSessionsScreenState {
  _ForgeSessionsWidgetChanges _widgetChanges(ForgeSessionsScreen oldWidget) {
    final deviceObservationChanged = !_sameDeviceObservationRequest(
      oldWidget.deviceObservationRequest,
      widget.deviceObservationRequest,
    );
    final deviceInventoryChanged =
        oldWidget.deviceInventoryOwner != widget.deviceInventoryOwner ||
        oldWidget.deviceInventoryReader != widget.deviceInventoryReader;
    final deviceInventoryV2Changed =
        oldWidget.deviceInventoryOwner != widget.deviceInventoryOwner ||
        oldWidget.deviceInventoryV2Reader != widget.deviceInventoryV2Reader;
    final deviceInventoryResourceConvergenceChanged =
        oldWidget.deviceInventoryResourceConvergenceOwner !=
            widget.deviceInventoryResourceConvergenceOwner ||
        oldWidget.deviceInventoryResourceConvergenceReader !=
            widget.deviceInventoryResourceConvergenceReader;
    final deviceInventoryRegistryPlacementPreviewChanged =
        oldWidget.deviceInventoryOwner != widget.deviceInventoryOwner ||
        oldWidget.deviceInventoryRegistryPlacementRequirements !=
            widget.deviceInventoryRegistryPlacementRequirements ||
        oldWidget.deviceInventoryRegistryPlacementPreviewReader !=
            widget.deviceInventoryRegistryPlacementPreviewReader;
    final schedulerSelectionPreviewChanged =
        oldWidget.schedulerSelectionPreviewRequest !=
            widget.schedulerSelectionPreviewRequest ||
        oldWidget.schedulerSelectionPreviewReader !=
            widget.schedulerSelectionPreviewReader;
    final schedulerSelectionLeaseChanged =
        oldWidget.schedulerSelectionLeaseRequest !=
            widget.schedulerSelectionLeaseRequest ||
        oldWidget.schedulerSelectionLeaseReader !=
            widget.schedulerSelectionLeaseReader ||
        oldWidget.schedulerSelectionLeaseIdempotencyKey !=
            widget.schedulerSelectionLeaseIdempotencyKey ||
        oldWidget.schedulerSelectionLeaseRenewalRequest !=
            widget.schedulerSelectionLeaseRenewalRequest ||
        oldWidget.schedulerSelectionLeaseRenewalReader !=
            widget.schedulerSelectionLeaseRenewalReader ||
        oldWidget.schedulerSelectionLeaseRenewalIdempotencyKey !=
            widget.schedulerSelectionLeaseRenewalIdempotencyKey;
    final schedulerSelectionLeaseReleaseChanged =
        oldWidget.schedulerSelectionLeaseReleaseRequest !=
            widget.schedulerSelectionLeaseReleaseRequest ||
        oldWidget.schedulerSelectionLeaseReleaseReader !=
            widget.schedulerSelectionLeaseReleaseReader ||
        oldWidget.schedulerSelectionLeaseReleaseIdempotencyKey !=
            widget.schedulerSelectionLeaseReleaseIdempotencyKey;
    final clientInstanceResourceViewChanged =
        oldWidget.clientInstanceResourceViewOwner !=
            widget.clientInstanceResourceViewOwner ||
        oldWidget.clientInstanceResourceViewReader !=
            widget.clientInstanceResourceViewReader;
    final clientInstanceResourceViewPreviewChanged =
        oldWidget.clientInstanceResourceViewPreview !=
        widget.clientInstanceResourceViewPreview;
    final clientInstanceSessionViewChanged =
        oldWidget.clientInstanceSessionViewOwner !=
            widget.clientInstanceSessionViewOwner ||
        oldWidget.clientInstanceSessionViewReader !=
            widget.clientInstanceSessionViewReader;
    final clientInstanceSessionViewPreviewChanged =
        oldWidget.clientInstanceSessionViewPreview !=
        widget.clientInstanceSessionViewPreview;
    final clientInstanceSessionResourceConvergenceChanged =
        oldWidget.clientInstanceSessionResourceConvergenceOwner !=
            widget.clientInstanceSessionResourceConvergenceOwner ||
        oldWidget.clientInstanceSessionResourceConvergenceReader !=
            widget.clientInstanceSessionResourceConvergenceReader;
    final lifecycleRegistryChanged =
        oldWidget.lifecycleRegistryOwner != widget.lifecycleRegistryOwner ||
        oldWidget.lifecycleRegistryReader != widget.lifecycleRegistryReader;
    final deviceCredentialCandidateChanged =
        oldWidget.deviceCredentialCandidateOwner !=
            widget.deviceCredentialCandidateOwner ||
        !_sameDeviceCredentialCandidateRequest(
          oldWidget.deviceCredentialCandidateRequest,
          widget.deviceCredentialCandidateRequest,
        ) ||
        oldWidget.deviceCredentialCandidateReader !=
            widget.deviceCredentialCandidateReader;
    final runAttemptLeaseDispatchPreflightChanged =
        oldWidget.runAttemptLeaseDispatchPreflightRequest !=
            widget.runAttemptLeaseDispatchPreflightRequest ||
        oldWidget.runAttemptLeaseDispatchPreflightReader !=
            widget.runAttemptLeaseDispatchPreflightReader;
    final runnerDispatchPlanPreviewChanged =
        oldWidget.runnerDispatchPlanPreviewRequest !=
            widget.runnerDispatchPlanPreviewRequest ||
        oldWidget.runnerDispatchPlanPreviewReader !=
            widget.runnerDispatchPlanPreviewReader;
    final runnerExecutionIntentChanged =
        oldWidget.runnerExecutionIntentRequest !=
            widget.runnerExecutionIntentRequest ||
        oldWidget.runnerExecutionIntentReader !=
            widget.runnerExecutionIntentReader;
    final runnerDispatchAdmissionChanged =
        oldWidget.runnerDispatchAdmissionRequest !=
            widget.runnerDispatchAdmissionRequest ||
        oldWidget.runnerDispatchAdmissionReader !=
            widget.runnerDispatchAdmissionReader;
    final runnerTransportAdmissionChanged =
        oldWidget.runnerTransportAdmissionRequest !=
            widget.runnerTransportAdmissionRequest ||
        oldWidget.runnerTransportAdmissionReader !=
            widget.runnerTransportAdmissionReader;
    final runnerExecutionBoundaryChanged =
        oldWidget.runnerExecutionBoundaryRequest !=
            widget.runnerExecutionBoundaryRequest ||
        oldWidget.runnerExecutionBoundaryReader !=
            widget.runnerExecutionBoundaryReader;
    final runnerAttemptBoundaryCandidateChanged =
        oldWidget.runnerAttemptBoundaryRequest !=
            widget.runnerAttemptBoundaryRequest ||
        oldWidget.runnerAttemptBoundaryReader !=
            widget.runnerAttemptBoundaryReader;
    final runnerAttemptBoundaryProjectionChanged =
        oldWidget.runnerAttemptBoundaryPreview !=
            widget.runnerAttemptBoundaryPreview ||
        oldWidget.runnerAttemptBoundaryScope !=
            widget.runnerAttemptBoundaryScope ||
        oldWidget.runnerAttemptBoundaryFileReader !=
            widget.runnerAttemptBoundaryFileReader ||
        oldWidget.enableRunnerAttemptBoundaryProjection !=
            widget.enableRunnerAttemptBoundaryProjection;
    final localRunnerPreviewChanged =
        oldWidget.localRunnerPreviewRequest !=
            widget.localRunnerPreviewRequest ||
        oldWidget.localRunnerPreviewReader != widget.localRunnerPreviewReader;
    final executionReconciliationChanged =
        oldWidget.executionReconciliationInput !=
            widget.executionReconciliationInput ||
        oldWidget.executionReconciliationReader !=
            widget.executionReconciliationReader;
    final executionConsentPreviewChanged =
        oldWidget.executionConsentPreviewOwner !=
            widget.executionConsentPreviewOwner ||
        oldWidget.executionConsentPreviewReader !=
            widget.executionConsentPreviewReader;
    final runObservedReaderChanged =
        oldWidget.runObservedReader != widget.runObservedReader ||
        oldWidget.sessionRunnerReceiptObservationReader !=
            widget.sessionRunnerReceiptObservationReader;
    final runExecutionEvidenceChanged =
        oldWidget.runExecutionEvidenceReader !=
            widget.runExecutionEvidenceReader ||
        oldWidget.runObserved != widget.runObserved ||
        oldWidget.sessionRunnerReceiptObservation !=
            widget.sessionRunnerReceiptObservation;
    final sessionRunnerReceiptHistoryCandidateChanged =
        oldWidget.sessionRunnerReceiptHistoryRequest !=
            widget.sessionRunnerReceiptHistoryRequest ||
        oldWidget.sessionRunnerReceiptHistoryReader !=
            widget.sessionRunnerReceiptHistoryReader;
    final sessionRunnerReconciliationProjectionCandidateChanged =
        oldWidget.sessionRunnerReconciliationProjectionRequest !=
            widget.sessionRunnerReconciliationProjectionRequest ||
        oldWidget.sessionRunnerReconciliationProjectionReader !=
            widget.sessionRunnerReconciliationProjectionReader;
    final pendingRunIntentChanged =
        oldWidget.pendingRunIntentReader != widget.pendingRunIntentReader ||
        oldWidget.pendingRunIntentPageReader !=
            widget.pendingRunIntentPageReader ||
        oldWidget.pendingRunIntentTimelineReader !=
            widget.pendingRunIntentTimelineReader;
    return (
      deviceObservationChanged: deviceObservationChanged,
      deviceInventoryChanged: deviceInventoryChanged,
      deviceInventoryV2Changed: deviceInventoryV2Changed,
      deviceInventoryResourceConvergenceChanged:
          deviceInventoryResourceConvergenceChanged,
      deviceInventoryRegistryPlacementPreviewChanged:
          deviceInventoryRegistryPlacementPreviewChanged,
      schedulerSelectionPreviewChanged: schedulerSelectionPreviewChanged,
      schedulerSelectionLeaseChanged: schedulerSelectionLeaseChanged,
      schedulerSelectionLeaseReleaseChanged:
          schedulerSelectionLeaseReleaseChanged,
      clientInstanceResourceViewChanged: clientInstanceResourceViewChanged,
      clientInstanceResourceViewPreviewChanged:
          clientInstanceResourceViewPreviewChanged,
      clientInstanceSessionViewChanged: clientInstanceSessionViewChanged,
      clientInstanceSessionViewPreviewChanged:
          clientInstanceSessionViewPreviewChanged,
      clientInstanceSessionResourceConvergenceChanged:
          clientInstanceSessionResourceConvergenceChanged,
      lifecycleRegistryChanged: lifecycleRegistryChanged,
      deviceCredentialCandidateChanged: deviceCredentialCandidateChanged,
      runAttemptLeaseDispatchPreflightChanged:
          runAttemptLeaseDispatchPreflightChanged,
      runnerDispatchPlanPreviewChanged: runnerDispatchPlanPreviewChanged,
      runnerExecutionIntentChanged: runnerExecutionIntentChanged,
      runnerDispatchAdmissionChanged: runnerDispatchAdmissionChanged,
      runnerTransportAdmissionChanged: runnerTransportAdmissionChanged,
      runnerExecutionBoundaryChanged: runnerExecutionBoundaryChanged,
      runnerAttemptBoundaryCandidateChanged:
          runnerAttemptBoundaryCandidateChanged,
      runnerAttemptBoundaryProjectionChanged:
          runnerAttemptBoundaryProjectionChanged,
      localRunnerPreviewChanged: localRunnerPreviewChanged,
      executionReconciliationChanged: executionReconciliationChanged,
      executionConsentPreviewChanged: executionConsentPreviewChanged,
      runObservedReaderChanged: runObservedReaderChanged,
      runExecutionEvidenceChanged: runExecutionEvidenceChanged,
      sessionRunnerReceiptHistoryCandidateChanged:
          sessionRunnerReceiptHistoryCandidateChanged,
      sessionRunnerReconciliationProjectionCandidateChanged:
          sessionRunnerReconciliationProjectionCandidateChanged,
      pendingRunIntentChanged: pendingRunIntentChanged,
    );
  }
}
