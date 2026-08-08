import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_router.dart';

/// FG-3 acceptance pin — the app_router.dart call-site wiring, exercised
/// through the REAL entry point (resolveProductScreen → ProductEntry.login).
///
/// Why this exists: the REQ-3 contract test injects defaultClientId directly,
/// so it cannot observe a dropped wiring argument. Dropping the argument at
/// the call site while keeping the sso_client import leaves the lib/ quoted
/// grep at 1 hit (the constant declaration itself) — AC-1 stays green while
/// the production probe silently never fires (`_effectiveClientId` = '').
///
/// This pin is call-site-targeted: it renders resolveProductScreen, so a
/// dropped argument makes the mount probe never fire (probePosts == 0 → red)
/// and a wrong value fires it with the wrong client_id (→ red). It holds in
/// M2 state (green) and is the single-source counter to FG-3.
///
/// Literal-free by construction (references only the constant): the census
/// scans this file in strict mode, and the 30-test count gate pins only the
/// three named files, so this file moves no pin.
void main() {
  testWidgets(
    'resolveProductScreen wires firstPartyClientId to the login screen '
    '(FG-3 call-site pin)',
    (tester) async {
      var probePosts = 0;
      String? lastProbeClientId;
      final api = OidcLoginApi(
        baseUri: Uri.parse('https://sso.example/'),
        httpClient: MockClient((request) async {
          if (request.method == 'POST' && request.url.path == '/auth/login') {
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['credential'] is! Map) {
              // D9 filter: probe posts carry no credential map.
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
          home: resolveProductScreen(
            Uri.parse('https://sso.example/login/'),
            oidcLoginApi: api,
          ),
        ),
      );
      await tester.pumpAndSettle();
      // Wiring dropped → effective client id is empty → probe never fires.
      expect(probePosts, 1, reason: 'FG-3: app_router call-site wiring');
      // Wiring present → the probe carries exactly the constant's value.
      expect(lastProbeClientId, SSOAdminClient.firstPartyClientId);
    },
  );
}
