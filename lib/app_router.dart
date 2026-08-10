import 'package:flutter/material.dart';
import 'api/oidc_login_api.dart';
import 'api/sso_client.dart';
import 'entries/admin_entry.dart' deferred as admin_entry;
import 'entries/developer_entry.dart' deferred as developer_entry;
import 'entries/device_entry.dart' deferred as device_entry;
import 'entries/login_entry.dart' deferred as login_entry;
import 'entries/portal_entry.dart' deferred as portal_entry;
import 'entries/setup_entry.dart' deferred as setup_entry;
import 'services/product_entry_route.dart';
import 'widgets/deferred_entry_screen.dart';

/// 代码分割：六个产品入口各自编译为独立 deferred chunk，首屏只下载
/// 当前入口对应的 chunk，而不是一次拉取整个 4.7MB 单包。
///
/// - `main()` 在 `runApp` 前通过 [preloadProductEntry] 预加载当前路径对应
///   的入口，因此生产首屏仍然同步渲染真实界面，不经过加载占位。
/// - 跨入口导航（原生壳路由、浏览器深链到其他入口）经由
///   [DeferredEntryScreen] 按需加载：加载期间显示进度，chunk 下载失败
///   提供重试。
/// - [preloadProductEntry] 幂等且可被测试直接调用，测试无需处理
///   FutureBuilder 的异步帧。
final Set<ProductEntry> _loadedEntries = <ProductEntry>{};

/// 预加载指定产品入口的 deferred chunk（幂等）。
Future<void> preloadProductEntry(ProductEntry entry) async {
  if (!_loadedEntries.add(entry)) return;
  switch (entry) {
    case ProductEntry.setup:
      await setup_entry.loadLibrary();
    case ProductEntry.portal:
      await portal_entry.loadLibrary();
    case ProductEntry.developer:
      await developer_entry.loadLibrary();
    case ProductEntry.deviceVerification:
      await device_entry.loadLibrary();
    case ProductEntry.admin:
      await admin_entry.loadLibrary();
    case ProductEntry.login:
      await login_entry.loadLibrary();
  }
}

/// One Flutter web build serves all six areas of the SSO product (extracted
/// from the sso-server Go binary, which is now a pure API backend) — a
/// reverse proxy (OpenResty) routes /login/, /setup/, /portal/, /developer/,
/// /device/verify, and /admin/ all to this SAME static bundle, and THIS
/// function picks which screen to show based on the path the browser actually
/// loaded, exactly like any client-routed SPA behind a proxy.
///
/// /admin/ is gated by AdminGateScreen — no session (or a session without
/// admin API access) means a real redirect to /login/?redirect=/admin/,
/// never an inline login form on the /admin/ path itself. /login/ is the
/// ONE login screen every account kind (admin or regular) authenticates
/// through; what happens afterward is decided by admin API access, not by
/// which URL was used to sign in.
Widget resolveInitialScreen({OidcLoginApi? oidcLoginApi}) =>
    resolveProductScreen(Uri.base, oidcLoginApi: oidcLoginApi);

Widget resolveProductScreen(Uri location, {OidcLoginApi? oidcLoginApi}) {
  final entry = productEntryForPath(location.path);
  switch (entry) {
    case ProductEntry.setup:
      return _entryScreen(entry, setup_entry.loadLibrary, setup_entry.buildSetupScreen);
    case ProductEntry.portal:
      return _entryScreen(
        entry,
        portal_entry.loadLibrary,
        () => portal_entry.buildPortalScreen(location),
      );
    case ProductEntry.developer:
      return _entryScreen(
        entry,
        developer_entry.loadLibrary,
        developer_entry.buildDeveloperScreen,
      );
    case ProductEntry.deviceVerification:
      return _entryScreen(
        entry,
        device_entry.loadLibrary,
        () => device_entry.buildDeviceVerifyScreen(location),
      );
    case ProductEntry.admin:
      return _entryScreen(entry, admin_entry.loadLibrary, admin_entry.buildAdminGateScreen);
    case ProductEntry.login:
      return _entryScreen(
        entry,
        login_entry.loadLibrary,
        () => login_entry.buildLoginScreen(
          defaultClientId: SSOAdminClient.firstPartyClientId,
          api: oidcLoginApi,
          routeUri: location,
        ),
      );
  }
}

/// 已加载的入口直接同步构建（首屏路径）；未加载的入口经由
/// [DeferredEntryScreen] 触发 chunk 下载。
Widget _entryScreen(
  ProductEntry entry,
  Future<void> Function() load,
  Widget Function() build,
) {
  if (_loadedEntries.contains(entry)) return build();
  return DeferredEntryScreen(load: load, build: build);
}

/// Used by native shells when BrowserNavigation replaces an application
/// location without a browser history or page reload.
Route<dynamic> buildProductRoute(RouteSettings settings) {
  final location = Uri.tryParse(settings.name ?? '/') ?? Uri(path: '/');
  return MaterialPageRoute<void>(
    settings: settings,
    builder: (_) => resolveProductScreen(location),
  );
}
