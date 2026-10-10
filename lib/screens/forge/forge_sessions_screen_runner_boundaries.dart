part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenRunnerBoundaries on _ForgeSessionsScreenState {
  Future<void> _loadRunnerExecutionBoundaryIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerExecutionBoundaryRequest;
    final reader = widget.runnerExecutionBoundaryReader;
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
        request.runID != runID) {
      if (mounted &&
          (_fetchedRunnerExecutionBoundary != null ||
              _runnerExecutionBoundaryError != null ||
              _loadingRunnerExecutionBoundary ||
              _runnerExecutionBoundaryStale)) {
        _update(_clearRunnerExecutionBoundary);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    // An execution-boundary preview is the last read before a possible
    // Runner handoff. Re-read the selected instance projection at this
    // boundary so a stale mobile/Web/App selection cannot reuse a private Run
    // after its session/resource declaration has been revoked. This remains
    // a read-only, candidate-only gate; the execution-boundary reader still
    // decides whether a preview is available.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedRunnerExecutionBoundary = null;
          _runnerExecutionBoundaryError =
              'Runner execution-boundary preview is waiting for a fresh validated client-instance session/resource observation.';
          _runnerExecutionBoundaryStale = false;
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
          'Runner execution-boundary preview',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedRunnerExecutionBoundary = null;
        _runnerExecutionBoundaryError = observationError;
        _runnerExecutionBoundaryStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerExecutionBoundary) return;
    if (!force &&
        (_fetchedRunnerExecutionBoundary != null ||
            _runnerExecutionBoundaryError != null)) {
      return;
    }
    final previous = _fetchedRunnerExecutionBoundary;
    final generation = ++_runnerExecutionBoundaryGeneration;
    _update(() {
      _loadingRunnerExecutionBoundary = true;
      _runnerExecutionBoundaryError = null;
      _runnerExecutionBoundaryStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(request.toJson());
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner execution boundary request is bound to another Run.',
        );
      }
      if (!_runnerAdmissionTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner execution-boundary target is outside the current resource observation.',
        );
      }
      final observation = ForgeRunnerExecutionBoundaryObservation.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!observation.isFor(
            conversationID,
            runID,
            validatedRequest.attemptID,
          ) ||
          observation.owner != validatedRequest.owner ||
          observation.commandID != validatedRequest.command.commandID ||
          observation.commandSHA256 !=
              validatedRequest.command.commandSHA256() ||
          observation.targetID !=
              validatedRequest.command.leaseProof.targetID ||
          observation.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          !_runnerAdmissionTargetMatchesResources(
            observation.owner,
            observation.targetID,
          ) ||
          !observation.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner execution boundary.',
        );
      }
      if (!mounted ||
          generation != _runnerExecutionBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerExecutionBoundary = observation;
        _runnerExecutionBoundaryError = null;
        _runnerExecutionBoundaryStale = false;
        _loadingRunnerExecutionBoundary = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerExecutionBoundaryGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerExecutionBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerExecutionBoundary = previous;
        _runnerExecutionBoundaryError = _friendlyError(
          error,
          'Could not load Runner execution-boundary preview.',
        );
        _runnerExecutionBoundaryStale = previous != null;
        _loadingRunnerExecutionBoundary = false;
      });
    }
  }

  void _clearRunnerExecutionBoundary() {
    _runnerExecutionBoundaryGeneration++;
    _fetchedRunnerExecutionBoundary = null;
    _runnerExecutionBoundaryError = null;
    _runnerExecutionBoundaryStale = false;
    _loadingRunnerExecutionBoundary = false;
  }

  Future<void> _loadRunnerAttemptBoundaryIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerAttemptBoundaryRequest;
    final reader = widget.runnerAttemptBoundaryReader;
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
        request.runID != runID) {
      if (mounted &&
          (_fetchedRunnerAttemptBoundary != null ||
              _runnerAttemptBoundaryError != null ||
              _loadingRunnerAttemptBoundary ||
              _runnerAttemptBoundaryStale)) {
        _update(_clearRunnerAttemptBoundary);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerAttemptBoundary) return;
    if (!force &&
        (_fetchedRunnerAttemptBoundary != null ||
            _runnerAttemptBoundaryError != null)) {
      return;
    }
    // Attempt-boundary output is display-only, but it is the last metadata
    // edge before a caller could mistake a transition for executable work.
    // Re-read the selected client-instance projection and any configured
    // inventory/resource image before the candidate POST. A reader gap or
    // drift therefore remains request-free.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedRunnerAttemptBoundary = null;
          _runnerAttemptBoundaryError =
              'Runner Attempt boundary is waiting for a fresh validated client-instance session/resource observation.';
          _runnerAttemptBoundaryStale = false;
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
          'Runner Attempt boundary',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedRunnerAttemptBoundary = null;
        _runnerAttemptBoundaryError = observationError;
        _runnerAttemptBoundaryStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerAttemptBoundary;
    final generation = ++_runnerAttemptBoundaryGeneration;
    _update(() {
      _loadingRunnerAttemptBoundary = true;
      _runnerAttemptBoundaryError = null;
      _runnerAttemptBoundaryStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(request.toJson());
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner Attempt boundary request is bound to another Run.',
        );
      }
      if (!_runnerAttemptBoundaryTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner Attempt boundary target is outside the current resource observation.',
        );
      }
      final observation = ForgeRunnerAttemptBoundaryObservation.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!observation.isDisplayOnly ||
          !observation.isFor(
            conversationID,
            runID,
            validatedRequest.attemptID,
          ) ||
          observation.owner != validatedRequest.owner ||
          observation.commandID != validatedRequest.command.commandID ||
          observation.targetID !=
              validatedRequest.command.leaseProof.targetID ||
          observation.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          observation.currentAttemptState != validatedRequest.attemptState ||
          observation.transition != validatedRequest.transition ||
          !_runnerAttemptBoundaryTargetMatchesResources(
            observation.owner,
            observation.targetID,
          )) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner Attempt boundary.',
        );
      }
      if (!mounted ||
          generation != _runnerAttemptBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerAttemptBoundary = observation;
        _runnerAttemptBoundaryError = null;
        _runnerAttemptBoundaryStale = false;
        _loadingRunnerAttemptBoundary = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerAttemptBoundaryGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerAttemptBoundaryGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerAttemptBoundary = previous;
        _runnerAttemptBoundaryError = _friendlyError(
          error,
          'Could not load Runner Attempt boundary preview.',
        );
        _runnerAttemptBoundaryStale = previous != null;
        _loadingRunnerAttemptBoundary = false;
      });
    }
  }

  void _clearRunnerAttemptBoundary() {
    _runnerAttemptBoundaryGeneration++;
    _fetchedRunnerAttemptBoundary = null;
    _runnerAttemptBoundaryError = null;
    _runnerAttemptBoundaryStale = false;
    _loadingRunnerAttemptBoundary = false;
  }

  void _clearRunnerAttemptBoundaryPreview() {
    _runnerAttemptBoundaryPreview = null;
    _runnerAttemptBoundaryPreviewError = null;
    _loadingRunnerAttemptBoundaryPreview = false;
  }
}
