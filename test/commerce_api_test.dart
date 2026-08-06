import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_api.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_checkout.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_models.dart';
import 'package:sso_admin/screens/admin/commerce/commerce_tab.dart';

void main() {
  test('commerce client URL-encodes tenant and payment order identities', () async {
    final seen = <String>[];
    final api = _api((request) async {
      seen.add('${request.method} ${request.url.path}?${request.url.query}');
      return http.Response(
        request.url.path.endsWith('/events')
            ? '{"events":[]}'
            : request.url.path.endsWith('/wallet')
            ? '{"wallet":{"currency":"USD"}}'
            : '{"subscriptions":[]}',
        200,
      );
    });
    final commerce = CommerceAdminApi(api);

    await commerce.listSubscriptions('acme / west');
    await commerce.getWallet('acme / west', 'USD');
    await commerce.listPaymentEvents('acme / west', 'order / 1');

    expect(seen, [
      'GET /api/v1/admin/commerce/tenants/acme%20%2F%20west/subscriptions?',
      'GET /api/v1/admin/commerce/tenants/acme%20%2F%20west/wallet?currency=USD',
      'GET /api/v1/admin/commerce/tenants/acme%20%2F%20west/payments/orders/order%20%2F%201/events?',
    ]);
  });

  test('commerce mutations preserve revisions and financial idempotency', () async {
    final bodies = <String, Map<String, dynamic>>{};
    final authorization = <String?>[];
    final api = _api((request) async {
      bodies['${request.method} ${request.url.path}'] =
          Map<String, dynamic>.from(jsonDecode(request.body) as Map);
      authorization.add(request.headers['authorization']);
      return http.Response('{}', 200);
    });
    final commerce = CommerceAdminApi(api);

    await commerce.transitionSubscription('sub / 1', 'paused', 7);
    await commerce.changePlan('sub / 1', 'full', 3, 8);
    await commerce.renewSubscription('sub / 1', 9);
    await commerce.adjustWallet('tenant / 1', {
      'currency': 'USD',
      'amount_minor': -250,
      'reference': 'ticket-1',
      'idempotency_key': 'adjust-1',
    });
    await commerce.createTopUp('tenant / 1', {
      'provider': 'stripe',
      'currency': 'USD',
      'amount_minor': 500,
      'idempotency_key': 'topup-1',
    });
    await commerce.createCheckout(
      'tenant / 1',
      'order / 1',
      Uri.parse(
        'https://console.example.test/admin/commerce?checkout=complete',
      ),
      Uri.parse(
        'https://console.example.test/admin/commerce?checkout=cancelled',
      ),
    );

    expect(
      bodies['PATCH /api/v1/admin/commerce/subscriptions/sub%20%2F%201/status'],
      {'status': 'paused', 'expected_revision': 7},
    );
    expect(
      bodies['PATCH /api/v1/admin/commerce/subscriptions/sub%20%2F%201/plan'],
      {'plan_id': 'full', 'plan_version': 3, 'expected_revision': 8},
    );
    expect(
      bodies['POST /api/v1/admin/commerce/subscriptions/sub%20%2F%201/renew'],
      {'expected_revision': 9},
    );
    expect(
      bodies['POST /api/v1/admin/commerce/tenants/tenant%20%2F%201/wallet/adjustments'],
      containsPair('idempotency_key', 'adjust-1'),
    );
    expect(
      bodies['POST /api/v1/admin/commerce/tenants/tenant%20%2F%201/payments/orders'],
      containsPair('idempotency_key', 'topup-1'),
    );
    expect(bodies['POST /api/v1/checkout/sessions'], {
      'tenant_id': 'tenant / 1',
      'order_id': 'order / 1',
      'success_url':
          'https://console.example.test/admin/commerce?checkout=complete',
      'cancel_url':
          'https://console.example.test/admin/commerce?checkout=cancelled',
    });
    expect(authorization, everyElement('Bearer admin-token'));
  });

  test('checkout URLs use only the trusted console origin', () {
    final urls = CommerceCheckoutUrls.fromOrigin(
      Uri.parse('https://console.example.test:8443/untrusted?token=secret'),
    );
    expect(
      urls.success.toString(),
      'https://console.example.test:8443/admin/commerce?checkout=complete',
    );
    expect(
      urls.cancel.toString(),
      'https://console.example.test:8443/admin/commerce?checkout=cancelled',
    );
    expect(
      () => CommerceCheckoutUrls.fromOrigin(Uri.parse('http://console.test')),
      throwsStateError,
    );
    expect(
      () => CommerceCheckoutUrls.fromOrigin(
        Uri.parse('http://127.evil.test.invalid:4444'),
      ),
      throwsStateError,
    );
    expect(
      CommerceCheckoutUrls.fromOrigin(
        Uri.parse('http://127.0.0.1:4444'),
      ).success.host,
      '127.0.0.1',
    );
  });

  test('checkout response parsing rejects unsafe redirects', () {
    expect(
      commerceCheckoutOrderID({
        'order': {'id': 'order-one'},
      }),
      'order-one',
    );
    expect(
      commerceCheckoutRedirect({
        'redirect_url': 'https://checkout.stripe.com/c/pay/cs_one',
      }).host,
      'checkout.stripe.com',
    );
    for (final value in [
      'http://checkout.stripe.com/cs_one',
      'https://user@checkout.stripe.com/cs_one',
      'javascript:alert(1)',
      'https://checkout.stripe.com\\evil.test/cs_one',
    ]) {
      expect(
        () => commerceCheckoutRedirect({'redirect_url': value}),
        throwsFormatException,
      );
    }
  });

  test('commerce model copy distinguishes hard zero from unlimited', () {
    expect(
      commerceGrant({'soft': 0, 'hard': 0, 'unlimited': false}),
      'Hard 0 · soft 0',
    );
    expect(
      commerceGrant({'soft': 0, 'hard': 0, 'unlimited': true}),
      'Unlimited',
    );
    expect(
      commerceMinorUnits({'currency': 'JPY', 'minor_units': 125}),
      'JPY 125 minor units',
    );
  });

  test('commerce probing hides only absent or forbidden modules', () {
    expect(
      commerceProbeState(const SnaplinkAdminApiError(403)),
      CommerceProbeState.unavailable,
    );
    expect(
      commerceProbeState(const SnaplinkAdminApiError(404)),
      CommerceProbeState.unavailable,
    );
    expect(
      commerceProbeState(const SnaplinkAdminApiError(500)),
      CommerceProbeState.degraded,
    );
    expect(
      commerceProbeState(StateError('offline')),
      CommerceProbeState.degraded,
    );
    expect(commerceProbeState(null), CommerceProbeState.available);
  });

  test('operation catalog includes the complete commerce admin family', () {
    final routes = SnaplinkAdminOperationCatalog.endpoints
        .map((endpoint) => '${endpoint.method} ${endpoint.path}')
        .toSet();

    expect(routes, contains('GET /api/v1/admin/commerce/plans'));
    expect(routes, contains('POST /api/v1/admin/commerce/plans'));
    expect(
      routes,
      contains('PATCH /api/v1/admin/commerce/subscriptions/{id}/status'),
    );
    expect(
      routes,
      contains(
        'GET /api/v1/admin/commerce/tenants/{tenant_id}/payments/orders/{order_id}/events',
      ),
    );
    expect(
      routes,
      contains(
        'POST /api/v1/admin/commerce/tenants/{tenant_id}/payments/reconcile',
      ),
    );
  });

  testWidgets('tenant commerce keeps independent 404 sections visible', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = _api((request) async {
      final path = request.url.path;
      if (path == '/api/v1/admin/commerce/plans') {
        return http.Response('{"plans":[]}', 200);
      }
      if (path.endsWith('/subscriptions')) {
        return http.Response('{"subscriptions":[]}', 200);
      }
      if (path.endsWith('/payments/orders')) {
        return http.Response('{"orders":[]}', 200);
      }
      return http.Response('{"error":"commerce_not_found"}', 404);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CommerceTab(api: api)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'tenant-a');
    await tester.tap(find.text('Load tenant commerce'));
    await tester.pumpAndSettle();

    expect(find.text('This tenant has no subscriptions.'), findsOneWidget);
    expect(
      find.text('No entitlement projection exists for this tenant.'),
      findsOneWidget,
    );
    expect(find.text('No USD wallet exists for this tenant.'), findsOneWidget);
    expect(
      find.text('No top-up orders exist for this tenant.'),
      findsOneWidget,
    );
    expect(find.text('Commerce service error'), findsNothing);
  });

  testWidgets('top-up creates a Stripe order and navigates without a secret', (
    tester,
  ) async {
    _largeView(tester);
    final requests = <http.Request>[];
    Uri? navigated;
    final api = _api((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/api/v1/admin/commerce/plans') {
        return http.Response('{"plans":[]}', 200);
      }
      if (request.method == 'POST' && path.endsWith('/payments/orders')) {
        return http.Response('{"order":{"id":"order-one"}}', 201);
      }
      if (path == '/api/v1/checkout/sessions') {
        return http.Response(
          '{"session_id":"cs_one","redirect_url":"https://checkout.stripe.com/c/pay/cs_one","expires_at":"2030-01-01T00:00:00Z"}',
          201,
        );
      }
      return _tenantCommerceResponse(path, orders: const []);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommerceTab(
            api: api,
            checkoutOrigin: () => Uri.parse('https://console.example.test'),
            checkoutNavigator: (target) {
              navigated = target;
              return true;
            },
          ),
        ),
      ),
    );
    await _loadTenant(tester);
    await tester.tap(find.text('Create top-up order'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Top-up amount in minor units'),
      '500',
    );
    await tester.tap(find.text('Continue to secure checkout'));
    await tester.pumpAndSettle();
    await _confirmFinancial(tester);

    final orderRequest = requests.firstWhere(
      (request) =>
          request.method == 'POST' &&
          request.url.path.endsWith('/payments/orders'),
    );
    final orderBody = jsonDecode(orderRequest.body) as Map<String, dynamic>;
    expect(orderBody['provider'], 'stripe');
    expect(orderBody, isNot(contains('provider_order_id')));
    expect(orderBody, isNot(contains('amount')));
    final checkoutRequest = requests.firstWhere(
      (request) => request.url.path == '/api/v1/checkout/sessions',
    );
    expect(checkoutRequest.headers['authorization'], 'Bearer admin-token');
    expect(jsonDecode(checkoutRequest.body), {
      'tenant_id': 'tenant-a',
      'order_id': 'order-one',
      'success_url':
          'https://console.example.test/admin/commerce?checkout=complete',
      'cancel_url':
          'https://console.example.test/admin/commerce?checkout=cancelled',
    });
    expect(navigated?.host, 'checkout.stripe.com');
    expect(find.textContaining('https://checkout.stripe.com'), findsNothing);
  });

  testWidgets('failed checkout keeps a retryable order and hides details', (
    tester,
  ) async {
    _largeView(tester);
    var checkoutCalls = 0;
    final pending = {
      'id': 'order-pending',
      'status': 'pending',
      'provider': 'stripe',
      'provider_order_id': '',
      'currency': 'USD',
      'amount_minor': 500,
      'revision': 1,
    };
    final api = _api((request) async {
      final path = request.url.path;
      if (path == '/api/v1/admin/commerce/plans') {
        return http.Response('{"plans":[]}', 200);
      }
      if (path == '/api/v1/checkout/sessions') {
        checkoutCalls++;
        return http.Response(
          '{"error":"provider_unavailable","error_description":"internal-provider-secret"}',
          502,
        );
      }
      return _tenantCommerceResponse(path, orders: [pending]);
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommerceTab(
            api: api,
            checkoutOrigin: () => Uri.parse('https://console.example.test'),
            checkoutNavigator: (_) => true,
          ),
        ),
      ),
    );
    await _loadTenant(tester);
    await tester.tap(find.text('Continue secure checkout'));
    await tester.pumpAndSettle();
    await _confirmFinancial(tester);

    expect(checkoutCalls, 1);
    expect(find.text('Continue secure checkout'), findsOneWidget);
    expect(
      find.textContaining('The pending order is saved, but secure checkout'),
      findsOneWidget,
    );
    expect(find.textContaining('internal-provider-secret'), findsNothing);
  });

  testWidgets('unknown order response reconciles by idempotency key', (
    tester,
  ) async {
    _largeView(tester);
    Map<String, dynamic>? pending;
    var checkoutCalls = 0;
    final api = _api((request) async {
      final path = request.url.path;
      if (path == '/api/v1/admin/commerce/plans') {
        return http.Response('{"plans":[]}', 200);
      }
      if (request.method == 'POST' && path.endsWith('/payments/orders')) {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        pending = {
          'id': 'order-recovered',
          'status': 'pending',
          'provider': 'stripe',
          'provider_order_id': '',
          'currency': 'USD',
          'amount_minor': 500,
          'idempotency_key': body['idempotency_key'],
          'revision': 1,
        };
        return http.Response(
          '{"error":"unavailable","error_description":"database-internal"}',
          503,
        );
      }
      if (path == '/api/v1/checkout/sessions') {
        checkoutCalls++;
        return http.Response('{}', 500);
      }
      return _tenantCommerceResponse(
        path,
        orders: pending == null ? const [] : [pending!],
      );
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommerceTab(
            api: api,
            checkoutOrigin: () => Uri.parse('https://console.example.test'),
            checkoutNavigator: (_) => true,
          ),
        ),
      ),
    );
    await _loadTenant(tester);
    await tester.tap(find.text('Create top-up order'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Top-up amount in minor units'),
      '500',
    );
    await tester.tap(find.text('Continue to secure checkout'));
    await tester.pumpAndSettle();
    await _confirmFinancial(tester);

    expect(checkoutCalls, 0);
    expect(find.text('Continue secure checkout'), findsOneWidget);
    expect(
      find.textContaining('The pending order is saved, but secure checkout'),
      findsOneWidget,
    );
    expect(find.textContaining('database-internal'), findsNothing);
  });
}

void _largeView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _loadTenant(WidgetTester tester) async {
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).first, 'tenant-a');
  await tester.tap(find.text('Load tenant commerce'));
  await tester.pumpAndSettle();
}

Future<void> _confirmFinancial(WidgetTester tester) async {
  final confirmation = find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.isDense == true,
  );
  expect(confirmation, findsOneWidget);
  await tester.enterText(confirmation, 'tenant-a');
  await tester.pump();
  final button = find.widgetWithText(FilledButton, 'Confirm financial change');
  expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

http.Response _tenantCommerceResponse(
  String path, {
  required List<Map<String, dynamic>> orders,
}) {
  if (path.endsWith('/subscriptions')) {
    return http.Response('{"subscriptions":[]}', 200);
  }
  if (path.endsWith('/payments/orders')) {
    return http.Response(jsonEncode({'orders': orders}), 200);
  }
  if (path.endsWith('/entitlement') ||
      path.endsWith('/wallet') ||
      path.endsWith('/wallet/entries')) {
    return http.Response('{"error":"commerce_not_found"}', 404);
  }
  return http.Response('{}', 200);
}

SnaplinkAdminApi _api(Future<http.Response> Function(http.Request) handler) =>
    SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient(handler),
    );
