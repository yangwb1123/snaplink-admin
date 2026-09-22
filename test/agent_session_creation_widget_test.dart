import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:sso_admin/screens/agent/agent_operations_screen.dart';
import 'package:sso_admin/screens/agent/agent_session_detail.dart';
import 'package:sso_admin/session.dart';

import 'agent_session_creation_test.dart' show requestData, response;

class _Hub {
  Completer<http.Response>? delayedCreation;
  bool created = false;
  bool withExisting = false;
  bool unknownFirst = false;
  String? failureCode;
  int postCount = 0;
  int pollCount = 0;
  final keys = <String?>[];
  final names = <String>[];

  Map<String, dynamic> session(String id) => {
    'session_id': id,
    'instance_id': 'i-1',
    'local_session_id': 'local-$id',
    'name': id == 's-1' ? '分析任务' : 'Existing work',
    'controllable': true,
    'status': 'idle',
  };

  Future<http.Response> send(http.Request request) async {
    final path = request.url.path;
    if (request.method == 'POST' && path.endsWith('/instances/i-1/sessions')) {
      postCount++;
      keys.add(request.headers['idempotency-key']);
      names.add((jsonDecode(request.body) as Map)['name'] as String);
      if (delayedCreation != null) return delayedCreation!.future;
      if (unknownFirst && postCount == 1) {
        throw http.ClientException('raw-private-token');
      }
      if (failureCode != null) {
        return http.Response(
          jsonEncode({
            'error': {'code': failureCode, 'message': 'raw-private-token'},
          }),
          409,
        );
      }
      return response(requestData(), status: 202);
    }
    if (path.endsWith('/session-requests/r-1')) {
      pollCount++;
      return response(requestData(status: created ? 'created' : 'queued'));
    }
    if (path.endsWith('/instances')) {
      return response([
        {
          'instance_id': 'i-1',
          'name': 'Ready host',
          'online': true,
          'session_capacity': 8,
        },
        {'instance_id': 'legacy', 'name': 'Legacy host', 'online': true},
        {
          'instance_id': 'offline',
          'name': 'Offline host',
          'online': false,
          'session_capacity': 8,
        },
      ]);
    }
    if (path.endsWith('/sessions')) {
      return response([
        if (withExisting) session('existing'),
        if (created) session('s-1'),
      ]);
    }
    if (path.endsWith('/sessions/s-1')) return response(session('s-1'));
    if (path.endsWith('/sessions/existing')) {
      return response(session('existing'));
    }
    if (path.endsWith('/events') ||
        path.endsWith('/devices') ||
        path.endsWith('/tasks')) {
      return response([]);
    }
    throw StateError('Unexpected request');
  }
}

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Hub hub, {
  double width = 1280,
  Locale? locale,
}) async {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      supportedLocales: const [Locale('en'), Locale('zh')],
      home: AgentOperationsScreen(
        accessToken: 'raw-private-token',
        apiOrigin: 'https://hub.example',
        httpClient: MockClient(hub.send),
      ),
    ),
  );
  await _pumpRequests(tester);
}

Future<void> _start(WidgetTester tester) async {
  await tester.tap(find.text('New session'));
  await tester.pumpAndSettle();
  final create = tester.widget<FilledButton>(
    find.widgetWithText(FilledButton, 'Create session'),
  );
  expect(create.onPressed, isNull);
  await tester.tap(find.byKey(const ValueKey('new-session-instance')));
  await tester.pumpAndSettle();
  expect(find.text('Legacy host'), findsNothing);
  expect(find.text('Offline host'), findsNothing);
  await tester.tap(find.text('Ready host').last);
  await tester.pumpAndSettle();
  await tester.enterText(
    find.byKey(const ValueKey('new-session-name')),
    '分析任务',
  );
  await tester.tap(find.text('Create session'));
  await _pumpRequests(tester);
}

void main() {
  testWidgets(
    'empty directory can create and closed dialog keeps GET tracking',
    (tester) async {
      final hub = _Hub();
      await _mount(tester, hub);
      expect(find.text('New session'), findsOneWidget);
      await _start(tester);
      expect(hub.postCount, 1);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Session creation status'), findsOneWidget);
      hub.created = true;
      await tester.pump(const Duration(seconds: 2));
      await _pumpRequests(tester);
      expect(hub.pollCount, 1);
      expect(hub.postCount, 1);
      expect(
        tester
            .widget<AgentSessionDetail>(find.byType(AgentSessionDetail))
            .session
            .sessionId,
        's-1',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('completion after selecting another session preserves focus', (
    tester,
  ) async {
    final hub = _Hub()..withExisting = true;
    await _mount(tester, hub);
    await _start(tester);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Existing work').first);
    await _pumpRequests(tester);
    hub.created = true;
    await tester.pump(const Duration(seconds: 2));
    await _pumpRequests(tester);
    expect(
      tester
          .widget<AgentSessionDetail>(find.byType(AgentSessionDetail))
          .session
          .sessionId,
      'existing',
    );
    await tester.tap(find.text('Session creation status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open session'));
    await _pumpRequests(tester);
    expect(
      tester
          .widget<AgentSessionDetail>(find.byType(AgentSessionDetail))
          .session
          .sessionId,
      's-1',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'unknown submission survives closing and retries its original key',
    (tester) async {
      final hub = _Hub()..unknownFirst = true;
      await _mount(tester, hub);
      await _start(tester);
      expect(find.textContaining('raw-private-token'), findsNothing);
      expect(find.text('Retry same request'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      expect(hub.postCount, 1);
      await tester.tap(find.text('Session creation status'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('new-session-name')), findsNothing);
      await tester.tap(find.text('Retry same request'));
      await _pumpRequests(tester);
      expect(hub.keys[0], hub.keys[1]);
      expect(hub.names, ['分析任务', '分析任务']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('capacity refusal allows editing and never exposes raw errors', (
    tester,
  ) async {
    final hub = _Hub()..failureCode = 'session_capacity';
    await _mount(tester, hub);
    await _start(tester);
    expect(
      find.text('This instance has reached its session capacity.'),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('new-session-name')), findsOneWidget);
    expect(find.textContaining('raw-private-token'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  for (final leaveScreen in [true, false]) {
    testWidgets(
      'late creation 401 preserves newer identity (leave=$leaveScreen)',
      (tester) async {
        Session.store('raw-private-token');
        addTearDown(Session.clear);
        final delayed = Completer<http.Response>();
        final hub = _Hub()..delayedCreation = delayed;
        await _mount(tester, hub);
        await _start(tester);
        if (leaveScreen) {
          await tester.pumpWidget(const SizedBox());
        }
        Session.store('new-identity-token');
        Session.storeForClient('other-client', 'new-scoped-token');
        delayed.complete(
          http.Response(
            jsonEncode({
              'error': {'code': 'unauthorized', 'message': 'private-old-token'},
            }),
            401,
          ),
        );
        await _pumpRequests(tester);
        expect(Session.read(), 'new-identity-token');
        expect(Session.readForClient('other-client'), 'new-scoped-token');
        expect(find.textContaining('private-old-token'), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final locale in [const Locale('en'), const Locale('zh')]) {
    testWidgets('narrow dialog has no overflow in $locale', (tester) async {
      final hub = _Hub();
      await _mount(tester, hub, width: 320, locale: locale);
      await tester.tap(
        find.text(locale.languageCode == 'zh' ? '新建会话' : 'New session'),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
