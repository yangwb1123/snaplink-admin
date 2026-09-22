import 'dart:convert';

import 'agent_hub_models.dart';
import 'agent_gpu_models.dart';
import 'agent_workspace_models.dart';

export 'agent_gpu_models.dart';
export 'agent_workspace_models.dart';

part 'agent_compute_resources.dart';
part 'agent_compute_request.dart';

class AgentArtifactRef {
  final String backend;
  final String key;
  final String versionId;
  final String etag;
  final String sha256;
  final int size;
  final String bucket;

  const AgentArtifactRef({
    required this.backend,
    required this.key,
    required this.versionId,
    required this.etag,
    required this.sha256,
    required this.size,
    required this.bucket,
  });

  factory AgentArtifactRef.fromJson(Object? value) {
    final json = _optionalObject(value);
    return AgentArtifactRef(
      backend: _optionalComputeText(json, 'backend'),
      key: _optionalComputeText(json, 'key'),
      versionId: _optionalComputeText(json, 'version_id'),
      etag: _optionalComputeText(json, 'etag'),
      sha256: _optionalComputeText(json, 'sha256'),
      size: _nonNegativeInt(json, 'size'),
      bucket: _optionalComputeText(json, 'bucket'),
    );
  }
}

class AgentTaskResult {
  static const int displayBytes = 64 * 1024;
  final int? exitCode;
  final bool timedOut;
  final bool cancelled;
  final String stdout;
  final String stderr;
  final bool outputTruncated;
  final bool displayTruncated;
  final double elapsed;
  final String evidenceDigest;

  const AgentTaskResult({
    required this.exitCode,
    required this.timedOut,
    required this.cancelled,
    required this.stdout,
    required this.stderr,
    required this.outputTruncated,
    required this.displayTruncated,
    required this.elapsed,
    required this.evidenceDigest,
  });

  factory AgentTaskResult.fromJson(Object? value) {
    final json = _optionalObject(value);
    final rawStdout = _optionalComputeText(json, 'stdout');
    final rawStderr = _optionalComputeText(json, 'stderr');
    final stdout = _boundedOutput(rawStdout);
    final stderr = _boundedOutput(rawStderr);
    return AgentTaskResult(
      exitCode: _optionalInt(json['exit_code']),
      timedOut: json['timed_out'] == true,
      cancelled: json['cancelled'] == true,
      stdout: stdout,
      stderr: stderr,
      outputTruncated: json['output_truncated'] == true,
      displayTruncated:
          stdout.length != rawStdout.length ||
          stderr.length != rawStderr.length,
      elapsed: _nonNegativeDouble(json['elapsed']),
      evidenceDigest: _optionalComputeText(json, 'evidence_digest'),
    );
  }
}

class AgentComputeTask {
  final String taskId;
  final String sessionId;
  final String instanceId;
  final String turnId;
  final String actor;
  final String projectId;
  final String state;
  final String deviceId;
  final String targetDeviceId;
  final String deviceInstanceId;
  final List<String> argv;
  final String workdir;
  final int timeout;
  final AgentTaskResources resources;
  final AgentTaskRequirements requirements;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String error;
  final AgentTaskResult? result;
  final String archiveState;
  final AgentArtifactRef? artifactRef;
  final AgentGpuAssignment? gpuAssignment;
  final AgentWorkspaceRequest? workspace;
  final AgentWorkspaceResult? workspaceResult;

  const AgentComputeTask({
    required this.taskId,
    required this.sessionId,
    required this.instanceId,
    required this.turnId,
    required this.actor,
    required this.projectId,
    required this.state,
    required this.deviceId,
    required this.targetDeviceId,
    required this.deviceInstanceId,
    required this.argv,
    required this.workdir,
    required this.timeout,
    required this.resources,
    required this.requirements,
    required this.createdAt,
    required this.updatedAt,
    required this.error,
    required this.result,
    required this.archiveState,
    required this.artifactRef,
    this.gpuAssignment,
    this.workspace,
    this.workspaceResult,
  });

