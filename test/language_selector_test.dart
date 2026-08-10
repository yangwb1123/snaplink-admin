import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/services/language_catalog.dart';
import 'package:sso_admin/widgets/language_selector.dart';

void main() {
  tearDown(() {
    // 恢复单例状态，避免测试间串扰。
    AppSettings.instance
      ..languageOptions = defaultLanguageOptions
      ..locale = const Locale('en');
  });

  Widget wrap(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  Future<void> openMenu(WidgetTester tester, Finder selector) async {
    await tester.tap(selector);
    await tester.pumpAndSettle();
  }

  /// 打开的菜单项（MenuItemButton 内的文本）。DropdownMenu 为宽度计算会
  /// 额外渲染一份菜单项副本（不可点击），因此必须限定 hitTestable。
  Finder menuItem(String label) => find.descendant(
    of: find.byType(MenuItemButton).hitTestable(),
    matching: find.text(label),
  );

  Finder menuCheckIcon() => find.descendant(
    of: find.byType(MenuItemButton).hitTestable(),
    matching: find.byIcon(Icons.check),
  );

  testWidgets(
    'compact selector (login header) opens the menu BELOW the control',
    (tester) async {
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
                child: SizedBox(width: 190, child: LanguageDropdown(compact: true)),
              ),
            ),
          ),
        ),
      );
      await openMenu(tester, find.byType(DropdownMenu<Locale>));

      final control = tester.getRect(find.byType(DropdownMenu<Locale>));
      final item = tester.getRect(menuItem('English'));
      // 菜单从控件下方展开（DropdownButton 在顶部控件上会向上弹）。
      expect(item.top, greaterThanOrEqualTo(control.bottom - 1),
          reason: 'compact menu must open below the header control');
      expect(item.left, greaterThanOrEqualTo(control.left - 1),
          reason: 'menu aligns with the control edge');
    },
  );

  testWidgets(
    'form selector (settings) opens the menu BELOW the control',
    (tester) async {
      tester.view.physicalSize = const Size(600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.center,
              child: SizedBox(width: 320, child: LanguageDropdown()),
            ),
          ),
        ),
      );
      await openMenu(tester, find.byType(DropdownMenu<Locale>));

      final control = tester.getRect(find.byType(DropdownMenu<Locale>));
      final item = tester.getRect(menuItem('English'));
      expect(item.top, greaterThanOrEqualTo(control.bottom - 1),
          reason: 'settings menu must open below the control');
    },
  );

  testWidgets('menu items come from the backend languages list', (
    tester,
  ) async {
    AppSettings.instance.languageOptions = const [Locale('en'), Locale('ja')];
    await tester.pumpWidget(wrap(const LanguageDropdown()));

    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    expect(menuItem('English'), findsOneWidget);
    expect(menuItem('日本語'), findsOneWidget);
    // 后端未公布的语言不出现在菜单里。
    expect(menuItem('中文'), findsNothing);
  });

  testWidgets('current locale absent from the backend list is appended', (
    tester,
  ) async {
    AppSettings.instance
      ..languageOptions = const [Locale('en'), Locale('zh')]
      ..locale = const Locale('ja');
    await tester.pumpWidget(wrap(const LanguageDropdown()));

    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    expect(menuItem('日本語'), findsOneWidget, reason: 'dropdown value safety');
    expect(menuItem('中文'), findsOneWidget);
  });

  testWidgets('selecting an entry updates the app locale and checks it', (
    tester,
  ) async {
    AppSettings.instance.languageOptions = const [Locale('en'), Locale('zh')];
    await tester.pumpWidget(wrap(const LanguageDropdown()));

    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    // 当前语言带勾选。
    expect(menuCheckIcon(), findsOneWidget);
    await tester.tap(menuItem('中文'));
    await tester.pumpAndSettle();

    expect(AppSettings.instance.locale.languageCode, 'zh');
    // 输入框文本跟随（EditableText 只匹配输入框，避开宽度测量副本）。
    final input = tester.widget<EditableText>(
      find.byType(EditableText).hitTestable().first,
    );
    expect(input.controller?.text, '中文');
  });

  testWidgets('default options render when no backend list was loaded', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const LanguageDropdown()));
    await openMenu(tester, find.byType(DropdownMenu<Locale>));
    expect(menuItem('English'), findsOneWidget);
    expect(menuItem('中文'), findsOneWidget);
  });
}
