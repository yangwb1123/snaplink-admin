@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/oidc_login/login_view_widget.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';

import 'app_sso_test_support.dart';

Future<void> _beginReplacement(WidgetTester tester, String target) async {
  BrowserNavigation.replaceLocation(target);
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets(
    'queued native navigation invalidates discovery before its frame',
    (tester) async {
      final discovery = Completer<http.Response>();
      final requests = <Map<String, dynamic>>[];
      await withAppSsoHarness(
        tester,
        (request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          if (body['client_id'] == 'app-a' && body['resume_session'] != true) {
            return discovery.future;
          }
          if (body['resume_session'] == true) {
            return appSsoResponse({
              'code': 'fixture-a-code',
              'state': 'app-a-state',
              'redirect_uri': 'https://app-a.example.invalid/callback',
              'redirect_uri_validated': true,
              'response_mode': 'query',
            });
          }
          return appSsoResponse(appSsoProviders);
        },
        (harness) async {
          await harness.navigate(tester, appSsoLocation('app-a'));
          final oldState = tester.state(appSsoLogin());
          final b = appSsoLocation('app-b');
          BrowserNavigation.replaceLocation(b);
          // The native owner queues Navigator mutation for the next frame. The
          // explicit B navigation already superseded A, although its route is
          // still active until that frame runs.
          expect(ModalRoute.of(oldState.context)!.isActive, isTrue);
          discovery.complete(appSsoResponse(appSsoResumable));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          await tester.pumpAndSettle();
          expect(requests, [
            {'client_id': 'app-a'},
            {'client_id': 'app-b'},
          ]);
          expect(BrowserNavigation.currentUri.toString(), b);
          expect(appSsoPassword(), findsOneWidget);
        },
      );
    },
  );

  testWidgets('removed native route cannot resume from late discovery', (
    tester,
  ) async {
    final discovery = Completer<http.Response>();
    final branding = Completer<http.Response>();
    final requests = <Map<String, dynamic>>[];
    var brands = 0;
    final originalLanguages = AppSettings.instance.languageOptions;
    addTearDown(() => AppSettings.instance.languageOptions = originalLanguages);
    await withAppSsoHarness(
      tester,
      (request) async {
        if (request.url.path == '/branding') {
          if (++brands == 1) return branding.future;
          return appSsoResponse({
            'branding': {'brand_name': 'Current application'},
          });
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        if (body['client_id'] == 'app-a' && body['resume_session'] != true) {
          return discovery.future;
        }
        if (body['resume_session'] == true) {
          return appSsoResponse({
            'code': 'fixture-a-code',
            'state': 'app-a-state',
            'redirect_uri': 'https://app-a.example.invalid/callback',
            'redirect_uri_validated': true,
            'response_mode': 'query',
          });
        }
        return appSsoResponse(appSsoProviders);
      },
      (harness) async {
        await harness.navigate(tester, appSsoLocation('app-a'));
        final oldState = tester.state(appSsoLogin());
        expect(find.byType(LoginViewWidget), findsNothing);
        final b = appSsoLocation('app-b');
        await _beginReplacement(tester, b);
        // pushNamedAndRemoveUntil removes A immediately but retains its mounted
        // subtree during B's transition. mounted alone is not request ownership.
        expect(oldState.mounted, isTrue);
        expect(ModalRoute.of(oldState.context)!.isActive, isFalse);
        discovery.complete(appSsoResponse(appSsoResumable));
        branding.complete(
          appSsoResponse({
            'branding': {'brand_name': 'Old application', 'languages': 'zh-CN'},
          }),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
        expect(requests, hasLength(2));
        expect(requests.map((body) => body['client_id']), ['app-a', 'app-b']);
        expect(
          requests.where((body) => body['resume_session'] == true),
          isEmpty,
        );
        expect(BrowserNavigation.currentUri.toString(), b);
        expect(find.text('Current application'), findsOneWidget);
        expect(find.text('Old application'), findsNothing);
        expect(AppSettings.instance.languageOptions, originalLanguages);
        expect(appSsoPassword(), findsOneWidget);
      },
    );
  });

  testWidgets('Settings coverage does not abandon an active login request', (
    tester,
  ) async {
    final discovery = Completer<http.Response>();
    var probes = 0;
    await withAppSsoHarness(
      tester,
      (request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        probes++;
        return discovery.future;
      },
      (harness) async {
        final a = appSsoLocation('app-a');
        await harness.navigate(tester, a);
        final state = tester.state(appSsoLogin());
        await tester.tap(find.byIcon(Icons.settings_outlined));
        await tester.pumpAndSettle();
        expect(state.mounted, isTrue);
        expect(ModalRoute.of(state.context)!.isActive, isTrue);
        expect(ModalRoute.of(state.context)!.isCurrent, isFalse);
        discovery.complete(appSsoResponse(appSsoProviders));
        await tester.pumpAndSettle();
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(identical(state, tester.state(appSsoLogin())), isTrue);
        expect(appSsoPassword(), findsOneWidget);
        expect(probes, 1);
        expect(BrowserNavigation.currentUri.toString(), a);
      },
    );
  });

  testWidgets(
    'removed primary result cannot install tokens during transition',
    (tester) async {
      final primary = Completer<http.Response>();
      var submissions = 0;
      await withAppSsoHarness(
        tester,
        (request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body.containsKey('credential')) {
            submissions++;
            return primary.future;
          }
          return appSsoResponse(appSsoProviders);
        },
        (harness) async {
          await harness.navigate(tester, '/login/?redirect=%2Fadmin%2F');
          final oldState = tester.state(appSsoLogin());
          await harness.submitPassword(tester);
          expect(submissions, 1);
          final b = appSsoLocation('app-b');
          await _beginReplacement(tester, b);
          expect(oldState.mounted, isTrue);
          expect(ModalRoute.of(oldState.context)!.isActive, isFalse);
          primary.complete(
            appSsoResponse({
              'access_token': 'fixture-a-access',
              'session_id': 'fixture-a-session',
            }),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 700));
          expect(Session.read(), isNull);
          expect(Session.readForClient('app-b'), isNull);
          expect(BrowserNavigation.currentUri.toString(), b);
          expect(submissions, 1);
        },
      );
    },
  );
}
