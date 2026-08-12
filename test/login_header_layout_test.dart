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

  // 下拉箭头（审计 F1 修复后）：普通 Icon 直装 suffix 槽——每个下拉字段
  // 内的箭头都是 20×20、垂直居中于字段、右缘贴齐字段（间隙一致）。
  testWidgets('dropdown arrows render 20x20 and center on the field axis', (
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

    final dropdowns =
        find.byWidgetPredicate((widget) => widget is DropdownMenu<dynamic>);
    expect(dropdowns, findsNWidgets(3));
    for (final element in dropdowns.evaluate()) {
      final field = tester.getRect(find.byWidget(element.widget));
      final decorator = find.descendant(
        of: find.byWidget(element.widget),
        matching: find.byType(InputDecorator),
      );
      expect(decorator, findsOneWidget,
          reason: 'one input decorator per dropdown');
      // suffix 区域仍是 20x20（与 prefix 一致，两个变体同一视觉）。
      final decoration = tester.widget<InputDecorator>(decorator).decoration;
      expect(
        decoration.suffixIconConstraints,
        const BoxConstraints.tightFor(width: 20, height: 20),
        reason: 'arrow must be pinned to a 20x20 centered region',
      );
      final arrow = find.descendant(
        of: decorator,
        matching: find.byIcon(Icons.arrow_drop_down),
      );
      expect(arrow, findsOneWidget, reason: 'one field arrow per dropdown');
      final arrowRect = tester.getRect(arrow);
      expect(arrowRect.size, const Size(20, 20),
          reason: 'arrow must render at its 20x20 icon region');
      expect(arrowRect.center.dy, closeTo(field.center.dy, 1.5),
          reason: 'arrow must be vertically centered in the field');
      expect(field.right - arrowRect.right, closeTo(0, 0.5),
          reason: 'arrow gap from the right edge must be consistent');
    }
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

  // 选中背景（primaryContainer，ButtonStyle.backgroundColor 经
  // WidgetState.focused 注入）与 2px 选中边框（ButtonStyle.side）都画在
  // MenuItemButton 的 Material 上：背景盒/边框盒与条目同框，横贯整个菜单项
  // 宽度、与 select item 对齐（审计 select-bg F1 修复，不再内缩 28px）；
  // 未选中项背景透明。每个菜单项携带圆角 shape 的 style（hover/focus
  // 背景圆角由 MenuItemButton 的 style.shape 决定）。
  testWidgets('selected background spans the item and entries carry rounded styles', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: LanguageDropdown(compact: true))),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownMenu<Locale>));
    await tester.pumpAndSettle();

    final buttons = find.byType(MenuItemButton).hitTestable();
    final item = tester.renderObject<RenderBox>(buttons.first);
    final theme = Theme.of(tester.element(find.byType(LanguageDropdown)));
    final primary = theme.colorScheme.primary;
    final selectedFinder = find.descendant(
      of: buttons,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Material &&
            widget.shape is RoundedRectangleBorder &&
            (widget.shape! as RoundedRectangleBorder).side.color == primary,
      ),
    );

    // 选中背景盒与边框盒是同一层（Material 整宽绘制）：横贯整个菜单项
    // 宽度，与 MenuItemButton 同框（审计 select-bg 修复——内容区高亮曾
    // 内缩 28px，此处不再断言 item − 28）。
    final bgBox = tester.renderObject<RenderBox>(selectedFinder.first);
    final bg = bgBox.localToGlobal(Offset.zero) & bgBox.size;
    expect(bg.left, closeTo(item.localToGlobal(Offset.zero).dx, 1),
        reason: 'selected background must start at the item left edge');
    expect(bg.width, closeTo(item.size.width, 1),
        reason:
            'selected background box must span the full MenuItemButton width');
    expect(bg.right,
        closeTo(
          item.localToGlobal(Offset.zero).dx + item.size.width,
          1,
        ),
        reason: 'selected background must end at the item right edge');

    // 选中项 Material 背景 primaryContainer@0.45；未选中项透明（同时顶掉
    // SDK 默认 onSurface 12% 底衬）。
    expect(
      tester.widget<Material>(selectedFinder.first).color,
      theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      reason:
          'selected entry background must be primaryContainer on the item Material',
    );
    final unselectedColors = tester
        .widgetList<Material>(
          find.descendant(
            of: buttons,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Material &&
                  widget.shape is RoundedRectangleBorder &&
                  (widget.shape! as RoundedRectangleBorder).side.color !=
                      primary,
            ),
          ),
        )
        .map((m) => m.color)
        .toSet();
    expect(unselectedColors, {Colors.transparent},
        reason: 'unselected entries keep a transparent background');

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

  // compact（登录头）与 form（设置页）下拉共享同一图标几何：prefix/suffix
  // 区域 20x20、箭头尺寸 20，视觉一致。
  testWidgets('compact and form variants share icon geometry', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              LanguageDropdown(compact: true),
              SizedBox(height: 16),
              LanguageDropdown(), // form 模式（设置页）
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (final dropdown in find.byType(DropdownMenu<Locale>).evaluate()) {
      final decorator = find.descendant(
        of: find.byWidget(dropdown.widget),
        matching: find.byType(InputDecorator),
      );
      expect(decorator, findsOneWidget);
      final decoration = tester.widget<InputDecorator>(decorator).decoration;
      expect(
        decoration.prefixIconConstraints,
        const BoxConstraints.tightFor(width: 20, height: 20),
        reason: 'prefix icon region must be 20x20 in both variants',
      );
      expect(
        decoration.suffixIconConstraints,
        const BoxConstraints.tightFor(width: 20, height: 20),
        reason: 'suffix icon region must be 20x20 in both variants',
      );
    }
    // 箭头尺寸统一 20（字段 + 宽度测量副本，两变体共 4 个实例）。
    final arrows = tester
        .widgetList<Icon>(find.byIcon(Icons.arrow_drop_down))
        .where((icon) => icon.size == 20);
    expect(arrows.length, 4, reason: 'two dropdowns x (closed arrow + measure copy)');
  });
}
