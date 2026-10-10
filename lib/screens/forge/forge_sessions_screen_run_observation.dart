part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenRunObservation on _ForgeSessionsScreenState {
  Future<void> _loadRunObservedIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.runObservedReader;
    final receiptReader = widget.sessionRunnerReceiptObservationReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null || conversationID == null || runID == null) {
      if (mounted &&
          (_fetchedRunObserved != null ||
              _runObservedError != null ||
              _loadingRunObserved ||
              _runObservedStale)) {
        _update(_clearRunObserved);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunObserved) return;
    if (!force && (_fetchedRunObserved != null || _runObservedError != null)) {
      return;
    }
    final previous = _fetchedRunObserved;
    final pairedRead = receiptReader != null;
    final selectedRun = _selectedRun;
    final generation = ++_runObservedGeneration;
    _update(() {
      _loadingRunObserved = true;
      _runObservedError = null;
      _runObservedStale = !pairedRead && previous != null;
      if (pairedRead) {
        // A paired refresh is fail-closed: never leave either half of the
        // previous independently read snapshot visible while refreshing.
        _fetchedRunObserved = null;
        _fetchedSessionRunnerReceiptObservation = null;
      }
    });
    try {
      // Re-decode the callback result through the strict wire boundary. This
      // prevents a caller-created model from bypassing the display-only
      // authority and content checks.
      final rawValues = await Future.wait<Object>([
        reader(conversationID, runID),
        if (receiptReader != null) receiptReader(conversationID, runID),
      ]);
      var observation = ForgeRunObserved.fromJson(
        (rawValues.first as ForgeRunObserved).toJson(),
      );
      ForgeSessionRunnerReceiptObservation? receiptObservation;
      if (receiptReader != null) {
        if (selectedRun == null || selectedRun.runID != runID) {
          throw const FormatException(
            'The selected Run changed before its observations converged.',
          );
        }
        final convergence =
            ForgeRunReceiptObservationConvergence.fromObservations(
              runObserved: observation,
              receiptObserved:
                  rawValues[1] as ForgeSessionRunnerReceiptObservation,
              conversationID: conversationID,
              runID: runID,
              promptID: selectedRun.promptID,
              runCreatedAtMS: selectedRun.createdAtMS,
              runLatestSequence: selectedRun.latestSequence,
              runStatus: selectedRun.status,
            );
        observation = convergence.runObserved;
        receiptObservation = convergence.receiptObserved;
      } else if (!observation.isFor(conversationID, runID) ||
          !observation.isDisplayOnly) {
        throw const FormatException(
          'Forge returned an invalid or differently bound Run observation.',
        );
      }
      if (!mounted ||
          generation != _runObservedGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunObserved = observation;
        _fetchedSessionRunnerReceiptObservation = receiptObservation;
        _runObservedError = null;
        _runObservedStale = false;
        _loadingRunObserved = false;
      });
      unawaited(
        _loadRunExecutionEvidenceIfRequested(
          conversationID: conversationID,
          runID: runID,
          force: true,
        ),
      );
    } catch (error) {
      if (!mounted || generation != _runObservedGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted) return;
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return;
        _update(() {
          _runObservedError = _friendlyError(
            error,
            'Could not load Run metadata observation.',
          );
        });
        return;
      }
      if (!mounted ||
          generation != _runObservedGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunObserved = pairedRead ? null : previous;
        if (pairedRead) _fetchedSessionRunnerReceiptObservation = null;
        _runObservedError = _friendlyError(
          error,
          pairedRead
              ? 'Could not converge Run and Runner receipt observations.'
              : 'Could not load Run metadata observation.',
        );
        _runObservedStale = !pairedRead && previous != null;
        _loadingRunObserved = false;
      });
    }
  }

  void _clearRunObserved() {
    _runObservedGeneration++;
    _fetchedRunObserved = null;
    _fetchedSessionRunnerReceiptObservation = null;
    _runObservedError = null;
    _runObservedStale = false;
    _loadingRunObserved = false;
  }

  Future<void> _loadRunExecutionEvidenceIfRequested({
    String? conversationID,
    String? runID,
    bool force = false,
  }) async {
    final reader = widget.runExecutionEvidenceReader;
    conversationID ??= _selected?.conversation.id;
    runID ??= _selectedRun?.runID;
    final fetchedRun = _fetchedRunObserved;
    final pairedReaderEnabled =
        widget.sessionRunnerReceiptObservationReader != null;
    final sourceRun =
        fetchedRun?.isFor(conversationID ?? '', runID ?? '') == true
        ? fetchedRun
        : pairedReaderEnabled
        ? null
        : widget.runObserved;
    final sourceReceipt = pairedReaderEnabled
        ? _fetchedSessionRunnerReceiptObservation
        : _fetchedSessionRunnerReceiptObservation ??
              widget.sessionRunnerReceiptObservation;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (reader == null ||
        sourceRun == null ||
        sourceReceipt == null ||
        conversationID == null ||
        runID == null) {
      if (mounted &&
          (_fetchedRunExecutionEvidence != null ||
              _runExecutionEvidenceError != null ||
              _loadingRunExecutionEvidence ||
              _runExecutionEvidenceStale)) {
        _update(_clearRunExecutionEvidence);
      }
      return;
    }
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }
    if (_loadingRunExecutionEvidence) return;
    if (!force &&
        (_fetchedRunExecutionEvidence != null ||
            _runExecutionEvidenceError != null)) {
      return;
    }
    final previous = _fetchedRunExecutionEvidence;
    final generation = ++_runExecutionEvidenceGeneration;
    _update(() {
      _loadingRunExecutionEvidence = true;
      _runExecutionEvidenceError = null;
      _runExecutionEvidenceStale = previous != null;
    });
    try {
      final validatedRun = ForgeRunObserved.fromJson(sourceRun.toJson());
      final validatedReceipt = ForgeSessionRunnerReceiptObservation.fromJson(
        sourceReceipt.toJson(),
      );
      if (!validatedRun.isFor(conversationID, runID) ||
          !validatedReceipt.isFor(conversationID, runID) ||
          validatedRun.promptID != validatedReceipt.promptID ||
          !validatedRun.isDisplayOnly ||
          !validatedReceipt.isDisplayOnly) {
        throw const FormatException(
          'Forge Run execution-evidence sources are not bound to the selected Run.',
        );
      }
      final evidence = ForgeRunExecutionEvidence.fromJson(
        (await reader(
          conversationID,
          runID,
          validatedRun,
          validatedReceipt,
        )).toJson(),
      );
      final receipt = validatedReceipt.receiptObservation;
      if (!evidence.isFor(conversationID, runID) ||
          evidence.ownerRef != validatedRun.ownerRef ||
          evidence.promptID != validatedRun.promptID ||
          evidence.runStatus != validatedRun.status ||
          evidence.attemptID != receipt.attemptID ||
          evidence.targetID != receipt.targetID ||
          evidence.commandID != receipt.commandID ||
          evidence.commandSHA256 != receipt.commandSHA256 ||
          evidence.dispositionKind != receipt.dispositionKind ||
          evidence.receiptObservedAtMS != receipt.observedAtMS ||
          evidence.uncertain != receipt.uncertain ||
          evidence.reconciliationRequired != receipt.reconciliationRequired ||
          !evidence.isDisplayOnly) {
        throw const FormatException(
          'Forge returned another or authority-bearing Run execution evidence.',
        );
      }
      if (!mounted ||
          generation != _runExecutionEvidenceGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunExecutionEvidence = evidence;
        _runExecutionEvidenceError = null;
        _runExecutionEvidenceStale = false;
        _loadingRunExecutionEvidence = false;
      });
    } catch (error) {
      if (!mounted || generation != _runExecutionEvidenceGeneration) return;
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _runExecutionEvidenceGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID) ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedRunExecutionEvidence = previous;
        _runExecutionEvidenceError = _friendlyError(
          error,
          'Could not load Run execution-evidence preview.',
        );
        _runExecutionEvidenceStale = previous != null;
        _loadingRunExecutionEvidence = false;
      });
    }
  }

  void _clearRunExecutionEvidence() {
    _runExecutionEvidenceGeneration++;
    _fetchedRunExecutionEvidence = null;
    _runExecutionEvidenceError = null;
    _runExecutionEvidenceStale = false;
    _loadingRunExecutionEvidence = false;
  }
}
