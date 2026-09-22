import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/session.dart';
import 'package:sso_admin/screens/agent/agent_session_detail.dart';
import 'agent_session_close_fixture.dart'
    show pumpCloseRequests, closeDetail, confirmClose;
import 'agent_session_creation_test.dart' show response;
import 'agent_session_history_fixture.dart';
import 'agent_session_history_test.dart' show operationPage;

void main() {
  testWidgets(
    'offline empty instance has requests, explicit paging and detail refresh',
    (tester) async {
      final hub = HistoryHub()
        ..emptySessions = true
        ..offline = true;
      await mountHistory(tester, hub);
      await openHistory(tester);
      expect(find.textContaining('Remote session'), findsOneWidget);
      expect(find.textContaining('Request queued'), findsOneWidget);
      expect(find.text('Request details'), findsNothing);
      expect(hub.reads.length, 1);
      await selectHistory(tester, 'create:r-1');
      expect(find.byKey(const ValueKey('history-open')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('history-refresh-detail')));
      await pumpCloseRequests(tester);
      expect(find.textContaining('Session created.'), findsNWidgets(2));
      expect(find.byKey(const ValueKey('history-open')), findsOneWidget);
      expect(hub.posts, isEmpty);
      await tester.tap(find.byKey(const ValueKey('history-older')));
      await pumpCloseRequests(tester);
      expect(find.textContaining('Remote session'), findsNothing);
      expect(
        find.byKey(const ValueKey('history-row-close:r-old')),
        findsOneWidget,
      );
      expect(hub.reads.last.url.queryParameters['before'], 'older');
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('history-older')))
            .onPressed,
        isNull,
      );
      await tester.tap(find.byKey(const ValueKey('history-latest')));
      await pumpCloseRequests(tester);
      expect(hub.reads.last.url.queryParameters.containsKey('before'), false);
      expect(hub.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'older-page failure retries same cursor; empty latest is understandable',
    (tester) async {
      final hub = HistoryHub()..failOlder = true;
      await mountHistory(tester, hub);
      await openHistory(tester);
      await tester.tap(find.byKey(const ValueKey('history-older')));
      await pumpCloseRequests(tester);
      expect(find.textContaining('private'), findsNothing);
      hub.failOlder = false;
      await tester.tap(find.text('Retry'));
      await pumpCloseRequests(tester);
      expect(hub.reads.last.url.queryParameters['before'], 'older');
      hub.historyDelayed = Completer<http.Response>()
        ..complete(operationPage([]));
      await tester.tap(find.byKey(const ValueKey('history-latest')));
      await pumpCloseRequests(tester);
      expect(
        find.text('No accepted session requests for this instance.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'opens only explicit matching session, never auto opens created record',
    (tester) async {
      final hub = HistoryHub()..detailCreated = true;
      await mountHistory(tester, hub);
      await openHistory(tester);
      expect(find.byType(AgentSessionDetail), findsNothing);
      await selectHistory(tester, 'create:r-1');
      await tester.tap(find.byKey(const ValueKey('history-open')));
      await pumpCloseRequests(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(closeDetail(tester).session.sessionId, 's-1');
      expect(hub.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('wrong session instance is rejected without navigation', (
    tester,
  ) async {
    final hub = HistoryHub()
      ..detailCreated = true
      ..sessionInstance = 'other';
    await mountHistory(tester, hub);
    await openHistory(tester);
    await selectHistory(tester, 'create:r-1');
    await tester.tap(find.byKey(const ValueKey('history-open')));
    await pumpCloseRequests(tester);
    expect(
      find.text('Agent Hub returned an invalid response.'),
      findsOneWidget,
    );
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  for (final method in ['dismiss', 'back', 'credentials']) {
    testWidgets('late open after $method cannot select a session', (
      tester,
    ) async {
      Session.store('old-agent-token');
      addTearDown(Session.clear);
      final delayed = Completer<http.Response>();
      final hub = HistoryHub()..detailCreated = true;
      await mountHistory(tester, hub);
      await openHistory(tester);
      await selectHistory(tester, 'create:r-1');
      hub.openDelayed = delayed;
      await tester.tap(find.byKey(const ValueKey('history-open')));
      await tester.pump();
      if (method == 'credentials') {
        Session.store('new-token');
      } else if (method == 'back') {
        Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      } else {
        await tester.tap(find.text('Dismiss'));
      }
      if (method == 'dismiss') {
        await tester.pumpAndSettle();
        await tester.tap(find.text('Second session').first);
        await pumpCloseRequests(tester);
      }
      delayed.complete(response(hub.session('s-1')));
      await pumpCloseRequests(tester);
      await tester.pumpAndSettle();
      await pumpCloseRequests(tester);
      if (method == 'dismiss') {
        expect(closeDetail(tester).session.sessionId, 's-2');
      } else {
        expect(find.byType(AgentSessionDetail), findsNothing);
      }
      if (method == 'credentials') expect(Session.read(), 'new-token');
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final status in [404, 405, 501, 403]) {
    testWidgets('history HTTP $status is clear and sends no POST', (
      tester,
    ) async {
      final hub = HistoryHub()..historyStatus = status;
      await mountHistory(tester, hub);
      await openHistory(tester);
      expect(
        find.text(
          status == 403
              ? 'You do not have permission to view these session requests.'
              : 'This Agent Hub does not support session request history yet.',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private'), findsNothing);
      expect(hub.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'late history 401 preserves newer default and scoped credentials',
    (tester) async {
      Session.store('old-agent-token');
      addTearDown(Session.clear);
      final delayed = Completer<http.Response>();
      final hub = HistoryHub()..historyDelayed = delayed;
      await mountHistory(tester, hub);
      await openHistory(tester);
      Session.store('new-token');
      Session.storeForClient('other', 'new-scoped-token');
      delayed.complete(http.Response('private', 401));
      await pumpCloseRequests(tester);
      expect(Session.read(), 'new-token');
      expect(Session.readForClient('other'), 'new-scoped-token');
      expect(find.textContaining('private'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('history leaves unknown close key and retry target untouched', (
    tester,
  ) async {
    final hub = HistoryHub()..unknownFirst = true;
    await mountHistory(tester, hub);
    await tester.tap(find.text('First session').first);
    await pumpCloseRequests(tester);
    await confirmClose(tester);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await openHistory(tester);
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('close-session-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry same request'));
    await pumpCloseRequests(tester);
    expect(hub.posts.length, 2);
    expect(
      hub.posts.first.headers['idempotency-key'],
      hub.posts.last.headers['idempotency-key'],
    );
    expect(hub.posts.first.url, hub.posts.last.url);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history preserves unknown creation target, name and retry key', (
    tester,
  ) async {
    final hub = HistoryHub();
    await mountHistory(tester, hub);
    await tester.tap(find.text('New session'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('new-session-name')),
      'Local pending',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create session'));
    await pumpCloseRequests(tester);
    await tester.tap(find.text('Close').last);
    await tester.pumpAndSettle();
    await openHistory(tester);
    await selectHistory(tester, 'create:r-1');
    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Session creation status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry same request'));
    await pumpCloseRequests(tester);
    expect(hub.creations.length, 2);
    expect(hub.creations.first.url, hub.creations.last.url);
    expect(hub.creations.first.body, hub.creations.last.body);
    expect(
      hub.creations.first.headers['idempotency-key'],
      hub.creations.last.headers['idempotency-key'],
    );
    expect(hub.posts, isEmpty);
    await tester.pumpWidget(const SizedBox());
  });

  for (final language in ['en', 'zh']) {
    testWidgets('$language narrow history and detail have no overflow', (
      tester,
    ) async {
      final hub = HistoryHub()
        ..emptySessions = true
        ..offline = true;
      await mountHistory(tester, hub, width: 320, locale: Locale(language));
      await openHistory(tester);
      expect(
        find.text(language == 'zh' ? '会话请求记录' : 'Session requests'),
        findsNWidgets(2),
      );
      expect(
        find.text(language == 'zh' ? '刷新最近记录' : 'Refresh latest'),
        findsOneWidget,
      );
      await selectHistory(tester, 'create:r-1');
      expect(
        find.text(language == 'zh' ? '请求详情' : 'Request details'),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(Card),
          matching: find.text(language == 'zh' ? '请求排队中' : 'Request queued'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
