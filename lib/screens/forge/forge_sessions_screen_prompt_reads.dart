part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenPromptReads on _ForgeSessionsScreenState {
  bool _canUseConversationMetadataCache(Object error) =>
      error is ForgeConversationsApiException &&
      (error.statusCode == 0 || error.statusCode >= 500);

  Future<bool> _loadPrompts(
    String conversationID, {
    bool loadOlder = false,
  }) async {
    // The client-instance envelope is a local display projection. Once a
    // caller has selected an instance, every Prompt/history read must pass
    // through the same projection before reaching the owner API. This also
    // covers refresh/feed updates and the "load older" cursor path, which can
    // otherwise outlive the conversation tile that originally triggered it.
    if (!_conversationVisibleFromSelectedClientInstance(conversationID)) {
      if (mounted) {
        _update(() {
          _prompts = const [];
          _promptCursor = null;
          _hasMorePrompts = false;
          _promptError = null;
          _loadingPrompts = false;
        });
      }
      return false;
    }
    final generation = ++_promptGeneration;
    _update(() {
      _loadingPrompts = true;
      _promptError = null;
    });
    try {
      final page = await _api.listPrompts(
        conversationID: conversationID,
        before: loadOlder ? _promptCursor : null,
      );
      if (!mounted ||
          generation != _promptGeneration ||
          _selected?.conversation.id != conversationID) {
        return false;
      }
      // A refresh caused by the owner change feed must not discard older
      // Prompt history that the user already loaded. Keep the deepest cursor
      // we have seen while merging the newest page by Prompt ID; the initial
      // load still takes its cursor directly from the service.
      final hadOlderHistory = !loadOlder && _promptCursor != null;
      final prompts = loadOlder
          ? [...page.prompts, ..._prompts]
          : [..._prompts, ...page.prompts];
      prompts.sort(_comparePrompts);
      final nextCursor = hadOlderHistory ? _promptCursor : page.nextCursor;
      final hasMore = hadOlderHistory ? _hasMorePrompts : page.hasMore;
      _update(() {
        _prompts = _uniquePrompts(prompts);
        _promptCursor = nextCursor;
        _hasMorePrompts = hasMore && nextCursor != null;
        _loadingPrompts = false;
        _clientInstanceFilterNeedsPrivateReload = false;
      });
      return true;
    } catch (error) {
      if (!mounted) return false;
      final authorizationFailure = _isAuthorizationFailure(error);
      await _clearSessionIfUnauthorized(error);
      if (!mounted ||
          (!authorizationFailure && generation != _promptGeneration)) {
        return false;
      }
      if (_dropSelectedConversationAfterOwnerReadFailure(
        conversationID,
        error,
      )) {
        if (!mounted) return false;
        _update(() {
          _promptError = _friendlyError(
            error,
            'Could not load prompt history.',
          );
          _loadingPrompts = false;
        });
        return false;
      }
      _update(() {
        _promptError = _friendlyError(error, 'Could not load prompt history.');
        _loadingPrompts = false;
      });
      return false;
    }
  }

  Future<void> _restoreChangeCursor() async {
    _changeCursor = await _changeCursorStore.load();
  }
}
