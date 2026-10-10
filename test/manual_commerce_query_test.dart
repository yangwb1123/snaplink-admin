import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_tab.dart';

SnaplinkAdminApi _api(Future<http.Response> Function(http.Request) send) =>
    SnaplinkAdminApi(
      baseUrl: 'https://sso.test',
      accessToken: 'fixture',
      httpClient: MockClient(send),
    )..maxRetries = 0;
http.Response _json(Object value) => http.Response(jsonEncode(value), 200);
Future<void> _pump(WidgetTester tester, SnaplinkAdminApi api) async {
  tester.view.physicalSize = const Size(1400, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: CommerceTab(
          api: api,
          probeClientBuilder: () => _api((_) async => http.Response('', 404)),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _field(String label) => find.widgetWithText(TextField, label);
Future<void> _load(WidgetTester tester, String tenant) async {
  await tester.enterText(_field('Tenant ID'), tenant);
  await tester.pump();
  await tester.tap(find.text('Load tenant commerce'));
  await tester.pumpAndSettle();
}

http.Response _response(
  http.Request request, {
  int balance = 10,
  String order = 'order-one',
}) {
  final path = request.url.path;
  if (path.endsWith('/plans')) return _json({'plans': []});
  if (path.endsWith('/subscriptions')) return _json({'subscriptions': []});
  if (path.endsWith('/entitlement')) {
    return http.Response('{"error":"not_found"}', 404);
  }
  if (path.endsWith('/wallet')) {
    return _json({
      'wallet': {
        'currency': request.url.queryParameters['currency'],
        'balance_minor': balance,
        'version': 1,
        'status': 'active',
      },
    });
  }
  if (path.endsWith('/wallet/entries')) return _json({'entries': []});
  return _json({
    'orders': [
      {
        'id': order,
        'currency': 'USD',
        'amount_minor': 100,
        'status': 'pending',
        'provider': 'stripe',
        'revision': 1,
      },
    ],
  });
}

void main() {
  testWidgets(
    'commerce refresh reads wallet and ledger again, and input edits hide old finance facts',
    (tester) async {
      var wallets = 0, ledgers = 0;
      final api = _api((request) async {
        expect(request.method, 'GET');
        if (request.url.path.endsWith('/wallet')) wallets++;
        if (request.url.path.endsWith('/wallet/entries')) ledgers++;
        return _response(request, balance: wallets * 10);
      });
      await _pump(tester, api);
      expect(wallets, 0);
      await _load(tester, 'tenant/one');
      expect(find.text('USD 10 minor units'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(wallets, 2);
      expect(ledgers, 2);
      expect(find.text('USD 20 minor units'), findsOneWidget);
      await tester.enterText(_field('Currency'), 'EUR');
      await tester.pump();
      expect(find.text('USD 20 minor units'), findsNothing);
      expect(find.text('Create top-up order'), findsNothing);
      expect(wallets, 2);
      await tester.tap(find.text('Load tenant commerce'));
      await tester.pumpAndSettle();
      expect(find.text('EUR 30 minor units'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('late finance response cannot replace the newly queried tenant', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    final api = _api((request) async {
      expect(request.method, 'GET');
      if (request.url.path.contains('/old/')) return old.future;
      return _response(request, balance: 99, order: 'new-order');
    });
    await _pump(tester, api);
    await tester.enterText(_field('Tenant ID'), 'old');
    await tester.tap(find.text('Load tenant commerce'));
    await tester.pump();
    await _load(tester, 'new');
    old.complete(
      _json({
        'wallet': {'currency': 'USD', 'balance_minor': 1},
        'subscriptions': [],
        'orders': [
          {'id': 'old-order'},
        ],
        'entries': [],
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('USD 99 minor units'), findsOneWidget);
    expect(find.text('USD 1 minor units'), findsNothing);
    expect(find.textContaining('new-order'), findsOneWidget);
    expect(find.textContaining('old-order'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'failed wallet and ledger do not imply absent wallet or empty ledger',
    (tester) async {
      final api = _api((request) async {
        expect(request.method, 'GET');
        if (request.url.path.endsWith('/wallet')) {
          return http.Response(
            '{"error":"forbidden","error_description":"wallet access denied"}',
            403,
          );
        }
        if (request.url.path.endsWith('/wallet/entries')) {
          return http.Response(
            '{"error":"unavailable","error_description":"ledger unavailable"}',
            502,
          );
        }
        return _response(request);
      });
      await _pump(tester, api);
      await _load(tester, 'tenant-one');
      expect(find.text('Wallet data is unavailable.'), findsOneWidget);
      expect(find.text('Ledger data is unavailable.'), findsOneWidget);
      expect(find.textContaining('wallet access denied'), findsOneWidget);
      expect(find.textContaining('ledger unavailable'), findsOneWidget);
      expect(find.text('No USD wallet exists for this tenant.'), findsNothing);
      expect(find.text('No ledger entries.'), findsNothing);
      expect(find.textContaining('order-one'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
