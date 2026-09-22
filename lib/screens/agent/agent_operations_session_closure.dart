part of 'agent_operations_screen.dart';

extension _AgentOperationsSessionClosure on _AgentOperationsScreenState {
  bool _sessionCloseBlocked(AgentSession session) =>
      session.frozen ||
      _closedSessionIds.contains(session.sessionId) ||
      (_closure.hasInput && _closure.sessionId == session.sessionId) ||
      const {
        'closing',
        'closed',
        'close_failed',
        'close_lost',
      }.contains(session.status);

  String? _closeUnavailable(AgentSession session) {
    if (_instanceFor(session.instanceId)?.sessionCloseSupported != true) {
      return 'This instance does not support remote session closing.';
    }
    if (!_canControl(session)) {
      return 'This session is read-only. Its history is still available.';
    }
    if (_closure.hasInput && !_closure.canReset) {
      return 'Finish tracking the current close request first.';
    }
    if (_activityLoading || _tasksLoading) {
      return 'Checking session activity...';
    }
    if (_turn?.isActive == true ||
        session.activeTurnId.isNotEmpty ||
        _computeTasks.any((task) => task.isActive) ||
        _sending ||
        _submittingTask ||
        _pendingPrompts.containsKey(session.sessionId) ||
        _computeIdempotencyKeys.keys.any(
          (key) => key.startsWith('${session.sessionId}\n'),
        )) {
      return 'This session has active work. Wait for it to finish before closing.';
    }
    return null;
  }

  Widget _closureStatusEntry() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: OutlinedButton.icon(
      onPressed: _unauthorized ? null : () => _showClosure(),
      icon: const Icon(Icons.history),
      label: Text(context.tr('Session close status')),
    ),
  );

  Widget? _closureEntry() {
    final session = _selectedSession;
    if (session == null) return null;
    final tracking =
        _closure.hasInput && _closure.sessionId == session.sessionId;
    final reason = _closeUnavailable(session);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('close-session-action'),
            onPressed: _unauthorized || (!tracking && reason != null)
                ? null
                : () => _showClosure(target: tracking ? null : session),
            icon: const Icon(Icons.stop_circle_outlined),
            label: Text(
              context.tr(tracking ? 'Session close status' : 'Close session'),
            ),
          ),
          if (reason != null && !tracking) Text(context.tr(reason)),
          if (tracking && _closure.request != null)
            Text(context.tr(closureStatus(_closure.request!))),
        ],
      ),
    );
  }

  Future<void> _showClosure({AgentSession? target}) async {
    if (target != null && _closure.canReset) _closure.reset();
    await showDialog<void>(
      context: context,
      builder: (_) => AgentSessionCloseDialog(
        closure: _closure,
        target: target,
        onSubmit: () {
          _closureSelectionGeneration = _selectionGeneration;
          _handledClosure = null;
        },
      ),
    );
  }

  void _closureChanged() {
    if (!mounted) return;
    final request = _closure.request;
    _update(() {
      if (request != null) _closedSessionIds.add(request.sessionId);
    });
    if (request == null) return;
    final state = '${request.requestId}:${request.status}';
    if (_handledClosure == state) return;
    _handledClosure = state;
    unawaited(_refreshClosedSession(request.sessionId, request.instanceId));
  }

  Future<void> _refreshClosedSession(
    String sessionId,
    String instanceId,
  ) async {
    final selection = _closureSelectionGeneration;
    try {
      final session = await _api.getSession(sessionId);
      if (!mounted ||
          _unauthorized ||
          session.sessionId != sessionId ||
          session.instanceId != instanceId) {
        return;
      }
      _update(() {
        _sessions = [
          for (final item in _sessions)
            item.sessionId == sessionId ? session : item,
        ];
        if (_isCurrent(selection, sessionId)) _selectedSession = session;
      });
    } catch (_) {
      // The durable receipt remains visible; normal activity polling can recover.
    }
  }
}
