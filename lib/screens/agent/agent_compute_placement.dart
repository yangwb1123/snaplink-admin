import 'package:flutter/foundation.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/api/agent_placement_models.dart';

/// Explicit, read-only observations for one task and one authenticated context.
class AgentComputePlacement extends ChangeNotifier {
  final AgentHubApi api;
  final String taskId;
  final bool Function() isCurrent;
  AgentTaskPlacement? page;
  String? error;
  bool busy = false;
  bool invalidated = false;
  int _generation = 0;
  bool _disposed = false;

  AgentComputePlacement({
    required this.api,
    required this.taskId,
    required this.isCurrent,
  });

  bool checkContext() {
    if (_disposed || invalidated) return false;
    if (isCurrent()) return true;
    _generation++;
    invalidated = true;
    page = null;
    busy = false;
    error = 'Your sign-in or selected session changed. Reopen task placement.';
    notifyListeners();
    return false;
  }

  Future<void> load({bool next = false}) async {
    if (!checkContext() || busy) return;
    final after = next ? page?.nextCursor ?? '' : '';
    if (next && after.isEmpty) return;
    page = null;
    error = null;
    busy = true;
    final generation = ++_generation;
    notifyListeners();
    try {
      final observation = await api.taskPlacement(taskId, after: after);
      if (checkContext() && generation == _generation) page = observation;
    } catch (failure) {
      if (checkContext() && generation == _generation) {
        error = placementError(failure);
      }
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    page = null;
    super.dispose();
  }
}

String placementError(Object failure) {
  if (failure is AgentHubApiException) {
    if (const {401, 403}.contains(failure.statusCode)) {
      return 'You do not have permission to inspect task placement.';
    }
    if (const {404, 405, 501}.contains(failure.statusCode)) {
      return 'This Agent Hub does not support task placement diagnostics yet.';
    }
  }
  if (failure is FormatException) {
    return 'Agent Hub returned an invalid response.';
  }
  return 'Could not inspect task placement. Refresh to try again.';
}

String placementReason(String reason) => switch (reason) {
  'device_offline' => 'Device is offline',
  'device_not_ready' => 'Device lifecycle is not ready',
  'device_busy' => 'Device is busy',
  'device_unavailable' => 'Device is not schedulable',
  'project_unavailable' => 'Project is unavailable on this device',
  'target_not_authorized' => 'Task target is not authorized',
  'target_mismatch' => 'Device does not match the requested target',
  'workspace_unsupported' => 'Workspace snapshots are unsupported',
  'cpu_insufficient' => 'Insufficient available CPU',
  'memory_insufficient' => 'Insufficient available memory',
  'os_mismatch' => 'Operating system does not match',
  'architecture_mismatch' => 'Architecture does not match',
  'runtime_missing' => 'Required runtime is unavailable',
  'gpu_unavailable' => 'GPU inventory is unavailable',
  'gpu_insufficient' => 'Insufficient eligible GPU capacity',
  'inventory_missing' => 'Device inventory is missing',
  _ => 'Device is not schedulable',
};

String? placementObservationTime(num seconds) {
  if (!seconds.isFinite || seconds < 0 || seconds > 8640000000000) return null;
  try {
    return DateTime.fromMillisecondsSinceEpoch(
      (seconds * 1000).round(),
      isUtc: true,
    ).toLocal().toString().split('.').first;
  } on ArgumentError {
    return null;
  }
}
