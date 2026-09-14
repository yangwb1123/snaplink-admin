part of 'agent_operations_screen.dart';

extension _AgentOperationsScreenActions on _AgentOperationsScreenState {
  Future<void> _sendPrompt() async {
    final session = _selectedSession;
    if (session == null || !_canControl(session) || _sending) return;
    if (_turn?.isActive == true) return;
    final existing = _pendingPrompts[session.sessionId];
    final pending =
        existing ??
        _PendingAgentPrompt(
          sessionId: session.sessionId,
          prompt: _promptController.text.trim(),
          idempotencyKey: newAgentIdempotencyKey(),
        );
    if (pending.prompt.isEmpty) return;
    _update(() {
      _sending = true;
      _actionFailure = null;
      _pendingPrompts[session.sessionId] = pending;
      _promptErrors.remove(session.sessionId);
    });
    try {
      final turn = await _api.submitPrompt(
        sessionId: pending.sessionId,
        prompt: pending.prompt,
        idempotencyKey: pending.idempotencyKey,
      );
      _pendingPrompts.remove(session.sessionId);
      if (!mounted) return;
      if (_selectedSession?.sessionId == session.sessionId) {
        _update(() {
          _turn = turn;
          _actionFailure = null;
          _promptController.clear();
          _sending = false;
        });
        _refreshActivity(silent: true);
      } else {
        _update(() => _sending = false);
      }
    } catch (error) {
      if (!mounted) return;
      final status = error is AgentHubApiException ? error.statusCode : 0;
      _update(() {
        _actionFailure = _requiresAgentScope(error) ? error : null;
        if (status >= 400 &&
            status < 500 &&
            !const {408, 409, 425, 429}.contains(status)) {
          _pendingPrompts.remove(session.sessionId);
        }
        _promptErrors[session.sessionId] = _friendlyError(
          error,
          'Could not load session activity.',
        );
        _sending = false;
      });
    }
  }

  Future<void> _cancelTurn() async {
    final turn = _turn;
    if (turn == null || !turn.isActive || _cancelling) return;
    final generation = _selectionGeneration;
    final sessionId = _selectedSession?.sessionId;
    _update(() {
      _cancelling = true;
      _actionFailure = null;
    });
    try {
      final result = await _api.cancelTurn(turn.turnId);
      if (!mounted) return;
      if (sessionId != null && _isCurrent(generation, sessionId)) {
        _update(() {
          _turn = result;
          _actionFailure = null;
        });
        _refreshActivity(silent: true);
      }
    } catch (error) {
      if (mounted && sessionId != null && _isCurrent(generation, sessionId)) {
        _update(() {
          _actionFailure = _requiresAgentScope(error) ? error : null;
          _promptErrors[sessionId] = _friendlyError(
            error,
            'Could not load session activity.',
          );
        });
      }
    } finally {
      if (mounted) _update(() => _cancelling = false);
    }
  }

  bool _canControl(AgentSession session) =>
      session.controllable && _instanceFor(session.instanceId)?.online == true;

  AgentInstance? _instanceFor(String id) {
    for (final instance in _instances) {
      if (instance.instanceId == id) return instance;
    }
    return null;
  }

  String _friendlyError(Object error, String fallback) {
    if (error is AgentHubApiException) {
      if (error.isUnconfigured) {
        return 'Agent Hub is not configured on this deployment.';
      }
      if (error.isForbidden) {
        return error.code.contains('session')
            ? 'You do not have permission to view Agent sessions.'
            : 'This session cannot be controlled from this account or instance.';
      }
      if (error.statusCode == 0 || error.statusCode >= 500) {
        return 'Agent Hub is unavailable. Check its service origin and try again.';
      }
      return error.message;
    }
    if (error is FormatException) {
      return 'Agent Hub returned an invalid response.';
    }
    return fallback;
  }

  bool _requiresAgentScope(Object? error) =>
      error is AgentHubApiException &&
      error.statusCode == 403 &&
      const {
        'insufficient_scope',
        'missing_scope',
        'insufficient_audience',
      }.contains(error.code.toLowerCase());

  void _signInForAgentAccess() => BrowserNavigation.replaceLocation(
    AgentHubOAuth.loginLocation(retryAfterAudienceFailure: _unauthorized),
  );

  void _openSettings() => Navigator.of(
    context,
  ).push<void>(MaterialPageRoute<void>(builder: (_) => const SettingsScreen()));
}
