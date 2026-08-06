import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'package:sso_admin/services/app_navigator.dart';
import 'package:sso_admin/services/product_api_origin.dart';
import 'package:sso_admin/session.dart';

void main() {
  late String? originalOverride;
  late Locale originalLocale;

  setUp(() {
    originalOverride = AppSettings.instance.ssoBaseUrlOverride;
    originalLocale = AppSettings.instance.locale;
    AppSettings.instance.locale = const Locale('en');
    AppSettings.instance.ssoBaseUrlOverride = null;
    Session.clear();
  });

  tearDown(() {
    AppSettings.instance.ssoBaseUrlOverride = originalOverride;
    AppSettings.instance.locale = originalLocale;
    Session.clear();
  });

  testWidgets('rejects an unsafe native server URL without saving it', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.enterText(
      find.byType(TextFormField),
      'http://credentials.example.test/api?tenant=one',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(
      find.textContaining('Enter an absolute HTTPS server URL'),
      findsOneWidget,
    );
    expect(AppSettings.instance.ssoBaseUrlOverride, isNull);
    expect(find.text('Saved'), findsNothing);
  });

  testWidgets('normalizes and saves a valid native server origin', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.enterText(
      find.byType(TextFormField),
      ' HTTPS://SSO.Example.test:8443/ ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(
      AppSettings.instance.ssoBaseUrlOverride,
      'https://sso.example.test:8443',
    );
    expect(
      tester.widget<TextFormField>(find.byType(TextFormField)).controller?.text,
      'https://sso.example.test:8443',
    );
    expect(find.text('Saved'), findsOneWidget);
  });

  testWidgets('changing origin discards an authenticated native session', (
    tester,
  ) async {
    Session.store('access-token', sessionId: 'session-1');
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        onGenerateRoute: (settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => Text('Destination: ${settings.name}'),
        ),
        home: const SettingsScreen(),
      ),
    );

    await tester.enterText(
      find.byType(TextFormField),
      'https://new-sso.example.test',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(Session.read(), isNull);
    expect(Session.readSessionId(), isNull);
    expect(find.text('Destination: /login/'), findsOneWidget);
    expect(find.byType(SettingsScreen), findsNothing);
  });

  testWidgets('an equivalent effective origin keeps the current session', (
    tester,
  ) async {
    Session.store('access-token', sessionId: 'session-1');
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));

    await tester.enterText(
      find.byType(TextFormField),
      ProductApiOrigin.nativeDefaultBaseUrl,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pump();

    expect(Session.read(), 'access-token');
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
  });
}
