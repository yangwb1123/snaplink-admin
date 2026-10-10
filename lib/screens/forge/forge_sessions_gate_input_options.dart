part of 'forge_sessions_gate.dart';

/// Immutable caller-supplied, display-only observations and route inputs.
abstract class _ForgeSessionsGateInputs extends _ForgeCandidateGate {
  final ForgeCredentialStore? credentialStore;
  final String? initialConversationID;
  final String? initialClientInstanceID;
  @visibleForTesting
  final int conversationChangesStreamWaitMS;
  @visibleForTesting
  final http.Client? httpClient;
  final ForgeSessionDeviceObservation? deviceObservation;
  final ForgeSessionPlacementRequest? deviceObservationRequest;
  final ForgeRunIntentObservation? runIntentObservation;
  final ForgeRunnerExecutionIntentObservation? runnerExecutionIntentObservation;
  final ForgeLocalRunnerPreviewObservation? localRunnerPreview;
  final ForgeRunObserved? runObserved;
  final ForgeRunExecutionEvidence? runExecutionEvidence;
  final ForgeSessionRunnerReceiptObservation? sessionRunnerReceiptObservation;
  final ForgeSessionRunnerReceiptVectors? sessionRunnerReceiptVectorsPreview;
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryPreview;
  final ForgeSessionRunnerReconciliationProjection?
  sessionRunnerReconciliationProjectionPreview;
  final ForgeExecutionReconciliationObservation?
  executionReconciliationObservation;
  final ForgeAttemptRequestPreviewFixture? attemptRequestPreview;
  final ForgeRunnerAttemptBoundaryObservation? runnerAttemptBoundaryPreview;
  final ForgePendingRunIntentFixture? pendingRunIntentPreview;
  final ForgeDeviceInventoryPageV2? deviceInventoryV2Preview;
  final ForgeDeviceInventoryPlacementEvaluationV2?
  deviceInventoryPlacementEvaluationV2Preview;
  final ForgeDeviceInventoryPlacementEvaluationFixture?
  deviceInventoryPlacementEvaluationPreview;
  final ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  deviceInventoryPlacementBatchEvaluationPreview;
  final ForgeRunnerLeaseFencingFixture? runnerLeaseFencingPreview;
  final ForgeExecutionLeaseCheckpointFixture? executionLeaseCheckpointPreview;
  final ForgeClientInstanceSessionView? clientInstanceSessionViewPreview;
  final ForgeClientInstanceResourceView? clientInstanceResourceViewPreview;
  final ForgePreflightFixture? runAttemptLeaseDispatchPreflightPreview;
  final ForgeRunnerDispatchPlanPreview? runnerDispatchPlanPreview;

