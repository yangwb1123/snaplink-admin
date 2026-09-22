part of 'agent_operations_screen.dart';

extension _AgentOperationsSessionHistory on _AgentOperationsScreenState {
  String get _historyInstance => _instanceFilter.isNotEmpty
      ? _instanceFilter
      : _selectedSession?.instanceId ?? '';

  Widget _historyEntry() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Tooltip(
      message: context.tr('Select an instance to view its requests.'),
      child: OutlinedButton.icon(
        key: const ValueKey('session-requests-entry'),
        onPressed: _unauthorized || _historyInstance.isEmpty
            ? null
            : _showHistory,
        icon: const Icon(Icons.receipt_long_outlined),
        label: Text(context.tr('Session requests')),
      ),
    ),
  );

  Future<void> _showHistory() async {
    final instanceId = _historyInstance;
    if (instanceId.isEmpty || _unauthorized) return;
    final name =
        _instances
            .where((item) => item.instanceId == instanceId)
            .map((item) => item.name)
            .firstOrNull ??
        instanceId;
    final selection = _selectionGeneration;
    final auth = _historyAuthGeneration;
    final storedToken = Session.read();
    final token = _api.accessToken;
    bool authorized() =>
        mounted &&
        !_unauthorized &&
        auth == _historyAuthGeneration &&
        widget.accessToken == token &&
        Session.read() == storedToken;
    bool current() =>
        authorized() &&
        selection == _selectionGeneration &&
        _historyInstance == instanceId;
    await showDialog<void>(
      context: context,
      builder: (_) => AgentSessionHistoryDialog(
        api: _api,
        instanceId: instanceId,
        instanceName: name,
        canOpen: current,
        isAuthorized: authorized,
        onOpen: (session) {
          if (!current() || session.instanceId != instanceId) return;
          _directoryGeneration++;
          _sessions = [
            session,
            ..._sessions.where((item) => item.sessionId != session.sessionId),
          ];
          _selectSession(session);
        },
      ),
    );
  }
}
