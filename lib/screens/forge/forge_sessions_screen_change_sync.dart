part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenChangeSync on _ForgeSessionsScreenState {
  Future<_ForgeChangeSyncOutcome> _syncChanges({bool stream = false}) async {
    if (_syncingChanges ||
        !mounted ||
        _sessionViewInvalidated ||
        _authorizationInvalidated) {
      return _ForgeChangeSyncOutcome.skipped;
    }
    _syncingChanges = true;
    try {
      // Refresh the selected client-instance projection before the owner
      // change feed can trigger Conversation, Prompt, or Run reads. A
      // changed session/resource declaration must revoke the old projection
      // before any private metadata is hydrated under it.
      if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
        return _ForgeChangeSyncOutcome.failed;
      }
      await _cursorReady;
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      final changes = <ForgeConversationChange>[];
      var nextCursor = _changeCursor;
      if (stream) {
        final page = await _api.conversationChangesStream(
          afterCursor: nextCursor,
          limit: ForgeConversationsApi.maxPageSize,
          waitMS: widget.conversationChangesStreamWaitMS,
        );
        if (!mounted) return _ForgeChangeSyncOutcome.skipped;
        if (page == null) {
          // A bounded 204 timeout is a successful read with no cursor
          // progress. The caller reconnects the stream without touching the
          // persisted cursor.
          if (_changeError != null) _update(() => _changeError = null);
          await _syncRunObservation();
          return _ForgeChangeSyncOutcome.unchanged;
        }
        if (page.scannedThroughCursor < nextCursor) {
          throw const FormatException('Forge change cursor regressed.');
        }
        nextCursor = page.scannedThroughCursor;
        changes.addAll(page.changes);
      } else {
        for (var pageNumber = 0; pageNumber < 4; pageNumber++) {
          final page = await _api.conversationChanges(
            afterCursor: nextCursor,
            limit: ForgeConversationsApi.maxPageSize,
          );
          if (!mounted) return _ForgeChangeSyncOutcome.skipped;
          if (page.scannedThroughCursor < nextCursor) {
            throw const FormatException('Forge change cursor regressed.');
          }
          nextCursor = page.scannedThroughCursor;
          changes.addAll(page.changes);
          if (!page.hasMore) break;
        }
      }
      if (_changeError != null) _update(() => _changeError = null);
      // The transport is deliberately owner-scoped, so the cursor must
      // advance across every row returned by the owner feed.  An explicitly
      // selected client instance is a narrower local projection, however:
      // rows whose Conversation is not declared by that instance must not
      // update the visible aggregate or trigger Prompt/Run hydration.  Keep
      // the two sets separate so hidden rows are acknowledged without being
      // rendered as instance-local activity.
      final visibleChanges = _conversationChangesVisibleFromSelectedInstance(
        changes,
      );
      if (visibleChanges.isEmpty) {
        if (nextCursor != _changeCursor) {
          // Persist owner-feed progress even when this page contained only
          // rows outside the selected instance.  This prevents hidden rows
          // from being replayed forever while keeping their private metadata
          // out of the selected projection.
          if (!await _changeCursorStore.save(nextCursor)) {
            return _ForgeChangeSyncOutcome.failed;
          }
          if (!mounted) return _ForgeChangeSyncOutcome.skipped;
          _changeCursor = nextCursor;
          return _ForgeChangeSyncOutcome.advancedHidden;
        }
        final selectedID = _selected?.conversation.id;
        if (_promptError != null && selectedID != null) {
          if (!await _loadPrompts(selectedID)) {
            return _ForgeChangeSyncOutcome.failed;
          }
        }
        await _syncRunObservation();
        return _ForgeChangeSyncOutcome.unchanged;
      }

      final latestByConversation = <String, ForgeConversationChange>{};
      var createdConversation = false;
      for (final change in visibleChanges) {
        final prior = latestByConversation[change.conversationID];
        if (prior == null || change.aggregateVersion > prior.aggregateVersion) {
          latestByConversation[change.conversationID] = change;
        }
        createdConversation |= change.kind == 'conversation_created';
      }
      final updated = _conversations
          .map((entry) {
            final change = latestByConversation[entry.conversation.id];
            if (change == null ||
                change.aggregateVersion <= entry.aggregateVersion) {
              return entry;
            }
            return _withConversationChange(entry, change);
          })
          .toList(growable: false);
      final loadedConversationIDs = _conversations
          .map((entry) => entry.conversation.id)
          .toSet();
      final hasUnloadedConversationChange = latestByConversation.keys.any(
        (conversationID) => !loadedConversationIDs.contains(conversationID),
      );
      final selectedID = _selected?.conversation.id;
      final selectedChange = selectedID == null
          ? null
          : latestByConversation[selectedID];
      _update(() {
        _conversations = updated;
        if (selectedChange != null &&
            selectedChange.aggregateVersion >
                (_selected?.aggregateVersion ?? 0)) {
          _selected = _withConversationChange(_selected!, selectedChange);
          _conversations = _replaceConversation(_conversations, _selected!);
        }
      });
      if (createdConversation || hasUnloadedConversationChange) {
        // A dense feed can contain a prompt append for a conversation outside
        // the currently loaded page. Advance the cursor only after a fresh
        // owner snapshot succeeds, otherwise that change could be consumed
        // without ever making the session metadata visible locally.
        if (!await _refreshConversations(loadPendingRunIntents: false)) {
          await _syncRunObservation();
          return _ForgeChangeSyncOutcome.failed;
        }
      } else if (selectedChange?.kind == 'prompt_appended') {
        if (!await _loadPrompts(selectedID!)) {
          await _syncRunObservation();
          return _ForgeChangeSyncOutcome.failed;
        }
      }
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      await _syncRunObservation();
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      await _loadPendingRunIntentsIfRequested(force: true);
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      // Persist the owner-local checkpoint before publishing it to the
      // in-process state. A storage failure must leave the old cursor in
      // memory so the next transport attempt replays the uncommitted page.
      if (!await _changeCursorStore.save(nextCursor)) {
        return _ForgeChangeSyncOutcome.failed;
      }
      if (!mounted) return _ForgeChangeSyncOutcome.skipped;
      _changeCursor = nextCursor;
      return _ForgeChangeSyncOutcome.changed;
    } catch (error) {
      await _clearSessionIfUnauthorized(error);
      if (mounted) {
        _update(() {
          _changeError = _friendlyError(
            error,
            'Could not sync Forge sessions.',
          );
        });
      }
      return _ForgeChangeSyncOutcome.failed;
    } finally {
      _syncingChanges = false;
    }
  }

  Future<void> _syncRunObservation() async {
    final conversationID = _selected?.conversation.id;
    if (conversationID == null || _loadingRuns || _loadingRunTimeline) return;
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) _update(_clearRunDetailsForHiddenClientInstance);
      return;
    }

    final runGeneration = _runGeneration;
    var timelineGeneration = _runTimelineGeneration;
    final selectedRunID = _selectedRun?.runID;
    bool isCurrent() =>
        mounted &&
        _selected?.conversation.id == conversationID &&
        _runGeneration == runGeneration &&
        _runTimelineGeneration == timelineGeneration &&
        _conversationVisibleFromSelectedClientInstance(conversationID);

    void revokeIfHidden() {
      if (mounted &&
          _selected?.conversation.id == conversationID &&
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        _update(_clearRunDetailsForHiddenClientInstance);
      }
    }

    late final ForgeConversationRunPage runPage;
    try {
      runPage = await _api.listRuns(conversationID: conversationID);
    } catch (error) {
      if (!mounted ||
          _selected?.conversation.id != conversationID ||
          _runGeneration != runGeneration ||
          _runTimelineGeneration != timelineGeneration ||
          !_conversationVisibleFromSelectedClientInstance(conversationID)) {
        revokeIfHidden();
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted || !isCurrent()) {
        revokeIfHidden();
        return;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return;
        _update(() {
          _runError = _friendlyError(error, 'Could not load runs.');
        });
        return;
      }
      _update(() {
        _runError = _friendlyError(error, 'Could not load runs.');
      });
      return;
    }
    if (!isCurrent()) {
      revokeIfHidden();
      return;
    }

    final mergedRuns = _uniqueRuns([..._runs, ...runPage.runs]);
    final selectedRun = selectedRunID == null
        ? (mergedRuns.isEmpty ? null : mergedRuns.first)
        : _findRun(mergedRuns, selectedRunID);
    final selectionChanged = selectedRun?.runID != selectedRunID;
    if (selectionChanged) {
      timelineGeneration = ++_runTimelineGeneration;
    }
    _update(() {
      _runs = mergedRuns;
      _selectedRun = selectedRun;
      _runCursor ??= runPage.nextCursor;
      _hasMoreRuns = _runCursor == null
          ? false
          : _hasMoreRuns || runPage.hasMore;
      _runError = null;
      if (selectionChanged) {
        _clearDeviceObservation();
        _clearRunObserved();
        _clearImportedRunObservations();
        _clearRunnerDispatchPlanPreview();
        _clearRunnerAttemptBoundaryPreview();
        _clearRunnerAttemptBoundary();
        _clearRunnerDispatchAdmission();
        _clearRunnerExecutionBoundary();
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
        _runTimelineError = null;
      }
    });
    if (selectedRun == null) return;

    var afterSequence = _runTimelineSequence;
    if (afterSequence == 0) {
      afterSequence = await _runTimelineCursor(
        conversationID,
        selectedRun.runID,
      ).load();
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) {
        revokeIfHidden();
        return;
      }
    }
    try {
      final timelinePage = await _api.listRunTimeline(
        conversationID: conversationID,
        runID: selectedRun.runID,
        afterSequence: afterSequence,
      );
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) {
        revokeIfHidden();
        return;
      }
      _update(() {
        _runEvents = _uniqueRunEvents([..._runEvents, ...timelinePage.events]);
        _runTimelineSequence = timelinePage.scannedThroughSequence;
        _hasMoreRunEvents = timelinePage.hasMore;
        _runTimelineError = null;
      });
      await _runTimelineCursor(
        conversationID,
        selectedRun.runID,
      ).save(timelinePage.scannedThroughSequence);
      await _loadDeviceObservationIfRequested(
        conversationID,
        selectedRun.runID,
      );
      await _loadRunObservedIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        // A scheduled change-feed poll can call this path without the outer
        // manual/resume refresh. Force the explicit reader so a selected Run
        // observation cannot remain cached after its timeline advances.
        force: true,
      );
      await _loadRunnerDispatchPlanPreviewIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadRunnerExecutionIntentIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadRunnerDispatchAdmissionIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadLocalRunnerPreviewIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadSessionRunnerReceiptHistoryIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
      await _loadSessionRunnerReconciliationProjectionIfRequested(
        conversationID: conversationID,
        runID: selectedRun.runID,
        force: true,
      );
    } catch (error) {
      if (!isCurrent() || _selectedRun?.runID != selectedRun.runID) {
        revokeIfHidden();
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted) return;
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return;
        _update(() {
          _runTimelineError = _friendlyError(
            error,
            'Could not load run timeline.',
          );
        });
        return;
      }
      _update(() {
        _runTimelineError = _friendlyError(
          error,
          'Could not load run timeline.',
        );
      });
    }
  }

  ForgeOwnedConversation _withConversationChange(
    ForgeOwnedConversation entry,
    ForgeConversationChange change,
  ) => ForgeOwnedConversation(
    conversation: ForgeConversation(
      id: entry.conversation.id,
      scope: entry.conversation.scope,
      title: entry.conversation.title,
      createdAtMS: entry.conversation.createdAtMS,
      updatedAtMS: change.createdAtMS > entry.conversation.updatedAtMS
          ? change.createdAtMS
          : entry.conversation.updatedAtMS,
    ),
    aggregateVersion: change.aggregateVersion,
  );
}
