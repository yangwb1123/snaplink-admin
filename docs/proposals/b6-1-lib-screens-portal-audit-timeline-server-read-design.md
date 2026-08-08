# B6-1 core — Design: audit timeline via server read API; localStorage ring demoted to debug-only (module: lib/screens/portal [negative] → changes in lib/screens/admin)

> Upstream: `docs/proposals/b6-1-lib-screens-portal-audit-timeline-server-read-spec.md` (requirements, mirrored from `docs/auto/runs/b6-1-core-route-the-audit-timeline-to-the-server-fd538d97/artifacts/requirements-10762e10/requirements.md`).
> Every citation below was re-verified against the repo on 2026-08-07 (verification table in §0). The spec's `[CORRECTION]`s (E1 `:13-16`, E3 `:81/:126-141/:134`, E5 `:31/:167-190/:183`, E7 `:566`, E8 `:63/:88/:149`, E11 sink paths) are carried forward and independently re-checked here.

## 0. Evidence verification (claims re-checked, not trusted)

| Spec/evidence citation | Verified reality | Verdict |
|---|---|---|
| Module boundary: zero diff in `lib/screens/portal/` (REQ-1) | `lib/screens/portal/portal_api.dart` is a 3-line re-export shim (`export 'package:sso_admin/api/portal_api.dart';`); `lib/api/portal_api.dart` (292 lines) has **zero** `audit` occurrences; the actionable timeline file is `lib/screens/admin/audit_log_tab.dart` (imported by `dashboard_screen.dart:26`) | ✅ — "portal" is the negative boundary; all changes land in `lib/screens/admin`, `lib/api`, `lib/services` |
| `audit_log_tab.dart`: `_logService` :22, ring read :43, "recorded on this device" :158, CSV :97, Clear :179-193, `const AuditLogTab({super.key})` :13-16 | `final _logService = AuditLogService();` :22; `_refresh` reads `_logService.entries` :43; subtitle :158; `_exportCsv` :97; Clear action spans :177-195 (tooltip :179, dialog :183-191, `_logService.clear()` :192 — spec's 179-193 is a minor span drift, substantively exact); `const AuditLogTab({super.key});` at **:16** (spec's 13-16 = doc comment :12-14 + class :15 + ctor :16) | ✅ |
| `audit_log_service.dart`: `sso_audit_log` :66, cap 1000 :65; sole ring writer `snaplink_admin_api.dart:81`/call :324 | `_maxEntries = 1000` :65; `_storageKey = 'sso_audit_log'` :66; `_recordAudit` at **:81** (not 82); sole call at **:324** (`if (method != 'GET')` in `_request` 2xx branch); `AuditLogService` referenced in `lib/` only at `snaplink_admin_api.dart:82` | ✅ |
| `get(path, query:)` :126-141, query forward :134 | `Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool forceRefresh = false})` :126-141; `query != null` → `_request('GET', path, query: query)` :133-134 (bypasses `_cache` entirely — live reads); `Authorization: 'Bearer $accessToken'` built in `_request` :294; GET retried ≤3 with `2^attempt*500ms` backoff :298-342 | ✅ |
| Governance: `_auditPath` :31, `_queryAudit` :167-190, `widget.api.get(...)` :183 | `static const _auditPath = '/api/v1/audit/events';` :31; `_queryAudit` :167-190; `widget.api.get(_auditPath, query: parameters)` :183; typed `AuditQuery.fromJson`/`toQueryParameters` wiring :169-180 | ✅ |
| `snaplink_admin_types.dart:310-312` | `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}` — exact trio | ✅ |
| `dashboard_screen.dart` `const AuditLogTab()` :566 | `page: const AuditLogTab(),` at **:566**; `GovernanceTab(api: _api, capabilities: capabilities)` :556; `_api` (`late final SnaplinkAdminApi`) :82 | ✅ |
| `test/admin_support_tabs_test.dart:63`, const pumps :88/:149 | `testWidgets('lists, filters and clears local audit entries', ...)` :63; `const MaterialApp(home: Scaffold(body: AuditLogTab()))` :88 and :149; CSV test :103-160 asserts ring-shaped CSV (`"POST","/api/v1/admin/clients"` :154) — both tests break on the constructor change | ✅ |
| Typed `AuditQuery` landed; default wire exactly `{'limit': '100'}` | `lib/api/audit_query.dart` present (commit `b82d2cf` B6-1c baseline); `toQueryParameters()` :148-164 emits `limit` via `'$limit'` and omits empty strings → `AuditQuery(limit: 100)` → `{'limit': '100'}`; `test/audit_query_test.dart` (164 lines) pins it | ✅ |
| Sink B1-5 implemented | `../snaplink-audit-governance/internal/domain/models.go:363` = `AdminActionEventRead = "audit.event.read"`; `internal/service/read_selfaudit_test.go:13` `TestReadSelfAuditOnQueryAndGet` (+ `TestReadSelfAuditOnExport` :61, `TestReadSelfAuditFailClosed` :111); `docs/release-notes.md:44` "2026-08-06 — … read-path self-audit"; `GET /api/v1/admin/actions` at `internal/httpapi/server.go:108`, handler :859 (permission `audit:policy:read` :860, response `{"items": items, "count": len(items)}` :895 — the sink's own admin-actions surface, distinct from the console's `/api/v1/audit/events` on sso-server) | ✅ — AC-4(b) targets the sink's `{items, count}` shape, not the console endpoint's |
| Real wire shape `{events, count}`, fields `id/type/outcome/timestamp/...`, no method/path/status | `docs/proposals/b6-1a-validation-audit-events-response-shape.md` §2: sso-server `platform/audit/handlers.go:37-41` → `{events, count}` (count = page length); `AuditEvent` has `id/type/outcome/timestamp/actor_id/client_id/tenant_id/...`, **no** method/path/status/event_type/time | ✅ — REQ-5 real-shape-first mapping is mandatory |
| Sibling overlap check (B6-1a / B6-1c landings) | `lib/api/audit_event_row.dart` **absent**, `test/audit_log_tab_test.dart` **absent** → B6-1a not landed; no naming collision with this design's `lib/api/audit_event_rows.dart`; contract guards (`test/audit_contract_guard_test.dart`, scan 1-4) green against the current tree | ✅ |
| Ring-side compatibility surface | `AuditEntry`/`AuditLogService` consumers outside the service: `snaplink_admin_api.dart:82-83` (lib); `test/snaplink_admin_api_test.dart:331-399` (asserts ring append + persistence — stays green because `kDebugMode == true` in test runs), `test/service_contracts_test.dart:18`, `test/admin_support_tabs_test.dart`, `test/oidc_login_ring_isolation_test.dart:104-137` (pins oidc login leaves ring unchanged — unaffected), `test/oidc_login_audit_visibility_guard_test.dart` (scoped to `lib/screens/oidc_login` — unaffected). `AuditLogService.recent()` :96-99 is the only `.timestamp.isAfter` consumer (nullability containment). Storage I/O `_save`/`_load` :109-124 already try/catch-wrapped with `debugPrint` — ring persistence failures never propagate into API calls | ✅ |
| i18n single call sites | Core catalog `'All authentication and administrative events recorded on this device.'` at `lib/i18n/app_strings_source_admin_core.dart:56` (zh `'此设备上记录的全部认证与管理事件。'`); features catalog `'No audit entries yet. Operations will appear here.'` at `app_strings_source_admin_features.dart:142` (zh `'尚无审计记录，操作会显示在此处。'`); each has exactly one call site (`audit_log_tab.dart:158/:244`) | ✅ |
| `SensitiveData.redact` | `lib/services/sensitive_data.dart:55` recursive map/list walker; allowlist keeps `token_id`→redacted, `request_id/session_id/actor_*/client_id/tenant_id/trace_id` survive (validation doc §2.1) — redact-first does not mangle real rows | ✅ |

