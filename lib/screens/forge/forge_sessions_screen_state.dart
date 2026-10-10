part of 'forge_sessions_screen.dart';

class _ForgeSessionsScreenState extends State<ForgeSessionsScreen>
    with WidgetsBindingObserver, _ForgeSessionsScreenStorage {
  void _update(VoidCallback callback) => setState(callback);

  @override
  void initState() {
    super.initState();
    _selectedClientInstanceID = _initialClientInstanceID();
    WidgetsBinding.instance.addObserver(this);
    _tokenRefresh = ForgeOAuthTokenRefresh(
      baseUrl: ProductApiOrigin.baseUrl,
      httpClient: widget.oauthHttpClient,
      revocationTimeout: widget.oauthRevocationTimeout,
      credentialStore: _credentialStore,
    );
    _api = ForgeConversationsApi(
      baseUrl: widget.apiOrigin,
      accessToken: widget.accessToken,
      accessTokenProvider: () =>
          Session.readForClient(ForgeConversationsOAuth.clientId),
      refreshAccessToken: _tokenRefresh.refreshAfterUnauthorized,
      httpClient: widget.httpClient,
    );
    _changeCursorStore = ForgeChangeCursorStore(
      accessToken: widget.accessToken,
      apiOrigin: widget.apiOrigin,
      clientId: ForgeConversationsOAuth.clientId,
      resource: ForgeConversationsOAuth.resource,
    );
    _cursorReady = _restoreChangeCursor();
    _runnerLeaseFencingPreview = _safeRunnerLeaseFencingPreview(
      widget.runnerLeaseFencingPreview,
    );
    _executionLeaseCheckpointPreview = _safeExecutionLeaseCheckpointPreview(
      widget.executionLeaseCheckpointPreview,
    );
    _runnerAttemptBoundaryPreview = _safeRunnerAttemptBoundaryPreview(
      widget.runnerAttemptBoundaryPreview,
    );
    _sessionRunnerReceiptVectorsPreview =
        _safeSessionRunnerReceiptVectorsPreview(
          widget.sessionRunnerReceiptVectorsPreview,
        );
    _sessionRunnerReceiptHistoryPreview =
        _safeSessionRunnerReceiptHistoryPreview(
          widget.sessionRunnerReceiptHistoryPreview,
        );
    _sessionRunnerReconciliationProjectionPreview =
        _safeSessionRunnerReconciliationProjectionPreview(
          widget.sessionRunnerReconciliationProjectionPreview,
        );
    _deviceInventoryV2Preview = _safeDeviceInventoryV2Preview(
      widget.deviceInventoryV2Preview,
    );
    _deviceResourceSummaryPreview = _safeDeviceResourceSummaryPreview(
      widget.deviceResourceSummaryPreview,
    );
    _clientInstanceResourceViewPreview = _safeClientInstanceResourceViewPreview(
      widget.clientInstanceResourceViewPreview,
    );
    _clientInstanceSessionViewPreview = _safeClientInstanceSessionViewPreview(
      widget.clientInstanceSessionViewPreview,
    );
    _deviceInventoryPlacementEvaluationV2Preview =
        _safeDeviceInventoryPlacementEvaluationV2Preview(
          widget.deviceInventoryPlacementEvaluationV2Preview,
        );
    _deviceInventoryPlacementEvaluationPreview =
        _safeDeviceInventoryPlacementEvaluationPreview(
          widget.deviceInventoryPlacementEvaluationPreview,
        );
    _deviceInventoryPlacementBatchEvaluationPreview =
        _safeDeviceInventoryPlacementBatchEvaluationPreview(
          widget.deviceInventoryPlacementBatchEvaluationPreview,
        );
    _cancelLocationChange = BrowserNavigation.listenToLocationChange(
      _onLocationChange,
    );
    // Keep the optional candidate read behind the initial owner session
    // snapshot. The two authenticated reads otherwise race during cold start
    // against a coordinator that is still warming its Runtime bridge.
    unawaited(_initialLoad());
    _startChangeSyncTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelLocationChange();
    _stopChangeSyncTimer();
    _api.close();
    _tokenRefresh.close();
    _titleController.dispose();
    _scopeIDController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ForgeSessionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enableConversationChangesStream !=
            widget.enableConversationChangesStream ||
        oldWidget.conversationChangesStreamWaitMS !=
            widget.conversationChangesStreamWaitMS) {
      _changeStreamFallbackToPolling = false;
      _changeStreamGeneration++;
      _changeStreamReconnectTimer?.cancel();
      _changeStreamReconnectTimer = null;
      if (widget.enableConversationChangesStream) {
        _startChangeSyncTimer();
      } else {
        _startChangeSyncTimer();
      }
    }
    final changes = _widgetChanges(oldWidget);
    _applyDeviceChanges(oldWidget, changes);
    _applyRunnerChanges(oldWidget, changes);
    _applyReceiptChanges(oldWidget, changes);
    _applyImportChanges(oldWidget, changes);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startChangeSyncTimer();
      _refreshOnResume();
      return;
    }
    _stopChangeSyncTimer();
  }

  @override
  Widget build(BuildContext context) => _ForgeSessionsView(state: this);
}
