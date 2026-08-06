import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/authorization_delivery.dart';
import 'package:sso_admin/screens/oidc_login/jarm_completion.dart';
import 'package:sso_admin/screens/oidc_login/oauth_params.dart';

void main() {
  test('plain success retains the redirect URI the server just validated', () {
    final delivery = resolveAuthorizationDelivery(
      request: _request(
        'client_id=rp&response_type=code&state=browser-state&'
        'redirect_uri=https%3A%2F%2Frp.example%2Fcb',
      ),
      response: const {'code': 'code', 'state': 'server-state'},
      errorResponse: false,
      tokenResponse: false,
    );

    expect(delivery?.redirectUri, Uri.parse('https://rp.example/cb'));
    expect(delivery?.responseMode, 'query');
  });

  test('plain error still requires explicit redirect validation', () {
    final request = _request(
      'client_id=rp&response_type=code&'
      'redirect_uri=https%3A%2F%2Frp.example%2Fcb',
    );

    expect(
      resolveAuthorizationDelivery(
        request: request,
        response: const {'error': 'access_denied'},
        errorResponse: true,
        tokenResponse: false,
      ),
      isNull,
    );
    expect(
      resolveAuthorizationDelivery(
        request: request,
        response: const {
          'error': 'access_denied',
          'redirect_uri_validated': true,
        },
        errorResponse: true,
        tokenResponse: false,
      ),
      isNotNull,
    );
  });

  test('PAR never falls back to attacker-controlled browser parameters', () {
    final request = _request(
      'client_id=rp&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3A1&'
      'state=attacker-state&'
      'redirect_uri=https%3A%2F%2Fattacker.example%2Fsteal',
    );

    expect(
      resolveAuthorizationDelivery(
        request: request,
        response: const {'code': 'code', 'state': 'server-state'},
        errorResponse: false,
        tokenResponse: false,
      ),
      isNull,
    );
  });

  test('PAR uses only the effective target and mode attested by Snaplink', () {
    final delivery = resolveAuthorizationDelivery(
      request: _request(
        'client_id=rp&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3A1&'
        'redirect_uri=https%3A%2F%2Fattacker.example%2Fsteal',
      ),
      response: const {
        'code': 'code',
        'redirect_uri': 'https://rp.example/callback?from=registered',
        'response_mode': 'query',
        'redirect_uri_validated': true,
      },
      errorResponse: false,
      tokenResponse: false,
    );

    expect(
      delivery?.redirectUri,
      Uri.parse('https://rp.example/callback?from=registered'),
    );
    expect(delivery?.responseMode, 'query');
  });

  test('server metadata fails closed without proof or with unsafe targets', () {
    final request = _request(
      'client_id=rp&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3A1',
    );

    for (final response in <Map<String, dynamic>>[
      {'redirect_uri': 'https://rp.example/cb', 'response_mode': 'query'},
      {
        'redirect_uri': 'javascript:alert(1)',
        'response_mode': 'query',
        'redirect_uri_validated': true,
      },
      {
        'redirect_uri': 'https://rp.example/cb',
        'response_mode': 'unknown',
        'redirect_uri_validated': true,
      },
    ]) {
      expect(
        resolveAuthorizationDelivery(
          request: request,
          response: response,
          errorResponse: false,
          tokenResponse: false,
        ),
        isNull,
      );
    }
  });

  test('keeps registered native schemes and the IPv4 loopback range', () {
    for (final target in ['com.example.app:', 'http://127.0.0.2/callback']) {
      final delivery = resolveAuthorizationDelivery(
        request: _request(
          'client_id=rp&response_type=code&redirect_uri='
          '${Uri.encodeQueryComponent(target)}',
        ),
        response: const {'code': 'code'},
        errorResponse: false,
        tokenResponse: false,
      );
      expect(delivery?.redirectUri.toString(), target);
    }
  });

  test('plain form_post requires the exact registered action and fields', () {
    const valid = '''<!doctype html>
      <form method="POST" action="https://rp.example/callback?x=1">
        <input type="hidden" name="code" value="c">
        <input type="hidden" name="state" value="s">
        <input type="hidden" name="iss" value="https://as.example">
      </form>''';
    expect(
      isTrustedAuthorizationFormPost(
        valid,
        Uri.parse('https://rp.example/callback?x=1'),
      ),
      isTrue,
    );
    expect(
      isTrustedAuthorizationFormPost(
        valid.replaceAll(
          'https://rp.example/callback?x=1',
          'https://evil.example/steal',
        ),
        Uri.parse('https://rp.example/callback?x=1'),
      ),
      isFalse,
    );
    expect(
      isTrustedAuthorizationFormPost(
        valid.replaceAll('name="iss"', 'name="access_token"'),
        Uri.parse('https://rp.example/callback?x=1'),
      ),
      isFalse,
    );
    expect(
      isTrustedAuthorizationFormPost(
        valid
            .replaceFirst('name="state"', 'name="state"')
            .replaceFirst(
              '<input type="hidden" name="iss"',
              '<input type="hidden" name="state" value="duplicate">'
                  '<input type="hidden" name="iss"',
            ),
        Uri.parse('https://rp.example/callback?x=1'),
      ),
      isFalse,
    );
  });
}

OAuthParams _request(String query) =>
    OAuthParams.fromUri(Uri.parse('https://console.example/login/?$query'));
