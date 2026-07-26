import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:sso_admin/api/snaplink_admin_types.dart';
import 'package:sso_admin/api/data_cache.dart';
import 'package:sso_admin/services/audit_log_service.dart';
export 'snaplink_admin_types.dart';
// routes constant moved to snaplink_admin_types.dart
/// A non-successful response from Snaplink's admin surface.
///
/// The API deliberately keeps the server's structured error fields so UI
/// callers can show a useful operational message without guessing from a
/// status code. Credential values are never retained here.
class SnaplinkAdminApiError implements Exception {
  final int status;
  final String? code;
  final String? description;
  const SnaplinkAdminApiError(this.status, {this.code, this.description});
  /// A 403 means this bearer is valid but does not hold the requested scope
  /// (or is outside the requested tenant boundary), so it must not destroy a
  /// still-valid console session.
  bool get isUnauthorized => status == 401;
  @override
  String toString() => description ?? code ?? 'Admin request failed ($status).';
}
/// Build-time catalog generated from Snaplink's `docs/openapi.yaml`.
///
/// Snaplink's runtime endpoint inventory is still used for feature awareness,
/// but current server versions do not report every gRPC-gateway operation in
/// that inventory. Keeping the documented routes here prevents those valid
/// operations from disappearing from the console. Regenerate this list from
/// that OpenAPI contract whenever the backend API changes.
class SnaplinkAdminOperationCatalog {
  static final endpoints = routes
      .trim()
      .split('\n')
      .map((line) {
        final space = line.indexOf(' ');
        return SnaplinkAdminEndpoint(
          method: line.substring(0, space),
          path: line.substring(space + 1),
          feature: 'documented',
        );
      })
      .toList(growable: false);
  static List<SnaplinkAdminEndpoint> mergedWith(
    List<SnaplinkAdminEndpoint> liveEndpoints,
  ) {
    final liveByRoute = {
      for (final endpoint in liveEndpoints) _key(endpoint): endpoint,
    };
    final merged = <SnaplinkAdminEndpoint>[];
    for (final documented in endpoints) {
      merged.add(liveByRoute.remove(_key(documented)) ?? documented);
    }
    merged.addAll(liveByRoute.values);
    return merged;
  }
  /// Whether a documented route family is available even when an older
  /// runtime inventory omits its gRPC-gateway registration.
  static bool hasDocumentedPathPrefix(String prefix) => endpoints.any(
    (endpoint) => _normalizedPath(endpoint.path).startsWith(prefix),
  );
  static String _key(SnaplinkAdminEndpoint endpoint) =>
      '${endpoint.method} ${_normalizedPath(endpoint.path)}';
  static String _normalizedPath(String path) => path.replaceAllMapped(
    RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}'),
    (match) => ':${match.group(1)}',
  );
}
/// Authenticated, contract-first client for Snaplink's administration API.
///
/// It intentionally exposes a small JSON transport rather than duplicating
/// every one of Snaplink's optional routes in this layer. Each domain screen
/// uses the documented path and checks the runtime endpoint inventory before
/// offering a mutation. That keeps the UI compatible with deployments that
/// do not wire every optional store.
class SnaplinkAdminApi {
  final String baseUrl;
  final String accessToken;
  final http.Client _http;
  final void Function()? onUnauthorized;
  final DataCache _cache;

  SnaplinkAdminApi({
    required this.baseUrl,
    required this.accessToken,
    http.Client? httpClient,
    this.onUnauthorized,
    DataCache? cache,
  }) : _http = httpClient ?? http.Client(),
       _cache = cache ?? DataCache();
  /// Number of entries currently in the response cache.
  /// Maximum retry attempts for transient failures.
  int maxRetries = 3;

  int get cacheSize => _cache.size;

  /// Number of in-flight deduplicated requests.
  int get cachePending => _cache.pendingCount;

  /// Record a mutation in the local audit log.
  void _recordAudit(String method, String path, int statusCode, Object? body) {
    final parts = path.split('/');
    // ignore: unnecessary_brace_in_string_interps
    final label = parts.length > 3 ? '${parts[3]} ${method}' : path;
    AuditLogService().record(AuditEntry(
      timestamp: DateTime.now(),
      method: method,
      path: path,
      statusCode: statusCode,
      label: label,
    ));
  }

  /// Clear the entire response cache.
  void clearCache() => _cache.clear();

  /// Flag: next GET request bypasses cache.
  bool _skipCacheNext = false;

  /// Mark that the next GET request should bypass the cache.
  /// Call this before a user-initiated refresh to ensure fresh data.
  void skipCache() {
    _skipCacheNext = true;
  }

