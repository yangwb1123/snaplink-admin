part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenConversationReads on _ForgeSessionsScreenState {
  Future<bool> _refreshConversations({
    bool loadMore = false,
    String? selectID,
    bool loadPendingRunIntents = true,
  }) async {
    if (_loadingConversations && !loadMore) return false;
    final generation = ++_conversationGeneration;
    final clientInstanceFilterGeneration = _clientInstanceFilterGeneration;
    var resolvingOwnerSelection = false;
    var revalidatingCurrentSelection = false;
    ForgeConversationPage? loadedPage;
    var loadedConversations = const <ForgeOwnedConversation>[];
    _update(() {
      _loadingConversations = true;
      _conversationError = null;
    });
    try {
      final page = await _api.listConversations(
        afterID: loadMore ? _nextAfterID : null,
      );
      loadedPage = page;
      if (!mounted || generation != _conversationGeneration) return false;
      var merged = _mergeConversations(
        incoming: page.conversations,
        existing: _conversations,
        append: loadMore,
      );
      loadedConversations = merged;
      final hasPendingSelection = _hasPendingLocationSelection;
      final pendingSelectionID = _takePendingLocationSelection();
      final wantedID = hasPendingSelection
          ? pendingSelectionID
          : selectID ?? _selected?.conversation.id;
      var selected = _findConversation(merged, wantedID);
      final canResolveOwnerSelection =
          _selectedClientInstanceID == null ||
          _conversationIDDeclaredBySelectedClientInstance(wantedID);
      if (selected == null &&
          wantedID != null &&
          (selectID != null || hasPendingSelection) &&
          !loadMore &&
          canResolveOwnerSelection) {
        // A deep link can point to an older session outside the first page.
        // Fetch only its owner-filtered metadata; this remains a read-only
        // selection and does not alter pagination or write authority.
        resolvingOwnerSelection = true;
        final linked = await _api.getConversation(conversationID: wantedID);
        resolvingOwnerSelection = false;
        if (!mounted || generation != _conversationGeneration) return false;
        merged = _mergeConversations(
          incoming: [linked, ...merged],
          existing: const [],
          append: false,
        );
        loadedConversations = merged;
        selected = linked;
      }
      if (selected == null &&
          !loadMore &&
          !hasPendingSelection &&
          selectID == null &&
          _selected != null) {
        // The first page can legitimately omit an older selected session, but
        // it can also omit one that was deleted or revoked. Re-read the
        // missing row through the authenticated owner detail path before
        // retaining it; blindly merging the previous selection would keep a
        // deleted session visible and permit stale Prompt/Run reads.
        final currentID = _selected!.conversation.id;
        if (_conversationIDDeclaredBySelectedClientInstance(currentID)) {
          revalidatingCurrentSelection = true;
          final linked = await _api.getConversation(conversationID: currentID);
          revalidatingCurrentSelection = false;
          if (!mounted || generation != _conversationGeneration) return false;
          merged = _mergeConversations(
            incoming: [linked, ...merged],
            existing: const [],
            append: false,
          );
          loadedConversations = merged;
          selected = _findConversation(merged, currentID);
        }
      }
      if (!hasPendingSelection && selectID == null) {
        selected ??= _selected;
        selected ??= merged.isEmpty ? null : merged.first;
      }
      final filterChanged =
          clientInstanceFilterGeneration != _clientInstanceFilterGeneration;
      if (filterChanged) {
        // A local instance selection happened while the owner page was in
        // flight. Preserve the selection chosen by that filter operation and
        // let it own Prompt/Run hydration; do not restore the stale page
        // selection from before the filter changed.
        selected = _selected;
      }
      if (!filterChanged && _selectedClientInstanceID != null) {
        // An instance deep link is a local projection boundary. Select only
        // a session declared by that observation, and keep private
        // Prompt/Run readers idle when the declaration is unavailable or
        // does not contain the requested session.
        final visible = _conversationsForClientInstance(
          merged,
          _declaredClientInstanceRows(),
          _selectedClientInstanceID,
        );
        selected =
            _findConversation(visible, selected?.conversation.id) ??
            (visible.isEmpty ? null : visible.first);
      }
      _update(() {
        _conversations = merged;
        _nextAfterID = page.nextAfterID;
        _hasMoreConversations = page.hasMore && page.nextAfterID != null;
        _selected = selected;
        _conversationsStale = false;
        _loadingConversations = false;
      });
      await _conversationMetadataCache.save(merged);
      if (!mounted || generation != _conversationGeneration) return false;
      if (!loadMore && selected != null && !filterChanged) {
        await _loadPrompts(selected.conversation.id);
        final runsLoaded = await _loadRuns(selected.conversation.id);
        await _loadExecutionConsentPreviewIfRequested(
          conversationID: selected.conversation.id,
        );
        if (loadPendingRunIntents) {
          await _loadPendingRunIntentsIfRequested();
        }
        return runsLoaded;
      } else if (selected == null || filterChanged) {
        if (filterChanged) return true;
        _update(() {
          _prompts = const [];
          _promptCursor = null;
          _hasMorePrompts = false;
          _runs = const [];
          _runCursor = null;
          _hasMoreRuns = false;
          _selectedRun = null;
          _runEvents = const [];
          _runTimelineSequence = 0;
          _hasMoreRunEvents = false;
          _loadingRuns = false;
          _loadingRunTimeline = false;
        });
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          (!authorizationFailure && generation != _conversationGeneration)) {
        return false;
      }
      if (authorizationFailure) {
        _update(() {
          _conversationError = _friendlyError(
            error,
            'Could not load Forge sessions.',
          );
          _loadingConversations = false;
        });
        return false;
      }
      // A same-document URL is only a selection hint. When its owner-scoped
      // detail lookup fails, keep the last successfully rendered session
      // snapshot and its Prompt/Run state instead of treating that failure as
      // a failed list read. The user can still retry through the normal
      // refresh path, while the inaccessible ID never becomes selected.
      final current = _conversations;
      if (resolvingOwnerSelection && current.isNotEmpty) {
        _update(() {
          _conversationError = _friendlyError(
            error,
            'Could not open the requested Forge session.',
          );
          _conversationsStale = false;
          _loadingConversations = false;
        });
        return false;
      }
      if (revalidatingCurrentSelection) {
        // The owner list was read successfully, but the missing selected row
        // could not be revalidated. Keep only the fresh list and clear all
        // private details, so a 404/foreign response or a transient detail
        // failure cannot leave the old session selected.
        final selectedID = _selected?.conversation.id;
        final fresh = loadedConversations
            .where((entry) => entry.conversation.id != selectedID)
            .toList(growable: false);
        _update(() {
          _conversations = List.unmodifiable(fresh);
          _nextAfterID = loadedPage?.nextAfterID;
          _hasMoreConversations =
              loadedPage?.hasMore == true && loadedPage?.nextAfterID != null;
          _selected = null;
          _conversationsStale = false;
          _conversationError = _friendlyError(
            error,
            'Could not verify the selected Forge session.',
          );
          _loadingConversations = false;
          _clearConversationDetails();
        });
        return false;
      }
      final canFallback = _canUseConversationMetadataCache(error);
      final cached = canFallback
          ? await _conversationMetadataCache.load()
          : null;
      if (!mounted) return false;
      // A failed older page must not discard the already rendered first page;
      // it is still authoritative local state and can be retried with the
      // same cursor. Deterministic failures on the initial snapshot clear
      // the list below instead of presenting it as an offline fallback.
      if (!canFallback && loadMore && current.isNotEmpty) {
        _update(() {
          _conversationError = _friendlyError(
            error,
            'Could not load Forge sessions.',
          );
          _conversationsStale = false;
          _loadingConversations = false;
        });
        return false;
      }
      final fallback = canFallback && current.isNotEmpty
          ? current
          : canFallback
          ? cached?.conversations
          : null;
      if (fallback != null) {
        final visibleFallback = _selectedClientInstanceID == null
            ? fallback
            : _conversationsForClientInstance(
                    fallback,
                    _declaredClientInstanceRows(),
                    _selectedClientInstanceID,
                  )
                  .where(
                    (entry) => fallback.any(
                      (candidate) =>
                          candidate.conversation.id == entry.conversation.id,
                    ),
                  )
                  .toList(growable: false);
        final selected =
            _findConversation(visibleFallback, _selected?.conversation.id) ??
            (visibleFallback.isEmpty ? null : visibleFallback.first);
        final restoringSnapshot = current.isEmpty;
        _update(() {
          _conversations = fallback;
          if (restoringSnapshot) {
            _nextAfterID = null;
            _hasMoreConversations = false;
          }
          _selected = selected;
          _conversationsStale = true;
          _conversationError = null;
          _loadingConversations = false;
          if (restoringSnapshot) _clearConversationDetails();
        });
        return false;
      }
      _update(() {
        if (!canFallback) {
          _conversations = const [];
          _selected = null;
          _nextAfterID = null;
          _hasMoreConversations = false;
          _clearConversationDetails();
        }
        _conversationError = _friendlyError(
          error,
          'Could not load Forge sessions.',
        );
        _conversationsStale = false;
        _loadingConversations = false;
      });
      return false;
    }
  }

  Future<void> _refreshAndSync() async {
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    final syncOutcome = await _syncChanges();
    final pendingReadDuringSync =
        syncOutcome == _ForgeChangeSyncOutcome.changed;
    if (syncOutcome == _ForgeChangeSyncOutcome.unchanged ||
        syncOutcome == _ForgeChangeSyncOutcome.changed) {
      _changePollFailureStreak = 0;
      _changePollDelay = _changePollBaseDelay;
    }
    if (mounted &&
        syncOutcome != _ForgeChangeSyncOutcome.advancedHidden &&
        _selectedClientInstanceProjectionReadyForOwnerReads()) {
      await _refreshConversations(loadPendingRunIntents: false);
    }
    if (mounted &&
        syncOutcome != _ForgeChangeSyncOutcome.advancedHidden &&
        (!pendingReadDuringSync || _fetchedPendingRunIntents == null)) {
      await _loadPendingRunIntentsIfRequested(force: true);
    }
    await Future.wait([
      _loadDeviceInventoryIfRequested(force: true),
      _loadDeviceInventoryV2IfRequested(force: true),
      _loadDeviceInventoryRegistryPlacementPreviewIfRequested(force: true),
    ]);
    await _loadSchedulerSelectionPreviewIfRequested(force: true);
    if (_selectedClientInstanceID == null) {
      await _loadClientInstanceSessionResourceConvergenceIfRequested(
        force: true,
      );
      await _loadClientInstanceSessionViewIfRequested(force: true);
      await _loadClientInstanceResourceViewIfRequested(force: true);
    }
    await _loadLifecycleRegistryIfRequested(force: true);
    await _loadExecutionConsentPreviewIfRequested(force: true);
    await _loadRunObservedIfRequested(force: true);
    await _loadRunAttemptLeaseDispatchPreflightIfRequested(force: true);
    await _loadRunnerDispatchPlanPreviewIfRequested(force: true);
    await _loadRunnerExecutionIntentIfRequested(force: true);
    await _loadRunnerDispatchAdmissionIfRequested(force: true);
    await _loadRunnerAttemptBoundaryIfRequested(force: true);
    await _loadLocalRunnerPreviewIfRequested(force: true);
    await _loadExecutionReconciliationIfRequested(force: true);
  }
}
