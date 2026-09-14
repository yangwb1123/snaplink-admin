part of 'agent_operations_screen.dart';

extension _AgentOperationsCompute on _AgentOperationsScreenState {
  Future<void> _refreshComputeDevices({
    bool silent = false,
    bool loadMore = false,
    bool reset = false,
  }) async {
    if (_unauthorized) return;
    final generation = ++_deviceGeneration;
    if (_devicesBusy) {
      _devicesPending = true;
      return;
    }
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
        _devicesPending = false;
        unawaited(_refreshComputeDevices(silent: true, reset: true));
      }
    }
  }

  Future<void> _refreshComputeTasks({
    bool silent = false,
    bool loadMore = false,
    bool reset = false,
  }) async {
    final session = _selectedSession;
    if (session == null || _unauthorized || _tasksBusy) return;
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

  Future<void> _submitComputeTask() async {
    final session = _selectedSession;
    if (session == null || _submittingTask || _taskWriteScopeMissing) return;
    late final AgentComputeRequest request;
    try {
      request = _readComputeRequest();
    } on FormatException catch (error) {
      _update(() => _computeFormError = error.message);
      return;
    }
    final fingerprint = '${session.sessionId}\n${request.fingerprint}';
    final existingKey = _computeIdempotencyKeys[fingerprint];
    if (existingKey == null && _computeIdempotencyKeys.length >= 128) {
      _update(
        () => _computeFormError =
            'Too many unconfirmed task submissions. Retry or resolve them first.',
      );
      return;
    }
    final key = existingKey ?? newAgentIdempotencyKey();
    _computeIdempotencyKeys[fingerprint] = key;
    final generation = _selectionGeneration;
    _update(() {
      _submittingTask = true;
      _computeFormError = null;
      _taskActionFailure = null;
      _taskWriteScopeMissing = false;
    });
    try {
      final task = await _api.submitTask(
        sessionId: session.sessionId,
        task: request,
        idempotencyKey: key,
      );
      _computeIdempotencyKeys.remove(fingerprint);
      if (!_isCurrent(generation, session.sessionId) ||
          task.sessionId != session.sessionId) {
        return;
      }
      _update(() {
        _computeTasks = _mergeById(
          [task],
          _computeTasks,
          (item) => item.taskId,
          appendExisting: false,
          preserveTail: true,
        );
        _taskActionFailure = null;
      });
      unawaited(_refreshComputeTasks(silent: true));
    } catch (error) {
      if (!_isCurrent(generation, session.sessionId)) return;
      final status = error is AgentHubApiException ? error.statusCode : 0;
      _update(() {
        _taskWriteScopeMissing = _requiresAgentScope(error);
        _taskActionFailure = _taskWriteScopeMissing ? null : error;
        if (status >= 400 &&
            status < 500 &&
            !const {408, 409, 425, 429}.contains(status) &&
            !_taskWriteScopeMissing) {
          _computeIdempotencyKeys.remove(fingerprint);
        }
      });
    } finally {
      if (mounted) _update(() => _submittingTask = false);
    }
  }

  AgentComputeRequest _readComputeRequest() {
    final argv = AgentComputeRequest.parseArgvInput(
      _computeArgvController.text,
    );
    final cpu = _readInteger(_computeCpuController.text, 'CPU cores');
    final memoryMiB = _readInteger(_computeMemoryController.text, 'Memory');
    final timeout = _readInteger(_computeTimeoutController.text, 'Timeout');
    final gpuCount = _readInteger(_computeGpuCountController.text, 'GPU count');
    final gpuMemoryMiB = _readInteger(
      _computeGpuMemoryController.text,
      'GPU memory',
    );
    if (gpuMemoryMiB < 0 || gpuMemoryMiB > 1048576) {
      throw const FormatException('GPU memory must be between 0 and 1 TiB.');
    }
    if (memoryMiB < 0 || memoryMiB > 16777216) {
      throw const FormatException('Memory must fit a non-negative byte count.');
    }
    final runtimes = _computeRuntimesController.text
        .split(RegExp(r'\r?\n'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    return AgentComputeRequest(
      argv: argv,
      workdir: _workspaceSelection.enabled
          ? '.'
          : _computeWorkdirController.text,
      workspace: _workspaceSelection.toRequest(),
      timeout: timeout,
      resources: AgentTaskResources(
        cpuCores: cpu,
        memoryBytes: memoryMiB * 1024 * 1024,
        gpuCount: gpuCount,
        gpuMemoryBytes: gpuMemoryMiB * 1024 * 1024,
      ),
      requirements: AgentTaskRequirements(
        os: _computeOsController.text.trim(),
        architecture: _computeArchitectureController.text.trim(),
        runtimes: runtimes,
      ),
      targetDeviceId: _targetDeviceId,
      turnId: _turn?.turnId ?? '',
    );
  }

  int _readInteger(String value, String label) {
    final result = int.tryParse(value.trim());
    if (result == null) throw FormatException('$label must be a whole number.');
    return result;
  }

  Future<void> _cancelComputeTask(AgentComputeTask task) async {
    if (!task.canCancel || _cancellingTaskIds.contains(task.taskId)) return;
    final sessionId = task.sessionId;
    final generation = _selectionGeneration;
    _update(() {
      _cancellingTaskIds.add(task.taskId);
      _taskActionFailure = null;
      _taskCancelScopeMissing = false;
    });
    try {
      final updated = await _api.cancelTask(task.taskId);
      if (!_isCurrent(generation, sessionId) ||
          updated.sessionId != sessionId) {
        return;
      }
      _update(() {
        _taskDetails[task.taskId] = updated;
        _computeTasks = _mergeById(
          [updated],
          _computeTasks,
          (item) => item.taskId,
          appendExisting: false,
          preserveTail: true,
        );
      });
    } catch (error) {
      if (!_isCurrent(generation, sessionId)) return;
      _update(() {
        _taskCancelScopeMissing = _requiresAgentScope(error);
        _taskActionFailure = _taskCancelScopeMissing ? null : error;
      });
    } finally {
      if (mounted) _update(() => _cancellingTaskIds.remove(task.taskId));
    }
  }

  AgentComputeTask? _listedComputeTask(String taskId) {
    for (final task in _computeTasks) {
      if (task.taskId == taskId) return task;
    }
    return null;
  }

  Object _computeTaskVersion(AgentComputeTask? task) => (
    task?.state,
    task?.updatedAt,
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
