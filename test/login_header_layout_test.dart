import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/widgets/language_selector.dart';
import 'package:sso_admin/widgets/theme_selector.dart';

/// 登录头布局：主题选择靠左、语言选择靠右，宽度贴合文字；窄屏自动换行
/// 不溢出。
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
}
