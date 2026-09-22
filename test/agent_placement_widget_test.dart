import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/agent/agent_compute_placement.dart';
import 'package:sso_admin/screens/agent/agent_operations_view.dart';
import 'package:sso_admin/api/agent_hub_models.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/screens/agent/agent_compute_placement_dialog.dart';
import 'package:sso_admin/screens/agent/agent_compute_tasks_panel.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';
import 'agent_placement_test.dart'
    show placementApi, placementData, placementDevice, placementResponse;

Future<void> _requests(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Widget _app(Widget home, {Locale? locale}) => MaterialApp(
  locale: locale,
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('en'), Locale('zh')],
  home: home,
);

void main() {
  setUp(Session.clear);
  tearDown(Session.clear);
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    testWidgets(
      'narrow dialog paging and reason translations ${locale.languageCode}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final reads = <http.Request>[];
        final api = placementApi((request) async {
          reads.add(request);
          final next = request.url.queryParameters['after'] != null;
          return placementResponse(
            placementData(
              cursor: next ? '' : 'device-a',
              devices: [
                {
                  ...placementDevice(next ? 'device-b' : 'device-a'),
                  'eligible': false,
                  'reasons': ['gpu_insufficient', 'runtime_missing'],
                },
              ],
            ),
          );
        });
        final model = AgentComputePlacement(
          api: api,
          taskId: 'task-1',
          isCurrent: () => true,
        );
        addTearDown(api.close);
        addTearDown(model.dispose);
        await tester.pumpWidget(
          _app(
            Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  child: const Text('Show'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) =>
                        AgentComputePlacementDialog(placement: model),
                  ),
                ),
              ),
            ),
            locale: locale,
          ),
        );
        unawaited(model.load());
        await tester.tap(find.text('Show'));
        await _requests(tester);
        await tester.pumpAndSettle();
        expect(
          find.text(locale.languageCode == 'zh' ? '任务调度诊断' : 'Task placement'),
          findsOneWidget,
        );
        final row = find.byKey(const ValueKey('placement-device-device-a'));
        await tester.scrollUntilVisible(
          row,
          150,
          scrollable: find
              .descendant(
                of: find.byType(AgentComputePlacementDialog),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.ensureVisible(row);
        await tester.pumpAndSettle();
        expect(
          find.text(
            locale.languageCode == 'zh'
                ? '符合条件的 GPU 容量不足'
                : 'Insufficient eligible GPU capacity',
          ),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('placement-next')));
        await _requests(tester);
        expect(reads, hasLength(2));
        expect(
          find.byKey(const ValueKey('placement-device-device-a')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('placement-device-device-b')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('placement-refresh')));
        await _requests(tester);
        expect(reads.last.url.queryParameters.containsKey('after'), isFalse);
        await tester.pumpWidget(const SizedBox.shrink());
        await _requests(tester);
      },
    );
  }
  for (final locale in [const Locale('en'), const Locale('zh')]) {
    testWidgets(
      'large valid timestamp renders localized fallback ${locale.languageCode}',
      (tester) async {
        final api = placementApi(
          (_) async => placementResponse({
            ...placementData(devices: []),
            'evaluated_at': 1e100,
          }),
        );
        final model = AgentComputePlacement(
          api: api,
          taskId: 'task-1',
          isCurrent: () => true,
        );
        addTearDown(api.close);
        addTearDown(model.dispose);
        await tester.pumpWidget(
          _app(AgentComputePlacementDialog(placement: model), locale: locale),
        );
        unawaited(model.load());
        await _requests(tester);
        expect(model.page!.evaluatedAt, 1e100);
        expect(
          find.text(
            locale.languageCode == 'zh'
                ? '观察时间超出可显示范围。'
                : 'Observation time is outside the displayable range.',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _requests(tester);
      },
    );
  }
  for (final state in ['queued', 'running']) {
    testWidgets('empty $state observation explains its scope', (tester) async {
      final api = placementApi(
        (_) async =>
            placementResponse(placementData(state: state, devices: [])),
      );
      final model = AgentComputePlacement(
        api: api,
        taskId: 'task-1',
        isCurrent: () => true,
      );
      addTearDown(api.close);
      addTearDown(model.dispose);
      await tester.pumpWidget(
        _app(AgentComputePlacementDialog(placement: model)),
      );
      unawaited(model.load());
      await _requests(tester);
      expect(
        find.text(
          state == 'queued'
              ? 'No visible original device bindings are available to inspect.'
              : 'Placement diagnostics apply only while the task is queued.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('placement-next')),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await _requests(tester);
    });
  }
  for (final scenario in [
    'dismiss',
    'identity',
    'selection',
    'before_identity',
    'before_logout',
  ]) {
    testWidgets(
      'task detail entry remains read only and fences dismissed/changed context $scenario',
      (tester) async {
        tester.view.physicalSize = const Size(1280, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const session = {
          'session_id': 's-1',
          'instance_id': 'i-1',
          'name': 'Session one',
          'project_id': 'p',
          'controllable': false,
          'status': 'offline',
        };
        const task = {
          'task_id': 'task-1',
          'session_id': 's-1',
          'instance_id': 'i-1',
          'state': 'queued',
        };
        final requests = <http.Request>[];
        final pending = Completer<http.Response>();
        final client = MockClient((request) async {
          requests.add(request);
          final path = request.url.path;
          if (path.endsWith('/placement')) return pending.future;
          if (path.endsWith('/instances') || path.endsWith('/devices')) {
            return placementResponse([]);
          }
          if (path.endsWith('/sessions')) {
            return placementResponse([session]);
          }
          if (path.endsWith('/sessions/s-1')) return placementResponse(session);
          if (path.endsWith('/events')) {
            return http.Response(
              jsonEncode({'data': [], 'next_cursor': 0}),
              200,
            );
          }
          if (path.endsWith('/tasks')) return placementResponse([task]);
          if (path.endsWith('/tasks/task-1')) return placementResponse(task);
          throw StateError('Unexpected $path');
        });
        Widget screen(String token) => _app(
          AgentOperationsScreen(
            key: const ValueKey('screen'),
            accessToken: token,
            apiOrigin: 'https://hub.example',
            httpClient: client,
          ),
        );
        final changedBeforeOpen = scenario.startsWith('before_');
        if (changedBeforeOpen) Session.store('old');
        await tester.pumpWidget(screen('old'));
        await _requests(tester);
        await tester.tap(find.text('Session one').first);
        await _requests(tester);
        await tester.tap(find.text('Compute tasks').first);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.textContaining('Task task-1'),
          300,
          scrollable: find
              .descendant(
                of: find.byType(AgentComputeTasksPanel),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        await tester.tap(find.textContaining('Task task-1'));
        await _requests(tester);
        await tester.pumpAndSettle();
        final entry = find.byKey(const ValueKey('placement-entry-task-1'));
        await tester.ensureVisible(entry);
        await tester.pumpAndSettle();
        if (scenario == 'before_identity') Session.store('new');
        if (scenario == 'before_logout') Session.clear();
        await tester.tap(entry);
        await _requests(tester);
        await tester.pump(const Duration(milliseconds: 250));
        expect(
          requests.where((r) => r.url.path.endsWith('/placement')),
          hasLength(changedBeforeOpen ? 0 : 1),
        );
        if (scenario == 'identity') {
          await tester.pumpWidget(screen('new'));
          await tester.pump();
        } else if (scenario == 'selection') {
          tester
              .widget<AgentOperationsView>(find.byType(AgentOperationsView))
              .onSelectSession(AgentSession.fromJson({...session}));
          await tester.pump();
          await _requests(tester);
        } else if (scenario == 'dismiss') {
          await tester.tap(find.text('Dismiss'));
          await tester.pumpAndSettle();
        }
        pending.complete(placementResponse(placementData()));
        await _requests(tester);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('placement-device-device-a')),
          findsNothing,
        );
        if (scenario != 'dismiss') {
          expect(
            find.text(
              'Your sign-in or selected session changed. Reopen task placement.',
            ),
            findsOneWidget,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.byKey(const ValueKey('placement-refresh')),
                )
                .onPressed,
            isNull,
          );
        }
        expect(requests.every((request) => request.method == 'GET'), isTrue);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await _requests(tester);
      },
    );
  }
}
