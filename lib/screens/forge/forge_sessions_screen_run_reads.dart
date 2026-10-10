part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenRunReads on _ForgeSessionsScreenState {
  ForgeRunTimelineCursorStore _runTimelineCursor(
    String conversationID,
    String runID,
  ) => ForgeRunTimelineCursorStore(
    accessToken: widget.accessToken,
    apiOrigin: widget.apiOrigin,
    clientId: ForgeConversationsOAuth.clientId,
    resource: ForgeConversationsOAuth.resource,
    conversationID: conversationID,
    runID: runID,
  );

  Future<bool> _loadRuns(
    String conversationID, {
    bool loadOlder = false,
  }) async {
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) _update(_clearRunDetailsForHiddenClientInstance);
      return false;
    }
    if (_loadingRuns && loadOlder) return false;
    final generation = loadOlder ? _runGeneration : ++_runGeneration;
    _update(() {
      _loadingRuns = true;
      _runError = null;
    });
    try {
      final page = await _api.listRuns(
        conversationID: conversationID,
        before: loadOlder ? _runCursor : null,
      );
      if (!mounted ||
          generation != _runGeneration ||
          _selected?.conversation.id != conversationID) {
        return false;
      }
      final incoming = loadOlder ? [..._runs, ...page.runs] : page.runs;
      final merged = _uniqueRuns(incoming);
      final wantedRunID = _selectedRun?.runID;
      final selectedRun =
          _findRun(merged, wantedRunID) ??
          (merged.isEmpty ? null : merged.first);
      final previousRunID = _selectedRun?.runID;
      _update(() {
        _runs = merged;
        _runCursor = page.nextCursor;
        _hasMoreRuns = page.hasMore && page.nextCursor != null;
        _selectedRun = selectedRun;
        if (selectedRun?.runID != previousRunID) {
          _clearDeviceObservation();
          _clearRunAttemptLeaseDispatchPreflight();
          _clearRunnerDispatchPlanPreview();
          _clearRunnerAttemptBoundaryPreview();
          _clearRunnerAttemptBoundary();
          _clearRunnerDispatchAdmission();
          _clearExecutionReconciliation();
          _clearRunObserved();
          _clearImportedRunObservations();
        }
        _loadingRuns = false;
      });
      if (!loadOlder && selectedRun != null) {
        final timelineLoaded = await _loadRunTimeline(
          conversationID,
          selectedRun.runID,
        );
        if (!mounted) return false;
        await _loadDeviceObservationIfRequested(
          conversationID,
          selectedRun.runID,
        );
        await _loadRunObservedIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunAttemptLeaseDispatchPreflightIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerDispatchPlanPreviewIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerExecutionIntentIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerDispatchAdmissionIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadRunnerAttemptBoundaryIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        await _loadExecutionReconciliationIfRequested(
          conversationID: conversationID,
          runID: selectedRun.runID,
        );
        return timelineLoaded;
      }
      if (selectedRun == null) {
        _update(_clearDeviceObservation);
        _update(_clearRunObserved);
        _update(_clearExecutionReconciliation);
        _update(() {
          _runTimelineGeneration++;
          _loadingRunTimeline = false;
          _runEvents = const [];
          _runTimelineSequence = 0;
          _hasMoreRunEvents = false;
          _runTimelineError = null;
        });
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted || (!authorizationFailure && generation != _runGeneration)) {
        return false;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return false;
        _update(() {
          _runError = _friendlyError(error, 'Could not load runs.');
          _loadingRuns = false;
        });
        return false;
      }
      _update(() {
        _runError = _friendlyError(error, 'Could not load runs.');
        _loadingRuns = false;
      });
      return false;
    }
  }

  Future<bool> _loadRunTimeline(
    String conversationID,
    String runID, {
    bool loadMore = false,
  }) async {
    // A local client-instance projection is a read boundary for the complete
    // Run surface. Check it again here because a timeline load can outlive the
    // conversation tile that started it while the instance filter changes.
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) _update(_clearRunDetailsForHiddenClientInstance);
      return false;
    }
    if (_loadingRunTimeline && loadMore) return false;
    final generation = loadMore
        ? _runTimelineGeneration
        : ++_runTimelineGeneration;
    // A manual reload with rendered events must still request from sequence 0
    // so the panel can rebuild its complete visible timeline. Checkpoints are
    // used when entering a Run after cold start or selection recovery, while
    // the periodic sync path already has the in-memory sequence.
    final resumeFromCheckpoint = !loadMore && _runEvents.isEmpty;
    var afterSequence = loadMore ? _runTimelineSequence : 0;
    if (resumeFromCheckpoint) {
      afterSequence = await _runTimelineCursor(conversationID, runID).load();
      if (!mounted || generation != _runTimelineGeneration) return false;
    }
    _update(() {
      _loadingRunTimeline = true;
      _runTimelineError = null;
      if (!loadMore) {
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
      }
    });
    try {
      final page = await _api.listRunTimeline(
        conversationID: conversationID,
        runID: runID,
        afterSequence: afterSequence,
      );
      if (!mounted ||
          generation != _runTimelineGeneration ||
          _selected?.conversation.id != conversationID ||
          _selectedRun?.runID != runID ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        return false;
      }
      _update(() {
        _runEvents = _uniqueRunEvents(
          loadMore ? [..._runEvents, ...page.events] : page.events,
        );
        _runTimelineSequence = page.scannedThroughSequence;
        _hasMoreRunEvents = page.hasMore;
        _loadingRunTimeline = false;
      });
      await _runTimelineCursor(
        conversationID,
        runID,
      ).save(page.scannedThroughSequence);
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          (!authorizationFailure && generation != _runTimelineGeneration)) {
        return false;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return false;
        _update(() {
          _runTimelineError = _friendlyError(
            error,
            'Could not load run timeline.',
          );
          _loadingRunTimeline = false;
        });
        return false;
      }
      if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
        if (mounted) _update(_clearRunDetailsForHiddenClientInstance);
        return false;
      }
      _update(() {
        _runTimelineError = _friendlyError(
          error,
          'Could not load run timeline.',
        );
        _loadingRunTimeline = false;
      });
      return false;
    }
  }

  Future<void> _selectRun(ForgeConversationRun run) async {
    final conversationID = _selected?.conversation.id;
    if (conversationID == null || _selectedRun?.runID == run.runID) return;
    _update(() {
      _runTimelineGeneration++;
      _loadingRunTimeline = false;
      _clearDeviceObservation();
      _clearRunObserved();
      _clearRunExecutionEvidence();
      _clearSessionRunnerReceiptHistory();
      _clearSessionRunnerReconciliationProjection();
      _clearRunnerAttemptBoundaryPreview();
      _importedRunnerExecutionIntentObservation = null;
      _importedSessionRunnerReceiptObservation = null;
      _selectedRun = run;
      _runEvents = const [];
      _runTimelineSequence = 0;
      _hasMoreRunEvents = false;
      _runTimelineError = null;
    });
    await _loadRunTimeline(conversationID, run.runID);
    if (!mounted) return;
    await _loadDeviceObservationIfRequested(conversationID, run.runID);
    await _loadRunObservedIfRequested(
      conversationID: conversationID,
      runID: run.runID,
    );
    await _loadRunExecutionEvidenceIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
    await _loadSessionRunnerReceiptHistoryIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
    await _loadSessionRunnerReconciliationProjectionIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
    await _loadRunnerAttemptBoundaryIfRequested(
      conversationID: conversationID,
      runID: run.runID,
      force: true,
    );
  }
}
