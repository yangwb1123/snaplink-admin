import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/screens/admin/governance_models.dart';
import 'package:sso_admin/screens/admin/governance_tab.dart';
import 'package:sso_admin/screens/admin/permission_detail_screen.dart';
import 'package:sso_admin/screens/admin/token_security_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

import 'fixtures/admin_page_fixture.dart';

final _capabilities = SnaplinkAdminCapabilities(
  SnaplinkAdminOperationCatalog.endpoints,
);

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(BrowserNavigation.resetForTest);
  for (final section in [
    'all',
    'health',
    'audit',
    'compliance',
    'configuration',
    'lifecycle',
    'write',
  ]) {
    testWidgets('governance/$section loads only its own read sources', (
      tester,
    ) async {
      BrowserNavigation.pushState(
        AdminRoute.url(
          'governance',
          subresource: section == 'all' ? '' : section,
        ),
      );
      final fixture = AdminPageFixture();
      await _pump(
        tester,
        GovernanceTab(api: fixture.api, capabilities: _capabilities),
      );
      expect(tester.takeException(), isNull);
      expect(fixture.unhandled, isEmpty);
      expect(
        fixture.paths,
        unorderedEquals([
          for (final spec in governanceReadSpecs)
            if (section == 'all' || spec.section == section) spec.path,
        ]),
      );
      await tester.pumpWidget(const SizedBox());
    });
  }
  final tokenSources = {
    'portfolio': '/api/v1/admin/tokens/portfolio',
    'suspicious': '/api/v1/admin/tokens/suspicious',
    'sessions': '/api/v1/admin/sessions',
    'expiring': '/api/v1/admin/tokens/expiring',
    'revoke': '/api/v1/admin/tokens',
  };
  for (final section in [...tokenSources.keys, 'temp']) {
    testWidgets('token-security/$section does not load unrelated sources', (
      tester,
    ) async {
      BrowserNavigation.pushState(
        AdminRoute.url('token-security', subresource: section),
      );
      final fixture = AdminPageFixture();
      await _pump(
        tester,
        TokenSecurityTab(api: fixture.api, capabilities: _capabilities),
      );
      expect(tester.takeException(), isNull);
      expect(fixture.unhandled, isEmpty);
      expect(
        fixture.paths,
        section == 'temp' ? isEmpty : [tokenSources[section]],
      );
      if (section == 'temp') {
        expect(find.byKey(const Key('temp-token-user-id')), findsOneWidget);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'submenu switches and browser history reload the selected source',
    (tester) async {
      BrowserNavigation.pushState(
        AdminRoute.url('token-security', subresource: 'sessions'),
      );
      final fixture = AdminPageFixture();
      await _pump(
        tester,
        TokenSecurityTab(api: fixture.api, capabilities: _capabilities),
      );
      AdminRoute.go('token-security', subresource: 'expiring');
      await tester.pumpAndSettle();
      AdminRoute.go('token-security', subresource: 'sessions');
      await tester.pumpAndSettle();
      expect(fixture.paths, [
        '/api/v1/admin/sessions',
        '/api/v1/admin/tokens/expiring',
        '/api/v1/admin/sessions',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'permission history transitions reload only roles or assignments',
    (tester) async {
      BrowserNavigation.pushState(
        AdminRoute.url(
          'permissions',
          resourceId: 'client-1',
          subresource: 'roles',
        ),
      );
      final fixture = AdminPageFixture();
      await _pump(
        tester,
        PermissionDetailScreen(
          api: fixture.api,
          client: fixture.client,
          clientId: 'client-1',
        ),
      );
      AdminRoute.go(
        'permissions',
        resourceId: 'client-1',
        subresource: 'assignments',
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('user-1'), findsWidgets);
      expect(find.textContaining('viewer'), findsWidgets);
      AdminRoute.go(
        'permissions',
        resourceId: 'client-1',
        subresource: 'roles',
      );
      await tester.pumpAndSettle();
      expect(fixture.paths, [
        '/api/v1/admin/permissions/client-1/roles',
        '/api/v1/admin/permissions/client-1/assignments',
        '/api/v1/admin/permissions/client-1/roles',
      ]);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('refresh exposes a new 403 instead of serving cached token data', (
    tester,
  ) async {
    BrowserNavigation.pushState(
      AdminRoute.url('token-security', subresource: 'sessions'),
    );
    var calls = 0, unauthorized = 0;
    final transport = MockClient((request) async {
      expect(request.url.path, '/api/v1/admin/sessions');
      calls++;
      return calls == 1
          ? http.Response('{"sessions":[],"total":0}', 200)
          : http.Response(
              '{"error":{"code":"forbidden","message":"fixture permission denied"}}',
              403,
            );
    });
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.test',
      accessToken: 'fixture',
      httpClient: transport,
      onUnauthorized: () => unauthorized++,
    )..maxRetries = 0;
    await _pump(
      tester,
      TokenSecurityTab(api: api, capabilities: _capabilities),
    );
    await tester.tap(find.byTooltip('Refresh'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(unauthorized, 0);
    expect(find.textContaining('fixture permission denied'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'a late source failure cannot overwrite a newly selected submenu',
    (tester) async {
      BrowserNavigation.pushState(
        AdminRoute.url('token-security', subresource: 'portfolio'),
      );
      final pending = Completer<http.Response>();
      final paths = <String>[];
      final transport = MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/portfolio')) return pending.future;
        return http.Response(jsonEncode({'sessions': [], 'total': 0}), 200);
      });
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.test',
        accessToken: 'fixture',
        httpClient: transport,
      )..maxRetries = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TokenSecurityTab(api: api, capabilities: _capabilities),
          ),
        ),
      );
      await tester.pump();
      AdminRoute.go('token-security', subresource: 'sessions');
      await tester.pumpAndSettle();
      pending.complete(http.Response('{"error":"old-source-failed"}', 503));
      await tester.pumpAndSettle();
      expect(paths, [
        '/api/v1/admin/tokens/portfolio',
        '/api/v1/admin/sessions',
      ]);
      expect(find.textContaining('old-source-failed'), findsNothing);
      expect(find.text('Active sessions'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