## 1. API changes

### 1.1 New file `lib/api/audit_event_rows.dart` — pure mapper (REQ-5)

Pure Dart (no Flutter imports, no IO, no `print`), VM-unit-testable, sitting beside `audit_query.dart` under `lib/api/`.

```dart
/// Maps a `GET /api/v1/audit/events` response body to display rows.
/// Real sso-server shape first: {events: [...], count}; event fields
/// id/type/outcome/timestamp/... (validated cross-repo, b6-1a-validation).
/// Legacy ring vocabulary is a defensive fallback only. Never throws,
/// never drops a record.
List<AuditEntry> auditEventRowsFromResponse(Map<String, dynamic> response)
```

Contract, pinned by `test/audit_event_rows_test.dart`:

1. **Redact-first**: starts from `Map<String, dynamic>.from(SensitiveData.redact(response) ?? const {})` (`sensitive_data.dart:55`). Rows and the CSV derived from them are built from redacted data (repo doctrine for generic renderers).
2. **List extraction**: first of `['events', 'items', 'results', 'data', 'entries']` whose value `is List`; none → `const []` (server-truth empty state — never invents a phantom record).
3. **Per-element mapping** (each element independent; a bad element never aborts the batch):
   - non-`Map` element → one fallback row `AuditEntry(timestamp: null, method: '-', path: '', statusCode: 0, label: 'audit event')` — the record is *rendered*, not dropped.
   - `timestamp` ← first of `timestamp/time/created_at/occurred_at` that is a `String` and parses via `DateTime.tryParse`; invalid/absent → `null` (renders `--`, REQ-5).
   - `label` ← first non-empty `String` of `type/event_type/event/action/label`; else `id`; else `'audit event'` (never empty).
   - `path` ← first non-empty `String` of `id/path/uri/resource` (real rows: the 24-hex server `id` — safe to display); absent → `''`.
   - `method` ← first of `method/verb`; absent → `'-'`.
   - `statusCode` ← first of `status/status_code/statusCode` that is `int`, `num` (truncated), or digit-`String` via `int.tryParse`; absent → `0` (rendered `'-'`).
   - `id` ← `id`/`event_id` (String); `outcome` ← first of `outcome/result` (String); absent → `''` (rendered `'-'`).
