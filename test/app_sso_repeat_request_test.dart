@TestOn('vm')
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_router.dart';
import 'package:sso_admin/screens/oidc_login/consent_view.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';
import 'package:sso_admin/widgets/error_boundary.dart';

import 'app_sso_test_support.dart';

void main() {
  testWidgets('production route factory uses fresh routes without URL keys', (
    tester,
  ) async {
    await withAppSsoHarness(
      tester,
      (_) async {
        fail('Constructing a route must not start authentication');
      },
      (harness) async {
        final location = appSsoLocation('app-b');
        final first =
            buildProductRoute(RouteSettings(name: location))
                as MaterialPageRoute<void>;
        final second =
            buildProductRoute(RouteSettings(name: location))
                as MaterialPageRoute<void>;
        expect(first, isNot(same(second)));
        final context = tester.element(find.byType(Scaffold));
        final firstEntry = first.builder(context) as ErrorBoundary;
        final secondEntry = second.builder(context) as ErrorBoundary;
        final firstLogin = firstEntry.child as OidcLoginScreen;
        final secondLogin = secondEntry.child as OidcLoginScreen;
        expect(firstLogin, isNot(same(secondLogin)));
        expect(firstLogin.routeUri.toString(), location);
        expect(secondLogin.routeUri.toString(), location);
        expect(firstLogin.defaultClientId, SSOAdminClient.firstPartyClientId);
        for (final widget in [
          firstEntry,
          secondEntry,
          firstLogin,
          secondLogin,
        ]) {
          for (final sensitive in [location, 'app-b-state', 'app-b-nonce']) {
            expect(widget.toStringShort(), isNot(contains(sensitive)));
          }
        }
        first.dispose();
        second.dispose();
      },
    );
  });

  testWidgets('identical explicit navigation owns a new consent transaction', (
    tester,
  ) async {
    final oldDecision = Completer<http.Response>();
    final requests = <Map<String, dynamic>>[];
    var resumes = 0;
    await withAppSsoHarness(
      tester,
      (request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        requests.add(body);
        if (body['resume_session'] == true) {
          resumes++;
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
            'resume_session': true,
          });
          return appSsoResponse({
            'error': 'consent_required',
            'login_transaction_id': 'fixture-transaction-$resumes',
            'consent_challenge_id': 'fixture-consent-$resumes',
            'client_name': 'Application B',
            'scopes': [
              {'scope': 'openid', 'description': 'Verify identity'},
              {'scope': 'app-b:read', 'description': 'Read B'},
            ],
          });
        }
        if (body['consent_decision'] != null) {
          if (body['login_transaction_id'] == 'fixture-transaction-1') {
            return oldDecision.future;
          }
          expect(body, {
            'client_id': 'app-b',
            'login_transaction_id': 'fixture-transaction-2',
            'consent_challenge_id': 'fixture-consent-2',
            'consent_decision': 'allow',
          });
          return appSsoResponse({
            'code': 'fixture-current-code',
            'state': 'app-b-state',
            'redirect_uri': 'https://app-b.example.invalid/callback',
            'redirect_uri_validated': true,
            'response_mode': 'query',
          });
        }
        expect(body, {'client_id': 'app-b'});
        return appSsoResponse(appSsoResumable);
      },
      (harness) async {
        final location = appSsoLocation('app-b');
        await harness.navigate(tester, location);
        final firstState = tester.state(appSsoLogin());
        final firstIdentity = BrowserNavigation.requestIdentity;
        for (final sensitive in [location, 'app-b-state', 'app-b-nonce']) {
          expect(firstState.widget.toStringShort(), isNot(contains(sensitive)));
        }
        expect(find.byType(ConsentView), findsOneWidget);
        expect(appSsoPassword(), findsNothing);
        final allow = find.widgetWithText(FilledButton, 'Allow');
        await tester.ensureVisible(allow);
        await tester.tap(allow);
        await tester.pump();
        expect(requests, hasLength(3));

        // This is a new explicit navigation, not a theme rebuild or URL scrub.
        // Identical text must neither deduplicate it nor reuse the old State.
        BrowserNavigation.replaceLocation(location);
        expect(BrowserNavigation.requestIdentity, isNot(same(firstIdentity)));
        await tester.pump();
        await tester.pump();
        // The new route can still be offstage while measuring its transition.
        // Select its actual route owner, not the last currently visible widget.
        final secondState = tester.state(
          find.byElementPredicate(
            (element) =>
                element.widget is OidcLoginScreen &&
                ModalRoute.of(element)!.isCurrent,
            skipOffstage: false,
          ),
        );
        expect(firstState.mounted, isTrue);
        expect(ModalRoute.of(firstState.context)!.isActive, isFalse);
        expect(identical(firstState, secondState), isFalse);
        for (final sensitive in [location, 'app-b-state', 'app-b-nonce']) {
          expect(
            secondState.widget.toStringShort(),
            isNot(contains(sensitive)),
          );
        }
        expect(resumes, 2);
        oldDecision.complete(
          appSsoResponse({
            'code': 'fixture-stale-code',
            'state': 'app-b-state',
            'redirect_uri': 'https://app-b.example.invalid/callback',
            'redirect_uri_validated': true,
            'response_mode': 'query',
          }),
        );
        await tester.pump();
        expect(BrowserNavigation.currentUri.toString(), location);
        await tester.pump(const Duration(milliseconds: 700));
        await tester.pumpAndSettle();
        expect(firstState.mounted, isFalse);
        expect(secondState.mounted, isTrue);
        expect(requests, hasLength(5));
        expect(find.byType(ConsentView), findsOneWidget);

        await tester.ensureVisible(allow);
        await tester.tap(allow);
        await tester.pumpAndSettle();
        expect(
          BrowserNavigation.currentUri.queryParameters['code'],
          'fixture-current-code',
        );
        final decisions = requests.where(
          (body) => body['consent_decision'] != null,
        );
        expect(decisions.map((body) => body['login_transaction_id']), [
          'fixture-transaction-1',
          'fixture-transaction-2',
        ]);
        expect(requests, hasLength(6));
        expect(Session.read(), isNull);
        expect(Session.readForClient('app-b'), isNull);
      },
    );
  });
}
