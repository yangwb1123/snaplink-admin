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
import 'package:sso_admin/services/browser_download_stub.dart'
    as native_download;

import 'fixtures/agent_workspace_fixture.dart';

http.Response _json(Object value, [int status = 200]) => http.Response(
  jsonEncode(value),
  status,
  headers: {'content-type': 'application/json'},
);
AgentHubApi _api(Future<http.Response> Function(http.Request) handle) =>
    AgentHubApi(
      baseUrl: 'https://hub.example',
      accessToken: 'token',
      httpClient: MockClient(handle),
    );
Widget _app(Widget child, [String language = 'en']) => MaterialApp(
  locale: Locale(language),
  supportedLocales: const [Locale('en'), Locale('zh')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await _settle(tester);
}

void main() {
  for (final language in ['en', 'zh']) {
    testWidgets('snapshot upload and output form wraps at 320px $language', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var value = const AgentWorkspaceSelection();
      var calls = 0;
      final api = _api((request) async {
        calls++;
        if (request.method == 'GET') return _json({'data': []});
        return _json({'data': workspaceSnapshot()});
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
              value: value,
              disabled: false,
              onSignIn: () {},
              onChanged: (next) => setState(() => value = next),
            ),
          ),
          language,
        ),
      );
      expect(calls, 0);
      await _tap(tester, find.byType(SwitchListTile));
      await tester.enterText(
        find.byType(TextField).first,
        workspaceBundle().canonicalJson,
      );
      await _tap(
        tester,
        find.text(language == 'en' ? 'Upload snapshot' : '上传快照'),
      );
      expect(value.snapshot?.snapshotId, 'snap-1');
      await tester.enterText(
        find.byType(TextField).last,
        'report.json\nresults/data.txt',
      );
      await tester.pumpAndSettle();
      expect(value.toRequest()?.outputs, ['report.json', 'results/data.txt']);
      expect(find.textContaining(workspaceBundle().sha256), findsOneWidget);
      expect(find.text('Choose JSON file'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'unconfirmed uploads reuse one key for the same canonical bundle',
    (tester) async {
      var value = const AgentWorkspaceSelection(enabled: true);
      final writes = <http.Request>[];
      final api = _api((request) async {
        writes.add(request);
        if (writes.length == 1) {
          throw http.ClientException('lost acknowledgement');
        }
        return _json({'data': workspaceSnapshot()});
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
              value: value,
              disabled: false,
              onSignIn: () {},
              onChanged: (next) => setState(() => value = next),
            ),
          ),
        ),
      );
      await tester.enterText(
        find.byType(TextField).first,
        workspaceBundle().canonicalJson,
      );
      await _tap(tester, find.text('Upload snapshot'));
      expect(value.snapshot, isNull);
      await _tap(tester, find.text('Upload snapshot'));
      expect(writes, hasLength(2));
      expect(
        writes[0].headers['idempotency-key'],
        writes[1].headers['idempotency-key'],
      );
      expect(writes[0].body, writes[1].body);
      expect(value.snapshot?.snapshotId, 'snap-1');
    },
  );

  testWidgets('late upload cannot select a snapshot in a changed session', (
    tester,
  ) async {
    var session = 's-1';
    var value = const AgentWorkspaceSelection(enabled: true);
    late StateSetter rebuild;
    final delayed = Completer<http.Response>();
    final api = _api((_) => delayed.future);
    addTearDown(api.close);
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
              value: value,
              disabled: false,
              onSignIn: () {},
              onChanged: (next) => setState(() => value = next),
            );
          },
        ),
      ),
    );
    await tester.enterText(
      find.byType(TextField).first,
      workspaceBundle().canonicalJson,
    );
    await tester.ensureVisible(find.text('Upload snapshot'));
    await tester.tap(find.text('Upload snapshot'));
    await tester.pump();
    rebuild(() {
      session = 's-2';
      value = const AgentWorkspaceSelection();
    });
    await tester.pump();
    delayed.complete(_json({'data': workspaceSnapshot()}));
    await _settle(tester);
    expect(value.snapshot, isNull);
    expect(value.enabled, isFalse);
    expect(find.textContaining('snap-1'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late snapshot list cannot populate a changed session', (
    tester,
  ) async {
    var session = 's-1';
    var value = const AgentWorkspaceSelection();
    late StateSetter rebuild;
    final delayed = Completer<http.Response>();
    final api = _api(
      (request) => request.url.path.contains('s-1')
          ? delayed.future
          : Future.value(
              _json({
                'data': [workspaceSnapshot(session: 's-2', id: 'snap-2')],
              }),
            ),
    );
    addTearDown(api.close);
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
              value: value,
              disabled: false,
              onSignIn: () {},
              onChanged: (next) => setState(() => value = next),
            );
          },
        ),
      ),
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    rebuild(() {
      session = 's-2';
      value = const AgentWorkspaceSelection();
    });
    await tester.pump();
    await _tap(tester, find.byType(SwitchListTile));
    delayed.complete(
      _json({
        'data': [workspaceSnapshot()],
      }),
    );
    await _settle(tester);
    await _tap(tester, find.byType(DropdownButtonFormField<String>));
    expect(find.text('snap-2 · 2'), findsWidgets);
    expect(find.text('snap-1 · 2'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'native verified output offers explicit JSON copy without a fake save',
    (tester) async {
      String? copied;
      native_download.resetForTest();
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final api = _api((_) async => _json({'data': workspaceOutput()}));
      addTearDown(api.close);
      final task = AgentComputeTask.fromJson({
        'task_id': 't',
        'session_id': 's-1',
        'workspace_result': workspaceResult(),
      });
      await tester.pumpWidget(
        _app(AgentWorkspaceTaskDetails(api: api, task: task, onSignIn: () {})),
      );
      await _tap(tester, find.text('View workspace JSON'));
      expect(find.text('Verified workspace JSON'), findsOneWidget);
      expect(copied, isNull);
      await _tap(tester, find.text('Copy workspace JSON'));
      expect(copied, workspaceBundle().canonicalJson);
      expect(native_download.capturedDownloads, isEmpty);
    },
  );

  testWidgets('changed task result discards a late successful download', (
    tester,
  ) async {
    var task = AgentComputeTask.fromJson({
      'task_id': 't',
      'session_id': 's',
      'workspace_result': workspaceResult(),
    });
    late StateSetter rebuild;
    final delayed = Completer<http.Response>();
    final api = _api((_) => delayed.future);
    addTearDown(api.close);
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
    await tester.tap(find.text('View workspace JSON'));
    await tester.pump();
    rebuild(
      () => task = AgentComputeTask.fromJson({
        'task_id': 't',
        'session_id': 's',
        'workspace_result': workspaceResult(state: 'failed'),
      }),
    );
    await tester.pump();
    delayed.complete(_json({'data': workspaceOutput()}));
    await _settle(tester);
    expect(find.text('Verified workspace JSON'), findsNothing);
    expect(find.text('Workspace artifact: failed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('checksum failure never exposes unverified JSON', (tester) async {
    final api = _api(
      (_) async => _json({
        'data': {...workspaceOutput(), 'input_sha256': '0' * 64},
      }),
    );
    addTearDown(api.close);
    final task = AgentComputeTask.fromJson({
      'task_id': 't',
      'session_id': 's',
      'workspace_result': workspaceResult(),
    });
    await tester.pumpWidget(
      _app(AgentWorkspaceTaskDetails(api: api, task: task, onSignIn: () {})),
    );
    await _tap(tester, find.text('View workspace JSON'));
    expect(
      find.text('Workspace checksum verification failed.'),
      findsOneWidget,
    );
    expect(find.text('Verified workspace JSON'), findsNothing);
  });
}
