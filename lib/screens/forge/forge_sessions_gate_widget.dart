part of 'forge_sessions_gate.dart';

/// Shared Forge Sessions authentication gate.
/// Constructor contracts are kept on typed interfaces in this library.
class ForgeSessionsGate extends _ForgeSessionsGateInputs
    implements
        _ForgeSessionsGateContract1,
        _ForgeSessionsGateContract2,
        _ForgeSessionsGateContract3 {
  @override
  final ForgeRunnerExecutionIntentRequest? runnerExecutionIntentRequest;
  @override
  final ForgeRunnerExecutionIntentReader? runnerExecutionIntentReader;
  @override
  final ForgeLocalRunnerPreviewRequest? localRunnerPreviewRequest;
  @override
  final ForgeLocalRunnerPreviewReader? localRunnerPreviewReader;
  @override
  final ForgeRunObservedReader? runObservedReader;
  @override
  final ForgeSessionRunnerReceiptObservationReader?
  sessionRunnerReceiptObservationReader;
  @override
  final ForgeSessionRunnerReceiptVectorsFileReader?
  sessionRunnerReceiptVectorsFileReader;
  @override
  final ForgeSessionRunnerReceiptHistoryFileReader?
  sessionRunnerReceiptHistoryFileReader;
  @override
  final ForgeSessionRunnerReconciliationProjectionFileReader?
  sessionRunnerReconciliationProjectionFileReader;
  @override
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryRequest;
  @override
  final ForgeSessionRunnerReceiptHistoryReader?
  sessionRunnerReceiptHistoryReader;
  @override
  final ForgeSessionRunnerReceiptHistory?
  sessionRunnerReconciliationProjectionRequest;
  @override
  final ForgeSessionRunnerReconciliationProjectionReader?
  sessionRunnerReconciliationProjectionReader;
  @override
  final ForgeRunExecutionEvidenceReader? runExecutionEvidenceReader;
  @override
  final ForgeExecutionReconciliationInput? executionReconciliationInput;
  @override
  final ForgeExecutionReconciliationReader? executionReconciliationReader;
  @override
  final ForgeDeviceOwner? executionConsentPreviewOwner;
  @override
  final ForgeExecutionConsentPreviewReader? executionConsentPreviewReader;
  @override
  final ForgeRunnerAttemptBoundaryScope? runnerAttemptBoundaryScope;
  @override
  final ForgeRunnerAttemptBoundaryFileReader? runnerAttemptBoundaryFileReader;
  @override
  final ForgeRunnerAttemptBoundaryPreviewRequest? runnerAttemptBoundaryRequest;
  @override
  final ForgeRunnerAttemptBoundaryReader? runnerAttemptBoundaryReader;
  @override
  final ForgeDeviceOwner? pendingRunIntentOwner;
  @override
  final ForgeDeviceOwner? promptAppendReceiptOwner;
  @override
  final ForgePromptAppendReceiptSubmitter? promptAppendReceiptSubmitter;
  @override
  @visibleForTesting
  final bool requireDeviceInventoryResourceConvergenceForPromptAppend;
  @override
  final ForgeDeviceOwner? deviceInventoryOwner;
  @override
  final ForgeDeviceInventoryCandidateReader? deviceInventoryReader;
  @override
  final ForgeDeviceInventoryV2Reader? deviceInventoryV2Reader;
  @override
  final ForgeDeviceOwner? deviceInventoryResourceConvergenceOwner;
  @override
  final ForgeDeviceInventoryResourceConvergenceReader?
  deviceInventoryResourceConvergenceReader;
  @override
  final ForgeDevicePlacementRequirements?
  deviceInventoryRegistryPlacementRequirements;
  @override
  final ForgeDeviceRegistryPlacementPreviewReader?
  deviceInventoryRegistryPlacementPreviewReader;
  @override
  final ForgeSchedulerSelectionPreviewRequest? schedulerSelectionPreviewRequest;
  @override
  final ForgeSchedulerSelectionPreviewReader? schedulerSelectionPreviewReader;
  @override
  final ForgeSchedulerSelectionLeaseRequest? schedulerSelectionLeaseRequest;
  @override
  final ForgeSchedulerSelectionLeaseReader? schedulerSelectionLeaseReader;
  @override
  @visibleForTesting
  final String? schedulerSelectionLeaseIdempotencyKey;
  @override
  final ForgeSchedulerSelectionLeaseRenewalRequest?
  schedulerSelectionLeaseRenewalRequest;
  @override
  final ForgeSchedulerSelectionLeaseRenewalReader?
  schedulerSelectionLeaseRenewalReader;
  @override
  @visibleForTesting
  final String? schedulerSelectionLeaseRenewalIdempotencyKey;
  @override
  final ForgeSchedulerSelectionLeaseReleaseRequest?
  schedulerSelectionLeaseReleaseRequest;
  @override
  final ForgeSchedulerSelectionLeaseReleaseReader?
  schedulerSelectionLeaseReleaseReader;
  @override
  @visibleForTesting
  final String? schedulerSelectionLeaseReleaseIdempotencyKey;
  @override
  final ForgeDeviceInventoryV2FileReader? deviceInventoryV2FileReader;
  @override
  final ForgeDeviceInventoryPlacementEvaluationV2FileReader?
  deviceInventoryPlacementEvaluationV2FileReader;
  @override
  final ForgeDeviceInventoryPlacementEvaluationFileReader?
  deviceInventoryPlacementEvaluationFileReader;
  @override
  final ForgeDeviceInventoryPlacementBatchEvaluationFileReader?
  deviceInventoryPlacementBatchEvaluationFileReader;
  @override
  final ForgePendingRunIntentReader? pendingRunIntentReader;
  @override
  final ForgePendingRunIntentPageReader? pendingRunIntentPageReader;
  @override
  final ForgePendingRunIntentTimelineReader? pendingRunIntentTimelineReader;
  @override
  final ForgeRunnerLeaseFencingFileReader? runnerLeaseFencingFileReader;
  @override
  final ForgeExecutionLeaseCheckpointFileReader?
  executionLeaseCheckpointFileReader;
  @override
  final ForgeDeviceOwner? clientInstanceResourceViewOwner;
  @override
  final ForgeClientInstanceResourceViewReader? clientInstanceResourceViewReader;
  @override
  final ForgeRunAttemptLeaseDispatchPreflightRequest?
  runAttemptLeaseDispatchPreflightRequest;
  @override
  final ForgeRunAttemptLeaseDispatchPreflightReader?
  runAttemptLeaseDispatchPreflightReader;
  @override
  final ForgeRunAttemptLeaseDispatchPreflightRequest?
  runnerDispatchPlanPreviewRequest;
  @override
  final ForgeRunnerDispatchPlanPreviewReader? runnerDispatchPlanPreviewReader;
  @override
  final ForgeRunnerDispatchAdmission? runnerDispatchAdmission;
  @override
  final ForgeRunnerDispatchAdmissionRequest? runnerDispatchAdmissionRequest;
  @override
  final ForgeRunnerDispatchAdmissionReader? runnerDispatchAdmissionReader;
  @override
  final ForgeRunnerTransportAdmission? runnerTransportAdmission;
  @override
  final ForgeRunnerTransportAdmissionRequest? runnerTransportAdmissionRequest;
  @override
  final ForgeRunnerTransportAdmissionReader? runnerTransportAdmissionReader;
  @override
  final ForgeRunnerExecutionBoundaryObservation? runnerExecutionBoundary;
  @override
  final ForgeRunnerExecutionBoundaryPreviewRequest?
  runnerExecutionBoundaryRequest;
  @override
  final ForgeRunnerExecutionBoundaryReader? runnerExecutionBoundaryReader;
  @override
  final ForgeDeviceOwner? clientInstanceSessionViewOwner;
  @override
  final ForgeClientInstanceSessionViewReader? clientInstanceSessionViewReader;
  @override
  final ForgeDeviceOwner? clientInstanceSessionResourceConvergenceOwner;
  @override
  final ForgeClientInstanceSessionResourceConvergenceReader?
  clientInstanceSessionResourceConvergenceReader;
  @override
  final ForgeDeviceOwner? lifecycleRegistryOwner;
  @override
  final ForgeLifecycleRegistryReader? lifecycleRegistryReader;
  @override
  final ForgeDeviceOwner? deviceCredentialCandidateOwner;
  @override
  final ForgeDeviceCredentialLifecycleRequest? deviceCredentialCandidateRequest;
  @override
  final ForgeDeviceCredentialLifecycleCandidateReader?
  deviceCredentialCandidateReader;
  @override
  @visibleForTesting
  final Widget Function(String accessToken)? testScreenBuilder;
  @override
  @visibleForTesting
  final Widget Function(String accessToken, String? initialConversationID)?
  testScreenBuilderWithRoute;

  const ForgeSessionsGate({
    super.key,
    super.credentialStore,
    super.initialConversationID,
    super.initialClientInstanceID,
    super.enableConversationChangesStream = false,
    super.conversationChangesStreamWaitMS = 15000,
    super.httpClient,
    super.deviceObservation,
    super.deviceObservationRequest,
    super.runIntentObservation,
    super.runnerExecutionIntentObservation,
    this.runnerExecutionIntentRequest,
    this.runnerExecutionIntentReader,
    super.enableRunnerExecutionIntentCandidate = false,
    super.runnerExecutionIntentCandidateApiOrigin,
    super.runObserved,
    this.runObservedReader,
    this.sessionRunnerReceiptObservationReader,
    super.enableRunObservedCandidate = false,
    super.runObservedCandidateApiOrigin,
    super.enableDeviceInventoryV2Candidate = false,
    super.deviceInventoryV2CandidateApiOrigin,
    super.runExecutionEvidence,
    super.sessionRunnerReceiptObservation,
    super.sessionRunnerReceiptVectorsPreview,
    this.sessionRunnerReceiptVectorsFileReader,
    super.sessionRunnerReceiptHistoryPreview,
    this.sessionRunnerReceiptHistoryFileReader,
    super.sessionRunnerReconciliationProjectionPreview,
    this.sessionRunnerReconciliationProjectionFileReader,
    this.sessionRunnerReceiptHistoryRequest,
    this.sessionRunnerReceiptHistoryReader,
    this.sessionRunnerReconciliationProjectionRequest,
    this.sessionRunnerReconciliationProjectionReader,
    super.enableSessionRunnerReconciliationProjectionCandidate = false,
    super.sessionRunnerReconciliationProjectionCandidateApiOrigin,
    super.enableSessionRunnerReconciliationProjectionHistoryChainCandidate =
        false,
    super.enableSessionRunnerReceiptHistoryCandidate = false,
    super.sessionRunnerReceiptHistoryCandidateApiOrigin,
    this.runExecutionEvidenceReader,
    super.enableRunExecutionEvidenceCandidate = false,
    super.runExecutionEvidenceCandidateApiOrigin,
    super.executionReconciliationObservation,
    this.executionReconciliationInput,
    this.executionReconciliationReader,
    super.enableExecutionReconciliationCandidate = false,
    super.executionReconciliationCandidateApiOrigin,
    this.executionConsentPreviewOwner,
    this.executionConsentPreviewReader,
    super.enableExecutionConsentPreviewCandidate = false,
    super.executionConsentPreviewCandidateApiOrigin,
    super.attemptRequestPreview,
    super.runnerAttemptBoundaryPreview,
    this.runnerAttemptBoundaryScope,
    this.runnerAttemptBoundaryFileReader,
    this.runnerAttemptBoundaryRequest,
    this.runnerAttemptBoundaryReader,
    super.enableRunnerAttemptBoundaryCandidate = false,
    super.runnerAttemptBoundaryCandidateApiOrigin,
    super.enableRunnerAttemptBoundaryProjection = false,
    super.pendingRunIntentPreview,
    super.enablePendingRunIntentCandidate = false,
    this.pendingRunIntentOwner,
    super.pendingRunIntentCandidateApiOrigin,
    this.promptAppendReceiptOwner,
    this.promptAppendReceiptSubmitter,
    super.enablePromptAppendReceiptCandidate = false,
    super.promptAppendReceiptCandidateApiOrigin,
    this.requireDeviceInventoryResourceConvergenceForPromptAppend = false,
    this.deviceInventoryOwner,
    this.deviceInventoryReader,
    super.enableDeviceInventoryCandidate = false,
    super.deviceInventoryCandidateApiOrigin,
    this.deviceInventoryV2Reader,
    this.deviceInventoryResourceConvergenceOwner,
    this.deviceInventoryResourceConvergenceReader,
    super.enableDeviceInventoryResourceConvergenceCandidate = false,
    super.deviceInventoryResourceConvergenceCandidateApiOrigin,
    this.deviceInventoryRegistryPlacementRequirements,
    this.deviceInventoryRegistryPlacementPreviewReader,
    super.enableDeviceInventoryRegistryPlacementPreviewCandidate = false,
    super.deviceInventoryRegistryPlacementPreviewCandidateApiOrigin,
    this.schedulerSelectionPreviewRequest,
    this.schedulerSelectionPreviewReader,
    super.enableSchedulerSelectionPreviewCandidate = false,
    super.schedulerSelectionPreviewCandidateApiOrigin,
    this.schedulerSelectionLeaseRequest,
    this.schedulerSelectionLeaseReader,
    super.enableSchedulerSelectionLeaseCandidate = false,
    super.schedulerSelectionLeaseCandidateApiOrigin,
    this.schedulerSelectionLeaseIdempotencyKey,
    this.schedulerSelectionLeaseRenewalRequest,
    this.schedulerSelectionLeaseRenewalReader,
    super.enableSchedulerSelectionLeaseRenewalCandidate = false,
    super.schedulerSelectionLeaseRenewalCandidateApiOrigin,
    this.schedulerSelectionLeaseRenewalIdempotencyKey,
    this.schedulerSelectionLeaseReleaseRequest,
    this.schedulerSelectionLeaseReleaseReader,
    super.enableSchedulerSelectionLeaseReleaseCandidate = false,
    super.schedulerSelectionLeaseReleaseCandidateApiOrigin,
    this.schedulerSelectionLeaseReleaseIdempotencyKey,
    super.deviceInventoryV2Preview,
    this.deviceInventoryV2FileReader,
    super.deviceInventoryPlacementEvaluationV2Preview,
    this.deviceInventoryPlacementEvaluationV2FileReader,
    super.deviceInventoryPlacementEvaluationPreview,
    this.deviceInventoryPlacementEvaluationFileReader,
    super.deviceInventoryPlacementBatchEvaluationPreview,
    this.deviceInventoryPlacementBatchEvaluationFileReader,
    this.pendingRunIntentReader,
    this.pendingRunIntentPageReader,
    this.pendingRunIntentTimelineReader,
    super.runnerLeaseFencingPreview,
    this.runnerLeaseFencingFileReader,
    super.executionLeaseCheckpointPreview,
    this.executionLeaseCheckpointFileReader,
    super.clientInstanceSessionViewPreview,
    super.clientInstanceResourceViewPreview,
    this.clientInstanceResourceViewOwner,
    this.clientInstanceResourceViewReader,
    super.enableClientInstanceResourceViewCandidate = false,
    super.clientInstanceResourceViewCandidateApiOrigin,
    this.clientInstanceSessionViewOwner,
    this.clientInstanceSessionViewReader,
    super.enableClientInstanceSessionViewCandidate = false,
    super.clientInstanceSessionViewCandidateApiOrigin,
    this.clientInstanceSessionResourceConvergenceOwner,
    this.clientInstanceSessionResourceConvergenceReader,
    super.enableClientInstanceSessionResourceConvergenceCandidate = false,
    super.clientInstanceSessionResourceConvergenceCandidateApiOrigin,
    this.lifecycleRegistryOwner,
    this.lifecycleRegistryReader,
    super.enableLifecycleRegistryCandidate = false,
    super.lifecycleRegistryCandidateApiOrigin,
    this.deviceCredentialCandidateOwner,
    this.deviceCredentialCandidateRequest,
    this.deviceCredentialCandidateReader,
    super.enableDeviceCredentialCandidate = false,
    super.deviceCredentialCandidateApiOrigin,
    super.runAttemptLeaseDispatchPreflightPreview,
    this.runAttemptLeaseDispatchPreflightRequest,
    this.runAttemptLeaseDispatchPreflightReader,
    super.enableRunAttemptLeaseDispatchPreflightCandidate = false,
    super.runAttemptLeaseDispatchPreflightCandidateApiOrigin,
    super.runnerDispatchPlanPreview,
    this.runnerDispatchPlanPreviewRequest,
    this.runnerDispatchPlanPreviewReader,
    super.enableRunnerDispatchPlanPreviewCandidate = false,
    super.runnerDispatchPlanPreviewCandidateApiOrigin,
    this.runnerDispatchAdmissionRequest,
    this.runnerDispatchAdmissionReader,
    this.runnerDispatchAdmission,
    super.enableRunnerDispatchAdmissionCandidate = false,
    super.runnerDispatchAdmissionCandidateApiOrigin,
    this.runnerTransportAdmissionRequest,
    this.runnerTransportAdmissionReader,
    this.runnerTransportAdmission,
    this.runnerExecutionBoundaryRequest,
    this.runnerExecutionBoundaryReader,
    this.runnerExecutionBoundary,
    super.enableRunnerExecutionBoundaryCandidate = false,
    super.runnerExecutionBoundaryCandidateApiOrigin,
    super.enableRunnerTransportAdmissionCandidate = false,
    super.runnerTransportAdmissionCandidateApiOrigin,
    super.localRunnerPreview,
    this.localRunnerPreviewRequest,
    this.localRunnerPreviewReader,
    super.enableLocalRunnerPreviewCandidate = false,
    super.localRunnerPreviewCandidateApiOrigin,
    this.testScreenBuilder,
    this.testScreenBuilderWithRoute,
  });

  @override
  State<ForgeSessionsGate> createState() => _ForgeSessionsGateState();
}
