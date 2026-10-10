part of 'agent_operations_screen.dart';

extension _AgentOperationsComputeActions on _AgentOperationsScreenState {
  Future<void> _submitComputeTask() async {
    final session = _selectedSession;
    if (session == null ||
        _sessionCloseBlocked(session) ||
        _submittingTask ||
        _taskWriteScopeMissing) {
      return;
    }
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

  Future<void> _rescheduleComputeTask(AgentComputeTask task) async {
    if (!task.canReschedule ||
        _reschedulingTaskIds.contains(task.taskId) ||
        _taskWriteScopeMissing) {
      return;
    }
    final sessionId = task.sessionId;
    final generation = _selectionGeneration;
    _update(() {
      _reschedulingTaskIds.add(task.taskId);
      _taskActionFailure = null;
      _taskRescheduleScopeMissing = false;
    });
    try {
      final updated = await _api.rescheduleTask(
        task.taskId,
        targetDeviceId: _targetDeviceId,
      );
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
        _taskRescheduleScopeMissing = _requiresAgentScope(error);
        _taskActionFailure = _taskRescheduleScopeMissing ? null : error;
      });
    } finally {
      if (mounted) _update(() => _reschedulingTaskIds.remove(task.taskId));
    }
  }

  Future<void> _retryLostComputeTask(AgentComputeTask task) async {
    if (!task.canRetry ||
        _retryingTaskIds.contains(task.taskId) ||
        _taskWriteScopeMissing) {
      return;
    }
    final sessionId = task.sessionId;
    final generation = _selectionGeneration;
    _update(() {
      _retryingTaskIds.add(task.taskId);
      _taskActionFailure = null;
      _taskRetryScopeMissing = false;
    });
    try {
      final updated = await _api.retryLostTask(
        task.taskId,
        targetDeviceId: _targetDeviceId,
        confirmDuplicate: true,
      );
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
        _taskRetryScopeMissing = _requiresAgentScope(error);
        _taskActionFailure = _taskRetryScopeMissing ? null : error;
      });
    } finally {
      if (mounted) _update(() => _retryingTaskIds.remove(task.taskId));
    }
  }
}
