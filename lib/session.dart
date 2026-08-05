import 'services/session_storage.dart';

/// Access-token persistence for redirect-based auth: a protected route (e.g.
/// /admin/) does a REAL browser redirect to /login/?redirect=[path] when
/// there's no session, and a real redirect back to [path] once login
/// succeeds — both hops are full page loads, so the token can't just live in
/// a Dart field the way it used to. sessionStorage (not localStorage) is
/// intentional: signed-in state shouldn't outlive the browser tab.
///
/// Native builds keep the same values only in process memory, allowing
/// authenticated in-app route replacement without persisting bearer tokens
/// to disk.
class Session {
  static const _tokenKey = 'sso_access_token';
  static const _sessionIdKey = 'sso_session_id';
  static const _clientIdKey = 'sso_client_id';

  /// Stores a freshly issued access token and verifies that the active
  /// storage implementation accepted every related value. Browser
  /// sessionStorage can be disabled or quota-blocked; silently navigating
  /// after a failed write would present a false authenticated state and lose
  /// the token on the next page load. Native memory storage always succeeds,
  /// while web callers can use the boolean to fail closed before redirecting.
  static bool store(String token, {String? sessionId, String? clientId}) {
    if (token.isEmpty) {
      clear();
      return false;
    }
    SessionStorage.setItem(_tokenKey, token);
    if (sessionId == null || sessionId.isEmpty) {
      SessionStorage.removeItem(_sessionIdKey);
    } else {
      SessionStorage.setItem(_sessionIdKey, sessionId);
    }
    if (clientId == null || clientId.isEmpty) {
      SessionStorage.removeItem(_clientIdKey);
    } else {
      SessionStorage.setItem(_clientIdKey, clientId);
    }
    final tokenStored = read() == token;
    final sessionStored = sessionId == null || sessionId.isEmpty
        ? readSessionId() == null
        : readSessionId() == sessionId;
    final clientStored = clientId == null || clientId.isEmpty
        ? readClientId() == null
        : readClientId() == clientId;
    if (!tokenStored || !sessionStored || !clientStored) {
      clear();
      return false;
    }
    return true;
  }

  static String? read() => SessionStorage.getItem(_tokenKey);

  /// Opaque/session-strategy access tokens have no readable JWT `sid` claim.
  /// Keep the direct-login session id in the same tab-scoped store so the
  /// self-service session controls can preserve the browser's own session.
  static String? readSessionId() => SessionStorage.getItem(_sessionIdKey);

  /// The authenticated client is needed to scope a trusted-device credential
  /// when the access token is opaque and therefore has no readable `aud`.
  static String? readClientId() => SessionStorage.getItem(_clientIdKey);

  static void clear() {
    SessionStorage.removeItem(_tokenKey);
    SessionStorage.removeItem(_sessionIdKey);
    SessionStorage.removeItem(_clientIdKey);
  }
}
