import 'dart:convert';
import 'package:http/http.dart' as http;

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
/// achieves the same "root of the current origin" resolution via
/// `Uri.base.resolve('/path')`, since a leading slash always replaces the
/// whole path regardless of what page loaded this app — no configurable
/// base URL needed because the reverse proxy fronts both on one origin.
class PortalApi {
  final http.Client _http = http.Client();
  String? _token;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  Uri _uri(String path) => Uri.base.resolve(path);

  Map<String, String> _headers({bool json = false}) => {
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (json) 'Content-Type': 'application/json',
      };

  Future<http.Response> get(String path) =>
      _http.get(_uri(path), headers: _headers());

  Future<http.Response> post(String path, [Object? body]) => _http.post(
        _uri(path),
        headers: _headers(json: true),
        body: body == null ? '' : jsonEncode(body),
      );

  Future<http.Response> patch(String path, Object body) => _http.patch(
        _uri(path),
        headers: _headers(json: true),
        body: jsonEncode(body),
      );

  Future<http.Response> delete(String path, [Object? body]) => _http.delete(
        _uri(path),
        headers: _headers(json: true),
        body: body == null ? null : jsonEncode(body),
      );

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
  Future<Map<String, dynamic>> login(String candidateToken) async {
    final previous = _token;
    _token = candidateToken;
    try {
      final r = await get('/me');
      if (r.statusCode != 200) {
        throw PortalApiError(r.statusCode, 'That token was not accepted.');
      }
      return decode(r);
    } catch (e) {
      _token = previous;
      if (e is PortalApiError) rethrow;
      throw PortalApiError(0, 'That token was not accepted.');
    }
  }

  void signOut() => _token = null;

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
