import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../services/browser_navigation.dart';
import '../../services/product_api_origin.dart';
import '../../services/session_storage.dart';

/// Extracts the server-minted, one-use transaction used to resume an RP
/// authorization after an upstream OIDC or SAML callback.
///
/// Snaplink places this value in the fragment so it is not sent as a referrer
/// or included in ordinary server access logs. Only the exact 32-byte
/// base64url representation minted by Snaplink is accepted; unrelated or
/// malformed fragments remain inert.
String? hostedFederatedTransactionId(Uri location) {
  if (location.fragment.isEmpty || location.fragment.length > 256) return null;
  try {
    final values = Uri(query: location.fragment).queryParametersAll;
    if (values.length != 1 ||
        !values.containsKey('login_transaction_id') ||
        values['login_transaction_id']!.length != 1) {
      return null;
    }
    final transactionId = values['login_transaction_id']!.single;
    return RegExp(r'^[A-Za-z0-9_-]{43}$').hasMatch(transactionId)
        ? transactionId
        : null;
  } on FormatException {
    return null;
  }
}

/// Handles the "Sign in with [a federated provider]" round trip for a
/// first-party login (this app itself is the OAuth client — a public PKCE
/// client, not an external relying party): generates and stashes its own
/// PKCE verifier before navigating away, then consumes the `code` this same
/// page is redirected back to once the external IdP (and this server's
/// /auth/callback) finish, exchanging it at /token.
///
/// redirect_uri is always the CURRENT page's path with no query/fragment —
/// it must stay byte-stable to match what's registered for this OAuth
/// client, so it can't carry the eventual "jump to this path after login"
/// target. Both that target and the verifier stay in sessionStorage; `state`
/// is an opaque random nonce and never carries Portal action credentials
/// through the external IdP hop. sessionStorage (not localStorage) is
/// intentional: none of this state may outlive one login attempt/tab.
class FederatedLogin {
  static const _exchangeTimeout = Duration(seconds: 30);
  static const _verifierKey = 'sso_pkce_verifier';
  static const _stateKey = 'sso_pkce_state';
  static const _clientIdKey = 'sso_pkce_client_id';
  static const _redirectKey = 'sso_pkce_redirect_uri';
  static const _targetKey = 'sso_pkce_redirect_target';

  static String _randomUrlSafe(int bytes) {
    final rnd = Random.secure();
    final values = List<int>.generate(bytes, (_) => rnd.nextInt(256));
    return base64Url.encode(values).replaceAll('=', '');
  }

  static String _currentPathNoQuery() =>
      Uri.base.replace(queryParameters: const {}, fragment: '').toString();

  /// Returns true only for a callback that belongs to a PKCE attempt started
  /// by this tab. The hosted login screen uses this before provider discovery
  /// so a callback cannot race a second `/auth/login` probe (or be redirected
  /// by branding/login-page discovery) while its one-time code is exchanged.
  static bool hasPendingReturn({Uri? location}) {
    if (!kIsWeb) return false;
    final states = (location ?? Uri.base).queryParametersAll['state'];
    if (states == null || states.length != 1 || states.single.isEmpty) {
      return false;
    }
    return SessionStorage.getItem(_stateKey) == states.single;
  }

  /// Builds the /auth/login URL for a federated connection and stashes the
  /// PKCE verifier + state in sessionStorage. Caller MUST navigate the
  /// browser there via a real top-level navigation (web.window.location) —
  /// not a fetch/XHR call, which cannot follow a cross-origin redirect out
  /// to the external IdP (see server_login.go's bindLoginRequestFromQuery).
  static String beginLoginUrl({
    required String connectionId,
    required String clientId,
    required String redirectTarget,
    List<String> scope = const ['openid', 'profile', 'email'],
  }) {
    if (!kIsWeb) {
      throw StateError('Federated sign-in requires the web console.');
    }
    final verifier = _randomUrlSafe(32);
    final challengeBytes = sha256.convert(utf8.encode(verifier)).bytes;
    final challenge = base64Url.encode(challengeBytes).replaceAll('=', '');
    final state = _randomUrlSafe(16);
    final redirectUri = _currentPathNoQuery();

    SessionStorage.setItem(_verifierKey, verifier);
    SessionStorage.setItem(_stateKey, state);
    SessionStorage.setItem(_clientIdKey, clientId);
    SessionStorage.setItem(_redirectKey, redirectUri);
    SessionStorage.setItem(_targetKey, redirectTarget);
    if (SessionStorage.getItem(_verifierKey) != verifier ||
        SessionStorage.getItem(_stateKey) != state ||
        SessionStorage.getItem(_clientIdKey) != clientId ||
        SessionStorage.getItem(_redirectKey) != redirectUri ||
        SessionStorage.getItem(_targetKey) != redirectTarget) {
      _clearPendingAttempt();
      throw StateError('pkce_storage_unavailable');
    }

    return ProductApiOrigin.baseUri
        .resolve('/auth/login')
        .replace(
          queryParameters: {
            'provider': connectionId,
            'client_id': clientId,
            'response_type': 'code',
            'redirect_uri': redirectUri,
            'state': state,
            'scope': scope.join(' '),
            'code_challenge': challenge,
            'code_challenge_method': 'S256',
          },
        )
        .toString();
  }

