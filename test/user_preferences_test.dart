import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/services/user_preferences.dart';
import 'package:sso_admin/session.dart';

void main() {
  test('loads allowlisted preferences with the bearer token', () async {
    late http.BaseRequest request;
    final client = SnaplinkUserPreferencesClient(
      baseUri: Uri.parse('https://sso.example.test/'),
      accessTokenProvider: () => 'access-token',
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response(
          '{"locale":"zh-CN","theme_mode":"dark",'
          '"password_hash":"must-not-be-consumed"}',
          200,
        );
      }),
    );

    final preferences = await client.getMyPreferences();
    expect(preferences?.locale, 'zh-CN');
    expect(preferences?.themeMode, 'dark');
    expect(request.method, 'GET');
    expect(request.url.path, '/me/preferences');
    expect(request.headers['authorization'], 'Bearer access-token');
  });

  test('reads the legacy theme wire alias during migration', () async {
    final client = SnaplinkUserPreferencesClient(
      baseUri: Uri.parse('https://sso.example.test/'),
      accessTokenProvider: () => 'access-token',
      httpClient: MockClient((_) async {
        return http.Response('{"sverp:theme_mode":"auto"}', 200);
      }),
    );

    expect((await client.getMyPreferences())?.themeMode, 'auto');
  });

  test('rejects conflicting theme wire aliases', () async {
    final client = SnaplinkUserPreferencesClient(
      baseUri: Uri.parse('https://sso.example.test/'),
      accessTokenProvider: () => 'access-token',
      httpClient: MockClient((_) async {
        return http.Response(
          '{"theme_mode":"dark","sverp:theme_mode":"light"}',
          200,
        );
      }),
    );

    expect(await client.getMyPreferences(), isNull);
  });

  test('writes only the shared allowlisted values', () async {
    late http.Request request;
    final client = SnaplinkUserPreferencesClient(
      baseUri: Uri.parse('https://sso.example.test/'),
      accessTokenProvider: () => 'access-token',
      httpClient: MockClient((incoming) async {
        request = incoming;
        return http.Response('{}', 200);
      }),
    );

    expect(
      await client.updateMyPreferences(
        const PresentationPreferencesPatch(locale: 'en-US', themeMode: 'light'),
      ),
      isTrue,
    );
    expect(request.method, 'PUT');
    expect(request.url.path, '/me/preferences');
    expect(request.headers['authorization'], 'Bearer access-token');
    expect(jsonDecode(request.body), {
      'locale': 'en-US',
      'theme_mode': 'light',
    });
  });

  test('treats absent sessions and invalid responses as unavailable', () async {
    var requests = 0;
    final client = SnaplinkUserPreferencesClient(
      accessTokenProvider: () => null,
      httpClient: MockClient((_) async {
        requests++;
        return http.Response('{"locale":"zh-CN"}', 200);
      }),
    );

    expect(await client.getMyPreferences(), isNull);
    expect(requests, 0);

    final invalid = SnaplinkUserPreferencesClient(
      accessTokenProvider: () => 'token',
      httpClient: MockClient((_) async => http.Response('[]', 200)),
    );
    expect(await invalid.getMyPreferences(), isNull);
  });

  test('login hints contain only values explicitly changed on this page', () {
    final settings = AppSettings.instance;
    final originalLocale = settings.locale;
    final originalTheme = settings.themeMode;
    addTearDown(() {
      settings.locale = originalLocale;
      settings.themeMode = originalTheme;
    });

    settings.locale = const Locale('en');
    settings.themeMode = ThemeMode.light;
    expect(
      settings.loginPresentationPreferences(
        initialLocale: const Locale('zh'),
        initialThemeMode: ThemeMode.dark,
      ),
      {'presentation_locale': 'en-US', 'presentation_theme_mode': 'light'},
    );
    expect(
      settings.loginPresentationPreferences(
        initialLocale: const Locale('en'),
        initialThemeMode: ThemeMode.dark,
      ),
      {'presentation_theme_mode': 'light'},
    );
  });

  test(
    'hydrates and uploads the Console/SVERP locale and theme mapping',
    () async {
      final settings = AppSettings.instance;
      final originalLocale = settings.locale;
      final originalTheme = settings.themeMode;
      addTearDown(() async {
        Session.clear();
        AppSettings.debugRemotePreferencesClient = null;
        settings.locale = originalLocale;
        settings.themeMode = originalTheme;
        await Future<void>.delayed(Duration.zero);
      });

      Map<String, dynamic>? saved;
      AppSettings.debugRemotePreferencesClient = SnaplinkUserPreferencesClient(
        accessTokenProvider: Session.read,
        httpClient: MockClient((request) async {
          if (request.method == 'GET') {
            return http.Response('{"locale":"zh-CN","theme_mode":"auto"}', 200);
          }
          saved = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response('{}', 200);
        }),
      );
      Session.store('access-token');

      await settings.loadRemotePreferences();
      expect(settings.locale, const Locale('zh'));
      expect(settings.themeMode, ThemeMode.system);

      settings.locale = const Locale('en');
      await Future<void>.delayed(Duration.zero);
      expect(saved, {'locale': 'en-US', 'theme_mode': 'auto'});
    },
  );
}
