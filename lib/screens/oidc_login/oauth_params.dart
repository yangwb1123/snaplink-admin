import 'dart:convert';

/// The authorization-request parameters the hosted /login/ page receives via
/// its own query string — mirrors interfaces/web/login/app.js's oauthParams
/// object exactly (same field set, same defaults).
class OAuthParams {
  final String clientId;
  final List<String> scope;
  final String state;
  final String responseType;
  final String redirectUri;
  final String nonce;
  final String codeChallenge;
  final String codeChallengeMethod;
  final List<String> resource;
  final String provider;
  final String requestUri;
  final String request;
  final String prompt;
  final String idTokenHint;
  final String maxAge;
  final String loginHint;
  final String responseMode;
  final String acrValues;
  final String uiLocales;
  final String authorizationDetails;
  final String claims;
  final String consentChallengeId;

  OAuthParams({
    required this.clientId,
    required this.scope,
    required this.state,
    required this.responseType,
    required this.redirectUri,
    required this.nonce,
    required this.codeChallenge,
    required this.codeChallengeMethod,
    required this.resource,
    required this.provider,
    required this.requestUri,
    required this.request,
    required this.prompt,
    required this.idTokenHint,
    required this.maxAge,
    required this.loginHint,
    required this.responseMode,
    required this.acrValues,
    required this.uiLocales,
    required this.authorizationDetails,
    required this.claims,
    required this.consentChallengeId,
  });

  factory OAuthParams.fromUri(Uri uri) {
    final q = uri.queryParameters;
    final scopeRaw = q['scope'] ?? 'openid';
    return OAuthParams(
      clientId: q['client_id'] ?? '',
      scope: scopeRaw.split(' ').where((s) => s.isNotEmpty).toList(),
      state: q['state'] ?? '',
      responseType: q['response_type'] ?? '',
      redirectUri: q['redirect_uri'] ?? '',
      nonce: q['nonce'] ?? '',
      codeChallenge: q['code_challenge'] ?? '',
      codeChallengeMethod: q['code_challenge_method'] ?? '',
      resource: uri.queryParametersAll['resource'] ?? const [],
      provider: q['provider'] ?? 'password',
      requestUri: q['request_uri'] ?? '',
      request: q['request'] ?? '',
      prompt: q['prompt'] ?? '',
      idTokenHint: q['id_token_hint'] ?? '',
      maxAge: q['max_age'] ?? '',
      loginHint: q['login_hint'] ?? '',
      responseMode: q['response_mode'] ?? '',
      acrValues: q['acr_values'] ?? '',
      uiLocales: q['ui_locales'] ?? '',
      authorizationDetails: q['authorization_details'] ?? '',
      claims: q['claims'] ?? '',
      consentChallengeId: q['consent_challenge_id'] ?? '',
    );
  }

  /// `prompt` is a space-delimited OIDC value. Keeping this parsing here
  /// prevents the hosted page and its payload builder from disagreeing about
  /// whether a request must stay non-interactive.
  bool get hasPromptNone =>
      prompt.split(RegExp(r'\s+')).any((value) => value == 'none');

  Map<String, dynamic> toLoginPayload(String selectedProvider) {
    final payload = <String, dynamic>{
      'provider': selectedProvider,
      'client_id': clientId,
      'scope': scope,
      'state': state,
      'response_type': responseType,
      'redirect_uri': redirectUri,
      'nonce': nonce,
      'code_challenge': codeChallenge,
      'code_challenge_method': codeChallengeMethod,
    };
    if (resource.isNotEmpty) payload['resource'] = resource;
    if (requestUri.isNotEmpty) payload['request_uri'] = requestUri;
    if (request.isNotEmpty) payload['request'] = request;
    if (prompt.isNotEmpty) payload['prompt'] = prompt;
    if (idTokenHint.isNotEmpty) payload['id_token_hint'] = idTokenHint;
    if (maxAge.isNotEmpty) {
      payload['max_age'] = int.tryParse(maxAge) ?? maxAge;
    }
    if (loginHint.isNotEmpty) payload['login_hint'] = loginHint;
    if (responseMode.isNotEmpty) payload['response_mode'] = responseMode;
    if (acrValues.isNotEmpty) payload['acr_values'] = acrValues;
    if (uiLocales.isNotEmpty) payload['ui_locales'] = uiLocales;
    if (authorizationDetails.isNotEmpty) {
      payload['authorization_details'] = _jsonOrRaw(authorizationDetails);
    }
    if (claims.isNotEmpty) payload['claims'] = _jsonOrRaw(claims);
    if (consentChallengeId.isNotEmpty) {
      payload['consent_challenge_id'] = consentChallengeId;
    }
    return payload;
  }

  /// Authorization-shaped query used for a top-level federated redirect.
  ///
  /// Unlike [toLoginPayload], JSON-valued parameters stay as their original
  /// strings and repeated `resource` values remain repeated URL parameters.
  /// Credentials and one-time action data are never part of this projection.
  Map<String, dynamic> toFederatedLoginQuery(String selectedProvider) => {
    'provider': selectedProvider,
    'client_id': clientId,
    if (scope.isNotEmpty) 'scope': scope.join(' '),
    if (state.isNotEmpty) 'state': state,
    if (responseType.isNotEmpty) 'response_type': responseType,
    if (redirectUri.isNotEmpty) 'redirect_uri': redirectUri,
    if (nonce.isNotEmpty) 'nonce': nonce,
    if (codeChallenge.isNotEmpty) 'code_challenge': codeChallenge,
    if (codeChallengeMethod.isNotEmpty)
      'code_challenge_method': codeChallengeMethod,
    if (resource.isNotEmpty) 'resource': resource,
    if (requestUri.isNotEmpty) 'request_uri': requestUri,
    if (request.isNotEmpty) 'request': request,
    if (prompt.isNotEmpty) 'prompt': prompt,
    if (idTokenHint.isNotEmpty) 'id_token_hint': idTokenHint,
    if (maxAge.isNotEmpty) 'max_age': maxAge,
    if (loginHint.isNotEmpty) 'login_hint': loginHint,
    if (responseMode.isNotEmpty) 'response_mode': responseMode,
    if (acrValues.isNotEmpty) 'acr_values': acrValues,
    if (uiLocales.isNotEmpty) 'ui_locales': uiLocales,
    if (authorizationDetails.isNotEmpty)
      'authorization_details': authorizationDetails,
    if (claims.isNotEmpty) 'claims': claims,
  };

  Object _jsonOrRaw(String value) {
    try {
      return jsonDecode(value);
    } on FormatException {
      // Preserve the malformed value as a JSON string so Snaplink, rather
      // than the client, owns the protocol-level invalid_request decision.
      return value;
    }
  }
}
