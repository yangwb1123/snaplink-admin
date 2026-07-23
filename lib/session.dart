import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:web/web.dart' as web;

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
    if (!kIsWeb) return;
    web.window.sessionStorage.setItem(_tokenKey, token);
    if (sessionId == null || sessionId.isEmpty) {
      web.window.sessionStorage.removeItem(_sessionIdKey);
    } else {
      web.window.sessionStorage.setItem(_sessionIdKey, sessionId);
    }
    if (clientId == null || clientId.isEmpty) {
      web.window.sessionStorage.removeItem(_clientIdKey);
    } else {
      web.window.sessionStorage.setItem(_clientIdKey, clientId);
    }
  }

  static String? read() {
    if (!kIsWeb) return null;
    return web.window.sessionStorage.getItem(_tokenKey);
  }

  /// Opaque/session-strategy access tokens have no readable JWT `sid` claim.
  /// Keep the direct-login session id in the same tab-scoped store so the
  /// self-service session controls can preserve the browser's own session.
  static String? readSessionId() {
    if (!kIsWeb) return null;
    return web.window.sessionStorage.getItem(_sessionIdKey);
  }

  /// The authenticated client is needed to scope a trusted-device credential
  /// when the access token is opaque and therefore has no readable `aud`.
  static String? readClientId() {
    if (!kIsWeb) return null;
    return web.window.sessionStorage.getItem(_clientIdKey);
  }

  static void clear() {
    if (!kIsWeb) return;
    web.window.sessionStorage.removeItem(_tokenKey);
    web.window.sessionStorage.removeItem(_sessionIdKey);
    web.window.sessionStorage.removeItem(_clientIdKey);
  }
}
