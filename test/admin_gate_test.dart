import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/admin/admin_gate.dart';
import 'package:sso_admin/screens/oidc_login/oauth_params.dart';

void main() {
  test('preserves an Admin deep link and repeated safe query values', () {
    final login = Uri.parse(
      adminLoginLocation(
        Uri.parse(
          'https://console.example/admin/users/u1/sessions?tab=security&'
          'tab=activity&token=do-not-forward#fragment',
        ),
      ),
    );

    expect(login.path, '/login/');
    expect(login.fragment, isEmpty);
    expect(login.queryParametersAll['resource'], [
      'billing-api',
      'stripe-adapter-api',
    ]);
    final target = Uri.parse(login.queryParameters['redirect']!);
    expect(target.path, '/admin/users/u1/sessions');
    expect(target.queryParametersAll, {
      'tab': ['security', 'activity'],
    });
    expect(login.toString(), isNot(contains('do-not-forward')));
  });

  test('custom Admin resources survive the hosted-login JSON payload', () {
    final login = Uri.parse(
      adminLoginLocation(
        Uri.parse('https://console.example/admin/commerce'),
        resources: const ['https://billing.example', 'https://stripe.example'],
      ),
    );

    final payload = OAuthParams.fromUri(login).toLoginPayload('password');

    expect(payload['resource'], [
      'https://billing.example',
      'https://stripe.example',
    ]);
  });

  test('falls back to the Admin root for a non-Admin location', () {
    final login = Uri.parse(
      adminLoginLocation(
        Uri.parse(
          'https://console.example/other?access_token=bearer&x=ignored',
        ),
      ),
    );

    expect(Uri.parse(login.queryParameters['redirect']!).path, '/admin/');
    expect(login.toString(), isNot(contains('bearer')));
    expect(login.toString(), isNot(contains('ignored')));
  });

  test('keeps an encoded slash inside an Admin resource id', () {
    final login = Uri.parse(
      adminLoginLocation(
        Uri.parse(
          'https://console.example/admin/clients/team%2Fwest%20console',
        ),
      ),
    );
    final target = Uri.parse(login.queryParameters['redirect']!);

    expect(target.pathSegments, ['admin', 'clients', 'team/west console']);
    expect(target.toString(), contains('team%2Fwest%20console'));
  });
}
