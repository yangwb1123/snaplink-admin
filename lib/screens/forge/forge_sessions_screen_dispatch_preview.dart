part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenDispatchPreview on _ForgeSessionsScreenState {
  Future<void> _loadRunAttemptLeaseDispatchPreflightIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runAttemptLeaseDispatchPreflightRequest;
    final reader = widget.runAttemptLeaseDispatchPreflightReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        !request.isFor(conversationID, runID)) {
      if (mounted &&
          (_fetchedRunAttemptLeaseDispatchPreflight != null ||
              _runAttemptLeaseDispatchPreflightError != null ||
              _loadingRunAttemptLeaseDispatchPreflight ||
              _runAttemptLeaseDispatchPreflightStale)) {
        _update(_clearRunAttemptLeaseDispatchPreflight);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunAttemptLeaseDispatchPreflight) return;
    if (!force &&
        (_fetchedRunAttemptLeaseDispatchPreflight != null ||
            _runAttemptLeaseDispatchPreflightError != null)) {
      return;
    }
    // A preflight is still a selected-session candidate. Refresh the
    // owner-bound client-instance projection immediately before invoking the
    // candidate reader so a revoked or drifted instance cannot keep a stale
    // Run/Attempt binding alive. A configured inventory/resource pair is
    // checked at the same boundary because the preflight carries placement
    // and lease metadata that must not outlive its observation.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedRunAttemptLeaseDispatchPreflight = null;
          _runAttemptLeaseDispatchPreflightError =
              'Forge preflight is waiting for a fresh validated client-instance session/resource observation.';
          _runAttemptLeaseDispatchPreflightStale = false;
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
          'Forge preflight',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedRunAttemptLeaseDispatchPreflight = null;
        _runAttemptLeaseDispatchPreflightError = observationError;
        _runAttemptLeaseDispatchPreflightStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunAttemptLeaseDispatchPreflight;
    final generation = ++_runAttemptLeaseDispatchPreflightGeneration;
    _update(() {
      _loadingRunAttemptLeaseDispatchPreflight = true;
      _runAttemptLeaseDispatchPreflightError = null;
      _runAttemptLeaseDispatchPreflightStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
            request.toJson(),
          );
      if (!validatedRequest.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge preflight request is bound to another selected Run.',
        );
      }
      final fixture = ForgePreflightFixture.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!fixture.isFor(conversationID, runID) ||
          fixture.issuer != validatedRequest.owner.issuer ||
          fixture.subject != validatedRequest.owner.subject ||
          fixture.tenantId != validatedRequest.owner.tenantID ||
          !fixture.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound preflight.',
        );
      }
      if (!mounted ||
          generation != _runAttemptLeaseDispatchPreflightGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunAttemptLeaseDispatchPreflight = fixture;
        _runAttemptLeaseDispatchPreflightError = null;
        _runAttemptLeaseDispatchPreflightStale = false;
        _loadingRunAttemptLeaseDispatchPreflight = false;
      });
    } catch (error) {
      if (!mounted ||
          generation != _runAttemptLeaseDispatchPreflightGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runAttemptLeaseDispatchPreflightGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunAttemptLeaseDispatchPreflight = previous;
        _runAttemptLeaseDispatchPreflightError = _friendlyError(
          error,
          'Could not load Run-Attempt lease preflight.',
        );
        _runAttemptLeaseDispatchPreflightStale = previous != null;
        _loadingRunAttemptLeaseDispatchPreflight = false;
      });
    }
  }

  void _clearRunAttemptLeaseDispatchPreflight() {
    _runAttemptLeaseDispatchPreflightGeneration++;
    _fetchedRunAttemptLeaseDispatchPreflight = null;
    _runAttemptLeaseDispatchPreflightError = null;
    _runAttemptLeaseDispatchPreflightStale = false;
    _loadingRunAttemptLeaseDispatchPreflight = false;
  }

  Future<void> _loadRunnerDispatchPlanPreviewIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerDispatchPlanPreviewRequest;
    final reader = widget.runnerDispatchPlanPreviewReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null ||
        reader == null ||
        conversationID == null ||
        runID == null ||
        !request.isFor(conversationID, runID)) {
      if (mounted &&
          (_fetchedRunnerDispatchPlanPreview != null ||
              _runnerDispatchPlanPreviewError != null ||
              _loadingRunnerDispatchPlanPreview ||
              _runnerDispatchPlanPreviewStale)) {
        _update(_clearRunnerDispatchPlanPreview);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerDispatchPlanPreview) return;
    if (!force &&
        (_fetchedRunnerDispatchPlanPreview != null ||
            _runnerDispatchPlanPreviewError != null)) {
      return;
    }
    // The dispatch-plan preview is still a candidate owner read. Re-read the
    // selected client-instance session/resource projection immediately before
    // invoking its reader so a revoked or drifted instance cannot keep a
    // stale Conversation binding alive. A configured inventory/resource pair
    // is refreshed at the same boundary because the plan contains placement
    // candidates whose metadata must not outlive that observation.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedRunnerDispatchPlanPreview = null;
          _runnerDispatchPlanPreviewError =
              'Runner dispatch-plan preview is waiting for a fresh validated client-instance session/resource observation.';
          _runnerDispatchPlanPreviewStale = false;
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
          'Runner dispatch-plan preview',
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedRunnerDispatchPlanPreview = null;
        _runnerDispatchPlanPreviewError = observationError;
        _runnerDispatchPlanPreviewStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerDispatchPlanPreview;
    final generation = ++_runnerDispatchPlanPreviewGeneration;
    _update(() {
      _loadingRunnerDispatchPlanPreview = true;
      _runnerDispatchPlanPreviewError = null;
      _runnerDispatchPlanPreviewStale = previous != null;
    });
    try {
      final validatedRequest =
          ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
            request.toJson(),
          );
      if (!validatedRequest.isFor(conversationID, runID)) {
        throw const FormatException(
          'Forge Runner dispatch-plan request is bound to another selected Run.',
        );
      }
      final preview = ForgeRunnerDispatchPlanPreview.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      final plan = validatedRequest.dispatchPlan;
      final intent = plan.runnerExecutionIntent;
      if (!preview.isFor(conversationID, runID) ||
          !preview.isDisplayOnly ||
          preview.owner != validatedRequest.owner ||
          preview.attemptID != intent.attemptID ||
          preview.attemptState != plan.attemptState ||
          preview.commandID != intent.commandID ||
          preview.commandSHA256 != intent.commandSHA256 ||
          preview.intentTargetID != intent.targetID ||
          preview.leaseEpoch != plan.lease.epoch.toInt() ||
          preview.evaluatedAtMS != plan.placement.evaluatedAtMS ||
          preview.candidateCount != plan.placement.devices.length) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner dispatch-plan preview.',
        );
      }
      if (!_runnerDispatchPlanTargetsMatchResources(preview)) {
        throw const FormatException(
          'Forge returned Runner dispatch-plan candidates outside the current resource observation.',
        );
      }
      if (!mounted ||
          generation != _runnerDispatchPlanPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerDispatchPlanPreview = preview;
        _runnerDispatchPlanPreviewError = null;
        _runnerDispatchPlanPreviewStale = false;
        _loadingRunnerDispatchPlanPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerDispatchPlanPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerDispatchPlanPreviewGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerDispatchPlanPreview = previous;
        _runnerDispatchPlanPreviewError = _friendlyError(
          error,
          'Could not load Runner dispatch-plan preview.',
        );
        _runnerDispatchPlanPreviewStale = previous != null;
        _loadingRunnerDispatchPlanPreview = false;
      });
    }
  }

  void _clearRunnerDispatchPlanPreview() {
    _runnerDispatchPlanPreviewGeneration++;
    _fetchedRunnerDispatchPlanPreview = null;
    _runnerDispatchPlanPreviewError = null;
    _runnerDispatchPlanPreviewStale = false;
    _loadingRunnerDispatchPlanPreview = false;
  }
}
