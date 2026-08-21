import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_operations_tab.dart';
import 'package:sso_admin/screens/admin/admin_ops_helpers.dart';

void main() {
  testWidgets('unknown outcome notice wraps at narrow widths', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Builder(
              builder: (context) => AdminOpsHelpers.unknownOutcomeCard(
                context,
                onAcknowledge: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Previous write outcome is unknown'), findsOneWidget);
    expect(find.text('I reconciled server state'), findsOneWidget);
  });

  test(
    'only ambiguous write statuses require authoritative reconciliation',
    () {
      for (final status in const [408, 429, 500, 502, 503, 599]) {
        expect(
          AdminOpsHelpers.isAmbiguousWriteStatus(status),
          isTrue,
          reason: 'HTTP $status may follow a committed write',
        );
      }
      for (final status in const [400, 401, 403, 404, 409, 412, 422]) {
        expect(
          AdminOpsHelpers.isAmbiguousWriteStatus(status),
          isFalse,
          reason: 'HTTP $status is an authoritative rejection',
        );
      }
    },
  );

  for (final testCase in const [
    (status: 503, locked: true),
    (status: 400, locked: false),
  ]) {
    testWidgets(
      'HTTP ${testCase.status} ${testCase.locked ? 'locks' : 'does not lock'} the mutation form',
      (tester) async {
        _useTallViewport(tester);
        const endpoint = SnaplinkAdminEndpoint(
          method: 'PATCH',
          path: '/api/v1/admin/test-write',
          feature: 'test',
        );
        final api = SnaplinkAdminApi(
          baseUrl: 'https://sso.example',
          accessToken: 'token',
          httpClient: MockClient(
            (_) async =>
                http.Response('{"message":"server response"}', testCase.status),
          ),
        )..maxRetries = 1;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AdminOperationsTab(api: api, endpoints: const [endpoint]),
            ),
          ),
        );
        await tester.pumpAndSettle();
        _selectEndpoint(tester, endpoint);
        await tester.pump();
        await tester.enterText(
          _fieldWithLabel('Exact write confirmation'),
          'CONFIRM PATCH /api/v1/admin/test-write',
        );
        await tester.tap(find.text('Run PATCH'));
        await tester.pumpAndSettle();

        expect(
          find.text('Previous write outcome is unknown'),
          testCase.locked ? findsOneWidget : findsNothing,
        );
        expect(
          _runButton(tester, 'Run PATCH').onPressed,
          testCase.locked ? isNull : isNotNull,
        );
      },
    );
  }

  testWidgets(
    'transport exception locks mutation but permits GET until reconciliation',
    (tester) async {
      _useTallViewport(tester);
      const writeEndpoint = SnaplinkAdminEndpoint(
        method: 'POST',
        path: '/api/v1/admin/test-write',
        feature: 'test',
      );
      const readEndpoint = SnaplinkAdminEndpoint(
        method: 'GET',
        path: '/api/v1/admin/test-write',
        feature: 'test',
      );
      var writeRequests = 0;
      var readRequests = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example',
        accessToken: 'token',
        httpClient: MockClient((request) async {
          if (request.method == 'POST') {
            writeRequests++;
            throw http.ClientException('connection closed', request.url);
          }
          readRequests++;
          return http.Response('{"state":"authoritative"}', 200);
        }),
      )..maxRetries = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AdminOperationsTab(
              api: api,
              endpoints: const [writeEndpoint, readEndpoint],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _selectEndpoint(tester, writeEndpoint);
      await tester.pump();
      await tester.enterText(
        _fieldWithLabel('Exact write confirmation'),
        'CONFIRM POST /api/v1/admin/test-write',
      );
      await tester.tap(find.text('Run POST'));
      await tester.pumpAndSettle();

      expect(writeRequests, 1);
      expect(find.text('Previous write outcome is unknown'), findsOneWidget);
      expect(
        find.textContaining('Write outcome is unknown because no response'),
        findsOneWidget,
      );
      expect(_runButton(tester, 'Run POST').onPressed, isNull);
      expect(
        tester
            .widget<TextField>(_fieldWithLabel('Query parameters JSON'))
            .enabled,
        isFalse,
      );
      expect(
        tester.widget<TextField>(_fieldWithLabel('Request body JSON')).enabled,
        isFalse,
      );
      expect(
        tester
            .widget<TextField>(_fieldWithLabel('Exact write confirmation'))
            .enabled,
        isFalse,
      );

      // A safe read stays available so the operator can inspect authoritative
      // state without prematurely unlocking or replaying the mutation.
      _selectEndpoint(tester, readEndpoint);
      await tester.pump();
      expect(_runButton(tester, 'Run GET').onPressed, isNotNull);
      await tester.tap(find.text('Run GET'));
      await tester.pumpAndSettle();
      expect(readRequests, 1);
      expect(find.text('Previous write outcome is unknown'), findsOneWidget);

      _selectEndpoint(tester, writeEndpoint);
      await tester.pump();
      expect(_runButton(tester, 'Run POST').onPressed, isNull);
      await tester.tap(find.text('I reconciled server state'));
      await tester.pumpAndSettle();

      final dialog = find.byType(AlertDialog);
      expect(dialog, findsOneWidget);
      expect(find.text('Type "RECONCILED" to confirm:'), findsOneWidget);
      final unlockButton = tester.widget<FilledButton>(
        find.descendant(
          of: dialog,
          matching: find.widgetWithText(FilledButton, 'Unlock writes'),
        ),
      );
      expect(unlockButton.onPressed, isNull);

      await tester.enterText(
        find.descendant(of: dialog, matching: find.byType(TextField)),
        'RECONCILED',
      );
      await tester.pump();
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: dialog,
                matching: find.widgetWithText(FilledButton, 'Unlock writes'),
              ),
            )
            .onPressed,
        isNotNull,
      );
      await tester.tap(find.text('Unlock writes'));
      await tester.pumpAndSettle();

      expect(find.text('Previous write outcome is unknown'), findsNothing);
      expect(_runButton(tester, 'Run POST').onPressed, isNotNull);
      expect(
        tester.widget<TextField>(_fieldWithLabel('Request body JSON')).enabled,
        isTrue,
      );
      expect(writeRequests, 1, reason: 'unlocking must never replay the write');
    },
  );
}

void _selectEndpoint(WidgetTester tester, SnaplinkAdminEndpoint endpoint) {
  tester
      .widget<DropdownButtonFormField<SnaplinkAdminEndpoint>>(
        find.byType(DropdownButtonFormField<SnaplinkAdminEndpoint>),
      )
      .onChanged!(endpoint);
}

Finder _fieldWithLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

FilledButton _runButton(WidgetTester tester, String label) =>
    tester.widget<FilledButton>(
      find.ancestor(
        of: find.text(label),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      ),
    );

void _useTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1800);
  addTearDown(tester.view.reset);
}
