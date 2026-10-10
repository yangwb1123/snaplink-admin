part of 'forge_sessions_gate.dart';

abstract class _ForgeCandidateGate extends StatefulWidget {
  @visibleForTesting
  final bool enableConversationChangesStream;
  @visibleForTesting
  final bool enableRunnerExecutionIntentCandidate;
  @visibleForTesting
  final String? runnerExecutionIntentCandidateApiOrigin;
  @visibleForTesting
  final bool enableLocalRunnerPreviewCandidate;
  @visibleForTesting
  final String? localRunnerPreviewCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunObservedCandidate;
  @visibleForTesting
  final String? runObservedCandidateApiOrigin;
  @visibleForTesting
  final bool enableDeviceInventoryV2Candidate;
  @visibleForTesting
  final String? deviceInventoryV2CandidateApiOrigin;
  @visibleForTesting
  final bool enableSessionRunnerReconciliationProjectionCandidate;
  @visibleForTesting
  final String? sessionRunnerReconciliationProjectionCandidateApiOrigin;
  @visibleForTesting
  final bool enableSessionRunnerReconciliationProjectionHistoryChainCandidate;
  @visibleForTesting
  final bool enableSessionRunnerReceiptHistoryCandidate;
  @visibleForTesting
  final String? sessionRunnerReceiptHistoryCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunExecutionEvidenceCandidate;
  @visibleForTesting
  final String? runExecutionEvidenceCandidateApiOrigin;
  @visibleForTesting
  final bool enableExecutionReconciliationCandidate;
  @visibleForTesting
  final String? executionReconciliationCandidateApiOrigin;
  @visibleForTesting
  final bool enableExecutionConsentPreviewCandidate;
  @visibleForTesting
  final String? executionConsentPreviewCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunnerAttemptBoundaryCandidate;
  @visibleForTesting
  final String? runnerAttemptBoundaryCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunnerAttemptBoundaryProjection;
  @visibleForTesting
  final bool enablePendingRunIntentCandidate;
  @visibleForTesting
  final String? pendingRunIntentCandidateApiOrigin;
  @visibleForTesting
  final bool enablePromptAppendReceiptCandidate;
  @visibleForTesting
  final String? promptAppendReceiptCandidateApiOrigin;
  @visibleForTesting
  final bool enableDeviceInventoryCandidate;
  @visibleForTesting
  final String? deviceInventoryCandidateApiOrigin;
  @visibleForTesting
  final bool enableDeviceInventoryResourceConvergenceCandidate;
  @visibleForTesting
  final String? deviceInventoryResourceConvergenceCandidateApiOrigin;
  @visibleForTesting
  final bool enableDeviceInventoryRegistryPlacementPreviewCandidate;
  @visibleForTesting
  final String? deviceInventoryRegistryPlacementPreviewCandidateApiOrigin;
  @visibleForTesting
  final bool enableSchedulerSelectionPreviewCandidate;
  @visibleForTesting
  final String? schedulerSelectionPreviewCandidateApiOrigin;
  @visibleForTesting
  final bool enableSchedulerSelectionLeaseCandidate;
  @visibleForTesting
  final String? schedulerSelectionLeaseCandidateApiOrigin;
  @visibleForTesting
  final bool enableSchedulerSelectionLeaseRenewalCandidate;
  @visibleForTesting
  final String? schedulerSelectionLeaseRenewalCandidateApiOrigin;
  @visibleForTesting
  final bool enableSchedulerSelectionLeaseReleaseCandidate;
  @visibleForTesting
  final String? schedulerSelectionLeaseReleaseCandidateApiOrigin;
  @visibleForTesting
  final bool enableClientInstanceResourceViewCandidate;
  @visibleForTesting
  final String? clientInstanceResourceViewCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunAttemptLeaseDispatchPreflightCandidate;
  @visibleForTesting
  final String? runAttemptLeaseDispatchPreflightCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunnerDispatchPlanPreviewCandidate;
  @visibleForTesting
  final String? runnerDispatchPlanPreviewCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunnerDispatchAdmissionCandidate;
  @visibleForTesting
  final String? runnerDispatchAdmissionCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunnerTransportAdmissionCandidate;
  @visibleForTesting
  final String? runnerTransportAdmissionCandidateApiOrigin;
  @visibleForTesting
  final bool enableRunnerExecutionBoundaryCandidate;
  @visibleForTesting
  final String? runnerExecutionBoundaryCandidateApiOrigin;
  @visibleForTesting
  final bool enableClientInstanceSessionViewCandidate;
  @visibleForTesting
  final String? clientInstanceSessionViewCandidateApiOrigin;
  @visibleForTesting
  final bool enableClientInstanceSessionResourceConvergenceCandidate;
  @visibleForTesting
  final String? clientInstanceSessionResourceConvergenceCandidateApiOrigin;
  @visibleForTesting
  final bool enableLifecycleRegistryCandidate;
  @visibleForTesting
  final String? lifecycleRegistryCandidateApiOrigin;
  @visibleForTesting
  final bool enableDeviceCredentialCandidate;
  @visibleForTesting
  final String? deviceCredentialCandidateApiOrigin;

