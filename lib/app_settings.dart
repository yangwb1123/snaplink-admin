import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:sso_admin/services/language_catalog.dart';
import 'package:sso_admin/services/local_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Admin navigation surface density.
///
/// `normal` (the default) shows the core trio ([AdminHotModules.core]);
/// `professional` shows the curated hot set ([AdminHotModules.modules]).
/// Serialized by `.name`.
enum AdminNavMode { normal, professional }

/// App-wide language/theme/SSO-base-URL preferences. A single ChangeNotifier
/// instance (not per-screen state) so a change anywhere — the login screen's
/// language toggle, the post-login settings screen — is visible everywhere
/// immediately, including screens already on the widget stack.
///
/// Preferences survive a restart, unlike session.dart's access token. Web uses
/// localStorage synchronously; native platforms load and persist through
/// SharedPreferencesAsync during application startup.
class AppSettings extends ChangeNotifier {
  AppSettings._() {
    _locale = _loadLocale();
    _themeMode = _loadThemeMode();
    _ssoBaseUrlOverride = _load(_baseUrlKey);
    _adminNavMode = _loadAdminNavMode();
  }

  static final AppSettings instance = AppSettings._();
  static SharedPreferencesAsync? _nativePreferences;

  static const _localeKey = 'sso_settings_locale';
  static const _themeKey = 'sso_settings_theme';
  static const _baseUrlKey = 'sso_settings_base_url';
  static const _adminNavModeKey = 'sso_settings_admin_nav_mode';

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
    final normalized = normalizeSsoBaseUrl(value);
    if (_ssoBaseUrlOverride == normalized) return;
    _ssoBaseUrlOverride = normalized;
    if (normalized == null) {
      _remove(_baseUrlKey);
    } else {
      _save(_baseUrlKey, normalized);
    }
    notifyListeners();
  }

  late AdminNavMode _adminNavMode;
  AdminNavMode get adminNavMode => _adminNavMode;
  set adminNavMode(AdminNavMode value) {
    if (_adminNavMode == value) return; // no-op guard: no notify, no write
    _adminNavMode = value;
    _save(_adminNavModeKey, value.name);
    notifyListeners();
  }

  /// 该 client（租户品牌）公布的可用语言列表，来自 branding 响应的
  /// `languages` 保留键（见 [languageCatalogKey]）。未加载或旧部署时保持
  /// [defaultLanguageOptions]。登录页品牌加载后写入，登录头与设置页的
  /// 语言选择器都消费这里，保证两处 items 一致且由后端数据驱动。
  List<Locale> _languageOptions = defaultLanguageOptions;
  List<Locale> get languageOptions => _languageOptions;
  set languageOptions(List<Locale> value) {
    if (value.isEmpty) return; // 空列表没有意义，保持当前值。
    if (value.length == _languageOptions.length &&
        value.every(
          (l) => _languageOptions.any((c) => c.languageCode == l.languageCode),
        )) {
      return;
    }
    _languageOptions = List.unmodifiable(value);
    notifyListeners();
  }

  /// Loads native preferences before the first widget builds. Storage failure
  /// is deliberately non-fatal: safe defaults still leave the app usable.
  Future<void> initialize() async {
    if (kIsWeb) return;
    final savedLocale = await _nativeLoad(_localeKey);
    final savedTheme = await _nativeLoad(_themeKey);
    final savedBaseUrl = await _nativeLoad(_baseUrlKey);

    _locale = _localeFromSaved(savedLocale);
    _themeMode = _themeModeFromSaved(savedTheme);
    _adminNavMode = _adminNavModeFromSaved(await _nativeLoad(_adminNavModeKey));
    try {
      _ssoBaseUrlOverride = normalizeSsoBaseUrl(savedBaseUrl);
    } on FormatException {
      _ssoBaseUrlOverride = null;
      unawaited(_nativeRemove(_baseUrlKey));
    }
  }

  /// Accepts only an origin, never a credential-bearing or path-scoped URL.
  /// Plain HTTP is limited to loopback development servers.
  static String? normalizeSsoBaseUrl(String? value) {
    final input = value?.trim() ?? '';
    if (input.isEmpty) return null;

    late final Uri uri;
    try {
      uri = Uri.parse(input);
    } on FormatException {
      throw const FormatException('invalid_sso_base_url');
    }
    final scheme = uri.scheme.toLowerCase();
    final rootPathOnly = uri.path.isEmpty || uri.path == '/';
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        (scheme != 'https' && scheme != 'http') ||
        uri.userInfo.isNotEmpty ||
        !rootPathOnly ||
        uri.hasQuery ||
        uri.hasFragment ||
        (scheme == 'http' && !_isLoopbackHost(uri.host))) {
      throw const FormatException('invalid_sso_base_url');
    }
    return Uri(
      scheme: scheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
    ).toString();
  }

  static bool _isLoopbackHost(String value) {
    final host = value.toLowerCase();
    if (host == 'localhost' || host == '::1') return true;
    final segments = host.split('.');
    if (segments.length != 4 || segments.first != '127') return false;
    return segments.every((segment) {
      final octet = int.tryParse(segment);
      return octet != null && octet >= 0 && octet <= 255;
    });
  }

  Locale _loadLocale() {
    return _localeFromSaved(_load(_localeKey));
  }

  Locale _localeFromSaved(String? saved) {
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
    return _themeModeFromSaved(_load(_themeKey));
  }

  AdminNavMode _loadAdminNavMode() {
    return _adminNavModeFromSaved(_load(_adminNavModeKey));
  }

  AdminNavMode _adminNavModeFromSaved(String? saved) {
    switch (saved) {
      case 'professional':
        return AdminNavMode.professional;
      default:
        // Absent key, corrupt value, or unknown future value → safe default.
        return AdminNavMode.normal;
    }
  }

  ThemeMode _themeModeFromSaved(String? saved) {
    switch (saved) {
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
    if (kIsWeb) {
      LocalStorage.setItem(key, value);
      return;
    }
    unawaited(_nativeSave(key, value));
  }

  static void _remove(String key) {
    if (kIsWeb) {
      LocalStorage.removeItem(key);
      return;
    }
    unawaited(_nativeRemove(key));
  }

  static Future<String?> _nativeLoad(String key) async {
    try {
      return await _preferences().getString(key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _nativeSave(String key, String value) async {
    try {
      await _preferences().setString(key, value);
    } catch (_) {
      // A preference write must not crash or block authentication.
    }
  }

  static Future<void> _nativeRemove(String key) async {
    try {
      await _preferences().remove(key);
    } catch (_) {
      // A preference write must not crash or block authentication.
    }
  }

  /// Test-only injection point for native preference failures (T13/T14):
  /// InMemorySharedPreferencesAsync never throws and the platform is cached
  /// at first use, so a throwing subclass must be injected here.
  @visibleForTesting
  static SharedPreferencesAsync? debugPreferencesOverride;

  static SharedPreferencesAsync _preferences() {
    final override = debugPreferencesOverride;
    if (override != null) return override;
    return _nativePreferences ??= SharedPreferencesAsync();
  }
}
