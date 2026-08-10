import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/api/setup_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/screens/setup/setup_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('SetupScreen', () {
    testWidgets('walks through admin creation and finish', (tester) async {
      var posted = <String>[];
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":true}', 200);
        }
        if (request.url.path == '/api/v1/setup') {
          posted.add(request.body);
          return http.Response(
            jsonEncode({
              'ok': true,
              'created': {
                'admin': 'root',
                'application': {
                  'client_id': 'first-app',
                  'client_secret': 'ONE-TIME-SECRET',
                },
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      // Step 1: admin form with validation.
      await tester.enterText(
        find.widgetWithText(TextField, 'Admin username'),
        'root',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'short',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'long-enough-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'long-enough-password',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: optional application.
      await tester.enterText(
        find.widgetWithText(TextField, 'Application name'),
        'First App',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Redirect URIs'),
        'https://app.example/callback',
      );
      await tester.tap(find.text('Create and finish'));
      await tester.pumpAndSettle();

      expect(posted.single, contains('"admin"'));
      expect(posted.single, contains('"username":"root"'));
      expect(posted.single, contains('"application"'));
      expect(posted.single, contains('"redirect_uris"'));
      // The one-time secret is displayed on the done screen.
      expect(find.text('ONE-TIME-SECRET'), findsOneWidget);
    });

    testWidgets('skips the application step', (tester) async {
      var posted = <String>[];
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":true}', 200);
        }
        if (request.url.path == '/api/v1/setup') {
          posted.add(request.body);
          return http.Response(
            jsonEncode({
              'ok': true,
              'created': {'admin': 'root'},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Admin username'),
        'root',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'long-enough-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'long-enough-password',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip and finish'));
      await tester.pumpAndSettle();

      expect(posted.single, contains('"admin"'));
      expect(posted.single, isNot(contains('"application"')));
    });

    testWidgets('shows already-initialized state', (tester) async {
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":false}', 200);
        }
        return http.Response('{}', 404);
      });
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.textContaining('already'), findsWidgets);
    });

    testWidgets('fails closed when the setup route is not mounted', (
      tester,
    ) async {
      final api = _setupApi((request) async => http.Response('{}', 404));
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('already-initialized exit records /admin/ on the stub', (
      tester,
    ) async {
      // REQ-1 exit 1: `_goToAdminConsole` (`setup_screen.dart:172`) via the
      // already-initialized panel's `'Go to admin console'` button
      // (`setup_widgets.dart:55-58`). The stub records the target
      // synchronously; assert on the recorded URI, never a mock interface.
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":false}', 200);
        }
        return http.Response('{}', 404);
      });
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to admin console'));
      await tester.pumpAndSettle();

      expect(BrowserNavigation.currentUri.path, '/admin/');
    });

    testWidgets('done-panel exit records /admin/ on the stub', (tester) async {
      // REQ-1 exit 2: `SetupDonePanel.onDone` -> `replaceLocation('/admin/')`
      // (`setup_screen.dart:362`). The no-secret fixture (no `client_secret`)
      // keeps the done action enabled without the secret-saved checkbox
      // (`setup_widgets.dart:355`).
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":true}', 200);
        }
        if (request.url.path == '/api/v1/setup') {
          return http.Response(
            jsonEncode({
              'ok': true,
              'created': {'admin': 'root'},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Admin username'),
        'root',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'long-enough-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'long-enough-password',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip and finish'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Go to admin console'));
      await tester.pumpAndSettle();

      expect(BrowserNavigation.currentUri.path, '/admin/');
    });

    testWidgets('setup-originated login wire carries the first-party client_id '
        '(REQ-2)', (tester) async {
      // REQ-2: pump `OidcLoginScreen` with the exact `app_router.dart:36`
      // wiring expression and assert the credential-bearing POST
      // `/auth/login` carries the first-party client id exactly once.
      final harness = _SetupLoginHarness(['ok']);
      await harness.pump(tester);

      await harness.submit(tester);

      expect(harness.loginPosts, 1);
      expect(harness.lastClientId, SSOAdminClient.firstPartyClientId);
    });
  });
}

SetupApi _setupApi(Future<http.Response> Function(http.Request) handler) =>
    SetupApi(client: MockClient(handler));

/// REQ-2 widget-level MockClient harness (mirror of `_LoginHarness` in
/// `test/oidc_login_screen_client_id_test.dart:27-104`).
///
/// A "login request" is a POST to `/auth/login` whose decoded body contains
/// a `credential` map (D9 filter). This deliberately excludes the mount-time
/// provider probe (`OidcLoginApi.probeProviders` POSTs to the same path with
/// only `client_id`/`login_hint`). The probe and the branding GET both answer
/// 404, which the screen treats as absence — no error UI, no pending timers.
class _SetupLoginHarness {
  _SetupLoginHarness(List<String> script) : script = List.of(script) {
    api = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/'),
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final isLogin = body['credential'] is Map; // D9 filter
          if (isLogin) {
            loginPosts++;
            lastClientId = body['client_id'] as String?;
            if (script.removeAt(0) == 'fail') {
              return http.Response(
                jsonEncode({'error': 'invalid_credentials'}),
                401,
              );
            }
            return http.Response(
              jsonEncode({'access_token': 't', 'session_id': 's'}),
              200,
            );
          }
        }
        // Probe, branding GET, and anything else: treated as absence.
        return http.Response('{}', 404);
      }),
    );
  }

  /// Per-test response script for credential-bearing login POSTs.
  final List<String> script;

  late final OidcLoginApi api;
  int loginPosts = 0;
  String? lastClientId;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          // The exact `app_router.dart:36` wiring expression.
          defaultClientId: SSOAdminClient.firstPartyClientId,
          // The redirect=/admin/ query shape the setup exits produce via
          // AdminGateScreen (`app_router.dart:19-20` doc comment). `redirect`
          // is not an OAuthParams field, so `_effectiveClientId` falls back to
          // `defaultClientId` (oidc_login_screen.dart:159-161).
          routeUri: Uri.parse('https://sso.example/login/?redirect=/admin/'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Username'),
      'ada@example.com',
    );
    // The login form's password field label is `strings.password`
    // ('Password').
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pw');
    // The view also renders a title Text('Sign in') above the button, so the
    // tap targets the FilledButton specifically.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }
}
