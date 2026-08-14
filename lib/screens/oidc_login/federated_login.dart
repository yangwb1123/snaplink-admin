/// Federated first-party sign-in: the PKCE round trip with an external
/// identity provider (this app is the OAuth client — a public PKCE client,
/// not an external relying party).
///
/// Semantics are fixed and fail closed: the verifier and `state` live only in
/// this tab's sessionStorage and are consumed exactly once; a callback is
/// adopted only when its `state` matches what this tab minted (anything else
/// stays inert — the page never acts on a state it did not mint, so an
/// attacker cannot enumerate or race the one-time code); and the browser
/// never invents a continuation — `code` is exchanged at /token with the
/// tab-scoped verifier and the return target must be a safe same-origin path.
library;

import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import '../../i18n/app_strings.dart';
import '../../services/browser_navigation.dart';
import '../../services/product_api_origin.dart';
import '../../services/session_storage.dart';

/// Fragment key of the server-minted, one-use transaction that resumes an RP
/// authorization after an upstream OIDC or SAML callback, placed in the
/// fragment so it is not sent as a referrer or included in ordinary server
/// access logs. Only the exact 32-byte base64url representation minted by
/// Snaplink is accepted; unrelated or malformed fragments remain inert.
const _transactionFragmentKey = 'login_transaction_id';

final _transactionIdPattern = RegExp(r'^[A-Za-z0-9_-]{43}$');

/// Extracts the server-minted, one-use transaction used to resume an RP
/// authorization after an upstream OIDC or SAML callback.
String? hostedFederatedTransactionId(Uri location) {
  if (location.fragment.isEmpty || location.fragment.length > 256) return null;
  try {
    final values = Uri(query: location.fragment).queryParametersAll;
    if (values.length != 1 ||
        !values.containsKey(_transactionFragmentKey) ||
        values[_transactionFragmentKey]!.length != 1) {
      return null;
    }
    final transactionId = values[_transactionFragmentKey]!.single;
    return _transactionIdPattern.hasMatch(transactionId) ? transactionId : null;
  } on FormatException {
    return null;
  }
}

/// Presentation contract for the federated sign-in return surface: pending
/// (return check in flight), resolved (the one-time PKCE callback was
/// consumed and exchanged), and failed (fail closed — nothing was replayed).
enum FederatedLoginPhase { pending, resolved, failed }

/// Typed failure classification for [FederatedLoginPhase.failed], replacing
/// bare `StateError` strings the host would otherwise render verbatim. The
/// classification never changes the underlying decision — the one-time
/// callback is still consumed (or rejected) exactly once.
enum FederatedLoginFailure {
  /// The PKCE verifier and state could not be persisted to tab-scoped
  /// sessionStorage before navigating away.
  storageUnavailable,

  /// The callback carried a `state` this tab did not mint, or a duplicated
  /// `state` — CSRF/replay rejected, nothing consumed.
  invalidState,

  /// The callback carried a malformed authorization response (duplicate or
  /// missing `code` / `error` parameters).
  invalidAuthorizationResponse,

  /// The upstream provider declined the sign-in (`error` /
  /// `error_description` on the return leg).
  providerDeclined,

  /// A matching callback arrived without the tab-scoped PKCE values it was
  /// supposed to carry.
  missingPkceState,

  /// The embedded return target was not a safe same-origin path.
  invalidRedirectTarget,

  /// The one-time code exchange at /token failed or timed out.
  tokenExchangeFailed,
}

/// Localized copy for the federated sign-in return surface. [failure] is
/// required for [FederatedLoginPhase.failed].
String federatedLoginStatusLabel(
  AppStrings strings,
  FederatedLoginPhase phase, [
  FederatedLoginFailure? failure,
]) => switch (phase) {
  FederatedLoginPhase.pending => strings.translate(
    'Checking for a pending federated sign-in…',
  ),
  FederatedLoginPhase.resolved => strings.translate(
    'Federated sign-in completed. Resuming your session…',
  ),
  FederatedLoginPhase.failed => strings.translate(
    _failedFederatedLoginCopy(failure),
  ),
};

String _failedFederatedLoginCopy(FederatedLoginFailure? failure) =>
    switch (failure) {
      FederatedLoginFailure.storageUnavailable =>
        'Federated sign-in could not start because secure tab storage is '
            'unavailable.',
      FederatedLoginFailure.providerDeclined =>
        'The identity provider declined the sign-in. Start again or choose '
            'another sign-in method.',
      FederatedLoginFailure.tokenExchangeFailed =>
        'The federated sign-in code could not be exchanged. Start sign-in '
            'again; the one-time callback was not replayed.',
      _ =>
        'Federated sign-in could not be completed. Start sign-in again; the '
            'one-time callback was not replayed.',
    };

