import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sso_admin/session.dart';
import 'package:sso_admin/services/admin_oauth_resources.dart';
import 'package:sso_admin/services/product_api_origin.dart';

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

/// A cursor page returned by Snaplink's administrative list endpoints.
///
/// The cursor is intentionally opaque; callers must send it back unchanged
/// with the same filter and ordering that produced the page.
class SSOAdminListPage {
  final List<Map<String, dynamic>> items;
  final String? nextPageToken;
  final int? totalSize;

  const SSOAdminListPage({
    required this.items,
    required this.nextPageToken,
    required this.totalSize,
  });
}

/// Minimal admin-API client for the sso_admin Flutter app: direct
/// password-grant login (mirrors the TypeScript SDK's login()) plus the
/// small slice of the admin REST surface this MVP covers (clients, users,
/// tenants + suspend/activate).
class SSOAdminClient {
  final String baseUrl;
  final http.Client _http;
  final Duration requestTimeout;
  final void Function()? onUnauthorized;
  String? _token;

  SSOAdminClient(
    String baseUrl, {
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 30),
    this.onUnauthorized,
  }) : baseUrl = _stripTrailingSlash(baseUrl),
       _http = httpClient ?? http.Client();

  /// Uses the current page origin on web and the configured service origin on
  /// native platforms.
  factory SSOAdminClient.sameOrigin() =>
      SSOAdminClient(ProductApiOrigin.baseUrl);

  /// Wraps an access_token already obtained elsewhere (the unified /login
  /// screen) as a logged-in client, without a second network round trip.
  factory SSOAdminClient.withToken(
    String accessToken, {
    String? baseUrl,
    void Function()? onUnauthorized,
  }) {
    final client = SSOAdminClient(
      baseUrl ?? ProductApiOrigin.baseUrl,
      onUnauthorized: onUnauthorized,
    );
    client._token = accessToken;
    return client;
  }

  static const nativeDefaultBaseUrl = ProductApiOrigin.nativeDefaultBaseUrl;

  /// OAuth2 client identifier used by this first-party console for direct
  /// login and admin access. Single source of truth: the hosted-login
  /// wiring and every test reference this constant instead of a fresh
  /// literal (single-source rule).
  static const String firstPartyClientId = 'sso-admin-console';

  static String _stripTrailingSlash(String s) =>
      s.replaceAll(RegExp(r'/+$'), '');

  bool get isLoggedIn => _token != null;

  Future<Map<String, dynamic>> login(
    String username,
    String password, {
    String clientId = firstPartyClientId,
    List<String>? resources,
  }) async {
    final requestedResources = resources ?? AdminOAuthResources.values;
    final body = await _post('/auth/login', {
      'provider': 'password',
      'client_id': clientId,
      'scope': ['openid', 'profile', 'admin:read', 'admin:write'],
      if (requestedResources.isNotEmpty) 'resource': requestedResources,
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

  /// Verifies the bearer has read access to the admin control plane without
  /// coupling entry authorization to any managed resource collection.
  Future<void> probeAdminAccess() async {
    await _get('/api/v1/admin/endpoints');
  }

  Future<SSOAdminListPage> listClients({
    String? pageToken,
    int? pageSize,
    String? orderBy,
    String? filter,
  }) => _listPage(
    '/api/v1/admin/clients',
    'clients',
    pageToken: pageToken,
    pageSize: pageSize,
    orderBy: orderBy,
    filter: filter,
  );

  Future<SSOAdminListPage> listUsers({
    String? pageToken,
    int? pageSize,
    String? orderBy,
    String? filter,
  }) => _listPage(
    '/api/v1/admin/users',
    'users',
    pageToken: pageToken,
    pageSize: pageSize,
    orderBy: orderBy,
    filter: filter,
  );

  Future<SSOAdminListPage> listTenants({
    String? pageToken,
    int? pageSize,
    String? orderBy,
    String? filter,
  }) => _listPage(
    '/api/v1/admin/tenants',
    'tenants',
    pageToken: pageToken,
    pageSize: pageSize,
    orderBy: orderBy,
    filter: filter,
  );

  Future<Map<String, dynamic>> setTenantStatus(String id, String status) async {
    final data = await _post(
      '/api/v1/admin/tenants/${Uri.encodeComponent(id)}:set-status',
      {'status': status},
    );
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  // ---- clients CRUD ----

  Future<Map<String, dynamic>> createClient(Map<String, dynamic> client) async {
    final data =
        await _post('/api/v1/admin/clients', client) as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateClient(
    String id,
    Map<String, dynamic> client,
  ) async {
    final data =
        await _put('/api/v1/admin/clients/${Uri.encodeComponent(id)}', client)
            as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteClient(String id) async {
    await _delete('/api/v1/admin/clients/${Uri.encodeComponent(id)}');
  }

  Future<Map<String, dynamic>> rotateClientSecretWithPolicy(
    String id, {
    Duration? overlap,
    Duration? lifetime,
  }) async {
    final body = <String, dynamic>{};
    if (overlap != null) body['overlap_seconds'] = overlap.inSeconds;
    if (lifetime != null) body['lifetime_seconds'] = lifetime.inSeconds;
    final data =
        await _post(
              '/api/v1/admin/clients/${Uri.encodeComponent(id)}/rotate-secret',
              body,
            )
            as Map<String, dynamic>;
    return data;
  }

  Future<String> rotateClientSecret(String id) async =>
      (await rotateClientSecretWithPolicy(id))['secret'] as String? ?? '';

  Future<List<Map<String, dynamic>>> listExpiringClients({
    Duration? within,
  }) async {
    final query = within == null ? '' : '?within_seconds=${within.inSeconds}';
    final data = await _get('/api/v1/admin/clients/expiring$query');
    final rows = data is Map ? data['clients'] : null;
    return rows is List
        ? rows.whereType<Map>().map(Map<String, dynamic>.from).toList()
        : const [];
  }

  Future<void> approveClient(String id) async {
    await _post(
      '/api/v1/admin/clients/${Uri.encodeComponent(id)}/approve',
      const {},
    );
  }

  Future<void> rejectClient(String id) async {
    await _post(
      '/api/v1/admin/clients/${Uri.encodeComponent(id)}/reject',
      const {},
    );
  }

  Future<Map<String, dynamic>> getClient(String id) async {
    final data =
        await _get('/api/v1/admin/clients/${Uri.encodeComponent(id)}')
            as Map<String, dynamic>;
    return (data['client'] as Map<String, dynamic>?) ?? data;
  }

  Future<Map<String, dynamic>> getUser(String id) async {
    final data =
        await _get('/api/v1/admin/users/${Uri.encodeComponent(id)}')
            as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? data;
  }

  Future<Map<String, dynamic>> getTenant(String id) async {
    final data =
        await _get('/api/v1/admin/tenants/${Uri.encodeComponent(id)}')
            as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? data;
  }

  // ---- users CRUD ----

  Future<Map<String, dynamic>> createUser(Map<String, dynamic> user) async {
    final data =
        await _post('/api/v1/admin/users', user) as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateUser(
    String id,
    Map<String, dynamic> user,
  ) async {
    final data =
        await _put('/api/v1/admin/users/${Uri.encodeComponent(id)}', user)
            as Map<String, dynamic>;
    return (data['user'] as Map<String, dynamic>?) ?? const {};
  }

  Future<void> deleteUser(String id) async {
    await _delete('/api/v1/admin/users/${Uri.encodeComponent(id)}');
  }

  // ---- tenants CRUD ----

  Future<Map<String, dynamic>> createTenant(Map<String, dynamic> tenant) async {
    final data =
        await _post('/api/v1/admin/tenants', tenant) as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> updateTenant(
    String id,
    Map<String, dynamic> tenant,
  ) async {
    final data =
        await _put('/api/v1/admin/tenants/${Uri.encodeComponent(id)}', tenant)
            as Map<String, dynamic>;
    return (data['tenant'] as Map<String, dynamic>?) ?? const {};
  }

  Future<Map<String, dynamic>> deleteTenant(String id) async {
    final data = await _delete(
      '/api/v1/admin/tenants/${Uri.encodeComponent(id)}',
    );
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// Fetch a single connection by id.
  Future<Map<String, dynamic>> getConnection(String id) async {
    final data = await _get(
      '/api/v1/admin/connections/${Uri.encodeComponent(id)}',
    );
    return data as Map<String, dynamic>;
  }

  /// Fetch a single break-glass session from the list-only API.
  Future<Map<String, dynamic>> getBreakGlassSession(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/break-glass',
      collectionKey: 'sessions',
      id: id,
      identityKeys: const ['id', 'session_id'],
      resourceLabel: 'Break-glass session',
    );
  }

  /// Fetch a single webhook subscription from the list-only API.
  Future<Map<String, dynamic>> getWebhookSubscription(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/webhooks/subscriptions',
      collectionKey: 'subscriptions',
      id: id,
      identityKeys: const ['id'],
      resourceLabel: 'Webhook subscription',
    );
  }

  /// Fetch a single domain by hostname.
  Future<Map<String, dynamic>> getDomain(String hostname) async {
    final data = await _get(
      '/api/v1/admin/domains/${Uri.encodeComponent(hostname)}',
    );
    return data as Map<String, dynamic>;
  }

  /// Fetch the active entry for a credential type from the inventory.
  Future<Map<String, dynamic>> getCredential(String type) async {
    return _getCollectionItem(
      path: '/api/v1/admin/credentials',
      collectionKey: 'credentials',
      id: type,
      identityKeys: const ['type', 'id'],
      resourceLabel: 'Credential',
      preferredStatus: 'active',
    );
  }

  /// Fetch a single crypto key from the read-only inventory.
  Future<Map<String, dynamic>> getCryptoKey(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/crypto/keys',
      collectionKey: 'keys',
      id: id,
      identityKeys: const ['key_id', 'kid', 'id'],
      resourceLabel: 'Cryptographic key',
    );
  }

  /// Fetch a single access policy from the list-only governance API.
  Future<Map<String, dynamic>> getAccessPolicy(String id) async {
    return _getCollectionItem(
      path: '/api/v1/admin/access-policies',
      collectionKey: 'policies',
      id: id,
      identityKeys: const ['name', 'id'],
      resourceLabel: 'Access policy',
    );
  }

  /// Fetch a single threat policy by id.
  Future<Map<String, dynamic>> getThreatPolicy(String id) async {
    final data = await _get(
      '/api/v1/admin/threat-policies/${Uri.encodeComponent(id)}',
    );
    return data as Map<String, dynamic>;
  }

  /// Create a new identity connection.
  Future<Map<String, dynamic>> createConnection(
    Map<String, dynamic> conn,
  ) async {
    final data = await _post('/api/v1/admin/connections', conn);
    return data as Map<String, dynamic>;
  }

  /// Create or replace a connection through Snaplink's collection upsert.
  Future<Map<String, dynamic>> updateConnection(
    String id,
    Map<String, dynamic> conn,
  ) async {
    final data = await _post('/api/v1/admin/connections', {...conn, 'id': id});
    return data as Map<String, dynamic>;
  }

  /// Delete a connection by id.
  Future<void> deleteConnection(String id) async {
    await _delete('/api/v1/admin/connections/${Uri.encodeComponent(id)}');
  }

  /// Create a new break-glass (emergency access) session.
  Future<Map<String, dynamic>> createBreakGlassSession(
    Map<String, dynamic> session,
  ) async {
    final data = await _post('/api/v1/admin/break-glass', session);
    return data as Map<String, dynamic>;
  }

  /// Delete a break-glass session by id.
  Future<Map<String, dynamic>> deleteBreakGlassSession(String id) async {
    final data = await _delete(
      '/api/v1/admin/break-glass/${Uri.encodeComponent(id)}',
    );
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// Create a new webhook subscription.
  Future<Map<String, dynamic>> createWebhookSubscription(
    Map<String, dynamic> sub,
  ) async {
    final data = await _post('/api/v1/admin/webhooks/subscriptions', sub);
    return data as Map<String, dynamic>;
  }

  /// Delete a webhook subscription by id.
  Future<void> deleteWebhookSubscription(String id) async {
    await _delete(
      '/api/v1/admin/webhooks/subscriptions/${Uri.encodeComponent(id)}',
    );
  }

  /// Delete a domain by hostname.
  Future<void> deleteDomain(String hostname) async {
    await _delete('/api/v1/admin/domains/${Uri.encodeComponent(hostname)}');
  }

  /// Report credential compromise by type.
  Future<void> reportCredentialCompromise(String type) async {
    await _post(
      '/api/v1/admin/credentials/${Uri.encodeComponent(type)}/compromise',
      {},
    );
  }

  /// Mark a crypto key as compromised.
  Future<void> compromiseCryptoKey(String id) async {
    await _post(
      '/api/v1/admin/crypto/keys/${Uri.encodeComponent(id)}/compromise',
      {},
    );
  }

  Future<Map<String, dynamic>> _getCollectionItem({
    required String path,
    required String collectionKey,
    required String id,
    required List<String> identityKeys,
    required String resourceLabel,
    String? preferredStatus,
  }) async {
    final data = await _get(path) as Map<String, dynamic>;
    final rawItems = data[collectionKey];
    final matches = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .where(
                (item) =>
                    identityKeys.any((key) => item[key]?.toString() == id),
              )
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    if (preferredStatus != null) {
      for (final item in matches) {
        if (item['status']?.toString() == preferredStatus) return item;
      }
    }
    if (matches.isNotEmpty) return matches.first;
    throw SSOError(404, 'not_found', '$resourceLabel not found.');
  }

  Map<String, String> _authHeaders() =>
      _token != null ? {'Authorization': 'Bearer $_token'} : const {};

  Future<SSOAdminListPage> _listPage(
    String path,
    String itemKey, {
    String? pageToken,
    int? pageSize,
    String? orderBy,
    String? filter,
  }) async {
    final data =
        await _get(
              path,
              query: {
                if (pageToken?.isNotEmpty ?? false) 'page_token': pageToken!,
                if (pageSize != null) 'page_size': pageSize.toString(),
                if (orderBy?.isNotEmpty ?? false) 'order_by': orderBy!,
                if (filter?.trim().isNotEmpty ?? false)
                  'filter': filter!.trim(),
              },
            )
            as Map<String, dynamic>;
    final values = data[itemKey];
    final items = values is List
        ? values
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final rawNext = data['next_page_token']?.toString();
    final rawTotal = data['total_size'];
    return SSOAdminListPage(
      items: items,
      nextPageToken: rawNext == null || rawNext.isEmpty ? null : rawNext,
      totalSize: rawTotal is num ? rawTotal.toInt() : int.tryParse('$rawTotal'),
    );
  }

  Future<dynamic> _get(String path, {Map<String, String>? query}) async {
    final resp = await _http
        .get(
          Uri.parse('$baseUrl$path').replace(
            queryParameters: query == null || query.isEmpty ? null : query,
          ),
          headers: _authHeaders(),
        )
        .timeout(requestTimeout);
    return _handle(resp);
  }

  Future<dynamic> _post(
    String path,
    Map<String, dynamic> body, {
    bool auth = true,
  }) async {
    final headers = {
      'Content-Type': 'application/json',
      if (auth) ..._authHeaders(),
    };
    final resp = await _http
        .post(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _handle(resp, authenticated: auth);
  }

  Future<dynamic> _put(String path, Map<String, dynamic> body) async {
    final headers = {'Content-Type': 'application/json', ..._authHeaders()};
    final resp = await _http
        .put(
          Uri.parse('$baseUrl$path'),
          headers: headers,
          body: jsonEncode(body),
        )
        .timeout(requestTimeout);
    return _handle(resp);
  }

  Future<dynamic> _delete(String path) async {
    final resp = await _http
        .delete(Uri.parse('$baseUrl$path'), headers: _authHeaders())
        .timeout(requestTimeout);
    return _handle(resp);
  }

  dynamic _handle(http.Response resp, {bool authenticated = true}) {
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
    // Centralized so every admin call — not just the gate's own probe —
    // reacts to a token that's expired or been revoked mid-session: clear
    // the stale session and bounce back to login, the same way admin_gate.dart
    // does on first load. Scoped to requests that actually carried a token,
    // so an unauthenticated call (e.g. a failed login attempt) can't trigger it.
    // 403 means a valid admin bearer lacks this route's scope or tenant
    // boundary. Preserve it so the console can show the denial; only a 401
    // proves the session itself has expired or been revoked.
    if (authenticated && resp.statusCode == 401) {
      _token = null;
      Session.clear();
      onUnauthorized?.call();
    }
    throw SSOError(
      resp.statusCode,
      parsed['error'] as String? ?? parsed['code']?.toString(),
      parsed['error_description'] as String? ?? parsed['message'] as String?,
    );
  }

  /// Skip the response cache on the next GET request (user-initiated refresh).
  /// Currently a no-op; SSOAdminClient does not cache responses.
  void skipCache() {}
}
