part of 'agent_operations_screen.dart';

extension _AgentOperationsCompute on _AgentOperationsScreenState {
  Future<void> _refreshComputeDevices({
    bool silent = false,
    bool loadMore = false,
    bool reset = false,
  }) async {
    if (_unauthorized) return;
    if (_devicesBusy) {
      _devicesPending = true;
      // A context reset (session/project change) invalidates the in-flight
      // response. A load-more or periodic refresh can consume that response
      // first, then continue with the latest cursor in the pending pass.
      if (reset) {
        _deviceGeneration++;
        _devicesPendingReset = true;
        _devicesPendingLoadMore = false;
      } else if (loadMore && !_devicesPendingReset) {
        _devicesPendingLoadMore = true;
      }
      _devicesPendingSilent = _devicesPendingSilent && silent;
      return;
    }
    final generation = ++_deviceGeneration;
    _devicesBusy = true;
    final projectId = _selectedSession?.projectId;
    final after = loadMore ? _deviceCursor : null;
    if (!silent && mounted) _update(() => _devicesLoading = true);
    try {
      final page = await _api.listDevices(
        projectId: projectId,
        after: after,
        limit: 100,
      );
      if (!mounted || generation != _deviceGeneration) return;
      _update(() {
        _devices = _mergeById(
          page.items,
          _devices,
          (device) => device.deviceId,
          appendExisting: loadMore,
          preserveTail: !loadMore && !reset,
        );
        _deviceCursor = page.nextCursor;
        _devicesHaveMore =
            page.items.isNotEmpty &&
            page.nextCursor != null &&
            page.nextCursor != after;
        _deviceFailure = null;
        _deviceScopeMissing = false;
        _devicesLoading = false;
        if (!_devices.any(
          (device) =>
              device.deviceId == _targetDeviceId &&
              device.online &&
              device.schedulable,
        )) {
          _targetDeviceId = '';
        }
      });
    } catch (error) {
      if (!mounted || generation != _deviceGeneration) return;
      _update(() {
        _deviceFailure = error;
        _deviceScopeMissing = _requiresAgentScope(error);
        _devicesLoading = false;
      });
    } finally {
      _devicesBusy = false;
      if (_devicesPending && !_unauthorized) {
        final pendingLoadMore = _devicesPendingLoadMore;
        final pendingReset = _devicesPendingReset;
        final pendingSilent = _devicesPendingSilent;
        _devicesPending = false;
        _devicesPendingLoadMore = false;
        _devicesPendingReset = false;
        _devicesPendingSilent = true;
        unawaited(
          _refreshComputeDevices(
            silent: pendingSilent,
            loadMore: pendingLoadMore,
            reset: pendingReset,
          ),
        );
      } else if (_devicesPending) {
        _devicesPending = false;
        _devicesPendingLoadMore = false;
        _devicesPendingReset = false;
        _devicesPendingSilent = true;
      }
    }
  }