  /// Detects a return leg (URL carries `code` + `state` matching what was
  /// stashed before navigating away) and exchanges the code at /token.
  /// Returns null when this isn't a return leg (a normal page load, or an
  /// RP's own authorization_code landing here — the state won't match
  /// anything of ours, so this correctly no-ops rather than misfiring).
  /// Throws on a state mismatch (CSRF/replay) or a failed exchange.
  static Future<FederatedLoginResult?> consumeReturnIfPresent({
    http.Client? httpClient,
  }) async {
    if (!kIsWeb) return null;
    final query = Uri.base.queryParametersAll;
    final stateValues = query['state'];
    final storedState = SessionStorage.getItem(_stateKey);
    if (stateValues == null) return null;
    if (stateValues.length != 1) {
      if (storedState == null) return null;
      BrowserNavigation.replaceState(_currentPathNoQuery());
      _clearPendingAttempt();
      throw StateError('invalid_state');
    }
    final state = stateValues.single;
    if (storedState == null || storedState != state) {
      // Not ours — most likely an RP's own authorization_code response
      // landing on a path this app also serves. Leave it for whatever else
      // reads Uri.base; nothing to consume.
      return null;
    }
    final verifier = SessionStorage.getItem(_verifierKey);
    final clientId = SessionStorage.getItem(_clientIdKey);
    final redirectUri = SessionStorage.getItem(_redirectKey);
    final redirectTarget = SessionStorage.getItem(_targetKey);
    // A matched callback is one-shot even if the token exchange times out or
    // has an unknown result. Remove the authorization response from the
    // current history entry before any network await or external resource can
    // observe it, then consume every tab-scoped PKCE value.
    BrowserNavigation.replaceState(_currentPathNoQuery());
    _clearPendingAttempt();

    final codeValues = query['code'];
    if (codeValues != null && codeValues.length != 1) {
      throw StateError('invalid_authorization_response');
    }
    final code = codeValues?.single;
    if (code == null) {
      final errors = query['error'];
      if (errors != null && errors.length != 1) {
        throw StateError('invalid_authorization_response');
      }
      final descriptions = query['error_description'];
      final description = descriptions != null && descriptions.length == 1
          ? descriptions.first
          : null;
      throw StateError(
        description ?? errors?.single ?? 'federated_login_failed',
      );
    }
    if (verifier == null ||
        clientId == null ||
        redirectUri == null ||
        redirectTarget == null) {
      throw StateError('missing_pkce_state');
    }
    if (!_isSafeRedirectTarget(redirectTarget)) {
      throw StateError('invalid_redirect_target');
    }

    final request = (httpClient?.post ?? http.post)(
      ProductApiOrigin.baseUri.resolve('/token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'grant_type': 'authorization_code',
        'code': code,
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'code_verifier': verifier,
      }),
    );
    final resp = await request.timeout(_exchangeTimeout);
    Map<String, dynamic> body = const {};
    if (resp.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) body = decoded;
      } catch (_) {
        // non-JSON body (proxy error page, empty 5xx, ...) — fall through
        // to the generic token_exchange_failed below instead of throwing a
        // raw FormatException the caller would show to the user verbatim.
      }
    }
    final accessToken = body['access_token'] as String?;
    if (resp.statusCode != 200 || accessToken == null) {
      throw StateError(body['error']?.toString() ?? 'token_exchange_failed');
    }
    return FederatedLoginResult(
      accessToken: accessToken,
      redirectTarget: redirectTarget,
    );
  }

  static void _clearPendingAttempt() {
    SessionStorage.removeItem(_stateKey);
    SessionStorage.removeItem(_verifierKey);
    SessionStorage.removeItem(_clientIdKey);
    SessionStorage.removeItem(_redirectKey);
    SessionStorage.removeItem(_targetKey);
  }

  static bool _isSafeRedirectTarget(String value) {
    if (value.isEmpty || value.contains('\\')) return false;
    final target = Uri.tryParse(value);
    if (target == null) return false;
    if (!target.hasScheme && !target.hasAuthority) {
      return target.path.startsWith('/');
    }
    return target.hasAuthority &&
        (target.scheme == 'https' || target.scheme == 'http') &&
        target.origin == Uri.base.origin;
  }
}

class FederatedLoginResult {
  final String accessToken;
  final String redirectTarget;
  FederatedLoginResult({
    required this.accessToken,
    required this.redirectTarget,
  });
}
