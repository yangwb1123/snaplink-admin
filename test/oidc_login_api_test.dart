import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_api.dart';

void main() {
  test('sends Snaplink MFA fields at their documented top level', () async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/mfa');
        expect(jsonDecode(request.body), {
          'mfa_challenge_id': 'challenge-1',
          'mfa_method': 'totp',
          'code': '123456',
          'trust_device': true,
        });
        return http.Response('{"access_token":"access"}', 200);
      }),
    );

    final result = await api.mfaComplete(
      mfaChallengeId: 'challenge-1',
      method: 'totp',
      code: '123456',
      trustDevice: true,
    );

    expect(result.ok, isTrue);
  });

  test('supports opaque WebAuthn MFA parameters', () async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['mfa_method'], 'webauthn');
        expect(body['params'], {
          'session': 'ceremony-session',
          'assertion': '{"id":"credential"}',
        });
        return http.Response('{}', 400);
      }),
    );

    final result = await api.mfaComplete(
      mfaChallengeId: 'challenge-2',
      method: 'webauthn',
      params: {
        'session': 'ceremony-session',
        'assertion': '{"id":"credential"}',
      },
    );

    expect(result.status, 400);
  });

  test('preserves the server-generated form-post response document', () async {
    final api = OidcLoginApi(
      httpClient: MockClient(
        (_) async => http.Response(
          '<form method="post"><input name="code" value="one"></form>',
          200,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      ),
    );

    final result = await api.login({'client_id': 'rp', 'provider': 'password'});

    expect(result.ok, isTrue);
    expect(result.isFormPost, isTrue);
    expect(result.html, contains('name="code"'));
  });

  test(
    'starts Snaplink discoverable WebAuthn login at its ceremony route',
    () async {
      final api = OidcLoginApi(
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/webauthn/login/conditional/begin');
          return http.Response(
            '{"session_id":"passkey-session","options":{"publicKey":{"challenge":"AQ"}}}',
            200,
          );
        }),
      );

      final result = await api.beginPasswordlessWebAuthn();

      expect(result.ok, isTrue);
      expect(result.data['session_id'], 'passkey-session');
    },
  );

  test(
    'sends code-provider delivery requests to the Snaplink auth route',
    () async {
      final api = OidcLoginApi(
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/send-code');
          expect(jsonDecode(request.body), {
            'provider': 'email',
            'target': 'person@example.test',
          });
          return http.Response('{"status":"sent"}', 200);
        }),
      );

      final result = await api.sendCode('email', 'person@example.test');

      expect(result.ok, isTrue);
    },
  );

  test('submits a reset token with its replacement password', () async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/auth/reset-password');
        expect(jsonDecode(request.body), {
          'token': 'reset-token',
          'new_password': 'a-new-password',
        });
        return http.Response('{"status":"ok"}', 200);
      }),
    );

    final result = await api.resetPassword('reset-token', 'a-new-password');

    expect(result.ok, isTrue);
  });

  test(
    'consumes a signup email-verification token at its distinct route',
    () async {
      final api = OidcLoginApi(
        httpClient: MockClient((request) async {
          expect(request.url.path, '/auth/verify-email');
          expect(jsonDecode(request.body), {'token': 'verification-token'});
          return http.Response('{"status":"verified"}', 200);
        }),
      );

      final result = await api.verifyEmail('verification-token');

      expect(result.ok, isTrue);
      expect(result.data['status'], 'verified');
    },
  );

  test('sends Snaplink push-MFA approval identifiers as parameters', () async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/auth/mfa');
        expect(jsonDecode(request.body), {
          'mfa_challenge_id': 'push-challenge',
          'mfa_method': 'push',
          'params': {'approval_id': 'approval-1'},
        });
        return http.Response('{"access_token":"access"}', 200);
      }),
    );

    final result = await api.mfaComplete(
      mfaChallengeId: 'push-challenge',
      method: 'push',
      params: {'approval_id': 'approval-1'},
    );

    expect(result.ok, isTrue);
  });

  test('uses the non-enumerating B2B home-realm route', () async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/home-realm');
        expect(jsonDecode(request.body), {'login_hint': 'user@acme.test'});
        return http.Response('{"found":true,"connection_id":"acme-oidc"}', 200);
      }),
    );

    final result = await api.discoverHomeRealm('user@acme.test');

    expect(result.ok, isTrue);
    expect(result.data['connection_id'], 'acme-oidc');
  });

  test('passes an RP login hint into provider discovery', () async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/auth/login');
        expect(jsonDecode(request.body), {
          'client_id': 'rp-client',
          'login_hint': 'person@acme.test',
        });
        return http.Response(
          '{"connection_required":true,"connection_id":"acme-oidc"}',
          200,
        );
      }),
    );

    final result = await api.probeProviders(
      'rp-client',
      loginHint: 'person@acme.test',
    );

    expect(result.data['connection_required'], isTrue);
  });

  test('loads public host branding without a bearer token', () async {
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/branding');
        expect(request.headers.containsKey('authorization'), isFalse);
        return http.Response(
          '{"branding":{"brand_name":"Acme","primary_color":"#ff5722"}}',
          200,
        );
      }),
    );

    expect(await api.loadBranding(), {
      'brand_name': 'Acme',
      'primary_color': '#ff5722',
    });
  });
}
