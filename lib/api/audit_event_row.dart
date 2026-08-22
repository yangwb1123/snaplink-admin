import 'package:sso_admin/services/sensitive_data.dart';

/// Read-only, server-derived row for the audit timeline.
///
/// Rows are built exclusively through [auditEventRowsFromResponse]; no path
/// from a raw response to a row exists outside that mapper's field
/// allowlist. The seven fields are the only server fields ever displayed or
/// exported — every other real event field (`request_id`, `trace_id`,
/// `span_id`, `actor_ip`, `user_agent`, `metadata`, `hash`, ...) is dropped
/// at row construction.
class AuditEventRow {
  /// Event time; `null` renders as `--` and sorts last.
  final DateTime? timestamp;

  /// EVENT column; never empty (`'audit event'` fallback).
  final String type;

  /// `success`/`failure` — OUTCOME column and the error-rate signal.
  final String outcome;

  /// Row key (duplicate/refresh stability).
  final String id;

  /// Identity columns; `''` renders as `-`.
  final String actorId;
  final String clientId;
  final String tenantId;

  const AuditEventRow({
    this.timestamp,
    required this.type,
    required this.outcome,
    required this.id,
    required this.actorId,
    required this.clientId,
    required this.tenantId,
  });
}

/// Pure, defensive mapper. Never throws, never drops a server record.
///
/// Redact-first: [SensitiveData.redact] runs once over the whole response
/// before any extraction. Allowlist-only reads (`is`-checks, no `as`
/// casts). N input elements produce exactly N rows; fallback rows carry
/// `outcome == ''` (no fabricated success/failure); `{}`,
/// `{'events': []}`, and wrong-typed envelopes (`{'events': null}`,
/// `{'events': 42}`, `{'events': 'oops'}`) produce zero rows — server
/// truth wins even when the server has nothing, and a degraded sink can
/// never fabricate a phantom 'audit event' record.
List<AuditEventRow> auditEventRowsFromResponse(Map<String, dynamic> response) {
  try {
    final redacted = SensitiveData.redact(response);
    final root = redacted is Map<String, dynamic>
        ? redacted
        : redacted is Map
        ? Map<String, dynamic>.from(redacted)
        : const <String, dynamic>{};
    for (final key in const ['events', 'items', 'results', 'data', 'entries']) {
      final value = root[key];
      if (value is List) {
        return [
          for (final item in value)
            _rowFromMap(
              item is Map<String, dynamic>
                  ? item
                  : item is Map
                  ? Map<String, dynamic>.from(item)
                  : const <String, dynamic>{},
            ),
        ];
      }
      if (root.containsKey(key)) {
        // Present-but-not-List envelope key: a wrong-typed or partial
        // payload from a degraded sink (`{'events': null, 'count': 0}`,
        // `{'events': 42}`). The server had nothing list-shaped to say —
        // zero rows, never the bare-map single-record fallback (F1).
        return const [];
      }
    }
    // No list payload: an empty map is a zero-row server result; a
    // non-empty bare map is a single record (defensive fallback for
    // non-snaplink deployments).
    return root.isEmpty ? const [] : [_rowFromMap(root)];
  } catch (_) {
    return const [_fallbackRow];
  }
}

const _fallbackRow = AuditEventRow(
  type: 'audit event',
  outcome: '',
  id: '',
  actorId: '',
  clientId: '',
  tenantId: '',
);

AuditEventRow _rowFromMap(Map<String, dynamic> map) {
  final timestamp = _firstString(map, const [
    'timestamp',
    'time',
    'created_at',
    'createdAt',
    'occurred_at',
  ]);
  final type = _firstString(map, const [
    'type',
    'event_type',
    'eventType',
    'event',
    'action',
    'label',
    'path',
    'uri',
    'resource',
    'endpoint',
    'id',
  ]);
  return AuditEventRow(
    timestamp: timestamp == null ? null : DateTime.tryParse(timestamp),
    type: _scrubQueryIfUri(type ?? 'audit event'),
    outcome: _firstString(map, const ['outcome']) ?? '',
    id: _firstString(map, const ['id', 'event_id']) ?? '',
    actorId:
        _firstString(map, const ['actor_id', 'actorId']) ??
        _nestedString(map, 'actor', 'id') ??
        '',
    // Audit Governance derives and persists the registered source identity as
    // `source_system`; it intentionally does not echo OAuth client secrets or
    // an unverified request-side client id. Use that trusted source as the
    // CLIENT column fallback while preserving Snaplink's legacy client_id.
    clientId:
        _firstString(map, const ['client_id', 'clientId', 'source_system']) ??
        '',
    tenantId: _firstString(map, const ['tenant_id', 'tenantId']) ?? '',
  );
}

String? _firstString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value is String && value.isNotEmpty) return value;
  }
  return null;
}

String? _nestedString(
  Map<String, dynamic> map,
  String containerKey,
  String valueKey,
) {
  final container = map[containerKey];
  if (container is! Map) return null;
  final value = container[valueKey];
  return value is String && value.isNotEmpty ? value : null;
}

/// URI-query-scoped credential-bearing keys, layered on top of
/// [SensitiveData.isSensitiveKey]'s global vocabulary (which covers
/// `*token*`, password/secret/credential/… fragments but misses the OAuth/
/// authorization vocabulary: `code`, `state`, `jwt`, `key`, `sig`,
/// `assertion`, `ticket`, `session`).
///
/// Matches are **exact on the normalized key only** (lowercase, non-alnum
/// stripped — mirroring [SensitiveData.isSensitiveKey]'s normalization), so
/// ordinary business uses of these words in a URI are never redacted:
/// `state=pending`, `code=200`, `key=primary`, `limit=100`, `tenant_id`,
/// `client_id`, `session_id`-style *query* keys are all legitimate audit
/// context and pass through. Only the credential-bearing position — the
/// value of an exactly-named authorization query key — is replaced.
const _uriSensitiveQueryKeys = {
  'code', // OAuth authorization code
  'state', // OAuth CSRF state / JARM state
  'jwt', // JARM / query.jwt authorization response
  'key', // shared/API key passed in the query
  'sig', // request signature
  'signature',
  'assertion', // SAML/WebAuthn assertion
  'ticket', // one-time auth ticket
  'session', // session continuation
  'sessionid', // normalized `session_id`
};

String _normalizedQueryKey(String key) =>
    key.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');

bool _isSensitiveQueryKey(String key) =>
    SensitiveData.isSensitiveKey(key) ||
    _uriSensitiveQueryKeys.contains(_normalizedQueryKey(key));

/// String-level URI query scrub for allowlisted strings that parse as URIs
/// (legacy `path`/`uri`/`resource` fallbacks and URI-shaped labels):
/// credential-bearing query values are truncated to [SensitiveData.redacted]
/// ([SensitiveData.redact] is key-based and cannot protect credentials
/// embedded in a URI).
///
/// Truncation semantics: the value is replaced, the key is retained (the
/// reader still sees *which* credential-bearing parameter was present), and
/// every other parameter, the path, and the host pass through untouched —
/// legitimate audit context survives the scrub.
String _scrubQueryIfUri(String value) {
  final uri = Uri.tryParse(value);
  if (uri == null || !uri.hasQuery) return value;
  final scrubbed = <String, String>{
    for (final entry in uri.queryParameters.entries)
      entry.key: _isSensitiveQueryKey(entry.key)
          ? SensitiveData.redacted
          : entry.value,
  };
  return Uri(
    scheme: uri.scheme,
    host: uri.host,
    port: uri.port,
    path: uri.path,
    queryParameters: scrubbed,
  ).toString();
}
