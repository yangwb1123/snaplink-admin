part of 'forge_sessions_screen.dart';

typedef _ForgeSessionInputs = ({
  String? selectedConversationID,
  String? selectedRunID,
  bool schedulerSelectionLeaseCandidateEnabled,
  bool schedulerSelectionLeaseReleaseCandidateEnabled,
  ForgeSessionDeviceObservation? staticObservation,
  ForgeRunIntentObservation? runIntentObservation,
  ForgeRunnerExecutionIntentObservation? runnerExecutionIntentObservation,
  ForgeRunObserved? runObserved,
  ForgeRunObserved? fetchedRunObserved,
  ForgeRunExecutionEvidence? runExecutionEvidence,
  ForgeClientInstanceSessionView? clientInstanceSessionView,
  ForgeDeviceInventoryResourceConvergence? inventoryResourceConvergence,
  ForgeClientInstanceResourceView? clientInstanceResourceView,
  ForgeExecutionLeaseCheckpointFixture? executionLeaseCheckpoint,
  ForgeSessionRunnerReceiptVectors? sessionRunnerReceiptVectors,
  ForgeSessionRunnerReceiptHistory? sessionRunnerReceiptHistory,
  ForgeSessionRunnerReconciliationProjection?
  sessionRunnerReconciliationProjection,
  ForgeSessionRunnerReconciliationProjection?
  fetchedSessionRunnerReconciliationProjection,
  ForgeDeviceInventoryPageV2? deviceInventoryV2Preview,
  ForgeDeviceResourceSummaryFixture? deviceResourceSummaryPreview,
  ForgeDeviceInventoryPlacementEvaluationV2?
  deviceInventoryPlacementEvaluationV2Preview,
  ForgeDeviceInventoryPlacementEvaluationFixture?
  deviceInventoryPlacementEvaluationPreview,
  ForgeDeviceInventoryPlacementBatchEvaluationFixture?
  deviceInventoryPlacementBatchEvaluationPreview,
  ForgeDeviceEnrollmentHeartbeatLifecycleRegistry? lifecycleRegistry,
  ForgeDeviceCredentialLifecycleCandidate? deviceCredentialCandidate,
  ForgeDeviceRegistryPlacementPreview? registryPlacementPreview,
});

typedef _ForgeSessionSelection = ({
  ForgeSchedulerSelectionPreview? schedulerSelectionPreview,
  ForgeSchedulerSelectionLease? schedulerSelectionLease,
  ForgeSchedulerSelectionLeaseRelease? schedulerSelectionLeaseRelease,
  Iterable<ForgeClientInstanceSessionViewInstance>?
  clientInstanceFilterInstances,
  bool clientInstanceProjectionInvalid,
  String? selectedClientInstanceID,
  List<ForgeOwnedConversation> visibleConversations,
  bool selectedConversationVisible,
  bool runResourceVisible,
});

typedef _ForgeSessionRunnerDisplay = ({
  ForgeSessionRunnerReceiptHistory? fetchedSessionRunnerReceiptHistory,
  ForgePreflightFixture? runAttemptLeaseDispatchPreflight,
  ForgeRunnerDispatchPlanPreview? runnerDispatchPlanPreview,
  ForgeRunnerDispatchAdmission? runnerDispatchAdmission,
  ForgeRunnerTransportAdmission? runnerTransportAdmission,
  ForgeRunnerExecutionBoundaryObservation? runnerExecutionBoundary,
  ForgeRunnerAttemptBoundaryObservation? runnerAttemptBoundary,
  ForgeLocalRunnerPreviewObservation? localRunnerPreview,
});

typedef _ForgeSessionReceiptDisplay = ({
  ForgeSessionDeviceObservation? observation,
  ForgeRunIntentObservation? displayRunIntentObservation,
  ForgeRunnerExecutionIntentObservation?
  displayRunnerExecutionIntentObservation,
  ForgeExecutionConsentPreview? executionConsentPreview,
  ForgeAttemptRequestPreviewFixture? attemptRequestPreview,
  ForgePendingRunIntentFixture? pendingRunIntentPreview,
  ForgePendingRunIntentReader? pendingRunIntentReader,
  ForgePendingRunIntentPageReader? pendingRunIntentPageReader,
  ForgeSessionRunnerReceiptObservation? displaySessionRunnerReceiptObservation,
  ForgeSessionRunnerReceiptHistory? displaySessionRunnerReceiptHistory,
  ForgeSessionRunnerReconciliationProjection?
  displaySessionRunnerReconciliationProjection,
  ForgeExecutionReconciliationObservation?
  displayExecutionReconciliationObservation,
  ForgeRunExecutionEvidence? displayRunExecutionEvidence,
  ForgeRunObserved? displayRunObserved,
  bool requestMatchesSelectedRun,
});

typedef _ForgeSessionDisplay = ({
  _ForgeSessionInputs inputs,
  _ForgeSessionSelection selection,
  _ForgeSessionRunnerDisplay runner,
  _ForgeSessionReceiptDisplay receipts,
});
