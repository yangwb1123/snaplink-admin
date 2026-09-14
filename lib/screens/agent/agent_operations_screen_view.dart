part of 'agent_operations_screen.dart';

extension _AgentOperationsScreenView on _AgentOperationsScreenState {
  Widget _buildOperationsView() => AgentOperationsView(
    instances: _instances,
    sessions: _sessions,
    events: _events,
    instanceFilter: _instanceFilter,
    selectedSession: _selectedSession,
    turn: _turn,
    pendingPrompt: _selectedSession == null
        ? null
        : _pendingPrompts[_selectedSession!.sessionId]?.prompt,
    promptError: _selectedSession == null
        ? null
        : _promptErrors[_selectedSession!.sessionId],
    directoryError: _directoryFailure == null
        ? null
        : _friendlyError(_directoryFailure!, 'Could not load Agent sessions.'),
    activityError: _activityFailure == null
        ? null
        : _friendlyError(_activityFailure!, 'Could not load session activity.'),
    directoryLoading: _directoryLoading,
    instancesHaveMore: _instancesHaveMore,
    sessionsHaveMore: _sessionsHaveMore,
    activityLoading: _activityLoading,
    sending: _sending,
    cancelling: _cancelling,
    unauthorized: _unauthorized,
    needsAgentScope:
        _requiresAgentScope(_directoryFailure) ||
        _requiresAgentScope(_activityFailure) ||
        _requiresAgentScope(_actionFailure),
    showSessionOnNarrowScreen: _showSessionOnNarrowScreen,
    promptController: _promptController,
    canControl: _selectedSession != null && _canControl(_selectedSession!),
    instanceChanged: _changeInstance,
    onRefresh: () {
      _refreshDirectory(reset: true);
      _refreshActivity();
      _refreshComputeDevices(reset: true);
      _refreshComputeTasks();
    },
    onLoadMoreDirectory: _loadMoreDirectory,
    onSelectSession: _selectSession,
    onBackToList: () => _update(() => _showSessionOnNarrowScreen = false),
    onSendPrompt: _sendPrompt,
    onRetryPrompt: _sendPrompt,
    onCancelTurn: _cancelTurn,
    onSignIn: _signInForAgentAccess,
    onOpenSettings: _openSettings,
    onRetryDirectory: () => _refreshDirectory(reset: true),
    onRetryActivity: _refreshActivity,
    workspaceEnabled: _workspaceSelection.enabled,
    workspaceForm: _selectedSession == null
        ? null
        : AgentWorkspaceForm(
            key: ValueKey('workspace-${_selectedSession!.sessionId}'),
            api: _api,
            idempotencyKeys: _workspaceUploadKeys,
            sessionId: _selectedSession!.sessionId,
            instanceId: _selectedSession!.instanceId,
            projectId: _selectedSession!.projectId,
            value: _workspaceSelection,
            disabled: _submittingTask || _taskWriteScopeMissing,
            onChanged: (value) => _update(() {
              _workspaceSelection = value;
              if (value.enabled &&
                  !_devices.any(
                    (device) =>
                        device.deviceId == _targetDeviceId &&
                        device.workspaceSupported,
                  )) {
                _targetDeviceId = '';
              }
            }),
            onSignIn: _signInForAgentAccess,
          ),
    workspaceDetailsBuilder: (task) => AgentWorkspaceTaskDetails(
      key: ValueKey('workspace-result-${task.taskId}'),
      api: _api,
      task: task,
      onSignIn: _signInForAgentAccess,
    ),
    devices: _devices,
    deviceLoading: _devicesLoading,
    devicesHaveMore: _devicesHaveMore,
    deviceError: _deviceFailure == null
        ? null
        : _friendlyError(_deviceFailure!, 'Could not load compute devices.'),
    deviceScopeMissing: _deviceScopeMissing,
    computeTasks: _computeTasks,
    computeTaskLoading: _tasksLoading,
    computeTasksHaveMore: _tasksHaveMore,
    computeTaskError: _taskFailure == null
        ? null
        : _friendlyError(_taskFailure!, 'Could not load compute tasks.'),
    computeFormError: _computeFormError,
    computeTaskActionError: _taskActionFailure == null
        ? null
        : _friendlyError(
            _taskActionFailure!,
            'Could not submit the compute task.',
          ),
    taskReadScopeMissing: _taskReadScopeMissing,
    taskWriteScopeMissing: _taskWriteScopeMissing,
    taskCancelScopeMissing: _taskCancelScopeMissing,
    targetDeviceId: _targetDeviceId,
    submittingTask: _submittingTask,
    cancellingTaskIds: _cancellingTaskIds,
    loadingTaskDetails: _loadingTaskDetails,
    taskDetails: _taskDetails,
    computeArgvController: _computeArgvController,
    computeWorkdirController: _computeWorkdirController,
    computeCpuController: _computeCpuController,
    computeMemoryController: _computeMemoryController,
    computeGpuCountController: _computeGpuCountController,
    computeGpuMemoryController: _computeGpuMemoryController,
    computeTimeoutController: _computeTimeoutController,
    computeOsController: _computeOsController,
    computeArchitectureController: _computeArchitectureController,
    computeRuntimesController: _computeRuntimesController,
    onRefreshDevices: () => _refreshComputeDevices(reset: true),
    onLoadMoreDevices: () => _refreshComputeDevices(loadMore: true),
    onRefreshTasks: () => _refreshComputeTasks(reset: true),
    onLoadMoreTasks: () => _refreshComputeTasks(loadMore: true),
    onTargetDeviceChanged: (value) => _update(() => _targetDeviceId = value),
    onSubmitTask: _submitComputeTask,
    onCancelTask: _cancelComputeTask,
    onLoadTaskDetails: _loadComputeTaskDetails,
  );
}
