@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/main.dart';
import 'package:sso_admin/screens/oidc_login/login_view_widget.dart';
import 'package:sso_admin/services/browser_navigation.dart';

import 'app_sso_test_support.dart';

void main() {
  testWidgets('real app EN/ZH and theme rebuilds retain one pending request', (
    tester,
  ) async {
    final settings = AppSettings.instance;
    final originalLocale = settings.locale;
    final originalTheme = settings.themeMode;
    addTearDown(() {
      settings.locale = originalLocale;
      settings.themeMode = originalTheme;
    });
    settings.locale = const Locale('en');
    settings.themeMode = ThemeMode.light;
    final discovery = Completer<http.Response>();
    final requests = <Map<String, dynamic>>[];
    await withAppSsoHarness(
      tester,
      (request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        requests.add(jsonDecode(request.body) as Map<String, dynamic>);
        return discovery.future;
      },
      (harness) async {
        // Do not reparent the fixture Navigator's GlobalKey into the real app:
        // that would retain its existing home Route rather than run app startup.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpWidget(SSOConsoleApp(oidcLoginApi: harness.api));
        await tester.pump();
        final state = tester.state(appSsoLogin());
        final identity = BrowserNavigation.requestIdentity;
        expect(requests, [
          {'client_id': SSOAdminClient.firstPartyClientId},
        ]);
        expect(find.byType(LoginViewWidget), findsNothing);
        expect(appSsoPassword(), findsNothing);
        settings.themeMode = ThemeMode.dark;
        // Use the real hosted selector callback, which updates its text
        // controller before broadcasting the locale change.
        tester
            .widget<DropdownMenu<Locale>>(find.byType(DropdownMenu<Locale>))
            .onSelected!(const Locale('zh'));
        await tester.pump();
        expect(identical(state, tester.state(appSsoLogin())), isTrue);
        expect(requests, hasLength(1));
        expect(find.byType(LoginViewWidget), findsNothing);
        expect(appSsoPassword(), findsNothing);

        discovery.complete(appSsoResponse(appSsoResumable));
        await tester.pumpAndSettle();
        // A direct first-party entry stays direct even if discovery advertises
        // an OP cookie. It must not invent a passwordless authorization grant.
        expect(requests, hasLength(1));
        expect(appSsoPassword(), findsOneWidget);
        final context = tester.element(appSsoLogin());
        expect(Localizations.localeOf(context).languageCode, 'zh');
        expect(Theme.of(context).brightness, Brightness.dark);
        expect(find.text(AppStrings.of(context).password), findsOneWidget);
        await tester.enterText(appSsoUsername(), 'fixture-user');
        await tester.enterText(appSsoPassword(), 'fixture-password');
        final originalController = tester
            .widget<TextField>(appSsoPassword())
            .controller;
        tester
            .widget<DropdownMenu<Locale>>(find.byType(DropdownMenu<Locale>))
            .onSelected!(const Locale('en'));
        settings.themeMode = ThemeMode.light;
        // Scrubbing the same-document location is not a new authorization.
        BrowserNavigation.replaceState('/login/');
        expect(BrowserNavigation.requestIdentity, same(identity));
        await tester.pumpAndSettle();
        expect(identical(state, tester.state(appSsoLogin())), isTrue);
        expect(
          tester.widget<TextField>(appSsoPassword()).controller,
          same(originalController),
        );
        expect(originalController!.text, 'fixture-password');
        expect(
          tester.widget<TextField>(appSsoUsername()).controller!.text,
          'fixture-user',
        );
        expect(requests, hasLength(1));
        expect(
          Localizations.localeOf(tester.element(appSsoLogin())).languageCode,
          'en',
        );
      },
    );
  });
}
