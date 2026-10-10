part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenPrivateSelectionReset
    on _ForgeSessionsScreenState {
  void _clearConversationDetails({bool clearOwnerObservations = true}) {
    _promptGeneration++;
    _runGeneration++;
    _runTimelineGeneration++;
    _clearDeviceObservation();
    if (clearOwnerObservations) {
      // Inventory and registry placement are owner-scoped screen resources,
      // rather than Conversation details. A local client-instance filter can
      // change the selected Conversation without invalidating these images;
      // sign-out, authorization failure, and route reset keep the default
      // clearing behavior.
      _clearDeviceInventory();
      _clearDeviceInventoryV2();
      _clearDeviceInventoryRegistryPlacementPreview();
    }
    _clearSchedulerSelectionPreview();
    // Client-instance/resource and client-instance/session observations are
    // owner-level projections for the whole screen, not Conversation detail.
    // Keep them mounted while switching Conversations so an instance filter
    // remains available when it selects a different visible session.
    _clearDeviceCredentialCandidate();
    _clearRunAttemptLeaseDispatchPreflight();
    _clearRunnerDispatchPlanPreview();
    _clearRunnerAttemptBoundaryPreview();
    _clearRunnerAttemptBoundary();
    _clearRunnerExecutionIntent();
    _clearRunnerDispatchAdmission();
    _clearExecutionReconciliation();
    _clearExecutionConsentPreview();
    _clearRunObserved();
    _clearRunExecutionEvidence();
    _clearSessionRunnerReceiptHistory();
    _clearSessionRunnerReconciliationProjection();
    _clearPendingRunIntents();
    _pendingRunIntentSubmission = null;
    _pendingRunIntentRequest = null;
    _pendingRunIntentSubmitError = null;
    _submittingPendingRunIntent = false;
    _pendingPrompt = null;
    _appendError = null;
    _appending = false;
    _clearImportedRunObservations();
    _prompts = const [];
    _promptCursor = null;
    _hasMorePrompts = false;
    _promptError = null;
    _loadingPrompts = false;
    _runs = const [];
    _runCursor = null;
    _hasMoreRuns = false;
    _selectedRun = null;
    _runEvents = const [];
    _runTimelineSequence = 0;
    _hasMoreRunEvents = false;
    _loadingRuns = false;
    _loadingRunTimeline = false;
  }

  /// Clears Run and Run-adjacent metadata when the selected local
  /// client-instance projection no longer declares the Conversation. The
  /// owner session itself remains selected so the caller can reselect it when
  /// the projection changes; no private Run request is allowed in the gap.
  void _clearRunDetailsForHiddenClientInstance() {
    _clientInstanceFilterNeedsPrivateReload = true;
    _promptGeneration++;
    _runGeneration++;
    _runTimelineGeneration++;
    _clearDeviceObservation();
    _clearRunAttemptLeaseDispatchPreflight();
    _clearSchedulerSelectionPreview();
    _clearRunnerDispatchPlanPreview();
    _clearRunnerAttemptBoundaryPreview();
    _clearRunnerAttemptBoundary();
    _clearRunnerExecutionIntent();
    _clearRunnerDispatchAdmission();
    _clearLocalRunnerPreview();
    _clearExecutionReconciliation();
    _clearRunObserved();
    _clearRunExecutionEvidence();
    _clearSessionRunnerReceiptHistory();
    _clearSessionRunnerReconciliationProjection();
    _clearExecutionConsentPreview();
    _clearPendingRunIntents();
    _pendingRunIntentSubmission = null;
    _pendingRunIntentRequest = null;
    _pendingRunIntentSubmitError = null;
    _submittingPendingRunIntent = false;
    _pendingPrompt = null;
    _appendError = null;
    _appending = false;
    _clearImportedRunObservations();
    _prompts = const [];
    _promptCursor = null;
    _hasMorePrompts = false;
    _promptError = null;
    _loadingPrompts = false;
    _runs = const [];
    _runCursor = null;
    _hasMoreRuns = false;
    _selectedRun = null;
    _runEvents = const [];
    _runTimelineSequence = 0;
    _hasMoreRunEvents = false;
    _runError = null;
    _runTimelineError = null;
    _loadingRuns = false;
    _loadingRunTimeline = false;
  }

  /// Imported Runner observations are scoped to the currently selected Run.
  /// They stay process-local and must not reappear when navigation changes
  /// the Conversation or clears the selection.
  void _clearImportedRunObservations() {
    _importedRunnerExecutionIntentObservation = null;
    _importedSessionRunnerReceiptObservation = null;
  }
}
