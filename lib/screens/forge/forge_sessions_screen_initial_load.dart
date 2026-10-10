part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenInitialLoad on _ForgeSessionsScreenState {
  Future<void> _initialLoad() async {
    // Prime an explicitly requested local instance projection before the
    // owner Conversation list. This prevents the first list item from being
    // hydrated as a private Prompt/Run selection before the display filter
    // has established which sessions belong to the requested instance.
    if (_selectedClientInstanceID != null) {
      await _loadDeviceInventoryResourceConvergenceIfRequested();
      await _loadClientInstanceSessionResourceConvergenceIfRequested();
      await _loadClientInstanceSessionViewIfRequested();
      await _loadClientInstanceResourceViewIfRequested();
    }
    await _refreshConversations(selectID: widget.initialConversationID);
    if (mounted) {
      await _loadPendingRunIntentsIfRequested();
      await _loadDeviceInventoryIfRequested();
      await _loadDeviceInventoryV2IfRequested();
      await _loadDeviceInventoryResourceConvergenceIfRequested();
      await _loadDeviceInventoryRegistryPlacementPreviewIfRequested();
      await _loadSchedulerSelectionPreviewIfRequested();
      await _loadSchedulerSelectionLeaseIfRequested();
      await _loadSchedulerSelectionLeaseReleaseIfRequested();
      await _loadClientInstanceSessionResourceConvergenceIfRequested();
      await _loadClientInstanceSessionViewIfRequested();
      await _loadClientInstanceResourceViewIfRequested();
      await _loadLifecycleRegistryIfRequested();
      await _loadDeviceCredentialCandidateIfRequested();
      await _loadRunAttemptLeaseDispatchPreflightIfRequested();
      await _loadRunnerDispatchPlanPreviewIfRequested();
      await _loadRunnerExecutionIntentIfRequested();
      await _loadRunnerDispatchAdmissionIfRequested();
      await _loadRunnerTransportAdmissionIfRequested();
      await _loadRunnerExecutionBoundaryIfRequested();
      await _loadRunnerAttemptBoundaryIfRequested();
      await _loadLocalRunnerPreviewIfRequested();
      await _loadExecutionReconciliationIfRequested();
      await _loadExecutionConsentPreviewIfRequested();
      await _loadRunExecutionEvidenceIfRequested();
      await _loadSessionRunnerReceiptHistoryIfRequested();
      await _loadSessionRunnerReconciliationProjectionIfRequested();
    }
    if (mounted) {
      _initialLoadComplete = true;
      _startChangeSyncTimer();
    }
  }

  String? _initialClientInstanceID() {
    final value = widget.initialClientInstanceID?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  /// Mobile platforms and desktop window integrations can report more than
  /// one `resumed` notification while a route is returning to the foreground.
  /// Coalesce those notifications so a single resume cannot issue overlapping
  /// feed, session, and Run reads.
  void _refreshOnResume() {
    if (_refreshingOnResume ||
        _sessionViewInvalidated ||
        _authorizationInvalidated) {
      return;
    }
    _refreshingOnResume = true;
    unawaited(_refreshAndSyncOnResume());
  }

  Future<void> _refreshAndSyncOnResume() async {
    try {
      await _refreshAndSync();
    } finally {
      _refreshingOnResume = false;
    }
  }
}
