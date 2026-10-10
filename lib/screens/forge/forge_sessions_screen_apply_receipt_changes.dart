part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenApplyReceiptChanges on _ForgeSessionsScreenState {
  void _applyReceiptChanges(
    ForgeSessionsScreen oldWidget,
    _ForgeSessionsWidgetChanges changes,
  ) {
    final clientInstanceResourceViewPreviewChanged =
        changes.clientInstanceResourceViewPreviewChanged;
    final clientInstanceSessionViewPreviewChanged =
        changes.clientInstanceSessionViewPreviewChanged;
    final runObservedReaderChanged = changes.runObservedReaderChanged;
    final runExecutionEvidenceChanged = changes.runExecutionEvidenceChanged;
    final sessionRunnerReceiptHistoryCandidateChanged =
        changes.sessionRunnerReceiptHistoryCandidateChanged;
    final sessionRunnerReconciliationProjectionCandidateChanged =
        changes.sessionRunnerReconciliationProjectionCandidateChanged;
    final pendingRunIntentChanged = changes.pendingRunIntentChanged;
    if (runObservedReaderChanged) {
      _update(_clearRunObserved);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadRunObservedIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (runExecutionEvidenceChanged) {
      _update(_clearRunExecutionEvidence);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadRunExecutionEvidenceIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (sessionRunnerReceiptHistoryCandidateChanged) {
      _update(_clearSessionRunnerReceiptHistory);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadSessionRunnerReceiptHistoryIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (sessionRunnerReconciliationProjectionCandidateChanged) {
      _update(_clearSessionRunnerReconciliationProjection);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(
          _loadSessionRunnerReconciliationProjectionIfRequested(
            conversationID: conversationID,
            runID: runID,
          ),
        );
      }
    }
    if (pendingRunIntentChanged) {
      _update(_clearPendingRunIntents);
      unawaited(_loadPendingRunIntentsIfRequested());
    }
    if (clientInstanceResourceViewPreviewChanged ||
        clientInstanceSessionViewPreviewChanged) {
      _reconcileSelectedClientInstanceProjection();
    }
  }
}
