import 'dart:convert';

class DcrDiscovery {
  final String registrationEndpoint;
  final List<String> grantTypes;
  final List<String> responseTypes;
  final List<String> tokenEndpointAuthMethods;
  final List<String> codeChallengeMethods;
  final List<String> scopes;
  final String servingRegion;

  const DcrDiscovery({
    required this.registrationEndpoint,
    required this.grantTypes,
    required this.responseTypes,
    required this.tokenEndpointAuthMethods,
    required this.codeChallengeMethods,
    required this.scopes,
    this.servingRegion = '',
  });

  factory DcrDiscovery.fromJson(Map<String, dynamic> value) {
    return DcrDiscovery(
      registrationEndpoint:
          value['registration_endpoint']?.toString().trim() ?? '',
      grantTypes: _stringList(value['grant_types_supported']),
      responseTypes: _stringList(value['response_types_supported']),
      tokenEndpointAuthMethods: _stringList(
        value['token_endpoint_auth_methods_supported'],
      ),
      codeChallengeMethods: _stringList(
        value['code_challenge_methods_supported'],
      ),
      scopes: _stringList(value['scopes_supported']),
      servingRegion: value['serving_region']?.toString().trim() ?? '',
    );
  }

  bool get registrationEnabled => registrationEndpoint.isNotEmpty;

  static List<String> _stringList(Object? raw) => raw is List
      ? raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : const [];
}

class DcrClientMetadata {
  static const typedKeys = {
    'client_name',
    'redirect_uris',
    'scope',
    'token_endpoint_auth_method',
    'token_strategy',
    'grant_types',
    'response_types',
    'contacts',
    'post_logout_redirect_uris',
    'allowed_authenticators',
    'allowed_resources',
    'tenant_id',
    'require_pkce',
  };

  static const protectedResponseKeys = {
    'client_id',
    'client_secret',
    'client_id_issued_at',
    'client_secret_expires_at',
    'registration_access_token',
    'registration_client_uri',
  };

  final String clientName;
  final List<String> redirectUris;
  final String scope;
  final String tokenEndpointAuthMethod;
  final String tokenStrategy;
  final List<String> grantTypes;
  final List<String> responseTypes;
  final List<String> contacts;
  final List<String> postLogoutRedirectUris;
  final List<String> allowedAuthenticators;
  final List<String> allowedResources;
  final String tenantId;
  final bool requirePkce;
  final Map<String, dynamic> expertMetadata;

  const DcrClientMetadata({
    required this.clientName,
    required this.redirectUris,
    required this.scope,
    required this.tokenEndpointAuthMethod,
    required this.tokenStrategy,
    required this.grantTypes,
    required this.responseTypes,
    required this.contacts,
    required this.postLogoutRedirectUris,
    required this.allowedAuthenticators,
    required this.allowedResources,
    required this.tenantId,
    required this.requirePkce,
    this.expertMetadata = const {},
  });

  factory DcrClientMetadata.defaults() => const DcrClientMetadata(
    clientName: '',
    redirectUris: [],
    scope: 'openid',
    tokenEndpointAuthMethod: 'client_secret_basic',
    tokenStrategy: 'jwt',
    grantTypes: ['authorization_code'],
    responseTypes: ['code'],
    contacts: [],
    postLogoutRedirectUris: [],
    allowedAuthenticators: [],
    allowedResources: [],
    tenantId: '',
    requirePkce: false,
  );

  factory DcrClientMetadata.fromWire(Map<String, dynamic> value) {
    return DcrClientMetadata(
      clientName: value['client_name']?.toString() ?? '',
      redirectUris: _wireStringList(value['redirect_uris']),
      scope: value['scope']?.toString() ?? '',
      tokenEndpointAuthMethod:
          value['token_endpoint_auth_method']?.toString() ??
          'client_secret_basic',
      tokenStrategy: value['token_strategy']?.toString() ?? 'jwt',
      grantTypes: _wireStringList(value['grant_types']),
      responseTypes: _wireStringList(value['response_types']),
      contacts: _wireStringList(value['contacts']),
      postLogoutRedirectUris: _wireStringList(
        value['post_logout_redirect_uris'],
      ),
      allowedAuthenticators: _wireStringList(value['allowed_authenticators']),
      allowedResources: _wireStringList(value['allowed_resources']),
      tenantId: value['tenant_id']?.toString() ?? '',
      requirePkce: value['require_pkce'] == true,
      expertMetadata: {
        for (final entry in value.entries)
          if (!typedKeys.contains(entry.key) &&
              !protectedResponseKeys.contains(entry.key))
            entry.key: entry.value,
      },
    );
  }

