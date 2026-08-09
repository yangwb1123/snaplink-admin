import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';

/// WS5：一致性修复清单。
///
/// 覆盖：WS5#1 设置页卡片 description 仅渲染一次（修复前 finds 2）；
/// WS5#3 zh locale 下 CopyableCell tooltip message == '点击复制'；
/// WS5#4 AdminListHeader 窄视口换行（wrap 后两行）。
void main() {
  late Locale originalLocale;

  setUp(() {
    originalLocale = AppSettings.instance.locale;
    AppSettings.instance.locale = const Locale('en');
  });

  tearDown(() {
    AppSettings.instance.locale = originalLocale;
  });

  testWidgets('WS5#1: settings theme card description renders exactly once', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(
      find.text('Appearance follows the system or your explicit choice.'),
      findsOneWidget,
    );
  });

  testWidgets('WS5#3: copyable cell tooltip resolves zh copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        supportedLocales: AppSettings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: CopyableCell(
                text: 'client-1',
                contextProvider: () => context,
              ),
            ),
          ),
        ),
      ),
    );

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, '点击复制');
  });

  testWidgets('WS5#4: AdminListHeader wraps below 560px', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(400, 600);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminListHeader(
            title: 'Clients',
            createTooltip: 'Create client',
            onCreate: _noop,
            onRefresh: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    // 窄视口：标题与操作按钮分两行。
    final titleY = tester.getCenter(find.text('Clients')).dy;
    final buttonY = tester.getCenter(find.byType(FilledButton)).dy;
    expect(buttonY, greaterThan(titleY + 20));
  });

  testWidgets('WS5#4: AdminListHeader keeps a single row at 800px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.view.physicalSize = const Size(800, 600);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AdminListHeader(
            title: 'Clients',
            createTooltip: 'Create client',
            onCreate: _noop,
            onRefresh: _noop,
          ),
        ),
      ),
    );
    await tester.pump();

    final titleY = tester.getCenter(find.text('Clients')).dy;
    final buttonY = tester.getCenter(find.byType(FilledButton)).dy;
    expect((buttonY - titleY).abs(), lessThan(20));
  });
}

void _noop() {}
