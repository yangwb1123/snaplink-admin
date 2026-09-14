import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/services/forge_oauth_token_refresh.dart';
import 'package:sso_admin/session.dart';

http.Response _tokenReply({
  String accessToken = 'new-access',
  String refreshToken = 'rotated-refresh',
}) => http.Response(
  jsonEncode({
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'token_type': 'Bearer',
    'expires_in': 900,
  }),
  200,
  headers: const {'content-type': 'application/json'},
);

void main() {
  setUp(() {
    Session.clear();
  });

  tearDown(() {
    Session.clear();
  });

  test(
    'rotates the client refresh token through Snaplink public grant',
    () async {
      late http.Request sentRequest;
      final service = ForgeOAuthTokenRefresh(
        baseUrl: 'https://sso.example',
        httpClient: MockClient((request) async {
          sentRequest = request;
          return _tokenReply();
        }),
      );
      addTearDown(service.close);
      expect(
        Session.store('admin-access', clientId: 'sso-admin-console'),
        isTrue,
      );
      expect(
        Session.storeForClient(
          'forge-console',
          'old-access',
          sessionId: 'forge-session',
          refreshToken: 'old-refresh',
        ),
        isTrue,
      );

      final refreshed = await service.refreshAfterUnauthorized('old-access');

      expect(refreshed, 'new-access');
      expect(sentRequest.method, 'POST');
      expect(sentRequest.url, Uri.parse('https://sso.example/token'));
      expect(sentRequest.followRedirects, isFalse);
      expect(sentRequest.headers['cache-control'], 'no-store');
      expect(sentRequest.bodyFields, {
        'grant_type': 'refresh_token',
        'client_id': 'forge-console',
        'refresh_token': 'old-refresh',
      });
      expect(sentRequest.body, isNot(contains('client_secret')));
      expect(Session.readForClient('forge-console'), 'new-access');
      expect(
        Session.readRefreshTokenForClient('forge-console'),
        'rotated-refresh',
      );
      expect(Session.readSessionIdForClient('forge-console'), 'forge-session');
      expect(Session.read(), 'admin-access');
    },
  );

  test('concurrent unauthorized calls share a single token rotation', () async {
    final response = Completer<http.Response>();
    var requestCount = 0;
    final service = ForgeOAuthTokenRefresh(
      baseUrl: 'https://sso.example',
      httpClient: MockClient((_) {
        requestCount++;
        return response.future;
      }),
    );
    addTearDown(service.close);
    Session.storeForClient(
      'forge-console',
      'old-access',
      refreshToken: 'old-refresh',
    );

    final first = service.refreshAfterUnauthorized('old-access');
    final second = service.refreshAfterUnauthorized('old-access');
    await Future<void>.delayed(Duration.zero);
    response.complete(_tokenReply());

    expect(await first, 'new-access');
    expect(await second, 'new-access');
    expect(requestCount, 1);
  });

  test(
    'revokes latest access and refresh tokens in order after rotation',
    () async {
      final rotationResponse = Completer<http.Response>();
      final revocationRequests = <http.Request>[];
      var rotationCount = 0;
      final service = ForgeOAuthTokenRefresh(
        baseUrl: 'https://sso.example',
        httpClient: MockClient((request) async {
          if (request.url.path == '/token') {
            rotationCount++;
            return rotationResponse.future;
          }
          revocationRequests.add(request);
          return http.Response('', 200);
        }),
      );
      addTearDown(service.close);
      Session.store('admin-access', clientId: 'sso-admin-console');
      Session.storeForClient(
        'forge-console',
        'old-access',
        refreshToken: 'old-refresh',
      );

      final refresh = service.refreshAfterUnauthorized('old-access');
      await Future<void>.delayed(Duration.zero);
      final revoke = service.revokeCurrentTokens();
      expect(await service.refreshAfterUnauthorized('new-access'), isNull);
      rotationResponse.complete(_tokenReply(refreshToken: 'new-refresh'));

      expect(await refresh, 'new-access');
      await revoke;
      expect(rotationCount, 1);
      expect(revocationRequests, hasLength(2));
      expect(revocationRequests.map((request) => request.bodyFields), [
        {
          'token': 'new-access',
          'token_type_hint': 'access_token',
          'client_id': 'forge-console',
        },
        {
          'token': 'new-refresh',
          'token_type_hint': 'refresh_token',
          'client_id': 'forge-console',
        },
      ]);
      for (final request in revocationRequests) {
        expect(request.method, 'POST');
        expect(request.url, Uri.parse('https://sso.example/token/revoke'));
        expect(request.followRedirects, isFalse);
        expect(request.headers['cache-control'], 'no-store');
        expect(request.body, isNot(contains('client_secret')));
        expect(request.body, isNot(contains('admin-access')));
      }
      expect(Session.readRefreshTokenForClient('forge-console'), 'new-refresh');
      expect(Session.read(), 'admin-access');
    },
  );

  test(
    'access revocation failure does not prevent refresh revocation',
    () async {
      final revocationRequests = <http.Request>[];
      final service = ForgeOAuthTokenRefresh(
        baseUrl: 'https://sso.example',
        httpClient: MockClient((request) async {
          revocationRequests.add(request);
          if (request.bodyFields['token_type_hint'] == 'access_token') {
            throw http.ClientException('offline');
          }
          return http.Response('', 200);
        }),
      );
      addTearDown(service.close);
      Session.store('admin-access', clientId: 'sso-admin-console');
      Session.storeForClient(
        'forge-console',
        'forge-access',
        refreshToken: 'forge-refresh',
      );

      await service.revokeCurrentTokens();
      expect(
        revocationRequests.map(
          (request) => request.bodyFields['token_type_hint'],
        ),
        ['access_token', 'refresh_token'],
      );
      expect(revocationRequests.map((request) => request.bodyFields['token']), [
        'forge-access',
        'forge-refresh',
      ]);
      expect(Session.readForClient('forge-console'), 'forge-access');
      expect(
        Session.readRefreshTokenForClient('forge-console'),
        'forge-refresh',
      );
      expect(Session.read(), 'admin-access');
    },
  );

  test('failed rotation clears only the Forge client slot', () async {
    final service = ForgeOAuthTokenRefresh(
      baseUrl: 'https://sso.example',
      httpClient: MockClient(
        (_) async => http.Response('{"error":"invalid_grant"}', 400),
      ),
    );
    addTearDown(service.close);
    Session.store('admin-access', clientId: 'sso-admin-console');
    Session.storeForClient(
      'forge-console',
      'old-access',
      refreshToken: 'spent-refresh',
    );

    expect(await service.refreshAfterUnauthorized('old-access'), isNull);
    expect(Session.readForClient('forge-console'), isNull);
    expect(Session.readRefreshTokenForClient('forge-console'), isNull);
    expect(Session.read(), 'admin-access');
  });

  test(
    'invalid_grant stays an unauthorized result and does not replay Forge',
    () async {
      var forgeRequestCount = 0;
      final refresh = ForgeOAuthTokenRefresh(
        baseUrl: 'https://sso.example',
        httpClient: MockClient(
          (_) async => http.Response('{"error":"invalid_grant"}', 400),
        ),
      );
      addTearDown(refresh.close);
      Session.store('admin-access', clientId: 'sso-admin-console');
      Session.storeForClient(
        'forge-console',
        'old-access',
        refreshToken: 'revoked-refresh',
      );
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'old-access',
        accessTokenProvider: () =>
            Session.readForClient('forge-console') ?? 'old-access',
        refreshAccessToken: refresh.refreshAfterUnauthorized,
        httpClient: MockClient((_) async {
          forgeRequestCount++;
          return http.Response('{"code":"unauthorized"}', 401);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.listConversations(),
        throwsA(
          isA<ForgeConversationsApiException>().having(
            (error) => error.statusCode,
            'statusCode',
            401,
          ),
        ),
      );

      expect(forgeRequestCount, 1);
      expect(Session.readForClient('forge-console'), isNull);
      expect(Session.readRefreshTokenForClient('forge-console'), isNull);
      expect(Session.read(), 'admin-access');
    },
  );

  test('rejects insecure non-loopback token origins', () {
    expect(
      () => ForgeOAuthTokenRefresh(baseUrl: 'http://sso.example'),
      throwsArgumentError,
    );
    final loopback = ForgeOAuthTokenRefresh(baseUrl: 'http://localhost:8123');
    loopback.close();
  });
}
