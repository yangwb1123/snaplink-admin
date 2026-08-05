import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../services/product_api_origin.dart';
import 'dcr_models.dart';

/// Thrown on any non-2xx response from the SSO server's Dynamic Client
/// Registration endpoints; carries the parsed OAuth-style error body
/// ({"error":"...", "error_description":"..."}) that /register and
/// /register/:client_id return on every failure.
class DeveloperApiError implements Exception {
  final int status;
  final String? error;
  final String? errorDescription;

  DeveloperApiError(this.status, this.error, this.errorDescription);

  bool get isInvalidManagementCredential => status == 401 || status == 404;

  bool get isRetryable => status >= 500 || status == 408 || status == 429;

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
/// returned. Requests stay same-origin on web and follow the configured
/// Snaplink service origin on native platforms.
class DeveloperApi {
  final http.Client _http;
  final Uri _baseUri;
  final Duration _timeout;

  DeveloperApi({
    http.Client? httpClient,
    Uri? baseUri,
    Duration timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _baseUri = baseUri ?? ProductApiOrigin.baseUri,
       _timeout = timeout;

  Future<DcrDiscovery> loadDiscovery() async {
    final response = await _http
        .get(
          _baseUri.resolve('/.well-known/openid-configuration'),
          headers: {'Accept': 'application/json'},
        )
        .timeout(_timeout);
    return DcrDiscovery.fromJson(_handle(response));
  }

  Future<Map<String, dynamic>> registerMetadata({
    required DcrClientMetadata metadata,
    String? initialAccessToken,
  }) {
    return _registerBody(
      metadata.toRegistrationWire(),
      initialAccessToken: initialAccessToken,
    );
  }

  /// POST /register — RFC 7591 Dynamic Client Registration.
  /// [initialAccessToken] is only sent (as a Bearer token) when the
  /// developer supplied one; omitted, registration is open.
  Future<Map<String, dynamic>> register({
    required String clientName,
    required List<String> redirectUris,
    required String scope,
    required String tokenEndpointAuthMethod,
    required String tokenStrategy,
    Map<String, dynamic> additionalMetadata = const {},
    String? initialAccessToken,
  }) async {
    return _registerBody({
      ...additionalMetadata,
      'client_name': clientName,
      'redirect_uris': redirectUris,
      'scope': scope,
      'token_endpoint_auth_method': tokenEndpointAuthMethod,
      'token_strategy': tokenStrategy,
    }, initialAccessToken: initialAccessToken);
  }

  Future<Map<String, dynamic>> _registerBody(
    Map<String, dynamic> body, {
    String? initialAccessToken,
  }) async {
    final headers = {'Content-Type': 'application/json'};
    if (initialAccessToken != null && initialAccessToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $initialAccessToken';
    }
    final resp = await _http
        .post(
          _baseUri.resolve('/register'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(_timeout);
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
    final resp = await _http
        .get(
          _baseUri.resolve('/register/${Uri.encodeComponent(clientId)}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        )
        .timeout(_timeout);
    return _handle(resp);
  }

  /// PUT /register/:client_id — RFC 7592 lossless full update. Current
  /// Snaplink reads and writes return every persisted management field;
  /// [DcrRoundTripSafety] retains a fail-closed guard for older replicas.
  Future<Map<String, dynamic>> saveApp({
    required String clientId,
    required String token,
    required Map<String, dynamic> body,
  }) async {
    final resp = await _http
        .put(
          _baseUri.resolve('/register/${Uri.encodeComponent(clientId)}'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    return _handle(resp);
  }

  /// DELETE /register/:client_id — RFC 7592 delete.
  Future<void> deleteApp({
    required String clientId,
    required String token,
  }) async {
    final resp = await _http
        .delete(
          _baseUri.resolve('/register/${Uri.encodeComponent(clientId)}'),
          headers: {'Authorization': 'Bearer $token'},
        )
        .timeout(_timeout);
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
      parsed['error']?.toString(),
      parsed['error_description']?.toString(),
    );
  }
}