/// Query parameter and JSON field names of the first-party PKCE exchange.
const _authLoginPath = '/auth/login';
const _tokenPath = '/token';
const _queryProvider = 'provider';
const _queryClientId = 'client_id';
const _queryResponseType = 'response_type';
const _queryRedirectUri = 'redirect_uri';
const _queryState = 'state';
const _queryScope = 'scope';
const _queryCodeChallenge = 'code_challenge';
const _queryCodeChallengeMethod = 'code_challenge_method';
const _queryCode = 'code';
const _queryFailure = 'error';
const _queryFailureDescription = 'error_description';
const _grantTypeField = 'grant_type';
const _authorizationCodeGrant = 'authorization_code';
const _codeVerifierField = 'code_verifier';
const _accessTokenField = 'access_token';
const _contentTypeHeader = 'Content-Type';
const _jsonContentType = 'application/json';

/// All tab-scoped PKCE values of one pending attempt, read together so the
/// sessionStorage key set lives in a single place.
typedef _PendingPkceAttempt = ({
  String? verifier,
  String? state,
  String? clientId,
  String? redirectUri,
  String? redirectTarget,
});

/// Handles the "Sign in with [a federated provider]" round trip for a
/// first-party login: generates and stashes its own PKCE verifier before
/// navigating away, then consumes the `code` this same page is redirected
/// back to once the external IdP (and this server's /auth/callback) finish,
/// exchanging it at /token.
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
    final states = (location ?? Uri.base).queryParametersAll[_queryState];
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
    final persisted = _readPendingAttempt();
    if (persisted.verifier != verifier ||
        persisted.state != state ||
        persisted.clientId != clientId ||
        persisted.redirectUri != redirectUri ||
        persisted.redirectTarget != redirectTarget) {
      _clearPendingAttempt();
      throw StateError('pkce_storage_unavailable');
    }

    return ProductApiOrigin.baseUri
        .resolve(_authLoginPath)
        .replace(
          queryParameters: {
            _queryProvider: connectionId,
            _queryClientId: clientId,
            _queryResponseType: 'code',
            _queryRedirectUri: redirectUri,
            _queryState: state,
            _queryScope: scope.join(' '),
            _queryCodeChallenge: challenge,
            _queryCodeChallengeMethod: 'S256',
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
    final pending = _readPendingAttempt();
    final stateValues = query[_queryState];
    if (stateValues == null) return null;
    if (stateValues.length != 1) {
      if (pending.state == null) return null;
      BrowserNavigation.replaceState(_currentPathNoQuery());
      _clearPendingAttempt();
      throw StateError('invalid_state');
    }
    final state = stateValues.single;
    if (pending.state == null || pending.state != state) {
      // Not ours — most likely an RP's own authorization_code response
      // landing on a path this app also serves. Leave it for whatever else
      // reads Uri.base; nothing to consume.
      return null;
    }
    final verifier = pending.verifier;
    final clientId = pending.clientId;
    final redirectUri = pending.redirectUri;
    final redirectTarget = pending.redirectTarget;
    // A matched callback is one-shot even if the token exchange times out or
    // has an unknown result. Remove the authorization response from the
    // current history entry before any network await or external resource can
    // observe it, then consume every tab-scoped PKCE value.
    BrowserNavigation.replaceState(_currentPathNoQuery());
    _clearPendingAttempt();

    final codeValues = query[_queryCode];
    if (codeValues != null && codeValues.length != 1) {
      throw StateError('invalid_authorization_response');
    }
    final code = codeValues?.single;
    if (code == null) {
      final errors = query[_queryFailure];
      if (errors != null && errors.length != 1) {
        throw StateError('invalid_authorization_response');
      }
      final descriptions = query[_queryFailureDescription];
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
      ProductApiOrigin.baseUri.resolve(_tokenPath),
      headers: {_contentTypeHeader: _jsonContentType},
      body: jsonEncode({
        _grantTypeField: _authorizationCodeGrant,
        _queryCode: code,
        _queryClientId: clientId,
        _queryRedirectUri: redirectUri,
        _codeVerifierField: verifier,
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
    final accessToken = body[_accessTokenField] as String?;
    if (resp.statusCode != 200 || accessToken == null) {
      throw StateError(
        body[_queryFailure]?.toString() ?? 'token_exchange_failed',
      );
    }
    return FederatedLoginResult(
      accessToken: accessToken,
      redirectTarget: redirectTarget,
    );
  }

  static _PendingPkceAttempt _readPendingAttempt() => (
    verifier: SessionStorage.getItem(_verifierKey),
    state: SessionStorage.getItem(_stateKey),
    clientId: SessionStorage.getItem(_clientIdKey),
    redirectUri: SessionStorage.getItem(_redirectKey),
    redirectTarget: SessionStorage.getItem(_targetKey),
  );

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
