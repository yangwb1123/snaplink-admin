import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/app_router.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/screens/portal/portal_screen.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'package:sso_admin/services/app_navigator.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';


/// 登录表单输入框：登录头下拉（DropdownMenu 内部也是 TextField）使按类型
/// 索引不稳定，用 autofillHints 定位。
Finder usernameField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.autofillHints?.contains(AutofillHints.username) ?? false),
);

Finder passwordField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.autofillHints?.contains(AutofillHints.password) ?? false),
);

void main() {
  tearDown(Session.clear);

  test(
    'native session storage remains process-only but supports route changes',
    () {
      Session.clear();
      expect(Session.read(), isNull);

      Session.store(
        'access-token',
        sessionId: 'session-1',
        clientId: 'client-1',
      );
      expect(Session.read(), 'access-token');
      expect(Session.readSessionId(), 'session-1');
      expect(Session.readClientId(), 'client-1');

      expect(Session.store(''), isFalse);
      expect(Session.read(), isNull);

      Session.clear();
      expect(Session.read(), isNull);
    },
  );

  test('native navigation refuses external checkout URLs', () {
    final before = BrowserNavigation.currentUri;
    expect(
      BrowserNavigation.assignExternalLocation(
        Uri.parse('https://checkout.stripe.com/c/pay/cs_one'),
      ),
      isFalse,
    );
    expect(BrowserNavigation.currentUri, before);
  });

  testWidgets('native portal entry routes through the in-app login', (
    tester,
  ) async {
    Session.clear();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        onGenerateRoute: buildProductRoute,
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => BrowserNavigation.replaceLocation('/portal/'),
            child: const Text('Open portal'),
          ),
        ),
      ),
    );

    expect(AppNavigator.key.currentState, isNotNull);
    await tester.tap(find.text('Open portal'));
    await tester.pumpAndSettle();

    expect(find.byType(PortalScreen), findsNothing);
    final login = tester.widget<OidcLoginScreen>(find.byType(OidcLoginScreen));
    expect(login.routeUri?.path, '/login/');
    expect(login.routeUri?.queryParameters['redirect'], '/portal/');
  });

  testWidgets('native login exposes server settings before authentication', (
    tester,
  ) async {
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response('{"providers":[]}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          defaultClientId: 'native-client',
          api: api,
          routeUri: Uri.parse('https://native.invalid/login/'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byTooltip('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('native password login stores the session and enters the app', (
    tester,
  ) async {
    Session.clear();
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['credential'] != null) {
            return http.Response(
              '{"access_token":"native-access","session_id":"sid-1"}',
              200,
            );
          }
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text('Destination: ${settings.name}'),
        ),
        home: OidcLoginScreen(
          defaultClientId: 'native-client',
          api: api,
          routeUri: Uri(
            path: '/login/',
            queryParameters: {'redirect': '/portal/security?from=native'},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    await tester.enterText(usernameField(), 'native-admin');
    await tester.enterText(passwordField(), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Destination: /portal/security?from=native'),
      findsOneWidget,
    );
    expect(Session.read(), 'native-access');
    expect(Session.readSessionId(), 'sid-1');
  });

  testWidgets('changing server before login discards the old credential form', (
    tester,
  ) async {
    final originalOrigin = AppSettings.instance.ssoBaseUrlOverride;
    AppSettings.instance.ssoBaseUrlOverride = null;
    addTearDown(() {
      AppSettings.instance.ssoBaseUrlOverride = originalOrigin;
    });
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text('Destination: ${settings.name}'),
        ),
        home: OidcLoginScreen(
          defaultClientId: 'native-client',
          api: api,
          routeUri: Uri.parse('/login/'),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    await tester.enterText(usernameField(), 'old-user');
    await tester.enterText(passwordField(), 'old-password');

    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byType(TextFormField),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.byType(TextFormField),
      'https://new-sso.example.test',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Destination: /login/'), findsOneWidget);
    expect(find.text('old-password'), findsNothing);
  });
}
