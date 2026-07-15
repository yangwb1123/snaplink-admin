import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;

/// Handles the "Sign in with [a federated provider]" round trip for a
/// first-party login (this app itself is the OAuth client — a public PKCE
/// client, not an external relying party): generates and stashes its own
/// PKCE verifier before navigating away, then consumes the `code` this same
/// page is redirected back to once the external IdP (and this server's
/// /auth/callback) finish, exchanging it at /token.
///
/// redirect_uri is always the CURRENT page's path with no query/fragment —
/// not a fixed constant — so returning here lands back on whichever of the
/// five mounted areas (/admin/, /login/, ...) initiated the flow, and
/// app_router's existing path-based routing reconstructs the right screen
/// with no extra state to thread through. sessionStorage (not localStorage)
/// is intentional: the verifier must not outlive this one login attempt/tab.
class FederatedLogin {
  static const _verifierKey = 'sso_pkce_verifier';
  static const _stateKey = 'sso_pkce_state';
  static const _clientIdKey = 'sso_pkce_client_id';
  static const _redirectKey = 'sso_pkce_redirect_uri';

  static String _randomUrlSafe(int bytes) {
    final rnd = Random.secure();
    final values = List<int>.generate(bytes, (_) => rnd.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  static String _currentPathNoQuery() =>
      Uri.base.replace(queryParameters: const {}, fragment: '').toString();

  /// Builds the /auth/login URL for a federated connection and stashes the
  /// PKCE verifier + state in sessionStorage. Caller MUST navigate the
  /// browser there via a real top-level navigation (web.window.location) —
  /// not a fetch/XHR call, which cannot follow a cross-origin redirect out
  /// to the external IdP (see server_login.go's bindLoginRequestFromQuery).
  static String beginLoginUrl({
    required String connectionId,
    required String clientId,
    List<String> scope = const ['openid', 'profile', 'email'],
  }) {
    final verifier = _randomUrlSafe(32);
    final challengeBytes = sha256.convert(utf8.encode(verifier)).bytes;
    final challenge = base64Url.encode(challengeBytes).replaceAll('=', '');
    final state = _randomUrlSafe(16);
    final redirectUri = _currentPathNoQuery();

    web.window.sessionStorage.setItem(_verifierKey, verifier);
    web.window.sessionStorage.setItem(_stateKey, state);
    web.window.sessionStorage.setItem(_clientIdKey, clientId);
    web.window.sessionStorage.setItem(_redirectKey, redirectUri);

    return Uri.base.resolve('../auth/login').replace(queryParameters: {
      'provider': connectionId,
      'client_id': clientId,
      'response_type': 'code',
      'redirect_uri': redirectUri,
      'state': state,
      'scope': scope.join(' '),
      'code_challenge': challenge,
      'code_challenge_method': 'S256',
    }).toString();
  }

  /// Detects a return leg (URL carries `code` + `state` matching what was
  /// stashed before navigating away) and exchanges the code at /token.
  /// Returns null when this isn't a return leg (a normal page load, or an
  /// RP's own authorization_code landing here — the state won't match
  /// anything of ours, so this correctly no-ops rather than misfiring).
  /// Throws on a state mismatch (CSRF/replay) or a failed exchange.
  static Future<String?> consumeReturnIfPresent() async {
    final q = Uri.base.queryParameters;
    final code = q['code'];
    final state = q['state'];
    if (code == null || state == null) return null;

    final storedState = web.window.sessionStorage.getItem(_stateKey);
    if (storedState == null || storedState != state) {
      // Not ours — most likely an RP's own authorization_code response
      // landing on a path this app also serves. Leave it for whatever else
      // reads Uri.base; nothing to consume.
      return null;
    }
    final verifier = web.window.sessionStorage.getItem(_verifierKey);
    final clientId = web.window.sessionStorage.getItem(_clientIdKey);
    final redirectUri = web.window.sessionStorage.getItem(_redirectKey);
    web.window.sessionStorage.removeItem(_stateKey);
    web.window.sessionStorage.removeItem(_verifierKey);
    web.window.sessionStorage.removeItem(_clientIdKey);
    web.window.sessionStorage.removeItem(_redirectKey);
    if (verifier == null || clientId == null || redirectUri == null) {
      throw StateError('missing_pkce_state');
    }

    final resp = await http.post(
      Uri.base.resolve('../token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
      }),
    );
    final body = jsonDecode(resp.body) as Map<String, dynamic>;
    final accessToken = body['access_token'] as String?;
    if (resp.statusCode != 200 || accessToken == null) {
      throw StateError(body['error']?.toString() ?? 'token_exchange_failed');
    }
    return accessToken;
  }
}
