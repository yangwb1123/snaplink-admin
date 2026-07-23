import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';

void main() {
  test('keeps advanced RFC 7591 metadata on client registration', () async {
    final api = DeveloperApi(
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/register');
        expect(request.headers['authorization'], 'Bearer bootstrap-token');
        expect(jsonDecode(request.body), {
          'grant_types': ['authorization_code', 'refresh_token'],
          'require_pkce': true,
          'client_name': 'Acme app',
          'redirect_uris': ['https://app.example.test/callback'],
          'scope': 'openid profile',
          'token_endpoint_auth_method': 'none',
          'token_strategy': 'jwt',
        });
        return http.Response('{"client_id":"client-1"}', 201);
      }),
    );

    final result = await api.register(
      clientName: 'Acme app',
      redirectUris: ['https://app.example.test/callback'],
      scope: 'openid profile',
      tokenEndpointAuthMethod: 'none',
      tokenStrategy: 'jwt',
      additionalMetadata: {
        'grant_types': ['authorization_code', 'refresh_token'],
        'require_pkce': true,
      },
      initialAccessToken: 'bootstrap-token',
    );

    expect(result['client_id'], 'client-1');
  });

  test(
    'sends client_secret_post as the selected RFC 7591 auth method',
    () async {
      final api = DeveloperApi(
        httpClient: MockClient((request) async {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['token_endpoint_auth_method'], 'client_secret_post');
          return http.Response('{"client_id":"client-post"}', 201);
        }),
      );

      final result = await api.register(
        clientName: 'Post client',
        redirectUris: ['https://post.example.test/callback'],
        scope: 'openid',
        tokenEndpointAuthMethod: 'client_secret_post',
        tokenStrategy: 'jwt',
      );

      expect(result['client_id'], 'client-post');
    },
  );
}
