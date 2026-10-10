part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenRunnerAdmission on _ForgeSessionsScreenState {
  Future<void> _loadRunnerDispatchAdmissionIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerDispatchAdmissionRequest;
    final reader = widget.runnerDispatchAdmissionReader;
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
          (_fetchedRunnerDispatchAdmission != null ||
              _runnerDispatchAdmissionError != null ||
              _loadingRunnerDispatchAdmission ||
              _runnerDispatchAdmissionStale)) {
        _update(_clearRunnerDispatchAdmission);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerDispatchAdmission) return;
    if (!force &&
        (_fetchedRunnerDispatchAdmission != null ||
            _runnerDispatchAdmissionError != null)) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedRunnerDispatchAdmission = null;
          _runnerDispatchAdmissionError =
              'Runner dispatch admission is waiting for a fresh validated client-instance session/resource observation.';
          _runnerDispatchAdmissionStale = false;
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
          'Runner dispatch admission',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedRunnerDispatchAdmission = null;
        _runnerDispatchAdmissionError = observationError;
        _runnerDispatchAdmissionStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerDispatchAdmission;
    final generation = ++_runnerDispatchAdmissionGeneration;
    _update(() {
      _loadingRunnerDispatchAdmission = true;
      _runnerDispatchAdmissionError = null;
      _runnerDispatchAdmissionStale = previous != null;
    });
    try {
      final validatedRequest = ForgeRunnerDispatchAdmissionRequest.fromJson(
        request.toJson(),
      );
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner dispatch admission request is bound to another Run.',
        );
      }
      if (!_runnerAdmissionTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner dispatch admission target is outside the current resource observation.',
        );
      }
      final admission = ForgeRunnerDispatchAdmission.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      if (!admission.isFor(conversationID, runID, validatedRequest.attemptID) ||
          admission.owner != validatedRequest.owner ||
          admission.commandID != validatedRequest.command.commandID ||
          admission.commandSHA256 != validatedRequest.command.commandSHA256() ||
          admission.targetID != validatedRequest.command.leaseProof.targetID ||
          admission.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          !_runnerAdmissionTargetMatchesResources(
            admission.owner,
            admission.targetID,
          ) ||
          !admission.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner dispatch admission.',
        );
      }
      if (!mounted ||
          generation != _runnerDispatchAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerDispatchAdmission = admission;
        _runnerDispatchAdmissionError = null;
        _runnerDispatchAdmissionStale = false;
        _loadingRunnerDispatchAdmission = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerDispatchAdmissionGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerDispatchAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerDispatchAdmission = previous;
        _runnerDispatchAdmissionError = _friendlyError(
          error,
          'Could not load Runner dispatch admission preview.',
        );
        _runnerDispatchAdmissionStale = previous != null;
        _loadingRunnerDispatchAdmission = false;
      });
    }
  }

  void _clearRunnerDispatchAdmission() {
    _runnerDispatchAdmissionGeneration++;
    _fetchedRunnerDispatchAdmission = null;
    _runnerDispatchAdmissionError = null;
    _runnerDispatchAdmissionStale = false;
    _loadingRunnerDispatchAdmission = false;
  }

  Future<void> _loadRunnerTransportAdmissionIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final request = widget.runnerTransportAdmissionRequest;
    final reader = widget.runnerTransportAdmissionReader;
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
          (_fetchedRunnerTransportAdmission != null ||
              _runnerTransportAdmissionError != null ||
              _loadingRunnerTransportAdmission ||
              _runnerTransportAdmissionStale)) {
        _update(_clearRunnerTransportAdmission);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunnerTransportAdmission) return;
    if (!force &&
        (_fetchedRunnerTransportAdmission != null ||
            _runnerTransportAdmissionError != null)) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedRunnerTransportAdmission = null;
          _runnerTransportAdmissionError =
              'Runner transport admission is waiting for a fresh validated client-instance session/resource observation.';
          _runnerTransportAdmissionStale = false;
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
          'Runner transport admission',
          force: true,
        );
    if (!mounted ||
        _selected?.conversation.id != conversationID ||
        _selectedRun?.runID != runID) {
      return;
    }
    if (observationError != null) {
      _update(() {
        _fetchedRunnerTransportAdmission = null;
        _runnerTransportAdmissionError = observationError;
        _runnerTransportAdmissionStale = false;
      });
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    final previous = _fetchedRunnerTransportAdmission;
    final generation = ++_runnerTransportAdmissionGeneration;
    _update(() {
      _loadingRunnerTransportAdmission = true;
      _runnerTransportAdmissionError = null;
      _runnerTransportAdmissionStale = previous != null;
    });
    try {
      final validatedRequest = ForgeRunnerTransportAdmissionRequest.fromJson(
        request.toJson(),
      );
      if (validatedRequest.conversationID != conversationID ||
          validatedRequest.runID != runID ||
          validatedRequest.command.leaseProof.attemptID !=
              validatedRequest.attemptID) {
        throw const FormatException(
          'Forge Runner transport admission request is bound to another Run.',
        );
      }
      if (!_runnerAdmissionTargetMatchesResources(
        validatedRequest.owner,
        validatedRequest.command.leaseProof.targetID,
      )) {
        throw const FormatException(
          'Forge Runner transport admission target is outside the current resource observation.',
        );
      }
      final admission = ForgeRunnerTransportAdmission.fromJson(
        (await reader(validatedRequest)).toJson(),
      );
      final expectedPath =
          '/api/v1/runners/${validatedRequest.command.leaseProof.targetID}/dispatch';
      if (!admission.isFor(conversationID, runID, validatedRequest.attemptID) ||
          admission.owner != validatedRequest.owner ||
          admission.commandID != validatedRequest.command.commandID ||
          admission.commandSHA256 != validatedRequest.command.commandSHA256() ||
          admission.targetID != validatedRequest.command.leaseProof.targetID ||
          admission.leaseEpoch != validatedRequest.command.leaseProof.epoch ||
          admission.transportMethod != 'POST' ||
          admission.transportPath != expectedPath ||
          admission.transportPayloadSHA256 !=
              validatedRequest.transport.payloadSHA256 ||
          !_runnerAdmissionTargetMatchesResources(
            admission.owner,
            admission.targetID,
          ) ||
          !admission.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Runner transport admission.',
        );
      }
      if (!mounted ||
          generation != _runnerTransportAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerTransportAdmission = admission;
        _runnerTransportAdmissionError = null;
        _runnerTransportAdmissionStale = false;
        _loadingRunnerTransportAdmission = false;
      });
    } catch (error) {
      if (!mounted || generation != _runnerTransportAdmissionGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runnerTransportAdmissionGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunnerTransportAdmission = previous;
        _runnerTransportAdmissionError = _friendlyError(
          error,
          'Could not load Runner transport admission preview.',
        );
        _runnerTransportAdmissionStale = previous != null;
        _loadingRunnerTransportAdmission = false;
      });
    }
  }

  void _clearRunnerTransportAdmission() {
    _runnerTransportAdmissionGeneration++;
    _fetchedRunnerTransportAdmission = null;
    _runnerTransportAdmissionError = null;
    _runnerTransportAdmissionStale = false;
    _loadingRunnerTransportAdmission = false;
  }
}
