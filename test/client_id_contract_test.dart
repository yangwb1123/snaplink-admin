import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';

/// REQ-3 first-party channel contract (AC-3): pins
/// `defaultClientId → _effectiveClientId → probe fire → POST body client_id`.
///
/// Channel coverage only: the assertion compares the captured body against
/// the constant itself, so a value flip keeps this test green — the value
/// itself is pinned by AC-1 (lib/ quoted grep = 1, the constant
/// declaration) and the drill AGREED_CLIENT_ID.
///
/// Hard requirements:
/// - The probe fires only when `_effectiveClientId` is non-empty; the
///   constructor has no default for `defaultClientId` (String?), so the
///   constant must be passed explicitly (omission ⇒ empty id ⇒ probe never
///   fires ⇒ this test is red-on-arrival).
/// - The plain first-party route (no query params, no flow, no magic-link
///   token, no prompt=none) satisfies all six conditions of the probe guard
///   in oidc_login_screen.dart initState, so exactly one mount-time probe
///   POST to /auth/login occurs.
/// - URL precedence: `?client_id=<rp>` in the route URI overrides
///   `defaultClientId` — the RP-passthrough chain is
///   `OAuthParams.fromUri (oauth_params.dart:59)` → `_effectiveClientId
///   (oidc_login_screen.dart:159-161)`, where the URL value wins over the
///   first-party default. The second case below pins that priority; the
///   override value is a distinct literal-free string (never the constant's
///   value, which strict-mode census would flag).
/// - Literal-free by construction (references only the constant): the
///   census scans every test/*.dart in strict mode once the constant
///   exists, so a fresh literal (contiguous or split) would redden it.
void main() {
  testWidgets(
    'mount probe fires exactly once with the constant client_id (AC-3)',
    (tester) async {
      var probePosts = 0;
      var loginPosts = 0;
      String? lastProbeClientId;
      final api = OidcLoginApi(
        baseUri: Uri.parse('https://sso.example/'),
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/auth/login') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['credential'] is Map) {
              // Credential-bearing login POST (D9 filter).
              loginPosts++;
            } else {
              // Mount-time provider probe: no credential map.
              probePosts++;
              lastProbeClientId = body['client_id'] as String?;
            }
          }
          // Probe, branding GET, and anything else: treated as absence.
          return http.Response('{}', 404);
        }),
      );
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            // FG-1: no constructor default — must pass the constant
            // explicitly or _effectiveClientId is empty and the probe
            // never fires.
            defaultClientId: SSOAdminClient.firstPartyClientId,
            // Plain first-party route: no query params, no flow, no
            // magic-link token, no prompt=none.
            routeUri: Uri.parse('https://sso.example/login/'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly one mount-time probe carrying the constant's value; the
      // probe is not a login request.
      expect(probePosts, 1);
      expect(lastProbeClientId, SSOAdminClient.firstPartyClientId);
      expect(loginPosts, 0);
    },
  );

  testWidgets(
    'URL-passthrough client_id overrides defaultClientId (URL precedence)',
    (tester) async {
      // RP-passthrough id, deliberately distinct from the first-party
      // constant (strict-mode census bans the constant's literal here).
      const rpClientId = 'sso-relay-client';
      var probePosts = 0;
      var loginPosts = 0;
      String? lastProbeClientId;
      final api = OidcLoginApi(
        baseUri: Uri.parse('https://sso.example/'),
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/auth/login') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['credential'] is Map) {
              loginPosts++;
            } else {
              probePosts++;
              lastProbeClientId = body['client_id'] as String?;
            }
          }
          return http.Response('{}', 404);
        }),
      );
      tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      addTearDown(api.close);
      await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            // The first-party default is present, but the URL's own
            // client_id must win (oauth_params.dart:59 →
            // _effectiveClientId oidc_login_screen.dart:159-161).
            defaultClientId: SSOAdminClient.firstPartyClientId,
            routeUri: Uri.parse(
              'https://sso.example/login/?client_id=$rpClientId',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exactly one mount-time probe, carrying the URL-provided id — not
      // the constant. The plain client_id-only route still satisfies all
      // probe-guard conditions (HostedLoginRoute.fromUri: default login
      // flow, no token/email/flow params, no prompt=none).
      expect(probePosts, 1);
      expect(lastProbeClientId, rpClientId);
      expect(lastProbeClientId, isNot(SSOAdminClient.firstPartyClientId));
      expect(loginPosts, 0);
    },
  );
}
