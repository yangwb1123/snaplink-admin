/// Authorization delivery: how and where a terminal authorization result
/// leaves the hosted page.
///
/// Delivery semantics are fixed and fail closed:
///
/// * `query` — browser redirect with the result in the query string.
/// * `fragment` — browser redirect with the result in the fragment.
/// * `form_post` — a same-origin auto-submitted form whose action and field
///   set were validated against the registered callback.
/// * `jwt` / `query.jwt` / `fragment.jwt` / `form_post.jwt` (JARM) — only a
///   compact JWT signed by Snaplink may leave; the browser never signs one.
///
/// Only a server-proven terminal state is adopted. PAR/JAR requests never
/// fall back to browser-visible targets, each decision is a one-time
/// transaction, and nothing is replayed on refresh.
library;

import 'authorization_redirect_policy.dart';
import 'oauth_params.dart';

/// Every response mode the hosted page may deliver. Unknown or dangerous
/// modes fail closed in [resolveAuthorizationDelivery].
const _deliveryModes = {
  'query',
  'fragment',
  'form_post',
  'jwt',
  'query.jwt',
  'fragment.jwt',
  'form_post.jwt',
};

/// JARM modes: the response must be a compact JWT signed by Snaplink.
const _jarmModes = {'jwt', 'query.jwt', 'fragment.jwt', 'form_post.jwt'};

/// Typed delivery channel, replacing string matching at the call sites.
enum AuthorizationDeliveryKind {
  /// `response_mode=query` — browser redirect, result in the query string.
  queryRedirect,

  /// `response_mode=fragment` — browser redirect, result in the fragment.
  fragmentRedirect,

  /// `response_mode=form_post` — same-origin auto-submitted form whose action
  /// and field set were validated against the registered callback.
  formPost,

  /// JARM (`jwt` / `query.jwt` / `fragment.jwt` / `form_post.jwt`) — only a
  /// server-signed envelope may leave; the browser never signs one.
  signedJarm,
}

/// Three-state presentation contract for the delivery surface: pending
/// (result in flight), resolved (server-attested terminal state adopted), and
/// blocked (fail closed — nothing left the hosted page).
enum AuthorizationDeliveryPhase { pending, resolved, blocked }

/// Server-attested delivery metadata for a non-form authorization response.
class AuthorizationDelivery {
  final Uri redirectUri;
  final String responseMode;

  const AuthorizationDelivery({
    required this.redirectUri,
    required this.responseMode,
  });

  bool get usesJarm => _jarmModes.contains(responseMode);

  /// Typed channel for consumers that render delivery status.
  AuthorizationDeliveryKind get kind => switch (responseMode) {
    'query' => AuthorizationDeliveryKind.queryRedirect,
    'fragment' => AuthorizationDeliveryKind.fragmentRedirect,
    'form_post' => AuthorizationDeliveryKind.formPost,
    _ => AuthorizationDeliveryKind.signedJarm,
  };
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
  if (redirectUri == null) return null;
  // Server-attested targets (redirect_uri_validated: true) have already
  // passed the server's DCR allowlist; accept plain-HTTP hosts (private
  // deployments) in that case. Unattested targets keep the strict local
  // policy so an attacker-controlled login URL cannot become an open
  // redirect. Dangerous schemes are rejected in both cases.
  final safe = validated
      ? _isServerAttestedTarget(redirectUri)
      : isSafeAuthorizationRedirectUri(redirectUri);
  if (!safe) return null;
  final effectiveMode = responseMode.isEmpty
      ? (tokenResponse ? 'fragment' : 'query')
      : responseMode;
  if (!_deliveryModes.contains(effectiveMode)) {
    return null;
  }
  return AuthorizationDelivery(
    redirectUri: redirectUri,
    responseMode: effectiveMode,
  );
}

bool _isTrue(Object? value) => value == true || value?.toString() == 'true';

/// Accepts a redirect target the server explicitly attested via
/// `redirect_uri_validated: true`. The server already checked the client's
/// registered redirect URIs, so plain-HTTP hosts (intranet deployments) are
/// allowed. Fragments, embedded credentials, relative URLs, and executable /
/// browser-local schemes remain rejected. Native schemes fall back to the
/// shared safe-URI policy.
bool _isServerAttestedTarget(Uri uri) {
  if (!uri.isAbsolute ||
      uri.userInfo.isNotEmpty ||
      uri.fragment.isNotEmpty ||
      const {
        'about',
        'blob',
        'data',
        'file',
        'javascript',
        'vbscript',
      }.contains(uri.scheme.toLowerCase())) {
    return false;
  }
  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return isSafeAuthorizationRedirectUri(uri);
  }
  return uri.host.isNotEmpty;
}
