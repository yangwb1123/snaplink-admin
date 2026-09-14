import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/agent_compute_models.dart';

const _gib = 1024 * 1024 * 1024;
const _uuid = 'GPU-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';

Map<String, dynamic> _gpu() => {
  'uuid': _uuid,
  'name': 'NVIDIA RTX',
  'vendor': 'nvidia',
  'total_memory_bytes': 24 * _gib,
  'available_memory_bytes': 20 * _gib,
  'schedulable': true,
  'reserved': false,
  'observed_at': 1789238400.25,
};

Map<String, dynamic> _assignment() => {
  'vendor': 'nvidia',
  'mode': 'physical',
  'uuids': [_uuid],
  'gpu_memory_bytes': 16 * _gib,
  'assigned_at': 1789238410,
  'observed_at': 1789238400.25,
};

AgentComputeRequest _request(int count, int memory) => AgentComputeRequest(
  argv: const ['python', 'train.py'],
  workdir: '.',
  timeout: 3600,
  resources: AgentTaskResources(
    cpuCores: 1,
    memoryBytes: 0,
    gpuCount: count,
    gpuMemoryBytes: memory,
  ),
  requirements: const AgentTaskRequirements(runtimes: ['python']),
  targetDeviceId: '',
  turnId: '',
);

void main() {
  test('legacy CPU requests and responses retain their wire shape', () {
    expect(_request(0, 0).toJson()['resources'], {
      'cpu_cores': 1,
      'memory_bytes': 0,
    });
    final device = AgentDevice.fromJson({'device_id': 'cpu'});
    expect(device.gpuStatus, 'unavailable');
    expect(device.gpus, isEmpty);
    final task = AgentComputeTask.fromJson({
      'task_id': 'task',
      'session_id': 'session',
      'resources': {'cpu_cores': 1, 'memory_bytes': 0},
    });
    expect(task.resources.gpuCount, 0);
    expect(task.resources.gpuMemoryBytes, 0);
    expect(task.gpuAssignment, isNull);
  });

  test(
    'GPU request bounds and zero count consistency fail before submission',
    () {
      expect(_request(16, 1024 * _gib).toJson()['resources'], {
        'cpu_cores': 1,
        'memory_bytes': 0,
        'gpu_count': 16,
        'gpu_memory_bytes': 1024 * _gib,
      });
      expect(_request(1, 0).resources.toJson()['gpu_memory_bytes'], 0);
      for (final (count, memory) in [
        (-1, 0),
        (17, 0),
        (1, -1),
        (1, 1024 * _gib + 1),
        (0, 1),
      ]) {
        expect(() => _request(count, memory), throwsFormatException);
        expect(
          () => AgentTaskResources(
            cpuCores: 1,
            memoryBytes: 0,
            gpuCount: count,
            gpuMemoryBytes: memory,
          ).toJson(),
          throwsFormatException,
        );
      }
      expect(_request(1, 0).fingerprint, isNot(_request(0, 0).fingerprint));
      expect(_request(1, _gib).fingerprint, isNot(_request(1, 0).fingerprint));
    },
  );

  test(
    'inventory keeps reported memory, reservations, UUIDs and observation time',
    () {
      final device = AgentDevice.fromJson({
        'device_id': 'gpu',
        'gpu_status': 'busy',
        'gpus': [
          {..._gpu(), 'reserved': true, 'schedulable': false},
        ],
      });
      final gpu = device.gpus.single;
      expect(device.gpuStatus, 'busy');
      expect(gpu.uuid, _uuid);
      expect(gpu.vendor, 'nvidia');
      expect(gpu.totalMemoryBytes, 24 * _gib);
      expect(gpu.availableMemoryBytes, 20 * _gib);
      expect(gpu.reserved, isTrue);
      expect(gpu.schedulable, isFalse);
      expect(gpu.observedAt.millisecondsSinceEpoch, 1789238400250);
      expect(() => device.gpus.clear(), throwsUnsupportedError);
    },
  );

  test(
    'assignment records physical cards independently of the requested resources',
    () {
      final task = AgentComputeTask.fromJson({
        'task_id': 'task',
        'session_id': 'session',
        'resources': {'gpu_count': 1, 'gpu_memory_bytes': 16 * _gib},
        'gpu_assignment': _assignment(),
        'updated_at': 1789238410.25,
      });
      expect(task.updatedAt!.millisecondsSinceEpoch, 1789238410250);
      final assignment = task.gpuAssignment!;
      expect(assignment.mode, 'physical');
      expect(assignment.uuids, [_uuid]);
      expect(assignment.gpuMemoryBytes, 16 * _gib);
      expect(assignment.assignedAt.millisecondsSinceEpoch, 1789238410000);
      expect(assignment.observedAt.millisecondsSinceEpoch, 1789238400250);
      expect(() => assignment.uuids.clear(), throwsUnsupportedError);
    },
  );

  test(
    'only complete physical UUIDs are accepted and case variants deduplicate',
    () {
      final upper = _uuid.toUpperCase();
      expect(AgentGpu.fromJson({..._gpu(), 'uuid': upper}).uuid, upper);
      expect(
        AgentGpuAssignment.fromJson({
          ..._assignment(),
          'uuids': [upper],
        }).uuids,
        [upper],
      );
      for (final uuid in [
        'GPU-aaaaaaaa',
        'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee',
        _uuid.toLowerCase(),
        'MIG-$_uuid',
        ' $_uuid',
        '$_uuid ',
        '$_uuid\n',
        _uuid.replaceFirst('aaaa', 'gggg'),
        _uuid.replaceAll('-', ''),
        123,
      ]) {
        expect(
          () => AgentGpu.fromJson({..._gpu(), 'uuid': uuid}),
          throwsFormatException,
        );
        expect(
          () => AgentGpuAssignment.fromJson({
            ..._assignment(),
            'uuids': [uuid],
          }),
          throwsFormatException,
        );
      }
      expect(
        () => AgentGpu.parseList([
          _gpu(),
          {..._gpu(), 'uuid': upper},
        ]),
        throwsFormatException,
      );
      expect(
        () => AgentGpuAssignment.fromJson({
          ..._assignment(),
          'uuids': [_uuid, upper],
        }),
        throwsFormatException,
      );
    },
  );

  test('inventory and assignments accept at most sixteen unique cards', () {
    final uuids = List.generate(
      17,
      (index) =>
          'GPU-00000000-0000-0000-0000-${index.toRadixString(16).padLeft(12, '0')}',
    );
    final cards = [
      for (final uuid in uuids) {..._gpu(), 'uuid': uuid},
    ];
    expect(AgentGpu.parseList(cards.take(16).toList()), hasLength(16));
    expect(
      AgentGpuAssignment.fromJson({
        ..._assignment(),
        'uuids': uuids.take(16).toList(),
      }).uuids,
      hasLength(16),
    );
    expect(() => AgentGpu.parseList(cards), throwsFormatException);
    expect(
      () => AgentGpuAssignment.fromJson({..._assignment(), 'uuids': uuids}),
      throwsFormatException,
    );
    expect(AgentGpu.parseList(null), isEmpty);
    expect(AgentGpu.parseList([]), isEmpty);
  });

  test('inventory memory total is positive and bounded by one TiB', () {
    for (final total in [1, agentMaxGpuMemoryBytes]) {
      final gpu = AgentGpu.fromJson({
        ..._gpu(),
        'total_memory_bytes': total,
        'available_memory_bytes': total,
      });
      expect(gpu.totalMemoryBytes, total);
      expect(gpu.availableMemoryBytes, total);
    }
    for (final total in [0, -1, agentMaxGpuMemoryBytes + 1]) {
      expect(
        () => AgentGpu.fromJson({
          ..._gpu(),
          'total_memory_bytes': total,
          'available_memory_bytes': 0,
        }),
        throwsFormatException,
      );
    }
  });

  test(
    'GPU timestamps enforce positive bounds and original observation order',
    () {
      const maximum = 1000000000000;
      expect(
        AgentGpu.fromJson({
          ..._gpu(),
          'observed_at': maximum,
        }).observedAt.millisecondsSinceEpoch,
        maximum * 1000,
      );
      expect(
        AgentGpuAssignment.fromJson({
          ..._assignment(),
          'observed_at': maximum,
          'assigned_at': maximum,
        }).assignedAt.millisecondsSinceEpoch,
        maximum * 1000,
      );
      expect(
        AgentGpuAssignment.fromJson({
          ..._assignment(),
          'observed_at': 0.0001,
          'assigned_at': 0.0002,
        }).assignedAt.millisecondsSinceEpoch,
        0,
      );
      for (final value in [
        0,
        -1,
        maximum + 1,
        double.nan,
        double.infinity,
        '1',
        false,
      ]) {
        expect(
          () => AgentGpu.fromJson({..._gpu(), 'observed_at': value}),
          throwsFormatException,
        );
        for (final field in ['observed_at', 'assigned_at']) {
          expect(
            () => AgentGpuAssignment.fromJson({..._assignment(), field: value}),
            throwsFormatException,
          );
        }
      }
      for (final (observed, assigned) in [(2, 1), (1.0002, 1.0001)]) {
        expect(
          () => AgentGpuAssignment.fromJson({
            ..._assignment(),
            'observed_at': observed,
            'assigned_at': assigned,
          }),
          throwsFormatException,
        );
      }
    },
  );

  test(
    'malformed GPU observations and assignments cannot become usable resources',
    () {
      for (final value in [
        {..._gpu(), 'available_memory_bytes': 25 * _gib},
        {..._gpu(), 'available_memory_bytes': -1},
        {..._gpu(), 'total_memory_bytes': 24.5},
        {..._gpu(), 'observed_at': double.nan},
        {..._gpu(), 'observed_at': double.infinity},
        {..._gpu(), 'observed_at': -1},
        {..._gpu(), 'vendor': 'other'},
        {..._gpu(), 'uuid': ''},
        {..._gpu(), 'reserved': 'false'},
      ]) {
        expect(() => AgentGpu.fromJson(value), throwsFormatException);
      }
      expect(() => AgentGpu.parseList([_gpu(), _gpu()]), throwsFormatException);
      for (final value in [
        {..._assignment(), 'mode': 'mig'},
        {
          ..._assignment(),
          'uuids': [_uuid, _uuid],
        },
        {..._assignment(), 'uuids': []},
        {..._assignment(), 'gpu_memory_bytes': 1024 * _gib + 1},
        {..._assignment(), 'gpu_memory_bytes': '1'},
      ]) {
        expect(() => AgentGpuAssignment.fromJson(value), throwsFormatException);
      }
      for (final value in [
        {'gpu_count': 1.5},
        {'gpu_count': '1'},
        {'gpu_count': 0, 'gpu_memory_bytes': 1},
      ]) {
        expect(() => AgentTaskResources.fromJson(value), throwsFormatException);
      }
    },
  );
}
