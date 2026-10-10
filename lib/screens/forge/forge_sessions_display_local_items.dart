part of 'forge_sessions_screen.dart';

extension _ForgeSessionsDisplayLocalItems on _ForgeSessionsScreenState {
  List<Widget> _localPreviewsItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final clientInstanceSessionView = display.inputs.clientInstanceSessionView;
    final clientInstanceResourceView =
        display.inputs.clientInstanceResourceView;
    final executionLeaseCheckpoint = display.inputs.executionLeaseCheckpoint;
    final sessionRunnerReceiptVectors =
        display.inputs.sessionRunnerReceiptVectors;
    final sessionRunnerReceiptHistory =
        display.inputs.sessionRunnerReceiptHistory;
    final sessionRunnerReconciliationProjection =
        display.inputs.sessionRunnerReconciliationProjection;
    final lifecycleRegistry = display.inputs.lifecycleRegistry;
    final deviceCredentialCandidate = display.inputs.deviceCredentialCandidate;
    final registryPlacementPreview = display.inputs.registryPlacementPreview;
    return <Widget>[
      if (_runnerLeaseFencingPreview != null)
        ForgeRunnerLeaseFencingPreviewCard(
          fixture: _runnerLeaseFencingPreview!,
        ),
      if (executionLeaseCheckpoint != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeExecutionLeaseCheckpointPreviewCard(
            fixture: executionLeaseCheckpoint,
          ),
        ),
      if (sessionRunnerReceiptVectors != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSessionRunnerReceiptVectorsPanel(
            fixture: sessionRunnerReceiptVectors,
          ),
        ),
      if (sessionRunnerReceiptHistory != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSessionRunnerReceiptHistoryPanel(
            history: sessionRunnerReceiptHistory,
          ),
        ),
      if (sessionRunnerReconciliationProjection != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSessionRunnerReconciliationProjectionPanel(
            projection: sessionRunnerReconciliationProjection,
          ),
        ),
      if (clientInstanceSessionView != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeClientInstanceSessionViewPanel(
            fixture: clientInstanceSessionView,
          ),
        ),
      if (clientInstanceResourceView != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeClientInstanceResourceViewPanel(
            fixture: clientInstanceResourceView,
          ),
        ),
      if (lifecycleRegistry != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeLifecycleRegistryPanel(registry: lifecycleRegistry),
        ),
      if (deviceCredentialCandidate != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeDeviceCredentialCandidatePanel(
            candidate: deviceCredentialCandidate,
          ),
        ),
      if (registryPlacementPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeDeviceRegistryPlacementPreviewPanel(
            preview: registryPlacementPreview,
          ),
        ),
    ];
  }

  List<Widget> _schedulerItems(
    BuildContext context,
    _ForgeSessionDisplay display,
  ) {
    final schedulerSelectionPreview =
        display.selection.schedulerSelectionPreview;
    final schedulerSelectionLease = display.selection.schedulerSelectionLease;
    final schedulerSelectionLeaseRelease =
        display.selection.schedulerSelectionLeaseRelease;
    final clientInstanceFilterInstances =
        display.selection.clientInstanceFilterInstances;
    final clientInstanceProjectionInvalid =
        display.selection.clientInstanceProjectionInvalid;
    final selectedClientInstanceID = display.selection.selectedClientInstanceID;
    return <Widget>[
      if (schedulerSelectionPreview != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSchedulerSelectionPreviewPanel(
            preview: schedulerSelectionPreview,
          ),
        ),
      if (schedulerSelectionLease != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSchedulerSelectionLeasePanel(
            lease: schedulerSelectionLease,
          ),
        ),
      if (schedulerSelectionLeaseRelease != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: ForgeSchedulerSelectionLeaseReleasePanel(
            release: schedulerSelectionLeaseRelease,
          ),
        ),
      if (clientInstanceProjectionInvalid ||
          (clientInstanceFilterInstances != null &&
              clientInstanceFilterInstances.isNotEmpty))
        _clientInstanceSessionFilter(
          context,
          clientInstanceFilterInstances ??
              const <ForgeClientInstanceSessionViewInstance>[],
          selectedClientInstanceID,
        ),
    ];
  }
}
