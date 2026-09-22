part of 'agent_operations_screen.dart';

extension _AgentOperationsPlacement on _AgentOperationsScreenState {
  Widget _computeDetails(AgentComputeTask task) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        key: ValueKey('placement-entry-${task.taskId}'),
        onPressed: _unauthorized ? null : () => _showPlacement(task),
        icon: const Icon(Icons.fact_check_outlined),
        label: Text(context.tr('Task placement')),
      ),
      AgentWorkspaceTaskDetails(
        key: ValueKey('workspace-result-${task.taskId}'),
        api: _api,
        task: task,
        onSignIn: _signInForAgentAccess,
      ),
    ],
  );

  Future<void> _showPlacement(AgentComputeTask task) async {
    if (_unauthorized ||
        _placement != null ||
        task.sessionId != _selectedSession?.sessionId) {
      return;
    }
    final selection = _selectionGeneration;
    final auth = _historyAuthGeneration;
    final storedToken = _placementStoredToken;
    final placement = AgentComputePlacement(
      api: _api,
      taskId: task.taskId,
      isCurrent: () =>
          mounted &&
          !_unauthorized &&
          auth == _historyAuthGeneration &&
          widget.accessToken == _api.accessToken &&
          widget.apiOrigin == _api.baseUrl &&
          Session.read() == storedToken &&
          selection == _selectionGeneration &&
          task.sessionId == _selectedSession?.sessionId,
    );
    _placement = placement;
    unawaited(placement.load());
    try {
      await showDialog<void>(
        context: context,
        builder: (_) => AgentComputePlacementDialog(placement: placement),
      );
    } finally {
      if (identical(_placement, placement)) _placement = null;
      placement.dispose();
    }
  }
}
