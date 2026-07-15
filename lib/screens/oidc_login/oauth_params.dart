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
    );
  }

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
    return payload;
  }
}