  Future<List<SnaplinkAdminEndpoint>> listEndpoints() async {
    final response = await get('/api/v1/admin/endpoints');
    final values = response['endpoints'];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map(
          (item) =>
              SnaplinkAdminEndpoint.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }
  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool forceRefresh = false}) async {
    if (query != null) {
      return _request('GET', path, query: query);
    }
    final skipCache = _skipCacheNext || forceRefresh;
    _skipCacheNext = false;
    if (!skipCache) {
      final cached = _cache.get('GET', path);
      if (cached != null) return cached;
    }
    // Request deduplication: if the same GET is already in-flight, wait for it
    final pending = _cache.registerOrGet('GET', path);
    if (pending != null) return await pending;
    try {
      final data = await _request('GET', path);
      _cache.set('GET', path, data);
      _cache.resolve('GET', path, data);
      return data;
    } catch (e) {
      _cache.reject('GET', path, e);
      rethrow;
    }
  }
  /// Reads the opt-in embedded API documentation page without attempting to
  /// coerce its `text/html` response into JSON.
  Future<String> getText(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _http.get(
      uri,
      headers: {
        'Accept': 'text/html, application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }
    final data = _decode(response);
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    throw SnaplinkAdminApiError(
      response.statusCode,
      code: data['error']?.toString() ?? data['code']?.toString(),
      description:
          data['error_description']?.toString() ?? data['message']?.toString(),
    );
  }
  Future<Map<String, dynamic>> post(
    String path, [
    Object? body,
    String? contentType,
  ]) async {
    _cache.invalidate(path);
    return _request('POST', path, body: body, contentType: contentType);
  }
  Future<Map<String, dynamic>> put(
    String path, [
    Object? body,
    String? contentType,
  ]) async {
    _cache.invalidate(path);
    return _request('PUT', path, body: body, contentType: contentType);
  }
  Future<Map<String, dynamic>> patch(
    String path, [
    Object? body,
    String? contentType,
  ]) async {
    _cache.invalidate(path);
    return _request('PATCH', path, body: body, contentType: contentType);
  }
  Future<Map<String, dynamic>> delete(
    String path, [
    Object? body,
    String? contentType,
  ]) async {
    _cache.invalidate(path);
    return _request('DELETE', path, body: body, contentType: contentType);
  }
  /// Requests an operator-authorized export without attempting to parse or
  /// display its contents. Snaplink may return an attachment with a multi-
  /// status result while it omits unavailable optional data.
  Future<SnaplinkAdminDownload> postDownload(
    String path, [
    Object? body,
    String? contentType,
  ]) async {
    final response = await _http.post(
      Uri.parse('$baseUrl$path'),
      headers: {
        'Accept': 'application/octet-stream, application/json',
        'Authorization': 'Bearer $accessToken',
        if (body != null) 'Content-Type': contentType ?? 'application/json',
      },
      body: body == null ? null : jsonEncode(body),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return SnaplinkAdminDownload(
        bytes: response.bodyBytes,
        contentType:
            response.headers['content-type'] ?? 'application/octet-stream',
        filename: _attachmentFilename(response.headers['content-disposition']),
      );
    }
    final data = _decode(response);
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    throw SnaplinkAdminApiError(
      response.statusCode,
      code: data['error']?.toString() ?? data['code']?.toString(),
      description:
          data['error_description']?.toString() ?? data['message']?.toString(),
    );
  }
  /// Reads a sensitive export as an attachment.  This deliberately avoids
  /// JSON decoding because subject exports contain PII and must never enter
  /// the generic operation-response panel or its clipboard action.
  Future<SnaplinkAdminDownload> getDownload(
    String path, {
    Map<String, String>? query,
  }) async {
    final response = await _http.get(
      Uri.parse('$baseUrl$path').replace(queryParameters: query),
      headers: {
        'Accept': 'application/octet-stream, application/json',
        'Authorization': 'Bearer $accessToken',
      },
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return SnaplinkAdminDownload(
        bytes: response.bodyBytes,
        contentType:
            response.headers['content-type'] ?? 'application/octet-stream',
        filename: _attachmentFilename(response.headers['content-disposition']),
      );
    }
    final data = _decode(response);
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    throw SnaplinkAdminApiError(
      response.statusCode,
      code: data['error']?.toString() ?? data['code']?.toString(),
      description:
          data['error_description']?.toString() ?? data['message']?.toString(),
    );
  }
  /// Opens Snaplink's authenticated realtime admin event feed.
  ///
  /// `http.Client.send` maps to Fetch's readable response stream on web, so
  /// this keeps the Bearer header that `EventSource` itself cannot attach.
  /// Cancelling the listener closes the browser reader and the HTTP request.
  Stream<SnaplinkAdminEvent> streamAdminEvents({
    String? eventTypes,
    String? tenantId,
    String? lastEventId,
  }) async* {
    final query = <String, String>{
      if (eventTypes?.trim().isNotEmpty ?? false) 'event_types': eventTypes!,
      if (tenantId?.trim().isNotEmpty ?? false) 'tenant_id': tenantId!,
    };
    final request =
        http.Request(
            'GET',
            Uri.parse(
              '$baseUrl/api/v1/admin/events/stream',
            ).replace(queryParameters: query.isEmpty ? null : query),
          )
          ..headers.addAll({
            'Accept': 'text/event-stream',
            'Authorization': 'Bearer $accessToken',
            if (lastEventId?.trim().isNotEmpty ?? false)
              'Last-Event-ID': lastEventId!,
          });
    final response = await _http.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = await response.stream.bytesToString();
      final data = _decodeText(payload);
      if (response.statusCode == 401) {
        onUnauthorized?.call();
      }
      throw SnaplinkAdminApiError(
        response.statusCode,
        code: data['error']?.toString() ?? data['code']?.toString(),
        description:
            data['error_description']?.toString() ??
            data['message']?.toString(),
      );
    }
    String? id;
    var type = 'message';
    final dataLines = <String>[];
    await for (final line
        in response.stream
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      if (line.isEmpty) {
        if (dataLines.isNotEmpty) {
          final data = _decodeText(dataLines.join('\n'));
          yield SnaplinkAdminEvent(id: id, type: type, data: data);
        }
        id = null;
        type = 'message';
        dataLines.clear();
        continue;
      }
      if (line.startsWith(':')) continue;
      final separator = line.indexOf(':');
      final field = separator < 0 ? line : line.substring(0, separator);
      var value = separator < 0 ? '' : line.substring(separator + 1);
      if (value.startsWith(' ')) value = value.substring(1);
      switch (field) {
        case 'id':
          id = value;
        case 'event':
          type = value;
        case 'data':
          dataLines.add(value);
      }
    }
  }
  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? contentType,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': path.startsWith('/api/v1/scim/')
          ? 'application/scim+json'
          : 'application/json',
      'Authorization': 'Bearer $accessToken',
      if (body != null) 'Content-Type': contentType ?? 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    
    // Retry loop with exponential backoff for transient failures
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        late final http.Response response;
        switch (method) {
          case 'GET':
            response = await _http.get(uri, headers: headers);
          case 'POST':
            response = await _http.post(uri, headers: headers, body: encodedBody);
          case 'PUT':
            response = await _http.put(uri, headers: headers, body: encodedBody);
          case 'PATCH':
            response = await _http.patch(uri, headers: headers, body: encodedBody);
          case 'DELETE':
            response = await _http.delete(uri, headers: headers, body: encodedBody);
          default:
            throw ArgumentError.value(method, 'method', 'Unsupported HTTP method');
        }
        final data = _decode(response);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Record mutation in audit log
          if (method != 'GET') {
            _recordAudit(method, path, response.statusCode, null);
          }
          return data;
        }
        // Retry on server errors (5xx), not client errors (4xx)
        if (response.statusCode >= 500 && attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        if (response.statusCode == 401) {
          onUnauthorized?.call();
        }
        throw SnaplinkAdminApiError(
          response.statusCode,
          code: data['error']?.toString() ?? data['code']?.toString(),
          description:
              data['error_description']?.toString() ?? data['message']?.toString(),
        );
      } on TimeoutException catch (_) {
        if (attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      } catch (e) {
        if (e is SnaplinkAdminApiError) rethrow;
        if (attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }
  static Map<String, dynamic> _decode(http.Response response) {
    return _decodeText(response.body);
  }
  static Map<String, dynamic> _decodeText(String payload) {
    if (payload.isEmpty) return const {};
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } on FormatException {
      // Snaplink's proxy/front-end can return a non-JSON error page. Keep the
      // status code authoritative and avoid leaking that body into the UI.
    }
    return const {};
  }
  static String? _attachmentFilename(String? contentDisposition) {
    if (contentDisposition == null) return null;
    final encoded = RegExp(
      r"filename\*\s*=\s*UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    final plain = RegExp(
      r'filename\s*=\s*(?:"([^"]*)"|([^;\s]+))',
      caseSensitive: false,
    ).firstMatch(contentDisposition);
    var filename = encoded?.group(1) ?? plain?.group(1) ?? plain?.group(2);
    if (filename == null || filename.trim().isEmpty) return null;
    if (encoded != null) {
      try {
        filename = Uri.decodeComponent(filename);
      } on FormatException {
        // Fall back to the encoded value; it is still sanitized below.
      }
    }
    final safe = filename!.replaceAll(RegExp(r'[\\/\x00-\x1f]'), '_').trim();
    return safe.isEmpty ? null : safe;
  }
}