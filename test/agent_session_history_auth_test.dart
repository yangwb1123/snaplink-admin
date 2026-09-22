import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/screens/agent/agent_session_history.dart';
import 'package:sso_admin/session.dart';
import 'agent_session_close_fixture.dart' show pumpCloseRequests;
import 'agent_session_creation_test.dart' show apiFor, response;
import 'agent_session_history_fixture.dart';
import 'agent_session_history_test.dart' show operationData, operationPage;

void main() {
  for (final kind in ['list', 'detail']) {
    testWidgets('late $kind clears old account records after new credentials', (
      tester,
    ) async {
      Session.store('old-agent-token');
      addTearDown(Session.clear);
      final delayed = Completer<http.Response>();
      final hub = HistoryHub();
      if (kind == 'list') hub.historyDelayed = delayed;
      await mountHistory(tester, hub);
      await openHistory(tester);
      if (kind == 'detail') {
        await selectHistory(tester, 'create:r-1');
        hub.detailDelayed = delayed;
        await tester.tap(find.byKey(const ValueKey('history-refresh-detail')));
        await tester.pump();
      }
      Session.store('fresh-default-token');
      Session.storeForClient('other', 'fresh-scoped-token');
      delayed.complete(
        kind == 'list'
            ? operationPage([operationData()])
            : response(operationData(status: 'created')..remove('operation')),
      );
      await pumpCloseRequests(tester);
      expect(
        find.byKey(const ValueKey('history-row-create:r-1')),
        findsNothing,
      );
      expect(find.textContaining('Remote session'), findsNothing);
      expect(
        find.text(
          'Your sign-in changed. Close this dialog and reopen requests after signing in.',
        ),
        findsOneWidget,
      );
      expect(Session.read(), 'fresh-default-token');
      expect(Session.readForClient('other'), 'fresh-scoped-token');
      final count = hub.reads.length;
      await tester.tap(find.byKey(const ValueKey('history-latest')));
      await pumpCloseRequests(tester);
      expect(hub.reads.length, count);
      await tester.pumpWidget(const SizedBox());
    });
  }

  test(
    'lost authorization before GET clears page and prevents another request',
    () async {
      var authorized = true;
      var calls = 0;
      final api = apiFor((_) async {
        calls++;
        return operationPage([operationData()]);
      });
      final history = AgentSessionHistory(
        api,
        'i-1',
        isAuthorized: () => authorized,
      );
      await history.load();
      history.select(history.page!.items.single);
      authorized = false;
      await history.refreshSelected();
      expect(calls, 1);
      expect(history.page, isNull);
      expect(history.selected, isNull);
      history.dispose();
      api.close();
    },
  );

  test(
    'disposed history ignores late page without notifying or adopting it',
    () async {
      final delayed = Completer<http.Response>();
      final api = apiFor((_) => delayed.future);
      final history = AgentSessionHistory(api, 'i-1');
      var notifications = 0;
      history.addListener(() {
        notifications++;
      });
      final pending = history.load();
      history.dispose();
      delayed.complete(operationPage([operationData()]));
      await pending;
      expect(history.page, isNull);
      expect(notifications, 1);
      api.close();
    },
  );
}
