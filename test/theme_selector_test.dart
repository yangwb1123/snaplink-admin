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

  // F1：紧凑变体箭头在收起/展开两态下均 20×20、垂直居中于字段、右缘
  // 贴齐（间隙一致）。
  testWidgets('compact trailing arrow is centered in collapsed and open states', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const ThemeDropdown(compact: true)));
    await tester.pumpAndSettle();

    final field = tester.getRect(find.byType(DropdownMenu<ThemeMode>));
    void checkArrow(IconData data) {
      final rect = tester.getRect(
        find.descendant(
          of: find.byType(InputDecorator),
          matching: find.byIcon(data),
        ),
      );
      expect(rect.size, const Size(20, 20),
          reason: 'arrow must keep the 20x20 icon region');
      expect(rect.center.dy, closeTo(field.center.dy, 1.5),
          reason: 'arrow must be vertically centered in the field');
      expect(field.right - rect.right, closeTo(0, 0.5),
          reason: 'arrow gap from the right edge must be consistent');
    }

    checkArrow(Icons.arrow_drop_down);
    await tester.tap(find.byType(DropdownMenu<ThemeMode>));
    await tester.pumpAndSettle();
    checkArrow(Icons.arrow_drop_up);
  });
}
