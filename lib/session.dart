import 'services/session_storage.dart';

/// Access-token persistence for redirect-based auth: a protected route (e.g.
/// /admin/) does a REAL browser redirect to /login/?redirect=[path] when
/// there's no session, and a real redirect back to [path] once login
/// succeeds — both hops are full page loads, so the token can't just live in
/// a Dart field the way it used to. sessionStorage (not localStorage) is
/// intentional: signed-in state shouldn't outlive the browser tab.
///
/// Web only: native builds have no comparable "redirect between paths"
/// concept (there's no page to navigate), so [store]/[read]/[clear] are
/// no-ops off web — callers fall back to the in-memory-only behavior that
/// already existed before this.
class Session {
  static const _tokenKey = 'sso_access_token';
  static const _sessionIdKey = 'sso_session_id';
  static const _clientIdKey = 'sso_client_id';

  static void store(String token, {String? sessionId, String? clientId}) {
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
