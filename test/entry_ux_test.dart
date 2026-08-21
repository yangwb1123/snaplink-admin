import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';
import 'package:sso_admin/screens/developer/developer_screen.dart';
import 'package:sso_admin/screens/device/device_verify_api.dart';
import 'package:sso_admin/screens/device/device_verify_screen.dart';
import 'package:sso_admin/screens/setup/setup_validation.dart';
import 'package:sso_admin/screens/setup/setup_widgets.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/local_storage.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/widgets/responsive_entry_card.dart';

void main() {
  test('setup redirect URIs reject fragments and embedded user info', () {
    expect(
      () => parseSetupRedirectUris('https://app.example/callback#token'),
      throwsFormatException,
    );
    expect(
      () => parseSetupRedirectUris(
        'https://operator:secret@app.example/callback',
      ),
      throwsFormatException,
    );
    expect(
      parseSetupRedirectUris(
        'https://app.example/callback\nhttp://localhost:8080/callback',
      ),
      ['https://app.example/callback', 'http://localhost:8080/callback'],
    );
  });

  testWidgets('setup protects and labels a one-time client secret', (
    tester,
  ) async {
    var continued = false;
    await _useNarrowViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveEntryCard(
            child: SetupDonePanel(
              adminUsername: 'root',
              clientId: 'client-1',
              clientSecret: 'secret-1',
              onDone: () => continued = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Client ID'), findsOneWidget);
    expect(find.text('Client secret · shown once'), findsOneWidget);
    expect(find.byTooltip('Copy Client secret'), findsOneWidget);
    expect(_filledButton(tester, 'Go to admin console').onPressed, isNull);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.text('I have securely saved the client secret.'),
    );
    await tester.tap(find.text('I have securely saved the client secret.'));
    await tester.pump();
    expect(_filledButton(tester, 'Go to admin console').onPressed, isNotNull);
    await tester.tap(find.text('Go to admin console'));
    expect(continued, isTrue);
  });

  testWidgets('partial setup offers an in-place recovery action', (
    tester,
  ) async {
    var retried = false;
    await _useNarrowViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveEntryCard(
            child: SetupDonePanel(
              adminUsername: 'root',
              applicationRequestedButMissing: true,
              onRetryApplication: () async => retried = true,
              onDone: () {},
            ),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Retry application creation'));
    await tester.tap(find.text('Retry application creation'));
    expect(retried, isTrue);
  });

  testWidgets('editing a checked device code invalidates its old preview', (
    tester,
  ) async {
    final api = DeviceVerifyApi(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status': 'pending',
            'client_name': 'Accounting terminal',
            'scopes': ['openid', 'payments:write'],
          }),
          200,
        ),
      ),
    );
    await _useNarrowViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceVerifyScreen(
          api: api,
          accessTokenProvider: () => 'user-token',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ABCD-1234');
    await tester.tap(find.text('Check code'));
    await tester.pumpAndSettle();
    expect(find.text('Accounting terminal'), findsOneWidget);
    expect(_filledButton(tester, 'Approve').onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'WXYZ-5678');
    await tester.pump();
    expect(find.text('Accounting terminal'), findsNothing);
    expect(_filledButton(tester, 'Approve').onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('developer discovery failure offers an in-place retry', (
    tester,
  ) async {
    var calls = 0;
    final api = DeveloperApi(
      httpClient: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('{}', 503);
        return http.Response(
          jsonEncode({
            'registration_endpoint': 'https://sso.example/register',
            'grant_types_supported': ['authorization_code'],
            'response_types_supported': ['code'],
            'token_endpoint_auth_methods_supported': ['none'],
            'code_challenge_methods_supported': ['S256'],
            'scopes_supported': ['openid'],
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://sso.example'),
    );
    await tester.pumpWidget(MaterialApp(home: DeveloperScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Retry discovery'), findsOneWidget);
    await tester.tap(find.text('Retry discovery'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Retry discovery'), findsNothing);
  });

  // B6-2 device-entry redirect leg (REQ-1): pins the no-session entry leg —
  // SessionStorage is memory-backed on VM (fresh per test-file isolate) and
  // Session.clear() in setUp guarantees a null session.
  group('B6-2 device-entry redirect leg (REQ-1)', () {
    setUp(() {
      BrowserNavigation.resetForTest();
      Session.clear(); // memory-backed on VM (D-DEV-2); guarantees null session
    });

    testWidgets(
      'no session with user_code redirects to /login/?redirect=/device/verify?user_code=…',
      (tester) async {
        await _useNarrowViewport(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceVerifyScreen(
              accessTokenProvider: () => null,
              routeUri: Uri.parse(
                'https://sso.example/device/verify?user_code=WXYZ-1234',
              ),
            ),
          ),
        );
        await tester
            .pump(); // fire addPostFrameCallback (:76) -> _redirectToLogin; stub records synchronously
        expect(BrowserNavigation.currentUri.path, '/login/'); // static getter
        expect(
          BrowserNavigation.currentUri.queryParameters['redirect'],
          '/device/verify?user_code=WXYZ-1234',
        );
      },
    );

    testWidgets(
      'no session without code redirects to /login/?redirect=/device/verify',
      (tester) async {
        await _useNarrowViewport(tester);
        await tester.pumpWidget(
          MaterialApp(
            home: DeviceVerifyScreen(
              accessTokenProvider: () => null,
              routeUri: Uri.parse('https://sso.example/device/verify'),
            ),
          ),
        );
        await tester
            .pump(); // fire addPostFrameCallback (:76) -> _redirectToLogin
        expect(BrowserNavigation.currentUri.path, '/login/'); // static getter
        expect(
          BrowserNavigation.currentUri.queryParameters['redirect'],
          '/device/verify',
        );
        expect(
          BrowserNavigation.currentUri.queryParameters.containsKey('user_code'),
          isFalse,
        );
      },
    );
  });

  // B6-1 device decisions stay out of the debug ring (REQ-1/REQ-2, AC-3).
  // The device module is a pure consumer: every decision path (check,
  // approve, deny, 401-expiry) must leave the debug-only audit ring
  // untouched — no writes, no reads, no storage interaction. The ring is
  // provably live (test/snaplink_admin_api_test.dart liveness group), so a
  // zero-write assertion is non-vacuous.
  //
  // Fixtures are per-test (each test builds its own MockClient + recording
  // list), so the group is order-independent under
  // --test-randomize-ordering-seed. Every test pins accessTokenProvider so
  // the no-session redirect spinner (an indefinitely animating
  // CircularProgressIndicator, device_verify_screen.dart:280-288) is
  // unreachable and pumpAndSettle always settles.
  group('B6-1 device decisions stay out of the debug ring (REQ-1)', () {
    setUp(() {
      BrowserNavigation.resetForTest();
      Session.clear();
      // D8: AuditLogService.clear() persists '[]' under the ring key, so the
      // key must be removed afterwards to restore the null-key baseline the
      // ring-untouched assertions rely on. TearDown order is clear() then
      // removeItem() — the reverse would re-persist '[]'.
      final ring = AuditLogService();
      ring.clear();
      LocalStorage.removeItem(
        'sso_audit_'
        'log',
      );
      addTearDown(() {
        ring.clear();
        LocalStorage.removeItem(
          'sso_audit_'
          'log',
        );
      });
    });

    MockClient fixture(List<http.Request> requests, int postStatus) {
      return MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'status': 'pending',
              'client_name': 'Accounting terminal',
              'scopes': ['openid', 'payments:write'],
            }),
            200,
          );
        }
        return http.Response('{}', postStatus);
      });
    }

    Future<void> pumpDeviceScreen(
      WidgetTester tester,
      DeviceVerifyApi api,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: DeviceVerifyScreen(
            api: api,
            accessTokenProvider: () => 'user-token',
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'WXYZ-1234');
      await tester.tap(find.text('Check code'));
      await tester.pumpAndSettle();
      expect(find.text('Accounting terminal'), findsOneWidget);
    }

    Finder dialogConfirm(String label) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, label),
    );

    void expectRingUntouched() {
      expect(
        LocalStorage.getItem(
          'sso_audit_'
          'log',
        ),
        isNull,
      );
      expect(AuditLogService().count, 0);
    }

    testWidgets('approve 200 completes with zero ring writes', (tester) async {
      final requests = <http.Request>[];
      final api = DeviceVerifyApi(httpClient: fixture(requests, 200));
      await pumpDeviceScreen(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();
      // Dialog confirm is a second 'Approve' FilledButton (dual-'Approve'
      // hazard): scope the tap to the dialog.
      await tester.tap(dialogConfirm('Approve'));
      await tester.pumpAndSettle();

      expect(
        find.text('Device approved. You can return to it now.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      expectRingUntouched();
      // Wire body: exactly {user_code, approve} — no client_id, no tenant
      // key (screen-level mirror of device_verify_api_test.dart:31-50).
      final post = requests.singleWhere(
        (r) => r.method == 'POST' && r.url.path == '/device/verify',
      );
      expect(jsonDecode(post.body), {
        'user_code': 'WXYZ-1234',
        'approve': true,
      });
      // A 200 decision never auto-redirects.
      expect(BrowserNavigation.currentUri.path, isNot('/login/'));
    });

    testWidgets('deny 200 completes with zero ring writes', (tester) async {
      final requests = <http.Request>[];
      final api = DeviceVerifyApi(httpClient: fixture(requests, 200));
      await pumpDeviceScreen(tester, api);

      // Screen deny is an OutlinedButton; the dialog confirm is a
      // FilledButton (find.text('Deny') would match both when open).
      await tester.tap(find.widgetWithText(OutlinedButton, 'Deny'));
      await tester.pumpAndSettle();
      await tester.tap(dialogConfirm('Deny'));
      await tester.pumpAndSettle();

      expect(find.text('Device sign-in was denied.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expectRingUntouched();
      final post = requests.singleWhere(
        (r) => r.method == 'POST' && r.url.path == '/device/verify',
      );
      expect(jsonDecode(post.body), {
        'user_code': 'WXYZ-1234',
        'approve': false,
      });
      expect(BrowserNavigation.currentUri.path, isNot('/login/'));
    });

    testWidgets('401 expiry clears the session and never auto-redirects', (
      tester,
    ) async {
      final requests = <http.Request>[];
      final api = DeviceVerifyApi(httpClient: fixture(requests, 401));
      await pumpDeviceScreen(tester, api);

      await tester.tap(find.widgetWithText(FilledButton, 'Approve'));
      await tester.pumpAndSettle();
      await tester.tap(dialogConfirm('Approve'));
      await tester.pumpAndSettle();

      expect(
        find.text('Your sign-in expired. Please sign in again.'),
        findsOneWidget,
      );
      // signInAgain button — the only 'Sign in' text on the 401 view.
      expect(find.text('Sign in'), findsOneWidget);
      expect(Session.read(), isNull);
      // The 401 branch must NOT invoke _redirectToLogin: only the explicit
      // 'Sign in' button redirects (B6-2 pins the no-session entry leg).
      expect(BrowserNavigation.currentUri.path, isNot('/login/'));
      expect(tester.takeException(), isNull);
      expectRingUntouched();
      final post = requests.singleWhere(
        (r) => r.method == 'POST' && r.url.path == '/device/verify',
      );
      expect(jsonDecode(post.body), {
        'user_code': 'WXYZ-1234',
        'approve': true,
      });
    });
  });
}

Future<void> _useNarrowViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 480);
  addTearDown(tester.view.reset);
}

FilledButton _filledButton(WidgetTester tester, String label) {
  return tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
}
