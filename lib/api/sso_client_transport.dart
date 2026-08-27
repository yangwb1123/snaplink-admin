part of 'sso_client.dart';

extension SSOAdminClientTransport on SSOAdminClient {
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
