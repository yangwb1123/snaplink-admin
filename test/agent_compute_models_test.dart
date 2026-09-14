import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/agent_compute_models.dart';

void main() {
  test('argv input preserves argument boundaries without shell splitting', () {
    expect(
      AgentComputeRequest.parseArgvInput(
        jsonEncode([
          'python',
          '-c',
          "import sys; sys.stdout.write('hello world\\n')",
        ]),
      ),
      ['python', '-c', "import sys; sys.stdout.write('hello world\\n')"],
    );
    expect(
      AgentComputeRequest.parseArgvInput(
        "python\n-c\nimport sys; sys.stdout.write('hello world\\n')",
      ),
      ['python', '-c', "import sys; sys.stdout.write('hello world\\n')"],
    );
    expect(
      () => AgentComputeRequest.parseArgvInput('["python", 3]'),
      throwsFormatException,
    );
  });

  test('workdir cannot escape the operator configured project workspace', () {
    AgentComputeRequest request({required String workdir}) =>
        AgentComputeRequest(
          argv: const ['make', 'test'],
          workdir: workdir,
          timeout: 60,
          resources: const AgentTaskResources(cpuCores: 1, memoryBytes: 0),
          requirements: const AgentTaskRequirements(),
          targetDeviceId: '',
          turnId: '',
        );

    expect(request(workdir: '.').toJson()['workdir'], '.');
    expect(
      request(workdir: 'packages/app').toJson()['workdir'],
      'packages/app',
    );
    expect(() => request(workdir: '../secret'), throwsFormatException);
    expect(() => request(workdir: '/tmp'), throwsFormatException);
    expect(() => request(workdir: r'C:\tmp'), throwsFormatException);
  });

  test('request validation matches Hub resource and body bounds', () {
    AgentComputeRequest request({
      List<String> argv = const ['echo'],
      int timeout = 60,
      int cpuCores = 1,
      int memoryBytes = 0,
    }) => AgentComputeRequest(
      argv: argv,
      workdir: '.',
      timeout: timeout,
      resources: AgentTaskResources(
        cpuCores: cpuCores,
        memoryBytes: memoryBytes,
      ),
      requirements: const AgentTaskRequirements(),
      targetDeviceId: '',
      turnId: '',
    );

    expect(request(timeout: 3600).timeout, 3600);
    expect(request(cpuCores: 256).resources.cpuCores, 256);
    expect(
      request(
        memoryBytes: 16 * 1024 * 1024 * 1024 * 1024,
      ).resources.memoryBytes,
      16 * 1024 * 1024 * 1024 * 1024,
    );
    expect(() => request(timeout: 3601), throwsFormatException);
    expect(() => request(cpuCores: 257), throwsFormatException);
    expect(
      () => request(memoryBytes: 16 * 1024 * 1024 * 1024 * 1024 + 1),
      throwsFormatException,
    );
    expect(() => request(argv: List.filled(129, 'x')), throwsFormatException);
  });

  test('task result and artifact are bounded, typed evidence', () {
    final task = AgentComputeTask.fromJson({
      'task_id': 'task-1',
      'session_id': 'session-1',
      'state': 'cancel_requested',
      'result': {
        'exit_code': 1,
        'stdout': List.filled(AgentTaskResult.displayBytes + 10, 'x').join(),
        'stderr': 'stderr',
        'output_truncated': true,
        'evidence_digest': 'sha256:evidence',
      },
      'archive_state': 'archived',
      'artifact_ref': {
        'backend': 'aero-vault',
        'key': 'evidence/task-1',
        'version_id': 'v1',
        'etag': 'etag',
        'sha256': 'sha256:artifact',
        'size': 10,
        'bucket': 'artifacts',
      },
    });

    expect(task.isActive, isTrue);
    expect(task.canCancel, isFalse);
    expect(task.result!.stdout.length, AgentTaskResult.displayBytes);
    expect(task.result!.displayTruncated, isTrue);
    expect(task.result!.outputTruncated, isTrue);
    expect(task.result!.evidenceDigest, 'sha256:evidence');
    expect(task.artifactRef!.backend, 'aero-vault');
    expect(task.artifactRef!.versionId, 'v1');
  });

  test('output display limit respects UTF-8 bytes', () {
    final task = AgentComputeTask.fromJson({
      'task_id': 'task-2',
      'session_id': 'session-1',
      'state': 'completed',
      'result': {'stdout': List.filled(30000, '你').join(), 'stderr': ''},
    });

    expect(utf8.encode(task.result!.stdout).length, lessThanOrEqualTo(65536));
    expect(task.result!.displayTruncated, isTrue);
  });
}
