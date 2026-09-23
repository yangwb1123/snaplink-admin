import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api/oidc_login_api.dart';
import 'app_router.dart';
import 'app_settings.dart';
import 'services/app_navigator.dart';
import 'services/product_entry_route.dart';
import 'forge_android_instrumentation_entrypoint.dart'
    deferred as forge_instrumentation;

/// Kept as a named VM entrypoint for the debug Android lifecycle harness.
/// Product launches continue through [main]; the instrumentation runner opts
/// into this entrypoint explicitly on a disposable emulator.
@pragma('vm:entry-point')
Future<void> forgeAndroidInstrumentationMain() async {
  await forge_instrumentation.loadLibrary();
  return forge_instrumentation.forgeAndroidInstrumentationMain();
}

/// Named VM entrypoint for the explicit Android emulator → Forge Coordinator
/// lifecycle probe. Product launches continue through [main].
@pragma('vm:entry-point')
Future<void> forgeAndroidCoordinatorInstrumentationMain() async {
  await forge_instrumentation.loadLibrary();
  return forge_instrumentation.forgeAndroidCoordinatorInstrumentationMain();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.initialize();
  // A browser reload keeps the tab-scoped bearer. Hydrate shared language and
  // theme preferences without delaying the first frame; local changes made
  // while this request is in flight win and are uploaded by AppSettings.
  unawaited(AppSettings.instance.loadRemotePreferences());
  // 预加载当前产品入口的 deferred chunk：首屏同步渲染真实界面，其余 5 个
  // 入口保持按需加载（代码分割收益：首屏 bundle 从 4.7MB 降到主包 + 当前
  // 入口 chunk）。
  await preloadProductEntry(productEntryForPath(Uri.base.path));
  runApp(const SSOConsoleApp());
}

class SSOConsoleApp extends StatelessWidget {
  final OidcLoginApi? oidcLoginApi;

  const SSOConsoleApp({super.key, this.oidcLoginApi});

  static final _darkTheme = AppTheme.dark();

  static final _lightTheme = AppTheme.light();

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app on any AppSettings change (language toggle on
    // the login screen, theme/language changed from the post-login settings
    // screen) — a single ChangeNotifier instance, not per-screen state, so a
    // change is visible everywhere immediately.
    return ListenableBuilder(
      listenable: AppSettings.instance,
      builder: (context, _) => MaterialApp(
        title: 'SSO Console',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNavigator.key,
        onGenerateRoute: buildProductRoute,
        theme: _lightTheme,
        darkTheme: _darkTheme,
        themeMode: AppSettings.instance.themeMode,
        locale: AppSettings.instance.locale,
        supportedLocales: AppSettings.supportedLocales,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: resolveInitialScreen(oidcLoginApi: oidcLoginApi),
      ),
    );
  }
}
