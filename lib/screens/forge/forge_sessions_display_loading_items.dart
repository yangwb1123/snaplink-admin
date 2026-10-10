part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayLoadingItems on _ForgeSessionsScreenState {
  List<Widget> _staleReadsItems(
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
    final requestMatchesSelectedRun =
        display.receipts.requestMatchesSelectedRun;
    return <Widget>[
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryReader != null &&
          _deviceInventoryStale)
        _staleDeviceInventoryCard(context),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryV2Reader != null &&
          _deviceInventoryV2Stale)
        _staleDeviceInventoryV2Card(context),
      if (widget.deviceInventoryResourceConvergenceOwner != null &&
          widget.deviceInventoryResourceConvergenceReader != null &&
          _deviceInventoryResourceConvergenceStale)
        _staleDeviceInventoryResourceConvergenceCard(context),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryRegistryPlacementRequirements != null &&
          widget.deviceInventoryRegistryPlacementPreviewReader != null &&
          _deviceInventoryRegistryPlacementPreviewStale)
        _staleRegistryPlacementPreviewCard(context),
      if (widget.schedulerSelectionPreviewRequest != null &&
          widget.schedulerSelectionPreviewReader != null &&
          _schedulerSelectionPreviewStale)
        _staleSchedulerSelectionPreviewCard(context),
      if (schedulerSelectionLeaseCandidateEnabled &&
          _schedulerSelectionLeaseStale)
        _staleSchedulerSelectionLeaseCard(context),
      if (schedulerSelectionLeaseReleaseCandidateEnabled &&
          _schedulerSelectionLeaseReleaseStale)
        _staleSchedulerSelectionLeaseReleaseCard(context),
      if (widget.clientInstanceResourceViewOwner != null &&
          widget.clientInstanceResourceViewReader != null &&
          _clientInstanceResourceViewStale)
        _staleClientInstanceResourceViewCard(context),
      if (widget.clientInstanceSessionViewOwner != null &&
          widget.clientInstanceSessionViewReader != null &&
          _clientInstanceSessionViewStale)
        _staleClientInstanceSessionViewCard(context),
      if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
          widget.clientInstanceSessionResourceConvergenceReader != null &&
          _clientInstanceSessionResourceConvergenceStale)
        _staleClientInstanceSessionResourceConvergenceCard(context),
      if (widget.lifecycleRegistryOwner != null &&
          widget.lifecycleRegistryReader != null &&
          _lifecycleRegistryStale)
        _staleLifecycleRegistryCard(context),
      if (widget.deviceCredentialCandidateOwner != null &&
          widget.deviceCredentialCandidateRequest != null &&
          widget.deviceCredentialCandidateReader != null &&
          _deviceCredentialCandidateStale)
        _staleDeviceCredentialCandidateCard(context),
      if (runResourceVisible &&
          widget.runAttemptLeaseDispatchPreflightRequest != null &&
          widget.runAttemptLeaseDispatchPreflightReader != null &&
          _runAttemptLeaseDispatchPreflightStale)
        _staleRunAttemptLeaseDispatchPreflightCard(context),
      if (runResourceVisible &&
          widget.runnerDispatchPlanPreviewRequest != null &&
          widget.runnerDispatchPlanPreviewReader != null &&
          _runnerDispatchPlanPreviewStale)
        _staleRunnerDispatchPlanPreviewCard(context),
      if (runResourceVisible &&
          widget.runnerDispatchAdmissionRequest != null &&
          widget.runnerDispatchAdmissionReader != null &&
          _runnerDispatchAdmissionStale)
        _staleRunnerDispatchAdmissionCard(context),
      if (runResourceVisible &&
          widget.runnerTransportAdmissionRequest != null &&
          widget.runnerTransportAdmissionReader != null &&
          _runnerTransportAdmissionStale)
        _staleRunnerTransportAdmissionCard(context),
      if (runResourceVisible &&
          widget.runnerExecutionBoundaryRequest != null &&
          widget.runnerExecutionBoundaryReader != null &&
          _runnerExecutionBoundaryStale)
        _staleRunnerExecutionBoundaryCard(context),
      if (runResourceVisible &&
          widget.runnerAttemptBoundaryRequest != null &&
          widget.runnerAttemptBoundaryReader != null &&
          _runnerAttemptBoundaryStale)
        _staleRunnerAttemptBoundaryCard(context),
      if (runResourceVisible &&
          widget.localRunnerPreviewRequest != null &&
          widget.localRunnerPreviewReader != null &&
          _localRunnerPreviewStale)
        _staleLocalRunnerPreviewCard(context),
      if (runResourceVisible &&
          widget.runObservedReader != null &&
          _runObservedStale)
        _staleRunObservedCard(context),
      if (selectedConversationVisible &&
          widget.executionConsentPreviewOwner != null &&
          widget.executionConsentPreviewReader != null &&
          _executionConsentPreviewStale)
        _staleExecutionConsentPreviewCard(context),
      if (requestMatchesSelectedRun &&
          runResourceVisible &&
          _deviceObservationError != null)
        _errorCard(context, _deviceObservationError!, _signIn),
      if (_conversationsStale) _staleConversationsCard(context),
    ];
  }

  List<Widget> _loadingReadsItems(
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
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryReader != null &&
          _loadingDeviceInventory)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryV2Reader != null &&
          _loadingDeviceInventoryV2)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (widget.deviceInventoryOwner != null &&
          widget.deviceInventoryRegistryPlacementRequirements != null &&
          widget.deviceInventoryRegistryPlacementPreviewReader != null &&
          _loadingDeviceInventoryRegistryPlacementPreview)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (widget.schedulerSelectionPreviewRequest != null &&
          widget.schedulerSelectionPreviewReader != null &&
          _loadingSchedulerSelectionPreview)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (schedulerSelectionLeaseCandidateEnabled &&
          _loadingSchedulerSelectionLease)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (schedulerSelectionLeaseReleaseCandidateEnabled &&
          _loadingSchedulerSelectionLeaseRelease)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (widget.clientInstanceResourceViewOwner != null &&
          widget.clientInstanceResourceViewReader != null &&
          _loadingClientInstanceResourceView)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (widget.clientInstanceSessionViewOwner != null &&
          widget.clientInstanceSessionViewReader != null &&
          _loadingClientInstanceSessionView)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (widget.clientInstanceSessionResourceConvergenceOwner != null &&
          widget.clientInstanceSessionResourceConvergenceReader != null &&
          _loadingClientInstanceSessionResourceConvergence)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (widget.lifecycleRegistryOwner != null &&
          widget.lifecycleRegistryReader != null &&
          _loadingLifecycleRegistry)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.runAttemptLeaseDispatchPreflightRequest != null &&
          widget.runAttemptLeaseDispatchPreflightReader != null &&
          _loadingRunAttemptLeaseDispatchPreflight)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.runnerDispatchPlanPreviewRequest != null &&
          widget.runnerDispatchPlanPreviewReader != null &&
          _loadingRunnerDispatchPlanPreview)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.runnerDispatchAdmissionRequest != null &&
          widget.runnerDispatchAdmissionReader != null &&
          _loadingRunnerDispatchAdmission)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.runnerTransportAdmissionRequest != null &&
          widget.runnerTransportAdmissionReader != null &&
          _loadingRunnerTransportAdmission)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (runResourceVisible &&
          widget.localRunnerPreviewRequest != null &&
          widget.localRunnerPreviewReader != null &&
          _loadingLocalRunnerPreview)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
      if (selectedConversationVisible &&
          widget.executionConsentPreviewOwner != null &&
          widget.executionConsentPreviewReader != null &&
          _loadingExecutionConsentPreview)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(),
        ),
    ];
  }
}
