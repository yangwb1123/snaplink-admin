import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/i18n/localized_text.dart';

void main() {
  testWidgets('LocalizedText renders static and interpolated Chinese copy', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        supportedLocales: AppSettings.supportedLocales,
        localizationsDelegates: [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: Column(
            children: [
              LocalizedText('Change approvals'),
              LocalizedText('Page 3 · 12 users'),
            ],
          ),
        ),
      ),
    );

    expect(find.text('变更审批'), findsOneWidget);
    expect(find.text('第 3 页 · 共 12 个用户'), findsOneWidget);
  });

  test('localized property follows application settings', () {
    final original = AppSettings.instance.locale;
    addTearDown(() => AppSettings.instance.locale = original);
    AppSettings.instance.locale = const Locale('zh');

    expect('Client ID filter'.localized, '客户端 ID 筛选');
  });
}
