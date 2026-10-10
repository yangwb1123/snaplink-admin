part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenSchedulerPreview on _ForgeSessionsScreenState {
  Future<void> _loadSchedulerSelectionPreviewIfRequested({
    bool force = false,
  }) async {
    final request = widget.schedulerSelectionPreviewRequest;
    final reader = widget.schedulerSelectionPreviewReader;
    if (!mounted || _sessionViewInvalidated || _authorizationInvalidated) {
      return;
    }
    if (request == null || reader == null) {
      if (mounted &&
          (_fetchedSchedulerSelectionPreview != null ||
              _schedulerSelectionPreviewError != null ||
              _loadingSchedulerSelectionPreview)) {
        _update(_clearSchedulerSelectionPreview);
      }
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionPreview != null ||
              _schedulerSelectionPreviewError != null ||
              _loadingSchedulerSelectionPreview)) {
        _update(_clearSchedulerSelectionPreview);
      }
      return;
    }
    // Keep an explicit scheduler preview scoped to the Run currently selected
    // by the Sessions surface. A request may be configured before the first
    // owner snapshot (so an empty/default Gate remains compatible), but once
    // the screen has a selected Conversation or Run, a different binding is
    // stale and must not reach the candidate route.
    final selectedConversationID = _selected?.conversation.id;
    final selectedRunID = _selectedRun?.runID;
    if ((selectedConversationID != null &&
            selectedConversationID != request.conversationID) ||
        (selectedRunID != null && selectedRunID != request.runID)) {
      if (mounted &&
          (_fetchedSchedulerSelectionPreview != null ||
              _schedulerSelectionPreviewError != null ||
              _loadingSchedulerSelectionPreview)) {
        _update(_clearSchedulerSelectionPreview);
      }
      return;
    }
    if (_loadingSchedulerSelectionPreview) return;
    if (!force &&
        (_fetchedSchedulerSelectionPreview != null ||
            _schedulerSelectionPreviewError != null)) {
      return;
    }
    if (!await _refreshSelectedClientInstanceProjectionBeforeOwnerReads()) {
      if (mounted) {
        _update(() {
          _fetchedSchedulerSelectionPreview = null;
          _schedulerSelectionPreviewError =
              'Scheduler selection preview is waiting for a fresh validated client-instance session/resource observation.';
          _schedulerSelectionPreviewStale = false;
        });
      }
      return;
    }
    if (!_schedulerSelectionRequestVisible(request.conversationID)) {
      if (mounted) _update(_clearSchedulerSelectionPreview);
      return;
    }
    if (_selected?.conversation.id != null &&
        _selected?.conversation.id != request.conversationID) {
      if (mounted) _update(_clearSchedulerSelectionPreview);
      return;
    }
    if (_selectedRun?.runID != null && _selectedRun?.runID != request.runID) {
      if (mounted) _update(_clearSchedulerSelectionPreview);
      return;
    }
    final observationError =
        await _refreshInventoryResourceObservationsBeforeOperation(
          'Scheduler selection preview',
          force: true,
        );
    if (observationError != null) {
      if (mounted) {
        _update(() {
          _fetchedSchedulerSelectionPreview = null;
          _schedulerSelectionPreviewError = observationError;
          _schedulerSelectionPreviewStale = false;
        });
      }
      return;
    }
    final previousPreview = _fetchedSchedulerSelectionPreview;
    final generation = ++_schedulerSelectionPreviewGeneration;
    _update(() {
      _loadingSchedulerSelectionPreview = true;
      _schedulerSelectionPreviewError = null;
      _schedulerSelectionPreviewStale = previousPreview != null;
    });
    try {
      final expectedRequest = ForgeSchedulerSelectionPreviewRequest.fromJson(
        request.toJson(),
      );
      final preview = ForgeSchedulerSelectionPreview.fromJson(
        (await reader(expectedRequest)).toJson(),
      );
      if (!preview.isFor(
            expectedRequest.conversationID,
            expectedRequest.runID,
          ) ||
          preview.attemptID != expectedRequest.attemptID ||
          preview.authority.anyGranted ||
          !preview.previewOnly) {
        throw const FormatException(
          'Forge returned an invalid scheduler selection preview.',
        );
      }
      if (!_schedulerSelectionTargetMatchesResources(preview)) {
        throw const FormatException(
          'Forge returned a scheduler target absent from the current resource observation.',
        );
      }
      if (!mounted ||
          generation != _schedulerSelectionPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSchedulerSelectionPreview = preview;
        _schedulerSelectionPreviewError = null;
        _schedulerSelectionPreviewStale = false;
        _loadingSchedulerSelectionPreview = false;
      });
    } catch (error) {
      if (!mounted || generation != _schedulerSelectionPreviewGeneration) {
        return;
      }
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          generation != _schedulerSelectionPreviewGeneration ||
          _authorizationInvalidated) {
        return;
      }
      _update(() {
        _fetchedSchedulerSelectionPreview = previousPreview;
        _schedulerSelectionPreviewError = _friendlyError(
          error,
          'Could not load scheduler selection preview.',
        );
        _schedulerSelectionPreviewStale = previousPreview != null;
        _loadingSchedulerSelectionPreview = false;
      });
    }
  }

  void _clearSchedulerSelectionPreview() {
    _schedulerSelectionPreviewGeneration++;
    _fetchedSchedulerSelectionPreview = null;
    _schedulerSelectionPreviewError = null;
    _schedulerSelectionPreviewStale = false;
    _loadingSchedulerSelectionPreview = false;
  }

  /// Keeps scheduler candidates inside the same local instance projection as
  /// Conversations and Prompt writes. A selected instance with no validated
  /// rows fails closed, so a refresh gap cannot broaden a candidate POST.
  bool _schedulerSelectionRequestVisible(String conversationID) =>
      _conversationVisibleFromSelectedClientInstance(conversationID);
}
