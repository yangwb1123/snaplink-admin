import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/break_glass_tab.dart';
import 'package:sso_admin/screens/admin/health_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

SnaplinkAdminApi _api(
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);

SnaplinkAdminCapabilities _breakGlassCaps() => SnaplinkAdminCapabilities([
  SnaplinkAdminEndpoint(
    method: 'GET',
    path: '/api/v1/admin/break-glass',
    feature: 'core',
  ),
]);

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('HealthTab', () {
    testWidgets('renders distributed cluster and runs the self-test', (
      tester,
    ) async {
      final api = _api({
        '/health': (_) => http.Response(
          jsonEncode({'status': 'ok', 'version': '1.2.3'}),
          200,
        ),
        '/readyz': (_) => http.Response(
          jsonEncode({
            'status': 'ready',
            'checks': {
              'etcd-signing-key-registry': 'ok',
              'invalidation-bus': 'ok',
              'signing-key-aggregation': 'ok',
              'audit-postgres': 'ok',
            },
          }),
          200,
        ),
        '/api/v1/status': (_) => http.Response(
          jsonEncode({
            'version': '1.2.3',
            'modules': {'audit-postgres': 'ok', 'sessions': 'ok'},
          }),
          200,
        ),
        '/api/v1/admin/keys': (_) => http.Response(
          jsonEncode({
            'status': 'ok',
            'keys': [
              {'kid': 'kid-active', 'alg': 'EdDSA', 'state': 'active'},
              {'kid': 'kid-peer-a', 'alg': 'EdDSA', 'state': 'verify_only'},
              {'kid': 'kid-peer-b', 'alg': 'EdDSA', 'state': 'verify_only'},
            ],
          }),
          200,
        ),
        '/.well-known/jwks.json': (_) => http.Response(
          jsonEncode({
            'keys': [
              {'kid': 'kid-active'},
              {'kid': 'kid-peer-a'},
              {'kid': 'kid-peer-b'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/endpoints': (_) =>
            http.Response(jsonEncode({'endpoints': []}), 200),
      });
      await tester.pumpWidget(_wrap(HealthTab(api: api)));
      await tester.pumpAndSettle();

      // Distributed cluster section renders the signing fleet and the
      // control-plane checks.
      await tester.scrollUntilVisible(
        find.text('Distributed Cluster'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Distributed Cluster'), findsOneWidget);
      expect(
        find.text('3 replica keys (1 active, 2 verify-only)'),
        findsOneWidget,
      );
      expect(find.text('kid-active (EdDSA)'), findsOneWidget);
      expect(find.text('etcd-signing-key-registry'), findsOneWidget);
      expect(find.text('invalidation-bus'), findsOneWidget);
      expect(find.text('signing-key-aggregation'), findsOneWidget);

      // Self-test: all four checks pass.
      await tester.scrollUntilVisible(
        find.text('Run Cluster Self-Test'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Run Cluster Self-Test'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run Cluster Self-Test'));
      await tester.pumpAndSettle();
      expect(find.text('Fleet aggregation'), findsOneWidget);
      expect(find.text('Cross-replica token validation'), findsOneWidget);
      expect(find.text('Control plane checks'), findsOneWidget);
      expect(find.text('Backend module checks'), findsOneWidget);
      expect(find.text('All 4 checks passed'), findsOneWidget);

      // Unmount so the periodic refresh timer is cancelled before the test
      // ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('renders server, storage and federation health', (
      tester,
    ) async {
      final api = _api({
        '/health': (_) => http.Response(
          jsonEncode({
            'status': 'ok',
            'version': '1.2.3',
            'issuer': 'https://sso.example.test',
            'vcs_revision': 'abcdef123456',
            'vcs_time': '2026-08-01T00:00:00Z',
          }),
          200,
        ),
        '/api/v1/admin/storage-health': (_) =>
            http.Response(jsonEncode({'database': 'ok', 'redis': 'ok'}), 200),
        '/api/v1/admin/federation/health': (_) =>
            http.Response(jsonEncode({'connections': 3}), 200),
      });
      await tester.pumpWidget(_wrap(HealthTab(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Backend Server'), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
      expect(find.text('1.2.3'), findsOneWidget);
      expect(find.text('abcdef123456'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Storage Health'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Storage Health'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Federation Health'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Federation Health'), findsOneWidget);

      // Quick actions are available.
      await tester.scrollUntilVisible(
        find.text('Quick Actions'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Quick Actions'), findsOneWidget);
      await tester.tap(find.text('Refresh Cache'));
      await tester.pumpAndSettle();
      expect(find.text('Cache cleared'), findsOneWidget);

      // Unmount so the periodic refresh timer is cancelled before the test
      // ends.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('shows an error state with retry when the backend is down', (
      tester,
    ) async {
      var calls = 0;
      final api = _api({
        '/health': (_) {
          calls++;
          // The API client retries GETs with backoff (up to 3 attempts); the
          // whole first refresh round must fail so the error state shows.
          if (calls <= 3) {
            throw http.ClientException('connection refused');
          }
          return http.Response(
            jsonEncode({
              'status': 'ok',
              'version': '2.0.0',
              'vcs_revision': 'deadbeefcafe',
            }),
            200,
          );
        },
      });
      // The tab auto-refreshes on a 30s timer; advance the fake clock only
      // enough for the GET retry backoff chain (500ms, then 1000ms) to
      // settle, not far enough to trigger the periodic timer.
      await tester.pumpWidget(_wrap(HealthTab(api: api)));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(seconds: 2));
      await tester.pump();

      expect(find.text('Cannot reach backend'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);

      await tester.tap(find.text('Retry'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump();
      expect(find.text('Backend Server'), findsOneWidget);
      expect(find.text('2.0.0'), findsOneWidget);
      expect(calls, greaterThanOrEqualTo(2));

      // Unmount so the periodic refresh timer is cancelled before the test
      // ends.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('BreakGlassTab', () {
    const session = {
      'id': 'grant-1',
      'target_user_id': 'user-42',
      'scope': 'readonly',
      'status': 'pending',
      'reason': 'Support escalation',
    };

    // The session list sits below the tall request card; use a tall viewport
    // so the whole ListView is laid out.
    Future<void> pumpBreakGlass(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(child));
      await tester.pumpAndSettle();
    }

    testWidgets('fails closed when the endpoint is not in capabilities', (
      tester,
    ) async {
      final api = _api({});
      await tester.pumpWidget(
        _wrap(
          BreakGlassTab(api: api, capabilities: SnaplinkAdminCapabilities([])),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Break-glass access is not enabled on this replica.'),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    });

    testWidgets('lists pending grants and approves one', (tester) async {
      var approved = <String>[];
      final api = _api({
        '/api/v1/admin/break-glass': (_) => http.Response(
          jsonEncode({
            'sessions': [session],
          }),
          200,
        ),
        '/api/v1/admin/break-glass/grant-1/approve': (request) {
          approved.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await pumpBreakGlass(
        tester,
        BreakGlassTab(api: api, capabilities: _breakGlassCaps()),
      );

      expect(find.text('user-42 · pending'), findsOneWidget);
      expect(find.textContaining('grant-1'), findsOneWidget);

      await tester.tap(find.text('Approve'));
      await tester.pumpAndSettle();
      expect(find.text('Approve?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'grant-1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Approve').last);
      await tester.pumpAndSettle();

      expect(approved, ['/api/v1/admin/break-glass/grant-1/approve']);
      expect(find.text('Break-glass approved.'), findsOneWidget);
    });

    testWidgets('creates a grant with typed target confirmation', (
      tester,
    ) async {
      var created = <String>[];
      final api = _api({
        '/api/v1/admin/break-glass': (request) {
          if (request.method == 'POST') {
            created.add(request.body);
            return http.Response('{}', 200);
          }
          return http.Response(jsonEncode({'sessions': []}), 200);
        },
      });
      await pumpBreakGlass(
        tester,
        BreakGlassTab(api: api, capabilities: _breakGlassCaps()),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Target user ID'),
        'user-42',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Reason (ticket/incident ref)'),
        'Support escalation',
      );
      // The card routes to /admin/emergency-access/new; the tab's route
      // handler opens the typed confirmation.
      await tester.tap(find.text('Create break-glass request'));
      await tester.pumpAndSettle();
      expect(find.text('Create emergency-access grant?'), findsOneWidget);
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'user-42',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Create grant').last);
      await tester.pumpAndSettle();

      expect(created.single, contains('"target_user_id":"user-42"'));
      expect(created.single, contains('"reason":"Support escalation"'));
      expect(created.single, contains('"scope":"readonly"'));
      expect(find.text('Break-glass session created.'), findsOneWidget);
    });

    testWidgets('requires both target and reason before creating', (
      tester,
    ) async {
      final api = _api({
        '/api/v1/admin/break-glass': (_) =>
            http.Response(jsonEncode({'sessions': []}), 200),
      });
      await pumpBreakGlass(
        tester,
        BreakGlassTab(api: api, capabilities: _breakGlassCaps()),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Target user ID'),
        'user-42',
      );
      await tester.tap(find.text('Create break-glass request'));
      await tester.pumpAndSettle();
      expect(find.text('Target user and reason are required.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('impersonation shows the token exactly once', (tester) async {
      const activeSession = {
        'id': 'grant-2',
        'target_user_id': 'user-7',
        'scope': 'readonly',
        'status': 'active',
        'reason': 'Incident response',
      };
      final api = _api({
        '/api/v1/admin/break-glass': (_) => http.Response(
          jsonEncode({
            'sessions': [activeSession],
          }),
          200,
        ),
        '/api/v1/admin/break-glass/grant-2/impersonate': (_) => http.Response(
          jsonEncode({'access_token': 'IMPERSONATION-TOKEN'}),
          200,
        ),
      });
      await pumpBreakGlass(
        tester,
        BreakGlassTab(api: api, capabilities: _breakGlassCaps()),
      );

      expect(find.text('user-7 · active'), findsOneWidget);
      await tester.tap(find.text('Impersonate'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'grant-2',
      );
      await tester.pumpAndSettle();
      // Confirm through the dialog's own button (the card also shows an
      // "Impersonate" action for active grants).
      await tester.tap(find.widgetWithText(FilledButton, 'Impersonate'));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump();

      expect(find.text('Impersonation token'), findsOneWidget);
      expect(find.text('IMPERSONATION-TOKEN'), findsOneWidget);
      expect(
        find.text(
          'This bearer is shown once and is not retained by the console.',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text('I have saved it'));
      await tester.pumpAndSettle();
      expect(find.text('IMPERSONATION-TOKEN'), findsNothing);
    });

    testWidgets('revokes a grant with typed confirmation', (tester) async {
      var revoked = <String>[];
      final api = _api({
        '/api/v1/admin/break-glass': (_) => http.Response(
          jsonEncode({
            'sessions': [session],
          }),
          200,
        ),
        '/api/v1/admin/break-glass/grant-1': (request) {
          if (request.method == 'DELETE') revoked.add(request.url.path);
          return http.Response('{}', 200);
        },
      });
      await pumpBreakGlass(
        tester,
        BreakGlassTab(api: api, capabilities: _breakGlassCaps()),
      );

      await tester.tap(find.text('Revoke'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(TextField),
        ),
        'grant-1',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').last);
      await tester.pumpAndSettle();

      expect(revoked, ['/api/v1/admin/break-glass/grant-1']);
    });
  });
}
