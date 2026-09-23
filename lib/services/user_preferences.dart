import 'dart:convert';

import 'package:http/http.dart' as http;

import '../session.dart';
import 'product_api_origin.dart';

const _localePattern = r'^[A-Za-z]{2,3}(-[A-Za-z0-9]{2,8})*$';
const _themeModes = {'light', 'dark', 'auto'};

typedef PresentationThemeMode = String;

/// The presentation preferences shared by Snaplink clients.
///
/// This is an SDK protocol type, not application UI state. Applications keep
/// their local settings and use this value only for hydration/synchronization.
class PresentationPreferences {
  final String? locale;
  final PresentationThemeMode? themeMode;

  const PresentationPreferences({this.locale, this.themeMode});
}

/// A partial presentation update. An empty string removes a stored value.
class PresentationPreferencesPatch {
  final String? locale;
  final PresentationThemeMode? themeMode;

  const PresentationPreferencesPatch({this.locale, this.themeMode});
}

/// Build only explicitly changed login-page hints.
///
/// The caller decides which values changed during the current login-page
/// session. Omitted values remain omitted and cannot overwrite stored values.
Map<String, String> buildLoginPreferenceHandoff(
  PresentationPreferencesPatch preferences,
) {
  final result = <String, String>{};
  final locale = preferences.locale;
  if (locale != null) {
    _validateLocale(locale, allowEmpty: false);
    result['presentation_locale'] = locale;
  }
  final themeMode = preferences.themeMode;
  if (themeMode != null && themeMode.isNotEmpty) {
    _validateThemeMode(themeMode, allowEmpty: false);
    result['presentation_theme_mode'] = themeMode;
  }
  return result;
}

/// The generated-client-style preference facade used by the Console.
///
/// The bearer token is supplied only in the Authorization header. No token or
/// preference response is persisted by this client; local UI settings remain
/// in AppSettings while Snaplink is the cross-application source of truth.
class SnaplinkUserPreferencesClient {
  final http.Client _http;
  final Duration requestTimeout;
  final Uri? baseUri;
  final String? Function() accessTokenProvider;

  SnaplinkUserPreferencesClient({
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 10),
    this.baseUri,
    String? Function()? accessTokenProvider,
  }) : _http = httpClient ?? http.Client(),
       accessTokenProvider = accessTokenProvider ?? Session.read;

  Uri _preferencesUri() =>
      (baseUri ?? ProductApiOrigin.baseUri).resolve('/me/preferences');

  String? _accessToken() {
    final token = accessTokenProvider()?.trim();
    return token == null || token.isEmpty ? null : token;
  }

  /// Returns null when there is no session, the endpoint is unavailable, or
  /// the response is not a valid JSON object.
  Future<PresentationPreferences?> getMyPreferences() async {
    final token = _accessToken();
    if (token == null) return null;

    final response = await _http
        .get(
          _preferencesUri(),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode != 200) return null;

    return _decode(response.body);
  }

  /// Merges the allowlisted values at the BFF/Snaplink endpoint.
  Future<bool> updateMyPreferences(
    PresentationPreferencesPatch preferences,
  ) async {
    final token = _accessToken();
    if (token == null) return false;

    final body = <String, String>{};
    final locale = preferences.locale;
    if (locale != null) {
      _validateLocale(locale, allowEmpty: true);
      body['locale'] = locale;
    }
    final themeMode = preferences.themeMode;
    if (themeMode != null) {
      _validateThemeMode(themeMode, allowEmpty: true);
      body['sverp:theme_mode'] = themeMode;
    }
    if (body.isEmpty) return false;

    final response = await _http
        .put(
          _preferencesUri(),
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return response.statusCode >= 200 && response.statusCode < 300;
  }

  /// Compatibility alias for callers migrating from the pre-SDK facade.
  @Deprecated('Use getMyPreferences()')
  Future<PresentationPreferences?> get() => getMyPreferences();

  /// Compatibility alias for callers migrating from the pre-SDK facade.
  @Deprecated('Use updateMyPreferences()')
  Future<bool> put(Map<String, String> preferences) => updateMyPreferences(
    PresentationPreferencesPatch(
      locale: preferences['locale'],
      themeMode: preferences['sverp:theme_mode'],
    ),
  );

  PresentationPreferences? _decode(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map) return null;
      final locale = decoded['locale'];
      final themeMode = decoded['sverp:theme_mode'];
      if (locale != null && locale is! String) return null;
      if (themeMode != null && themeMode is! String) return null;
      if (locale is String) _validateLocale(locale, allowEmpty: false);
      if (themeMode is String) {
        _validateThemeMode(themeMode, allowEmpty: false);
      }
      return PresentationPreferences(
        locale: locale as String?,
        themeMode: themeMode as String?,
      );
    } on FormatException {
      return null;
    } on ArgumentError {
      return null;
    }
  }
}

void _validateLocale(String value, {required bool allowEmpty}) {
  if (allowEmpty && value.isEmpty) return;
  if (value.length > 32 || !RegExp(_localePattern).hasMatch(value)) {
    throw ArgumentError('locale must be a valid BCP 47 language tag');
  }
}

void _validateThemeMode(String value, {required bool allowEmpty}) {
  if (allowEmpty && value.isEmpty) return;
  if (!_themeModes.contains(value)) {
    throw ArgumentError('themeMode must be light, dark, or auto');
  }
}
