import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/app_router.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/services/app_navigator.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/services/product_entry_route.dart';
import 'package:sso_admin/session.dart';

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('native Forge navigation requests the scoped Forge login', (
    tester,
  ) async {
    final loginApi = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response('{"providers":[]}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(loginApi.close);
    await tester.runAsync(() async {
      await preloadProductEntry(ProductEntry.forgeSessions);
      await preloadProductEntry(ProductEntry.login);
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        onGenerateRoute: (settings) {
          final location = Uri.tryParse(settings.name ?? '/') ?? Uri(path: '/');
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                resolveProductScreen(location, oidcLoginApi: loginApi),
          );
        },
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => BrowserNavigation.assignLocation('/forge/'),
            child: const Text('Open Forge'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Forge'));
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();

    final login = tester.widget<OidcLoginScreen>(find.byType(OidcLoginScreen));
    final route = login.routeUri!;
    expect(route.path, '/login/');
    expect(route.queryParameters['redirect'], '/forge/');
    expect(
      route.queryParameters['client_id'],
      ForgeConversationsOAuth.clientId,
    );
    expect(route.queryParameters['resource'], ForgeConversationsOAuth.resource);
    expect(
      route.queryParameters['scope']!.split(' '),
      containsAll(ForgeConversationsOAuth.scopes),
    );
    expect(route.queryParameters, isNot(contains('token')));
    expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
  });

  testWidgets('Forge sign-out clears only this client and returns to login', (
    tester,
  ) async {
    Session.store('admin-token', clientId: SSOAdminClient.firstPartyClientId);
    Session.storeForClient(
      ForgeConversationsOAuth.clientId,
      'forge-token',
      sessionId: 'forge-session',
      refreshToken: 'forge-refresh',
    );
    final loginApi = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/auth/login') {
          return http.Response('{"providers":[]}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(loginApi.close);
    final forgeClient = MockClient((request) async {
      expect(request.method, 'GET');
      switch (request.url.path) {
        case '/api/v1/conversations':
          return http.Response(
            '{"conversations":[{"conversation":{"id":"c1","scope":{"kind":"global"},"title":"Private work","created_at_ms":10,"updated_at_ms":20},"aggregate_version":1}],"has_more":false}',
            200,
          );
        case '/api/v1/conversations/c1/prompts':
          return http.Response(
            '{"conversation_id":"c1","prompts":[{"id":"p1","conversation_id":"c1","role":"user","content":"secret","created_at_ms":30}],"has_more":false}',
            200,
          );
        case '/api/v1/conversations/c1/runs':
          return http.Response(
            '{"conversation_id":"c1","runs":[],"has_more":false}',
            200,
          );
        default:
          throw StateError('Unexpected Forge request: ${request.url}');
      }
    });
    addTearDown(forgeClient.close);
    final revokeRequests = <http.Request>[];
    final neverCompletingAccessRevocation = Completer<http.Response>();
    final oauthClient = MockClient((request) async {
      revokeRequests.add(request);
      if (request.bodyFields['token_type_hint'] == 'access_token') {
        return neverCompletingAccessRevocation.future;
      }
      return http.Response('', 200);
    });
    addTearDown(oauthClient.close);
    await tester.runAsync(() async {
      await preloadProductEntry(ProductEntry.forgeSessions);
      await preloadProductEntry(ProductEntry.login);
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: AppNavigator.key,
        onGenerateRoute: (settings) {
          final location = Uri.tryParse(settings.name ?? '/') ?? Uri(path: '/');
          if (location.path == '/forge/') {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => ForgeSessionsScreen(
                accessToken: 'forge-token',
                apiOrigin: 'https://forge.example',
                httpClient: forgeClient,
                oauthHttpClient: oauthClient,
                oauthRevocationTimeout: const Duration(milliseconds: 25),
                // This route test exercises navigation and revocation. Keep
                // the host's real keyring out of the test process.
                credentialStore: ForgeCredentialStore(
                  forcePersistentStorage: false,
                ),
              ),
            );
          }
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (_) =>
                resolveProductScreen(location, oidcLoginApi: loginApi),
          );
        },
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => BrowserNavigation.assignLocation('/forge/'),
            child: const Text('Open Forge'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Forge'));
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Private work'), findsWidgets);
    expect(find.text('secret'), findsOneWidget);
    await tester.tap(find.byTooltip('Sign out of Forge on this device'));
    await tester.pump();
    expect(find.text('Private work'), findsNothing);
    expect(find.text('secret'), findsNothing);
    expect(find.text('Signing out of Forge…'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
    expect(
      Session.readRefreshTokenForClient(ForgeConversationsOAuth.clientId),
      isNull,
    );
    expect(
      Session.readSessionIdForClient(ForgeConversationsOAuth.clientId),
      isNull,
    );
    expect(Session.read(), 'admin-token');
    expect(revokeRequests, hasLength(2));
    expect(revokeRequests.map((request) => request.bodyFields), [
      {
        'token': 'forge-token',
        'token_type_hint': 'access_token',
        'client_id': ForgeConversationsOAuth.clientId,
      },
      {
        'token': 'forge-refresh',
        'token_type_hint': 'refresh_token',
        'client_id': ForgeConversationsOAuth.clientId,
      },
    ]);
    for (final request in revokeRequests) {
      expect(request.method, 'POST');
      expect(request.url.path, '/token/revoke');
      expect(request.body, isNot(contains('admin-token')));
      expect(request.body, isNot(contains('client_secret')));
    }
    expect(find.byType(OidcLoginScreen), findsOneWidget);
    final login = tester.widget<OidcLoginScreen>(find.byType(OidcLoginScreen));
    expect(
      login.routeUri?.queryParameters['client_id'],
      ForgeConversationsOAuth.clientId,
    );
    expect(
      login.routeUri?.queryParameters['resource'],
      ForgeConversationsOAuth.resource,
    );
    expect(
      login.routeUri?.queryParameters['scope']!.split(' '),
      containsAll(ForgeConversationsOAuth.scopes),
    );
    expect(login.routeUri?.queryParameters['redirect'], '/forge/');
  });
}
