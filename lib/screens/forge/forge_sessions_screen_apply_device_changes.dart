part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenApplyDeviceChanges on _ForgeSessionsScreenState {
  void _applyDeviceChanges(
    ForgeSessionsScreen oldWidget,
    _ForgeSessionsWidgetChanges changes,
  ) {
    final deviceObservationChanged = changes.deviceObservationChanged;
    final deviceInventoryChanged = changes.deviceInventoryChanged;
    final deviceInventoryV2Changed = changes.deviceInventoryV2Changed;
    final deviceInventoryResourceConvergenceChanged =
        changes.deviceInventoryResourceConvergenceChanged;
    final deviceInventoryRegistryPlacementPreviewChanged =
        changes.deviceInventoryRegistryPlacementPreviewChanged;
    final schedulerSelectionPreviewChanged =
        changes.schedulerSelectionPreviewChanged;
    final schedulerSelectionLeaseChanged =
        changes.schedulerSelectionLeaseChanged;
    final schedulerSelectionLeaseReleaseChanged =
        changes.schedulerSelectionLeaseReleaseChanged;
    final clientInstanceResourceViewChanged =
        changes.clientInstanceResourceViewChanged;
    final clientInstanceSessionViewChanged =
        changes.clientInstanceSessionViewChanged;
    final clientInstanceSessionResourceConvergenceChanged =
        changes.clientInstanceSessionResourceConvergenceChanged;
    final lifecycleRegistryChanged = changes.lifecycleRegistryChanged;
    final deviceCredentialCandidateChanged =
        changes.deviceCredentialCandidateChanged;
    if (deviceObservationChanged) {
      // A parent can replace the caller-supplied declaration while keeping
      // this screen mounted (for example, after a Web/App/Mobile preview
      // completes). Drop the previous response before evaluating the new
      // request so a changed declaration cannot be shown as if it were still
      // current.
      _update(_clearDeviceObservation);
      final conversationID = _selected?.conversation.id;
      final runID = _selectedRun?.runID;
      if (conversationID != null && runID != null) {
        unawaited(_loadDeviceObservationIfRequested(conversationID, runID));
      }
    }
    if (deviceInventoryChanged) {
      _update(_clearDeviceInventory);
      unawaited(_loadDeviceInventoryIfRequested());
    }
    if (deviceInventoryV2Changed) {
      _update(_clearDeviceInventoryV2);
      unawaited(_loadDeviceInventoryV2IfRequested());
    }
    if (deviceInventoryResourceConvergenceChanged) {
      _update(_clearDeviceInventoryResourceConvergence);
      unawaited(_loadDeviceInventoryResourceConvergenceIfRequested());
    }
    if (deviceInventoryRegistryPlacementPreviewChanged) {
      _update(_clearDeviceInventoryRegistryPlacementPreview);
      unawaited(_loadDeviceInventoryRegistryPlacementPreviewIfRequested());
    }
    if (schedulerSelectionPreviewChanged) {
      _update(_clearSchedulerSelectionPreview);
      unawaited(_loadSchedulerSelectionPreviewIfRequested());
    }
    if (schedulerSelectionLeaseChanged) {
      _update(_clearSchedulerSelectionLease);
      unawaited(_loadSchedulerSelectionLeaseIfRequested());
    }
    if (schedulerSelectionLeaseReleaseChanged) {
      _update(_clearSchedulerSelectionLeaseRelease);
      unawaited(_loadSchedulerSelectionLeaseReleaseIfRequested());
    }
    if (clientInstanceResourceViewChanged) {
      _update(_clearClientInstanceResourceView);
      unawaited(_loadClientInstanceResourceViewIfRequested());
    }
    if (clientInstanceSessionViewChanged) {
      _update(_clearClientInstanceSessionView);
      unawaited(_loadClientInstanceSessionViewIfRequested());
    }
    if (clientInstanceSessionResourceConvergenceChanged) {
      _update(_clearClientInstanceSessionResourceConvergence);
      unawaited(_loadClientInstanceSessionResourceConvergenceIfRequested());
    }
    if (lifecycleRegistryChanged) {
      _update(_clearLifecycleRegistry);
      unawaited(_loadLifecycleRegistryIfRequested());
    }
    if (deviceCredentialCandidateChanged) {
      _update(_clearDeviceCredentialCandidate);
      unawaited(_loadDeviceCredentialCandidateIfRequested());
    }
  }
}
