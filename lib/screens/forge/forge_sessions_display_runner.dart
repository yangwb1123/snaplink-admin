part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayRunner on _ForgeSessionsScreenState {
  _ForgeSessionRunnerDisplay _projectRunner(
    _ForgeSessionInputs inputs,
    _ForgeSessionSelection selection,
  ) {
    final selectedConversationID = inputs.selectedConversationID;
    final selectedRunID = inputs.selectedRunID;
    final runResourceVisible = selection.runResourceVisible;
    final fetchedSessionRunnerReceiptHistory = runResourceVisible
        ? _safeSessionRunnerReceiptHistoryPreview(
            _fetchedSessionRunnerReceiptHistory,
          )
        : null;
    final staticRunAttemptLeaseDispatchPreflight = runResourceVisible
        ? _strictRunAttemptLeaseDispatchPreflight(
            widget.runAttemptLeaseDispatchPreflightPreview,
          )
        : null;
    final fetchedRunAttemptLeaseDispatchPreflight =
        _strictRunAttemptLeaseDispatchPreflight(
          _fetchedRunAttemptLeaseDispatchPreflight,
        );
    final runAttemptLeaseDispatchPreflight = !runResourceVisible
        ? null
        : staticRunAttemptLeaseDispatchPreflight ??
              (fetchedRunAttemptLeaseDispatchPreflight?.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                      ) ==
                      true
                  ? fetchedRunAttemptLeaseDispatchPreflight
                  : null);
    final staticRunnerDispatchPlanPreviewCandidate =
        _strictRunnerDispatchPlanPreview(
          runResourceVisible ? widget.runnerDispatchPlanPreview : null,
        );
    final staticRunnerDispatchPlanPreview =
        staticRunnerDispatchPlanPreviewCandidate != null &&
            _runnerDispatchPlanTargetsMatchResources(
              staticRunnerDispatchPlanPreviewCandidate,
            )
        ? staticRunnerDispatchPlanPreviewCandidate
        : null;
    final fetchedRunnerDispatchPlanPreviewCandidate =
        _strictRunnerDispatchPlanPreview(_fetchedRunnerDispatchPlanPreview);
    final fetchedRunnerDispatchPlanPreview =
        fetchedRunnerDispatchPlanPreviewCandidate != null &&
            _runnerDispatchPlanTargetsMatchResources(
              fetchedRunnerDispatchPlanPreviewCandidate,
            )
        ? fetchedRunnerDispatchPlanPreviewCandidate
        : null;
    final runnerDispatchPlanPreview = !runResourceVisible
        ? null
        : staticRunnerDispatchPlanPreview ??
              (fetchedRunnerDispatchPlanPreview?.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                      ) ==
                      true
                  ? fetchedRunnerDispatchPlanPreview
                  : null);
    final staticRunnerDispatchAdmissionCandidate = runResourceVisible
        ? _strictRunnerDispatchAdmission(widget.runnerDispatchAdmission)
        : null;
    final staticRunnerDispatchAdmission =
        staticRunnerDispatchAdmissionCandidate != null &&
            selectedConversationID != null &&
            selectedRunID != null &&
            staticRunnerDispatchAdmissionCandidate.conversationID ==
                selectedConversationID &&
            staticRunnerDispatchAdmissionCandidate.runID == selectedRunID &&
            (widget.runnerDispatchAdmissionRequest == null ||
                staticRunnerDispatchAdmissionCandidate.attemptID ==
                    widget.runnerDispatchAdmissionRequest!.attemptID) &&
            _runnerAdmissionTargetMatchesResources(
              staticRunnerDispatchAdmissionCandidate.owner,
              staticRunnerDispatchAdmissionCandidate.targetID,
            )
        ? staticRunnerDispatchAdmissionCandidate
        : null;
    final fetchedRunnerDispatchAdmission = _strictRunnerDispatchAdmission(
      _fetchedRunnerDispatchAdmission,
    );
    final runnerDispatchAdmission = !runResourceVisible
        ? null
        : staticRunnerDispatchAdmission ??
              (fetchedRunnerDispatchAdmission != null &&
                      fetchedRunnerDispatchAdmission.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                        widget.runnerDispatchAdmissionRequest?.attemptID ?? '',
                      ) &&
                      _runnerAdmissionTargetMatchesResources(
                        fetchedRunnerDispatchAdmission.owner,
                        fetchedRunnerDispatchAdmission.targetID,
                      )
                  ? fetchedRunnerDispatchAdmission
                  : null);
    final staticRunnerTransportAdmissionCandidate = runResourceVisible
        ? _strictRunnerTransportAdmission(widget.runnerTransportAdmission)
        : null;
    final staticRunnerTransportAdmission =
        staticRunnerTransportAdmissionCandidate != null &&
            selectedConversationID != null &&
            selectedRunID != null &&
            staticRunnerTransportAdmissionCandidate.conversationID ==
                selectedConversationID &&
            staticRunnerTransportAdmissionCandidate.runID == selectedRunID &&
            (widget.runnerTransportAdmissionRequest == null ||
                staticRunnerTransportAdmissionCandidate.attemptID ==
                    widget.runnerTransportAdmissionRequest!.attemptID) &&
            _runnerAdmissionTargetMatchesResources(
              staticRunnerTransportAdmissionCandidate.owner,
              staticRunnerTransportAdmissionCandidate.targetID,
            )
        ? staticRunnerTransportAdmissionCandidate
        : null;
    final fetchedRunnerTransportAdmission = _strictRunnerTransportAdmission(
      _fetchedRunnerTransportAdmission,
    );
    final runnerTransportAdmission = !runResourceVisible
        ? null
        : staticRunnerTransportAdmission ??
              (fetchedRunnerTransportAdmission != null &&
                      fetchedRunnerTransportAdmission.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                        widget.runnerTransportAdmissionRequest?.attemptID ?? '',
                      ) &&
                      _runnerAdmissionTargetMatchesResources(
                        fetchedRunnerTransportAdmission.owner,
                        fetchedRunnerTransportAdmission.targetID,
                      )
                  ? fetchedRunnerTransportAdmission
                  : null);
    final staticRunnerExecutionBoundaryCandidate = runResourceVisible
        ? _strictRunnerExecutionBoundary(widget.runnerExecutionBoundary)
        : null;
    final staticRunnerExecutionBoundary =
        staticRunnerExecutionBoundaryCandidate != null &&
            _runnerAdmissionTargetMatchesResources(
              staticRunnerExecutionBoundaryCandidate.owner,
              staticRunnerExecutionBoundaryCandidate.targetID,
            )
        ? staticRunnerExecutionBoundaryCandidate
        : null;
    final fetchedRunnerExecutionBoundaryCandidate =
        _strictRunnerExecutionBoundary(_fetchedRunnerExecutionBoundary);
    final fetchedRunnerExecutionBoundary =
        fetchedRunnerExecutionBoundaryCandidate != null &&
            _runnerAdmissionTargetMatchesResources(
              fetchedRunnerExecutionBoundaryCandidate.owner,
              fetchedRunnerExecutionBoundaryCandidate.targetID,
            )
        ? fetchedRunnerExecutionBoundaryCandidate
        : null;
    final runnerExecutionBoundary = !runResourceVisible
        ? null
        : staticRunnerExecutionBoundary ??
              (fetchedRunnerExecutionBoundary?.isFor(
                        selectedConversationID ?? '',
                        selectedRunID ?? '',
                        widget.runnerExecutionBoundaryRequest?.attemptID ?? '',
                      ) ==
                      true
                  ? fetchedRunnerExecutionBoundary
                  : null);
    final staticRunnerAttemptBoundary = _strictRunnerAttemptBoundary(
      widget.runnerAttemptBoundaryPreview,
      selectedConversationID,
      selectedRunID,
    );
    final importedRunnerAttemptBoundary = _strictRunnerAttemptBoundary(
      _runnerAttemptBoundaryPreview,
      selectedConversationID,
      selectedRunID,
    );
    final fetchedRunnerAttemptBoundary = _strictFetchedRunnerAttemptBoundary(
      _fetchedRunnerAttemptBoundary,
      selectedConversationID,
      selectedRunID,
    );
    final runnerAttemptBoundary = !runResourceVisible
        ? null
        : staticRunnerAttemptBoundary ??
              importedRunnerAttemptBoundary ??
              fetchedRunnerAttemptBoundary;
    final staticLocalRunnerPreview = _strictLocalRunnerPreview(
      runResourceVisible ? widget.localRunnerPreview : null,
    );
    final fetchedLocalRunnerPreview = _strictLocalRunnerPreview(
      runResourceVisible ? _fetchedLocalRunnerPreview : null,
    );
    final localRunnerPreview =
        staticLocalRunnerPreview ?? fetchedLocalRunnerPreview;
    return (
      fetchedSessionRunnerReceiptHistory: fetchedSessionRunnerReceiptHistory,
      runAttemptLeaseDispatchPreflight: runAttemptLeaseDispatchPreflight,
      runnerDispatchPlanPreview: runnerDispatchPlanPreview,
      runnerDispatchAdmission: runnerDispatchAdmission,
      runnerTransportAdmission: runnerTransportAdmission,
      runnerExecutionBoundary: runnerExecutionBoundary,
      runnerAttemptBoundary: runnerAttemptBoundary,
      localRunnerPreview: localRunnerPreview,
    );
  }
}
