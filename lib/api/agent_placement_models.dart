import 'dart:convert';

const agentPlacementReasons = {
  'device_offline',
  'device_not_ready',
  'device_busy',
  'device_unavailable',
  'project_unavailable',
  'target_not_authorized',
  'target_mismatch',
  'workspace_unsupported',
  'cpu_insufficient',
  'memory_insufficient',
  'os_mismatch',
  'architecture_mismatch',
  'runtime_missing',
  'gpu_unavailable',
  'gpu_insufficient',
  'inventory_missing',
};

String validateAgentPlacementId(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value != value.trim() ||
      value.runes.length > 256 ||
      utf8.decode(utf8.encode(value)) != value ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid placement identifier.');
  }
  return value;
}

// Hub sorts Unicode code points, while Dart String.compareTo sorts UTF-16.
int _compareIds(String left, String right) {
  final a = left.runes.iterator;
  final b = right.runes.iterator;
  while (a.moveNext()) {
    if (!b.moveNext()) return 1;
    final compared = a.current.compareTo(b.current);
    if (compared != 0) return compared;
  }
  return b.moveNext() ? -1 : 0;
}

Map<String, dynamic> _fields(Object? value, Set<String> fields) {
  if (value is! Map<String, dynamic> ||
      value.length != fields.length ||
      !fields.containsAll(value.keys)) {
    throw const FormatException('Invalid placement fields.');
  }
  return value;
}

class AgentPlacementDevice {
  final String deviceId;
  final String instanceId;
  final bool eligible;
  final List<String> reasons;

  const AgentPlacementDevice({
    required this.deviceId,
    required this.instanceId,
    required this.eligible,
    required this.reasons,
  });

  factory AgentPlacementDevice.fromJson(Object? value) {
    final row = _fields(value, {
      'device_id',
      'instance_id',
      'eligible',
      'reasons',
    });
    final eligible = row['eligible'];
    final reasons = row['reasons'];
    if (eligible is! bool ||
        reasons is! List ||
        reasons.any((reason) => !agentPlacementReasons.contains(reason)) ||
        reasons.toSet().length != reasons.length ||
        eligible != reasons.isEmpty) {
      throw const FormatException('Invalid placement eligibility.');
    }
    return AgentPlacementDevice(
      deviceId: validateAgentPlacementId(row['device_id']),
      instanceId: validateAgentPlacementId(row['instance_id']),
      eligible: eligible,
      reasons: List<String>.unmodifiable(reasons),
    );
  }
}

/// A bounded observation. Eligibility does not reserve execution capacity.
class AgentTaskPlacement {
  final String taskId;
  final String state;
  final num evaluatedAt;
  final List<AgentPlacementDevice> devices;
  final String nextCursor;

  const AgentTaskPlacement({
    required this.taskId,
    required this.state,
    required this.evaluatedAt,
    required this.devices,
    required this.nextCursor,
  });

  factory AgentTaskPlacement.fromJson(
    Object? value, {
    required String taskId,
    String after = '',
    int limit = 20,
  }) {
    final data = _fields(value, {
      'task_id',
      'state',
      'evaluated_at',
      'devices',
      'next_cursor',
    });
    final state = data['state'];
    final time = data['evaluated_at'];
    final rows = data['devices'];
    final next = data['next_cursor'];
    if (validateAgentPlacementId(data['task_id']) != taskId ||
        !const {
          'queued',
          'dispatching',
          'running',
          'cancel_requested',
          'completed',
          'failed',
          'cancelled',
          'lost',
        }.contains(state) ||
        time is! num ||
        !time.isFinite ||
        !time.toDouble().isFinite ||
        time < 0 ||
        rows is! List ||
        rows.length > limit ||
        rows.length > 20 ||
        next is! String) {
      throw const FormatException('Invalid placement observation.');
    }
    if (next.isNotEmpty) validateAgentPlacementId(next);
    final devices = rows.map(AgentPlacementDevice.fromJson).toList();
    var previous = after;
    for (final device in devices) {
      if (_compareIds(device.deviceId, previous) <= 0) {
        throw const FormatException('Invalid placement device order.');
      }
      previous = device.deviceId;
    }
    if ((state != 'queued' && (devices.isNotEmpty || next.isNotEmpty)) ||
        (next.isNotEmpty &&
            (devices.isEmpty ||
                next != devices.last.deviceId ||
                next == after))) {
      throw const FormatException('Invalid placement cursor.');
    }
    return AgentTaskPlacement(
      taskId: taskId,
      state: state as String,
      evaluatedAt: time,
      devices: List.unmodifiable(devices),
      nextCursor: next,
    );
  }
}
