part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayReceipts on _ForgeSessionsScreenState {
  _ForgeSessionReceiptDisplay _projectReceipts(
    _ForgeSessionInputs inputs,
    _ForgeSessionSelection selection,
    _ForgeSessionRunnerDisplay runner,
  ) {
    final selectedConversationID = inputs.selectedConversationID;
    final selectedRunID = inputs.selectedRunID;
    final staticObservation = inputs.staticObservation;
    final runIntentObservation = inputs.runIntentObservation;
    final runnerExecutionIntentObservation =
        inputs.runnerExecutionIntentObservation;
    final runObserved = inputs.runObserved;
    final fetchedRunObserved = inputs.fetchedRunObserved;
    final runExecutionEvidence = inputs.runExecutionEvidence;
    final fetchedSessionRunnerReconciliationProjection =
        inputs.fetchedSessionRunnerReconciliationProjection;
    final selectedConversationVisible = selection.selectedConversationVisible;
    final runResourceVisible = selection.runResourceVisible;
    final fetchedSessionRunnerReceiptHistory =
        runner.fetchedSessionRunnerReceiptHistory;
    final observation = !runResourceVisible
        ? null
        : staticObservation?.isFor(
                selectedConversationID ?? '',
                selectedRunID ?? '',
              ) ==
              true
        ? staticObservation
        : _fetchedDeviceObservation?.isFor(
                selectedConversationID ?? '',
                selectedRunID ?? '',
              ) ==
              true
        ? _fetchedDeviceObservation
        : _importedDeviceObservation?.isFor(
                selectedConversationID ?? '',
                selectedRunID ?? '',
              ) ==
              true
        ? _importedDeviceObservation
        : null;
    final displayRunIntentObservation = !runResourceVisible
        ? null
        : runIntentObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              runIntentObservation!.isDisplayOnly
        ? runIntentObservation
        : null;
    final displayRunnerExecutionIntentObservation = !runResourceVisible
        ? null
        : runnerExecutionIntentObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              runnerExecutionIntentObservation!.isDisplayOnly
        ? runnerExecutionIntentObservation
        : _importedRunnerExecutionIntentObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              _importedRunnerExecutionIntentObservation!.isDisplayOnly
        ? _importedRunnerExecutionIntentObservation
        : null;
    final sessionRunnerReceiptObservation = runResourceVisible
        ? widget.sessionRunnerReceiptObservationReader != null
              ? _fetchedSessionRunnerReceiptObservation
              : _fetchedSessionRunnerReceiptObservation ??
                    widget.sessionRunnerReceiptObservation
        : null;
    final executionReconciliationObservation = !runResourceVisible
        ? null
        : _strictExecutionReconciliationObservation(
                widget.executionReconciliationObservation,
              ) ??
              _strictExecutionReconciliationObservation(
                _fetchedExecutionReconciliationObservation,
              );
    final executionConsentPreview = selectedConversationVisible
        ? _strictExecutionConsentPreview(
            _fetchedExecutionConsentPreview,
            selectedConversationID ?? '',
          )
        : null;
    final attemptRequestPreview = runResourceVisible
        ? widget.attemptRequestPreview
        : null;
    final pendingRunIntentPreview = selectedConversationVisible
        ? widget.pendingRunIntentPreview
        : null;
    final pendingRunIntentReader = widget.pendingRunIntentReader;
    final pendingRunIntentPageReader = widget.pendingRunIntentPageReader;
    final displaySessionRunnerReceiptObservation = !runResourceVisible
        ? null
        : sessionRunnerReceiptObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              sessionRunnerReceiptObservation!.isDisplayOnly
        ? sessionRunnerReceiptObservation
        : _importedSessionRunnerReceiptObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              _importedSessionRunnerReceiptObservation!.isDisplayOnly
        ? _importedSessionRunnerReceiptObservation
        : null;
    final displaySessionRunnerReceiptHistory = !runResourceVisible
        ? null
        : fetchedSessionRunnerReceiptHistory?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              fetchedSessionRunnerReceiptHistory!.isDisplayOnly
        ? fetchedSessionRunnerReceiptHistory
        : null;
    final displaySessionRunnerReconciliationProjection = !runResourceVisible
        ? null
        : fetchedSessionRunnerReconciliationProjection?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              fetchedSessionRunnerReconciliationProjection!.isDisplayOnly
        ? fetchedSessionRunnerReconciliationProjection
        : null;
    final displayExecutionReconciliationObservation = !runResourceVisible
        ? null
        : executionReconciliationObservation?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              executionReconciliationObservation!.isDisplayOnly
        ? executionReconciliationObservation
        : null;
    final displayRunExecutionEvidence = !runResourceVisible
        ? null
        : runExecutionEvidence?.isFor(
                    selectedConversationID ?? '',
                    selectedRunID ?? '',
                  ) ==
                  true &&
              runExecutionEvidence!.isDisplayOnly
        ? runExecutionEvidence
        : null;
    ForgeRunObserved? displayRunObserved;
    for (final candidate
        in runResourceVisible
            ? widget.sessionRunnerReceiptObservationReader != null
                  ? <ForgeRunObserved?>[fetchedRunObserved]
                  : <ForgeRunObserved?>[fetchedRunObserved, runObserved]
            : const <ForgeRunObserved?>[]) {
      if (candidate?.isFor(selectedConversationID ?? '', selectedRunID ?? '') ==
              true &&
          candidate!.isDisplayOnly) {
        displayRunObserved = candidate;
        break;
      }
    }
    final requestMatchesSelectedRun =
        widget.deviceObservationRequest != null &&
        widget.deviceObservationRequest!.conversationID ==
            selectedConversationID &&
        widget.deviceObservationRequest!.runID == selectedRunID;
    return (
      observation: observation,
      displayRunIntentObservation: displayRunIntentObservation,
      displayRunnerExecutionIntentObservation:
          displayRunnerExecutionIntentObservation,
      executionConsentPreview: executionConsentPreview,
      attemptRequestPreview: attemptRequestPreview,
      pendingRunIntentPreview: pendingRunIntentPreview,
      pendingRunIntentReader: pendingRunIntentReader,
      pendingRunIntentPageReader: pendingRunIntentPageReader,
      displaySessionRunnerReceiptObservation:
          displaySessionRunnerReceiptObservation,
      displaySessionRunnerReceiptHistory: displaySessionRunnerReceiptHistory,
      displaySessionRunnerReconciliationProjection:
          displaySessionRunnerReconciliationProjection,
      displayExecutionReconciliationObservation:
          displayExecutionReconciliationObservation,
      displayRunExecutionEvidence: displayRunExecutionEvidence,
      displayRunObserved: displayRunObserved,
      requestMatchesSelectedRun: requestMatchesSelectedRun,
    );
  }
}
