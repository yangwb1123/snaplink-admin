import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/developer/dcr_models.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';

void main() {
  final baseUri = Uri.parse('https://sso.example');

  test('keeps advanced RFC 7591 metadata on client registration', () async {
    final api = DeveloperApi(
      baseUri: baseUri,
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
        baseUri: baseUri,
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

  test('registerMetadata sends the complete typed RFC 7591 contract', () async {
    final api = DeveloperApi(
      baseUri: baseUri,
      httpClient: MockClient((request) async {
        expect(jsonDecode(request.body), {
          'custom_metadata': 'expert',
          'client_name': 'Native app',
          'redirect_uris': ['com.example.app:/oauth/callback'],
          'scope': 'openid offline_access',
          'token_endpoint_auth_method': 'none',
          'token_strategy': 'jwt',
          'grant_types': ['authorization_code', 'refresh_token'],
          'response_types': ['code'],
          'contacts': ['dev@example.com'],
          'post_logout_redirect_uris': ['com.example.app:/signed-out'],
          'allowed_authenticators': ['webauthn'],
          'allowed_resources': ['https://api.example'],
          'tenant_id': 'tenant-a',
          'require_pkce': true,
        });
        return http.Response(
          '{"client_id":"native-1","registration_access_token":"rat"}',
          201,
        );
      }),
    );

    final result = await api.registerMetadata(
      metadata: const DcrClientMetadata(
        clientName: 'Native app',
        redirectUris: ['com.example.app:/oauth/callback'],
        scope: 'openid offline_access',
        tokenEndpointAuthMethod: 'none',
        tokenStrategy: 'jwt',
        grantTypes: ['authorization_code', 'refresh_token'],
        responseTypes: ['code'],
        contacts: ['dev@example.com'],
        postLogoutRedirectUris: ['com.example.app:/signed-out'],
        allowedAuthenticators: ['webauthn'],
        allowedResources: ['https://api.example'],
        tenantId: 'tenant-a',
        requirePkce: false,
        expertMetadata: {'custom_metadata': 'expert'},
      ),
    );

    expect(result['registration_access_token'], 'rat');
  });

  test('loads discovery from the current OpenID Provider', () async {
    final api = DeveloperApi(
      baseUri: baseUri,
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://sso.example/.well-known/openid-configuration',
        );
        return http.Response(
          '{"registration_endpoint":"https://sso.example/register",'
          '"grant_types_supported":["authorization_code"],'
          '"response_types_supported":["code"],'
          '"token_endpoint_auth_methods_supported":["none"],'
          '"code_challenge_methods_supported":["S256"]}',
          200,
        );
      }),
    );

    final discovery = await api.loadDiscovery();

    expect(discovery.registrationEnabled, isTrue);
    expect(discovery.tokenEndpointAuthMethods, ['none']);
  });

  test('PUT sends the guarded typed body and exposes a rotated RAT', () async {
    final body = {
      'client_name': 'Acme',
      'grant_types': ['authorization_code'],
      'redirect_uris': ['https://app.example/callback'],
    };
    final api = DeveloperApi(
      baseUri: baseUri,
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/register/client%20id');
        expect(request.headers['authorization'], 'Bearer old-rat');
        expect(jsonDecode(request.body), body);
        return http.Response(
          '{"client_id":"client id",'
          '"registration_access_token":"new-rat"}',
          200,
        );
      }),
    );

    final response = await api.saveApp(
      clientId: 'client id',
      token: 'old-rat',
      body: body,
    );

    expect(response['registration_access_token'], 'new-rat');
  });

  test('only 401 and 404 classify management credentials as invalid', () {
    expect(
      DeveloperApiError(401, null, null).isInvalidManagementCredential,
      isTrue,
    );
    expect(
      DeveloperApiError(404, null, null).isInvalidManagementCredential,
      isTrue,
    );
    expect(
      DeveloperApiError(403, null, null).isInvalidManagementCredential,
      isFalse,
    );
    expect(
      DeveloperApiError(500, null, null).isInvalidManagementCredential,
      isFalse,
    );
    expect(DeveloperApiError(500, null, null).isRetryable, isTrue);
  });

  test('times out a registration mutation without replaying it', () async {
    var calls = 0;
    final api = DeveloperApi(
      baseUri: baseUri,
      timeout: const Duration(milliseconds: 1),
      httpClient: MockClient((_) async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{"client_id":"late"}', 201);
      }),
    );

    await expectLater(
      api.register(
        clientName: 'Slow app',
        redirectUris: const ['https://slow.example/callback'],
        scope: 'openid',
        tokenEndpointAuthMethod: 'client_secret_basic',
        tokenStrategy: 'jwt',
      ),
      throwsA(isA<TimeoutException>()),
    );
    await Future<void>.delayed(const Duration(milliseconds: 25));
    expect(calls, 1);
  });
}
