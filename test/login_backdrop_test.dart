import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/login_backdrop.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/session.dart';

/// WS2：登录页装饰性背景场景。
///
/// 覆盖：登录页嵌入 LoginBackdrop；ExcludeSemantics 显式排除（语义下
/// backdrop 区域无任何 label）；无 Ticker/Timer；亮/暗两亮度渲染不抛异常；
/// 大/窄两种视口下绘制不抛异常。teardown 均恢复 view。
void main() {
  tearDown(Session.clear);

  Future<void> pumpLogin(WidgetTester tester) async {
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/login/'),
      httpClient: MockClient(
        (request) async => http.Response('{"providers":[]}', 200),
      ),
    );
    addTearDown(api.close);
    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          defaultClientId: 'web-client',
          api: api,
          routeUri: Uri.parse('https://sso.example/login/'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('login page embeds the backdrop, excluded from semantics', (
    tester,
  ) async {
    await pumpLogin(tester);

    expect(find.byType(LoginBackdrop), findsOneWidget);
    expect(find.byType(ExcludeSemantics), findsWidgets);

    final handle = tester.ensureSemantics();
    await tester.pump();
    // 装饰画面显式排除：backdrop 区域无任何语义 label。
    expect(
      find.descendant(
        of: find.byType(LoginBackdrop),
        matching: find.bySemanticsLabel(RegExp('.+')),
      ),
      findsNothing,
    );
    handle.dispose();
  });

  testWidgets('backdrop is static: no ticker or timer keeps running', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoginBackdrop(brightness: Brightness.light)),
      ),
    );
    // pump 数帧后：无 ticker；pending timer 由框架的测试结束断言覆盖
    // （“A Timer is still pending”），无需（也无法）访问 binding.fakeAsync。
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('backdrop renders in light and dark without exceptions', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(body: LoginBackdrop(brightness: brightness)),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(LoginBackdrop), findsOneWidget);
    }
  });

  testWidgets('backdrop paints on desktop and narrow phone surfaces', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1.0;

    // 桌面：排除带之外有大片绘制区域。
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LoginBackdrop(brightness: Brightness.dark)),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);

    // 320px 手机：排除带覆盖全宽（装饰全部隐去），仍不抛异常。
    tester.view.physicalSize = const Size(320, 568);
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