  factory AgentComputeTask.fromJson(AgentJson json) {
    final rawResult = json['result'];
    final rawArtifact = json['artifact_ref'];
    return AgentComputeTask(
      taskId: _requiredComputeText(json, 'task_id'),
      sessionId: _requiredComputeText(json, 'session_id'),
      instanceId: _optionalComputeText(json, 'instance_id'),
      turnId: _optionalComputeText(json, 'turn_id'),
      actor: _optionalComputeText(json, 'actor'),
      projectId: _optionalComputeText(json, 'project_id'),
      state: _optionalComputeText(json, 'state', fallback: 'unknown'),
      deviceId: _optionalComputeText(json, 'device_id'),
      targetDeviceId: _optionalComputeText(json, 'target_device_id'),
      deviceInstanceId: _optionalComputeText(json, 'device_instance_id'),
      argv: _stringList(json, 'argv'),
      workdir: _optionalComputeText(json, 'workdir', fallback: '.'),
      timeout: _nonNegativeInt(json, 'timeout'),
      resources: AgentTaskResources.fromJson(json['resources']),
      gpuAssignment: json['gpu_assignment'] == null
          ? null
          : AgentGpuAssignment.fromJson(json['gpu_assignment']!),
      requirements: AgentTaskRequirements.fromJson(json['requirements']),
      workspace: json['workspace'] == null
          ? null
          : AgentWorkspaceRequest.fromJson(json['workspace']),
      workspaceResult: json['workspace_result'] == null
          ? null
          : AgentWorkspaceResult.fromJson(json['workspace_result']),
      createdAt: _computeDate(json['created_at']),
      updatedAt: _computeDate(json['updated_at']),
      error: _optionalComputeText(json, 'error'),
      result: _hasFields(rawResult)
          ? AgentTaskResult.fromJson(rawResult)
          : null,
      archiveState: _optionalComputeText(
        json,
        'archive_state',
        fallback: 'disabled',
      ),
      artifactRef: _hasFields(rawArtifact)
          ? AgentArtifactRef.fromJson(rawArtifact)
          : null,
    );
  }

  bool get isActive => const {
    'queued',
    'dispatching',
    'running',
    'cancel_requested',
  }.contains(state.toLowerCase());

  bool get canCancel =>
      const {'queued', 'dispatching', 'running'}.contains(state.toLowerCase());

  bool get canReschedule => state.toLowerCase() == 'queued';

  /// A lost task may have run remotely; retry is always an explicit action.
  bool get canRetry => state.toLowerCase() == 'lost';
}

bool _hasFields(Object? value) => value is Map && value.isNotEmpty;

AgentJson _optionalObject(Object? value) {
  if (value == null) return const {};
  if (value is! Map) {
    throw const FormatException('Invalid Agent compute object.');
  }
  return Map<String, dynamic>.from(value);
}

String _requiredComputeText(AgentJson json, String key) {
  final value = _optionalComputeText(json, key);
  if (value.isEmpty) {
    throw FormatException('Missing Agent compute field: $key.');
  }
  return value;
}

String _optionalComputeText(
  AgentJson json,
  String key, {
  String fallback = '',
}) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : fallback;
}

List<String> _stringList(AgentJson json, String key) {
  final value = json[key];
  if (value == null) return const [];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Invalid Agent compute list: $key.');
  }
  return List.unmodifiable(value.cast<String>());
}

int _nonNegativeInt(AgentJson json, String key) {
  final value = _optionalInt(json[key]) ?? 0;
  if (value < 0) throw FormatException('Invalid Agent compute count: $key.');
  return value;
}

int? _optionalInt(Object? value) {
  if (value is int) return value;
  if (value is num && value.isFinite) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double _nonNegativeDouble(Object? value) {
  final number = value is num
      ? value.toDouble()
      : double.tryParse('$value') ?? 0;
  return number.isFinite && number >= 0 ? number : 0;
}

DateTime? _computeDate(Object? value) {
  if (value is num && value.isFinite) {
    final milliseconds = (value.abs() < 100000000000 ? value * 1000 : value)
        .toInt();
    return DateTime.fromMillisecondsSinceEpoch(milliseconds, isUtc: true);
  }
  if (value is String && value.trim().isNotEmpty) {
    final numeric = num.tryParse(value);
    if (numeric != null) return _computeDate(numeric);
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}

String _boundedOutput(String value) {
  final output = StringBuffer();
  var bytes = 0;
  for (final rune in value.runes) {
    final runeBytes = rune <= 0x7f
        ? 1
        : rune <= 0x7ff
        ? 2
        : rune <= 0xffff
        ? 3
        : 4;
    if (bytes + runeBytes > AgentTaskResult.displayBytes) break;
    output.writeCharCode(rune);
    bytes += runeBytes;
  }
  return output.toString();
}
