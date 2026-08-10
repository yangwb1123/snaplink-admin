import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/widgets/theme_selector.dart';

void main() {
  tearDown(() {
    AppSettings.instance.themeMode = ThemeMode.system;
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  Finder menuItem(String label) => find.descendant(
    of: find.byType(MenuItemButton).hitTestable(),
    matching: find.text(label),
  );

  testWidgets('theme menu opens BELOW the control', (tester) async {
    tester.view.physicalSize = const Size(600, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: ThemeDropdown(compact: true),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();

    final control = tester.getRect(find.byType(DropdownMenu<ThemeMode>));
    final item = tester.getRect(menuItem('System'));
    expect(item.top, greaterThanOrEqualTo(control.bottom - 1),
        reason: 'theme menu must open below the control');
  });

  testWidgets('selecting a theme updates AppSettings and checks the item', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ThemeDropdown()));
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();

    // 当前主题（system）带勾选。
    expect(
      find.descendant(
        of: find.byType(MenuItemButton).hitTestable(),
        matching: find.byIcon(Icons.check),
      ),
      findsOneWidget,
    );
    await tester.tap(menuItem('Dark'));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.themeMode, ThemeMode.dark);
  });

  testWidgets('theme items carry colored leading icons', (tester) async {
    await tester.pumpWidget(wrap(const ThemeDropdown()));
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();

    // 每个菜单项都有图标（彩色由 Icon.color 提供，此处验证存在且着色）。
    for (final icon in [Icons.brightness_auto, Icons.light_mode, Icons.dark_mode]) {
      final icons = tester.widgetList<Icon>(
        find.descendant(
          of: find.byType(MenuItemButton).hitTestable(),
          matching: find.byIcon(icon),
        ),
      );
      expect(icons, isNotEmpty, reason: '$icon must render in the menu');
      for (final iconWidget in icons) {
        expect(iconWidget.color, isNotNull, reason: '$icon must be colored');
      }
    }
  });
}
