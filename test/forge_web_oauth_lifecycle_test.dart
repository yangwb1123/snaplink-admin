@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/services/forge_oauth_token_refresh.dart';
import 'package:sso_admin/session.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  setUp(Session.clear);
  tearDown(Session.clear);

  test(
    'Web sessionStorage survives Forge refresh and isolates sign-out',
    () async {
      final store = ForgeCredentialStore(forcePersistentStorage: false);
      expect(
        Session.store(
          'admin-access',
          clientId: SSOAdminClient.firstPartyClientId,
        ),
        isTrue,
      );
      expect(
        await store.store(
          accessToken: 'old-access',
          sessionId: 'forge-session',
          refreshToken: 'old-refresh',
        ),
        isTrue,
      );

      // A new store instance models a cold route mount in the same browser tab.
      final restoredStore = ForgeCredentialStore(forcePersistentStorage: false);
      expect(await restoredStore.restore(), 'old-access');
      expect(
        Session.readRefreshTokenForClient(ForgeConversationsOAuth.clientId),
        'old-refresh',
      );

      var conversationRequests = 0;
      final refresh = ForgeOAuthTokenRefresh(
        baseUrl: 'https://sso.example',
        credentialStore: restoredStore,
        httpClient: MockClient((request) async {
          if (request.url.path == '/token') {
            expect(request.bodyFields['refresh_token'], 'old-refresh');
            return _json({
              'access_token': 'new-access',
              'refresh_token': 'new-refresh',
              'token_type': 'Bearer',
              'expires_in': 900,
            });
          }
          throw StateError('Unexpected OAuth request: ${request.url}');
        }),
      );
      addTearDown(refresh.close);

      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'old-access',
        accessTokenProvider: () =>
            Session.readForClient(ForgeConversationsOAuth.clientId),
        refreshAccessToken: refresh.refreshAfterUnauthorized,
        httpClient: MockClient((request) async {
          expect(request.url.path, '/api/v1/conversations');
          conversationRequests++;
          if (conversationRequests == 1) return _json({}, status: 401);
          expect(request.headers['authorization'], 'Bearer new-access');
          return _json({'conversations': <Object>[], 'has_more': false});
        }),
      );
      addTearDown(api.close);

      final page = await api.listConversations();
      expect(page.conversations, isEmpty);
      expect(conversationRequests, 2);
      expect(
        Session.readForClient(ForgeConversationsOAuth.clientId),
        'new-access',
      );
      expect(
        Session.readRefreshTokenForClient(ForgeConversationsOAuth.clientId),
        'new-refresh',
      );
      expect(Session.read(), 'admin-access');

      await restoredStore.clear();
      expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
      expect(
        Session.readRefreshTokenForClient(ForgeConversationsOAuth.clientId),
        isNull,
      );
      expect(Session.read(), 'admin-access');
    },
  );
}
