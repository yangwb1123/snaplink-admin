import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:sso_admin/api/snaplink_admin_types.dart';

export 'snaplink_admin_types.dart';

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
  static final endpoints = _routes
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

  static const _routes = '''
GET /api/v1/admin/events/stream
GET /api/v1/admin/authz/policy-bundle
GET /api/v1/admin/storage-health
GET /api/v1/admin/federation/health
POST /api/v1/admin/credentials/{type}/compromise
GET /api/v1/admin/compliance/soc2-evidence
GET /api/v1/admin/compliance/data-map
GET /api/v1/admin/compliance/consents
POST /api/v1/admin/compliance/retention-sweep
GET /api/v1/admin/endpoints
GET /api/v1/admin/docs
GET /api/v1/admin/docs/openapi.json
GET /api/v1/admin/config/running
GET /api/v1/admin/credentials
GET /api/v1/admin/crypto/keys
POST /api/v1/admin/crypto/keys/{id}/compromise
GET /api/v1/admin/config/applied
GET /api/v1/admin/config/diff
POST /api/v1/admin/config/cluster-diff
GET /api/v1/admin/config/history
POST /api/v1/admin/backup
GET /api/v1/admin/dr/status
GET /api/v1/admin/access-policies
GET /api/v1/admin/webhooks/subscriptions
POST /api/v1/admin/webhooks/subscriptions
DELETE /api/v1/admin/webhooks/subscriptions/{id}
GET /api/v1/admin/webhooks/deadletters
POST /api/v1/admin/webhooks/deadletters/{id}/replay
GET /api/v1/admin/rebac/check
POST /api/v1/admin/wasmauthz/check
GET /api/v1/admin/dr/mode
POST /api/v1/admin/dr/mode
POST /api/v1/admin/snapshots
GET /api/v1/admin/snapshots
GET /api/v1/admin/snapshots/{id}
DELETE /api/v1/admin/snapshots/{id}
POST /api/v1/admin/snapshots/{id}:restore
POST /api/v1/admin/releases
GET /api/v1/admin/releases
GET /api/v1/admin/releases:current
GET /api/v1/admin/releases/{id}
DELETE /api/v1/admin/releases/{id}
POST /api/v1/admin/releases/{id}:pin
POST /api/v1/admin/releases/{id}:rollback
GET /api/v1/admin/tenants
POST /api/v1/admin/tenants
GET /api/v1/admin/tenants/{id}
PUT /api/v1/admin/tenants/{id}
DELETE /api/v1/admin/tenants/{id}
GET /api/v1/admin/tenants/{id}/usage
GET /api/v1/admin/usage/top-tenants
GET /api/v1/admin/tokens/usage
GET /api/v1/admin/token-policies
GET /api/v1/admin/tokens/portfolio
GET /api/v1/admin/tokens/subjects/{subject}
GET /api/v1/admin/tokens/expiring
GET /api/v1/admin/tokenexchange/chains/{jti}
GET /api/v1/admin/sessions
GET /api/v1/admin/tokens
DELETE /api/v1/admin/tokens/{id}
POST /api/v1/admin/logout
GET /api/v1/admin/sessions/linked/{subject}
GET /api/v1/admin/tokens/suspicious
GET /api/v1/admin/threat-policies
GET /api/v1/admin/threat-policies/{name}
PUT /api/v1/admin/threat-policies/{name}
DELETE /api/v1/admin/threat-policies/{name}
POST /api/v1/admin/tokens/bulk-revoke
POST /api/v1/admin/tenants/{id}:set-status
GET /api/v1/admin/domains
POST /api/v1/admin/domains
GET /api/v1/admin/domains/{hostname}
PUT /api/v1/admin/domains/{hostname}
DELETE /api/v1/admin/domains/{hostname}
GET /api/v1/admin/clients
POST /api/v1/admin/clients
GET /api/v1/admin/clients/{id}
PUT /api/v1/admin/clients/{id}
DELETE /api/v1/admin/clients/{id}
POST /api/v1/admin/clients/{id}/rotate-secret
POST /api/v1/admin/clients/{id}/approve
POST /api/v1/admin/clients/{id}/reject
GET /api/v1/clients/{id}
GET /api/v1/admin/keys
POST /api/v1/admin/keys/rotate
GET /api/v1/admin/users
POST /api/v1/admin/users
GET /api/v1/admin/users/{id}
PUT /api/v1/admin/users/{id}
DELETE /api/v1/admin/users/{id}
GET /api/v1/admin/users/{id}/sessions
GET /api/v1/admin/local-users
POST /api/v1/admin/local-users
GET /api/v1/admin/local-users/{id}
PUT /api/v1/admin/local-users/{id}
DELETE /api/v1/admin/local-users/{id}
GET /api/v1/admin/users/{id}/consents
DELETE /api/v1/admin/users/{id}/consents/{client_id}
GET /api/v1/admin/users/{id}/mfa
DELETE /api/v1/admin/users/{id}/mfa/{factor_id}
GET /api/v1/admin/users/{id}/lifecycle
POST /api/v1/admin/users/{id}/lifecycle
POST /api/v1/admin/users/{id}/mfa/recovery-codes
POST /api/v1/admin/users/{id}/password
POST /api/v1/admin/users/{id}/email
POST /api/v1/admin/account-lockout/clear
POST /api/v1/admin/break-glass
GET /api/v1/admin/break-glass
DELETE /api/v1/admin/break-glass/{id}
POST /api/v1/admin/break-glass/{id}/approve
POST /api/v1/admin/break-glass/{id}/impersonate
POST /api/v1/admin/changes
GET /api/v1/admin/changes
GET /api/v1/admin/changes/{id}
POST /api/v1/admin/changes/{id}/approve
POST /api/v1/admin/changes/{id}/reject
GET /api/v1/admin/connections
POST /api/v1/admin/connections
GET /api/v1/admin/connections/{id}
DELETE /api/v1/admin/connections/{id}
GET /api/v1/admin/connections/{id}/domains
POST /api/v1/admin/connections/{id}/domains/{domain}/verify
GET /api/v1/admin/connections/{id}/health
POST /api/v1/admin/connections/{id}/probe
GET /api/v1/admin/tenants/{id}/members
PUT /api/v1/admin/tenants/{id}/members/{user_id}
DELETE /api/v1/admin/tenants/{id}/members/{user_id}
POST /api/v1/admin/tenants/{id}/export
GET /api/v1/admin/tenants/{id}/invitations
POST /api/v1/admin/tenants/{id}/invitations
DELETE /api/v1/admin/tenants/{id}/invitations/{email}
DELETE /api/v1/admin/users/{id}/device-secrets
DELETE /api/v1/admin/users/{id}/refresh-tokens
GET /api/v1/admin/users/{id}/password-reset-tokens
DELETE /api/v1/admin/users/{id}/password-reset-tokens
GET /api/v1/admin/users/{id}/email-change-tokens
DELETE /api/v1/admin/users/{id}/email-change-tokens
GET /api/v1/admin/tokens/sessions
POST /api/v1/admin/tokens/revoke
POST /api/v1/admin/tokens/temp
GET /api/v1/admin/permissions/{client_id}/roles
POST /api/v1/admin/permissions/{client_id}/roles
PUT /api/v1/admin/permissions/{client_id}/roles/{role_code}
DELETE /api/v1/admin/permissions/{client_id}/roles/{role_code}
GET /api/v1/admin/permissions/{client_id}/assignments
POST /api/v1/admin/permissions/{client_id}/assignments/{user_id}
POST /api/v1/admin/permissions/{client_id}/assignments/{user_id}/unassign
PUT /api/v1/admin/permissions/{client_id}/menus
GET /api/v1/audit/events
GET /api/v1/audit/facets
GET /api/v1/audit/events/{id}
GET /api/v1/netpolicy/policies
POST /api/v1/netpolicy/policies
GET /api/v1/netpolicy/policies/{name}
DELETE /api/v1/netpolicy/policies/{name}
GET /api/v1/netpolicy/classify
GET /api/v1/netpolicy/resolve-me
GET /api/v1/compliance/users/{id}/export
POST /api/v1/compliance/users/{id}/erase
GET /api/v1/scim/v2/ServiceProviderConfig
GET /api/v1/scim/v2/Schemas
POST /api/v1/scim/v2/Bulk
GET /api/v1/scim/v2/Me
PUT /api/v1/scim/v2/Me
PATCH /api/v1/scim/v2/Me
DELETE /api/v1/scim/v2/Me
GET /api/v1/scim/v2/Users
POST /api/v1/scim/v2/Users
GET /api/v1/scim/v2/Users/{id}
PUT /api/v1/scim/v2/Users/{id}
PATCH /api/v1/scim/v2/Users/{id}
DELETE /api/v1/scim/v2/Users/{id}
GET /api/v1/scim/v2/Groups
POST /api/v1/scim/v2/Groups
GET /api/v1/scim/v2/Groups/{id}
PUT /api/v1/scim/v2/Groups/{id}
PATCH /api/v1/scim/v2/Groups/{id}
DELETE /api/v1/scim/v2/Groups/{id}
''';
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

  SnaplinkAdminApi({
    required this.baseUrl,
    required this.accessToken,
    http.Client? httpClient,
    this.onUnauthorized,
  }) : _http = httpClient ?? http.Client();

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

  Future<Map<String, dynamic>> get(String path, {Map<String, String>? query}) =>
      _request('GET', path, query: query);

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
  ]) => _request('POST', path, body: body, contentType: contentType);

  Future<Map<String, dynamic>> put(
    String path, [
    Object? body,
    String? contentType,
  ]) => _request('PUT', path, body: body, contentType: contentType);

  Future<Map<String, dynamic>> patch(
    String path, [
    Object? body,
    String? contentType,
  ]) => _request('PATCH', path, body: body, contentType: contentType);

  Future<Map<String, dynamic>> delete(
    String path, [
    Object? body,
    String? contentType,
  ]) => _request('DELETE', path, body: body, contentType: contentType);

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
      return data;
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
