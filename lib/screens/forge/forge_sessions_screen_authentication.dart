part of 'forge_sessions_screen.dart';

extension _ForgeSessionsScreenAuthentication on _ForgeSessionsScreenState {
  bool _isDefinitiveOwnerReadFailure(Object error) {
    if (error is FormatException) return true;
    if (error is! ForgeConversationsApiException) return false;
    if (error.statusCode == 408 ||
        error.statusCode == 425 ||
        error.statusCode == 429 ||
        error.statusCode >= 500) {
      return false;
    }
    return error.statusCode >= 400;
  }

  bool _dropSelectedConversationAfterOwnerReadFailure(
    String conversationID,
    Object error,
  ) {
    if (!mounted ||
        !_isDefinitiveOwnerReadFailure(error) ||
        _selected?.conversation.id != conversationID) {
      return false;
    }
    _update(() {
      _conversationGeneration++;
      _conversations = _conversations
          .where((entry) => entry.conversation.id != conversationID)
          .toList(growable: false);
      _selected = null;
      _clearConversationDetails();
    });
    return true;
  }

  Future<void> _clearSessionIfUnauthorized(Object error) async {
    if (!_isAuthorizationFailure(error)) return;
    _authorizationInvalidated = true;
    // Once the owner credential has been rejected, stop the foreground change
    // feed before clearing the view.  A timer tick that survives credential
    // cleanup would immediately issue another request with the same rejected
    // owner and could race an explicit reauthentication/navigation flow.
    _stopChangeSyncTimer();
    if (mounted) {
      _update(() {
        _conversationGeneration++;
        _loadingConversations = false;
        _conversations = const [];
        _selected = null;
        _nextAfterID = null;
        _hasMoreConversations = false;
        _conversationsStale = false;
        _clearConversationDetails();
      });
    }
    try {
      await _credentialStore.clear();
    } catch (_) {
      // Keep the route usable so the user can retry sign-out and vault clear.
    }
  }

  bool _isAuthorizationFailure(Object error) =>
      error is ForgeConversationsApiException &&
      (error.isUnauthorized || error.isForbidden);

  void _signOutThisDevice() {
    if (_signingOut) return;
    _update(() {
      _signingOut = true;
      _signOutError = null;
      _sessionViewInvalidated = true;
      _conversationGeneration++;
      _locationSelectionGeneration++;
      _loadingConversations = false;
      _conversations = const [];
      _selected = null;
      _nextAfterID = null;
      _hasMoreConversations = false;
      _conversationsStale = false;
      _clearConversationDetails();
    });
    _stopChangeSyncTimer();
    unawaited(_revokeAndReturnToForgeLogin());
  }

  Future<void> _revokeAndReturnToForgeLogin() async {
    try {
      await _tokenRefresh.revokeCurrentTokens();
    } catch (_) {
      // A failed revoke must not trap the user in the signed-in screen.
    }
    try {
      await _credentialStore.clear();
    } catch (_) {
      if (mounted) {
        _update(() {
          _signingOut = false;
          _signOutError =
              'Could not clear stored Forge credentials. Try signing out again.';
          // A failed secure-store delete leaves the route available for an
          // explicit retry, but never restores the owner-scoped view.
          _conversationGeneration++;
          _loadingConversations = false;
          _conversations = const [];
          _selected = null;
          _nextAfterID = null;
          _hasMoreConversations = false;
          _conversationsStale = false;
          _clearConversationDetails();
        });
      }
      return;
    }
    await _conversationMetadataCache.clear();
    BrowserNavigation.replaceLocation(ForgeConversationsOAuth.loginLocation());
  }

  String _friendlyError(Object error, String fallback) {
    if (error is ForgeConversationsApiException) {
      if (error.isUnauthorized || error.isForbidden) {
        return _forgeAuthRequiredMessage;
      }
      if (error.statusCode == 0 || error.statusCode >= 500) {
        return error.message;
      }
      if (error.code == 'conflict') {
        return 'This conversation changed elsewhere. Refresh before sending again.';
      }
      return error.message;
    }
    if (error is FormatException) return 'Forge returned an invalid response.';
    return fallback;
  }

  void _signIn() => BrowserNavigation.replaceLocation(
    ForgeConversationsOAuth.loginLocation(retryAfterAuthorizationFailure: true),
  );

  void _setScopeKind(String? value) =>
      _update(() => _scopeKind = value ?? 'global');
}
