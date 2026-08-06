import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_theme.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api/oidc_login_api.dart';
import 'app_router.dart';
import 'app_settings.dart';
import 'services/app_navigator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.instance.initialize();
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
