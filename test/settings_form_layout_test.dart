import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'package:sso_admin/widgets/language_selector.dart';

/// 设置页 form 化布局：行内 form item（彩色图标 + 标签 + 控件 + 分隔线），
/// 导航模式使用 Switch。
void main() {
  late AdminNavMode originalMode;
  late Locale originalLocale;

  setUp(() {
    originalMode = AppSettings.instance.adminNavMode;
    originalLocale = AppSettings.instance.locale;
    AppSettings.instance.adminNavMode = AdminNavMode.normal;
    AppSettings.instance.locale = const Locale('en');
  });

  tearDown(() {
    AppSettings.instance.adminNavMode = originalMode;
    AppSettings.instance.locale = originalLocale;
  });

  Future<void> pumpSettings(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();
  }

  testWidgets('settings render as grouped form rows, not one card per item', (
    tester,
  ) async {
    await pumpSettings(tester);

    // 两个分组卡片（偏好 / 服务），而不是每项一张卡。
    expect(find.byType(Card), findsNWidgets(2));
    // 每组内行数：偏好 3（语言/主题/导航模式）+ 服务 2（服务器/时区）。
    final dividers = find.byType(Divider);
    expect(dividers, findsNWidgets(3), reason: 'rows separated by dividers');
    // 行内彩色图标存在。
    for (final icon in [
      Icons.translate,
      Icons.palette_outlined,
      Icons.view_sidebar_outlined,
      Icons.dns_outlined,
      Icons.schedule_outlined,
    ]) {
      final icons = tester.widgetList<Icon>(find.byIcon(icon));
      expect(icons, isNotEmpty, reason: '$icon must render');
      for (final iconWidget in icons) {
        expect(iconWidget.color, isNotNull, reason: '$icon must be colored');
      }
    }
  });

  testWidgets('language and theme rows sit inline with their labels', (
    tester,
  ) async {
    await pumpSettings(tester);

    // 语言行：标签与 LanguageDropdown 垂直居中对齐（同一行）。
    final label = tester.getCenter(find.text('Language'));
    final dropdown = tester.getCenter(find.byType(LanguageDropdown));
    expect((label.dy - dropdown.dy).abs(), lessThan(40),
        reason: 'label and control share one row');
  });

  testWidgets('admin nav mode toggles with a switch', (tester) async {
    await pumpSettings(tester);

    final toggle = find.byType(Switch);
    expect(toggle, findsOneWidget);
    expect(tester.widget<Switch>(toggle).value, isFalse,
        reason: 'default mode is normal');

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.adminNavMode, AdminNavMode.professional);
    expect(tester.widget<Switch>(toggle).value, isTrue);

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(AppSettings.instance.adminNavMode, AdminNavMode.normal);
  });
}
