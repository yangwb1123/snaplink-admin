import 'dart:convert';

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
  static const _refreshTokenKey = 'sso_refresh_token';
  static const _sessionIdKey = 'sso_session_id';
  static const _clientIdKey = 'sso_client_id';
  static const _scopedClientsKey = 'sso_scoped_clients';

  static String _clientKey(String key, String clientId) =>
      '$key:${Uri.encodeComponent(clientId)}';

  static List<String> _scopedClients() {
    final raw = SessionStorage.getItem(_scopedClientsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<String>()
            .where((clientId) => clientId.isNotEmpty)
            .toSet()
            .toList(growable: false);
      }
    } on FormatException {
      // A corrupt index must not prevent clearing the default session.
    }
    return const [];
  }

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

  /// Stores credentials for an explicitly selected OAuth client without
  /// replacing the Console's default first-party session. Dedicated product
  /// clients such as Forge use this slot so their narrower token cannot
  /// overwrite the Admin Console token in the same browser tab.
  static bool storeForClient(
    String clientId,
    String token, {
    String? sessionId,
    String? refreshToken,
  }) {
    if (clientId.isEmpty) return false;
    if (token.isEmpty) {
      clearForClient(clientId);
      return false;
    }
    final tokenKey = _clientKey(_tokenKey, clientId);
    final sessionIdKey = _clientKey(_sessionIdKey, clientId);
    final clientIdKey = _clientKey(_clientIdKey, clientId);
    SessionStorage.setItem(tokenKey, token);
    final refreshTokenKey = _clientKey(_refreshTokenKey, clientId);
    if (refreshToken == null || refreshToken.isEmpty) {
      SessionStorage.removeItem(refreshTokenKey);
    } else {
      SessionStorage.setItem(refreshTokenKey, refreshToken);
    }
    if (sessionId == null || sessionId.isEmpty) {
      SessionStorage.removeItem(sessionIdKey);
    } else {
      SessionStorage.setItem(sessionIdKey, sessionId);
    }
    SessionStorage.setItem(clientIdKey, clientId);
    final clients = _scopedClients().toSet()..add(clientId);
    SessionStorage.setItem(_scopedClientsKey, jsonEncode(clients.toList()));
    final tokenStored = SessionStorage.getItem(tokenKey) == token;
    final refreshTokenStored = refreshToken == null || refreshToken.isEmpty
        ? SessionStorage.getItem(refreshTokenKey) == null
        : SessionStorage.getItem(refreshTokenKey) == refreshToken;
    final sessionStored = sessionId == null || sessionId.isEmpty
        ? SessionStorage.getItem(sessionIdKey) == null
        : SessionStorage.getItem(sessionIdKey) == sessionId;
    final clientStored = SessionStorage.getItem(clientIdKey) == clientId;
    final indexed = _scopedClients().contains(clientId);
    if (!tokenStored ||
        !refreshTokenStored ||
        !sessionStored ||
        !clientStored ||
        !indexed) {
      clearForClient(clientId);
      return false;
    }
    return true;
  }

  static String? readForClient(String clientId) => clientId.isEmpty
      ? null
      : SessionStorage.getItem(_clientKey(_tokenKey, clientId));

  static String? readRefreshTokenForClient(String clientId) => clientId.isEmpty
      ? null
      : SessionStorage.getItem(_clientKey(_refreshTokenKey, clientId));

  static String? readSessionIdForClient(String clientId) => clientId.isEmpty
      ? null
      : SessionStorage.getItem(_clientKey(_sessionIdKey, clientId));

  static String? readClientIdForClient(String clientId) => clientId.isEmpty
      ? null
      : SessionStorage.getItem(_clientKey(_clientIdKey, clientId));

  static void clearForClient(String clientId) {
    if (clientId.isEmpty) return;
    SessionStorage.removeItem(_clientKey(_tokenKey, clientId));
    SessionStorage.removeItem(_clientKey(_refreshTokenKey, clientId));
    SessionStorage.removeItem(_clientKey(_sessionIdKey, clientId));
    SessionStorage.removeItem(_clientKey(_clientIdKey, clientId));
    final clients = _scopedClients().where((id) => id != clientId).toList();
    if (clients.isEmpty) {
      SessionStorage.removeItem(_scopedClientsKey);
    } else {
      SessionStorage.setItem(_scopedClientsKey, jsonEncode(clients));
    }
  }

  static void clear() {
    for (final clientId in _scopedClients()) {
      SessionStorage.removeItem(_clientKey(_tokenKey, clientId));
      SessionStorage.removeItem(_clientKey(_refreshTokenKey, clientId));
      SessionStorage.removeItem(_clientKey(_sessionIdKey, clientId));
      SessionStorage.removeItem(_clientKey(_clientIdKey, clientId));
    }
    SessionStorage.removeItem(_scopedClientsKey);
    SessionStorage.removeItem(_tokenKey);
    SessionStorage.removeItem(_sessionIdKey);
    SessionStorage.removeItem(_clientIdKey);
  }
}
