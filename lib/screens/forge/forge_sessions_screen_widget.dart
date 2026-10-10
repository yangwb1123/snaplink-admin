part of 'forge_sessions_screen.dart';

/// Shared Forge Sessions surface.
/// Constructor contracts are kept on typed interfaces in this library.
class ForgeSessionsScreen extends _ForgeSessionsTransport
    implements _ForgeSessionsScreenContract1, _ForgeSessionsScreenContract2 {
  @override
  final ForgeSessionDeviceObservation? deviceObservation;
  @override
  final ForgeSessionPlacementRequest? deviceObservationRequest;
  @override
  final ForgeRunIntentObservation? runIntentObservation;
  @override
  final ForgeRunnerExecutionIntentObservation? runnerExecutionIntentObservation;
  @override
  final ForgeRunnerExecutionIntentRequest? runnerExecutionIntentRequest;
  @override
  final ForgeRunnerExecutionIntentReader? runnerExecutionIntentReader;
  @override
  final ForgeLocalRunnerPreviewObservation? localRunnerPreview;
  @override
  final ForgeLocalRunnerPreviewRequest? localRunnerPreviewRequest;
  @override
  final ForgeLocalRunnerPreviewReader? localRunnerPreviewReader;
  @override
  final ForgeRunObserved? runObserved;
  @override
  final ForgeRunObservedReader? runObservedReader;
  @override
  final ForgeSessionRunnerReceiptObservationReader?
  sessionRunnerReceiptObservationReader;
  @override
  final ForgeRunExecutionEvidence? runExecutionEvidence;
  @override
  final ForgeRunExecutionEvidenceReader? runExecutionEvidenceReader;
  @override
  final ForgeSessionRunnerReceiptObservation? sessionRunnerReceiptObservation;
  @override
  final ForgeSessionRunnerReceiptVectors? sessionRunnerReceiptVectorsPreview;
  @override
  final ForgeSessionRunnerReceiptVectorsFileReader?
  sessionRunnerReceiptVectorsFileReader;
  @override
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryPreview;
  @override
  final ForgeSessionRunnerReceiptHistoryFileReader?
  sessionRunnerReceiptHistoryFileReader;
  @override
  final ForgeSessionRunnerReconciliationProjection?
  sessionRunnerReconciliationProjectionPreview;
  @override
  final ForgeSessionRunnerReconciliationProjectionFileReader?
  sessionRunnerReconciliationProjectionFileReader;
  @override
  final ForgeSessionRunnerReceiptHistory?
  sessionRunnerReconciliationProjectionRequest;
  @override
  final ForgeSessionRunnerReconciliationProjectionReader?
  sessionRunnerReconciliationProjectionReader;
  @override
  final ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistoryRequest;
  @override
  final ForgeSessionRunnerReceiptHistoryReader?
  sessionRunnerReceiptHistoryReader;
  @override
  final ForgeExecutionReconciliationObservation?
  executionReconciliationObservation;
  @override
  final ForgeExecutionReconciliationInput? executionReconciliationInput;
  @override
  final ForgeExecutionReconciliationReader? executionReconciliationReader;
  @override
  final ForgeDeviceOwner? executionConsentPreviewOwner;
  @override
  final ForgeExecutionConsentPreviewReader? executionConsentPreviewReader;
  @override
  final ForgeAttemptRequestPreviewFixture? attemptRequestPreview;
  @override
  final ForgeRunnerAttemptBoundaryObservation? runnerAttemptBoundaryPreview;
  @override
  final ForgeRunnerAttemptBoundaryScope? runnerAttemptBoundaryScope;
  @override
  final ForgeRunnerAttemptBoundaryFileReader? runnerAttemptBoundaryFileReader;
  @override
  final ForgeRunnerAttemptBoundaryPreviewRequest? runnerAttemptBoundaryRequest;
  @override
  final ForgeRunnerAttemptBoundaryReader? runnerAttemptBoundaryReader;
  @override
  final bool enableRunnerAttemptBoundaryProjection;
  @override
  final ForgePendingRunIntentFixture? pendingRunIntentPreview;
  @override
  final ForgeDeviceOwner? pendingRunIntentOwner;
  @override
  final ForgePendingRunIntentSubmitter? pendingRunIntentSubmitter;
  @override
  final ForgeDeviceOwner? promptAppendReceiptOwner;
  @override
  final ForgePromptAppendReceiptSubmitter? promptAppendReceiptSubmitter;
  @override
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
  final ForgeSchedulerSelectionPreview? schedulerSelectionPreview;
  @override
  final ForgeSchedulerSelectionPreviewRequest? schedulerSelectionPreviewRequest;
  @override
  final ForgeSchedulerSelectionPreviewReader? schedulerSelectionPreviewReader;
  @override
  final ForgeSchedulerSelectionLease? schedulerSelectionLease;
  @override
  final ForgeSchedulerSelectionLeaseRequest? schedulerSelectionLeaseRequest;
  @override
  final ForgeSchedulerSelectionLeaseReader? schedulerSelectionLeaseReader;
  @override
  final String? schedulerSelectionLeaseIdempotencyKey;
  @override
  final ForgeSchedulerSelectionLeaseRenewalRequest?
  schedulerSelectionLeaseRenewalRequest;
  @override
  final ForgeSchedulerSelectionLeaseRenewalReader?
  schedulerSelectionLeaseRenewalReader;
  @override
  final String? schedulerSelectionLeaseRenewalIdempotencyKey;
  @override
  final ForgeSchedulerSelectionLeaseRelease? schedulerSelectionLeaseRelease;
  @override
  final ForgeSchedulerSelectionLeaseReleaseRequest?
  schedulerSelectionLeaseReleaseRequest;
  @override
  final ForgeSchedulerSelectionLeaseReleaseReader?
  schedulerSelectionLeaseReleaseReader;
  @override
  final String? schedulerSelectionLeaseReleaseIdempotencyKey;
  @override
  final ForgeDeviceInventoryPageV2? deviceInventoryV2Preview;
  @override
  final ForgeDeviceInventoryV2FileReader? deviceInventoryV2FileReader;
  @override
  final ForgeDeviceResourceSummaryFixture? deviceResourceSummaryPreview;
  @override
  final ForgeDeviceResourceSummaryFileReader? deviceResourceSummaryFileReader;
  @override
  final ForgeDeviceInventoryPlacementEvaluationV2?
  deviceInventoryPlacementEvaluationV2Preview;
  @override
  final ForgeDeviceInventoryPlacementEvaluationV2FileReader?
  deviceInventoryPlacementEvaluationV2FileReader;
  @override
  final ForgeDeviceInventoryPlacementEvaluationFixture?
  deviceInventoryPlacementEvaluationPreview;
  @override
  final ForgeDeviceInventoryPlacementEvaluationFileReader?
  deviceInventoryPlacementEvaluationFileReader;
  @override
  final ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  deviceInventoryPlacementBatchEvaluationPreview;
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
  final ForgeRunnerLeaseFencingFixture? runnerLeaseFencingPreview;
  @override
  final ForgeRunnerLeaseFencingFileReader? runnerLeaseFencingFileReader;
  @override
  final ForgeExecutionLeaseCheckpointFixture? executionLeaseCheckpointPreview;
  @override
  final ForgeExecutionLeaseCheckpointFileReader?
  executionLeaseCheckpointFileReader;
  @override
  final ForgeClientInstanceSessionView? clientInstanceSessionViewPreview;
  @override
  final ForgeClientInstanceSessionViewFileReader?
  clientInstanceSessionViewFileReader;
  @override
  final ForgeClientInstanceResourceView? clientInstanceResourceViewPreview;
  @override
  final ForgeClientInstanceResourceViewFileReader?
  clientInstanceResourceViewFileReader;
  @override
  final ForgeDeviceOwner? clientInstanceResourceViewOwner;
  @override
  final ForgeClientInstanceResourceViewReader? clientInstanceResourceViewReader;
  @override
  final ForgePreflightFixture? runAttemptLeaseDispatchPreflightPreview;
  @override
  final ForgeRunAttemptLeaseDispatchPreflightRequest?
  runAttemptLeaseDispatchPreflightRequest;
  @override
  final ForgeRunAttemptLeaseDispatchPreflightReader?
  runAttemptLeaseDispatchPreflightReader;
  @override
  final ForgeRunnerDispatchPlanPreview? runnerDispatchPlanPreview;
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

  const ForgeSessionsScreen({
    super.key,
    required super.accessToken,
    required super.apiOrigin,
    super.enableConversationChangesStream = false,
    super.conversationChangesStreamWaitMS = 15000,
    super.initialConversationID,
    super.initialClientInstanceID,
    super.httpClient,
    super.oauthHttpClient,
    super.oauthRevocationTimeout = const Duration(seconds: 5),
    super.credentialStore,
    this.deviceObservation,
    this.deviceObservationRequest,
    this.runIntentObservation,
    this.runnerExecutionIntentObservation,
    this.runnerExecutionIntentRequest,
    this.runnerExecutionIntentReader,
    this.localRunnerPreview,
    this.localRunnerPreviewRequest,
    this.localRunnerPreviewReader,
    this.runObserved,
    this.runObservedReader,
    this.sessionRunnerReceiptObservationReader,
    this.runExecutionEvidence,
    this.runExecutionEvidenceReader,
    this.sessionRunnerReceiptObservation,
    this.sessionRunnerReceiptVectorsPreview,
    this.sessionRunnerReceiptVectorsFileReader,
    this.sessionRunnerReceiptHistoryPreview,
    this.sessionRunnerReceiptHistoryFileReader,
    this.sessionRunnerReconciliationProjectionPreview,
    this.sessionRunnerReconciliationProjectionFileReader,
    this.sessionRunnerReconciliationProjectionRequest,
    this.sessionRunnerReconciliationProjectionReader,
    this.sessionRunnerReceiptHistoryRequest,
    this.sessionRunnerReceiptHistoryReader,
    this.executionReconciliationObservation,
    this.executionReconciliationInput,
    this.executionReconciliationReader,
    this.executionConsentPreviewOwner,
    this.executionConsentPreviewReader,
    this.attemptRequestPreview,
    this.runnerAttemptBoundaryPreview,
    this.runnerAttemptBoundaryScope,
    this.runnerAttemptBoundaryFileReader,
    this.runnerAttemptBoundaryRequest,
    this.runnerAttemptBoundaryReader,
    this.enableRunnerAttemptBoundaryProjection = false,
    this.pendingRunIntentPreview,
    this.pendingRunIntentOwner,
    this.pendingRunIntentSubmitter,
    this.promptAppendReceiptOwner,
    this.promptAppendReceiptSubmitter,
    this.requireDeviceInventoryResourceConvergenceForPromptAppend = false,
    this.deviceInventoryOwner,
    this.deviceInventoryReader,
    this.deviceInventoryV2Reader,
    this.deviceInventoryResourceConvergenceOwner,
    this.deviceInventoryResourceConvergenceReader,
    this.deviceInventoryRegistryPlacementRequirements,
    this.deviceInventoryRegistryPlacementPreviewReader,
    this.schedulerSelectionPreview,
    this.schedulerSelectionPreviewRequest,
    this.schedulerSelectionPreviewReader,
    this.schedulerSelectionLease,
    this.schedulerSelectionLeaseRequest,
    this.schedulerSelectionLeaseReader,
    this.schedulerSelectionLeaseIdempotencyKey,
    this.schedulerSelectionLeaseRenewalRequest,
    this.schedulerSelectionLeaseRenewalReader,
    this.schedulerSelectionLeaseRenewalIdempotencyKey,
    this.schedulerSelectionLeaseRelease,
    this.schedulerSelectionLeaseReleaseRequest,
    this.schedulerSelectionLeaseReleaseReader,
    this.schedulerSelectionLeaseReleaseIdempotencyKey,
    this.deviceInventoryV2Preview,
    this.deviceInventoryV2FileReader,
    this.deviceResourceSummaryPreview,
    this.deviceResourceSummaryFileReader,
    this.deviceInventoryPlacementEvaluationV2Preview,
    this.deviceInventoryPlacementEvaluationV2FileReader,
    this.deviceInventoryPlacementEvaluationPreview,
    this.deviceInventoryPlacementEvaluationFileReader,
    this.deviceInventoryPlacementBatchEvaluationPreview,
    this.deviceInventoryPlacementBatchEvaluationFileReader,
    this.pendingRunIntentReader,
    this.pendingRunIntentPageReader,
    this.pendingRunIntentTimelineReader,
    this.runnerLeaseFencingPreview,
    this.runnerLeaseFencingFileReader,
    this.executionLeaseCheckpointPreview,
    this.executionLeaseCheckpointFileReader,
    this.clientInstanceSessionViewPreview,
    this.clientInstanceSessionViewFileReader,
    this.clientInstanceResourceViewPreview,
    this.clientInstanceResourceViewFileReader,
    this.clientInstanceResourceViewOwner,
    this.clientInstanceResourceViewReader,
    this.clientInstanceSessionViewOwner,
    this.clientInstanceSessionViewReader,
    this.clientInstanceSessionResourceConvergenceOwner,
    this.clientInstanceSessionResourceConvergenceReader,
    this.lifecycleRegistryOwner,
    this.lifecycleRegistryReader,
    this.deviceCredentialCandidateOwner,
    this.deviceCredentialCandidateRequest,
    this.deviceCredentialCandidateReader,
    this.runAttemptLeaseDispatchPreflightPreview,
    this.runAttemptLeaseDispatchPreflightRequest,
    this.runAttemptLeaseDispatchPreflightReader,
    this.runnerDispatchPlanPreview,
    this.runnerDispatchPlanPreviewRequest,
    this.runnerDispatchPlanPreviewReader,
    this.runnerDispatchAdmission,
    this.runnerDispatchAdmissionRequest,
    this.runnerDispatchAdmissionReader,
    this.runnerTransportAdmission,
    this.runnerTransportAdmissionRequest,
    this.runnerTransportAdmissionReader,
    this.runnerExecutionBoundary,
    this.runnerExecutionBoundaryRequest,
    this.runnerExecutionBoundaryReader,
  });

  @override
  State<ForgeSessionsScreen> createState() => _ForgeSessionsScreenState();
}
