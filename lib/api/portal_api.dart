import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../services/product_api_origin.dart';

/// Thrown for any response the caller didn't explicitly ask to inspect.
/// Screens generally branch on `response.statusCode` themselves (mirroring
/// interfaces/web/portal/app.js, which treats 404 as "feature not wired" and
/// any other non-2xx as a validation/auth failure) — this is only raised by
/// the handful of convenience methods below that always expect success.
class PortalApiError implements Exception {
  final int status;
  final String message;
  PortalApiError(this.status, [String? message])
    : message = message ?? 'Request failed (status $status).';

  @override
  String toString() => message;
}

/// REST client for the self-service account portal ("/portal"), ported
/// straight from interfaces/web/portal/app.js.
///
/// There is no portal-specific login endpoint on the server: app.js just has
/// the end user paste their OWN bearer access token (obtained elsewhere,
/// e.g. from a completed OIDC login) and probes GET /me with it before
/// showing the app. This client does the same — [login] validates a token
/// and, once accepted, every subsequent call rides that token.
///
/// All paths are root-level (`/me`, `/sessions/me`, `/consents/me`,
/// `/roles/me`, `/permissions/me`, `/menus/me` — NOT the admin API under
/// `/api/v1/admin`). app.js reaches them via `".." + path` because the SPA
/// is itself served one path segment down at `/portal/`; this client
/// achieves the same root-path resolution through [ProductApiOrigin], which
/// is same-origin on web and configurable on native platforms.
class PortalApi {
  final http.Client _http;
  final Uri _baseUri;
  final Duration requestTimeout;
  String? _token;
  String? _sessionId;
  String? _clientId;

