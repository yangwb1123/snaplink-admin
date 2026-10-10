part of '../app_settings.dart';

extension _AppSettingsPresentation on AppSettings {
  Locale _loadLocale() {
    return _localeFromSaved(AppSettings._load(AppSettings._localeKey));
  }

  Locale _localeFromSaved(String? saved) {
    final parsed = saved == null ? null : _parseLocaleTag(saved);
    if (parsed != null) return parsed;
    // Device/browser locale as the default — no third-party IP lookup: it's
    // free, has no privacy cost, and gets the right answer for the
    // overwhelming majority of users (their device locale already reflects
    // where they are).
    final deviceCode = PlatformDispatcher.instance.locale.languageCode;
    final match = AppSettings.supportedLocales.where(
      (l) => l.languageCode == deviceCode,
    );
    return match.isNotEmpty ? match.first : const Locale('en');
  }

  ThemeMode _loadThemeMode() {
    return _themeModeFromSaved(AppSettings._load(AppSettings._themeKey));
  }

  AdminNavMode _loadAdminNavMode() {
    return _adminNavModeFromSaved(
      AppSettings._load(AppSettings._adminNavModeKey),
    );
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

  String _localeTag(Locale value) {
    final parts = <String>[value.languageCode.toLowerCase()];
    if (value.scriptCode case final script?) parts.add(script);
    if (value.countryCode case final country?) parts.add(country);
    return parts.join('-');
  }

  String _remoteLocaleTag(Locale value) {
    final language = value.languageCode.toLowerCase();
    // SVERP uses regional tags for its supported locales. Keep an explicitly
    // selected region/script intact, but make the Console's generic options
    // interoperable with SVERP's exact en-US/zh-CN values.
    if (value.scriptCode == null && value.countryCode == null) {
      if (language == 'en') return 'en-US';
      if (language == 'zh') return 'zh-CN';
    }
    return _localeTag(value);
  }

  Locale? _parseLocaleTag(String value) {
    final tag = value.trim();
    if (!isValidLanguageTag(tag)) return null;
    final parsed = parseLanguageOptions(tag);
    return parsed.length == 1 ? parsed.single : null;
  }

  String? _validatedLocaleTag(String? value) {
    final tag = value?.trim();
    final parsed = tag == null ? null : _parseLocaleTag(tag);
    return parsed == null ? null : _localeTag(parsed);
  }

  Locale? _localeFromRemote(String? value) {
    final locale = value == null ? null : _parseLocaleTag(value);
    if (locale == null) return null;
    // The Console's translations are language-based. Keep the precise server
    // tag separately so a theme-only change does not rewrite zh-TW/en-GB,
    // while the Flutter locale remains one of the selector's language values.
    if (locale.languageCode == 'en') return const Locale('en');
    if (locale.languageCode == 'zh') return const Locale('zh');
    return locale;
  }

  ThemeMode? _themeModeFromRemote(String? value) {
    return switch (value) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      'auto' => ThemeMode.system,
      _ => null,
    };
  }

  String _remoteThemeMode(ThemeMode value) {
    return switch (value) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'auto',
    };
  }
}

String? _normalizeAppServiceOrigin(String? value, String errorCode) {
  final input = value?.trim() ?? '';
  if (input.isEmpty) return null;

  late final Uri uri;
  try {
    uri = Uri.parse(input);
  } on FormatException {
    throw FormatException(errorCode);
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
      (scheme == 'http' && !_isLoopbackAppHost(uri.host))) {
    throw FormatException(errorCode);
  }
  return Uri(
    scheme: scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
  ).toString();
}

bool _isLoopbackAppHost(String value) {
  final host = value.toLowerCase();
  if (host == 'localhost' || host == '::1') return true;
  final segments = host.split('.');
  if (segments.length != 4 || segments.first != '127') return false;
  return segments.every((segment) {
    final octet = int.tryParse(segment);
    return octet != null && octet >= 0 && octet <= 255;
  });
}
