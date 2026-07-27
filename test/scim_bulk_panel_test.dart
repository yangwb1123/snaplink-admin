import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/scim/scim_bulk_panel.dart';

void main() {
  testWidgets('bulk stays fail-closed when capability discovery fails', (
    tester,
  ) async {
    _useTallViewport(tester);
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example',
      accessToken: 'token',
      httpClient: MockClient((_) async => http.Response('{}', 503)),
    )..maxRetries = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScimBulkPanel(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry discovery'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Load template'),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<FilledButton>(
            find.ancestor(
              of: find.text('Execute bulk'),
              matching: find.byWidgetPredicate(
                (widget) => widget is FilledButton,
              ),
            ),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('retry discovery can enable an explicitly advertised Bulk', (
    tester,
  ) async {
    _useTallViewport(tester);
    var requests = 0;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example',
      accessToken: 'token',
      httpClient: MockClient((_) async {
        requests++;
        if (requests == 1) return http.Response('{}', 503);
        return http.Response(
          jsonEncode({
            'bulk': {
              'supported': true,
              'maxOperations': 25,
              'maxPayloadSize': 4096,
            },
          }),
          200,
        );
      }),
    )..maxRetries = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ScimBulkPanel(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry discovery'));
    await tester.pumpAndSettle();

    expect(requests, 2);
    expect(find.text('Retry discovery'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Load template'),
          )
          .onPressed,
      isNotNull,
    );
  });

  testWidgets(
    'unknown Bulk outcome locks replay until explicit reconciliation',
    (tester) async {
      _useTallViewport(tester);
      var postRequests = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example',
        accessToken: 'token',
        httpClient: MockClient((request) async {
          if (request.method == 'GET' &&
              request.url.path.endsWith('/ServiceProviderConfig')) {
            return http.Response(
              jsonEncode({
                'bulk': {
                  'supported': true,
                  'maxOperations': 25,
                  'maxPayloadSize': 4096,
                },
              }),
              200,
            );
          }
          if (request.method == 'POST' && request.url.path.endsWith('/Bulk')) {
            postRequests++;
            throw http.ClientException(
              'response connection was lost',
              request.url,
            );
          }
          return http.Response('{}', 404);
        }),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ScimBulkPanel(api: api)),
        ),
      );
      await tester.pumpAndSettle();

      const request = '''
{
  "schemas": ["urn:ietf:params:scim:api:messages:2.0:BulkRequest"],
  "failOnErrors": 1,
  "Operations": [
    {
      "method": "POST",
      "bulkId": "new-user",
      "path": "/Users",
      "data": {"userName": "ada@example.test"}
    }
  ]
}
''';
      await tester.enterText(find.byType(TextField), request);
      await tester.pump();

      final executeButton = find.ancestor(
        of: find.text('Execute bulk'),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(tester.widget<FilledButton>(executeButton).onPressed, isNotNull);
      await tester.tap(executeButton);
      await tester.pumpAndSettle();

      final confirmation = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(confirmation, findsOneWidget);
      await tester.tap(confirmation);
      await tester.pumpAndSettle();

      expect(postRequests, 1);
      expect(find.text('Previous bulk outcome is unknown'), findsOneWidget);
      expect(find.textContaining('response was not received'), findsOneWidget);
      expect(find.text('I reconciled server state'), findsOneWidget);
      expect(find.textContaining('Retry bulk'), findsNothing);
      expect(find.text('Retry discovery'), findsNothing);
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      expect(tester.widget<FilledButton>(executeButton).onPressed, isNull);
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Load template'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(executeButton);
      await tester.pump();
      expect(postRequests, 1);

      await tester.tap(find.text('I reconciled server state'));
      await tester.pumpAndSettle();

      final unlockButton = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byWidgetPredicate((widget) => widget is FilledButton),
      );
      expect(tester.widget<FilledButton>(unlockButton).onPressed, isNull);
      final reconciliationInput = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(reconciliationInput, 'RECONCILED');
      await tester.pump();
      expect(tester.widget<FilledButton>(unlockButton).onPressed, isNotNull);
      await tester.tap(unlockButton);
      await tester.pumpAndSettle();

      expect(find.text('Previous bulk outcome is unknown'), findsNothing);
      expect(
        find.text(
          'Reconciliation acknowledged. Review the draft before sending.',
        ),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.widget<FilledButton>(executeButton).onPressed, isNotNull);
      expect(postRequests, 1);
    },
  );
}

void _useTallViewport(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1200, 1600);
  addTearDown(tester.view.reset);
}
