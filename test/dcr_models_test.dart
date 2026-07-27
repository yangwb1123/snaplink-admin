import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/developer/dcr_models.dart';
import 'package:sso_admin/screens/developer/dcr_update_projection.dart';
import 'package:sso_admin/screens/developer/dcr_validation.dart';

void main() {
  group('DCR typed metadata', () {
    test('serializes common registration metadata and expert fields', () {
      final metadata = _metadata(
        authMethod: 'none',
        requirePkce: false,
        expert: const {'id_token_encrypted_response_alg': 'RSA-OAEP-256'},
      );

      expect(metadata.toRegistrationWire(), {
        'id_token_encrypted_response_alg': 'RSA-OAEP-256',
        'client_name': 'Acme',
        'redirect_uris': ['https://app.example/callback'],
        'scope': 'openid profile',
        'token_endpoint_auth_method': 'none',
        'token_strategy': 'jwt',
        'grant_types': ['authorization_code', 'refresh_token'],
        'response_types': ['code'],
        'contacts': ['security@example.com'],
        'post_logout_redirect_uris': ['https://app.example/signed-out'],
        'allowed_authenticators': ['password', 'webauthn'],
        'allowed_resources': ['https://api.example'],
        'tenant_id': 'tenant-a',
        'require_pkce': true,
      });
    });

    test('management wire excludes fields the handler cannot update', () {
      final wire = _metadata().toManagementWire();

      expect(wire['grant_types'], ['authorization_code', 'refresh_token']);
      expect(wire['allowed_resources'], ['https://api.example']);
      expect(wire, isNot(contains('response_types')));
      expect(wire, isNot(contains('contacts')));
      expect(wire, isNot(contains('tenant_id')));
    });

    test('expert JSON cannot override typed or credential fields', () {
      expect(
        () => DcrClientMetadata.parseExpertJson(
          '{"client_name":"shadow","client_secret":"leak"}',
        ),
        throwsA(
          isA<FormatException>().having(
            (error) => error.message,
            'message',
            contains('client_name, client_secret'),
          ),
        ),
      );
    });
  });

  group('RFC 7592 round-trip safety', () {
    test('blocks GET projection that omitted grant_types', () {
      final safety = DcrRoundTripSafety.fromWire({
        'client_id': 'client-1',
        'client_name': 'Acme',
      });

      expect(safety.canSafelyUpdate, isFalse);
      expect(safety.warnings.first, contains('saving is disabled'));
      expect(
        safety.warnings,
        contains(contains('response_types are not returned or persisted')),
      );
    });

    test('allows a trusted registration snapshot with explicit grants', () {
      final safety = DcrRoundTripSafety.fromWire({
        'grant_types': ['authorization_code'],
        'response_types': ['code'],
        'contacts': <String>[],
        'tenant_id': 'tenant-a',
      }, trustedRegistrationSnapshot: true);

      expect(safety.canSafelyUpdate, isTrue);
      expect(
        safety.warnings,
        contains(contains('shown from the registration snapshot')),
      );
    });

    test('PUT projection preserves only known omitted values', () {
      final projection = DcrUpdateProjection.fromPutResponse(
        response: const {
          'client_id': 'client-1',
          'client_name': 'Acme updated',
          'client_secret': 'must-not-survive',
          'registration_access_token': 'must-not-survive',
        },
        submitted: _metadata(),
      );

      expect(projection.safety.canSafelyUpdate, isTrue);
      expect(projection.wire['grant_types'], [
        'authorization_code',
        'refresh_token',
      ]);
      expect(projection.wire['response_types'], ['code']);
      expect(projection.wire['contacts'], ['security@example.com']);
      expect(projection.wire['tenant_id'], 'tenant-a');
      expect(projection.wire, isNot(contains('client_secret')));
      expect(projection.wire, isNot(contains('registration_access_token')));
    });
  });

  group('DCR dependency validation', () {
    test('public clients require S256 and reject client credentials', () {
      final result = validateDcrMetadata(
        _metadata(
          authMethod: 'none',
          requirePkce: false,
          grants: const ['client_credentials'],
          responses: const [],
          redirects: const [],
        ),
      );

      expect(result.message, contains('cannot use the client_credentials'));
      expect(result.message, contains('require PKCE with S256'));
    });

    test('authorization code requires redirect URI and code response', () {
      final result = validateDcrMetadata(
        _metadata(redirects: const [], responses: const []),
      );

      expect(result.message, contains('requires at least one redirect URI'));
      expect(result.message, contains('must include the code response type'));
    });

    test('checks handler-safe auth methods and discovery capabilities', () {
      const discovery = DcrDiscovery(
        registrationEndpoint: 'https://sso.example/register',
        grantTypes: ['authorization_code'],
        responseTypes: ['token'],
        tokenEndpointAuthMethods: ['private_key_jwt'],
        codeChallengeMethods: ['plain'],
        scopes: ['openid'],
      );
      final result = validateDcrMetadata(
        _metadata(
          authMethod: 'private_key_jwt',
          requirePkce: true,
          grants: const ['authorization_code', 'refresh_token'],
        ),
        discovery: discovery,
      );

      expect(result.message, contains('not accepted by Snaplink DCR'));
      expect(result.message, contains('not advertised by Snaplink'));
      expect(result.message, contains('Response type is not advertised'));
      expect(result.message, contains('does not advertise PKCE S256'));
    });

    test('rejects malformed redirect URIs and unknown token strategies', () {
      final result = validateDcrMetadata(
        _metadata(
          redirects: const [
            'https://user@example.com/cb#fragment',
            'javascript:alert(1)',
            'http://public.example/callback',
          ],
          tokenStrategy: 'opaque',
        ),
      );

      expect(
        RegExp('Invalid redirect URI').allMatches(result.message),
        hasLength(3),
      );
      expect(result.message, contains('must be jwt or session'));
    });

    test('allows HTTPS, loopback HTTP, and native custom schemes', () {
      final result = validateDcrMetadata(
        _metadata(
          redirects: const [
            'https://app.example/callback',
            'http://127.0.0.1:8341/callback',
            'com.example.app:/oauth/callback',
          ],
        ),
      );

      expect(result.isValid, isTrue);
    });
  });

  test('parses the relevant discovery capabilities', () {
    final discovery = DcrDiscovery.fromJson(const {
      'registration_endpoint': 'https://sso.example/register',
      'grant_types_supported': ['authorization_code', 'refresh_token'],
      'response_types_supported': ['code'],
      'token_endpoint_auth_methods_supported': ['none'],
      'code_challenge_methods_supported': ['S256'],
      'scopes_supported': ['openid', 'profile'],
    });

    expect(discovery.registrationEnabled, isTrue);
    expect(discovery.grantTypes, contains('refresh_token'));
    expect(discovery.codeChallengeMethods, ['S256']);
  });
}

DcrClientMetadata _metadata({
  String authMethod = 'client_secret_basic',
  String tokenStrategy = 'jwt',
  bool requirePkce = true,
  List<String> grants = const ['authorization_code', 'refresh_token'],
  List<String> responses = const ['code'],
  List<String> redirects = const ['https://app.example/callback'],
  Map<String, dynamic> expert = const {},
}) {
  return DcrClientMetadata(
    clientName: 'Acme',
    redirectUris: redirects,
    scope: 'openid profile',
    tokenEndpointAuthMethod: authMethod,
    tokenStrategy: tokenStrategy,
    grantTypes: grants,
    responseTypes: responses,
    contacts: const ['security@example.com'],
    postLogoutRedirectUris: const ['https://app.example/signed-out'],
    allowedAuthenticators: const ['password', 'webauthn'],
    allowedResources: const ['https://api.example'],
    tenantId: 'tenant-a',
    requirePkce: requirePkce,
    expertMetadata: expert,
  );
}
