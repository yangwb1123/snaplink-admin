import 'dart:convert';
import 'package:http/http.dart' as http;

/// Thrown on any non-2xx response from the SSO server's Dynamic Client
/// Registration endpoints; carries the parsed OAuth-style error body
/// ({"error":"...", "error_description":"..."}) that /register and
/// /register/:client_id return on every failure.
class DeveloperApiError implements Exception {
  final int status;
  final String? error;
  final String? errorDescription;

  DeveloperApiError(this.status, this.error, this.errorDescription);

  @override
  String toString() =>
      errorDescription ?? error ?? 'Request failed with status $status';
}

/// Talks to this SDK's Dynamic Client Registration endpoints (RFC 7591
/// register, RFC 7592 read/update/delete) on behalf of the Developer
/// Portal screen.
///
/// There is no developer login/account in this flow: registration itself
/// is either open or gated by an operator-configured initial access token
/// (a bearer sent only if the developer supplies one), and every
/// subsequent read/update/delete of an already-registered app is
/// authenticated solely by the registration_access_token that /register
/// returned. Requests are built against the CURRENT origin (Uri.base) since
/// this app is served from behind the same reverse proxy as the SSO API.
class DeveloperApi {
  final http.Client _http;

  DeveloperApi({http.Client? httpClient}) : _http = httpClient ?? http.Client();

  /// POST /register — RFC 7591 Dynamic Client Registration.
  /// [initialAccessToken] is only sent (as a Bearer token) when the
  /// developer supplied one; omitted, registration is open.
  Future<Map<String, dynamic>> register({
    required String clientName,
    required List<String> redirectUris,
    required String scope,
    required String tokenEndpointAuthMethod,
    required String tokenStrategy,
    String? initialAccessToken,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (initialAccessToken != null && initialAccessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $initialAccessToken';
    }
    final resp = await _http.post(
      Uri.base.resolve('/register'),
      headers: headers,
      body: jsonEncode({
        'client_name': clientName,
        'redirect_uris': redirectUris,
        'scope': scope,
        'token_endpoint_auth_method': tokenEndpointAuthMethod,
        'token_strategy': tokenStrategy,
      }),
    );
    return _handle(resp);
  }

  /// GET /register/:client_id — RFC 7592, authenticated by the
  /// registration_access_token alone (no admin bearer, no login). The
  /// server collapses every failure (wrong token, unknown client_id) to
  /// the same 401 shape by design (anti-enumeration) — callers must not
  /// try to distinguish them from the thrown [DeveloperApiError].
  Future<Map<String, dynamic>> loadApp({
    required String clientId,
    required String token,
  }) async {
    final resp = await _http.get(
      Uri.base.resolve('/register/${Uri.encodeComponent(clientId)}'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    );
    return _handle(resp);
  }

  /// PUT /register/:client_id — RFC 7592 full update. Callers must pass
  /// the COMPLETE prior registration (from [loadApp]) overlaid with only
  /// the fields the UI edits; the server takes fields absent from the
  /// request body verbatim with no stored-value fallback (unlike
  /// token_strategy/token_endpoint_auth_method, which the server itself
  /// preserves when omitted), so dropping a field here would silently wipe
  /// real client capabilities (grant_types, response_types,
  /// allowed_authenticators, allowed_resources,
  /// post_logout_redirect_uris, ...).
  Future<Map<String, dynamic>> saveApp({
    required String clientId,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final resp = await _http.put(
      Uri.base.resolve('/register/${Uri.encodeComponent(clientId)}'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),
    );
    return _handle(resp);
  }

  /// DELETE /register/:client_id — RFC 7592 delete.
  Future<void> deleteApp({
    required String clientId,
    required String token,
  }) async {
    final resp = await _http.delete(
      Uri.base.resolve('/register/${Uri.encodeComponent(clientId)}'),
      headers: {'Authorization': 'Bearer $token'},
    );
    _handle(resp);
  }

  Map<String, dynamic> _handle(http.Response resp) {
    Map<String, dynamic> parsed = const {};
    if (resp.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) parsed = decoded;
      } catch (_) {
        // non-JSON body (or empty, e.g. a 204); fall through to the
        // generic status-based error below.
      }
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return parsed;
    }
    throw DeveloperApiError(
      resp.statusCode,
      parsed['error'] as String?,
      parsed['error_description'] as String?,
    );
  }
}
