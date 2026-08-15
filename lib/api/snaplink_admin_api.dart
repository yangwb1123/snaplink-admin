import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:sso_admin/api/data_cache.dart';
import 'package:sso_admin/api/snaplink_admin_download_transport.dart';
import 'package:sso_admin/api/snaplink_admin_error.dart';
import 'package:sso_admin/api/snaplink_admin_event_stream.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';
import 'package:sso_admin/services/audit_log_service.dart';
import 'package:sso_admin/services/event_bus.dart';

export 'snaplink_admin_catalog.dart' show SnaplinkAdminOperationCatalog;
export 'snaplink_admin_error.dart' show SnaplinkAdminApiError;
export 'snaplink_admin_types.dart';

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
  final Duration requestTimeout;
  late final SnaplinkAdminDownloadTransport _downloads;
  late final SnaplinkAdminEventStream _events;

  SnaplinkAdminApi({
    required this.baseUrl,
    required this.accessToken,
    http.Client? httpClient,
    this.onUnauthorized,
    DataCache? cache,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client(),
       _cache = cache ?? DataCache() {
    _downloads = SnaplinkAdminDownloadTransport(
      baseUrl: baseUrl,
      accessToken: accessToken,
      httpClient: _http,
      requestTimeout: requestTimeout,
      onUnauthorized: onUnauthorized,
    );
    _events = SnaplinkAdminEventStream(
      baseUrl: baseUrl,
      accessToken: accessToken,
      httpClient: _http,
      requestTimeout: requestTimeout,
      onUnauthorized: onUnauthorized,
    );
  }

  /// Maximum retry attempts for transient failures.
  int maxRetries = 3;

  /// Number of entries currently in the response cache.
  int get cacheSize => _cache.size;

  /// Number of in-flight deduplicated requests.
  int get cachePending => _cache.pendingCount;

  /// Record a mutation in the local audit log.
  /// Fire a DataChangedEvent after a successful mutation.
  void _fireDataChanged(String method, String path) {
    final resourceType = _resourceType(path);
    final changeType = switch (method) {
      'POST' => ChangeType.created,
      'DELETE' => ChangeType.deleted,
      _ => ChangeType.updated,
    };
    EventBus().fire(DataChangedEvent(resourceType, changeType: changeType));
  }

  void _recordAudit(String method, String path, int statusCode) {
    AuditLogService().record(
      AuditEntry(
        timestamp: DateTime.now(),
        method: method,
        path: path,
        statusCode: statusCode,
        label: '${_resourceType(path)} $method',
      ),
    );
  }

  static String _resourceType(String path) {
    final segments = Uri(path: path).pathSegments;
    if (segments.length >= 4 && segments[0] == 'api' && segments[1] == 'v1') {
      return segments[2] == 'admin' ? segments[3] : segments[2];
    }
    return segments.isEmpty ? path : segments.first;
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

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
    bool forceRefresh = false,
  }) async {
    final skipCache = _skipCacheNext || forceRefresh;
    _skipCacheNext = false;
    if (query != null) {
      return _request('GET', path, query: query);
    }
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
    } catch (error, stackTrace) {
      _cache.reject('GET', path, error, stackTrace);
      rethrow;
    }
  }

  /// 缓存先渲染 + 后台刷新（stale-while-revalidate）读取。
  ///
  /// DataCache 语义不变（TTL/去重/失效规则与 [get] 完全一致），仅调整编排：
  /// 1. 缓存命中时立即返回缓存载荷 —— 调用方先渲染缓存行，不再每次进入都
  ///    空白加载；
  /// 2. 命中后仍在后台强制刷新，[onRefresh] 收到新载荷（失败静默，保留已
  ///    渲染的缓存行）；
  /// 3. 缓存未命中时仅一次网络请求（不重复拉取）。
  Future<Map<String, dynamic>> getStaleWhileRevalidate(
    String path, {
    void Function(Map<String, dynamic> data)? onRefresh,
  }) async {
    final wasCached = _cache.get('GET', path) != null;
    final data = await get(path);
    if (wasCached && onRefresh != null) {
      unawaited(_refreshStale(path, onRefresh));
    }
    return data;
  }

  /// 后台刷新载体：失败静默（调用方已渲染缓存行，不弹错误、不打断页面）。
  Future<void> _refreshStale(
    String path,
    void Function(Map<String, dynamic> data) onRefresh,
  ) async {
    try {
      onRefresh(await get(path, forceRefresh: true));
    } catch (_) {
      // 后台刷新失败：保留已渲染的缓存行，静默。
    }
  }

  /// Reads the opt-in embedded API documentation page without attempting to
  /// coerce its `text/html` response into JSON.
  Future<String> getText(String path, {Map<String, String>? query}) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final response = await _http
        .get(
          uri,
          headers: {
            'Accept': 'text/html, application/json',
            'Authorization': 'Bearer $accessToken',
          },
        )
        .timeout(requestTimeout);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.body;
    }
    final data = _decode(response);
    if (response.statusCode == 401) {
      onUnauthorized?.call();
    }
    throw snaplinkAdminError(response.statusCode, data);
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

  /// Performs an optimistic-concurrency protected write.
  ///
  /// SCIM resources expose their validator as `meta.version`; callers pass
  /// that value unchanged so stale PUT/PATCH/DELETE requests fail with 412
  /// instead of overwriting a concurrent provisioning change.
  Future<Map<String, dynamic>> mutateIfMatch({
    required String method,
    required String path,
    required String etag,
    Object? body,
    String? contentType,
  }) {
    final normalizedMethod = method.toUpperCase();
    if (!const {'PUT', 'PATCH', 'DELETE'}.contains(normalizedMethod)) {
      throw ArgumentError.value(method, 'method', 'Not a conditional write');
    }
    if (etag.trim().isEmpty) {
      throw ArgumentError.value(etag, 'etag', 'An ETag is required');
    }
    _cache.invalidate(path);
    return _request(
      normalizedMethod,
      path,
      body: body,
      contentType: contentType,
      extraHeaders: {'If-Match': etag},
    );
  }

  /// Requests an operator-authorized export without attempting to parse or
  /// display its contents. Snaplink may return an attachment with a multi-
  /// status result while it omits unavailable optional data.
  Future<SnaplinkAdminDownload> postDownload(
    String path, [
    Object? body,
    String? contentType,
  ]) {
    return _downloads.post(path, body: body, contentType: contentType);
  }

  /// Reads a sensitive export as an attachment.  This deliberately avoids
  /// JSON decoding because subject exports contain PII and must never enter
  /// the generic operation-response panel or its clipboard action.
  Future<SnaplinkAdminDownload> getDownload(
    String path, {
    Map<String, String>? query,
  }) {
    return _downloads.get(path, query: query, maxRetries: maxRetries);
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
  }) {
    return _events.open(
      eventTypes: eventTypes,
      tenantId: tenantId,
      lastEventId: lastEventId,
    );
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
    String? contentType,
    Map<String, String>? extraHeaders,
  }) async {
    final uri = Uri.parse('$baseUrl$path').replace(queryParameters: query);
    final headers = <String, String>{
      'Accept': path.startsWith('/api/v1/scim/')
          ? 'application/scim+json'
          : 'application/json',
      ...?extraHeaders,
      'Authorization': 'Bearer $accessToken',
      if (body != null) 'Content-Type': contentType ?? 'application/json',
    };
    final encodedBody = body == null ? null : jsonEncode(body);
    final canRetry = method == 'GET';

    // Only safe reads are retried automatically. Replaying a POST/PATCH after
    // an ambiguous network failure can duplicate a change even when the
    // browser never received the first successful response.
    int attempt = 0;
    while (true) {
      attempt++;
      try {
        final responseFuture = switch (method) {
          'GET' => _http.get(uri, headers: headers),
          'POST' => _http.post(uri, headers: headers, body: encodedBody),
          'PUT' => _http.put(uri, headers: headers, body: encodedBody),
          'PATCH' => _http.patch(uri, headers: headers, body: encodedBody),
          'DELETE' => _http.delete(uri, headers: headers, body: encodedBody),
          _ => throw ArgumentError.value(
            method,
            'method',
            'Unsupported HTTP method',
          ),
        };
        final response = await responseFuture.timeout(requestTimeout);
        final data = _decode(response);
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Record mutation in audit log
          if (method != 'GET') {
            _recordAudit(method, path, response.statusCode);
            _fireDataChanged(method, path);
          }
          return data;
        }
        // Retry server-side read failures, never an unsafe mutation.
        if (canRetry && response.statusCode >= 500 && attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        if (response.statusCode == 401) {
          onUnauthorized?.call();
        }
        throw snaplinkAdminError(response.statusCode, data);
      } on TimeoutException catch (_) {
        if (canRetry && attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      } catch (e) {
        if (e is SnaplinkAdminApiError) rethrow;
        if (canRetry && attempt < maxRetries) {
          final delay = Duration(milliseconds: pow(2, attempt).toInt() * 500);
          await Future.delayed(delay);
          continue;
        }
        rethrow;
      }
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    return decodeSnaplinkAdminPayload(response.body);
  }
}
