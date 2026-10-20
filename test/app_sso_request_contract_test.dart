@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/oidc_login/consent_view.dart';
import 'package:sso_admin/screens/oidc_login/mfa_view.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';

import 'app_sso_test_support.dart';

void main() {
  testWidgets(
    'B waits for discovery and retains policy through MFA and consent',
    (tester) async {
      final discovery = Completer<http.Response>();
      final requests = <Map<String, dynamic>>[];
      final details = [
        {
          'type': 'fixture-read',
          'actions': ['read'],
        },
      ];
      final claims = {
        'id_token': {
          'acr': {'essential': true},
        },
      };
      await withAppSsoHarness(
        tester,
        (request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          expect(request.headers.containsKey('authorization'), isFalse);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          if (request.url.path == '/auth/mfa') {
            expect(body, {
              'mfa_challenge_id': 'fixture-b-mfa',
              'mfa_method': 'totp',
              'code': '123456',
            });
            return appSsoResponse({
              'error': 'consent_required',
              'login_transaction_id': 'fixture-b-transaction',
              'consent_challenge_id': 'fixture-b-consent',
              'client_name': 'Application B',
              'scopes': [
                {'scope': 'openid', 'description': 'Verify identity'},
                {'scope': 'app-b:read', 'description': 'Read B'},
              ],
            });
          }
          if (body['resume_session'] == true) {
            expect(body, {
              'client_id': 'app-b',
              'provider': '',
              'response_type': 'code',
              'redirect_uri': 'https://app-b.example.invalid/callback',
              'scope': ['openid', 'app-b:read'],
              'resource': ['app-b-api', 'app-b-reports'],
              'state': 'app-b-state',
              'nonce': 'app-b-nonce',
              'code_challenge': 'app-b'.padRight(43, 'x'),
              'code_challenge_method': 'S256',
              'prompt': 'consent',
              'max_age': 300,
              'acr_values': 'urn:fixture:strong',
              'claims': claims,
              'authorization_details': details,
              'resume_session': true,
            });
            return appSsoResponse({
              'error': 'mfa_required',
              'mfa_challenge_id': 'fixture-b-mfa',
              'mfa_methods': ['totp'],
            });
          }
          if (body.containsKey('consent_decision')) {
            expect(body, {
              'client_id': 'app-b',
              'login_transaction_id': 'fixture-b-transaction',
              'consent_challenge_id': 'fixture-b-consent',
              'consent_decision': 'allow',
            });
            return appSsoResponse({
              'code': 'fixture-b-code',
              'state': 'app-b-state',
              'redirect_uri': 'https://app-b.example.invalid/callback',
              'redirect_uri_validated': true,
              'response_mode': 'query',
            });
          }
          expect(body, {'client_id': 'app-b'});
          return discovery.future;
        },
        (harness) async {
          // A local token is not the OP cookie and must not be sent to B.
          Session.store(
            'fixture-local-console',
            clientId: SSOAdminClient.firstPartyClientId,
          );
          final b = appSsoLocation(
            'app-b',
            extra: {
              'prompt': 'consent',
              'max_age': '300',
              'acr_values': 'urn:fixture:strong',
              'claims': jsonEncode(claims),
              'authorization_details': jsonEncode(details),
            },
          );
          await harness.navigate(tester, b);
          expect(requests, hasLength(1));
          expect(appSsoPassword(), findsNothing);
          expect(find.byType(MfaView), findsNothing);
          discovery.complete(appSsoResponse(appSsoResumable));
          await tester.pumpAndSettle();
          expect(requests, hasLength(2));
          expect(find.byType(MfaView), findsOneWidget);
          expect(appSsoPassword(), findsNothing);
          final mfaCode = find.descendant(
            of: find.byType(MfaView),
            matching: find.byType(TextField),
          );
          await tester.enterText(mfaCode, '123456');
          final verify = find.widgetWithText(FilledButton, 'Verify');
          await tester.ensureVisible(verify);
          await tester.tap(verify);
          await tester.pumpAndSettle();
          expect(requests, hasLength(3));
          expect(find.byType(ConsentView), findsOneWidget);
          final allow = find.widgetWithText(FilledButton, 'Allow');
          await tester.ensureVisible(allow);
          await tester.tap(allow);
          await tester.pumpAndSettle();
          expect(requests, hasLength(4));
          expect(BrowserNavigation.currentUri.queryParameters, {
            'code': 'fixture-b-code',
            'state': 'app-b-state',
          });
          expect(Session.read(), 'fixture-local-console');
          expect(Session.readForClient('app-b'), isNull);
          expect(
            requests.where((body) => body.containsKey('credential')),
            isEmpty,
          );
        },
      );
    },
  );

  testWidgets(
    'removed prompt-none discovery cannot submit an old authorization',
    (tester) async {
      final discovery = Completer<http.Response>();
      final requests = <Map<String, dynamic>>[];
      await withAppSsoHarness(
        tester,
        (request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          requests.add(body);
          if (body['client_id'] == 'app-a') return discovery.future;
          return appSsoResponse(appSsoProviders);
        },
        (harness) async {
          await harness.navigate(
            tester,
            appSsoLocation('app-a', extra: {'prompt': 'none'}),
          );
          final oldState = tester.state(appSsoLogin());
          final b = appSsoLocation('app-b');
          BrowserNavigation.replaceLocation(b);
          await tester.pump();
          await tester.pump();
          expect(oldState.mounted, isTrue);
          expect(ModalRoute.of(oldState.context)!.isActive, isFalse);
          discovery.complete(appSsoResponse(appSsoResumable));
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
}
