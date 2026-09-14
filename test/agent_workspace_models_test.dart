import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/agent_compute_models.dart';

import 'fixtures/agent_workspace_fixture.dart';

Map<String, dynamic> _bundle(List<Map<String, String>> files) => {
  'schema': AgentWorkspaceBundle.schema,
  'files': files,
};
Map<String, String> _file(String path, [int bytes = 0]) => {
  'path': path,
  'content_b64': base64Encode(List.filled(bytes, 0)),
};

void main() {
  test(
    'combined compute JSON respects 64 KiB even with individually valid outputs',
    () {
      final workspace = AgentWorkspaceRequest(
        snapshotId: 's',
        outputs: List.generate(
          128,
          (i) => '${'$i'.padRight(255, 'a')}/${'b' * 255}',
        ),
      );
      expect(
        () => AgentComputeRequest(
          argv: ['echo'],
          workdir: '.',
          timeout: 60,
          resources: const AgentTaskResources(cpuCores: 1, memoryBytes: 0),
          requirements: const AgentTaskRequirements(),
          targetDeviceId: '',
          turnId: '',
          workspace: workspace,
        ),
        throwsFormatException,
      );
      for (final id in [' snap', 'snap ', 'snap\u0000']) {
        expect(
          () => AgentWorkspaceRequest(snapshotId: id, outputs: []),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'canonical bundle matches independent Python UTF8 fixture and is immutable',
    () {
      final bundle = workspaceBundle();
      expect(
        bundle.canonicalJson,
        '{"files":[{"content_b64":"YQ==","path":"a.txt"},{"content_b64":"AAE=","path":"z/é.txt"}],"schema":"pbatch.workspace.v1"}',
      );
      expect(
        bundle.sha256,
        'a388cd8e87940f10987df742843a470dfbdb1b3735fd30e377d2b4b6cf174202',
      );
      expect(bundle.size, utf8.encode(bundle.canonicalJson).length);
      expect(bundle.rawSize, 3);
      expect(
        () => bundle.files.first['path'] = 'mutated',
        throwsUnsupportedError,
      );
      expect(() => bundle.files.clear(), throwsUnsupportedError);
      expect(
        AgentWorkspaceBundle.parse(jsonEncode(bundle.toJson())).sha256,
        bundle.sha256,
      );
    },
  );

  test('sorts Unicode codepoints rather than UTF16 code units', () {
    final bundle = AgentWorkspaceBundle.fromJson(
      _bundle([_file('😀'), _file('\ue000')]),
    );
    expect(bundle.files.map((item) => item['path']), ['\ue000', '😀']);
    expect(
      bundle.sha256,
      '4d7598075fd5499d637446a14d70b8a41712ca041312bdba2248d513b72c432f',
    );
    final outputs = AgentWorkspaceRequest(
      snapshotId: 's',
      outputs: ['😀', '\ue000'],
    );
    expect(outputs.outputs, ['\ue000', '😀']);
  });

  test('rejects malformed schema, JSON, entries and noncanonical base64', () {
    for (final bad in [
      null,
      [],
      {},
      {..._bundle([]), 'extra': true},
      {'schema': 'unknown', 'files': []},
      _bundle([
        {'path': 'a'},
      ]),
      _bundle([
        {'path': 'a', 'content_b64': 'YQ'},
      ]),
      _bundle([
        {'path': 'a', 'content_b64': 'YR=='},
      ]),
      _bundle([
        {'path': 'a', 'content_b64': 'YQ==\n'},
      ]),
      _bundle([
        {'path': 'a', 'content_b64': '!!!!'},
      ]),
    ]) {
      expect(
        () => AgentWorkspaceBundle.fromJson(bad),
        throwsFormatException,
        reason: '$bad',
      );
    }
    expect(() => AgentWorkspaceBundle.parse('not json'), throwsFormatException);
    expect(
      () => AgentWorkspaceBundle.parse('${' ' * (512 * 1024)}{}'),
      throwsFormatException,
    );
  });

  test('enforces inclusive file count, per file and aggregate raw bounds', () {
    expect(
      AgentWorkspaceBundle.fromJson(
        _bundle(List.generate(128, (i) => _file('$i'))),
      ).files.length,
      128,
    );
    expect(
      () => AgentWorkspaceBundle.fromJson(
        _bundle(List.generate(129, (i) => _file('$i'))),
      ),
      throwsFormatException,
    );
    expect(
      AgentWorkspaceBundle.fromJson(_bundle([_file('a', 65536)])).rawSize,
      65536,
    );
    expect(
      () => AgentWorkspaceBundle.fromJson(_bundle([_file('a', 65537)])),
      throwsFormatException,
    );
    expect(
      AgentWorkspaceBundle.fromJson(
        _bundle(List.generate(4, (i) => _file('$i', 65536))),
      ).rawSize,
      262144,
    );
    expect(
      () => AgentWorkspaceBundle.fromJson(
        _bundle([
          ...List.generate(4, (i) => _file('$i', 65536)),
          _file('extra', 1),
        ]),
      ),
      throwsFormatException,
    );
  });

  test(
    'portable paths reject traversal, controls, devices, unsafe segments and surrogate input',
    () {
      for (final path in [
        '',
        '/root',
        '../a',
        'a/../b',
        'a/./b',
        'a//b',
        'a/',
        r'a\b',
        'C:/a',
        'a\u0000b',
        'a\u0085b',
        'a:',
        'a?',
        'a*',
        'a<',
        'a>',
        'a"',
        'a|',
        'CON',
        'nul.txt',
        'com¹.log',
        'LPT9',
        'a.',
        'a ',
        'a/${'b' * 256}',
        'é' * 128,
        '${'a' * 255}/${'b' * 255}/c',
        String.fromCharCode(0xd800),
      ]) {
        expect(
          () => validateAgentWorkspacePath(path),
          throwsFormatException,
          reason: path,
        );
      }
      expect(validateAgentWorkspacePath('项目/[name].txt'), '项目/[name].txt');
      expect(
        validateAgentWorkspacePath('${'a' * 255}/${'b' * 255}'),
        hasLength(511),
      );
    },
  );

  test(
    'rejects case insensitive duplicate paths and file-parent collisions',
    () {
      for (final files in [
        [_file('A'), _file('a')],
        [_file('a'), _file('a')],
        [_file('a/b'), _file('A')],
      ]) {
        expect(
          () => AgentWorkspaceBundle.fromJson(_bundle(files)),
          throwsFormatException,
        );
        expect(
          () => AgentWorkspaceRequest(
            snapshotId: 's',
            outputs: files.map((f) => f['path']!).toList(),
          ),
          throwsFormatException,
        );
      }
    },
  );

  test('request workspace remains optional and requires root workdir', () {
    AgentComputeRequest task({
      AgentWorkspaceRequest? workspace,
      String workdir = '.',
    }) => AgentComputeRequest(
      argv: ['echo', 'done'],
      workdir: workdir,
      timeout: 60,
      resources: const AgentTaskResources(cpuCores: 1, memoryBytes: 0),
      requirements: const AgentTaskRequirements(),
      targetDeviceId: '',
      turnId: '',
      workspace: workspace,
    );
    final workspace = AgentWorkspaceRequest(snapshotId: 'snap-1', outputs: []);
    expect(task().toJson().containsKey('workspace'), isFalse);
    expect(task(workspace: workspace).toJson()['workspace'], {
      'snapshot_id': 'snap-1',
      'outputs': [],
    });
    expect(task().fingerprint, isNot(task(workspace: workspace).fingerprint));
    expect(
      () => task(workspace: workspace, workdir: 'src'),
      throwsFormatException,
    );
    expect(
      () => AgentWorkspaceRequest(snapshotId: '', outputs: []),
      throwsFormatException,
    );
    expect(
      () => AgentWorkspaceRequest(snapshotId: 'a' * 129, outputs: []),
      throwsFormatException,
    );
    expect(
      () => AgentWorkspaceRequest(
        snapshotId: 's',
        outputs: List.generate(129, (i) => '$i'),
      ),
      throwsFormatException,
    );
  });

  test(
    'snapshot and result bounds reject bad DTO fields; legacy tasks remain compatible',
    () {
      final valid = workspaceSnapshot();
      for (final bad in [
        {'size': 524289},
        {'size': 1.5},
        {'file_count': 129},
        {'file_count': -1},
        {'created_at': 0},
        {'created_at': double.infinity},
        {'created_at': 1e12 + 1},
        {'sha256': 'SHA256'},
        {'artifact_ref': []},
      ]) {
        expect(
          () => AgentWorkspaceSnapshot.fromJson({...valid, ...bad}),
          throwsFormatException,
        );
      }
      final task = AgentComputeTask.fromJson({
        'task_id': 't',
        'session_id': 's',
      });
      expect(task.workspaceResult, isNull);
      expect(task.workspace, isNull);
      for (final state in ['pending', 'ready', 'failed', 'unavailable']) {
        expect(
          AgentWorkspaceResult.fromJson(workspaceResult(state: state)).state,
          state,
        );
      }
      expect(
        () => AgentWorkspaceResult.fromJson({
          ...workspaceResult(),
          'state': 'unknown',
        }),
        throwsFormatException,
      );
      expect(
        () => AgentWorkspaceResult.fromJson({
          ...workspaceResult(),
          'output_sha256': '',
        }),
        throwsFormatException,
      );
      expect(
        AgentDevice.fromJson({'device_id': 'd'}).workspaceSupported,
        isFalse,
      );
      expect(
        AgentDevice.fromJson({
          'device_id': 'd',
          'workspace_supported': true,
        }).workspaceSupported,
        isTrue,
      );
    },
  );

  test(
    'download verifies input baseline, output digest, payload and ready state',
    () {
      final expected = AgentWorkspaceResult.fromJson(workspaceResult());
      expect(
        AgentWorkspaceDownload.verified(
          workspaceOutput(),
          expected,
        ).bundle.sha256,
        workspaceBundle().sha256,
      );
      for (final bad in [
        {...workspaceOutput(), 'input_sha256': '0' * 64},
        {...workspaceOutput(), 'output_sha256': '0' * 64},
        {
          ...workspaceOutput(),
          'bundle': _bundle([_file('tampered')]),
        },
      ]) {
        expect(
          () => AgentWorkspaceDownload.verified(bad, expected),
          throwsFormatException,
        );
      }
      expect(
        () => AgentWorkspaceDownload.verified(
          workspaceOutput(),
          AgentWorkspaceResult.fromJson(workspaceResult(state: 'pending')),
        ),
        throwsFormatException,
      );
    },
  );
}
