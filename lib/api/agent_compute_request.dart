part of 'agent_compute_models.dart';

class AgentComputeRequest {
  final List<String> argv;
  final String workdir;
  final int timeout;
  final AgentTaskResources resources;
  final AgentTaskRequirements requirements;
  final String targetDeviceId;
  final String turnId;
  final AgentWorkspaceRequest? workspace;

  const AgentComputeRequest._({
    required this.argv,
    required this.workdir,
    required this.timeout,
    required this.resources,
    required this.requirements,
    required this.targetDeviceId,
    required this.turnId,
    this.workspace,
  });

  factory AgentComputeRequest({
    required List<String> argv,
    required String workdir,
    required int timeout,
    required AgentTaskResources resources,
    required AgentTaskRequirements requirements,
    required String targetDeviceId,
    required String turnId,
    AgentWorkspaceRequest? workspace,
  }) {
    final relative = _validateRelativeWorkdir(workdir);
    if (workspace != null && relative != '.') {
      throw const FormatException(
        'Snapshot tasks must run at the workspace root.',
      );
    }
    if (argv.isEmpty || argv.first.trim().isEmpty) {
      throw const FormatException('Enter an executable and its arguments.');
    }
    if (timeout < 1 || timeout > 3600) {
      throw const FormatException(
        'Timeout must be between 1 and 3600 seconds.',
      );
    }
    if (resources.cpuCores < 1 || resources.cpuCores > 256) {
      throw const FormatException('CPU cores must be between 1 and 256.');
    }
    if (resources.memoryBytes < 0 ||
        resources.memoryBytes > 16 * 1024 * 1024 * 1024 * 1024) {
      throw const FormatException('Memory must be between 0 and 16 TiB.');
    }
    validateAgentGpuResources(resources.gpuCount, resources.gpuMemoryBytes);
    if (argv.length > 128 ||
        argv.any((argument) => argument.contains('\u0000')) ||
        utf8.encode(jsonEncode(argv)).length > 16 * 1024) {
      throw const FormatException('Arguments exceed the task request limit.');
    }
    if (requirements.runtimes.length > 32 ||
        requirements.runtimes.any(
          (runtime) => runtime.isEmpty || runtime.length > 64,
        ) ||
        requirements.os.length > 64 ||
        requirements.architecture.length > 64 ||
        targetDeviceId.length > 256 ||
        turnId.length > 256) {
      throw const FormatException(
        'Requirements exceed the task request limit.',
      );
    }
    final request = AgentComputeRequest._(
      argv: List.unmodifiable(argv),
      workdir: relative,
      timeout: timeout,
      resources: resources,
      requirements: requirements,
      targetDeviceId: targetDeviceId,
      turnId: turnId,
      workspace: workspace,
    );
    if (utf8.encode(jsonEncode(request.toJson())).length > 64 * 1024) {
      throw const FormatException('Compute request exceeds 64 KiB.');
    }
    return request;
  }

  Map<String, dynamic> toJson() => {
    'argv': argv,
    'workdir': workdir,
    'timeout': timeout,
    'resources': resources.toJson(),
    'requirements': requirements.toJson(),
    'target_device_id': targetDeviceId,
    'turn_id': turnId,
    if (workspace != null) 'workspace': workspace!.toJson(),
  };

  String get fingerprint => jsonEncode(toJson());

  static List<String> parseArgvInput(String value) {
    final trimmed = value.trim();
    if (trimmed.startsWith('[')) {
      final decoded = jsonDecode(trimmed);
      if (decoded is! List || decoded.any((item) => item is! String)) {
        throw const FormatException('Arguments must be a JSON string array.');
      }
      return decoded.cast<String>();
    }
    return value
        .replaceAll('\r\n', '\n')
        .split('\n')
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
  }
}

String _validateRelativeWorkdir(String value) {
  final path = value.trim().isEmpty ? '.' : value.trim();
  if (path.length > 512 ||
      path.contains('\\') ||
      path.contains('\u0000') ||
      path.startsWith('/') ||
      RegExp(r'^[A-Za-z]:').hasMatch(path)) {
    throw const FormatException(
      'Workdir must be relative to the project root.',
    );
  }
  final normalized = path.replaceAll('\\', '/');
  if (normalized.startsWith('/')) {
    throw const FormatException(
      'Workdir must be relative to the project root.',
    );
  }
  final segments = normalized.split('/');
  if (segments.contains('..')) {
    throw const FormatException('Workdir cannot leave the project root.');
  }
  return path;
}