  const _ForgeCandidateGate({
    super.key,
    this.enableConversationChangesStream = false,
    this.enableRunnerExecutionIntentCandidate = false,
    this.runnerExecutionIntentCandidateApiOrigin,
    this.enableLocalRunnerPreviewCandidate = false,
    this.localRunnerPreviewCandidateApiOrigin,
    this.enableRunObservedCandidate = false,
    this.runObservedCandidateApiOrigin,
    this.enableDeviceInventoryV2Candidate = false,
    this.deviceInventoryV2CandidateApiOrigin,
    this.enableSessionRunnerReconciliationProjectionCandidate = false,
    this.sessionRunnerReconciliationProjectionCandidateApiOrigin,
    this.enableSessionRunnerReconciliationProjectionHistoryChainCandidate =
        false,
    this.enableSessionRunnerReceiptHistoryCandidate = false,
    this.sessionRunnerReceiptHistoryCandidateApiOrigin,
    this.enableRunExecutionEvidenceCandidate = false,
    this.runExecutionEvidenceCandidateApiOrigin,
    this.enableExecutionReconciliationCandidate = false,
    this.executionReconciliationCandidateApiOrigin,
    this.enableExecutionConsentPreviewCandidate = false,
    this.executionConsentPreviewCandidateApiOrigin,
    this.enableRunnerAttemptBoundaryCandidate = false,
    this.runnerAttemptBoundaryCandidateApiOrigin,
    this.enableRunnerAttemptBoundaryProjection = false,
    this.enablePendingRunIntentCandidate = false,
    this.pendingRunIntentCandidateApiOrigin,
    this.enablePromptAppendReceiptCandidate = false,
    this.promptAppendReceiptCandidateApiOrigin,
    this.enableDeviceInventoryCandidate = false,
    this.deviceInventoryCandidateApiOrigin,
    this.enableDeviceInventoryResourceConvergenceCandidate = false,
    this.deviceInventoryResourceConvergenceCandidateApiOrigin,
    this.enableDeviceInventoryRegistryPlacementPreviewCandidate = false,
    this.deviceInventoryRegistryPlacementPreviewCandidateApiOrigin,
    this.enableSchedulerSelectionPreviewCandidate = false,
    this.schedulerSelectionPreviewCandidateApiOrigin,
    this.enableSchedulerSelectionLeaseCandidate = false,
    this.schedulerSelectionLeaseCandidateApiOrigin,
    this.enableSchedulerSelectionLeaseRenewalCandidate = false,
    this.schedulerSelectionLeaseRenewalCandidateApiOrigin,
    this.enableSchedulerSelectionLeaseReleaseCandidate = false,
    this.schedulerSelectionLeaseReleaseCandidateApiOrigin,
    this.enableClientInstanceResourceViewCandidate = false,
    this.clientInstanceResourceViewCandidateApiOrigin,
    this.enableRunAttemptLeaseDispatchPreflightCandidate = false,
    this.runAttemptLeaseDispatchPreflightCandidateApiOrigin,
    this.enableRunnerDispatchPlanPreviewCandidate = false,
    this.runnerDispatchPlanPreviewCandidateApiOrigin,
    this.enableRunnerDispatchAdmissionCandidate = false,
    this.runnerDispatchAdmissionCandidateApiOrigin,
    this.enableRunnerTransportAdmissionCandidate = false,
    this.runnerTransportAdmissionCandidateApiOrigin,
    this.enableRunnerExecutionBoundaryCandidate = false,
    this.runnerExecutionBoundaryCandidateApiOrigin,
    this.enableClientInstanceSessionViewCandidate = false,
    this.clientInstanceSessionViewCandidateApiOrigin,
    this.enableClientInstanceSessionResourceConvergenceCandidate = false,
    this.clientInstanceSessionResourceConvergenceCandidateApiOrigin,
    this.enableLifecycleRegistryCandidate = false,
    this.lifecycleRegistryCandidateApiOrigin,
    this.enableDeviceCredentialCandidate = false,
    this.deviceCredentialCandidateApiOrigin,
  });
}
