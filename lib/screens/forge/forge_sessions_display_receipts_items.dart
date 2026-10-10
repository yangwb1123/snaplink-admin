part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayReceiptsItems on _ForgeSessionsScreenState {
  List<Widget> _receiptLoadingItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final runResourceVisible = display.selection.runResourceVisible;
    final requestMatchesSelectedRun =
        display.receipts.requestMatchesSelectedRun;
    return <Widget>[
      if (requestMatchesSelectedRun &&
          runResourceVisible &&
          _loadingDeviceObservation)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.runObservedReader != null &&
          _loadingRunObserved)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.runExecutionEvidenceReader != null &&
          _runExecutionEvidenceError != null)
        _errorCard(context, _runExecutionEvidenceError!, _signIn),
      if (runResourceVisible &&
          widget.runExecutionEvidenceReader != null &&
          _loadingRunExecutionEvidence)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.sessionRunnerReceiptHistoryReader != null &&
          _sessionRunnerReceiptHistoryError != null)
        _errorCard(context, _sessionRunnerReceiptHistoryError!, _signIn),
      if (runResourceVisible &&
          widget.sessionRunnerReceiptHistoryReader != null &&
          _loadingSessionRunnerReceiptHistory)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.sessionRunnerReconciliationProjectionReader != null &&
          _sessionRunnerReconciliationProjectionError != null)
        _errorCard(
          context,
          _sessionRunnerReconciliationProjectionError!,
          _signIn,
        ),
      if (runResourceVisible &&
          widget.sessionRunnerReconciliationProjectionReader != null &&
          _loadingSessionRunnerReconciliationProjection)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.executionReconciliationReader != null &&
          _executionReconciliationError != null)
        _errorCard(context, _executionReconciliationError!, _signIn),
      if (runResourceVisible &&
          widget.executionReconciliationReader != null &&
          _loadingExecutionReconciliation)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
    ];
  }

  List<Widget> _runBindingsItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final runResourceVisible = display.selection.runResourceVisible;
    final observation = display.receipts.observation;
    final displayRunIntentObservation =
        display.receipts.displayRunIntentObservation;
    final displayRunnerExecutionIntentObservation =
        display.receipts.displayRunnerExecutionIntentObservation;
    final attemptRequestPreview = display.receipts.attemptRequestPreview;
    final pendingRunIntentPreview = display.receipts.pendingRunIntentPreview;
    final displaySessionRunnerReceiptObservation =
        display.receipts.displaySessionRunnerReceiptObservation;
    final displaySessionRunnerReceiptHistory =
        display.receipts.displaySessionRunnerReceiptHistory;
    final displaySessionRunnerReconciliationProjection =
        display.receipts.displaySessionRunnerReconciliationProjection;
    final displayExecutionReconciliationObservation =
        display.receipts.displayExecutionReconciliationObservation;
    final displayRunExecutionEvidence =
        display.receipts.displayRunExecutionEvidence;
    final displayRunObserved = display.receipts.displayRunObserved;
    return <Widget>[
      if (observation != null)
        ForgeSessionDeviceObservationPanel(observation: observation),
      if (displayRunIntentObservation != null)
        ForgeRunIntentObservationCard(observation: displayRunIntentObservation),
      if (displayRunnerExecutionIntentObservation != null)
        ForgeRunnerExecutionIntentCard(
          observation: displayRunnerExecutionIntentObservation,
        ),
      if (runResourceVisible &&
          widget.runnerExecutionIntentReader != null &&
          _runnerExecutionIntentError != null)
        _errorCard(context, _runnerExecutionIntentError!, _signIn),
      if (runResourceVisible &&
          widget.runnerExecutionIntentReader != null &&
          _loadingRunnerExecutionIntent)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (displaySessionRunnerReceiptObservation != null)
        ForgeSessionRunnerReceiptObservationCard(
          observation: displaySessionRunnerReceiptObservation,
        ),
      if (displaySessionRunnerReceiptHistory != null)
        Padding(
          key: const ValueKey(
            'forge-session-runner-receipt-history-remote-panel',
          ),
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSessionRunnerReceiptHistoryPanel(
            history: displaySessionRunnerReceiptHistory,
          ),
        ),
      if (displaySessionRunnerReconciliationProjection != null)
        Padding(
          key: const ValueKey(
            'forge-session-runner-reconciliation-projection-remote-panel',
          ),
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSessionRunnerReconciliationProjectionPanel(
            projection: displaySessionRunnerReconciliationProjection,
          ),
        ),
      if (displayExecutionReconciliationObservation != null)
        ForgeExecutionReconciliationObservationCard(
          observation: displayExecutionReconciliationObservation,
        ),
      if (displayRunExecutionEvidence != null)
        ForgeRunExecutionEvidenceCard(evidence: displayRunExecutionEvidence),
      if (displayRunObserved != null)
        ForgeRunObservedCard(observation: displayRunObserved),
      if (attemptRequestPreview != null)
        ForgeAttemptRequestPreviewCard(fixture: attemptRequestPreview),
      if (pendingRunIntentPreview != null)
        ForgePendingRunIntentCard(fixture: pendingRunIntentPreview),
    ];
  }
}
