part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayNoticesItems on _ForgeSessionsScreenState {
  List<Widget> _operationNoticesItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final runResourceVisible = display.selection.runResourceVisible;
    return <Widget>[
      if (_signOutError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            context.tr(_signOutError!),
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      if (_runnerLeaseFencingError != null)
        _errorCard(context, _runnerLeaseFencingError!, _signIn),
      if (_executionLeaseCheckpointError != null)
        _errorCard(context, _executionLeaseCheckpointError!, _signIn),
      if (_sessionRunnerReceiptVectorsPreviewError != null)
        _errorCard(context, _sessionRunnerReceiptVectorsPreviewError!, _signIn),
      if (_sessionRunnerReceiptHistoryPreviewError != null)
        _errorCard(context, _sessionRunnerReceiptHistoryPreviewError!, _signIn),
      if (_sessionRunnerReconciliationProjectionPreviewError != null)
        _errorCard(
          context,
          _sessionRunnerReconciliationProjectionPreviewError!,
          _signIn,
        ),
      if (_runnerAttemptBoundaryPreviewError != null)
        _errorCard(context, _runnerAttemptBoundaryPreviewError!, _signIn),
      if (runResourceVisible && _runnerAttemptBoundaryError != null)
        _errorCard(context, _runnerAttemptBoundaryError!, _signIn),
      if (_deviceInventoryV2PreviewError != null)
        _errorCard(context, _deviceInventoryV2PreviewError!, _signIn),
      if (_deviceInventoryResourceConvergenceError != null)
        _errorCard(context, _deviceInventoryResourceConvergenceError!, _signIn),
      if (_deviceResourceSummaryPreviewError != null)
        _errorCard(context, _deviceResourceSummaryPreviewError!, _signIn),
      if (_clientInstanceResourceViewPreviewError != null)
        _errorCard(context, _clientInstanceResourceViewPreviewError!, _signIn),
      if (_clientInstanceSessionViewPreviewError != null)
        _errorCard(context, _clientInstanceSessionViewPreviewError!, _signIn),
      if (_deviceInventoryPlacementEvaluationV2PreviewError != null)
        _errorCard(
          context,
          _deviceInventoryPlacementEvaluationV2PreviewError!,
          _signIn,
        ),
      if (_deviceInventoryPlacementEvaluationPreviewError != null)
        _errorCard(
          context,
          _deviceInventoryPlacementEvaluationPreviewError!,
          _signIn,
        ),
      if (_deviceInventoryPlacementBatchEvaluationPreviewError != null)
        _errorCard(
          context,
          _deviceInventoryPlacementBatchEvaluationPreviewError!,
          _signIn,
        ),
    ];
  }

  List<Widget> _readErrorsItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final schedulerSelectionLeaseCandidateEnabled =
        display.inputs.schedulerSelectionLeaseCandidateEnabled;
    final schedulerSelectionLeaseReleaseCandidateEnabled =
        display.inputs.schedulerSelectionLeaseReleaseCandidateEnabled;
    final selectedConversationVisible =
        display.selection.selectedConversationVisible;
    final runResourceVisible = display.selection.runResourceVisible;
    return <Widget>[
      _createCard(context),
      if (_conversationError != null)
        _errorCard(context, _conversationError!, _signIn),
      if (_changeError != null) _errorCard(context, _changeError!, _signIn),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryReader != null &&
          _deviceInventoryError != null)
        _errorCard(context, _deviceInventoryError!, _signIn),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryV2Reader != null &&
          _deviceInventoryV2Error != null)
        _errorCard(context, _deviceInventoryV2Error!, _signIn),
      if (widget.deviceInventoryResourceConvergenceOwner != null &&
          widget.deviceInventoryResourceConvergenceReader != null &&
          _deviceInventoryResourceConvergenceError != null)
        _errorCard(context, _deviceInventoryResourceConvergenceError!, _signIn),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryRegistryPlacementRequirements != null &&
          widget.deviceInventoryRegistryPlacementPreviewReader != null &&
          _deviceInventoryRegistryPlacementPreviewError != null)
        _errorCard(
          context,
          _deviceInventoryRegistryPlacementPreviewError!,
          _signIn,
        ),
      if (widget.schedulerSelectionPreviewRequest != null &&
          widget.schedulerSelectionPreviewReader != null &&
          _schedulerSelectionPreviewError != null)
        _errorCard(context, _schedulerSelectionPreviewError!, _signIn),
      if (schedulerSelectionLeaseCandidateEnabled &&
          _schedulerSelectionLeaseError != null)
        _errorCard(context, _schedulerSelectionLeaseError!, _signIn),
      if (schedulerSelectionLeaseReleaseCandidateEnabled &&
          _schedulerSelectionLeaseReleaseError != null)
        _errorCard(context, _schedulerSelectionLeaseReleaseError!, _signIn),
      if (widget.clientInstanceResourceViewOwner != null &&
          widget.clientInstanceResourceViewReader != null &&
          _clientInstanceResourceViewError != null)
        _errorCard(context, _clientInstanceResourceViewError!, _signIn),
      if (widget.clientInstanceSessionViewOwner != null &&
          widget.clientInstanceSessionViewReader != null &&
          _clientInstanceSessionViewError != null)
        _errorCard(context, _clientInstanceSessionViewError!, _signIn),
      if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
          widget.clientInstanceSessionResourceConvergenceReader != null &&
          _clientInstanceSessionResourceConvergenceError != null)
        _errorCard(
          context,
          _clientInstanceSessionResourceConvergenceError!,
          _signIn,
        ),
      if (widget.lifecycleRegistryOwner != null &&
          widget.lifecycleRegistryReader != null &&
          _lifecycleRegistryError != null)
        _errorCard(context, _lifecycleRegistryError!, _signIn),
      if (widget.deviceCredentialCandidateOwner != null &&
          widget.deviceCredentialCandidateRequest != null &&
          widget.deviceCredentialCandidateReader != null &&
          _deviceCredentialCandidateError != null)
        _errorCard(context, _deviceCredentialCandidateError!, _signIn),
      if (runResourceVisible &&
          widget.runAttemptLeaseDispatchPreflightRequest != null &&
          widget.runAttemptLeaseDispatchPreflightReader != null &&
          _runAttemptLeaseDispatchPreflightError != null)
        _errorCard(context, _runAttemptLeaseDispatchPreflightError!, _signIn),
      if (runResourceVisible &&
          widget.runnerDispatchPlanPreviewRequest != null &&
          widget.runnerDispatchPlanPreviewReader != null &&
          _runnerDispatchPlanPreviewError != null)
        _errorCard(context, _runnerDispatchPlanPreviewError!, _signIn),
      if (runResourceVisible &&
          widget.runnerDispatchAdmissionRequest != null &&
          widget.runnerDispatchAdmissionReader != null &&
          _runnerDispatchAdmissionError != null)
        _errorCard(context, _runnerDispatchAdmissionError!, _signIn),
      if (runResourceVisible &&
          widget.runnerTransportAdmissionRequest != null &&
          widget.runnerTransportAdmissionReader != null &&
          _runnerTransportAdmissionError != null)
        _errorCard(context, _runnerTransportAdmissionError!, _signIn),
      if (runResourceVisible &&
          widget.runnerExecutionBoundaryRequest != null &&
          widget.runnerExecutionBoundaryReader != null &&
          _runnerExecutionBoundaryError != null)
        _errorCard(context, _runnerExecutionBoundaryError!, _signIn),
      if (runResourceVisible &&
          widget.localRunnerPreviewRequest != null &&
          widget.localRunnerPreviewReader != null &&
          _localRunnerPreviewError != null)
        _errorCard(context, _localRunnerPreviewError!, _signIn),
      if (runResourceVisible &&
          widget.runObservedReader != null &&
          _runObservedError != null)
        _errorCard(context, _runObservedError!, _signIn),
      if (selectedConversationVisible &&
          widget.executionConsentPreviewOwner != null &&
          widget.executionConsentPreviewReader != null &&
          _executionConsentPreviewError != null)
        _errorCard(context, _executionConsentPreviewError!, _signIn),
    ];
  }
}
