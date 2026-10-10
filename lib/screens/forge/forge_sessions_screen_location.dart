part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenLocation on _ForgeSessionsScreenState {
  void _onLocationChange() {
    if (!mounted) return;
    final location = BrowserNavigation.currentUri;
    if (!_isForgeSessionsLocation(location)) return;
    final conversationID = _conversationIDFromLocation(location);
    if (_hasObservedLocationSelection &&
        _observedLocationConversationID == conversationID) {
      if (_selected?.conversation.id == conversationID) {
        _takePendingLocationSelection();
      }
      return;
    }
    _hasObservedLocationSelection = true;
    _observedLocationConversationID = conversationID;
    if (_selected?.conversation.id == conversationID) {
      _takePendingLocationSelection();
      return;
    }

    _hasPendingLocationSelection = true;
    _pendingLocationConversationID = conversationID;
    final generation = ++_locationSelectionGeneration;
    if (_loadingConversations || _restoringLocationSelection) return;
    unawaited(_restoreLocationSelection(conversationID, generation));
  }

  Future<void> _restoreLocationSelection(
    String? conversationID,
    int generation,
  ) async {
    if (!mounted || generation != _locationSelectionGeneration) return;
    _restoringLocationSelection = true;
    try {
      if (conversationID == null) {
        if (!mounted || generation != _locationSelectionGeneration) return;
        _takePendingLocationSelection();
        if (_selected == null) return;
        _update(() {
          _selected = null;
          _clearConversationDetails();
        });
        return;
      }

      final local = _findConversation(_conversations, conversationID);
      if (local != null) {
        _takePendingLocationSelection();
        await _selectConversation(
          local,
          updateLocation: false,
          locationGeneration: generation,
        );
        return;
      }

      // Keep the first list page intact while resolving a URL that points to
      // an older owner-scoped session. _refreshConversations performs the
      // authenticated detail fallback exactly once for that selection.
      await _refreshConversations(selectID: conversationID);
    } finally {
      _restoringLocationSelection = false;
      if (mounted && !_loadingConversations && _hasPendingLocationSelection) {
        final nextGeneration = _locationSelectionGeneration;
        if (nextGeneration != generation) {
          final nextConversationID = _pendingLocationConversationID;
          unawaited(
            _restoreLocationSelection(nextConversationID, nextGeneration),
          );
        }
      }
    }
  }

  String? _takePendingLocationSelection() {
    if (!_hasPendingLocationSelection) return null;
    final conversationID = _pendingLocationConversationID;
    _hasPendingLocationSelection = false;
    _pendingLocationConversationID = null;
    return conversationID;
  }

  bool _isForgeSessionsLocation(Uri location) {
    final segments = location.pathSegments;
    if (segments.length == 1 && segments[0] == 'forge') return true;
    if (segments.length == 2 && segments[0] == 'forge' && segments[1].isEmpty) {
      return true;
    }
    return segments.length == 3 &&
        segments[0] == 'forge' &&
        segments[1] == 'conversations' &&
        segments[2].isNotEmpty;
  }

  String? _conversationIDFromLocation(Uri location) {
    final segments = location.pathSegments;
    if (segments.length != 3 ||
        segments[0] != 'forge' ||
        segments[1] != 'conversations' ||
        segments[2].isEmpty) {
      return null;
    }
    return segments[2];
  }

  void _updateConversationLocation(String conversationID) {
    final route = Uri(
      pathSegments: <String>['forge', 'conversations', conversationID],
      queryParameters: _selectedClientInstanceID == null
          ? null
          : <String, String>{'instance_id': _selectedClientInstanceID!},
    );
    final routePath = '/${route.path}';
    final routeWithQuery = route.query.isEmpty
        ? routePath
        : '$routePath?${route.query}';
    final current = BrowserNavigation.currentUri;
    if (current.path == routePath && current.query == route.query) return;
    // Keep a same-document selection bookmarkable without rebuilding the
    // authenticated gate or issuing another navigation request. The URL is
    // only a selection hint; owner-scoped reads remain authoritative.
    BrowserNavigation.replaceState(routeWithQuery);
  }
}
