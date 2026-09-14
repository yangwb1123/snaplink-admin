@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/agent_compute_models.dart';
import 'package:sso_admin/api/agent_hub_api.dart';
import 'package:sso_admin/screens/agent/agent_workspace_form.dart';
import 'package:sso_admin/screens/agent/agent_workspace_selection.dart';
import 'package:sso_admin/screens/agent/agent_workspace_task_details.dart';

import 'fixtures/agent_workspace_fixture.dart';

const _channel = MethodChannel('site.ywbsd.sso/agent_workspace_files');
const _support = {'version': 1, 'pick': true, 'save': true};

Widget _app(Widget child, [String language = 'en']) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

AgentHubApi _api(Future<http.Response> Function(http.Request) handler) =>
    AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      httpClient: MockClient(handler),
    );

http.Response _json(Object data) => http.Response(
  jsonEncode({'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);

AgentComputeTask _task([String id = 't-1']) => AgentComputeTask.fromJson({
  'task_id': id,
  'session_id': 's-1',
  'workspace_result': workspaceResult(),
});

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  void host(Future<Object?> Function(MethodCall)? handle) =>
      binding.defaultBinaryMessenger.setMockMethodCallHandler(_channel, handle);
  tearDown(() => host(null));

  for (final language in ['en', 'zh']) {
    testWidgets(
      'native file selection fills canonical JSON at 320px $language',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        host(
          (call) async => call.method == 'capabilities'
              ? _support
              : Uint8List.fromList(
                  utf8.encode(workspaceBundle().canonicalJson),
                ),
        );
        var selection = const AgentWorkspaceSelection(enabled: true);
        var uploads = 0;
        final api = _api((_) async {
          uploads++;
          return _json(workspaceSnapshot());
        });
        addTearDown(api.close);
        await tester.pumpWidget(
          _app(
            StatefulBuilder(
              builder: (context, setState) => AgentWorkspaceForm(
                api: api,
                sessionId: 's-1',
                instanceId: 'i-1',
                projectId: 'project-1',
                value: selection,
                disabled: false,
                onSignIn: () {},
                onChanged: (value) => setState(() => selection = value),
              ),
            ),
            language,
          ),
        );
        await _settle(tester);
        final choose = find.text(
          language == 'en' ? 'Choose JSON file' : '选择 JSON 文件',
        );
        await tester.ensureVisible(choose);
        await tester.tap(choose);
        await _settle(tester);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .controller!
              .text,
          workspaceBundle().canonicalJson,
        );
        expect(uploads, 0);
        final upload = find.text(language == 'en' ? 'Upload snapshot' : '上传快照');
        await tester.tap(upload);
        await _settle(tester);
        expect(uploads, 1);
        expect(selection.snapshot?.snapshotId, 'snap-1');
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('late picker result cannot populate another session', (
    tester,
  ) async {
    final pending = Completer<Object?>();
    host(
      (call) => call.method == 'capabilities'
          ? Future.value(_support)
          : pending.future,
    );
    final api = _api((_) async => _json([]));
    addTearDown(api.close);
    var session = 's-1';
    late StateSetter rebuild;
    await tester.pumpWidget(
      _app(
        StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return AgentWorkspaceForm(
              api: api,
              sessionId: session,
              instanceId: 'i-1',
              projectId: 'project-1',
              value: const AgentWorkspaceSelection(enabled: true),
              disabled: false,
              onSignIn: () {},
              onChanged: (_) {},
            );
          },
        ),
      ),
    );
    await _settle(tester);
    await tester.ensureVisible(find.text('Choose JSON file'));
    await tester.tap(find.text('Choose JSON file'));
    await tester.pump();
    rebuild(() => session = 's-2');
    await tester.pump();
    pending.complete(
      Uint8List.fromList(utf8.encode(workspaceBundle().canonicalJson)),
    );
    await _settle(tester);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      isEmpty,
    );
    expect(tester.takeException(), isNull);
  });

  for (final saved in [true, false]) {
    testWidgets(
      'native save reports host result $saved after checksum verification',
      (tester) async {
        var saveCalls = 0;
        host((call) async {
          if (call.method == 'capabilities') return _support;
          saveCalls++;
          expect(call.method, 'saveJson');
          expect(
            (call.arguments as Map)['bytes'],
            utf8.encode(workspaceBundle().canonicalJson),
          );
          expect((call.arguments as Map)['filename'], 'workspace-t-1.json');
          return saved;
        });
        final api = _api((_) async => _json(workspaceOutput()));
        addTearDown(api.close);
        await tester.pumpWidget(
          _app(
            AgentWorkspaceTaskDetails(api: api, task: _task(), onSignIn: () {}),
          ),
        );
        await _settle(tester);
        expect(find.text('View workspace JSON'), findsOneWidget);
        await tester.tap(find.text('Save workspace JSON'));
        await _settle(tester);
        expect(saveCalls, 1);
        expect(
          find.text(saved ? 'Workspace JSON saved.' : 'File save cancelled.'),
          findsOneWidget,
        );
        expect(find.text('Verified workspace JSON'), findsNothing);
      },
    );
  }

  testWidgets('checksum failure never opens native save dialog', (
    tester,
  ) async {
    var saveCalls = 0;
    host((call) async {
      if (call.method == 'capabilities') return _support;
      saveCalls++;
      return true;
    });
    final api = _api(
      (_) async => _json({...workspaceOutput(), 'output_sha256': '0' * 64}),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      _app(AgentWorkspaceTaskDetails(api: api, task: _task(), onSignIn: () {})),
    );
    await _settle(tester);
    await tester.tap(find.text('Save workspace JSON'));
    await _settle(tester);
    expect(saveCalls, 0);
    expect(
      find.text('Workspace checksum verification failed.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'late save acknowledgement cannot report success on a changed task',
    (tester) async {
      final pending = Completer<Object?>();
      host(
        (call) => call.method == 'capabilities'
            ? Future.value(_support)
            : pending.future,
      );
      final api = _api((_) async => _json(workspaceOutput()));
      addTearDown(api.close);
      var task = _task();
      late StateSetter rebuild;
      await tester.pumpWidget(
        _app(
          StatefulBuilder(
            builder: (context, setState) {
              rebuild = setState;
              return AgentWorkspaceTaskDetails(
                api: api,
                task: task,
                onSignIn: () {},
              );
            },
          ),
        ),
      );
      await _settle(tester);
      await tester.tap(find.text('Save workspace JSON'));
      for (var i = 0; i < 3; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      rebuild(() => task = _task('t-2'));
      await tester.pump();
      pending.complete(true);
      await _settle(tester);
      expect(find.text('Workspace JSON saved.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
