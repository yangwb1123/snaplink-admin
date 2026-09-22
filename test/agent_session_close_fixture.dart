import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';
import 'package:sso_admin/screens/agent/agent_session_detail.dart';

import 'agent_session_creation_test.dart' show response;
import 'agent_session_close_test.dart' show closeData, closeError;

class CloseHub {
  bool supported = true;
  bool activeTurn = false;
  bool activeCompute = false;
  bool unknownFirst = false;
  bool denySecond = false;
  String status = 'queued';
  Completer<http.Response>? delayed;
  final posts = <http.Request>[];
  int polls = 0;
  bool get admitted => posts.isNotEmpty && !unknownFirst && delayed == null;

  Map<String, dynamic> session(String id) => {
    'session_id': id,
    'instance_id': 'i-1',
    'local_session_id': 'local-$id',
    'name': id == 's-1' ? 'First session' : 'Second session',
    'status': admitted && id == 's-1'
        ? (status == 'queued' ? 'closing' : status)
        : 'idle',
    'controllable': !(admitted && id == 's-1'),
    'frozen': admitted && id == 's-1',
    'active_turn_id': activeTurn ? 't-1' : '',
  };

  Future<http.Response> send(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/close')) {
      posts.add(request);
      if (delayed != null) return delayed!.future;
      if (unknownFirst && posts.length == 1) {
        throw http.ClientException('raw-private-error');
      }
      if (denySecond && posts.length == 2) {
        return closeError('insufficient_scope', status: 403);
      }
      return response(closeData(status: status), status: 202);
    }
    if (path.endsWith('/session-close-requests/r-1')) {
      polls++;
      return response(closeData(status: status));
    }
    if (path.endsWith('/instances')) {
      return response([
        {
          'instance_id': 'i-1',
          'name': 'Ready host',
          'online': true,
          'session_close_supported': supported,
          'session_capacity': 0,
        },
      ]);
    }
    if (path.endsWith('/sessions')) {
      return response([session('s-1'), session('s-2')]);
    }
    if (path.endsWith('/sessions/s-1')) return response(session('s-1'));
    if (path.endsWith('/sessions/s-2')) return response(session('s-2'));
    if (path.endsWith('/turns/t-1')) {
      return response({
        'turn_id': 't-1',
        'session_id': 's-1',
        'state': 'running',
      });
    }
    if (path.endsWith('/events')) {
      return response([
        {
          'cursor': 1,
          'event_id': 'e-1',
          'session_id': 's-1',
          'turn_id': '',
          'kind': 'message.completed',
          'payload': {'text': 'Preserved response'},
        },
      ]);
    }
    if (path.endsWith('/tasks')) {
      return response([
        if (activeCompute)
          {'task_id': 'compute-1', 'session_id': 's-1', 'state': 'running'},
      ]);
    }
    if (path.endsWith('/devices')) return response([]);
    throw StateError('Unexpected request: $path');
  }
}

Future<void> pumpCloseRequests(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> mountClose(
  WidgetTester tester,
  CloseHub hub, {
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
  await tester.tap(find.text('First session').first);
  await pumpCloseRequests(tester);
}

Future<void> confirmClose(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('close-session-action')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Confirm close'));
  await pumpCloseRequests(tester);
}

AgentSessionDetail closeDetail(WidgetTester tester) =>
    tester.widget<AgentSessionDetail>(find.byType(AgentSessionDetail));
