part of 'agent_operations_screen.dart';

extension _AgentOperationsSessionCreation on _AgentOperationsScreenState {
  Widget _creationEntry() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: OutlinedButton.icon(
      onPressed: _unauthorized ? null : _showCreation,
      icon: const Icon(Icons.add_comment_outlined),
      label: Text(
        context.tr(
          _creation.hasInput ? 'Session creation status' : 'New session',
        ),
      ),
    ),
  );

  Future<void> _showCreation() => showDialog<void>(
    context: context,
    builder: (_) => AgentSessionCreationDialog(
      creation: _creation,
      instances: _instances,
      initialInstance: _instanceFilter,
      onSubmit: () {
        _creationSelectionGeneration = _selectionGeneration;
        _creationInstanceFilter = _instanceFilter;
        _handledCreation = null;
      },
      onOpen: () => unawaited(_openCreatedSession(explicit: true)),
    ),
  );

  void _creationChanged() {
    if (!mounted) return;
    _update(() {});
    final request = _creation.request;
    if (request?.status != 'created' ||
        _handledCreation == request!.requestId) {
      return;
    }
    _handledCreation = request.requestId;
    unawaited(_openCreatedSession());
  }

  Future<void> _openCreatedSession({bool explicit = false}) async {
    final request = _creation.request;
    if (request?.status != 'created' || _unauthorized) return;
    final selection = explicit
        ? _selectionGeneration
        : _creationSelectionGeneration;
    final filter = explicit ? _instanceFilter : _creationInstanceFilter;
    try {
      final session = await _api.getSession(request!.sessionId);
      if (!mounted || _unauthorized || _creation.request != request) return;
      if (session.sessionId != request.sessionId ||
          session.instanceId != request.instanceId) {
        throw const FormatException('Invalid created session.');
      }
      if (selection == _selectionGeneration && filter == _instanceFilter) {
        // Fence directory reads started before the new session became visible.
        _directoryGeneration++;
        if (_instanceFilter.isNotEmpty &&
            _instanceFilter != session.instanceId) {
          _instanceFilter = session.instanceId;
          _sessions = const [];
          _sessionCursor = null;
          _sessionsHaveMore = false;
        }
        _sessions = [
          session,
          ..._sessions.where((item) => item.sessionId != session.sessionId),
        ];
        _selectSession(session);
      }
      unawaited(_refreshDirectory(silent: true));
    } catch (_) {
      if (!mounted || _unauthorized) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.tr(
              'Session created. Refresh the directory or open it again to view it.',
            ),
          ),
        ),
      );
    }
  }
}
