@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/app_router.dart';
import 'package:sso_admin/main.dart';
import 'package:sso_admin/services/product_entry_route.dart';

void main() {
  testWidgets('theme labels follow the login language selector', (
    tester,
  ) async {
    final originalLocale = AppSettings.instance.locale;
    addTearDown(() => AppSettings.instance.locale = originalLocale);
    AppSettings.instance.locale = const Locale('en');
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
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
    await tester.runAsync(() => preloadProductEntry(ProductEntry.login));

    await tester.pumpWidget(SSOConsoleApp(oidcLoginApi: api));
    await tester.pump();
    await tester.pump();

    final language = find.byType(DropdownMenu<Locale>);
    expect(language, findsOneWidget);
    await tester.tap(language);
    await tester.pump();
    await tester.pump();
    final chinese = find.descendant(
      of: find.byType(MenuItemButton).hitTestable(),
      matching: find.text('中文'),
    );
    expect(chinese, findsOneWidget);
    await tester.tap(chinese);
    await tester.pump();
    await tester.pump();

    final theme = find.byType(DropdownMenu<ThemeMode>);
    expect(theme, findsOneWidget);
    final themeInput = find.descendant(
      of: theme,
      matching: find.byType(EditableText),
    );
    expect(themeInput, findsOneWidget);
    expect(tester.widget<EditableText>(themeInput).controller.text, '跟随系统');
    await tester.tap(theme);
    await tester.pump();
    await tester.pump();
    expect(find.text('跟随系统'), findsWidgets);
    expect(find.text('浅色'), findsWidgets);
    expect(find.text('深色'), findsWidgets);
    expect(find.text('System'), findsNothing);
  });
}
