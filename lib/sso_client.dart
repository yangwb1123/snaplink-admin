import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// Thrown on any non-2xx response from the SSO server; carries the parsed
/// error body when the response was JSON.
class SSOError implements Exception {
  final int status;
  final String? error;
  final String? errorDescription;

  SSOError(this.status, this.error, this.errorDescription);

  @override
  String toString() =>
      errorDescription ?? error ?? 'SSO request failed with status $status';
}

/// Minimal admin-API client for the sso_admin Flutter app: direct
/// password-grant login (mirrors the TypeScript SDK's login()) plus the
/// small slice of the admin REST surface this MVP covers (clients, users,
/// tenants + suspend/activate).
class SSOAdminClient {
  final String baseUrl;
  final http.Client _http = http.Client();
  String? _token;

  SSOAdminClient(String baseUrl) : baseUrl = _stripTrailingSlash(baseUrl);

  /// Same-origin default: the Flutter bundle and the SSO API are always
  /// served from the same origin in every deployment mode this app
  /// supports (OpenResty fronts both on web; native builds fall back to
  /// [nativeDefaultBaseUrl]) — mirrors how oidc_login_api.dart resolves
  /// `/auth/login` etc. relative to Uri.base with no configurable field.
  factory SSOAdminClient.sameOrigin() =>
      SSOAdminClient(_sameOriginBaseUrl() ?? nativeDefaultBaseUrl);

  /// Wraps an access_token already obtained elsewhere (the unified /login
  /// screen) as a logged-in client, without a second network round trip.
  factory SSOAdminClient.withToken(String accessToken, {String? baseUrl}) {
    final client = SSOAdminClient(baseUrl ?? _sameOriginBaseUrl() ?? nativeDefaultBaseUrl);
    client._token = accessToken;
    return client;
  }

  /// Compiled-in fallback for native (non-web) builds, which have no page
  /// origin to infer from. Native builds don't yet expose a way to override
  /// this — a settings screen for that is a documented follow-up, not
  /// silently omitted.
  static const nativeDefaultBaseUrl = 'https://sso.ywbsd.site';

  static String? _sameOriginBaseUrl() {
    if (!kIsWeb) return null;
    final origin = Uri.base;
    if (origin.host.isEmpty) return null;
    return Uri(scheme: origin.scheme, host: origin.host, port: origin.hasPort ? origin.port : null).toString();
  }

  static String _stripTrailingSlash(String s) =>
      s.replaceAll(RegExp(r'/+$'), '');

  bool get isLoggedIn => _token != null;

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String clientId = 'sso-admin-console',
  }) async {
    final body = await _post('/auth/login', {
      'provider': 'password',
      'client_id': clientId,
      'scope': ['openid', 'profile', 'admin:read', 'admin:write'],
      'credential': {'username': username, 'password': password},
    }, auth: false);
    final map = body as Map<String, dynamic>;
    if (map['access_token'] != null) {
      _token = map['access_token'] as String;
    }
    return map;
  }

  void logout() {
    _token = null;
  }

  Future<List<dynamic>> listClients() async {
    final data = await _get('/api/v1/admin/clients') as Map<String, dynamic>;
    return (data['clients'] as List?) ?? const [];
  }

  Future<List<dynamic>> listUsers() async {
    final data = await _get('/api/v1/admin/users') as Map<String, dynamic>;
    return (data['users'] as List?) ?? const [];
  }

  Future<List<dynamic>> listTenants() async {
    final data = await _get('/api/v1/admin/tenants') as Map<String, dynamic>;
    return (data['tenants'] as List?) ?? const [];
  }

  Future<void> setTenantStatus(String id, String status) async {
    await _post('/api/v1/admin/tenants/$id:set-status', {'status': status});
  }

  // ---- clients CRUD ----

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> client) async {
    final data = await _post('/api/v1/admin/clients', client) as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateClient(String id, Map<String, dynamic> client) async {
    final data = await _put('/api/v1/admin/clients/${Uri.encodeComponent(id)}', client) as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteClient(String id) async {
    await _delete('/api/v1/admin/clients/${Uri.encodeComponent(id)}');
  }

  Future<String> rotateClientSecret(String id) async {
    final data = await _post('/api/v1/admin/clients/${Uri.encodeComponent(id)}/rotate-secret', const {}) as Map<String, dynamic>;
    return data['secret'] as String? ?? '';
  }

  // ---- users CRUD ----

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> user) async {
    final data = await _post('/api/v1/admin/users', user) as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateUser(String id, Map<String, dynamic> user) async {
    final data = await _put('/api/v1/admin/users/${Uri.encodeComponent(id)}', user) as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteUser(String id) async {
    await _delete('/api/v1/admin/users/${Uri.encodeComponent(id)}');
  }

  // ---- tenants CRUD ----

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> tenant) async {
    final data = await _post('/api/v1/admin/tenants', tenant) as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateTenant(String id, Map<String, dynamic> tenant) async {
    final data = await _put('/api/v1/admin/tenants/${Uri.encodeComponent(id)}', tenant) as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteTenant(String id) async {
    await _delete('/api/v1/admin/tenants/${Uri.encodeComponent(id)}');
  }

  Map<String, String> _authHeaders() =>
      _token != null ? {'Authorization': 'Bearer $_token'} : const {};

  Future<dynamic> _get(String path) async {
    final resp = await _http.get(Uri.parse('$baseUrl$path'), headers: _authHeaders());
    return _handle(resp);
  }

  Future<dynamic> _post(String path, Map<String, dynamic> body, {bool auth = true}) async {
    final headers = {'Content-Type': 'application/json', if (auth) ..._authHeaders()};
    final resp = await _http.post(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body));
    return _handle(resp);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final headers = {'Content-Type': 'application/json', ..._authHeaders()};
    final resp = await _http.put(Uri.parse('$baseUrl$path'), headers: headers, body: jsonEncode(body));
    return _handle(resp);
  }

  Future<dynamic> _delete(String path) async {
    final resp = await _http.delete(Uri.parse('$baseUrl$path'), headers: _authHeaders());
    return _handle(resp);
  }

  dynamic _handle(http.Response resp) {
    Map<String, dynamic> parsed = const {};
    if (resp.body.isNotEmpty) {
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) parsed = decoded;
      } catch (_) {
        // non-JSON body; fall through to the generic status-based error below.
      }
    }
    if (resp.statusCode >= 200 && resp.statusCode < 300) {
      return parsed;
    }
    throw SSOError(
      resp.statusCode,
      parsed['error'] as String? ?? parsed['code']?.toString(),
      parsed['error_description'] as String? ?? parsed['message'] as String?,
    );
  }
}
