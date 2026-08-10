/// Typed builder for audit read query parameters.
///
/// The only sanctioned way to construct query parameters for the documented
/// audit trio — `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`,
/// `GET /api/v1/audit/events/{id}` (the `routes` listing in
/// `snaplink_admin_types.dart`).
///
/// Field wire keys are grounded in the governance tab helper text
/// (`governance_tab.dart`: `{"tenant_id":"acme","outcome":"failure","limit":100}`)
/// and the sink `parseQuery` filter surface (`snaplink-audit-governance`
/// `internal/httpapi/server.go`).
///
/// Presence/absence semantics: a field serializes iff it is non-null and
/// (for strings) non-empty after trim. `tenant_id` and `trace_id` are
/// omitted by default, so the default wire is exactly `{'limit': '100'}`
/// (or the caller's limit) — preserving the B6-1a AC-1 exact-limit assertion.
class AuditQuery {
  /// Maximum events per page. Wire key: `limit`; serialized via string
  /// coercion, identical to the previous `'$value'` wire behavior.
  final int? limit;

  /// Tenant scope. Wire key: `tenant_id`; omitted unless non-empty after trim.
  final String? tenantId;

  /// Correlation id. Wire key: `trace_id`; omitted unless non-empty after trim.
  final String? traceId;

  /// Server pagination cursor. Wire key: `cursor`; omitted unless non-empty
  /// after trim.
  final String? cursor;

  /// Event type filter (server-defined multi-value semantics; the console
  /// passes the raw value through). Wire key: `event_type`; omitted unless
  /// non-empty after trim.
  final String? eventTypes;

  /// Outcome filter. Wire key: `outcome`; omitted unless non-empty after trim.
  final String? outcome;

  const AuditQuery({
    this.limit,
    this.tenantId,
    this.traceId,
    this.cursor,
    this.eventTypes,
    this.outcome,
  });

  /// The six supported wire keys, in the order the governance helper text
  /// advertises them. The guard test pins this set.
  static const supportedKeys = [
    'limit',
    'tenant_id',
    'trace_id',
    'cursor',
    'event_type',
    'outcome',
  ];

  /// Parses the governance text-field content (a JSON object with the wire
  /// keys above).
  ///
  /// Values may be `int` (stringified, matching the previous `'$value'`
  /// behavior) or `String` (kept for trimming at serialization). A `null`
  /// value is treated as absent. Unknown keys and non-scalar values throw
  /// [AuditQueryParseException] — this is the fix for the unvalidated
  /// pass-through that previously reached the wire verbatim.
  factory AuditQuery.fromJson(Map<String, dynamic> json) {
    int? limit;
    String? tenantId;
    String? traceId;
    String? cursor;
    String? eventTypes;
    String? outcome;
    for (final entry in json.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key == 'limit') {
        if (value == null) continue;
        if (value is int) {
          limit = value;
          continue;
        }
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed == null) {
            throw const AuditQueryParseException(
              'Audit query: limit must be an integer.',
            );
          }
          limit = parsed;
          continue;
        }
        throw AuditQueryParseException(
          'Audit query: key "limit" must be an integer or numeric string, '
          'got ${value.runtimeType}.',
        );
      }
      if (key == 'tenant_id') {
        tenantId = _scalarString('tenant_id', value);
        continue;
      }
      if (key == 'trace_id') {
        traceId = _scalarString('trace_id', value);
        continue;
      }
      if (key == 'cursor') {
        cursor = _scalarString('cursor', value);
        continue;
      }
      if (key == 'event_type') {
        eventTypes = _scalarString('event_type', value);
        continue;
      }
      if (key == 'outcome') {
        outcome = _scalarString('outcome', value);
        continue;
      }
      throw AuditQueryParseException(
        'Audit query: unsupported key "$key". Supported: '
        'limit, tenant_id, trace_id, cursor, event_type, outcome.',
      );
    }
    return AuditQuery(
      limit: limit,
      tenantId: tenantId,
      traceId: traceId,
      cursor: cursor,
      eventTypes: eventTypes,
      outcome: outcome,
    );
  }

  static String? _scalarString(String key, Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    throw AuditQueryParseException(
      'Audit query: key "$key" must be a string or integer, '
      'got ${value.runtimeType}.',
    );
  }

  /// Serializes to the wire map. Order-insensitive; consumers must compare
  /// as maps. `limit` is coerced via `'$limit'`; each string field
  /// contributes its trimmed value iff non-empty. An all-null construction
  /// yields an empty map.
  Map<String, String> toQueryParameters() {
    final parameters = <String, String>{};
    if (limit != null) parameters['limit'] = '$limit';
    void addIfPresent(String key, String? value) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) parameters[key] = trimmed;
    }

    addIfPresent('tenant_id', tenantId);
    addIfPresent('trace_id', traceId);
    addIfPresent('cursor', cursor);
    addIfPresent('event_type', eventTypes);
    addIfPresent('outcome', outcome);
    return parameters;
  }
}

/// Typed parse error carrying a human-readable message for the governance
/// tab's error banner.
class AuditQueryParseException implements Exception {
  final String message;

  const AuditQueryParseException(this.message);

  @override
  String toString() => message;
}
