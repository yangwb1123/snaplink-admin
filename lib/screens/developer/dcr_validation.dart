import 'dcr_models.dart';

class DcrValidationResult {
  final List<String> errors;

  const DcrValidationResult(this.errors);

  bool get isValid => errors.isEmpty;

  String get message => errors.join('\n');
}

const dcrSafeAuthMethods = {
  'client_secret_basic',
  'client_secret_post',
  'private_key_jwt',
  'none',
  'tls_client_auth',
  'self_signed_tls',
};

DcrValidationResult validateDcrMetadata(
  DcrClientMetadata metadata, {
  DcrDiscovery? discovery,
  bool registration = true,
}) {
  final errors = <String>[];
  final grants = metadata.grantTypes.toSet();
  final responses = metadata.responseTypes.toSet();
  final authorizationCode = grants.contains('authorization_code');

  if (metadata.clientName.trim().isEmpty) {
    errors.add('App name is required.');
  }
  if (grants.isEmpty) {
    errors.add('Select at least one grant type.');
  }
  if (authorizationCode && metadata.redirectUris.isEmpty) {
    errors.add('authorization_code requires at least one redirect URI.');
  }
  if (registration && authorizationCode && !responses.contains('code')) {
    errors.add('authorization_code must include the code response type.');
  }
  if (!authorizationCode && responses.isNotEmpty) {
    errors.add(
      'Response types are only valid when authorization_code is selected.',
    );
  }
  if (responses.any((value) => value != 'code')) {
    errors.add(
      'The current Snaplink DCR handler cannot register a consistent '
      'implicit/hybrid grant; use the code response type.',
    );
  }
  if (!dcrSafeAuthMethods.contains(metadata.tokenEndpointAuthMethod)) {
    errors.add(
      'The selected token endpoint authentication method is not accepted by '
      'Snaplink DCR.',
    );
  }
  final jwks = metadata.expertMetadata['jwks'];
  final hasJwks =
      jwks is Map && jwks['keys'] is List && (jwks['keys'] as List).isNotEmpty;
  if (const {
        'private_key_jwt',
        'self_signed_tls',
      }.contains(metadata.tokenEndpointAuthMethod) &&
      !hasJwks) {
    errors.add(
      '${metadata.tokenEndpointAuthMethod} requires a non-empty jwks.keys array.',
    );
  }
  if (metadata.tokenEndpointAuthMethod == 'tls_client_auth' &&
      !const {
        'tls_client_auth_subject_dn',
        'tls_client_auth_san_dns',
        'tls_client_auth_san_email',
        'tls_client_auth_san_uri',
      }.any(
        (key) => metadata.expertMetadata[key]?.toString().isNotEmpty == true,
      )) {
    errors.add('tls_client_auth requires certificate binding metadata.');
  }
  if (!const {'jwt', 'session'}.contains(metadata.tokenStrategy)) {
    errors.add('Token strategy must be jwt or session.');
  }
  if (metadata.isPublicClient && grants.contains('client_credentials')) {
    errors.add('Public clients cannot use the client_credentials grant.');
  }
  if (metadata.isPublicClient && !metadata.requirePkce) {
    errors.add('Public clients require PKCE with S256.');
  }

  for (final raw in [
    ...metadata.redirectUris,
    ...metadata.postLogoutRedirectUris,
  ]) {
    final uri = Uri.tryParse(raw);
    if (!_isSafeRedirectUri(uri)) {
      errors.add('Invalid redirect URI: $raw');
    }
  }

  if (discovery != null) {
    if (registration && !discovery.registrationEnabled) {
      errors.add('Dynamic client registration is not advertised by Snaplink.');
    }
    if (discovery.grantTypes.isNotEmpty) {
      for (final grant in grants) {
        if (!discovery.grantTypes.contains(grant)) {
          errors.add('Grant type is not advertised by Snaplink: $grant');
        }
      }
    }
    if (discovery.responseTypes.isNotEmpty) {
      for (final response in responses) {
        if (!discovery.responseTypes.contains(response)) {
          errors.add('Response type is not advertised by Snaplink: $response');
        }
      }
    }
    if (discovery.tokenEndpointAuthMethods.isNotEmpty &&
        !discovery.tokenEndpointAuthMethods.contains(
          metadata.tokenEndpointAuthMethod,
        )) {
      errors.add(
        'Token endpoint authentication method is not advertised by Snaplink: '
        '${metadata.tokenEndpointAuthMethod}',
      );
    }
    if ((metadata.requirePkce || metadata.isPublicClient) &&
        discovery.codeChallengeMethods.isNotEmpty &&
        !discovery.codeChallengeMethods.contains('S256')) {
      errors.add('Snaplink discovery does not advertise PKCE S256.');
    }
  }

  return DcrValidationResult(List.unmodifiable(errors));
}

bool _isSafeRedirectUri(Uri? uri) {
  if (uri == null ||
      !uri.isAbsolute ||
      uri.fragment.isNotEmpty ||
      uri.userInfo.isNotEmpty) {
    return false;
  }
  if (uri.scheme == 'https') return uri.host.isNotEmpty;
  if (uri.scheme == 'http') {
    return const {'localhost', '127.0.0.1', '::1'}.contains(uri.host);
  }
  return !const {
    'about',
    'blob',
    'data',
    'file',
    'javascript',
    'vbscript',
  }.contains(uri.scheme.toLowerCase());
}
