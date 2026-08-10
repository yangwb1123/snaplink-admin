import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/widgets/language_selector.dart';
import 'package:sso_admin/widgets/theme_selector.dart';

/// 登录头布局：主题选择靠左、语言选择靠右，宽度贴合文字；窄屏自动换行
/// 不溢出。另含审计修复的回归测试：键盘焦点可见（F1）、emoji 语义
/// 标签（F2，见 language_selector_test）、触摸目标 ≥44px（F3）、间距
/// token 门禁（F4）、加载中禁用（F6）。
void main() {

  Future<void> pumpLogin(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final api = OidcLoginApi(
      httpClient: MockClient((request) async => http.Response('{}', 404)),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse('https://console.example/login/'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('theme sits left of language, both size to their text', (
    tester,
  ) async {
    // Ahem 测试字体等宽（西文 12px/字符）下并排宽度比生产 Roboto 大约
    // 一倍；单行并排由 Wrap 在 Ahem 下换行兜底（生产桌面端单行），这里
    // 断言布局层级（主题先出现且更靠左）、宽度贴合文字与零溢出。
    await pumpLogin(tester, const Size(1200, 800));

    final theme = tester.getRect(find.byType(ThemeDropdown));
    final language = tester.getRect(find.byType(LanguageDropdown));
    final card = tester.getRect(find.byType(Card).first);

    // 主题先于语言（同一行时在其左侧；Ahem 换行时在其上方），两者都在
    // 卡片内且不溢出。
    expect(theme.top, lessThanOrEqualTo(language.top),
        reason: 'theme selector must come before the language selector');
    expect(theme.left, lessThanOrEqualTo(language.left),
        reason: 'theme selector must be left-aligned before language');
    expect(card.contains(theme.center), isTrue);
    expect(card.contains(language.center), isTrue);
    expect(tester.takeException(), isNull, reason: 'no layout overflow');

    // 宽度贴合文字（非固定宽）：'English'/'System' + 图标 + 菜单 chrome，
    // 远小于卡片宽度的一半。
    expect(theme.width, lessThan(card.width / 2));
    expect(language.width, lessThan(card.width / 2));
    expect(theme.width, greaterThan(120), reason: 'still sized to content');
  });

  testWidgets('narrow viewport wraps the header without overflow', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(400, 800));
    expect(tester.takeException(), isNull,
        reason: 'narrow header must wrap, not overflow');
    expect(find.byType(ThemeDropdown), findsOneWidget);
    expect(find.byType(LanguageDropdown), findsOneWidget);
  });

  // F3：紧凑下拉触摸目标（InputDecorator 容器高度）达到最小交互尺寸。
  testWidgets('compact header dropdowns meet the 44px minimum touch target', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(1200, 800));

    final theme = tester.getRect(find.byType(DropdownMenu<ThemeMode>));
    final language = tester.getRect(find.byType(DropdownMenu<Locale>));
    expect(theme.height, greaterThanOrEqualTo(44),
        reason: 'theme selector tap target must meet Apple HIG 44px');
    expect(language.height, greaterThanOrEqualTo(44),
        reason: 'language selector tap target must meet Apple HIG 44px');
  });

  // F1：键盘 Tab 到达下拉后，悬停容器出现焦点底色，输入装饰绘制 primary
  // 圆角描边（WCAG 2.4.7 Focus Visible）。
  testWidgets('keyboard focus on the selectors is visibly indicated', (
    tester,
  ) async {
    await pumpLogin(tester, const Size(1200, 800));

    final themeDropdown = find.byType(DropdownMenu<ThemeMode>);
    final dropdownContext = tester.element(themeDropdown);
    var tabs = 0;
    while (!Focus.of(dropdownContext).hasFocus && tabs < 40) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      tabs++;
    }
    expect(Focus.of(dropdownContext).hasFocus, isTrue,
        reason: 'Tab traversal must reach the compact theme dropdown');

    // _HoverTint 焦点底色：悬停容器不再是透明背景。
    final tint = tester.widget<AnimatedContainer>(
      find
          .ancestor(
            of: find.byType(ThemeDropdown),
            matching: find.byType(AnimatedContainer),
          )
          .first,
    );
    expect((tint.decoration as BoxDecoration?)?.color, isNot(Colors.transparent),
        reason: 'focus must tint the hover container background');

    // 输入装饰：聚焦态配置 primary 描边（非透明、宽度 1.5）。
    final decorator = tester.widget<InputDecorator>(
      find
          .descendant(of: themeDropdown, matching: find.byType(InputDecorator))
          .first,
    );
    expect(decorator.decoration.enabledBorder, same(InputBorder.none),
        reason: 'unfocused state stays borderless');
    final focused = decorator.decoration.focusedBorder as OutlineInputBorder;
    expect(focused.borderSide.color, Theme.of(dropdownContext).colorScheme.primary,
        reason: 'focused border must use the theme primary color');
    expect(focused.borderSide.width, 1.5);
  });

  // F6：OIDC 请求进行中（_loading）时，两个下拉与设置按钮一起禁用；
  // 请求结束后恢复可交互。
  testWidgets('selectors are disabled while an OIDC request is in flight', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final pending = Completer<http.Response>();
    final api = OidcLoginApi(
      httpClient: MockClient((request) {
        if (request.method == 'POST' &&
            request.url.path.endsWith('/auth/login')) {
          return pending.future;
        }
        return Future.value(http.Response('{}', 404));
      }),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse('https://console.example/login/'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<DropdownMenu<ThemeMode>>(find.byType(DropdownMenu<ThemeMode>))
          .enabled,
      isTrue,
      reason: 'selectors start enabled',
    );

    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), 'secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pump();

    expect(
      tester
          .widget<DropdownMenu<ThemeMode>>(find.byType(DropdownMenu<ThemeMode>))
          .enabled,
      isFalse,
      reason: 'theme selector disabled while loading',
    );
    expect(
      tester
          .widget<DropdownMenu<Locale>>(find.byType(DropdownMenu<Locale>))
          .enabled,
      isFalse,
      reason: 'language selector disabled while loading',
    );

    // 请求结束后恢复。
    pending.complete(http.Response('{}', 404));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<DropdownMenu<ThemeMode>>(find.byType(DropdownMenu<ThemeMode>))
          .enabled,
      isTrue,
      reason: 'selectors re-enable after the request settles',
    );
  });

  // F4：登录头相关源文件的间距字面量必须落在 4/8/12/16/20/24/32/40/
  // 48/64 token 集合内（镜像 i18n_coverage_test 的门禁模式）。
  test('header sources use only spacing tokens from the 4-64 set', () {
    const tokens = {4, 8, 12, 16, 20, 24, 32, 40, 48, 64};
    const files = [
      'lib/widgets/select_style.dart',
      'lib/widgets/language_selector.dart',
      'lib/widgets/theme_selector.dart',
      'lib/screens/oidc_login/oidc_login_view_flow.dart',
    ];
    final violations = <String>[];
    final number = RegExp(r'\d+(?:\.\d+)');

    void checkLine(String path, String source, int offset, String literal) {
      final line = source.substring(0, offset).split('\n').length;
      for (final match in number.allMatches(literal)) {
        final value = double.parse(match.group(0)!);
        if (value != 0 && !tokens.contains(value)) {
          violations.add('$path:$line: $literal');
        }
      }
    }

    for (final path in files) {
      final source = File(path).readAsStringSync();
      for (final match
          in RegExp(r'EdgeInsets\.symmetric\([^)]*\)').allMatches(source)) {
        checkLine(path, source, match.start, match.group(0)!);
      }
      for (final pattern in [
        RegExp(r'SizedBox\(width:\s*(\d+)\)'),
        RegExp(r'SizedBox\(height:\s*(\d+)\)'),
        RegExp(r'leadingWidth:\s*(\d+)'),
      ]) {
        for (final match in pattern.allMatches(source)) {
          final value = int.parse(match.group(1)!);
          if (!tokens.contains(value)) {
            checkLine(path, source, match.start, match.group(0)!);
          }
        }
      }
    }
    expect(violations, isEmpty,
        reason: 'non-token spacing in header sources:\n'
            '${violations.join('\n')}');
  });

  // 下拉箭头：显式尺寸与 suffix 约束一致（默认 24px 在紧凑 18px 约束下
  // 会被压到不可见），IconButton 约束保证垂直居中。
  testWidgets('dropdown arrows match their constraints and center', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              ThemeDropdown(compact: true),
              SizedBox(height: 24),
              LanguageDropdown(compact: true),
              SizedBox(height: 24),
              LanguageDropdown(), // form 模式（设置页）
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final size in [18.0, 18.0, 20.0]) {
      final arrows = tester
          .widgetList<Icon>(find.byIcon(Icons.arrow_drop_down))
          .where((icon) => icon.size == size);
      expect(arrows, isNotEmpty, reason: 'arrow size $size must be present');
    }
    // compact 的 suffix 区域被约束为 18x18（垂直居中由 InputDecorator 保证）。
    final compactIconButton = tester.widget<IconButton>(
      find
          .descendant(
            of: find.byType(ThemeDropdown),
            matching: find.byType(IconButton),
          )
          .first,
    );
    expect(
      compactIconButton.constraints,
      const BoxConstraints.tightFor(width: 18, height: 18),
      reason: 'compact arrow must be pinned to an 18x18 centered region',
    );
  });

  // 菜单项内部对齐：国旗、语言名、勾选徽标的垂直中心一致；各菜单项的
  // 国旗起点一致（文字列对齐）。
  testWidgets('menu items align flag, label and check on one center line', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LanguageDropdown(compact: true))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<Locale>));
    await tester.pumpAndSettle();

    final flags = tester
        .renderObjectList<RenderBox>(find.text('🇬🇧').hitTestable())
        .toList();
    final labels = tester
        .renderObjectList<RenderBox>(find.text('English').hitTestable())
        .toList();
    final checks = tester
        .renderObjectList<RenderBox>(find.byIcon(Icons.check).hitTestable())
        .toList();
    expect(flags, isNotEmpty);
    expect(labels, isNotEmpty);
    expect(checks, isNotEmpty);

    // 排除输入框内的同名元素（菜单打开时仍 hitTestable），只比较菜单项。
    final fieldBottom =
        tester.getRect(find.byType(DropdownMenu<Locale>)).bottom;
    bool inMenu(RenderBox box) =>
        box.localToGlobal(Offset.zero).dy >= fieldBottom - 1;

    double centerY(RenderBox box) =>
        box.localToGlobal(Offset.zero).dy + box.size.height / 2;
    final menuFlags = flags.where(inMenu).toList();
    final menuLabels = labels.where(inMenu).toList();
    final menuChecks = checks.where(inMenu).toList();
    expect(menuFlags.length, menuLabels.length,
        reason: 'one flag per menu label');
    for (var i = 0; i < menuFlags.length; i++) {
      expect(centerY(menuFlags[i]), closeTo(centerY(menuLabels[i]), 1.5),
          reason: 'flag and label must share a center line');
      if (i < menuChecks.length) {
        expect(centerY(menuChecks[i]), closeTo(centerY(menuLabels[i]), 1.5),
            reason: 'check badge must share the center line');
      }
    }
    // 国旗起点一致 → 语言名左缘对齐。
    final flagLefts = menuFlags
        .map((b) => b.localToGlobal(Offset.zero).dx)
        .toSet();
    expect(flagLefts.length, 1, reason: 'all flags start at the same x');
  });

  // active 框占满菜单项内容区宽度；每个菜单项携带圆角 shape 的 style
  // （hover/focus 背景圆角由 MenuItemButton 的 style.shape 决定）。
  testWidgets('active highlight fills the item and entries carry rounded styles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LanguageDropdown(compact: true))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<Locale>));
    await tester.pumpAndSettle();

    final item = tester.renderObject<RenderBox>(
      find.byType(MenuItemButton).hitTestable().first,
    );
    final highlight = tester.renderObject<RenderBox>(
      find
          .byWidgetPredicate(
            (widget) =>
                widget is AnimatedContainer &&
                widget.decoration is BoxDecoration &&
                (widget.decoration as BoxDecoration).border != null,
          )
          .hitTestable()
          .first,
    );
    // 高亮撑满 labelWidget 可用区（菜单项宽度 - 左右 padding 12x2 - startGap 4）。
    expect(highlight.size.width, closeTo(item.size.width - 28, 1.5),
        reason: 'active highlight must span the full item content width');

    final menu = tester
        .widget<DropdownMenu<Locale>>(find.byType(DropdownMenu<Locale>));
    for (final entry in menu.dropdownMenuEntries) {
      final shape = entry.style?.shape?.resolve(<WidgetState>{});
      expect(shape, isA<RoundedRectangleBorder>(),
          reason: 'every entry must carry a rounded shape for hover/focus');
      final radius = (shape as RoundedRectangleBorder).borderRadius;
      expect(radius, const BorderRadius.all(Radius.circular(8)),
          reason: 'hover/focus background must be rounded like the active box');
    }
  });
}
