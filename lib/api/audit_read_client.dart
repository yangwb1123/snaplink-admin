import 'package:sso_admin/api/audit_event_row.dart';
import 'package:sso_admin/api/audit_query.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

/// Typed read client for the documented audit trio.
///
/// The single owner of the audit path literals and the only sanctioned way
/// for the audit timeline to reach the sink read API. Query construction is
/// exclusively through [AuditQuery] — no hand-built `query:` maps (guard
/// scan 5). `tenantId`/`traceId` are optional context parameters: neither
/// token-claim parsing nor proxy-side trace_id injection exists in this
/// repo (B4-1-dependent, [PROPOSED]); they are never hardcoded or derived,
/// and are omitted from the wire unless non-empty after trim.
class AuditReadClient {
  static const eventsPath = '/api/v1/audit/events';
  static const facetsPath = '/api/v1/audit/facets';
  static const eventDetailPath = '/api/v1/audit/events/{id}';

  final SnaplinkAdminApi _api;
  final String? _tenantId;
  final String? _traceId;

  AuditReadClient(this._api, {String? tenantId, String? traceId})
    : _tenantId = tenantId,
      _traceId = traceId;

  /// Wire note: `cursor` and `event_type` are governance-service keys —
  /// the trio backend reads only `type, actor_id, client_id, tenant_id,
  /// provider, outcome, request_id, trace_id, since, until, limit, offset`
  /// and silently ignores unknown params, so [cursor] and [eventTypes]
  /// pass through unfiltered today; only `limit` and [outcome] are real
  /// trio keys. No mapping is applied (`AuditQuery` untouched); a future
  /// filter UI must map `eventTypes → type` and `cursor → offset` in its
  /// own layer.
  Future<List<AuditEventRow>> list({
    int limit = 100,
    String? cursor,
    String? eventTypes,
    String? outcome,
    String? tenantId,
    String? traceId,
  }) async {
    final query = AuditQuery(
      limit: limit,
      tenantId: tenantId ?? _tenantId,
      traceId: traceId ?? _traceId,
      cursor: cursor,
      eventTypes: eventTypes,
      outcome: outcome,
    ).toQueryParameters();
    return auditEventRowsFromResponse(await _api.get(eventsPath, query: query));
  }

  /// Returns the raw facets envelope `{'facets': {total, outcomes, types,
  /// clients, providers}}` (verified shape: `total: int`; `outcomes`/
  /// `types` map key→count; `clients` keyed by `client_id`; `providers`
  /// by provider; all five members required; 501 when the sink lacks
  /// `FacetQuerier`). Pass-through is deliberate — there is no consumer
  /// in this direction; a typed `FacetResult` becomes groundable when
  /// the filter UI lands.
  ///
  /// Same wire-forwarding semantics as [list] (see its wire note):
  /// `cursor`/`event_type` are governance-surface keys ignored by the
  /// trio backend; `outcome`/`limit` are real trio keys.
  Future<Map<String, dynamic>> facets({
    int limit = 100,
    String? cursor,
    String? eventTypes,
    String? outcome,
    String? tenantId,
    String? traceId,
  }) async => _api.get(
    facetsPath,
    query: AuditQuery(
      limit: limit,
      tenantId: tenantId ?? _tenantId,
      traceId: traceId ?? _traceId,
      cursor: cursor,
      eventTypes: eventTypes,
      outcome: outcome,
    ).toQueryParameters(),
  );

  /// Single-event detail reader, mirroring the live-events precedent
  /// (`Uri.encodeComponent` split literal, no query parameters).
  Future<Map<String, dynamic>> event(String id) async =>
      _api.get('$eventsPath/${Uri.encodeComponent(id)}');
}
