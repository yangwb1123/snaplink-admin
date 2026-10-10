part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenReceiptReads on _ForgeSessionsScreenState {
  Future<void> _loadSessionRunnerReceiptHistoryIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.sessionRunnerReceiptHistoryReader;
    final request = widget.sessionRunnerReceiptHistoryRequest;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null ||
        request == null ||
        conversationID == null ||
        runID == null) {
      if (mounted &&
          (_fetchedSessionRunnerReceiptHistory != null ||
              _sessionRunnerReceiptHistoryError != null ||
              _loadingSessionRunnerReceiptHistory ||
              _sessionRunnerReceiptHistoryStale)) {
        _update(_clearSessionRunnerReceiptHistory);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingSessionRunnerReceiptHistory) return;
    if (!force &&
        (_fetchedSessionRunnerReceiptHistory != null ||
            _sessionRunnerReceiptHistoryError != null)) {
      return;
    }
    final previous = _fetchedSessionRunnerReceiptHistory;
    final generation = ++_sessionRunnerReceiptHistoryGeneration;
    _update(() {
      _loadingSessionRunnerReceiptHistory = true;
      _sessionRunnerReceiptHistoryError = null;
      _sessionRunnerReceiptHistoryStale = previous != null;
    });
    try {
      final validatedRequest = ForgeSessionRunnerReceiptHistory.fromJson(
        request.toJson(),
      );
      if (!validatedRequest.isDisplayOnly ||
          !validatedRequest.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge session Runner receipt-history request is not bound to the selected Run.',
        );
      }
      final history = ForgeSessionRunnerReceiptHistory.fromJson(
        (await reader(conversationID, runID, validatedRequest)).toJson(),
      );
      if (!history.isDisplayOnly ||
          !history.isFor(conversationID, runID) ||
          history.owner != validatedRequest.owner ||
          jsonEncode(history.toJson()) !=
              jsonEncode(validatedRequest.toJson())) {
        throw const FormatException(
          'Forge returned another or authority-bearing session Runner receipt history.',
        );
      }
      if (!mounted ||
          generation != _sessionRunnerReceiptHistoryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSessionRunnerReceiptHistory = history;
        _sessionRunnerReceiptHistoryError = null;
        _sessionRunnerReceiptHistoryStale = false;
        _loadingSessionRunnerReceiptHistory = false;
      });
    } catch (error) {
      if (!mounted || generation != _sessionRunnerReceiptHistoryGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _sessionRunnerReceiptHistoryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSessionRunnerReceiptHistory = previous;
        _sessionRunnerReceiptHistoryError = _friendlyError(
          error,
          'Could not load session Runner receipt-history preview.',
        );
        _sessionRunnerReceiptHistoryStale = previous != null;
        _loadingSessionRunnerReceiptHistory = false;
      });
    }
  }

  void _clearSessionRunnerReceiptHistory() {
    _sessionRunnerReceiptHistoryGeneration++;
    _fetchedSessionRunnerReceiptHistory = null;
    _sessionRunnerReceiptHistoryError = null;
    _sessionRunnerReceiptHistoryStale = false;
    _loadingSessionRunnerReceiptHistory = false;
  }

  Future<void> _loadSessionRunnerReconciliationProjectionIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.sessionRunnerReconciliationProjectionReader;
    final request = widget.sessionRunnerReconciliationProjectionRequest;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null ||
        request == null ||
        conversationID == null ||
        runID == null) {
      if (mounted &&
          (_fetchedSessionRunnerReconciliationProjection != null ||
              _sessionRunnerReconciliationProjectionError != null ||
              _loadingSessionRunnerReconciliationProjection ||
              _sessionRunnerReconciliationProjectionStale)) {
        _update(_clearSessionRunnerReconciliationProjection);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingSessionRunnerReconciliationProjection) return;
    if (!force &&
        (_fetchedSessionRunnerReconciliationProjection != null ||
            _sessionRunnerReconciliationProjectionError != null)) {
      return;
    }
    final previous = _fetchedSessionRunnerReconciliationProjection;
    final generation = ++_sessionRunnerReconciliationProjectionGeneration;
    _update(() {
      _loadingSessionRunnerReconciliationProjection = true;
      _sessionRunnerReconciliationProjectionError = null;
      _sessionRunnerReconciliationProjectionStale = previous != null;
    });
    try {
      final validatedRequest = ForgeSessionRunnerReceiptHistory.fromJson(
        request.toJson(),
      );
      if (!validatedRequest.isDisplayOnly ||
          !validatedRequest.isFor(conversationID, runID) ||
          !validatedRequest.hasUncertainTerminal) {
        throw const FormatException(
          'Forge reconciliation request is not bound to an uncertain terminal Run.',
        );
      }
      final projection = ForgeSessionRunnerReconciliationProjection.fromJson(
        (await reader(conversationID, runID, validatedRequest)).toJson(),
      );
      final source = projection.source;
      if (!projection.isDisplayOnly ||
          !projection.isFor(conversationID, runID) ||
          projection.owner != validatedRequest.owner ||
          source.owner != validatedRequest.owner ||
          source.conversationID != validatedRequest.conversationID ||
          source.promptID != validatedRequest.promptID ||
          source.runID != validatedRequest.runID ||
          source.attemptCount != validatedRequest.attemptCount ||
          source.latestAttemptID != validatedRequest.latestAttemptID ||
          source.latestCommandID != validatedRequest.latestCommandID ||
          source.latestTargetID != validatedRequest.latestTargetID ||
          source.latestDispositionKind !=
              validatedRequest.latestDispositionKind ||
          source.latestObservedAtMS != validatedRequest.latestObservedAtMS) {
        throw const FormatException(
          'Forge returned another or authority-bearing reconciliation projection.',
        );
      }
      if (!mounted ||
          generation != _sessionRunnerReconciliationProjectionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSessionRunnerReconciliationProjection = projection;
        _sessionRunnerReconciliationProjectionError = null;
        _sessionRunnerReconciliationProjectionStale = false;
        _loadingSessionRunnerReconciliationProjection = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _sessionRunnerReconciliationProjectionGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _sessionRunnerReconciliationProjectionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSessionRunnerReconciliationProjection = previous;
        _sessionRunnerReconciliationProjectionError = _friendlyError(
          error,
          'Could not load session Runner reconciliation preview.',
        );
        _sessionRunnerReconciliationProjectionStale = previous != null;
        _loadingSessionRunnerReconciliationProjection = false;
      });
    }
  }

  void _clearSessionRunnerReconciliationProjection() {
    _sessionRunnerReconciliationProjectionGeneration++;
    _fetchedSessionRunnerReconciliationProjection = null;
    _sessionRunnerReconciliationProjectionError = null;
    _sessionRunnerReconciliationProjectionStale = false;
    _loadingSessionRunnerReconciliationProjection = false;
  }
}
