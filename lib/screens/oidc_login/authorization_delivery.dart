import 'authorization_redirect_policy.dart';
import 'oauth_params.dart';

/// Server-attested delivery metadata for a non-form authorization response.
class AuthorizationDelivery {
  final Uri redirectUri;
  final String responseMode;

  const AuthorizationDelivery({
    required this.redirectUri,
    required this.responseMode,
  });

  bool get usesJarm => const {
    'jwt',
    'query.jwt',
    'fragment.jwt',
    'form_post.jwt',
  }.contains(responseMode);
}

/// Resolves where and how an authorization result may leave the hosted page.
///
/// A plain request can retain compatibility with the URI the server just
/// validated. PAR and JAR can replace redirect URI, state, and response mode,
/// so their browser-visible values are never accepted as a delivery target;
/// those flows require effective metadata echoed by Snaplink after validation.
AuthorizationDelivery? resolveAuthorizationDelivery({
  required OAuthParams request,
  required Map<String, dynamic> response,
  required bool errorResponse,
  required bool tokenResponse,
}) {
  final validated = _isTrue(response['redirect_uri_validated']);
  final serverRedirect = response['redirect_uri']?.toString().trim() ?? '';
  final serverMode = response['response_mode']?.toString().trim() ?? '';
  final hasServerOwnedRequest =
      request.requestUri.isNotEmpty || request.request.isNotEmpty;

  late final String redirectValue;
  late final String responseMode;
  if (serverRedirect.isNotEmpty) {
    if (!validated) return null;
    redirectValue = serverRedirect;
    responseMode = serverMode;
  } else {
    if (hasServerOwnedRequest || request.redirectUri.isEmpty) return null;
    if (errorResponse && !validated) return null;
    redirectValue = request.redirectUri;
    responseMode = request.responseMode;
  }

  final redirectUri = Uri.tryParse(redirectValue);
  if (redirectUri == null || !isSafeAuthorizationRedirectUri(redirectUri)) {
    return null;
  }
  final effectiveMode = responseMode.isEmpty
      ? (tokenResponse ? 'fragment' : 'query')
      : responseMode;
  if (!const {
    'query',
    'fragment',
    'form_post',
    'jwt',
    'query.jwt',
    'fragment.jwt',
    'form_post.jwt',
  }.contains(effectiveMode)) {
    return null;
  }
  return AuthorizationDelivery(
    redirectUri: redirectUri,
    responseMode: effectiveMode,
  );
}

bool _isTrue(Object? value) => value == true || value?.toString() == 'true';
