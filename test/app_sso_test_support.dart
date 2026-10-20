import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/app_router.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/services/app_navigator.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/product_entry_route.dart';
import 'package:sso_admin/session.dart';

const appSsoProviders = <String, dynamic>{
  'providers': [
    {'id': 'password', 'type': 'builtin'},
  ],
};
const appSsoResumable = <String, dynamic>{
  ...appSsoProviders,
  'op_session_supported': true,
  'op_session_available': true,
};

http.Response appSsoResponse(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200);

String appSsoLocation(String client, {Map<String, dynamic> extra = const {}}) =>
    Uri(
      path: '/login/',
      queryParameters: {
        'client_id': client,
        'response_type': 'code',
        'redirect_uri': 'https://$client.example.invalid/callback',
        'scope': 'openid $client:read',
        'resource': ['$client-api', '$client-reports'],
        'state': '$client-state',
        'nonce': '$client-nonce',
        'code_challenge': client.padRight(43, 'x'),
        'code_challenge_method': 'S256',
        ...extra,
      },
    ).toString();

Finder appSsoLogin() => find.byType(OidcLoginScreen);
Finder appSsoUsername() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.autofillHints?.contains(AutofillHints.username) ?? false),
);
Finder appSsoPassword() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.autofillHints?.contains(AutofillHints.password) ?? false),
);

class AppSsoHarness {
  AppSsoHarness(Future<http.Response> Function(http.Request) handle)
    : api = OidcLoginApi(
        baseUri: Uri.parse('https://op.example.invalid/login/'),
        httpClient: MockClient(handle),
      );

  final OidcLoginApi api;

  Future<void> navigate(WidgetTester tester, String target) async {
    BrowserNavigation.replaceLocation(target);
    // Flush the native post-frame replacement and MaterialPageRoute transition.
    // Do not pumpAndSettle: discovery or a mutation may deliberately be pending.
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 250));
  }

  Future<void> submitPassword(WidgetTester tester) async {
    await tester.enterText(appSsoUsername(), 'fixture-user');
    await tester.enterText(appSsoPassword(), 'fixture-password');
    final button = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }
}

/// Exercise the native production navigation/resolver shape, substituting only
/// the resolver's existing API seam. Non-login destinations stop at the handoff
/// boundary; this fixture never starts an Admin/API session or external browser.
Future<void> withAppSsoHarness(
  WidgetTester tester,
  Future<http.Response> Function(http.Request) handle,
  Future<void> Function(AppSsoHarness harness) body,
) async {
  final previousError = FlutterError.onError;
  final previousPresentation = FlutterError.presentError;
  final harness = AppSsoHarness(handle);
  BrowserNavigation.resetForTest();
  Session.clear();
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  // The entry ErrorBoundary owns a global onError hook. Forward presentation to
  // the test binding so unexpected framework exceptions remain test failures,
  // and restore both hooks even if an assertion fails or routes overlap.
  FlutterError.presentError = previousError ?? previousPresentation;
  try {
    await tester.runAsync(() => preloadProductEntry(ProductEntry.login));
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) {
            final location = Uri.parse(settings.name!);
            return location.path == '/login/'
                ? resolveProductScreen(location, oidcLoginApi: harness.api)
                : const Scaffold(body: Text('Local handoff destination'));
          },
        ),
        home: const Scaffold(body: Text('Native navigation fixture')),
      ),
    );
    await body(harness);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    FlutterError.onError = previousError;
    FlutterError.presentError = previousPresentation;
    harness.api.close();
    tester.view.reset();
    BrowserNavigation.resetForTest();
    Session.clear();
  }
}
