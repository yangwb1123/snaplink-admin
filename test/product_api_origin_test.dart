import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/device_verify_api.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/api/portal_api.dart';
import 'package:sso_admin/api/setup_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';
import 'package:sso_admin/services/product_api_origin.dart';

void main() {
  late String? originalOverride;

  setUp(() {
    originalOverride = AppSettings.instance.ssoBaseUrlOverride;
  });

  tearDown(() {
    AppSettings.instance.ssoBaseUrlOverride = originalOverride;
  });

  test('normalizes secure and loopback service origins', () {
    expect(
      AppSettings.normalizeSsoBaseUrl(' HTTPS://SSO.Example.test:8443/ '),
      'https://sso.example.test:8443',
    );
    expect(
      AppSettings.normalizeSsoBaseUrl('http://localhost:8080/'),
      'http://localhost:8080',
    );
    expect(
      AppSettings.normalizeSsoBaseUrl('http://127.12.34.56:9000'),
      'http://127.12.34.56:9000',
    );
    expect(
      AppSettings.normalizeSsoBaseUrl('http://[::1]:9000'),
      'http://[::1]:9000',
    );
    expect(AppSettings.normalizeSsoBaseUrl('  '), isNull);
  });

  test('rejects unsafe or path-scoped service origins', () {
    for (final value in [
      'http://sso.example.test',
      'http://127.example.test',
      'https://operator:secret@sso.example.test',
      'https://sso.example.test/api',
      'https://sso.example.test?tenant=acme',
      'https://sso.example.test/#fragment',
      'ftp://sso.example.test',
      'sso.example.test',
    ]) {
      expect(
        () => AppSettings.normalizeSsoBaseUrl(value),
        throwsFormatException,
        reason: value,
      );
    }
  });

  test('native default and admin client follow the configured origin', () {
    AppSettings.instance.ssoBaseUrlOverride = null;
    expect(ProductApiOrigin.baseUrl, ProductApiOrigin.nativeDefaultBaseUrl);

    AppSettings.instance.ssoBaseUrlOverride =
        'https://native.example.test:8443/';
    expect(ProductApiOrigin.baseUrl, 'https://native.example.test:8443');
    expect(
      SSOAdminClient.withToken('token').baseUrl,
      'https://native.example.test:8443',
    );
  });

  test(
    'all default product API clients use the configured native origin',
    () async {
      AppSettings.instance.ssoBaseUrlOverride =
          'https://native.example.test:8443';
      final requested = <Uri>[];
      final transport = MockClient((request) async {
        requested.add(request.url);
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":false}', 200);
        }
        if (request.url.path == '/.well-known/openid-configuration') {
          return http.Response('{}', 200);
        }
        if (request.url.path == '/device/verify') {
          return http.Response('{"status":"pending"}', 200);
        }
        return http.Response('{}', 200);
      });

      final login = OidcLoginApi(httpClient: transport);
      addTearDown(login.close);
      await login.loadBranding();
      await PortalApi(httpClient: transport).login('user-token');
      await SetupApi(client: transport).checkStatus();
      await DeviceVerifyApi(httpClient: transport).check('ABCD-1234');
      await DeveloperApi(httpClient: transport).loadDiscovery();

      expect(requested, hasLength(5));
      for (final url in requested) {
        expect(url.scheme, 'https', reason: url.toString());
        expect(url.host, 'native.example.test', reason: url.toString());
        expect(url.port, 8443, reason: url.toString());
      }
      expect(requested.map((url) => url.path), [
        '/branding',
        '/me',
        '/api/v1/setup/status',
        '/device/verify',
        '/.well-known/openid-configuration',
      ]);
    },
  );
}