4. **Never-throw structure**: all reads via `is` checks (no `as`); the per-row body is wrapped in `try/catch` returning the fallback row; the whole extraction is wrapped returning `[]` on a non-map/redact edge. No Flutter types in the file.

**Design decision (flagged, implementer-reviewable)**: the mapper reuses the existing `AuditEntry` type (spec REQ-5 names `List<AuditEntry>`) extended in §1.2, rather than the sibling B6-1a's proposed `AuditEventRow` (not landed; no collision). This keeps the table/CSV/sort code shape and satisfies the spec verbatim.

### 1.2 `lib/services/audit_log_service.dart` — model extension + single debug flag (REQ-8)

`AuditEntry` gains fields and a nullable timestamp (ring rows always carry valid timestamps; null only for server rows with absent/unparseable time):

```dart
class AuditEntry {
  final DateTime? timestamp; // nullable: server rows may lack a parseable time (renders '--')
  final String method;       // '-' when absent on the wire
  final String path;         // server id on real rows
  final int statusCode;      // 0 when absent (rendered '-')
  final String label;        // server type on real rows
  final String id;           // server event id, '' when absent
  final String outcome;      // server outcome (success/failure), '' when absent
```

- Constructor: `timestamp` stays `required` (type widens to `DateTime?` — no call-site churn: ring writers pass `DateTime.now()`, the mapper passes `null`).
- `toJson()` adds `'id': id, 'outcome': outcome` (ring format is append-only; old readers ignore unknown keys).
- `fromJson` reads them defensively (`json['id'] as String? ?? ''`), and `timestamp` via `DateTime.tryParse(...) ?? DateTime.fromMillisecondsSinceEpoch(0)` so legacy/foreign ring rows never throw (the existing `_load` catch :109-124 stays as belt-and-braces).
- `recent()` (:98) becomes `e.timestamp?.isAfter(cutoff) ?? false` — the only `.isAfter` consumer in the tree.

The debug flag — one overridable switch, default `kDebugMode`, both branches assertable in tests:

```dart
/// Single switch for the localStorage ring recorder (REQ-8).
/// Defaults to kDebugMode; unit tests flip it to exercise both branches
/// (a compile-time-only kDebugMode cannot be flipped in a debug run).
static bool debugAuditRing = kDebugMode;
```

### 1.3 `lib/api/snaplink_admin_api.dart` — gate the ring append (REQ-8)

The single write hook at :322-326 becomes:

```dart
if (method != 'GET') {
  if (AuditLogService.debugAuditRing) {
    _recordAudit(method, path, response.statusCode);
  }
  _fireDataChanged(method, path);   // unchanged, outside the gate
}
```

- Flag on → non-GET 2xx appends exactly as today via `_recordAudit` (:81-88, still the **sole** writer — no new writers).
- Flag off → no append, no `AuditLogService` touch from the API layer.
- GET never records in either mode (existing guard unchanged). `_fireDataChanged`/`DataChangedEvent` behavior untouched (spec §6).
- No transport/retry/cache/`onUnauthorized` changes.

