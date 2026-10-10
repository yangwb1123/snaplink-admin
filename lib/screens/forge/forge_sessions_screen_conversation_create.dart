part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenConversationCreate on _ForgeSessionsScreenState {
  Future<void> _createConversation() async {
    if (_creating || _appending || _pendingPrompt != null) return;
    final pending = _pendingCreate ?? _readCreateRequest();
    if (pending == null) return;
    _update(() {
      _pendingCreate = pending;
      _creating = true;
      _createError = null;
    });
    // A selected client instance is a local display projection. Refresh its
    // owner-bound observation before creating so a reader gap cannot turn the
    // owner-wide storage write into a private instance selection.
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (!mounted) return;
      _update(() {
        _creating = false;
        _createError =
            'Conversation create is blocked until the selected client instance is observed.';
      });
      return;
    }
    try {
      final created = await _api.createConversation(
        scope: pending.scope,
        title: pending.title,
        idempotencyKey: pending.idempotencyKey,
      );
      if (!mounted) return;
      final createdVisible = _conversationIDDeclaredBySelectedClientInstance(
        created.id,
      );
      final previousSelection = _selected;
      final retainedSelection =
          previousSelection != null &&
              _conversationIDDeclaredBySelectedClientInstance(
                previousSelection.conversation.id,
              )
          ? previousSelection
          : null;
      // A new conversation's creation event establishes aggregate version 1.
      final selected = ForgeOwnedConversation(
        conversation: created,
        aggregateVersion: 1,
      );
      _update(() {
        _runGeneration++;
        _runTimelineGeneration++;
        _clearDeviceObservation();
        _clearPendingRunIntents();
        _clearImportedRunObservations();
        _loadingRuns = false;
        _loadingRunTimeline = false;
        _pendingCreate = null;
        _pendingPrompt = null;
        _creating = false;
        _appendError = null;
        _titleController.clear();
        _scopeIDController.clear();
        _selected = createdVisible ? selected : retainedSelection;
        _createError = createdVisible
            ? null
            : 'Created conversation "${created.id}", but the selected client instance has not declared it yet.';
        _conversations = _mergeConversations(
          incoming: [selected, ..._conversations],
          existing: const [],
          append: false,
        );
        _prompts = const [];
        _promptCursor = null;
        _runs = const [];
        _runCursor = null;
        _hasMoreRuns = false;
        _selectedRun = null;
        _runEvents = const [];
        _runTimelineSequence = 0;
        _hasMoreRunEvents = false;
      });
      if (!createdVisible) {
        if (retainedSelection != null) {
          _updateConversationLocation(retainedSelection.conversation.id);
        }
        return;
      }
      _updateConversationLocation(created.id);
      await _loadPrompts(created.id);
      await _loadRuns(created.id);
      await _loadPendingRunIntentsIfRequested();
    } catch (error) {
      if (!mounted) return;
      await _clearSessionIfUnauthorized(error);
      final terminal = _isDefinitiveWriteFailure(error);
      _update(() {
        if (terminal) _pendingCreate = null;
        _createError = _friendlyError(
          error,
          'Forge did not confirm conversation creation.',
        );
        _creating = false;
      });
    }
  }

  _PendingCreate? _readCreateRequest() {
    final title = _titleController.text.trim();
    final scopeID = _scopeIDController.text.trim();
    if (title.isEmpty) {
      _update(() => _createError = 'Enter a conversation title.');
      return null;
    }
    if (_scopeKind != 'global' && scopeID.isEmpty) {
      _update(() => _createError = 'Enter a project or group ID.');
      return null;
    }
    return _PendingCreate(
      title: title,
      scope: ForgeConversationScope(
        kind: _scopeKind,
        id: _scopeKind == 'global' ? null : scopeID,
      ),
      idempotencyKey: newForgeIdempotencyKey(),
    );
  }

  Future<void> _selectConversation(
    ForgeOwnedConversation value, {
    bool updateLocation = true,
    int? locationGeneration,
  }) async {
    if (!_conversationVisibleFromSelectedClientInstance(
      value.conversation.id,
    )) {
      return;
    }
    if (_appending ||
        _pendingPrompt != null ||
        (!_clientInstanceFilterNeedsPrivateReload &&
            _selected?.conversation.id == value.conversation.id)) {
      return;
    }
    _update(() {
      _runGeneration++;
      _runTimelineGeneration++;
      _clearDeviceObservation();
      _clearRunAttemptLeaseDispatchPreflight();
      _clearRunnerDispatchPlanPreview();
      _clearRunnerAttemptBoundaryPreview();
      _clearRunnerAttemptBoundary();
      _clearRunnerDispatchAdmission();
      _clearExecutionReconciliation();
      _clearExecutionConsentPreview();
      _clearPendingRunIntents();
      _clearImportedRunObservations();
      _loadingRuns = false;
      _loadingRunTimeline = false;
      _selected = value;
      _prompts = const [];
      _promptCursor = null;
      _hasMorePrompts = false;
      _promptError = null;
      _appendError = null;
      _pendingPrompt = null;
      _pendingRunIntentSubmission = null;
      _pendingRunIntentRequest = null;
      _pendingRunIntentSubmitError = null;
      _submittingPendingRunIntent = false;
      _runs = const [];
      _runCursor = null;
      _hasMoreRuns = false;
      _selectedRun = null;
      _runEvents = const [];
      _runTimelineSequence = 0;
      _hasMoreRunEvents = false;
      _runError = null;
      _runTimelineError = null;
    });
    if (updateLocation) {
      _updateConversationLocation(value.conversation.id);
    }
    final promptsLoaded = await _loadPrompts(value.conversation.id);
    if (!mounted ||
        (locationGeneration != null &&
            locationGeneration != _locationSelectionGeneration) ||
        _selected?.conversation.id != value.conversation.id ||
        !promptsLoaded) {
      return;
    }
    await _loadRuns(value.conversation.id);
    await _loadExecutionConsentPreviewIfRequested(
      conversationID: value.conversation.id,
    );
    await _loadPendingRunIntentsIfRequested();
  }
}
