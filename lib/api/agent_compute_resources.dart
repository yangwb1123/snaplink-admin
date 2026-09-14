part of 'agent_compute_models.dart';

class AgentDevice {
  final String deviceId;
  final String instanceId;
  final String name;
  final bool online;
  final bool schedulable;
  final String lifecycleState;
  final String os;
  final String architecture;
  final int cpuCores;
  final int totalMemoryBytes;
  final int availableMemoryBytes;
  final int reservedCpuCores;
  final int reservedMemoryBytes;
  final List<String> runtimes;
  final int runningTasks;
  final List<String> projectIds;
  final DateTime? lastSeen;
  final String gpuStatus;
  final List<AgentGpu> gpus;
  final bool workspaceSupported;

  const AgentDevice({
    required this.deviceId,
    required this.instanceId,
    required this.name,
    required this.online,
    required this.schedulable,
    required this.lifecycleState,
    required this.os,
    required this.architecture,
    required this.cpuCores,
    required this.totalMemoryBytes,
    required this.availableMemoryBytes,
    required this.reservedCpuCores,
    required this.reservedMemoryBytes,
    required this.runtimes,
    required this.runningTasks,
    required this.projectIds,
    required this.lastSeen,
    this.workspaceSupported = false,
    this.gpuStatus = 'unavailable',
    this.gpus = const [],
  });

  factory AgentDevice.fromJson(AgentJson json) => AgentDevice(
    deviceId: _requiredComputeText(json, 'device_id'),
    instanceId: _optionalComputeText(json, 'instance_id'),
    name: _optionalComputeText(json, 'name'),
    online: json['online'] == true,
    schedulable: json['schedulable'] == true,
    lifecycleState: _optionalComputeText(
      json,
      'lifecycle_state',
      fallback: 'unknown',
    ),
    os: _optionalComputeText(json, 'os'),
    architecture: _optionalComputeText(json, 'architecture'),
    cpuCores: _nonNegativeInt(json, 'cpu_cores'),
    totalMemoryBytes: _nonNegativeInt(json, 'total_memory_bytes'),
    availableMemoryBytes: _nonNegativeInt(json, 'available_memory_bytes'),
    reservedCpuCores: _nonNegativeInt(json, 'reserved_cpu_cores'),
    reservedMemoryBytes: _nonNegativeInt(json, 'reserved_memory_bytes'),
    runtimes: _stringList(json, 'runtimes'),
    runningTasks: _nonNegativeInt(json, 'running_tasks'),
    projectIds: _stringList(json, 'project_ids'),
    lastSeen: _computeDate(json['last_seen']),
    gpuStatus: _optionalComputeText(
      json,
      'gpu_status',
      fallback: 'unavailable',
    ),
    gpus: AgentGpu.parseList(json['gpus']),
    workspaceSupported: json['workspace_supported'] == true,
  );

  int get freeCpuCores => (cpuCores - reservedCpuCores).clamp(0, cpuCores);

  String get availability {
    if (!online) return 'offline';
    if (runningTasks > 0) return 'busy';
    if (schedulable) return 'schedulable';
    return 'no resources';
  }
}

class AgentTaskResources {
  final int cpuCores;
  final int memoryBytes;
  final int gpuCount;
  final int gpuMemoryBytes;

  const AgentTaskResources({
    required this.cpuCores,
    required this.memoryBytes,
    this.gpuCount = 0,
    this.gpuMemoryBytes = 0,
  });

  factory AgentTaskResources.fromJson(Object? value) {
    final json = _optionalObject(value);
    final gpuCount = agentGpuInteger(json, 'gpu_count', fallback: 0);
    final gpuMemory = agentGpuInteger(json, 'gpu_memory_bytes', fallback: 0);
    validateAgentGpuResources(gpuCount, gpuMemory);
    return AgentTaskResources(
      gpuCount: gpuCount,
      gpuMemoryBytes: gpuMemory,
      cpuCores: _nonNegativeInt(json, 'cpu_cores'),
      memoryBytes: _nonNegativeInt(json, 'memory_bytes'),
    );
  }

  Map<String, dynamic> toJson() {
    validateAgentGpuResources(gpuCount, gpuMemoryBytes);
    return {
      'cpu_cores': cpuCores,
      'memory_bytes': memoryBytes,
      if (gpuCount > 0) 'gpu_count': gpuCount,
      if (gpuCount > 0) 'gpu_memory_bytes': gpuMemoryBytes,
    };
  }
}

class AgentTaskRequirements {
  final String os;
  final String architecture;
  final List<String> runtimes;

  const AgentTaskRequirements({
    this.os = '',
    this.architecture = '',
    this.runtimes = const [],
  });

  factory AgentTaskRequirements.fromJson(Object? value) {
    final json = _optionalObject(value);
    return AgentTaskRequirements(
      os: _optionalComputeText(json, 'os'),
      architecture: _optionalComputeText(json, 'architecture'),
      runtimes: _stringList(json, 'runtimes'),
    );
  }

  Map<String, dynamic> toJson() => {
    'os': os,
    'architecture': architecture,
    'runtimes': runtimes,
  };
}
