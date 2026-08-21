@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/portal_api.dart';
import 'package:sso_admin/screens/portal/portal_entry.dart';
import 'package:sso_admin/screens/portal/portal_screen.dart';
import 'package:sso_admin/session.dart';

/// One recorded request for the REQ-3 request-bound portal tests.
class _PortalRecordedRequest {
  const _PortalRecordedRequest({required this.method, required this.path});

  final String method;
  final String path;
}

/// Recording MockClient for the REQ-3 bounds (design §3.3, D4):
/// `fail()`s on any POST and on any path not under `/me`, records everything
/// else. The assertions are structural — a future `POST /auth/login` (or any
/// POST) cannot be missed by a post-hoc filter.
MockClient _portalRecordingClient(
  List<_PortalRecordedRequest> recorded, {
  required String expectedBearer,
}) {
  return MockClient((request) async {
    if (request.method == 'POST') {
      fail(
        'portal paste/resume must issue zero POSTs — got POST '
        '${request.url.path} (F2)',
      );
    }
    if (!request.url.path.startsWith('/me')) {
      fail('portal traffic must stay under /me — got ${request.url.path} (F2)');
    }
    recorded.add(
      _PortalRecordedRequest(method: request.method, path: request.url.path),
    );
    if (request.url.path == '/me') {
      expect(request.headers['Authorization'], 'Bearer $expectedBearer');
      return http.Response('{"sub":"user-1"}', 200);
    }
    if (request.url.path == '/me/notifications') {
      return http.Response('{"notifications":[],"unread_count":0}', 200);
    }
    if (request.url.path == '/me/notifications/stream') {
      return http.Response('data: {"id":"n1","type":"ping"}\n\n', 200);
    }
    return http.Response('{}', 404);
  });
}

/// The single credential-validation bound: [PortalApi.login]'s probe is
/// always the FIRST request of the paste/resume flow; the overview tab's
/// later profile read ([PortalApi.fetchMe], overview_tab.dart:63) is a
/// /me-rooted BFF GET in the same class as /me/notifications (spec S6), not
/// a second validation. A duplicated validation probe would appear as a
/// second leading /me and fails here.
void _expectSingleValidationGetMe(List<_PortalRecordedRequest> recorded) {
  final leadingMe = recorded.takeWhile((r) => r.path == '/me').toList();
  expect(
    leadingMe.length,
    1,
    reason:
        'exactly one credential-validating GET /me — the paste/resume '
        'path must probe once and only once (${recorded.length} requests '
        'recorded)',
  );
  expect(
    leadingMe.single.method,
    'GET',
    reason: 'the credential validation must be a GET, never a POST',
  );
}

