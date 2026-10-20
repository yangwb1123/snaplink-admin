@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/main.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/user_preferences.dart';
import 'package:sso_admin/session.dart';

import 'app_sso_test_support.dart';

void main() {
  testWidgets(
    'remote preference hydration can change locale during real handoff',
    (tester) async {
      final settings = AppSettings.instance;
      final originalLocale = settings.locale;
      final originalTheme = settings.themeMode;
      final previousClient = AppSettings.debugRemotePreferencesClient;
      final preferences = Completer<http.Response>();
      var preferenceReads = 0;
      final preferenceHttp = MockClient((request) {
        expect(request.method, 'GET');
        preferenceReads++;
        return preferences.future;
      });
      settings.locale = const Locale('en');
      settings.themeMode = ThemeMode.light;
      AppSettings.debugRemotePreferencesClient = SnaplinkUserPreferencesClient(
        httpClient: preferenceHttp,
        baseUri: Uri.parse('https://op.example.invalid/'),
      );
      addTearDown(() {
        AppSettings.debugRemotePreferencesClient = previousClient;
        preferenceHttp.close();
        settings.locale = originalLocale;
        settings.themeMode = originalTheme;
      });
      await withAppSsoHarness(
        tester,
        (request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          return appSsoResponse(
            body.containsKey('credential')
                ? {'access_token': 'fixture-a-access'}
                : appSsoProviders,
          );
        },
        (harness) async {
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpWidget(SSOConsoleApp(oidcLoginApi: harness.api));
          await tester.pumpAndSettle();
          final loginState = tester.state(appSsoLogin());
          await harness.submitPassword(tester);
          expect(preferenceReads, 1);
          preferences.complete(
            http.Response('{"locale":"zh-CN","theme_mode":"dark"}', 200),
          );
          // Render the preference-driven rebuild before the queued native handoff.
          // Stop at this boundary rather than mounting unrelated Admin APIs.
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(loginState.mounted, isTrue);
          expect(ModalRoute.of(loginState.context)!.isActive, isFalse);
          expect(preferenceReads, 1);
          expect(settings.locale, const Locale('zh'));
          expect(settings.themeMode, ThemeMode.dark);
          expect(BrowserNavigation.currentUri.path, '/admin/');
          expect(Session.read(), 'fixture-a-access');
        },
      );
    },
  );

  testWidgets('active local login waits for preferences then hands off once', (
    tester,
  ) async {
    final preferences = Completer<http.Response>();
    var preferenceReads = 0;
    var credentialPosts = 0;
    final preferenceHttp = MockClient((request) {
      expect(request.method, 'GET');
      expect(request.url.path, '/me/preferences');
      preferenceReads++;
      return preferences.future;
    });
    final previousClient = AppSettings.debugRemotePreferencesClient;
    AppSettings.debugRemotePreferencesClient = SnaplinkUserPreferencesClient(
      httpClient: preferenceHttp,
      baseUri: Uri.parse('https://op.example.invalid/'),
    );
    addTearDown(() {
      AppSettings.debugRemotePreferencesClient = previousClient;
      preferenceHttp.close();
    });
    await withAppSsoHarness(
      tester,
      (request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body.containsKey('credential')) {
          credentialPosts++;
          return appSsoResponse({'access_token': 'fixture-a-access'});
        }
        return appSsoResponse(appSsoProviders);
      },
      (harness) async {
        const a = '/login/?redirect=%2Fadmin%2F';
        await harness.navigate(tester, a);
        await harness.submitPassword(tester);
        expect(preferenceReads, 1);
        expect(BrowserNavigation.currentUri.toString(), a);
        preferences.complete(http.Response('{}', 200));
        await tester.pumpAndSettle();
        expect(BrowserNavigation.currentUri.path, '/admin/');
        expect(find.text('Local handoff destination'), findsOneWidget);
        expect(credentialPosts, 1);
        expect(preferenceReads, 1);
        expect(Session.read(), 'fixture-a-access');
      },
    );
  });

  testWidgets(
    'disposed local login cannot hand off after preference hydration',
    (tester) async {
      final preferences = Completer<http.Response>();
      final preferenceRequests = <http.Request>[];
      final preferenceHttp = MockClient((request) {
        preferenceRequests.add(request);
        return preferences.future;
      });
      final previousClient = AppSettings.debugRemotePreferencesClient;
      AppSettings.debugRemotePreferencesClient = SnaplinkUserPreferencesClient(
        httpClient: preferenceHttp,
        baseUri: Uri.parse('https://op.example.invalid/'),
      );
      addTearDown(() {
        AppSettings.debugRemotePreferencesClient = previousClient;
        preferenceHttp.close();
      });
      final requests = <Map<String, dynamic>>[];
      await withAppSsoHarness(
        tester,
        (request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          if (body.containsKey('credential')) {
            return appSsoResponse({
              'access_token': 'fixture-a-access',
              'session_id': 'fixture-a-session',
            });
          }
          return appSsoResponse(appSsoProviders);
        },
        (harness) async {
          await harness.navigate(tester, '/login/?redirect=%2Fadmin%2F');
          final oldState = tester.state(appSsoLogin());
          await harness.submitPassword(tester);
          expect(preferenceRequests, hasLength(1));
          expect(preferenceRequests.single.url.path, '/me/preferences');
          expect(Session.read(), 'fixture-a-access');
          expect(Session.readClientId(), SSOAdminClient.firstPartyClientId);

          final b = appSsoLocation('app-b');
          await harness.navigate(tester, b);
          final currentState = tester.state(appSsoLogin());
          expect(oldState.mounted, isFalse);
          expect(identical(oldState, currentState), isFalse);
          expect(appSsoPassword(), findsOneWidget);
          preferences.complete(http.Response('{}', 200));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));

          expect(BrowserNavigation.currentUri.toString(), b);
          expect(currentState.mounted, isTrue);
          expect(Session.read(), 'fixture-a-access');
          expect(Session.readForClient('app-b'), isNull);
          expect(
            requests.where((body) => body.containsKey('credential')),
            hasLength(1),
          );
          expect(
            requests.where((body) => body['resume_session'] == true),
            isEmpty,
          );
          expect(preferenceRequests, hasLength(1));
        },
      );
    },
  );
}
