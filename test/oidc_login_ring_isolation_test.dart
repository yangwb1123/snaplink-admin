@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/local_storage.dart';

/// AC-1 Phase A (spec REQ-2): completing an `OidcLoginScreen` login must
/// leave the debug-only audit ring (`sso_audit_log`) untouched — no new
/// key, no rewrite of the stored value, no in-memory mutation, and no
/// request to any audit endpoint.
///
/// The MockClient replicates the `_LoginHarness` pattern from
/// `test/oidc_login_screen_client_id_test.dart` (deliberate duplication —
/// the harness is file-private): a "login request" is a POST to
/// `/auth/login` whose decoded body contains a `credential` map (D9
/// filter), which excludes the mount-time provider probe (same path, no
/// `credential`) and the branding GET (both answer 404 = absence).
///
/// NOTE (design §0.4 D1): the ring is pre-seeded, so `LocalStorage.keys()`
/// *necessarily* contains `sso_audit_log` before the login. The assertions
/// therefore compare the post-seed snapshot (keys set, stored JSON value,
/// service count, entries) against the post-login state — a net-zero
/// rewrite (write-then-restore) is caught by the stored-value comparison.
class _RingIsolationHarness {
  _RingIsolationHarness() {
    api = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/'),
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['credential'] is Map) {
            loginPosts++;
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

  late final OidcLoginApi api;
  final List<String> paths = [];
  int loginPosts = 0;
  int probePosts = 0;

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          // Deliberately NOT the contract client_id literal: the census
          // `test/oidc_login_handle_success_census_test.dart` pins the
          // exact set of test/ files carrying the quoted contract value
          // (B6-2 single-source rule; constantization is the sibling M2
          // commit). Any non-empty value fires the mount probe
          // identically, and REQ-2/AC-1 Phase A never asserts the wire
          // client_id value.
          defaultClientId: 'ring-isolation-test-client',
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
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pw');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
  }
}

void main() {
  group('OidcLoginScreen ring isolation (AC-1 Phase A, REQ-2)', () {
    testWidgets('login flow leaves the pre-seeded audit ring untouched', (
      tester,
    ) async {
      // Pre-seed the debug-only ring (design §1.2): record() persists
      // synchronously via LocalStorage.setItem, so the key is present.
      AuditLogService().record(
        AuditEntry(
          timestamp: DateTime.now(),
          method: 'POST',
          path: '/api/v1/admin/forged',
          statusCode: 200,
          label: 'forged',
        ),
      );
      addTearDown(AuditLogService().clear);

      // Post-seed snapshots (design §0.4 D1 correction).
      final keysBefore = LocalStorage.keys().toSet();
      final valueBefore = LocalStorage.getItem('sso_audit_log');
      final countBefore = AuditLogService().count;
      final entriesBefore = AuditLogService().entries;
      expect(keysBefore, contains('sso_audit_log'), reason: 'seed sanity');
      expect(countBefore, 1, reason: 'seed sanity');

      final harness = _RingIsolationHarness();
      await harness.pump(tester);
      await harness.submit(tester);

      // Exactly one credential-bearing login POST; the mount probe is not
      // a login request.
      expect(harness.loginPosts, 1);
      expect(harness.probePosts, 1);

      // Ring untouched: no new key, no stored-value rewrite, no in-memory
      // mutation, no audit-endpoint request from the login flow.
      expect(LocalStorage.keys().toSet(), keysBefore);
      expect(LocalStorage.getItem('sso_audit_log'), valueBefore);
      expect(AuditLogService().count, countBefore);
      expect(AuditLogService().entries, entriesBefore);
      expect(
        harness.paths.where((p) => p.contains('/api/v1/audit')),
        isEmpty,
        reason: 'the login flow must not issue any audit request',
      );
    });
  });
}
