import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';

/// REQ-2 + REQ-3 widget-level MockClient harness (design §4.2, D9/D11).
///
/// A "login request" is a POST to `/auth/login` whose decoded body contains a
/// `credential` map. This deliberately excludes the mount-time provider probe
/// (`OidcLoginApi.probeProviders` POSTs to the same path with only
/// `client_id`/`login_hint`) and any `/auth/send-code` traffic (different
/// path). The probe and the branding GET both answer 404, which the screen
/// treats as absence — no error UI, no pending timers.
///
/// REQ-2 expectation source (design §4.2/§5/§6.4): the three literal sites
/// below (harness `defaultClientId` + two `expect(lastClientId, …)`) are
/// constantized to `SSOAdminClient.firstPartyClientId` in the same commit as
/// the constant (sibling co-change list, §3.4) — after which this file
/// references the constant (compile-time gate) and carries no literal; the
/// AC-1 `test/` grep turns from pinned-allowlist to zero hits, and the census
/// literal-census asserts the same automatically.
class _LoginHarness {
  _LoginHarness(List<String> script) : script = List.of(script) {
    api = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/'),
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final isLogin = body['credential'] is Map; // D9 filter
          if (isLogin) {
            loginPosts++;
            lastClientId = body['client_id'] as String?;
            lastUsername =
                (body['credential'] as Map)['username'] as String?;
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
          probePosts++; // mount-time probe: no `credential` key
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
  int probePosts = 0;
  String? lastClientId;
  String? lastUsername;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          defaultClientId: SSOAdminClient.firstPartyClientId,
          // Constantized to SSOAdminClient.firstPartyClientId in the sibling
          // M2 commit (co-change list §3.4; design §4.2 constant rule).
          // D11: no prompt=none, no fragment, no magic-link token, no flow
          // param — avoids silent-renewal and federated-resume auto-fire.
          routeUri: Uri.parse('https://sso.example/login/'),
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
    // The login form's password field label is `strings.password` ('Password').
    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'pw',
    );
    // The view also renders a title Text('Sign in') above the button, so the
    // tap targets the FilledButton specifically.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('OidcLoginScreen client_id + exactly-once login POST', () {
    testWidgets(
      'mount probe fires once and is not a login request (F1, D9)',
      (tester) async {
        final harness = _LoginHarness(['ok']);
        await harness.pump(tester);

        // Probe-404 at initState: the probe answered 404 and was excluded by
        // the credential-key filter; the login form is still up with no
        // branding-error UI.
        expect(harness.probePosts, 1);
        expect(harness.loginPosts, 0);
        expect(find.widgetWithText(TextField, 'Username'), findsOneWidget);
        expect(find.widgetWithText(TextField, 'Password'), findsOneWidget);
      },
    );

    testWidgets(
      'single submit sends one credential-bearing login POST with the '
      'contract client_id (REQ-2 + REQ-3)',
      (tester) async {
        final harness = _LoginHarness(['ok']);
        await harness.pump(tester);

        await harness.submit(tester);

        // Request-side facts only: no navigation/session assertions (D6).
        // Constantized: lastClientId is SSOAdminClient.firstPartyClientId
        // (design §4.2/§5) since the sibling M2 commit.
        expect(harness.loginPosts, 1);
        expect(harness.lastClientId, SSOAdminClient.firstPartyClientId);
        expect(harness.lastUsername, 'ada@example.com');
      },
    );

    testWidgets(
      'retry after 401: exactly one login POST per submit, cumulative 2 '
      '(REQ-3)',
      (tester) async {
        final harness = _LoginHarness(['fail', 'ok']);
        await harness.pump(tester);

        await harness.submit(tester);
        expect(harness.loginPosts, 1);
        // The 401 surface the server error; `_loading` clears in `finally`,
        // so the submit button re-enables for the retry.
        expect(find.text('invalid_credentials'), findsOneWidget);

        await harness.submit(tester);
        expect(harness.loginPosts, 2);
        // Constantized: lastClientId is SSOAdminClient.firstPartyClientId
        // (design §4.2/§5) since the sibling M2 commit.
        expect(harness.lastClientId, SSOAdminClient.firstPartyClientId);
      },
    );
  });
}
