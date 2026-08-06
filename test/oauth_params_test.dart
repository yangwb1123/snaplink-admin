import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/oauth_params.dart';

void main() {
  test('preserves Snaplink authorization request extensions in login JSON', () {
    final params = OAuthParams.fromUri(
      Uri.parse(
        'https://console.example/login/?client_id=rp&scope=openid%20profile'
        '&response_type=code&redirect_uri=https%3A%2F%2Frp.example%2Fcb'
        '&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Aone'
        '&prompt=login&max_age=300&login_hint=person%40example.test'
        '&response_mode=form_post&acr_values=urn%3Aacr%3Astrong'
        '&ui_locales=en-US%20zh-CN'
        '&authorization_details=%5B%7B%22type%22%3A%22payment%22%7D%5D'
        '&claims=%7B%22id_token%22%3A%7B%22acr%22%3A%7B%22essential%22%3Atrue%7D%7D%7D'
        '&device_token=trusted-device',
      ),
    );

    final payload = params.toLoginPayload('password');

    expect(payload['request_uri'], 'urn:ietf:params:oauth:request_uri:one');
    expect(payload['prompt'], 'login');
    expect(payload['max_age'], 300);
    expect(payload['response_mode'], 'form_post');
    expect(payload['authorization_details'], [
      {'type': 'payment'},
    ]);
    expect(payload['claims'], {
      'id_token': {
        'acr': {'essential': true},
      },
    });
    expect(payload, isNot(contains('device_token')));
  });

  test('recognizes prompt none among OIDC prompt values', () {
    expect(
      OAuthParams.fromUri(
        Uri.parse('https://console.example/login?prompt=none'),
      ).hasPromptNone,
      isTrue,
    );
    expect(
      OAuthParams.fromUri(
        Uri.parse('https://console.example/login?prompt=login%20consent'),
      ).hasPromptNone,
      isFalse,
    );
  });

  test('projects every authorization extension into federated navigation', () {
    final params = OAuthParams.fromUri(
      Uri.parse(
        'https://console.example/login/?client_id=rp&scope=openid%20profile'
        '&response_type=code&redirect_uri=https%3A%2F%2Frp.example%2Fcb'
        '&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Aone'
        '&request=signed.request.jwt&resource=https%3A%2F%2Fapi.one'
        '&resource=https%3A%2F%2Fapi.two&prompt=login&max_age=300'
        '&id_token_hint=id-token&authorization_details=%5B%7B%22type%22%3A%22payment%22%7D%5D'
        '&claims=%7B%22userinfo%22%3A%7B%22email%22%3Anull%7D%7D',
      ),
    );

    final target = Uri.parse(
      'https://as.example/auth/login',
    ).replace(queryParameters: params.toFederatedLoginQuery('workforce'));

    expect(target.queryParameters['provider'], 'workforce');
    expect(target.queryParameters['request'], 'signed.request.jwt');
    expect(target.queryParameters['request_uri'], contains('request_uri:one'));
    expect(target.queryParameters['id_token_hint'], 'id-token');
    expect(target.queryParameters['max_age'], '300');
    expect(
      target.queryParameters['authorization_details'],
      '[{"type":"payment"}]',
    );
    expect(target.queryParameters['claims'], '{"userinfo":{"email":null}}');
    expect(target.queryParametersAll['resource'], [
      'https://api.one',
      'https://api.two',
    ]);
  });
}
