import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'api/oidc_login_api.dart';
import 'app_router.dart';
import 'app_settings.dart';

void main() {
  runApp(const SSOConsoleApp());
}

class SSOConsoleApp extends StatelessWidget {
  final OidcLoginApi? oidcLoginApi;

  const SSOConsoleApp({super.key, this.oidcLoginApi});

  static const _brand = Color(0xFF6366F1);

  static final _darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.dark,
      surface: const Color(0xFF1E293B),
    ),
    cardColor: const Color(0xFF1E293B),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1E293B),
      elevation: 0,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

  static final _lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _brand,
      brightness: Brightness.light,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
  );

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
