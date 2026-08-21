import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/api/portal_api.dart';
import 'package:sso_admin/api/setup_api.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/admin/clients_tab.dart';
import 'package:sso_admin/screens/admin/governance_tab.dart';
import 'package:sso_admin/screens/admin/tenants_tab.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';
import 'package:sso_admin/screens/developer/developer_screen.dart';
import 'package:sso_admin/screens/device/device_verify_api.dart';
import 'package:sso_admin/screens/device/device_verify_screen.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/screens/portal/overview_tab.dart';
import 'package:sso_admin/screens/portal/security_tab.dart';
import 'package:sso_admin/screens/setup/setup_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_theme.dart';

/// 渲染矩阵固化回归测试（常驻门禁）。
///
/// 设计见 docs/ui/pages-per-page/matrix-gate.md。六个产品入口各选代表页：
///   admin     clients / tenants / governance
///   portal    overview / security
///   developer register
///   login     表单
///   device    verify
///   setup     screen
/// 每页 × {light, dark} × {en, zh} = 9 × 4 = 36 个独立用例，每个用例
/// 只 pump 一次 + settle 一次，断言 tester.takeException() == null ——
/// 任何 build 异常、布局溢出、断言异常都会在此失败。数据走 MockClient
/// 空数据路由（列表端点 200 空数组、其余 404），零网络、零真实 I/O。
/// 这是 zz_ 临时体检矩阵的常驻版本：页面在 dark/zh 下回归立即暴露。
void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('render matrix smoke (light/dark × en/zh)', () {
    for (final page in _pages) {
      for (final dark in const [false, true]) {
        for (final lang in const ['en', 'zh']) {
          _runCombo(page, dark: dark, lang: lang);
        }
      }
    }
  });
}

/// 页面注册表：{name, build(空数据路由), type}。
List<({String name, Widget Function() build, Type type})> get _pages => [
  (
    name: 'admin clients',
    build: () =>
        ClientsTab(client: _adminClient('/api/v1/admin/clients', 'clients')),
    type: ClientsTab,
  ),
  (
    name: 'admin tenants',
    build: () =>
        TenantsTab(client: _adminClient('/api/v1/admin/tenants', 'tenants')),
    type: TenantsTab,
  ),
  (
    name: 'admin governance',
    build: () => GovernanceTab(
      api: _adminApi(),
      capabilities: SnaplinkAdminCapabilities(const []),
    ),
    type: GovernanceTab,
  ),
  (
    name: 'portal overview',
    build: () => OverviewTab(api: _portalApi(profile: true)),
    type: OverviewTab,
  ),
  (
    name: 'portal security',
    build: () => SecurityTab(api: _portalApi(profile: false)),
    type: SecurityTab,
  ),
  (
    name: 'developer register',
    build: () => DeveloperScreen(api: _developerApi()),
    type: DeveloperScreen,
  ),
  (
    name: 'login form',
    build: () => OidcLoginScreen(
      api: OidcLoginApi(
        baseUri: Uri.parse('https://sso.example/'),
        httpClient: MockClient(
          (_) async => http.Response('{"error":"not found"}', 404),
        ),
      ),
      defaultClientId: SSOAdminClient.firstPartyClientId,
      routeUri: Uri.parse('https://sso.example/login/'),
    ),
    type: OidcLoginScreen,
  ),
  (
    name: 'device verify',
    build: () => DeviceVerifyScreen(
      api: DeviceVerifyApi(
        httpClient: MockClient(
          (_) async => http.Response('{"error":"not found"}', 404),
        ),
      ),
      accessTokenProvider: () => 'user-token',
    ),
    type: DeviceVerifyScreen,
  ),
  (
    name: 'setup screen',
    build: () => SetupScreen(
      api: SetupApi(
        client: MockClient((request) async {
          if (request.url.path == '/api/v1/setup/status') {
            return http.Response(
              jsonEncode({'setup_required': true, 'available': true}),
              200,
            );
          }
          return http.Response('{"error":"not found"}', 404);
        }),
      ),
    ),
    type: SetupScreen,
  ),
];

/// 注册一个 {light|dark} × {en|zh} 组合用例：pump 一次 + settle 一次，
/// 断言无异常且页面根组件已渲染。
void _runCombo(
  ({String name, Widget Function() build, Type type}) page, {
  required bool dark,
  required String lang,
}) {
  testWidgets('${page.name} · ${dark ? 'dark' : 'light'} · $lang', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final originalLocale = AppSettings.instance.locale;
    addTearDown(() => AppSettings.instance.locale = originalLocale);
    final locale = Locale(lang);
    AppSettings.instance.locale = locale;
    await tester.pumpWidget(_wrap(page.build(), dark: dark, locale: locale));
    await tester.pumpAndSettle();
    expect(
      tester.takeException(),
      isNull,
      reason:
          '${page.name} (${dark ? 'dark' : 'light'}, $lang) threw '
          'during render',
    );
    expect(
      find.byType(page.type),
      findsOneWidget,
      reason:
          '${page.name} (${dark ? 'dark' : 'light'}, $lang) did not '
          'settle into its page root',
    );
  });
}

Widget _wrap(Widget child, {required bool dark, required Locale locale}) =>
    MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: locale,
      supportedLocales: AppSettings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    );

/// 空数据 admin client：列表端点 200 空数组，其余 404。
SSOAdminClient _adminClient(String path, String key) => SSOAdminClient(
  'https://sso.example.test',
  httpClient: MockClient((request) async {
    if (request.url.path == path) {
      return http.Response(
        jsonEncode({key: <Object>[], 'total_size': 0}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not found"}', 404);
  }),
);

/// 空数据 admin api：全部 404（governance 的目录回退自行渲染空态）。
SnaplinkAdminApi _adminApi() => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient(
    (_) async => http.Response('{"error":"not found"}', 404),
  ),
);

/// 空数据 portal api：profile=true 时 /me 返回空档案（overview 用），
/// security 用 /me/mfa 空因子列表；其余 404。
PortalApi _portalApi({required bool profile}) => PortalApi(
  baseUri: Uri.parse('https://sso.example.test'),
  httpClient: MockClient((request) async {
    if (profile && request.url.path == '/me') {
      return http.Response(
        jsonEncode({
          'sub': 'user-1',
          'user': {
            'name': 'Ada',
            'email': 'ada@example.test',
            'attributes': <String, dynamic>{},
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    if (!profile && request.url.path == '/me/mfa') {
      return http.Response(
        jsonEncode({'factors': <Object>[]}),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('{"error":"not found"}', 404);
  }),
);

/// 空数据 developer api：discovery 返回最小配置，其余 404。
DeveloperApi _developerApi() => DeveloperApi(
  baseUri: Uri.parse('https://sso.example'),
  httpClient: MockClient((request) async {
    if (request.url.path == '/.well-known/openid-configuration') {
      return http.Response(
        jsonEncode({
          'registration_endpoint': 'https://sso.example/register',
          'grant_types_supported': ['authorization_code'],
          'response_types_supported': ['code'],
          'token_endpoint_auth_methods_supported': ['none'],
          'code_challenge_methods_supported': ['S256'],
          'scopes_supported': ['openid'],
        }),
        200,
      );
    }
    return http.Response('{"error":"not found"}', 404);
  }),
);
