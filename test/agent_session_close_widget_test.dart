import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/session.dart';
import 'agent_session_close_fixture.dart';
import 'agent_session_close_test.dart' show closeData, closeError;
import 'agent_session_creation_test.dart' show response;

void main() {
  testWidgets(
    'confirmation names exact session and cancellation sends nothing',
    (tester) async {
      final hub = CloseHub();
      await mountClose(tester, hub);
      await tester.tap(find.byKey(const ValueKey('close-session-action')));
      await tester.pumpAndSettle();
      expect(find.text('Close session?'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('First session'),
        ),
        findsOneWidget,
      );
      expect(find.text('s-1'), findsOneWidget);
      expect(find.textContaining('history is preserved'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(hub.posts, isEmpty);
      expect(closeDetail(tester).canControl, true);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'accepted close disables composer; dismissed dialog polls GET and keeps history',
    (tester) async {
      final hub = CloseHub();
      await mountClose(tester, hub);
      expect(find.text('Preserved response'), findsOneWidget);
      await confirmClose(tester);
      expect(hub.posts.length, 1);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(closeDetail(tester).canControl, false);
      expect(find.text('Preserved response'), findsOneWidget);
      hub.status = 'closed';
      await tester.pump(const Duration(seconds: 2));
      await pumpCloseRequests(tester);
      expect(hub.polls, 1);
      expect(hub.posts.length, 1);
      expect(closeDetail(tester).session.sessionId, 's-1');
      expect(closeDetail(tester).session.frozen, true);
      expect(
        find.text('Session closed. Its history is still available.'),
        findsOneWidget,
      );
      expect(find.text('Preserved response'), findsOneWidget);
      await tester.tap(find.text('Compute tasks').last);
      await tester.pumpAndSettle();
      await pumpCloseRequests(tester);
      expect(find.text('Run a compute task'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'unknown result and later denial retain original POST across dialog dismissal',
    (tester) async {
      final hub = CloseHub()
        ..unknownFirst = true
        ..denySecond = true;
      await mountClose(tester, hub);
      await confirmClose(tester);
      expect(find.text('Retry same request'), findsOneWidget);
      expect(find.textContaining('raw-private'), findsNothing);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      expect(closeDetail(tester).canControl, false);
      await tester.pump(const Duration(seconds: 5));
      expect(find.text('The selected instance is offline.'), findsNothing);
      expect(hub.posts.length, 1);
      await tester.tap(find.byKey(const ValueKey('close-session-action')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Retry same request'));
      await pumpCloseRequests(tester);
      await tester.tap(find.text('Retry same request'));
      await pumpCloseRequests(tester);
      expect(hub.posts.length, 3);
      expect(
        hub.posts.map((item) => item.headers['idempotency-key']).toSet().length,
        1,
      );
      expect(
        hub.posts.every(
          (item) => item.body == '{}' && item.url.path.endsWith('/s-1/close'),
        ),
        true,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'late close result never changes selected session or transcript',
    (tester) async {
      final delayed = Completer<http.Response>();
      final hub = CloseHub()..delayed = delayed;
      await mountClose(tester, hub);
      await confirmClose(tester);
      await tester.tap(find.text('Dismiss'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Second session').first);
      await pumpCloseRequests(tester);
      delayed.complete(response(closeData(status: 'closed'), status: 202));
      await pumpCloseRequests(tester);
      expect(closeDetail(tester).session.sessionId, 's-2');
      expect(closeDetail(tester).canControl, true);
      expect(find.text('Preserved response'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final mode in ['unsupported', 'turn', 'compute']) {
    testWidgets('$mode session cannot start closing from the UI', (
      tester,
    ) async {
      final hub = CloseHub()
        ..supported = mode != 'unsupported'
        ..activeTurn = mode == 'turn'
        ..activeCompute = mode == 'compute';
      await mountClose(tester, hub);
      final button = tester.widget<OutlinedButton>(
        find.byKey(const ValueKey('close-session-action')),
      );
      expect(button.onPressed, isNull);
      expect(hub.posts, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final status in ['failed', 'lost']) {
    testWidgets(
      '$status terminal close cannot retry and preserves read-only history',
      (tester) async {
        final hub = CloseHub()..status = status;
        await mountClose(tester, hub);
        await confirmClose(tester);
        expect(find.text('Retry same request'), findsNothing);
        expect(find.text('Confirm close'), findsNothing);
        await tester.tap(find.text('Dismiss'));
        await tester.pumpAndSettle();
        expect(closeDetail(tester).canControl, false);
        expect(find.text('Preserved response'), findsOneWidget);
        expect(hub.posts.length, 1);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  for (final leave in [false, true]) {
    testWidgets('late 401 preserves newer credentials (leave=$leave)', (
      tester,
    ) async {
      Session.store('old-agent-token');
      addTearDown(Session.clear);
      final delayed = Completer<http.Response>();
      final hub = CloseHub()..delayed = delayed;
      await mountClose(tester, hub);
      await confirmClose(tester);
      if (leave) await tester.pumpWidget(const SizedBox());
      Session.store('new-default-token');
      Session.storeForClient('other', 'new-scoped-token');
      delayed.complete(closeError('unauthorized', status: 401));
      await pumpCloseRequests(tester);
      expect(Session.read(), 'new-default-token');
      expect(Session.readForClient('other'), 'new-scoped-token');
      expect(find.textContaining('raw-private'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final locale in [const Locale('en'), const Locale('zh')]) {
    testWidgets('shared narrow close confirmation has no overflow in $locale', (
      tester,
    ) async {
      await mountClose(tester, CloseHub(), width: 320, locale: locale);
      await tester.tap(find.byKey(const ValueKey('close-session-action')));
      await tester.pumpAndSettle();
      expect(
        find.text(locale.languageCode == 'zh' ? '确认关闭' : 'Confirm close'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
