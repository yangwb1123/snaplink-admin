part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenChangePolling on _ForgeSessionsScreenState {
  void _startChangeSyncTimer({bool immediate = false}) {
    if (_sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    _changeSyncEnabled = true;
    if (widget.enableConversationChangesStream &&
        !_changeStreamFallbackToPolling) {
      if (!_initialLoadComplete) return;
      _scheduleChangeStreamReconnect();
      return;
    }
    if (_changeSyncTimer != null || _changePollInFlight) return;
    _changeSyncTimer = Timer(immediate ? Duration.zero : _changePollDelay, () {
      _changeSyncTimer = null;
      unawaited(_runScheduledChangePoll());
    });
  }

  /// A successful feed read also proves that the transport recovered. Retry a
  /// failed conversation snapshot so a transient outage does not leave the
  /// screen empty until the user manually refreshes or backgrounds the app.
  Future<_ForgeChangePollOutcome> _pollForChanges() async {
    if (_sessionViewInvalidated || _authorizationInvalidated) {
      return _ForgeChangePollOutcome.skipped;
    }
    final syncOutcome = await _syncChanges();
    if (syncOutcome == _ForgeChangeSyncOutcome.skipped) {
      return _ForgeChangePollOutcome.skipped;
    }
    // A change-bearing sync already refreshes pending Run-intent metadata as
    // part of its selected-conversation update. The scheduled path must also
    // refresh the explicit reader when the feed is unchanged (or recovered
    // after a transient failure), otherwise an opted-in metadata panel can
    // remain stale between foreground/manual refreshes. The default reader
    // remains request-free.
    if (syncOutcome != _ForgeChangeSyncOutcome.changed &&
        syncOutcome != _ForgeChangeSyncOutcome.advancedHidden) {
      await _loadPendingRunIntentsIfRequested(force: true);
    }
    // The scheduled path invokes _syncChanges directly rather than the
    // manual/resume wrapper. Refresh explicitly injected v1 and v2 inventory
    // readers here so either opted-in resource view cannot remain stale
    // between foreground refreshes; the default readers remain request-free.
    // These owner-scoped observations are independent GETs. Start them from
    // the same poll frame so one slow candidate cannot consume the entire
    // transport window before the other proof image is refreshed.
    await Future.wait([
      _loadDeviceInventoryIfRequested(force: true),
      _loadDeviceInventoryV2IfRequested(force: true),
      _loadDeviceInventoryResourceConvergenceIfRequested(force: true),
    ]);
    // Registry-backed placement is another explicit display-only reader. It
    // follows the same owner-scoped cadence when enabled and remains a no-op
    // for the default Gate.
    await _loadDeviceInventoryRegistryPlacementPreviewIfRequested(force: true);
    await _loadSchedulerSelectionPreviewIfRequested(force: true);
    // Client-instance views are also explicit display-only readers. When an
    // instance is selected, _syncChanges has already refreshed them before
    // touching owner-scoped state; repeating the reads here could produce a
    // newer projection than the Conversation page was filtered against.
    if (_selectedClientInstanceID == null) {
      await _loadClientInstanceSessionResourceConvergenceIfRequested(
        force: true,
      );
      await _loadClientInstanceSessionViewIfRequested(force: true);
      await _loadClientInstanceResourceViewIfRequested(force: true);
    }
    await _loadLifecycleRegistryIfRequested(force: true);
    await _loadExecutionConsentPreviewIfRequested(force: true);
    var succeeded = syncOutcome != _ForgeChangeSyncOutcome.failed;
    if (syncOutcome == _ForgeChangeSyncOutcome.advancedHidden) {
      return succeeded
          ? _ForgeChangePollOutcome.succeeded
          : _ForgeChangePollOutcome.failed;
    }
    if (!mounted ||
        _changeError != null ||
        (_conversationError == null && !_conversationsStale)) {
      return succeeded
          ? _ForgeChangePollOutcome.succeeded
          : _ForgeChangePollOutcome.failed;
    }
    if (!_selectedClientInstanceProjectionReadyForOwnerReads()) {
      return _ForgeChangePollOutcome.failed;
    }
    succeeded = await _refreshConversations() && succeeded;
    return succeeded
        ? _ForgeChangePollOutcome.succeeded
        : _ForgeChangePollOutcome.failed;
  }

  Future<void> _runScheduledChangePoll() async {
    if (!_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        _changePollInFlight) {
      return;
    }
    _changePollInFlight = true;
    final outcome = await _pollForChanges();
    _changePollInFlight = false;
    if (!_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !mounted) {
      return;
    }
    switch (outcome) {
      case _ForgeChangePollOutcome.succeeded:
        _changePollFailureStreak = 0;
        _changePollDelay = _changePollBaseDelay;
      case _ForgeChangePollOutcome.failed:
        _changePollFailureStreak = min(
          _changePollFailureStreak + 1,
          _changePollMaxFailureStreak,
        );
        final multiplier = 1 << _changePollFailureStreak;
        _changePollDelay = Duration(
          milliseconds: min(
            _changePollBaseDelay.inMilliseconds * multiplier,
            _changePollMaxDelay.inMilliseconds,
          ),
        );
      case _ForgeChangePollOutcome.skipped:
        break;
    }
    _startChangeSyncTimer();
  }

  void _scheduleChangeStreamReconnect({bool immediate = false}) {
    if (!_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !widget.enableConversationChangesStream ||
        _changeStreamFallbackToPolling ||
        !_initialLoadComplete ||
        _changeStreamReconnectTimer != null ||
        _changeStreamInFlight) {
      return;
    }
    final generation = _changeStreamGeneration;
    _changeStreamReconnectTimer = Timer(
      immediate ? Duration.zero : _changeStreamReconnectDelay,
      () {
        _changeStreamReconnectTimer = null;
        if (generation != _changeStreamGeneration) return;
        unawaited(_runScheduledChangeStream(generation));
      },
    );
  }

  Future<void> _runScheduledChangeStream(int generation) async {
    if (generation != _changeStreamGeneration ||
        !_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !mounted ||
        _changeStreamInFlight ||
        _changeStreamFallbackToPolling) {
      return;
    }
    _changeStreamInFlight = true;
    final outcome = await _syncChanges(stream: true);
    _changeStreamInFlight = false;
    if (generation != _changeStreamGeneration ||
        !_changeSyncEnabled ||
        _sessionViewInvalidated ||
        _authorizationInvalidated ||
        !mounted) {
      return;
    }
    if (outcome == _ForgeChangeSyncOutcome.failed) {
      // A stream transport, authorization, or framing failure must not leave
      // the shared Sessions surface stale. Degrade this screen instance to
      // the already-tested bounded polling path.
      _changeStreamFallbackToPolling = true;
      _startChangeSyncTimer(immediate: true);
      return;
    }
    if (outcome == _ForgeChangeSyncOutcome.skipped) {
      // A manual refresh may own the shared merge gate briefly. Leave a
      // bounded gap before retrying instead of spinning microtasks while it
      // completes.
      _scheduleChangeStreamReconnect();
      return;
    }
    // A 204 timeout and an unchanged page both reconnect through one bounded
    // single-flight stream. Cursor persistence still belongs to _syncChanges
    // and occurs only after the page has been merged successfully.
    _scheduleChangeStreamReconnect(immediate: true);
  }

  void _stopChangeSyncTimer() {
    _changeSyncEnabled = false;
    _changeSyncTimer?.cancel();
    _changeSyncTimer = null;
    _changeStreamReconnectTimer?.cancel();
    _changeStreamReconnectTimer = null;
    _changeStreamGeneration++;
  }
}
