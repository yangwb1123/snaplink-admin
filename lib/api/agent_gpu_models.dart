import 'agent_hub_models.dart';

const agentMaxGpuMemoryBytes = 1024 * 1024 * 1024 * 1024;

/// The request is a whole-card selection with a minimum free memory filter.
/// It does not describe an enforced VRAM limit or a GPU isolation boundary.
void validateAgentGpuResources(int count, int memoryBytes) {
  if (count < 0 || count > 16) {
    throw const FormatException('GPU count must be between 0 and 16.');
  }
  if (memoryBytes < 0 || memoryBytes > agentMaxGpuMemoryBytes) {
    throw const FormatException('GPU memory must be between 0 and 1 TiB.');
  }
  if (count == 0 && memoryBytes != 0) {
    throw const FormatException(
      'GPU memory must be zero when GPU count is zero.',
    );
  }
}

int agentGpuInteger(AgentJson json, String key, {int? fallback}) {
  final value = json[key];
  if (value == null && fallback != null) return fallback;
  if (value is! int || value < 0) {
    throw FormatException('Invalid Agent GPU integer: $key.');
  }
  return value;
}

class AgentGpu {
  final String uuid;
  final String name;
  final String vendor;
  final int totalMemoryBytes;
  final int availableMemoryBytes;
  final bool schedulable;
  final bool reserved;
  final DateTime observedAt;

  const AgentGpu({
    required this.uuid,
    required this.name,
    required this.vendor,
    required this.totalMemoryBytes,
    required this.availableMemoryBytes,
    required this.schedulable,
    required this.reserved,
    required this.observedAt,
  });

  factory AgentGpu.fromJson(AgentJson json) {
    final total = agentGpuInteger(json, 'total_memory_bytes');
    final available = agentGpuInteger(json, 'available_memory_bytes');
    if (total == 0 ||
        total > agentMaxGpuMemoryBytes ||
        available > total ||
        !_isPhysicalGpuUuid(json['uuid']) ||
        json['vendor'] != 'nvidia' ||
        json['schedulable'] is! bool ||
        json['reserved'] is! bool) {
      throw const FormatException('Invalid Agent GPU inventory.');
    }
    return AgentGpu(
      uuid: json['uuid'] as String,
      name: _gpuText(json, 'name'),
      vendor: 'nvidia',
      totalMemoryBytes: total,
      availableMemoryBytes: available,
      schedulable: json['schedulable'] == true,
      reserved: json['reserved'] == true,
      observedAt: _gpuDate(json, 'observed_at'),
    );
  }

  static List<AgentGpu> parseList(Object? value) {
    if (value == null) return const [];
    if (value is! List ||
        value.length > 16 ||
        value.any((item) => item is! Map)) {
      throw const FormatException('Invalid Agent GPU inventory.');
    }
    final gpus = value
        .map(
          (item) => AgentGpu.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList(growable: false);
    if (gpus.map((gpu) => gpu.uuid.toLowerCase()).toSet().length !=
        gpus.length) {
      throw const FormatException('Duplicate Agent GPU inventory UUID.');
    }
    return List.unmodifiable(gpus);
  }
}

class AgentGpuAssignment {
  final String vendor;
  final String mode;
  final List<String> uuids;
  final int gpuMemoryBytes;
  final DateTime assignedAt;
  final DateTime observedAt;

  const AgentGpuAssignment({
    required this.vendor,
    required this.mode,
    required this.uuids,
    required this.gpuMemoryBytes,
    required this.assignedAt,
    required this.observedAt,
  });

  factory AgentGpuAssignment.fromJson(Object value) {
    if (value is! Map) {
      throw const FormatException('Invalid Agent GPU assignment.');
    }
    final json = Map<String, dynamic>.from(value);
    final uuids = json['uuids'];
    if (json['vendor'] != 'nvidia' ||
        json['mode'] != 'physical' ||
        uuids is! List ||
        uuids.isEmpty ||
        uuids.length > 16 ||
        uuids.any((uuid) => !_isPhysicalGpuUuid(uuid)) ||
        uuids.cast<String>().map((uuid) => uuid.toLowerCase()).toSet().length !=
            uuids.length) {
      throw const FormatException('Invalid Agent GPU assignment.');
    }
    final memory = agentGpuInteger(json, 'gpu_memory_bytes');
    validateAgentGpuResources(uuids.length, memory);
    final assignedAt = _gpuDate(json, 'assigned_at');
    final observedAt = _gpuDate(json, 'observed_at');
    if ((json['observed_at'] as num) > (json['assigned_at'] as num)) {
      throw const FormatException('Agent GPU observation is after assignment.');
    }
    return AgentGpuAssignment(
      vendor: 'nvidia',
      mode: 'physical',
      uuids: List.unmodifiable(uuids.cast<String>()),
      gpuMemoryBytes: memory,
      assignedAt: assignedAt,
      observedAt: observedAt,
    );
  }
}

String _gpuText(AgentJson json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid Agent GPU text: $key.');
  }
  return value.trim();
}

DateTime _gpuDate(AgentJson json, String key) {
  final value = json[key];
  if (value is! num || !value.isFinite || value <= 0 || value > 1000000000000) {
    throw FormatException('Invalid Agent GPU timestamp: $key.');
  }
  return DateTime.fromMillisecondsSinceEpoch(
    (value * 1000).toInt(),
    isUtc: true,
  );
}

final _physicalGpuUuid = RegExp(
  r'^GPU-[0-9a-fA-F]{8}(?:-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$',
);

bool _isPhysicalGpuUuid(Object? value) =>
    value is String && value.length == 40 && _physicalGpuUuid.hasMatch(value);