### 1.4 `lib/screens/admin/audit_log_tab.dart` — server-fed timeline (REQ-2/3/4/6/7)

**Constructor** (GovernanceTab injection shape, minus capabilities):

```dart
class AuditLogTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  const AuditLogTab({super.key, required this.api});
```

**State model** (replaces `_logService`):

```dart
static const _auditPath = '/api/v1/audit/events';
List<AuditEntry> _allRows = [];   // fetched server page (unfiltered) → badge source
List<AuditEntry> _entries = [];   // displayed after client-side filter/sort → table+CSV source
bool _loading = false;
String? _error;
int _generation = 0;              // out-of-order refresh guard (validation doc §3/F10)
```

**Fetch path** — `initState`, header refresh button (:170) and `onRefresh` all call one `_refresh()`:

```dart
Future<void> _refresh() async {
  final gen = ++_generation;
  setState(() { _loading = true; _error = null; });
  try {
    final response = await widget.api.get(_auditPath,
        query: AuditQuery(limit: 100).toQueryParameters());  // wire exactly {'limit':'100'}
    if (!mounted || gen != _generation) return;              // stale response dropped
    setState(() { _allRows = auditEventRowsFromResponse(response); _loading = false; });
    _applyFilters();                                          // client-side only, no re-request
  } catch (e) {                                              // SnaplinkAdminApiError | TimeoutException
    if (!mounted || gen != _generation) return;
    setState(() { _error = e.toString(); _loading = false; _allRows = []; _entries = []; });
  }
}
```

- Error state replaces the table (server truth — a failed fetch renders the error panel, never ring data, never stale rows); Refresh stays enabled for retry.
- Initial load (no rows yet) renders a lightweight loading indicator; refreshes with rows visible keep the rows until the result lands.
- Search field and METHOD dropdown stay exactly as today but operate on `_allRows` client-side (REQ-3: no re-request, no event content in URLs). Sort keeps `_sortColumn`/`_sortAscending`; **null timestamps sort last** in both directions (pinned in unit test).
- `_formatTime(DateTime? dt)` — `null` → `'--'`, never throws.

**STATUS slot + error-rate — one interpretive design decision (flagged)**: the real wire has no `status`; the spec's literal fallback renders `'-'` in STATUS and makes the REQ-4-mandated error-rate badge permanently dead (validation doc §6.4: "never from a field that is always 0"). Minimal in-scope resolution, no column redesign:
- `String _statusText(AuditEntry e)` → `e.statusCode > 0 ? '${e.statusCode}' : e.outcome.isNotEmpty ? e.outcome.toUpperCase() : '-'` — used by **both** the STATUS table cell and the CSV `status` cell (single source of truth).
- Cell color: existing statusCode bands when `statusCode > 0`; else `outcome == 'failure'` → `AppColors.danger`, `outcome == 'success'` → `AppColors.success`, else muted.
- `_errorRate` counts `outcome == 'failure' || statusCode >= 400` over `_allRows` (0 when empty); badge thresholds unchanged (≥20% danger, ≥5% warning).
- If reviewers prefer the literal `'-'`, the badge simply never fires on real deployments — rejected (dead feature) in favor of the above.

**Copy** (REQ-6, atomic with zh per §1.6):
- Subtitle :158 → `'All authentication and administrative events recorded by the server.'`
- Debug-only marker (header, shown iff `AuditLogService.debugAuditRing`): chip `'device ring active (debug)'` — same flag as the §1.3 append gate, so marker and mutation always agree.
- Empty state :244 → `'No server audit events yet.'`

**Removed** (REQ-7): the Clear-log action (:177-195). `AuditLogService` import removed from the tab (grep guard, AC-3). CSV export stays, now over displayed server rows, preserving `_csvCell` (:107-115 quote-doubling + `'` prefix) and the `'Exported N entries as CSV to clipboard'` feedback; null timestamps → `''` in the CSV (the `--` marker is a table-only rendering).

### 1.5 `lib/screens/admin/dashboard_screen.dart` — wiring (REQ-9)

`:566` `page: const AuditLogTab(),` → `page: AuditLogTab(api: _api),`. Entry stays unconditionally registered (capability culling is sibling B6-1a scope). After the change, grep finds zero `const AuditLogTab()` in `lib/` + `test/` (AC-7).

