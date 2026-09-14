import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/screens/agent/agent_compute_resource_fields.dart';
import 'package:sso_admin/screens/agent/agent_compute_task_tile.dart';
import 'package:sso_admin/screens/agent/agent_device_directory.dart';
import 'package:sso_admin/screens/agent/agent_gpu_details.dart';

const _uuid = 'GPU-aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee';
const _gib = 1024 * 1024 * 1024;

Widget _app(Widget child, String language) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: child),
);

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

AgentDevice _device({String status = 'available', bool reserved = false}) =>
    AgentDevice.fromJson({
      'device_id': 'device-1',
      'name': 'CUDA worker',
      'online': true,
      'schedulable': true,
      'gpu_status': status,
      'gpus': [
        {
          'uuid': _uuid,
          'name': 'RTX 4090',
          'vendor': 'nvidia',
          'total_memory_bytes': 24 * _gib,
          'available_memory_bytes': 20 * _gib,
          'schedulable': !reserved,
          'reserved': reserved,
          'observed_at': 1789238400,
        },
      ],
    });

AgentComputeTask _task({bool assigned = true, int count = 1}) =>
    AgentComputeTask.fromJson({
      'task_id': 'task-1',
      'session_id': 'session',
      'state': 'running',
      'resources': {
        'gpu_count': count,
        'gpu_memory_bytes': count == 0 ? 0 : 16 * _gib,
      },
      if (assigned)
        'gpu_assignment': {
          'vendor': 'nvidia',
          'mode': 'physical',
          'uuids': [_uuid],
          'gpu_memory_bytes': 16 * _gib,
          'assigned_at': 1789238410,
          'observed_at': 1789238400,
        },
    });

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('GPU inventory wraps in 320px $language device directory', (
      tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        _app(
          AgentDeviceDirectory(
            devices: [_device(reserved: true, status: 'busy')],
            projectId: '',
            loading: false,
            hasMore: false,
            needsScope: false,
            error: null,
            onRefresh: () {},
            onLoadMore: () {},
            onSignIn: () {},
          ),
          language,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('NVIDIA · RTX 4090'), findsOneWidget);
      expect(find.textContaining('20.0 / 24.0 GiB'), findsOneWidget);
      expect(find.textContaining(_uuid), findsOneWidget);
      expect(
        find.textContaining(language == 'en' ? 'Reserved' : '已预留'),
        findsOneWidget,
      );
      expect(
        find.textContaining(language == 'en' ? 'Busy' : '忙碌'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('GPU form labels fit 320px in $language', (tester) async {
      _phone(tester);
      final controllers = List.generate(
        5,
        (_) => TextEditingController(text: '0'),
      );
      addTearDown(() {
        for (final controller in controllers) {
          controller.dispose();
        }
      });
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AgentComputeResourceFields(
              cpuController: controllers[0],
              memoryController: controllers[1],
              timeoutController: controllers[2],
              gpuCountController: controllers[3],
              gpuMemoryController: controllers[4],
              enabled: false,
            ),
          ),
          language,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(language == 'en' ? 'GPU count' : 'GPU 数量'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          language == 'en' ? 'does not set a memory limit' : '不是显存使用上限',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widgetList<TextField>(find.byType(TextField))
            .every((field) => field.enabled == false),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'task expands actual assigned GPU UUIDs at 320px in $language',
      (tester) async {
        _phone(tester);
        await tester.pumpWidget(
          _app(
            SingleChildScrollView(
              child: AgentComputeTaskTile(
                task: _task(),
                loadingDetails: false,
                cancelling: false,
                cancelScopeMissing: false,
                onCancel: () {},
                onExpansionChanged: (_) {},
                onSignIn: () {},
              ),
            ),
            language,
          ),
        );
        await tester.tap(find.byType(ExpansionTile));
        await tester.pumpAndSettle();
        expect(find.textContaining(_uuid), findsOneWidget);
        expect(find.textContaining('16384 MiB'), findsOneWidget);
        expect(
          find.textContaining(
            language == 'en'
                ? 'Assigned NVIDIA physical GPUs'
                : '已分配 NVIDIA 物理整卡',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'missing or stale GPU reports are explicit and CPU tasks stay compact',
    (tester) async {
      await tester.pumpWidget(
        _app(
          Column(
            children: [
              AgentDeviceGpuDetails(
                device: AgentDevice.fromJson({'device_id': 'legacy'}),
              ),
              AgentDeviceGpuDetails(device: _device(status: 'stale')),
              AgentDeviceGpuDetails(device: _device(status: 'unsupported')),
              AgentTaskGpuDetails(task: _task(assigned: false)),
              AgentTaskGpuDetails(task: _task(assigned: false, count: 0)),
            ],
          ),
          'en',
        ),
      );
      expect(
        find.text('GPU status: Unavailable or not reported'),
        findsOneWidget,
      );
      expect(find.text('GPU status: Stale GPU report'), findsOneWidget);
      expect(find.text('GPU status: Unsupported'), findsOneWidget);
      expect(
        find.text('GPU assignment has not been reported.'),
        findsOneWidget,
      );
      expect(find.text('Requested GPUs: 0'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