  /// RFC 7591 register wire: typed fields plus any accepted expert
  /// metadata; require_pkce is forced for public clients.
  Map<String, dynamic> toRegistrationWire() => {
    ...expertMetadata,
    'client_name': clientName,
    'redirect_uris': redirectUris,
    'scope': scope,
    'token_endpoint_auth_method': tokenEndpointAuthMethod,
    'token_strategy': tokenStrategy,
    'grant_types': grantTypes,
    'response_types': responseTypes,
    'contacts': contacts,
    'post_logout_redirect_uris': postLogoutRedirectUris,
    'allowed_authenticators': allowedAuthenticators,
    'allowed_resources': allowedResources,
    if (tenantId.isNotEmpty) 'tenant_id': tenantId,
    'require_pkce': requirePkce || isPublicClient,
  };

  /// tenant_id remains immutable on RFC 7592 PUT; every other typed
  /// registration field round-trips through the management contract.
  /// RFC 7592 PUT wire: same shape as registration but tenant_id stays
  /// immutable on the server and is deliberately omitted.
  Map<String, dynamic> toManagementWire() => {
    ...expertMetadata,
    'client_name': clientName,
    'redirect_uris': redirectUris,
    'scope': scope,
    'token_endpoint_auth_method': tokenEndpointAuthMethod,
    'token_strategy': tokenStrategy,
    'grant_types': grantTypes,
    'response_types': responseTypes,
    'contacts': contacts,
    'post_logout_redirect_uris': postLogoutRedirectUris,
    'allowed_authenticators': allowedAuthenticators,
    'allowed_resources': allowedResources,
    'require_pkce': requirePkce || isPublicClient,
  };

  bool get isPublicClient => tokenEndpointAuthMethod == 'none';

  /// Pretty-printed expert metadata for the JSON editor.
  String expertJson() =>
      const JsonEncoder.withIndent('  ').convert(expertMetadata);

  /// Parses the expert JSON editor value; rejects typed and credential
  /// keys so the wire can never be shadowed by expert input.
  static Map<String, dynamic> parseExpertJson(String raw) {
    if (raw.trim().isEmpty) return const {};
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw const FormatException('Expert metadata must be a JSON object.');
    }
    final result = {
      for (final entry in decoded.entries) entry.key.toString(): entry.value,
    };
    final conflicts =
        result.keys
            .where(
              (key) =>
                  typedKeys.contains(key) ||
                  protectedResponseKeys.contains(key),
            )
            .toList()
          ..sort();
    if (conflicts.isNotEmpty) {
      throw FormatException(
        'Expert JSON cannot override typed or credential fields: '
        '${conflicts.join(', ')}.',
      );
    }
    return result;
  }

  static List<String> _wireStringList(Object? raw) => raw is List
      ? raw
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false)
      : const [];
}

/// RFC 7592 lossless round-trip gate: a GET response that omits any
/// typed field would be overwritten by a PUT, so saving is disabled until
/// the full representation is known.
class DcrRoundTripSafety {
  final bool grantTypesKnown;
  final bool responseTypesKnown;
  final bool contactsKnown;
  final bool tenantKnown;

  const DcrRoundTripSafety({
    required this.grantTypesKnown,
    required this.responseTypesKnown,
    required this.contactsKnown,
    required this.tenantKnown,
  });

  /// Trusted registration snapshots (echoed 201 response) may carry
  /// explicitly empty lists; untrusted GET responses must contain the key.
  factory DcrRoundTripSafety.fromWire(
    Map<String, dynamic> value, {
    bool trustedRegistrationSnapshot = false,
  }) {
    return DcrRoundTripSafety(
      grantTypesKnown:
          value['grant_types'] is List &&
          (trustedRegistrationSnapshot || value.containsKey('grant_types')),
      responseTypesKnown: value.containsKey('response_types'),
      contactsKnown: value.containsKey('contacts'),
      tenantKnown: value.containsKey('tenant_id'),
    );
  }

  bool get canSafelyUpdate =>
      grantTypesKnown && responseTypesKnown && contactsKnown && tenantKnown;

  List<String> get warnings => [
    if (!grantTypesKnown)
      'GET omitted grant_types. A PUT would replace the stored grants, so '
          'saving is disabled.',
    if (!responseTypesKnown)
      'GET omitted response_types; saving is disabled to prevent metadata loss.',
    if (!contactsKnown)
      'GET omitted contacts; saving is disabled to prevent metadata loss.',
    if (!tenantKnown)
      'GET omitted tenant_id; saving is disabled because the tenant binding cannot be verified.',
  ];
}
