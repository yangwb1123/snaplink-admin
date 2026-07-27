import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sso_admin/services/local_storage.dart';

/// App-wide language/theme/SSO-base-URL preferences. A single ChangeNotifier
/// instance (not per-screen state) so a change anywhere — the login screen's
/// language toggle, the post-login settings screen — is visible everywhere
/// immediately, including screens already on the widget stack.
///
/// localStorage (not sessionStorage, unlike session.dart's access token):
/// preferences are meant to survive a browser restart; the auth token
/// deliberately isn't. Web only — native builds keep in-memory defaults for
/// now (no settings UI wired for them yet; see [ssoBaseUrlOverride]'s doc).
class AppSettings extends ChangeNotifier {
  AppSettings._() {
    _locale = _loadLocale();
    _themeMode = _loadThemeMode();
    _ssoBaseUrlOverride = _load(_baseUrlKey);
  }

  static final AppSettings instance = AppSettings._();

  static const _localeKey = 'sso_settings_locale';
  static const _themeKey = 'sso_settings_theme';
  static const _baseUrlKey = 'sso_settings_base_url';

  static const supportedLocales = [Locale('en'), Locale('zh')];

  late Locale _locale;
  Locale get locale => _locale;
  set locale(Locale value) {
    if (_locale == value) return;
    _locale = value;
    _save(_localeKey, value.languageCode);
    notifyListeners();
  }

  late ThemeMode _themeMode;
  ThemeMode get themeMode => _themeMode;
  set themeMode(ThemeMode value) {
    if (_themeMode == value) return;
    _themeMode = value;
    _save(_themeKey, value.name);
    notifyListeners();
  }

  /// Overrides SSOAdminClient.sameOrigin's same-origin default — only
  /// meaningful on native builds, which have no page origin to infer the SSO
  /// server from (see sso_client.dart's nativeDefaultBaseUrl fallback). On
  /// web this is intentionally ignored: the origin the app is already
  /// running on IS the SSO server, by construction of how this app is
  /// deployed (OpenResty fronts both on one origin), and letting it be
  /// overridden there would just be a way to misconfigure a working setup.
  String? _ssoBaseUrlOverride;
  String? get ssoBaseUrlOverride => kIsWeb ? null : _ssoBaseUrlOverride;
  set ssoBaseUrlOverride(String? value) {
    final normalized = (value == null || value.isEmpty) ? null : value;
    if (_ssoBaseUrlOverride == normalized) return;
    _ssoBaseUrlOverride = normalized;
    if (normalized == null) {
      _remove(_baseUrlKey);
    } else {
      _save(_baseUrlKey, normalized);
    }
    notifyListeners();
  }

  Locale _loadLocale() {
    final saved = _load(_localeKey);
    if (saved != null) {
      final match = supportedLocales.where((l) => l.languageCode == saved);
      if (match.isNotEmpty) return match.first;
    }
    // Device/browser locale as the default — no third-party IP lookup: it's
    // free, has no privacy cost, and gets the right answer for the
    // overwhelming majority of users (their device locale already reflects
    // where they are).
    final deviceCode = PlatformDispatcher.instance.locale.languageCode;
    final match = supportedLocales.where((l) => l.languageCode == deviceCode);
    return match.isNotEmpty ? match.first : const Locale('en');
  }

  ThemeMode _loadThemeMode() {
    switch (_load(_themeKey)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        // ThemeMode.system covers "auto-detect theme" with zero manual
        // brightness-detection code — Flutter already re-derives it live
        // from the OS/browser's prefers-color-scheme.
        return ThemeMode.system;
    }
  }

  static String? _load(String key) {
    if (!kIsWeb) return null;
    return LocalStorage.getItem(key);
  }

  static void _save(String key, String value) {
    if (!kIsWeb) return;
    LocalStorage.setItem(key, value);
  }

  static void _remove(String key) {
    if (!kIsWeb) return;
    LocalStorage.removeItem(key);
  }
}