### 1.6 i18n — atomic key + zh (REQ-6, E14)

- `lib/i18n/app_strings_source_admin_core.dart:56` — replace device-subtitle key with `'All authentication and administrative events recorded by the server.'` → zh `'服务器记录的全部认证与管理事件。'`; add `'device ring active (debug)'` → zh `'设备记录环已启用（调试）'`.
- `lib/i18n/app_strings_source_admin_features.dart:142` — replace empty-state key with `'No server audit events yet.'` → zh `'暂无服务器审计事件。'`.
- Old keys deleted in the same change (single call sites, verified §0; the i18n coverage scan enforces key↔zh pairing and no dangling keys).

### 1.7 Tests

| File | Change | Pins |
|---|---|---|
| `test/audit_event_rows_test.dart` (new, pure Dart) | Mapper matrix | real-shape rows primary (id/type/outcome/timestamp → label/path/method `'-'`/status `0`/outcome), ring-shaped fallback rows, `{events: [], count: 0}`, missing list key → `[]`, non-map element → fallback row, invalid timestamp → null, redaction (`token_id` → `<redacted>` never reaches rows), malformed/`null` payload → `[]`, never-throws (REQ-5) |
| `test/audit_log_debug_ring_test.dart` (new, plain Dart + MockClient) | Flag unit test (AC-5) | flag on: POST 2xx → ring count +1 with expected entry; flag off: same POST → ring unchanged; GET → never appends in either mode; `AuditLogService.debugAuditRing` restored in `addTearDown` |
| `test/admin_support_tabs_test.dart` | Rewrite test at :63 → 'fetches server audit rows and filters them' (AC-1); rewrite CSV test :103+ → server fixtures (AC-6); add AC-2 (ring clear ≠ timeline clear) and AC-3 (forged ring renders nowhere) | see §5 |
| `test/snaplink_admin_api_test.dart` | unchanged (kDebugMode default keeps :331-399 green) | — |

## 2. Compatibility constraints

1. **Constructor break is contained**: `AuditLogTab` gains a required `api`. Exactly 3 `const AuditLogTab()` call sites exist (`dashboard_screen.dart:566`, `admin_support_tabs_test.dart:88/:149`) — all rewritten in the same change; AC-7 greps to zero.
2. **`AuditEntry.timestamp` nullable**: only consumers are the ring service (`recent()` — updated), the tab (`_formatTime`/`_sortEntries` — updated), and the mapper (new). Ring rows always carry valid timestamps; `fromJson` never throws on foreign/legacy rows.
3. **Ring storage format append-only**: `toJson` adds `id`/`outcome`; old persisted rows load (defensive `fromJson`), new rows are readable by older code (unknown keys ignored). No storage migration needed.
4. **Default flag preserves every existing behavior/test**: `debugAuditRing = kDebugMode` is `true` in `flutter test` (debug) and debug builds → `snaplink_admin_api_test.dart:331-399`, `service_contracts_test.dart`, `oidc_login_ring_isolation_test.dart` stay green unchanged. Release builds stop ring appends — the intended demotion.
5. **Transport untouched**: retry/backoff/timeout/401 handling, `onUnauthorized`, and the query-param cache bypass (live reads) are all existing `SnaplinkAdminApi` behavior; `get(path, query:)` signature unchanged.
6. **Wire query pinned**: `AuditQuery(limit: 100).toQueryParameters()` == `{'limit': '100'}` — the B6-1a AC-1 exact-query assertion and `test/audit_query_test.dart` remain valid; no `tenant_id`/`trace_id` (both `[PROPOSED]`).
7. **No new audit-path literals outside the documented trio** and no `MapEntry(key, '$value')` stringification → `test/audit_contract_guard_test.dart` scans 1-4 stay green (`/api/v1/audit/events` is already in the trio; governance precedent :31).
8. **Guards unaffected**: `oidc_login_audit_visibility_guard_test.dart` scans only `lib/screens/oidc_login`; this direction touches no file under it.
9. **i18n**: replaced keys have single call sites (verified); key+zh land atomically; no dangling keys.
10. **Module boundary**: `lib/screens/portal/portal_api.dart` and `lib/api/portal_api.dart` are byte-identical to HEAD (AC-7).

## 3. Failure modes