  Future<void> _refreshComputeTasks({
    bool silent = false,
    bool loadMore = false,
    bool reset = false,
  }) async {
    final session = _selectedSession;
    if (session == null || _unauthorized) return;
    if (_tasksBusy) {
      _tasksPending = true;
      // A reset means the selected session or paging context changed. It
      // invalidates the in-flight response; ordinary refresh and load-more
      // can consume it first and then continue with its updated cursor.
      if (reset) {
        _taskGeneration++;
        _tasksPendingReset = true;
        _tasksPendingLoadMore = false;
      } else if (loadMore && !_tasksPendingReset) {
        _tasksPendingLoadMore = true;
      }
      _tasksPendingSilent = _tasksPendingSilent && silent;
      return;
    }
    if (reset) _taskGeneration++;
    _tasksBusy = true;
    final generation = _taskGeneration;
    final selectionGeneration = _selectionGeneration;
    final after = loadMore ? _taskCursor : null;
    if (!silent && mounted) _update(() => _tasksLoading = true);
    try {
      final page = await _api.listTasks(
        sessionId: session.sessionId,
        after: after,
        limit: 100,
      );
      if (!_isComputeSelectionCurrent(
        generation,
        selectionGeneration,
        session.sessionId,
      )) {
        return;
      }
      _update(() {
        _computeTasks = _mergeById(
          page.items,
          _computeTasks,
          (task) => task.taskId,
          appendExisting: loadMore,
          preserveTail: !loadMore && !reset,
        );
        for (final listed in page.items) {
          final cached = _taskDetails[listed.taskId];
          if (cached == null ||
              _computeTaskVersion(cached) == _computeTaskVersion(listed)) {
            continue;
          }
          final listedTime = listed.updatedAt;
          final cachedTime = cached.updatedAt;
          if (listedTime != null &&
              cachedTime != null &&
              listedTime.isBefore(cachedTime)) {
            continue;
          }
          _taskDetails.remove(listed.taskId);
        }
        _taskCursor = page.nextCursor;
        _tasksHaveMore =
            page.items.isNotEmpty &&
            page.nextCursor != null &&
            page.nextCursor != after;
        _taskFailure = null;
        _taskReadScopeMissing = false;
        _tasksLoading = false;
      });
    } catch (error) {
      if (!_isComputeSelectionCurrent(
        generation,
        selectionGeneration,
        session.sessionId,
      )) {
        return;
      }
      _update(() {
        _taskFailure = error;
        _taskReadScopeMissing = _requiresAgentScope(error);
        _tasksLoading = false;
      });
    } finally {
      _tasksBusy = false;
      if (_tasksPending && !_unauthorized) {
        final pendingLoadMore = _tasksPendingLoadMore;
        final pendingReset = _tasksPendingReset;
        final pendingSilent = _tasksPendingSilent;
        _tasksPending = false;
        _tasksPendingLoadMore = false;
        _tasksPendingReset = false;
        _tasksPendingSilent = true;
        unawaited(
          _refreshComputeTasks(
            silent: pendingSilent,
            loadMore: pendingLoadMore,
            reset: pendingReset,
          ),
        );
      } else if (_tasksPending) {
        _tasksPending = false;
        _tasksPendingLoadMore = false;
        _tasksPendingReset = false;
        _tasksPendingSilent = true;
      }
    }
  }

  bool _isComputeSelectionCurrent(
    int generation,
    int selectionGeneration,
    String sessionId,
  ) =>
      mounted &&
      generation == _taskGeneration &&
      selectionGeneration == _selectionGeneration &&
      _selectedSession?.sessionId == sessionId;

  AgentComputeTask? _listedComputeTask(String taskId) {
    for (final task in _computeTasks) {
      if (task.taskId == taskId) return task;
    }
    return null;
  }

  Object _computeTaskVersion(AgentComputeTask? task) => (
    task?.state,
    task?.updatedAt,
    task?.targetDeviceId,
    task?.archiveState,
    task?.workspaceResult?.state,
    task?.workspaceResult?.inputSha256,
    task?.workspaceResult?.outputSha256,
    task?.gpuAssignment?.assignedAt,
    task?.gpuAssignment?.uuids.join(','),
  );

  Future<void> _loadComputeTaskDetails(String taskId) async {
    final session = _selectedSession;
    if (session == null ||
        _taskDetails.containsKey(taskId) ||
        _loadingTaskDetails.contains(taskId)) {
      return;
    }
    final generation = _selectionGeneration;
    final listVersion = _computeTaskVersion(_listedComputeTask(taskId));
    _update(() => _loadingTaskDetails.add(taskId));
    try {
      final task = await _api.getTask(taskId);
      if (!_isCurrent(generation, session.sessionId) ||
          task.sessionId != session.sessionId ||
          listVersion != _computeTaskVersion(_listedComputeTask(taskId))) {
        return;
      }
      _update(() => _taskDetails[taskId] = task);
    } catch (error) {
      if (!_isCurrent(generation, session.sessionId)) return;
      _update(() {
        _taskFailure = error;
        _taskReadScopeMissing = _requiresAgentScope(error);
      });
    } finally {
      if (mounted) _update(() => _loadingTaskDetails.remove(taskId));
    }
  }
}
