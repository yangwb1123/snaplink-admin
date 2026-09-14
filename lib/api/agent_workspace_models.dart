import 'agent_workspace_bundle.dart';

export 'agent_workspace_bundle.dart';

class AgentWorkspaceRequest {
  final String snapshotId;
  final List<String> outputs;

  const AgentWorkspaceRequest._(this.snapshotId, this.outputs);

  factory AgentWorkspaceRequest({
    required String snapshotId,
    required List<String> outputs,
  }) {
    if (snapshotId.isEmpty ||
        snapshotId.length > 128 ||
        snapshotId != snapshotId.trim() ||
        RegExp(r'[\x00-\x1f\x7f]').hasMatch(snapshotId)) {
      throw const FormatException('Choose a workspace snapshot.');
    }
    if (outputs.length > AgentWorkspaceBundle.maxFiles) {
      throw const FormatException(
        'Workspace accepts at most 128 output paths.',
      );
    }
    final paths = outputs.map(validateAgentWorkspacePath).toList()
      ..sort(compareWorkspacePaths);
    validateAgentWorkspacePathSet(paths);
    return AgentWorkspaceRequest._(snapshotId, List.unmodifiable(paths));
  }

  factory AgentWorkspaceRequest.fromJson(Object? value) {
    final json = workspaceObject(value);
    final outputs = json['outputs'];
    if (outputs is! List || outputs.any((item) => item is! String)) {
      throw const FormatException('Invalid workspace output paths.');
    }
    return AgentWorkspaceRequest(
      snapshotId: workspaceText(json, 'snapshot_id'),
      outputs: outputs.cast<String>(),
    );
  }

  Map<String, dynamic> toJson() => {
    'snapshot_id': snapshotId,
    'outputs': outputs,
  };
}

class AgentWorkspaceSnapshot {
  final String snapshotId;
  final String sessionId;
  final String instanceId;
  final String projectId;
  final String sha256;
  final int size;
  final int fileCount;
  final DateTime createdAt;
  final Map<String, dynamic> artifactRef;

  const AgentWorkspaceSnapshot._(
    this.snapshotId,
    this.sessionId,
    this.instanceId,
    this.projectId,
    this.sha256,
    this.size,
    this.fileCount,
    this.createdAt,
    this.artifactRef,
  );

  factory AgentWorkspaceSnapshot.fromJson(Map<String, dynamic> json) {
    final time = json['created_at'];
    if (time is! num || !time.isFinite || time <= 0 || time > 1e12) {
      throw const FormatException('Invalid workspace creation time.');
    }
    return AgentWorkspaceSnapshot._(
      workspaceText(json, 'snapshot_id'),
      workspaceText(json, 'session_id'),
      workspaceText(json, 'instance_id'),
      workspaceText(json, 'project_id'),
      workspaceDigest(json['sha256']),
      _boundedCount(json['size'], 1, AgentWorkspaceBundle.maxJsonBytes),
      _boundedCount(json['file_count'], 0, AgentWorkspaceBundle.maxFiles),
      DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt(), isUtc: true),
      Map.unmodifiable(workspaceObject(json['artifact_ref'])),
    );
  }
}

class AgentWorkspaceResult {
  final String inputSha256;
  final String outputSha256;
  final String state;
  final Map<String, dynamic> artifactRef;

  const AgentWorkspaceResult._(
    this.inputSha256,
    this.outputSha256,
    this.state,
    this.artifactRef,
  );

  factory AgentWorkspaceResult.fromJson(Object? value) {
    final json = workspaceObject(value);
    final state = json['state'];
    if (!const {'pending', 'ready', 'failed', 'unavailable'}.contains(state)) {
      throw const FormatException('Invalid workspace output state.');
    }
    return AgentWorkspaceResult._(
      workspaceDigest(json['input_sha256']),
      json['output_sha256'] == '' && state != 'ready'
          ? ''
          : workspaceDigest(json['output_sha256']),
      state as String,
      Map.unmodifiable(workspaceObject(json['artifact_ref'])),
    );
  }
}

class AgentWorkspaceDownload {
  final String inputSha256;
  final String outputSha256;
  final AgentWorkspaceBundle bundle;

  const AgentWorkspaceDownload._(
    this.inputSha256,
    this.outputSha256,
    this.bundle,
  );

  factory AgentWorkspaceDownload.verified(
    Object? value,
    AgentWorkspaceResult expected,
  ) {
    final json = workspaceObject(value);
    final input = workspaceDigest(json['input_sha256']);
    final output = workspaceDigest(json['output_sha256']);
    final bundle = AgentWorkspaceBundle.fromJson(json['bundle']);
    if (expected.state != 'ready' ||
        input != expected.inputSha256 ||
        output != expected.outputSha256 ||
        output != bundle.sha256) {
      throw const FormatException('Workspace checksum verification failed.');
    }
    return AgentWorkspaceDownload._(input, output, bundle);
  }
}

Map<String, dynamic> workspaceObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Invalid workspace response.');
  }
  return Map<String, dynamic>.from(value);
}

String workspaceText(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String ||
      value.isEmpty ||
      value.length > 256 ||
      value != value.trim() ||
      RegExp(r'[\x00-\x1f\x7f]').hasMatch(value)) {
    throw const FormatException('Invalid workspace identifier.');
  }
  return value;
}

String workspaceDigest(Object? value) {
  if (value is! String || !RegExp(r'^[a-f0-9]{64}$').hasMatch(value)) {
    throw const FormatException('Invalid workspace checksum.');
  }
  return value;
}

int _boundedCount(Object? value, int min, int max) {
  if (value is! int || value < min || value > max) {
    throw const FormatException('Invalid workspace size or file count.');
  }
  return value;
}
