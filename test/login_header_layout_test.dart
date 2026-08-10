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
}
