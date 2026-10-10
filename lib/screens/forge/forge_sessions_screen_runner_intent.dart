part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenRunnerIntent on _ForgeSessionsScreenState {
  Future<void> _loadRunnerExecutionIntentIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerExecutionIntentRequest;
    final reader = widget.runnerExecutionIntentReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.conversationID != conversationID ||
        request.run.runID != runID) {
      if (mounted &&
          (_fetchedRunnerExecutionIntent != null ||
              _runnerExecutionIntentError != null ||
              _loadingRunnerExecutionIntent ||
              _runnerExecutionIntentStale)) {
        _update(_clearRunnerExecutionIntent);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerExecutionIntent) return;
    if (!force &&
        (_fetchedRunnerExecutionIntent != null ||
            _runnerExecutionIntentError != null)) {
      return;
    }
    // Runner execution-intent preview is the authenticated candidate edge
    // closest to executable work. Re-read the selected client-instance
    // projection and any configured inventory/resource observations at this
    // boundary so a revoked instance or drifted resource image cannot keep a
    // stale Conversation/Run binding alive. A refresh gap or drift remains
    // request-free.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedRunnerExecutionIntent = null;
          _runnerExecutionIntentError =
              'Runner execution-intent preview is waiting for a fresh validated client-instance session/resource observation.';
          _runnerExecutionIntentStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Runner execution-intent preview',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedRunnerExecutionIntent = null;
        _runnerExecutionIntentError = observationError;
        _runnerExecutionIntentStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerExecutionIntent;
    final generation = ++_runnerExecutionIntentGeneration;
    _update(() {
      _loadingRunnerExecutionIntent = true;
      _runnerExecutionIntentError = null;
      _runnerExecutionIntentStale = previous != null;
    });
    try {
      final validatedRequest = ForgeRunnerExecutionIntentRequest(
        owner: ForgeDeviceOwner.fromJson(request.owner.toJson()),
        conversationID: request.conversationID,
        prompt: request.prompt,
        run: request.run,
        binding: request.binding,
        command: request.command,
      );
      final expected = observeForgeRunnerExecutionIntent(validatedRequest);
      final preview = ForgeRunnerExecutionIntentObservation.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!preview.isFor(conversationID, runID) ||
          !preview.isDisplayOnly ||
          jsonEncode(preview.toJson()) != jsonEncode(expected.toJson())) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner execution-intent preview.',
        );
      }
      if (!mounted ||
          generation != _runnerExecutionIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerExecutionIntent = preview;
        _runnerExecutionIntentError = null;
        _runnerExecutionIntentStale = false;
        _loadingRunnerExecutionIntent = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerExecutionIntentGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerExecutionIntentGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerExecutionIntent = previous;
        _runnerExecutionIntentError = _friendlyError(
          error,
          'Could not load Runner execution-intent preview.',
        );
        _runnerExecutionIntentStale = previous != null;
        _loadingRunnerExecutionIntent = false;
      });
    }
  }

  void _clearRunnerExecutionIntent() {
    _runnerExecutionIntentGeneration++;
    _fetchedRunnerExecutionIntent = null;
    _runnerExecutionIntentError = null;
    _runnerExecutionIntentStale = false;
    _loadingRunnerExecutionIntent = false;
  }

  Future<void> _loadLocalRunnerPreviewIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.localRunnerPreviewRequest;
    final reader = widget.localRunnerPreviewReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        request.intent.conversationID != conversationID ||
        request.intent.run.runID != runID) {
      if (mounted &&
          (_fetchedLocalRunnerPreview != null ||
              _localRunnerPreviewError != null ||
              _loadingLocalRunnerPreview ||
              _localRunnerPreviewStale)) {
        _update(_clearLocalRunnerPreview);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingLocalRunnerPreview) return;
    if (!force &&
        (_fetchedLocalRunnerPreview != null ||
            _localRunnerPreviewError != null)) {
      return;
    }
    // Execution-readiness is the last metadata boundary before a caller could
    // mistake a local Runner preview for an executable result. Re-read the
    // selected client-instance pair and any separately configured
    // inventory/resource observations immediately before invoking the
    // candidate reader. A refresh gap or drift must block the candidate POST
    // and cannot broaden the selected Conversation back to the owner view.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedLocalRunnerPreview = null;
          _localRunnerPreviewError =
              'Local Runner execution-readiness preview is waiting for a fresh validated client-instance session/resource observation.';
          _localRunnerPreviewStale = false;
        });
      }
      return;
    }
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Local Runner execution-readiness preview',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedLocalRunnerPreview = null;
        _localRunnerPreviewError = observationError;
        _localRunnerPreviewStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedLocalRunnerPreview;
    final generation = ++_localRunnerPreviewGeneration;
    _update(() {
      _loadingLocalRunnerPreview = true;
      _localRunnerPreviewError = null;
      _localRunnerPreviewStale = previous != null;
    });
    try {
      request.validateForPath(conversationID, request.intent.prompt.intentID);
      final preview = ForgeLocalRunnerPreviewObservation.fromJson(
        (await reader(request)).toJson(),
        request: request,
        conversationID: conversationID,
        intentID: request.intent.prompt.intentID,
      );
      if (preview.runnerExecutionIntent.runID != runID) {
        throw const FormatException(
          'Forge returned a local Runner preview for another Run.',
        );
      }
      if (!mounted ||
          generation != _localRunnerPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedLocalRunnerPreview = preview;
        _localRunnerPreviewError = null;
        _localRunnerPreviewStale = false;
        _loadingLocalRunnerPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _localRunnerPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _localRunnerPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedLocalRunnerPreview = previous;
        _localRunnerPreviewError = _friendlyError(
          error,
          'Could not load local Runner execution-readiness preview.',
        );
        _localRunnerPreviewStale = previous != null;
        _loadingLocalRunnerPreview = false;
      });
    }
  }

  void _clearLocalRunnerPreview() {
    _localRunnerPreviewGeneration++;
    _fetchedLocalRunnerPreview = null;
    _localRunnerPreviewError = null;
    _localRunnerPreviewStale = false;
    _loadingLocalRunnerPreview = false;
  }

  ForgeLocalRunnerPreviewObservation? _strictLocalRunnerPreview(
    ForgeLocalRunnerPreviewObservation? candidate,
  ) {
    final request = widget.localRunnerPreviewRequest;
    final conversationID = _selected?.conversation.id;
    final runID = _selectedRun?.runID;
    if (candidate == null ||
        request == null ||
        conversationID == null ||
        runID == null) {
      return null;
    }
    if (request.intent.conversationID != conversationID ||
        request.intent.run.runID != runID) {
      return null;
    }
    try {
      final validated = ForgeLocalRunnerPreviewObservation.fromJson(
        candidate.toJson(),
        request: request,
        conversationID: conversationID,
        intentID: request.intent.prompt.intentID,
      );
      return validated.runnerExecutionIntent.runID == runID ? validated : null;
    } catch (_) {
      return null;
    }
  }
}