  const _ForgeSessionsGateInputs({
    super.key,
    super.enableConversationChangesStream,
    super.enableRunnerExecutionIntentCandidate,
    super.runnerExecutionIntentCandidateApiOrigin,
    super.enableLocalRunnerPreviewCandidate,
    super.localRunnerPreviewCandidateApiOrigin,
    super.enableRunObservedCandidate,
    super.runObservedCandidateApiOrigin,
    super.enableDeviceInventoryV2Candidate,
    super.deviceInventoryV2CandidateApiOrigin,
    super.enableSessionRunnerReconciliationProjectionCandidate,
    super.sessionRunnerReconciliationProjectionCandidateApiOrigin,
    super.enableSessionRunnerReconciliationProjectionHistoryChainCandidate,
    super.enableSessionRunnerReceiptHistoryCandidate,
    super.sessionRunnerReceiptHistoryCandidateApiOrigin,
    super.enableRunExecutionEvidenceCandidate,
    super.runExecutionEvidenceCandidateApiOrigin,
    super.enableExecutionReconciliationCandidate,
    super.executionReconciliationCandidateApiOrigin,
    super.enableExecutionConsentPreviewCandidate,
    super.executionConsentPreviewCandidateApiOrigin,
    super.enableRunnerAttemptBoundaryCandidate,
    super.runnerAttemptBoundaryCandidateApiOrigin,
    super.enableRunnerAttemptBoundaryProjection,
    super.enablePendingRunIntentCandidate,
    super.pendingRunIntentCandidateApiOrigin,
    super.enablePromptAppendReceiptCandidate,
    super.promptAppendReceiptCandidateApiOrigin,
    super.enableDeviceInventoryCandidate,
    super.deviceInventoryCandidateApiOrigin,
    super.enableDeviceInventoryResourceConvergenceCandidate,
    super.deviceInventoryResourceConvergenceCandidateApiOrigin,
    super.enableDeviceInventoryRegistryPlacementPreviewCandidate,
    super.deviceInventoryRegistryPlacementPreviewCandidateApiOrigin,
    super.enableSchedulerSelectionPreviewCandidate,
    super.schedulerSelectionPreviewCandidateApiOrigin,
    super.enableSchedulerSelectionLeaseCandidate,
    super.schedulerSelectionLeaseCandidateApiOrigin,
    super.enableSchedulerSelectionLeaseRenewalCandidate,
    super.schedulerSelectionLeaseRenewalCandidateApiOrigin,
    super.enableSchedulerSelectionLeaseReleaseCandidate,
    super.schedulerSelectionLeaseReleaseCandidateApiOrigin,
    super.enableClientInstanceResourceViewCandidate,
    super.clientInstanceResourceViewCandidateApiOrigin,
    super.enableRunAttemptLeaseDispatchPreflightCandidate,
    super.runAttemptLeaseDispatchPreflightCandidateApiOrigin,
    super.enableRunnerDispatchPlanPreviewCandidate,
    super.runnerDispatchPlanPreviewCandidateApiOrigin,
    super.enableRunnerDispatchAdmissionCandidate,
    super.runnerDispatchAdmissionCandidateApiOrigin,
    super.enableRunnerTransportAdmissionCandidate,
    super.runnerTransportAdmissionCandidateApiOrigin,
    super.enableRunnerExecutionBoundaryCandidate,
    super.runnerExecutionBoundaryCandidateApiOrigin,
    super.enableClientInstanceSessionViewCandidate,
    super.clientInstanceSessionViewCandidateApiOrigin,
    super.enableClientInstanceSessionResourceConvergenceCandidate,
    super.clientInstanceSessionResourceConvergenceCandidateApiOrigin,
    super.enableLifecycleRegistryCandidate,
    super.lifecycleRegistryCandidateApiOrigin,
    super.enableDeviceCredentialCandidate,
    super.deviceCredentialCandidateApiOrigin,
    this.credentialStore,
    this.initialConversationID,
    this.initialClientInstanceID,
    this.conversationChangesStreamWaitMS = 15000,
    this.httpClient,
    this.deviceObservation,
    this.deviceObservationRequest,
    this.runIntentObservation,
    this.runnerExecutionIntentObservation,
    this.localRunnerPreview,
    this.runObserved,
    this.runExecutionEvidence,
    this.sessionRunnerReceiptObservation,
    this.sessionRunnerReceiptVectorsPreview,
    this.sessionRunnerReceiptHistoryPreview,
    this.sessionRunnerReconciliationProjectionPreview,
    this.executionReconciliationObservation,
    this.attemptRequestPreview,
    this.runnerAttemptBoundaryPreview,
    this.pendingRunIntentPreview,
    this.deviceInventoryV2Preview,
    this.deviceInventoryPlacementEvaluationV2Preview,
    this.deviceInventoryPlacementEvaluationPreview,
    this.deviceInventoryPlacementBatchEvaluationPreview,
    this.runnerLeaseFencingPreview,
    this.executionLeaseCheckpointPreview,
    this.clientInstanceSessionViewPreview,
    this.clientInstanceResourceViewPreview,
    this.runAttemptLeaseDispatchPreflightPreview,
    this.runnerDispatchPlanPreview,
  });
}
