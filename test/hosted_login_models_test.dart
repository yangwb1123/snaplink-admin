import 'package:flutter_test/flutter_test.dart';
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
  });
}