  PortalApi({
    http.Client? httpClient,
    Uri? baseUri,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? ProductApiOrigin.baseUri;

  /// Fired the first time an authenticated call comes back 401/403 while
  /// this is set — mid-session token expiry/revocation. Left unarmed until
  /// portal_screen.dart wires it in right after a session is established,
  /// so it never fires for the initial [login]/resume probe, which already
  /// has its own "token not accepted" handling.
  void Function()? onSessionExpired;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// The `sid` claim of the current bearer token (RFC 9068), decoded
  /// client-side straight out of the JWT payload — lets the portal tell
  /// whether a session the user just revoked was the one it is itself
  /// riding, with no extra server round-trip.
  String? get currentSessionId => _sessionId ?? _sidFromToken(_token);

  /// OAuth client ID carried by the current access token, used only to scope
  /// a locally retained trusted-device grant to that same client. Opaque
  /// session tokens need the client id captured by the hosted login flow.
  String? get currentClientId => _clientId ?? _claimFromToken(_token, 'aud');

  static String? _sidFromToken(String? token) {
    return _claimFromToken(token, 'sid');
  }

  static String? _claimFromToken(String? token, String claim) {
    if (token == null) return null;
    final parts = token.split('.');
    if (parts.length != 3) return null;
    try {
      final payload = utf8.decode(
        base64Url.decode(base64Url.normalize(parts[1])),
      );
      final claims = jsonDecode(payload);
      if (claims is Map) {
        final value = claims[claim];
        if (value is List && value.isNotEmpty) return value.first.toString();
        return value?.toString();
      }
    } catch (_) {
      // not a JWT / no sid claim; treat as unknown.
    }
    return null;
  }

  Uri _uri(String path) => _baseUri.resolve(path);

  Map<String, String> _headers({bool json = false}) => {
    if (_token != null) 'Authorization': 'Bearer $_token',
    if (json) 'Content-Type': 'application/json',
  };

  void _notifyIfSessionExpired(http.Response r) {
    // A 403 is often a valid session missing a feature-specific grant. For
    // example, trusted-device enrollment deliberately returns 403 until MFA
    // has happened in the current session. Only 401 invalidates this bearer.
    if (r.statusCode == 401) onSessionExpired?.call();
  }

  Future<http.Response> get(String path) async {
    final r = await _http
        .get(_uri(path), headers: _headers())
        .timeout(requestTimeout);
    _notifyIfSessionExpired(r);
    return r;
  }

  /// Opens the bearer-authenticated notification SSE feed. EventSource cannot
  /// attach Authorization, so this uses the same streamed HTTP client as the
  /// admin console and parses frames incrementally.
  Stream<Map<String, dynamic>> notificationEvents({
    String? lastEventId,
  }) async* {
    if (!hasToken) throw PortalApiError(401, 'A bearer token is required.');
    final request = http.Request('GET', _uri('/me/notifications/stream'))
      ..headers.addAll({
        'Accept': 'text/event-stream',
        'Authorization': 'Bearer $_token',
        if (lastEventId?.isNotEmpty ?? false) 'Last-Event-ID': lastEventId!,
      });
    final response = await _http.send(request).timeout(requestTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode == 401) onSessionExpired?.call();
      throw PortalApiError(response.statusCode);
    }
    final data = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (data.isNotEmpty) {
          final decoded = jsonDecode(data.join('\n'));
          if (decoded is Map<String, dynamic>) yield decoded;
        }
        data.clear();
        continue;
      }
      if (line.startsWith('data:')) {
        data.add(line.substring(5).trimLeft());
      }
    }
    if (data.isNotEmpty) {
      final decoded = jsonDecode(data.join('\n'));
      if (decoded is Map<String, dynamic>) yield decoded;
    }
  }

  Future<http.Response> post(String path, [Object? body]) async {
    final r = await _http
        .post(
          _uri(path),
          headers: _headers(json: true),
          body: body == null ? '' : jsonEncode(body),
        )
        .timeout(requestTimeout);
    _notifyIfSessionExpired(r);
    return r;
  }

  Future<http.Response> patch(String path, Object body) async {
    final r = await _http
        .patch(
          _uri(path),
          headers: _headers(json: true),
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    _notifyIfSessionExpired(r);
    return r;
  }

  Future<http.Response> put(String path, Object body) async {
    final r = await _http
        .put(_uri(path), headers: _headers(json: true), body: jsonEncode(body))
        .timeout(requestTimeout);
    _notifyIfSessionExpired(r);
    return r;
  }

  Future<http.Response> delete(String path, [Object? body]) =>
      _delete(path, body: body);

  Future<http.Response> deleteWithQuery(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) => _delete(path, body: body, query: query);

  Future<http.Response> _delete(
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    final r = await _http
        .delete(
          _uri(path).replace(queryParameters: query),
          headers: _headers(json: true),
          body: body == null ? null : jsonEncode(body),
        )
        .timeout(requestTimeout);
    _notifyIfSessionExpired(r);
    return r;
  }

  /// Decodes a JSON object body, treating an empty or unparsable body as `{}`
  /// — app.js's fetch chains do the equivalent by only calling `.json()` on
  /// responses it already expects to be JSON and swallowing the rest.
  static Map<String, dynamic> decode(http.Response r) {
    if (r.body.isEmpty) return const {};
    try {
      final d = jsonDecode(r.body);
      if (d is Map<String, dynamic>) return d;
    } catch (_) {
      // non-JSON body; treated as absent, same as app.js's catch handlers.
    }
    return const {};
  }

  /// Validates [candidateToken] against GET /me — the same probe app.js runs
  /// before it will show the app, whether from the login form or from a
  /// resumed session. Only installs the token if it is accepted.
  Future<Map<String, dynamic>> login(
    String candidateToken, {
    String? sessionId,
    String? clientId,
  }) async {
    final previous = _token;
    final previousSessionId = _sessionId;
    final previousClientId = _clientId;
    _token = candidateToken;
    _sessionId = sessionId;
    _clientId = clientId;
    try {
      final r = await get('/me');
      if (r.statusCode != 200) {
        throw PortalApiError(r.statusCode, 'That token was not accepted.');
      }
      return decode(r);
    } catch (e) {
      _token = previous;
      _sessionId = previousSessionId;
      _clientId = previousClientId;
      if (e is PortalApiError) rethrow;
      throw PortalApiError(0, 'That token was not accepted.');
    }
  }

  void signOut() {
    _token = null;
    _sessionId = null;
    _clientId = null;
  }

  /// Asks Snaplink to revoke the active bearer before local state is cleared.
  /// The caller still clears locally in a `finally` block so an offline tab
  /// cannot retain a token after an explicit sign-out request.
  Future<http.Response> logout() => post('/logout');

  Future<Map<String, dynamic>> fetchMe() async {
    final r = await get('/me');
    if (r.statusCode != 200) {
      throw PortalApiError(r.statusCode, 'Could not load your profile.');
    }
    return decode(r);
  }

  /// Fetches a `{key: [...]}` list endpoint, treating ANY non-200 (including
  /// 404 "not wired") as an empty list — matches app.js's `fetchSection`,
  /// which hides its card entirely rather than surfacing an error for these
  /// optional, best-effort disclosures (roles/permissions/menus/orgs).
  Future<List<dynamic>> fetchListOrEmpty(String path, String key) async {
    try {
      final r = await get(path);
      if (r.statusCode != 200) return const [];
      final d = decode(r);
      return (d[key] as List?) ?? const [];
    } catch (_) {
      return const [];
    }
  }
}
