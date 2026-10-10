part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenApplyRunnerChanges on _ForgeSessionsScreenState {
  void _applyRunnerChanges(
    ForgeSessionsScreen oldWidget,
    _ForgeSessionsWidgetChanges changes,
  ) {
    final runAttemptLeaseDispatchPreflightChanged =
        changes.runAttemptLeaseDispatchPreflightChanged;
    final runnerDispatchPlanPreviewChanged =
        changes.runnerDispatchPlanPreviewChanged;
    final runnerExecutionIntentChanged = changes.runnerExecutionIntentChanged;
    final runnerDispatchAdmissionChanged =
        changes.runnerDispatchAdmissionChanged;
    final runnerTransportAdmissionChanged =
        changes.runnerTransportAdmissionChanged;
    final runnerExecutionBoundaryChanged =
        changes.runnerExecutionBoundaryChanged;
    final runnerAttemptBoundaryCandidateChanged =
        changes.runnerAttemptBoundaryCandidateChanged;
    final runnerAttemptBoundaryProjectionChanged =
        changes.runnerAttemptBoundaryProjectionChanged;
    final localRunnerPreviewChanged = changes.localRunnerPreviewChanged;
    final executionReconciliationChanged =
        changes.executionReconciliationChanged;
    final executionConsentPreviewChanged =
        changes.executionConsentPreviewChanged;
    if (runAttemptLeaseDispatchPreflightChanged) {
      _update(_clearRunAttemptLeaseDispatchPreflight);
      unawaited(_loadRunAttemptLeaseDispatchPreflightIfRequested());
    }
    if (runnerDispatchPlanPreviewChanged) {
      _update(_clearRunnerDispatchPlanPreview);
      unawaited(_loadRunnerDispatchPlanPreviewIfRequested());
    }
    if (runnerExecutionIntentChanged) {
      _update(_clearRunnerExecutionIntent);
      unawaited(_loadRunnerExecutionIntentIfRequested());
    }
    if (runnerDispatchAdmissionChanged) {
      _update(_clearRunnerDispatchAdmission);
      unawaited(_loadRunnerDispatchAdmissionIfRequested());
    }
    if (runnerTransportAdmissionChanged) {
      _update(_clearRunnerTransportAdmission);
      unawaited(_loadRunnerTransportAdmissionIfRequested());
    }
    if (runnerExecutionBoundaryChanged) {
      _update(_clearRunnerExecutionBoundary);
      unawaited(_loadRunnerExecutionBoundaryIfRequested());
    }
    if (runnerAttemptBoundaryCandidateChanged) {
      _update(_clearRunnerAttemptBoundary);
      unawaited(_loadRunnerAttemptBoundaryIfRequested());
    }
    if (runnerAttemptBoundaryProjectionChanged) {
      _update(() {
        _clearRunnerAttemptBoundaryPreview();
        _runnerAttemptBoundaryPreview = _safeRunnerAttemptBoundaryPreview(
          widget.runnerAttemptBoundaryPreview,
        );
      });
    }
    if (localRunnerPreviewChanged) {
      _update(_clearLocalRunnerPreview);
      unawaited(_loadLocalRunnerPreviewIfRequested());
    }
    if (executionReconciliationChanged) {
      _update(_clearExecutionReconciliation);
      unawaited(_loadExecutionReconciliationIfRequested());
    }
    if (executionConsentPreviewChanged) {
      _update(_clearExecutionConsentPreview);
      unawaited(_loadExecutionConsentPreviewIfRequested());
    }
  }
}