| F | Trigger | Behavior (pinned by) |
|---|---|---|
| F1 | 5xx / timeout on fetch | `_request` retries GET ≤3 (`2^attempt*500ms`), then error panel + Refresh; **no ring fallback** (AC-1 error-path case) |
| F2 | 401 (expired/invalid token) | `onUnauthorized` fires (:342), error panel; no rows rendered |
| F3 | 404 — route not mounted (audit disabled on deployment, the *default* when `!WithAuditAPI`) | error panel "audit unavailable" — server truth; never device data. Capability-culled navigation is sibling B6-1a scope (N2) |
| F4 | Malformed body (non-map, no list key, non-map elements, redact edge) | mapper → `[]` or per-element fallback rows; never throws; empty/fallback rows render (REQ-5 matrix) |
| F5 | Field-vocabulary divergence (real rows: no method/path/status) | METHOD `'-'`, PATH = server `id`, STATUS = outcome text, error-rate from `outcome == 'failure'`; METHOD dropdown non-ALL selection yields empty on real payloads — accepted server truth, documented (column/filter redesign = sibling scope) |
| F6 | Null/invalid timestamp | TIME `'--'` (never throws); sort nulls-last; CSV `''` |
| F7 | Out-of-order refresh (query GETs are uncached/undeduped) | `_generation` guard drops stale responses (validation doc F10 extension) |
| F8 | Devtools-forged `'sso_audit_log'` values | render nowhere — tab has no `AuditLogService` import (grep guard, AC-3); badge/CSV/count derive only from fetched rows |
| F9 | Ring persistence failure (quota etc.) | `_save`/`_load` already swallow + `debugPrint` (:109-124) — debug recorder failure can never break an API call or the timeline |
| F10 | >100 matching events | page ceiling = `limit` 100; `{count} entries` = page length, not total; no pagination (documented; offset/pagination out of scope) |
| F11 | Stale cache | none — query-param GET bypasses `_cache` entirely (:133-134); every refresh is a fresh request (AC-1 asserts refresh issues a second identical request) |
| F12 | Ring append while flag on | identical to today's `_recordAudit` path (sole writer preserved); GET never records (AC-5) |

## 4. Migration steps (ordered; each step leaves the tree green)

1. **Model + mapper land as pure additions**: §1.1 new `lib/api/audit_event_rows.dart`; §1.2 `AuditEntry` extension (nullable timestamp, `id`, `outcome`, tolerant `fromJson`, `recent()` guard) and `AuditLogService.debugAuditRing`. New `test/audit_event_rows_test.dart`. No behavior change anywhere (flag defaults `true` in tests).
2. **Gate the ring append**: §1.3 `snaplink_admin_api.dart:324` behind the flag. New `test/audit_log_debug_ring_test.dart` (both branches). Existing ring tests stay green (kDebugMode).
3. **Flip the tab** (the atomic behavior switch): §1.4 tab rewrite + §1.5 dashboard wiring + §1.6 i18n keys/zh + §1.7 rewrites of both `admin_support_tabs_test.dart` tests + AC-2/AC-3 additions — all in one change (the tree is red between 2 and 3 only if the old tab tests run against the new constructor, hence same-change).
4. **Repo gates**: `flutter analyze`; `flutter test` (full suite, incl. `i18n_coverage_test.dart`, `audit_contract_guard_test.dart`, `audit_query_test.dart`, oidc guards); grep guards: zero `const AuditLogTab()`, one `AuditLogTab(api:` in `lib/`, zero `AuditLogService` in `audit_log_tab.dart`, zero `audit` in `lib/api/portal_api.dart` + shim byte-identical (`git diff --exit-code` on the two portal files).
5. **Sink leg (AC-4b)**: `cd ../snaplink-audit-governance && go test ./internal/service -run 'TestReadSelfAuditOnQueryAndGet|TestReadSelfAuditFailClosed'`; optional HTTP joint check: query events as identity X, then `GET /api/v1/admin/actions` contains `action == 'audit.event.read'` with actor == X (`{items, count}` shape, server.go:895). Reported as PASS only with the console leg; otherwise "not run in this environment" with the green sink test cited — never PASS-by-omission.

## 5. Testable acceptance mapping