void main() {
  tearDown(Session.clear);

  test('portal login redirect preserves only the local path and query', () {
    final location = portalLoginLocation(
      Uri.parse(
        'https://sso.example/portal/security?from=settings#sensitive-fragment',
      ),
    );
    final login = Uri.parse(location);

    expect(login.origin, 'https://sso.example');
    expect(login.path, '/login/');
    expect(login.queryParameters['redirect'], '/portal/security?from=settings');
    expect(location, isNot(contains('sensitive-fragment')));
  });

  test('portal login redirect strips credential-like query values', () {
    final location = portalLoginLocation(
      Uri.parse(
        'https://sso.example/portal/security?from=settings&'
        'access_token=bearer-secret&password=primary-secret&'
        'state=oauth-state&token=untyped-secret&flow=unknown',
      ),
    );
    final redirect = Uri.parse(location).queryParameters['redirect']!;

    expect(redirect, '/portal/security?from=settings');
    expect(location, isNot(contains('bearer-secret')));
    expect(location, isNot(contains('primary-secret')));
    expect(location, isNot(contains('oauth-state')));
    expect(location, isNot(contains('untyped-secret')));
  });

  test('portal login redirect retains only typed account action material', () {
    final location = portalLoginLocation(
      Uri.parse(
        'https://sso.example/portal/?flow=invitation&token=invite-secret&'
        'from=mail',
      ),
    );
    final redirect = Uri.parse(location).queryParameters['redirect']!;

    expect(redirect, '/portal/?flow=invitation&token=invite-secret&from=mail');
  });

  test('portal login redirect replaces non-portal input with portal root', () {
    final location = portalLoginLocation(
      Uri.parse('https://sso.example/external?continue=https://evil.example'),
    );

    expect(Uri.parse(location).queryParameters['redirect'], '/portal/');
  });

  test('portal login redirect rejects lookalike path prefixes', () {
    final location = portalLoginLocation(
      Uri.parse('https://sso.example/portal-evil?secret=value'),
    );

    expect(Uri.parse(location).queryParameters['redirect'], '/portal/');
    expect(location, isNot(contains('secret')));
  });

  test('portal action routes map only explicit typed tokens', () {
    final email = PortalActionRoute.fromUri(
      Uri.parse('/portal/?flow=change_email&token=email-token'),
    );
    final invitation = PortalActionRoute.fromUri(
      Uri.parse('/portal/?flow=invitation&token=invite-token'),
    );
    final ambiguous = PortalActionRoute.fromUri(
      Uri.parse('/portal/?token=opaque-token'),
    );
    final duplicate = PortalActionRoute.fromUri(
      Uri.parse(
        '/portal/?flow=invitation&flow=change_email&token=invite-token',
      ),
    );

    expect(email.endpoint, '/me/email/verify');
    expect(email.navigationIndex, 1);
    expect(invitation.endpoint, '/me/invitations/accept');
    expect(invitation.navigationIndex, 7);
    expect(ambiguous.isAvailable, isFalse);
    expect(duplicate.isAvailable, isFalse);
  });

  test(
    'consumed portal action location drops secrets but keeps local state',
    () {
      final location = portalLocationWithoutAction(
        Uri.parse(
          'https://sso.example/portal/security?flow=change_email&'
          'token=one-time-secret&from=settings&view=credentials#fragment',
        ),
      );
      final sanitized = Uri.parse(location);

      expect(sanitized.path, '/portal/security');
      expect(sanitized.queryParameters, {
        'from': 'settings',
        'view': 'credentials',
      });
      expect(location, isNot(contains('one-time-secret')));
      expect(location, isNot(contains('flow=')));
      expect(location, isNot(contains('fragment')));
    },
  );

  testWidgets('missing web session enters the unified hosted login flow', (
    tester,
  ) async {
    String? redirectedTo;
    await tester.pumpWidget(
      MaterialApp(
        home: PortalScreen(
          redirectMissingSessionToLogin: true,
          onLoginRedirect: (location) => redirectedTo = location,
        ),
      ),
    );
    await tester.pump();

    expect(redirectedTo, isNotNull);
    expect(Uri.parse(redirectedTo!).path, '/login/');
    expect(find.text('Redirecting to sign in…'), findsOneWidget);
    expect(
      find.text('Paste your access token to manage your account.'),
      findsNothing,
    );
  });

  testWidgets('explicit token mode retains the bearer-token gate', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PortalScreen(redirectMissingSessionToLogin: false),
      ),
    );
    await tester.pump();

    expect(
      find.text('Paste your access token to manage your account.'),
      findsOneWidget,
    );
  });

  testWidgets('authenticated invitation action is consumed exactly once', (
    tester,
  ) async {
    var invitationPosts = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' && request.url.path == '/me') {
        return http.Response('{"sub":"user-1"}', 200);
      }
      if (request.method == 'POST' &&
          request.url.path == '/me/invitations/accept') {
        invitationPosts++;
        expect(request.headers['Authorization'], 'Bearer bearer-token');
        expect(jsonDecode(request.body), {'token': 'invite-token'});
        return http.Response('{}', 200);
      }
      return http.Response('{}', 404);
    });
    final api = PortalApi(httpClient: client);

    await tester.pumpWidget(
      MaterialApp(
        home: PortalScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/portal/'
            '?flow=invitation&token=invite-token',
          ),
          redirectMissingSessionToLogin: false,
        ),
      ),
    );
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'bearer-token');
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(
      find.text('The organization invitation has been accepted.'),
      findsOneWidget,
    );
    expect(invitationPosts, 1);
    await tester.pump();
    expect(invitationPosts, 1);
  });

  testWidgets('a stored portal session survives a 403 and can be retried', (
    tester,
  ) async {
    Session.store('still-valid-token', clientId: 'portal-client');
    String? redirectedTo;
    final api = PortalApi(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/me');
        return http.Response('{"error":"insufficient_scope"}', 403);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PortalScreen(
          api: api,
          redirectMissingSessionToLogin: true,
          onLoginRedirect: (location) => redirectedTo = location,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(redirectedTo, isNull);
    expect(Session.read(), 'still-valid-token');
    expect(
      find.textContaining('not authorized to use the account portal'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets(
    'paste login issues zero POSTs and exactly one GET /me validation '
    '(REQ-3/AC-2)',
    (tester) async {
      final recorded = <_PortalRecordedRequest>[];
      final api = PortalApi(
        httpClient: _portalRecordingClient(
          recorded,
          expectedBearer: 'pasted-token',
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: PortalScreen(api: api, redirectMissingSessionToLogin: false),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'pasted-token');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      _expectSingleValidationGetMe(recorded);
      expect(
        recorded.where((r) => r.method == 'POST'),
        isEmpty,
        reason: 'zero POSTs — in particular zero /auth/login',
      );
      expect(
        recorded.every((r) => r.path.startsWith('/me')),
        isTrue,
        reason: 'all other traffic (if any) is a /me-rooted GET BFF read',
      );
    },
  );

  testWidgets('stored-session resume issues zero POSTs and exactly one GET /me '
      'validation (REQ-3/AC-2)', (tester) async {
    Session.store('still-valid-token', clientId: 'portal-client');
    final recorded = <_PortalRecordedRequest>[];
    final api = PortalApi(
      httpClient: _portalRecordingClient(
        recorded,
        expectedBearer: 'still-valid-token',
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: PortalScreen(api: api, redirectMissingSessionToLogin: false),
      ),
    );
    await tester.pumpAndSettle();

    _expectSingleValidationGetMe(recorded);
    expect(
      recorded.where((r) => r.method == 'POST'),
      isEmpty,
      reason: 'zero POSTs — in particular zero /auth/login',
    );
    expect(
      recorded.every((r) => r.path.startsWith('/me')),
      isTrue,
      reason: 'all other traffic (if any) is a /me-rooted GET BFF read',
    );
  });
}
