import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';
import 'agent_session_close_fixture.dart';
import 'agent_session_creation_test.dart' show response;
import 'agent_session_history_test.dart' show operationData, operationPage;

class HistoryHub extends CloseHub {
  bool emptySessions = false;
  final creations = <http.Request>[];
  bool offline = false;
  int historyStatus = 200;
  bool detailCreated = false;
  bool failOlder = false;
  String sessionInstance = 'i-1';
  Completer<http.Response>? historyDelayed;
  Completer<http.Response>? openDelayed;
  Completer<http.Response>? detailDelayed;
  final reads = <http.Request>[];

  @override
  Future<http.Response> send(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/instances/i-1/sessions')) {
      creations.add(request);
      if (creations.length == 1) throw http.ClientException('unknown');
      return response({
        ...operationData()..remove('operation'),
        'name': (jsonDecode(request.body) as Map)['name'],
      }, status: 202);
    }
    if (path.endsWith('/session-operations')) {
      reads.add(request);
      if (historyDelayed != null) return historyDelayed!.future;
      if (historyStatus != 200) return http.Response('private', historyStatus);
      if (request.url.queryParameters['before'] == 'older') {
        if (failOlder) throw http.ClientException('private');
        return operationPage([
          operationData(operation: 'close', status: 'closed', id: 'r-old'),
        ]);
      }
      return operationPage([
        operationData(status: detailCreated ? 'created' : 'queued'),
      ], cursor: 'older');
    }
    if (path.endsWith('/session-requests/r-1')) {
      if (detailDelayed != null) return detailDelayed!.future;
      reads.add(request);
      detailCreated = true;
      return response(operationData(status: 'created')..remove('operation'));
    }
    if (path.endsWith('/sessions/s-1') && openDelayed != null) {
      return openDelayed!.future;
    }
    if (path.endsWith('/sessions/s-1')) {
      return response({...session('s-1'), 'instance_id': sessionInstance});
    }
    if (path.endsWith('/instances')) {
      return response([
        {
          'instance_id': 'i-1',
          'name': 'Ready host',
          'online': !offline,
          'session_close_supported': true,
          'session_capacity': 2,
        },
      ]);
    }
    if (path.endsWith('/sessions') && emptySessions) return response([]);
    return super.send(request);
  }
}

Future<void> mountHistory(
  WidgetTester tester,
  HistoryHub hub, {
  double width = 1280,
  Locale? locale,
}) async {
  tester.view.physicalSize = Size(width, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('zh')],
      home: AgentOperationsScreen(
        accessToken: 'old-agent-token',
        apiOrigin: 'https://hub.example',
        httpClient: MockClient(hub.send),
      ),
    ),
  );
  await pumpCloseRequests(tester);
  await tester.tap(find.byType(DropdownButtonFormField<String>).first);
  await tester.pumpAndSettle();
  await tester.tap(find.textContaining('Ready host').last);
  await tester.pumpAndSettle();
  await pumpCloseRequests(tester);
}

Future<void> openHistory(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('session-requests-entry')));
  await tester.pump();
  await pumpCloseRequests(tester);
  await tester.pump(const Duration(milliseconds: 250));
}

Future<void> selectHistory(WidgetTester tester, String identity) async {
  final finder = find.byKey(ValueKey('history-row-$identity'));
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pump();
}