| AC | Testable assertion (file:case) |
|---|---|
| AC-1 (T-12 console leg, G7) | `test/admin_support_tabs_test.dart` rewritten test (replaces :63): pump `AuditLogTab(api: _api({...}))` with `_api` MockClient harness (pattern `admin_governance_security_test.dart:12-32`, 404 fallback); fixture `{'events': [3 real-shape rows], 'count': 3}`; assert exactly 1 request, path `/api/v1/audit/events`, query map == `{'limit': '100'}` (order-insensitive), 3 rows render, no `/facets`/other requests; search typing keeps request count at 1; refresh issues a second identical request |
| AC-2 | same file: seed ring (2 entries), pump tab with server fixture (3 rows), `service.clear()`, re-pump → 3 server rows + `'3 entries'`; `'0 entries'` never occurs; debug flag off → no `'device ring active (debug)'`; flag on → marker present |
| AC-3 | same file: ring seeded with `'FORGED-DEVTOOLS-1'`/`'/forged/path'` labels → `find.textContaining(...)` finds nothing in table/badge/CSV/empty state; static guard: `audit_log_tab.dart` contains no `AuditLogService` reference |
| AC-4 (T-12 joint) | (a) console leg — AC-1 test additionally asserts the recorded request carries `Authorization: Bearer admin-token` (identity the sink attributes self-audit rows to); (b) sink leg — §4 step 5 command + optional HTTP joint check; both halves must pass, never skipped |
| AC-5 | `test/audit_log_debug_ring_test.dart`: flag on → POST 2xx increments ring by exactly 1 (method POST, path, 2xx); flag off → unchanged; GET → unchanged in both modes; `addTearDown(clear)` |
| AC-6 | `test/admin_support_tabs_test.dart` CSV test rewritten with server-shaped fixtures (one row label `=SUM(A1:A2)`): CSV contains server rows, `'` prefix inside quotes, export-count snackbar, quote doubling; null-timestamp row → `''` in CSV, `'--'` in TIME column |
| AC-7 | grep guards (step 4): zero `const AuditLogTab()` in `lib/`+`test/`; exactly one `AuditLogTab(api:` in `lib/`; portal files byte-identical to HEAD |

REQ coverage: REQ-1 → AC-7 (portal byte-identical, grep); REQ-2 → AC-1 (injected api, no self-construction); REQ-3 → AC-1 (exact query, no re-request on filter); REQ-4 → AC-2/AC-3 (ring clear no-op on timeline, forgery invisible, error state no fallback); REQ-5 → `test/audit_event_rows_test.dart` matrix; REQ-6 → AC-2 marker + i18n coverage test (zh atomic); REQ-7 → AC-1 (Clear gone) + CSV retained in AC-6; REQ-8 → AC-5; REQ-9 → AC-7.

## 6. Out of scope / risks

- **Hard boundary** (spec §6): capability gating/navigation culling (sibling B6-1a), `tenant_id`/`trace_id` request params (both `[PROPOSED]`), `/facets` + `/events/{id}` usage, column/filter redesign (METHOD dropdown kept as-is; its emptiness against real payloads is F5), any change to `lib/screens/portal/`, `lib/api/portal_api.dart`, `_fireDataChanged`/`DataChangedEvent`, or the response cache.
- **R1 (response shape)**: fixtures must be real-shape (`id/type/outcome/timestamp/...`), never ring-shaped, or AC-1 passes against invented data while real integration renders dead columns — the b6-1a validation's central finding; the §1.4 STATUS-slot decision is the mitigation.
- **R2 (i18n regression)**: old keys deleted atomically with zh replacements; `i18n_coverage_test.dart` enforces pairing.
- **R3 (flag testability)**: `static bool debugAuditRing` is test-overridable by design — both branches asserted; `addTearDown` restores the default.
- **N1**: `{count} entries` badge = fetched page length (≤100), never a server total — no pagination (F10).
- **N2**: deployments without the audit route surface the tab's error state, not a hidden entry (no gating in this direction).

Evidence index: spec `docs/proposals/b6-1-lib-screens-portal-audit-timeline-server-read-spec.md`; validation `docs/proposals/b6-1a-validation-audit-events-response-shape.md`; sibling design `docs/proposals/b6-1c-lib-screens-admin-audit-read-contract-design.md`; sink `../snaplink-audit-governance` (models.go:363, read_selfaudit_test.go:13, server.go:108/859, release-notes.md:44); campaign `docs/campaigns/implementation-gate.md:56` (T-12).
