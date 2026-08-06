import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/hosted_login_location.dart';
import 'package:sso_admin/screens/oidc_login/hosted_login_models.dart';

void main() {
  group('LoginProviderDescriptor', () {
    test('uses all server-owned provider presentation fields', () {
      final provider = LoginProviderDescriptor.fromWire({
        'id': 'acme-oidc',
        'type': 'oidc',
        'display_name': 'Acme Workforce',
        'icon_url': 'https://cdn.acme.test/icon.svg',
        'button_label': 'Continue with Acme',
        'button_color': '#123456',
        'builtin': false,
      });

      expect(provider.id, 'acme-oidc');
      expect(provider.displayName, 'Acme Workforce');
      expect(provider.effectiveButtonLabel, 'Continue with Acme');
      expect(provider.buttonColor, '#123456');
      expect(provider.isFederated, isTrue);
    });

    test('keeps legacy string provider responses compatible', () {
      final provider = LoginProviderDescriptor.fromWire('magiclink');

      expect(provider.id, 'magiclink');
      expect(provider.displayName, 'Magiclink');
      expect(provider.builtin, isTrue);
    });
  });

  group('hosted URL policy', () {
    final httpsPage = Uri.parse(
      'https://console.example/login/?client_id=rp&resource=one&resource=two',
    );

    test('allows explicit HTTPS and same-origin relative resources', () {
      expect(
        resolveSafeHostedUrl(
          'https://cdn.example/logo.svg',
          httpsPage,
        ).toString(),
        'https://cdn.example/logo.svg',
      );
      expect(
        resolveSafeHostedUrl('/assets/logo.svg', httpsPage).toString(),
        'https://console.example/assets/logo.svg',
      );
    });

    test('rejects unsafe schemes, credentials, and cross-origin HTTP', () {
      expect(resolveSafeHostedUrl('javascript:alert(1)', httpsPage), isNull);
      expect(
        resolveSafeHostedUrl(
          'https://user:pass@cdn.example/logo.svg',
          httpsPage,
        ),
        isNull,
      );
      expect(
        resolveSafeHostedUrl('http://other.example/login', httpsPage),
        isNull,
      );
      expect(
        resolveSafeHostedUrl(r'https://cdn.example\logo.svg', httpsPage),
        isNull,
      );
    });

    test('forwards OAuth parameters and preserves target overrides', () {
      final redirect = buildLoginPageRedirect(
        'https://login.example/hosted?theme=dark&client_id=managed',
        httpsPage,
      )!;

      expect(redirect.origin, 'https://login.example');
      expect(redirect.queryParameters['theme'], 'dark');
      expect(redirect.queryParameters['client_id'], 'managed');
      expect(redirect.queryParametersAll['resource'], ['one', 'two']);
    });

    test('does not forward an external first-party return target', () {
      final redirect = buildLoginPageRedirect(
        'https://login.example/hosted',
        Uri.parse(
          'https://console.example/login/?client_id=rp&'
          'redirect=https%3A%2F%2Fevil.example%2Fafter-login',
        ),
      )!;

      expect(redirect.queryParameters, {'client_id': 'rp'});
      expect(redirect, isNot(contains('evil.example')));
    });

    test('never forwards action or trusted-device credentials', () {
      final redirect = buildLoginPageRedirect(
        'https://login.example/hosted?theme=dark&device_token=configured',
        Uri.parse(
          'https://console.example/login/?client_id=rp&state=state-1&'
          'device_token=trusted-secret&token=action-secret&'
          'email=user%40example.test',
        ),
      )!;

      expect(redirect.queryParameters['client_id'], 'rp');
      expect(redirect.queryParameters['state'], 'state-1');
      expect(redirect.queryParameters, isNot(contains('device_token')));
      expect(redirect.queryParameters, isNot(contains('token')));
      expect(redirect.queryParameters, isNot(contains('email')));
    });

    test(
      'does not forward authorization responses or one-use continuations',
      () {
        final redirect = buildLoginPageRedirect(
          'https://login.example/hosted',
          Uri.parse(
            'https://console.example/login/?client_id=rp&state=state-1&'
            'code=authorization-code&access_token=bearer&'
            'id_token=id-token&error=access_denied&'
            'login_transaction_id=transaction-once&'
            'consent_challenge_id=consent-once',
          ),
        )!;

        expect(redirect.queryParameters, {
          'client_id': 'rp',
          'state': 'state-1',
        });
      },
    );

    test('avoids redirecting back to the exact current login page', () {
      expect(buildLoginPageRedirect('/login/', httpsPage), isNull);
    });
  });

  group('ConsentRequestSummary', () {
    test('parses described scopes and exact authorization details', () {
      final summary = ConsentRequestSummary.fromResponse({
        'scopes': [
          {'scope': 'openid', 'description': ''},
          {'scope': 'billing:read', 'description': 'View billing history'},
        ],
        'authorization_details': [
          {
            'type': 'payment_initiation',
            'actions': ['initiate'],
            'locations': ['https://api.example/payments'],
            'instructedAmount': {'currency': 'EUR', 'amount': '10.00'},
          },
        ],
      });

      expect(summary.canAuthorize, isTrue);
      expect(summary.scopes[1].description, 'View billing history');
      expect(summary.authorizationDetails.single['type'], 'payment_initiation');
    });

    test('accepts JSON-encoded authorization details from older proxies', () {
      final summary = ConsentRequestSummary.fromResponse({
        'scopes': ['openid'],
        'authorization_details':
            '[{"type":"account_information","actions":["read"]}]',
      });

      expect(summary.canAuthorize, isTrue);
      expect(summary.authorizationDetails.single['actions'], ['read']);
    });

    test('disables authorization for empty or malformed summaries', () {
      final empty = ConsentRequestSummary.fromResponse({'scopes': []});
      final malformed = ConsentRequestSummary.fromResponse({
        'scopes': ['openid'],
        'authorization_details': '{not-json}',
      });

      expect(empty.canAuthorize, isFalse);
      expect(malformed.canAuthorize, isFalse);
      expect(malformed.parseError, isNotNull);
    });
  });

  group('HostedLoginRoute', () {
    test('detects sensitive values nested in a first-party redirect', () {
      expect(
        hostedLoginRedirectContainsSensitiveData(
          Uri.parse(
            'https://console.example/login/?redirect=%2Fportal%2F%3Fflow%3D'
            'invitation%26token%3Dinvite-secret',
          ),
        ),
        isTrue,
      );
      expect(
        hostedLoginRedirectContainsSensitiveData(
          Uri.parse(
            'https://console.example/login/?redirect=%2Fportal%2F%3Ftoken%3D'
            'untyped-secret',
          ),
        ),
        isTrue,
      );
      expect(
        hostedLoginRedirectContainsSensitiveData(
          Uri.parse(
            'https://console.example/login/?redirect=%2Fportal%2Fsafe&'
            'redirect=%2Fportal%2F%3Ftoken%3Dhidden-secret',
          ),
        ),
        isTrue,
      );
    });

    test('only ordinary login flows may use a separately hosted page', () {
      final login = HostedLoginRoute.fromUri(
        Uri.parse('https://console.example/login/?client_id=client-1'),
      );
      final magicLink = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/?flow=magiclink&'
          'token=magic-1&email=user@example.test',
        ),
      );
      final changeEmail = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/?flow=change_email&token=email-1',
        ),
      );

      expect(login.allowsCustomLoginPage, isTrue);
      expect(magicLink.allowsCustomLoginPage, isFalse);
      expect(changeEmail.allowsCustomLoginPage, isFalse);

      final duplicateAction = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/?flow=reset&flow=login&'
          'token=reset-secret',
        ),
      );
      expect(duplicateAction.malformed, isTrue);
      expect(duplicateAction.allowsCustomLoginPage, isFalse);
    });

    test('scrubs an inbound trusted-device credential immediately', () {
      final location = hostedLoginLocationWithoutDeviceCredential(
        Uri.parse(
          'https://console.example/login/?client_id=client-1&'
          'device_token=bearer-secret&scope=openid#fragment',
        ),
      );
      final sanitized = Uri.parse(location);

      expect(sanitized.path, '/login/');
      expect(sanitized.queryParameters, {
        'client_id': 'client-1',
        'scope': 'openid',
      });
      expect(sanitized.fragment, isEmpty);
      expect(location, isNot(contains('bearer-secret')));
    });

    test(
      'scrubs one-time data but preserves OAuth continuation parameters',
      () {
        final location = hostedLoginLocationWithoutOneTimeData(
          Uri.parse(
            'https://console.example/login/reset?flow=reset&token=secret&'
            'email=user%40example.test&client_id=client-1&scope=openid&'
            'scope=profile#email=user@example.test',
          ),
        );
        final sanitized = Uri.parse(location);

        expect(sanitized.path, '/login/reset');
        expect(sanitized.queryParametersAll, {
          'client_id': ['client-1'],
          'scope': ['openid', 'profile'],
        });
        expect(location, isNot(contains('secret')));
        expect(location, isNot(contains('user%40example.test')));
        expect(sanitized.fragment, isEmpty);
      },
    );

    test('routes reset and verification tokens only to explicit flows', () {
      final reset = HostedLoginRoute.fromUri(
        Uri.parse('https://console.example/login/?flow=reset&token=reset-1'),
      );
      final verify = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/?flow=verify_email&token=verify-1'
          '#email=user@example.test',
        ),
      );

      expect(reset.resetToken, 'reset-1');
      expect(reset.magicLinkToken, isNull);
      expect(verify.verificationToken, 'verify-1');
      expect(verify.magicLinkToken, isNull);
    });

    test('keeps only the legacy token-plus-fragment magic-link shape', () {
      final legacy = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/?token=magic-1'
          '#email=user@example.test',
        ),
      );
      final ambiguous = HostedLoginRoute.fromUri(
        Uri.parse('https://console.example/login/?token=opaque-1'),
      );
      final unknownExplicitFlow = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/?flow=other&token=opaque-2'
          '#email=user@example.test',
        ),
      );

      expect(legacy.magicLinkToken, 'magic-1');
      expect(legacy.shouldAutoSubmitMagicLink, isTrue);
      expect(ambiguous.magicLinkToken, isNull);
      expect(unknownExplicitFlow.magicLinkToken, isNull);
    });

    test('carries authenticated account actions into the portal', () {
      final changeEmail = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/'
          '?flow=change_email&token=email-token',
        ),
      );
      final invitation = HostedLoginRoute.fromUri(
        Uri.parse(
          'https://console.example/login/'
          '?flow=invitation&token=invite-token',
        ),
      );

      expect(
        changeEmail.portalActionTarget,
        '/portal/?flow=change_email&token=email-token',
      );
      expect(changeEmail.requiresAuthentication, isTrue);
      expect(
        invitation.portalActionTarget,
        '/portal/?flow=invitation&token=invite-token',
      );
      expect(invitation.requiresAuthentication, isTrue);
    });
  });
}
