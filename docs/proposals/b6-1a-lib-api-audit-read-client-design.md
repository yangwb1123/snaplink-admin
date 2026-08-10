# B6-1a — Design: typed `AuditReadClient` in lib/api + AuditLogTab rewire behind the endpoint-inventory gate (module: lib/api)

> Durable repo copy of the design stage artifact (`docs/auto/runs/land-a-typed-audit-read-client-in-lib-api-auditr-23691df4/artifacts/design-4bb9e6d8/task-1-design.md`).
> Upstream: `docs/proposals/b6-1a-lib-api-audit-read-client-spec.md` (requirements, supersedes `b6-1a-lib-api-auditlogtab-server-read-spec.md` rev-3).
> **Hardening pass (2026-08-07, i18n reviewer)**: applied in place — §1.7 i18n delta set is now a complete pinned inventory (outcome filter keys, `'{n}% errors'` key, not-enabled copy, search-hint replacement, `'All methods'`/`'Modify'` orphan removal); FM-16 resolved: the `subtitle` scan extension is **MANDATORY** in the anchored form `(?:\b(?:title|subtitle|detail|body|emptyText)):` (the design's earlier unanchored `(?:title|subtitle|…):` form was a no-op — the unanchored `title:` alternative already matches `subtitle:` sites); C7/FM-16/step 4/AC-6 updated; tree-safety re-verified (7 direct-literal `subtitle:` sites, all zh-complete). Evidence: `docs/auto/runs/land-a-typed-audit-read-client-in-lib-api-auditr-23691df4/artifacts/adversarial_review-9c87f3a7/meta/i18n_reviewer.md`.
> Prior art (binding for the row model and tab internals where not contradicted here): `docs/proposals/b6-1a-lib-api-auditlogtab-server-read-design.md` (§1.1 row model, §1.2 tab state model, §1.4 dashboard wiring, CSV hardening, i18n deltas) and `docs/proposals/b6-1a-validation-audit-events-response-shape.md` (validated real shape).
> **This design re-anchors the prior art to the new spec.** The two material conflicts with the old design are resolved here: (1) the tab no longer owns `_auditPath`/`_limit` path literals or the direct `widget.api.get(...)` call — `AuditReadClient` owns the trio literals and the tab reads only through `_client.list(limit: 100)` (REQ-5 scan-5 safety by construction); (2) the `AuditLogService` `kDebugMode` seam and the self-audit drill (§1.2a/W2/W3/F13/F14/F16 in the old design) are **B6-1b / B1-5 scope** and are excluded (§6 of the spec).

## 0. Evidence verification (spec claims re-checked at HEAD, 2026-08-07, before writing)

The spec's 16 evidence rows were treated as untrusted and re-verified. All substantive claims hold. Three trivial citation drifts found and corrected below; no [CORRECTION] in the spec itself is contradicted.

| Claim (spec row) | Verified reality | Verdict |
|---|---|---|
| E1 `audit_log_tab.dart` ring-only, `const AuditLogTab({super.key})` at `:11`, no api param; ring-derived UI at `:161` ({count} entries), `:129-130` (_errorRate), `:180-192` (Clear), `:97-124` (CSV), subtitle `:158`, empty `:244`; 345 lines | Confirmed line-for-line: `_logService = AuditLogService()` `:22`, `_refresh` reads `_logService.entries` `:43`, file is 345 lines (wc) | ✅ |
| E2 dashboard governance `:551-557` (page `:557`), auditLog `:558-567` ungated `const AuditLogTab()` `:566`; `navigation` `:243`, `capabilities` `:244`, `_endpoints` from `listEndpoints()` `:127-130`, `_visibleModules` `:578` | Confirmed. `[CORRECTION: :558 → :559]` — the auditLog entry block starts at `:559` (`:558` closes governance); `page: const AuditLogTab()` at `:566` exactly. `_api` declared at `:92` (spec says `:82` — field is `late final` at `:92`, assigned in `initState`; trivial). | ✅ |
| E3 audit trio at `snaplink_admin_types.dart:310-312`; `SnaplinkAdminCapabilities.has` at `:94` with `{param}`-normalizing compare | Confirmed: trio exactly `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}`; `has()` at `:94` uses `_normalizePath` | ✅ |
| E4 `AuditQuery` fields `:20-38`, `supportedKeys` `:51-58`, `fromJson` `:66-146` rejecting unknown keys, `toQueryParameters()` `:148-165`, default wire `{'limit': '100'}` | Confirmed (`class AuditQuery` at `:17`, `supportedKeys` at `:51`, `AuditQueryParseException` at `:167`). Trim semantics verified in `toQueryParameters` | ✅ |
| E5 governance `_has` fallback `:81-91` → audit UI unconditionally available; pinned by `admin_governance_security_test.dart:189-193` | Confirmed: third clause consults `SnaplinkAdminOperationCatalog.endpoints`; the pin test ("catalog fallback renders the UI even with empty capabilities") is green at HEAD. `[CORRECTION: skipCache at :105, not :166]` — `widget.api.skipCache()` is at `governance_tab.dart:105` (the spec/old design cited `:166`; `:166` is inside `_queryAudit`, no skipCache there). | ✅ + ⚠️ |
| E6 `portal_api.dart` no audit surface (`:56-60,:180-265`) | Confirmed: /me-family, notifications stream, /logout only; no query-param support on read verbs | ✅ |
| E7 scan 5 `scanSecondConsumer` at `scans.dart:233-260`, group at `guard_test.dart:163-176`; trip condition = audit literal + `query:` + no `AuditQuery` string; `{id}` detail reader stays green | Confirmed; group green at HEAD (ran `test/audit_contract_guard_test.dart`: 38 passed) | ✅ |
| E8 stale `lib/api/README.md` row | Confirmed: `| audit_log_service.dart | 本地审计日志（append-only） |` at line 8; file lives in `lib/services/` | ✅ |
| E9 `implementation-gate.md:56` T-12 joint | Confirmed: console row 1 — read path via sink read API, ring demoted, "devtools 伪造不再构成证据" | ✅ |
| E10 tenant_id/trace_id `[PROPOSED]`, B4-1/BFF-dependent; AC-3.2 `bff`-literal scan | Confirmed: no BFF code in lib/; AC-3.2 scan green at HEAD | ✅ |
| E11 no tenant-claim parser, no trace_id injection in lib/ | Confirmed (`trace_id` only read at `setup_api.dart:215`; `tenant_id` only response-field reads, CRUD, and query-param precedents) | ✅ |
| E12 harness `admin_governance_security_test.dart:12-38` (`_api`/`_caps`/`_pump`) + recording MockClient `:147-161` | Confirmed; file has uncommitted formatting-only diff (30+/34-, `dart format`-shaped), no semantic change | ✅ |
| E13 tests breaking on constructor change: `admin_support_tabs_test.dart:62-163` (pumps `const AuditLogTab()` at `:88` and `:149`) | Confirmed | ✅ |
| E14 no in-repo response schema; validated real shape `{events, count}`; `limit=100` in-bounds; query GET bypasses `DataCache` at `snaplink_admin_api.dart:133-134`; `SnaplinkAdminApiError.toString()` at `:44` excludes `data` | Confirmed: query branch `if (query != null) return _request(...)` at `:133-134` never consults/populates the cache; `toString()` at `:44` = `description ?? code ?? 'Admin request failed ($status).'`; error class carries `data` field (never rendered — W1.3a) | ✅ |
| E15 row-model prior art (§1.1 old design): allowlist, redact-first, `is`-only, never-throw, count-preserving, `outcome == ''` fallback, URI query scrub, list keys `['events','items','results','data','entries']` | Confirmed in `docs/proposals/b6-1a-lib-api-auditlogtab-server-read-design.md` §1.1 + AMEND W1.1 | ✅ (adopted) |
| E16 line budget + i18n | Confirmed: `engineering.yaml:11` `max_lines: 400`, `audit_log_tab.dart` not exempt; zh subtitle at `app_strings_source_admin_core.dart:56`, zh empty state at `app_strings_source_admin_features.dart:142`; `localizedNamedCopy` regex `(?:title\|detail\|body\|emptyText):` at `i18n_coverage_test.dart:78-81`. `[CORRECTION: "subtitle: uncovered" is false as written]` — the unanchored `title:` alternative already matches every `subtitle:` literal by substring (verified empirically); coverage is accidental, not intentional, which is exactly why the FM-16 resolution (§1.7) makes the **anchored** extension mandatory | ✅ + ⚠️ |

Transport facts re-verified for the failure-mode section: `SnaplinkAdminApi` retries 5xx up to `maxRetries = 3` with backoff (`snaplink_admin_api.dart:61,:330`), 401 fires `onUnauthorized` (`:172`), non-2xx raises `SnaplinkAdminApiError`.

Baseline gates run at HEAD: `test/audit_contract_guard_test.dart` + `test/audit_query_test.dart` + `test/admin_navigation_test.dart` (38 passed); `test/admin_governance_security_test.dart` + `test/admin_support_tabs_test.dart` + `test/api_contract_test.dart` + `test/api_paths_test.dart` + `test/snaplink_admin_api_test.dart` + `test/service_contracts_test.dart` + `test/backend_contract_manifest_test.dart` + `test/i18n_coverage_test.dart` (55 passed).

## 1. API changes

### 1.1 New file `lib/api/audit_event_row.dart` — typed row model + pure mapper (REQ-2)

Adopted unchanged from the old design §1.1 + AMEND W1.1 (binding prior art; the new spec REQ-2 re-anchors it as `list()`'s return type). Summary of the contract, unchanged:

- `class AuditEventRow` — immutable, read-only: `final DateTime? timestamp; final String type; final String outcome; final String id; final String actorId; final String clientId; final String tenantId;` + const constructor.
- `List<AuditEventRow> auditEventRowsFromResponse(Map<String, dynamic> response)` — pure, no Flutter imports, zero `debugPrint`/`print`.
- Invariants: **allowlist first** (fields other than the seven above — `request_id, trace_id, span_id, parent_span_id, actor_ip, user_agent, provider, session_id, token_id, token_strategy, reason, metadata, prev_hash, hash, server_version` — are dropped at row construction; no path from raw response to row except through the allowlist); **redact-first** (`SensitiveData.redact` once, before any extraction); **string-level URI query scrub** on allowlisted strings that parse as URIs (sensitive query params → `<redacted>`, rule 3a — required because `SensitiveData.redact` is key-based); **`is`-only reads, no `as` casts**; top-level `try/catch` → single constant-built fallback row, never rethrows; **count-preserving** (N input elements → N rows; fallback rows carry `outcome == ''` — no fabricated success/failure); list extraction from first of `['events','items','results','data','entries']`; `{}`/`{'events': []}` → 0 rows; legacy ring vocabulary (`method`/`path`/`status`) demoted to defensive fallback for non-snaplink deployments.
- Target size: ≤ 130 lines (old design pin), ≤ 400 gate.

### 1.2 New file `lib/api/audit_read_client.dart` — `AuditReadClient` (REQ-1)

The lib/api deliverable. Read-only, typed, over the **existing** `SnaplinkAdminApi.get(path, {query})` transport. Owns the trio path literals — the single source of truth for the audit paths, and the reason scan 5 can never flag the tab.

```dart
/// Typed read client for the documented audit trio.
///
/// The single owner of the audit path literals and the only sanctioned way
/// for the audit timeline to reach the sink read API. Query construction is
/// exclusively through [AuditQuery] — no hand-built `query:` maps (guard
/// scan 5). `tenantId`/`traceId` are optional context parameters: neither
/// token-claim parsing nor BFF trace_id injection exists in this repo
/// (B4-1/BFF-dependent, [PROPOSED]); they are never hardcoded or derived,
/// and are omitted from the wire unless non-empty after trim.
class AuditReadClient {
  static const eventsPath = '/api/v1/audit/events';
  static const facetsPath = '/api/v1/audit/facets';
  static const eventDetailPath = '/api/v1/audit/events/{id}';

  final SnaplinkAdminApi _api;
  final String? _tenantId;
  final String? _traceId;

  AuditReadClient(this._api, {String? tenantId, String? traceId});

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
    return auditEventRowsFromResponse(
      await _api.get(eventsPath, query: query),
    );
  }

  Future<Map<String, dynamic>> facets({
    int limit = 100,
    String? cursor,
    String? eventTypes,
    String? outcome,
    String? tenantId,
    String? traceId,
  }) async =>
      _api.get(facetsPath, query: AuditQuery(
        limit: limit,
        tenantId: tenantId ?? _tenantId,
        traceId: traceId ?? _traceId,
        cursor: cursor,
        eventTypes: eventTypes,
        outcome: outcome,
      ).toQueryParameters());

  Future<Map<String, dynamic>> event(String id) async =>
      _api.get('$eventsPath/${Uri.encodeComponent(id)}');
}
```

Design decisions:

- **D1 — path literals live only here.** `eventsPath`/`facetsPath`/`eventDetailPath` are `static const`; the tab's gate references `AuditReadClient.eventsPath` and its reads go through `_client.list(...)` — so `lib/screens/admin/audit_log_tab.dart` contains no `/api/v1/audit` literal (not even in comments — the AC-5.2 grep is comment-sensitive). Scan 5's trip condition (audit literal + `query:` + no `AuditQuery`) fires **on this file only** and is satisfied by construction: the file contains the literals, the `query:` argument, and the `AuditQuery` string.
- **D2 — AuditQuery-only query construction.** The query map is produced solely by `AuditQuery(...).toQueryParameters()`; there is no map literal in the file (grep pin in AC-2.3). Default wire exactly `{'limit': '100'}`.
- **D3 — optional context parameters, never hardcoded.** `tenantId`/`traceId` are constructor-level context with per-call override shadowing (`tenantId ?? _tenantId`); whitespace-only values are omitted by `AuditQuery` trim semantics. This is the B4-1/BFF extension point; no claim parsing or injection mechanism is invented in this direction.
- **D4 — `event()` uses the detail-reader precedent** (`Uri.encodeComponent(id)`, split literal, no `query:` argument — `admin_live_events_tab.dart:167` pattern), so the `{id}` reader never trips scan 5. The tab does not call `event()` in this direction (no detail dialog exists in the tab); the method completes the documented trio surface per REQ-1 and is unit-tested in AC-2 surface-completeness.
- **D5 — transport untouched.** No new HTTP behavior, retries, auth, cache, or BFF surface; `list()`/`facets()` ride the existing `query != null` branch of `get()` which bypasses `DataCache` entirely (`snaplink_admin_api.dart:133-134`) — correct for a live timeline. `skipCache()` is therefore redundant-but-harmless in the tab (kept for symmetry with governance; flag still consumed).
- Target size: ≤ 110 lines, ≤ 400 gate.

### 1.3 `lib/screens/admin/audit_log_tab.dart` — rewire (REQ-3, REQ-4, REQ-5)

Constructor (breaking, same shape as `GovernanceTab`):

```dart
class AuditLogTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const AuditLogTab({super.key, required this.api, required this.capabilities});
  ...
}
```

State model (inherits the old design §1.2, re-anchored to the client):

```dart
late final AuditReadClient _client;   // = AuditReadClient(widget.api) — tenant/trace context is
                                      // B4-1/BFF scope; nothing is passed today (D3)
List<AuditEventRow> _rows = [];       // server truth; raw response never retained in state
List<AuditEventRow> _displayed = [];  // client-side filtered/sorted view of _rows
bool _loading = false;
String? _error;
bool _notEnabled = false;
int _generation = 0;                  // stale-response guard: only the newest fetch may commit
```

- **`_refresh()` flow** (called from `initState` and every user-initiated refresh — refresh button, retry, search `onChanged`, outcome filter change):
  1. **Gate first:** `if (!widget.capabilities.has('GET', AuditReadClient.eventsPath))` → `_notEnabled = true`, `_rows = []`, **return without issuing any request** (AC-4.1 zero-request pin). The gate consults the injected `SnaplinkAdminCapabilities` **directly** — it deliberately does **not** copy governance's `_has` catalog fallback (`governance_tab.dart:81-91`). This is the one documented deviation (REQ-4); the dashboard already hands the tab the merged view, so production behavior is unchanged — only the hiding clause becomes testable.
  2. `widget.api.skipCache()` (governance precedent `:105`; harmless no-op for query GETs — E14), `_loading = true`, `_error = null`, capture `final gen = ++_generation`.
  3. `final rows = await _client.list(limit: 100);` then `if (!mounted || gen != _generation) return;` — commit `_rows = rows`, recompute `_displayed` (client-side filter/sort), `_loading = false`.
  4. `on SnaplinkAdminApiError catch (error)` → `if (!mounted || gen != _generation) return;` `_error = error.toString()` — **never `error.data`** (`SnaplinkAdminApiError.toString()` at `snaplink_admin_error.dart:44` excludes `data` by construction). `finally` clears `_loading` under the same guard.
- **Derived UI (server response only, REQ-3):**
  - `{count} entries` ← `_displayed.length`... **no** — `_rows.length` for the header count (page length; the response `count` field is **never** read — E14/W1.3d: it is page length, and `_rows.length` is the same value only when untruncated; using `_rows.length` makes the displayed count server-truth by construction).
  - Error-rate badge ← rows with `outcome == 'failure'` (real-shape signal; the ring's `statusCode >= 400` rule is dead against the real schema — validation doc verdict).
  - Subtitle `:158` → server-sourced copy (see §1.7); empty state `:244` → server-truth copy, shown when `_rows.isEmpty && !_loading && _error == null`.
  - States rendered: loading (refresh disabled), error (`error.toString()` + inline retry that re-invokes `_refresh()` — the gate is re-entered, never a raw fetch), not-enabled (REQ-4 copy, zero requests), server-truth empty.
- **Search/filter:** client-side over the fetched page. The ring-vocabulary METHOD dropdown (dead against real payloads) is replaced by an **outcome filter** (All / success / failure) over `row.outcome`; search matches `type`/`outcome`/`actorId`/`clientId`/`tenantId`/`id` (case-insensitive). Search/filter changes re-invoke `_refresh()` (fresh page, then filter) — and **never** contribute query parameters (AC-1.6 no-leak boundary: every request carries exactly `{'limit': '100'}`).
- **Table columns** (real-shape): TIME (`timestamp`, `--` when null, sorts last), EVENT (`type`), OUTCOME (status-colored `StatusChip`: success/failure, `-` when `''`), ACTOR (`actorId`, `-` when empty), TENANT (`tenantId`, `-` when empty). Sortable over timestamp/type/outcome. (CSV header matches the old design pin: `timestamp,type,outcome,id,actor_id,client_id,tenant_id`.)
- **CSV export:** operates on `_displayed` (server-derived rows); hardened `_csvCell` from the old design (CR/LF normalization first, quote doubling, OWASP `= + - @ \t \r` + unicode-lookalike prefix set, always-quote); null timestamps export `--` (no `toUtc()` throw); snackbar canonicalized to `LocalizedText('Exported {n} entries as CSV to clipboard', args: {'n': ...})` (exact-key path; the pre-interpolated form only works via the fragile pattern fallback).
- **Clear button: unchanged code** — still clears the local ring via `_logService.clear()` and refetches (ring semantics/relabeling are B6-1b scope, §6; the timeline no longer reads the ring, so Clear only affects the invisible debug ring).
- **No `_logService.entries` read anywhere in the tab** (only `_logService.count`/`clear()` for the Clear action).

### 1.4 `lib/screens/admin/admin_navigation.dart` — `supportsAuditLog` getter (REQ-4)

Additive, following the sibling `supportsX` pattern (`:71-144`):

```dart
bool get supportsAuditLog => _has('GET', '/api/v1/audit/events');
```

- `_has` (admin_navigation.dart, the navigation-level helper — **not** governance's `_has`) compares against `capabilities` (the merged view). Because `SnaplinkAdminOperationCatalog` contains the trio, the default (documented-catalog merge) is `true` — identical semantics to `supportsOrganizations` etc. The cull is effective when the merged contract lacks the route (`AdminNavigationCapabilities(endpoints, documentedEndpoints: const [])` — constructor already supports it).
- Predicate equivalence by construction: `navigation.supportsAuditLog == navigation.capabilities.has('GET', '/api/v1/audit/events')` for the same endpoint set — the nav getter and the tab gate share one predicate (AC-4.3 pins it across three variants).
- `AdminModuleId.auditLog` (`'audit-log'`, `:41`) and the constructor are unchanged.

### 1.5 `lib/screens/admin/dashboard_screen.dart` — wiring + cull (REQ-6)

Replace the ungated entry at `:559-567` with the standard cull pattern:

```dart
if (navigation.supportsAuditLog)
  AdminNavigationEntry(
    module: AdminModuleId.auditLog,
    destination: NavigationRailDestination(
      icon: const Icon(Icons.receipt_long_outlined),
      selectedIcon: const Icon(Icons.receipt_long),
      label: Text(strings.auditLog),
    ),
    page: AuditLogTab(api: _api, capabilities: capabilities),
  ),
```

(`_api` at `:92`, `navigation`/`capabilities` at `:243-244`, all in scope.) The cull chain is automatic: `_visibleModules = adminNavigationModules(entries)` (`:578`) → `commandPaletteItemsForModules(widget.allModules)` (`command_palette.dart:83`; `/admin/audit-log` item at `command_palette_commands.dart:247`). `health_tab.dart:337` (`AdminRoute.go('audit-log')`) keeps working — a culled module falls back to overview via `adminNavigationIndexForModule` (`admin_navigation.dart:186-196`), existing semantics.

### 1.6 `lib/api/README.md` — corrections (REQ-7)

- Remove the stale `| audit_log_service.dart | 本地审计日志（append-only） |` row (the file lives in `lib/services/audit_log_service.dart`).
- Add rows for `audit_read_client.dart` (typed audit read client, trio surface, AuditQuery-only) and `audit_event_row.dart` (read-only row model + pure mapper).

### 1.7 i18n deltas (REQ-8) — complete pinned inventory (hardening pass)

All new/changed UI strings in this rework, with key naming vs existing keys, zh entries, and atomic landing (step 4, one change). Verified single-call-site claims at HEAD; catalogs stay at HEAD line counts except the pinned deltas below (admin_core 493 → 494 net; admin_features 329, unchanged).

- **Subtitle key replaced in place**: `'All authentication and administrative events recorded on this device.'` → `'All authentication and administrative events recorded by the server.'` with zh `'服务器记录的全部认证与管理事件。'` at `app_strings_source_admin_core.dart:56`. Old key has exactly one call site (`audit_log_tab.dart:158`) + one catalog entry → replace in place (no orphan). New key avoids `' on '`/`{…}` → missing-zh returns identity → parity scan flags red.
- **Empty-state key replaced in place**: `'No audit entries yet. Operations will appear here.'` → `'No audit events returned by the server yet.'` with zh `'服务器尚未返回审计事件。'` at `app_strings_source_admin_features.dart:142` (single call site `audit_log_tab.dart:244`; file stays 329 lines).
- **Outcome filter labels (new)**: `'All'` reuses the existing common key (`app_strings_source_common.dart:11` → `'全部'`); `'success'`/`'failure'` are **new lowercase keys** in admin_core (convention: `'active'`, `'suspended'`, `'allow'`, `'token'`, `'down'`), zh `'成功'`/`'失败'` — do NOT reuse capitalized `'Success'`/`'Failed'` (`:466,:468`; `'Failed'` ≠ `'failure'`). Filter dropdown items ride `LocalizedText`; the OUTCOME column `StatusChip` shows the raw server `row.outcome` (data, not localized — same as today's METHOD chips).
- **Error-rate badge (new key)**: `'{n}% errors'` — currently raw and **unlocalized** (`audit_log_tab.dart:141`, silent English in zh today). Add key + zh `'错误率 {n}%'` in admin_core; render via `context.tr('{n}% errors', {'n': rate.round()})` (StatusChip label is a plain String). Zh value must keep the `{n}` placeholder (`test/app_strings_test.dart` placeholder-preservation pin).
- **Not-enabled state (REQ-4) copy pinned**: reuse `'This feature is not enabled on the connected replica.'` — exact key + zh `'连接的副本未启用此功能。'` already exist (`app_strings_source_admin_features.dart:92`), governance precedent (`governance_tab.dart:374`), pinned-test precedent (`admin_governance_security_test.dart:198`). Zero new i18n surface. Do NOT invent a new `'…on this replica'` sentence: any untranslated EN containing `' on '` is **garbled, not flagged** by the parity scan (pattern `'{browser} on {os}'` in `app_strings_source_portal.dart:340`; governance's `'Audit querying is not enabled on the connected replica.'` already ships garbled zh today — pre-existing, out of scope).
- **Search hint (stale copy)**: replace `'Search by path, label...'` with `'Search...'` (common key, zh `'搜索…'`) — path/label are ring vocabulary, dead post-rework (search matches type/outcome/actorId/clientId/tenantId/id). Old key single-site (`audit_log_tab.dart:206`, `admin_core:343`) → replace in place.
- **Orphan removal**: `'All methods'` (`admin_core:102`) and `'Modify'` (`admin_core:231`) have single call sites (`audit_log_tab.dart:224,:229`), single catalog entries, and zero test pins → removed in step 4.
- **CSV snackbar canonicalization**: `LocalizedText('Exported {n} entries as CSV to clipboard', args: {'n': _displayed.length})` — key unchanged (`admin_core:89` → `'已将 {n} 条记录以 CSV 导出到剪贴板'`); replaces the pre-interpolated form (works today only via the fragile pattern fallback, probe-verified).
- **Deliberate non-items (no zh entries)**: CSV header `timestamp,type,outcome,id,actor_id,client_id,tenant_id` (machine format, AC-5 header-equality pin); error text `error.toString()` (`SnaplinkAdminApiError.toString()` = `description ?? code ?? 'Admin request failed ($status).'` — API-derived dynamic data; C11/FM-12 pin `toString()` only, never `LocalizedText`-wrapped); table headers `TIME`/`EVENT`/`OUTCOME`/`ACTOR`/`TENANT` (raw, `AdminDataColumn.label` → `Text`, matches today's `METHOD`/`PATH`).
- New keys + zh entries land **atomically with the tab rework** (step 4) — `zh.translate` returns the English source for unlisted keys, so a missing zh entry is a silent zh regression; the parity scan catches it only when the string is not pattern-garbled (see the `' on '` trap above — all new keys avoid it).
- **FM-16 resolution — the `subtitle` scan extension is MANDATORY** (restores prior-art C8c/F15, which the spec's "optionally" regressed): extend `localizedNamedCopy` in `test/i18n_coverage_test.dart:78-81` to the **anchored** form `(?:\b(?:title|subtitle|detail|body|emptyText)):` — the design's earlier unanchored `(?:title|subtitle|detail|body|emptyText):` was a **no-op** (the unanchored `title:` alternative already matches `subtitle:` sites by substring). Anchoring makes subtitle coverage intentional and drops only 3 accidental current matches (`emptySubtitle:` in `network_policies_tab.dart:201`, `local_users_tab.dart:266`, `access_policies_tab.dart:192` — all zh-complete, `admin_indirect:3,54,55`). Tree-safety re-verified: 7 direct-literal `subtitle:` sites in `lib/screens`+`lib/widgets` (audit_log_tab:158, clients_tab:460, tenants_tab:285,:412, users_tab:239,:350, device_security_widgets:215) — **all 7 have exact zh entries** (admin_core:72-74, admin_indirect:48,95,123). Extension and zh entries are mutually dependent (extension without entry → i18n test red; entry without extension → gap persists silently).
- AC-1.4 gains a zh-locale variant: pump with zh locale, assert `find.text('共 2 条')` + the new subtitle zh (prior-art AC-5 precedent).

### 1.8 `engineering.yaml` — filesize (REQ-8)

`max_lines: 400` (`:11`); `audit_log_tab.dart` (345 today) is **not** exempt. The rework adds the gate block, generation guard, loading/error/not-enabled states, and real-shape CSV/sort rework; the client (D1) shaves the old design's `_auditPath`/`_limit` consts and direct-fetch lines, but the measured estimate remains **~415-425** (old design measured +81 → 426; client removes ~6-10). **Decision rule (deterministic):** implement the rework, count lines; if > 400, add `- "lib/screens/admin/audit_log_tab.dart"` to `filesize.exemptions` **in the same change** (precedent `governance_tab.dart`, `clients_tab.dart`). The exemption is expected to be mandatory. New files: `audit_read_client.dart` ≤ 110, `audit_event_row.dart` ≤ 130 — no violations.

## 2. Compatibility constraints

| # | Constraint | Consequence / enforcement |
|---|---|---|
| C1 | `AuditLogTab` constructor is **breaking** (`const AuditLogTab()` → required `api`/`capabilities`) | Exactly 3 call sites (dashboard `:566`, `admin_support_tabs_test.dart:88,:149`) change in the same commit; analyzer/test fail otherwise; AC-5.2 grep pins zero `const AuditLogTab()` hits |
| C2 | **No transport changes in lib/api** (REQ-7): `SnaplinkAdminApi`, `PortalApi`, `SnaplinkAdminOperationCatalog`, `SnaplinkAdminCapabilities` untouched | `test/snaplink_admin_api_test.dart`, `test/api_contract_test.dart`, `test/api_paths_test.dart`, `test/sso_client_test.dart`, `test/admin_governance_security_test.dart` stay green unchanged (AC-6). lib/api delta = 2 new files + README rows |
| C3 | `AuditLogService` public API untouched (record/entries/search/filterByMethod/recent/clear/count) | `test/service_contracts_test.dart` green unchanged; `_recordAudit` (`snaplink_admin_api.dart:81,:324`) untouched; tab simply stops reading the ring for the timeline |
| C4 | `AuditQuery` untouched (exists, pinned) | `test/audit_query_test.dart` green unchanged; `AuditReadClient` is a new consumer of its existing API |
| C5 | `AdminNavigationCapabilities` — additive getter only; constructor signature unchanged | `documentedEndpoints:` override (already supported) is the absence-simulation seam (AC-4.3) |
| C6 | Guard scans 1–5 (`test/audit_contract_guard_test.dart`) green **without modification** | Scan 5 trips iff a lib file combines audit literal + `query:` without `AuditQuery`; client satisfies by construction (D1/D2), tab has no literal (D1) |
| C7 | i18n rules (`test/i18n_coverage_test.dart`): no raw `Text(literal)`; zh parity; new keys + zh entries atomic | §1.7 (pinned inventory); **mandatory** anchored `subtitle` scan extension (`(?:\b(?:title|subtitle|detail|body|emptyText)):`) is the only `i18n_coverage_test.dart` change; FM-16 resolution |
| C8 | Line budget (`engineering.yaml` `max_lines: 400`) | §1.8: ≤ 400 or atomic exemption; new files ≤ 400 |
| C9 | Culling machinery reused — no new gate widget | `supportsAuditLog` + dashboard `if`; palette cull via `_visibleModules`; health link falls back to overview |
| C10 | No `docs/backend-contracts.json` edit; no BFF surface | `test/backend_contract_manifest_test.dart` unaffected; AC-3.2 `bff`-literal scan green |
| C11 | Error surfacing contract: `error.toString()` only, never `error.data` | `SnaplinkAdminApiError.toString()` excludes `data` by construction; grep gate in step 10 |

## 3. Failure modes

| # | Failure | Behavior | Mitigation / assertion |
|---|---|---|---|
| FM-1 | Server 5xx / timeout / network loss | Transport retries GET ≤ `maxRetries` (3, backoff, `snaplink_admin_api.dart:61,:330`); on exhaustion → `SnaplinkAdminApiError`/`TimeoutException` → `_error = error.toString()` + inline retry (re-enters gate); **ring never shown as fallback** | AC-3b (seeded ring + 500 → error state, forged row absent) |
| FM-2 | 401 | Existing `onUnauthorized` fires; tab shows error state | No new code path; covered by existing API tests (AC-6) |
| FM-3 | Malformed / unexpected response shape (no in-repo contract, E14) | Mapper never throws, never leaks: redact-first → list extraction → `is`-only reads → fallback rows; `{}` → 0 rows; non-map payloads become `{}` in `decodeSnaplinkAdminPayload` | `test/audit_event_row_test.dart` unit matrix (incl. `{}` → 0 rows, bait non-allowlisted fields never surface, mid-list garbage never drops later rows, no rethrow) |
| FM-4 | Empty server result | Server-truth empty state, `0 entries` — `{'events': []}` and `{}` both → 0 rows, no phantom record | AC-3c |
| FM-5 | Missing capability (trio-less raw inventory) | Tab gate: not-enabled state, **zero requests**; navigation cull hides the module | AC-4.1 (MockClient records zero requests) + AC-4.3ii (cull) |
| FM-6 | Governance `_has` catalog fallback copied into the tab | Would make the audit UI unconditionally available and defeat the hiding clause | REQ-4 mandates direct `capabilities.has(...)`; AC-4.1 pins zero requests with trio-less caps (would fail red if the fallback were copied); governance's own fallback stays pinned by its unchanged test |
| FM-7 | Nav getter / tab gate divergence | Entry offered but page disabled, or hidden while page would work | One predicate by construction (§1.4); AC-4.3 predicate-equivalence across 3 variants |
| FM-8 | Hand-built query map / path literal in the tab | Scan 5 trips (CI red) | D1/D2 by construction; AC-6 guard green; AC-5.2 grep (`/api/v1/audit` in the tab → zero hits, comment-sensitive) |
| FM-9 | Stale async race (rapid refresh/search) | Generation counter: only the newest fetch may commit rows (`gen != _generation` after await; `mounted` alone insufficient) | Widget test: two in-flight requests completing out of order → older response never replaces newer rows |
| FM-10 | `count` field misread as total | `{count} entries` ← `_rows.length`; response `count` never read (page length, E14) | AC-1.4/AC-3a assert the rendered count equals the served page size, not a planted `count` value |
| FM-11 | tenant_id/trace_id leakage onto the wire | Defaults absent by construction (D3); whitespace-only trimmed; search terms never leave the client | AC-1.3/AC-1.6 exact-query assertions; AC-2.1 explicit absence |
| FM-12 | `error.data` exposure | Error renders `error.toString()` only; `data` never retained/rendered | AC-3b error fixture carries bait in non-`toString` fields → bait appears nowhere; grep `error\.data` in the tab → zero hits (step 10) |
| FM-13 | Ring forgery (devtools-seeded `sso_audit_log`) | Timeline never reads the ring → forged rows never render (T-12: "devtools 伪造不再构成证据") | AC-1.5/AC-3 seed `/api/v1/admin/forged`, assert findsNothing in all three server states |
| FM-14 | CSV formula injection / row-splitting | Hardened `_csvCell` (CR/LF normalization, quote doubling, OWASP + lookalike prefix set, always-quote); rows redacted + scrubbed before export; header constant | AC-5 test-2 table-driven matrix (from the old design, preserved against MockClient-served bait rows) + header equality pin |
| FM-15 | Null timestamp crash in CSV | `--` fallback (no `toUtc()` throw) | AC-5 test-2 includes a null-timestamp row |
| FM-16 | New i18n key without zh entry | `zh.translate` silently returns English source; **worse**: untranslated EN containing `' on '` is pattern-garbled by `'{browser} on {os}'` (portal:340), which the zh-parity test does NOT flag (false-negative class; live in governance today) | §1.7 pinned inventory — all new keys avoid `' on '`/`{…}` so missing zh returns identity and is scan-flagged; **mandatory anchored `subtitle` scan extension** (step 4, same change as the new subtitle key; extension and zh entry red in both directions); AC-1.4 zh-locale variant |
| FM-17 | Line-budget violation | `checks/filesize.py` fails (`audit_log_tab.dart` > 400) | §1.8: atomic exemption in the same change as the rework |
| FM-18 | Leftover `const AuditLogTab()` call site | Compile error (required params) — that is the enforcement | AC-5.2 grep zero hits |
| FM-19 | Real-payload divergence (server rows have no method/path/status) | Columns/filters/badge re-pinned to `{type, outcome, timestamp, actor_id, client_id, tenant_id}`; error-rate from `outcome == 'failure'`; METHOD dropdown → outcome filter | AC-1.4 fixture is real-shaped; validation doc verdict adopted |

## 4. Migration steps (ordered; each step leaves the tree green)

1. **Baseline:** `flutter analyze && flutter test` — record green state (AC-6 baseline; measured 38 + 55 at HEAD for the pinned suites).
2. **Add `lib/api/audit_event_row.dart`** (model + mapper per §1.1) + **`test/audit_event_row_test.dart`** (unit matrix: real-shape, `{}` → 0 rows, `{'events': []}` → 0 rows, bare map → 1 row, non-map elements → fallback rows, bait non-allowlisted fields dropped, URI query scrub `?client_secret=`/`?token=`, count-preserving N→N, `outcome == ''` on fallbacks, no rethrow). No consumers yet → green.
3. **Add `lib/api/audit_read_client.dart`** (§1.2) + **`test/audit_read_client_test.dart`** (AC-2: default absence, constructor-provided presence, per-call override shadowing, whitespace-only omission, facets/event surface-completeness, no map literal in the client source). No consumers yet → green.
4. **Rework `lib/screens/admin/audit_log_tab.dart`** (§1.3) **+ i18n deltas (§1.7, full pinned inventory) + filesize decision (§1.8) in the same change.** Dashboard still constructs `const AuditLogTab()` → analyzer fails here by design; proceed to step 5 in the same change. **The anchored `subtitle` scan extension (mandatory, FM-16 resolution) also lands here** — `localizedNamedCopy` → `(?:\b(?:title|subtitle|detail|body|emptyText)):` in `test/i18n_coverage_test.dart:78-81`, plus: subtitle key + zh, empty-state key + zh, `'{n}% errors'` + zh, `'success'`/`'failure'` + zh, not-enabled copy (reuse `'This feature is not enabled on the connected replica.'`), search hint → `'Search...'`, `'All methods'`/`'Modify'` removal, snackbar canonicalization. The new `lib/api/audit_read_client.dart` doc comments must **not** copy the design sketch's `BFF` acronym (scan-2 whole-file, case-insensitive — phrase as "B4-1-dependent [PROPOSED]").
5. **Add `supportsAuditLog`** (§1.4) **+ wire `dashboard_screen.dart`** (§1.5). Compiles again.
6. **Rework `test/admin_support_tabs_test.dart`** (both tests pump with injected `_api`/`_caps`): test 1 becomes server-driven (2 real-shape MockClient events; filter/search/export flows assert server rows); test 2 preserves clipboard mock + injection-guard matrix against MockClient-served bait rows + null-timestamp `--` + header equality (old-design AC-5 pins).
7. **Add `test/audit_log_tab_test.dart`** (AC-1, AC-3, AC-4 page half; harness cloned from `admin_governance_security_test.dart:12-38` + recording MockClient `:147-161`).
8. **Extend `test/admin_navigation_test.dart`** (AC-4.3: `supportsAuditLog` true/false/true across the three variants + module culling + predicate equivalence) **and `test/admin_shell_test.dart`** (AC-5.1: endpoints fixture with the trio → navigate to audit-log in the System group → server rows render, proving the page is constructed with the dashboard's `_api`/`capabilities`; palette item absent when culled).
9. **`lib/api/README.md` corrections** (§1.6).
10. **Gates:** `grep -rn 'const AuditLogTab()' lib/ test/` → zero hits; `grep -rn '/api/v1/audit' lib/screens/admin/audit_log_tab.dart` → zero hits; `grep -rn 'error\.data' lib/screens/admin/audit_log_tab.dart` → zero hits; `grep -rn 'query: {' lib/api/audit_read_client.dart` → zero hits (AuditQuery-only, AC-2.3); `flutter analyze`; `flutter test` (full); `dart format --set-exit-if-changed`; `checks/` gates (`engineering.yaml`).

Rollback: single-commit revert of steps 2-8 restores ring-only behavior; no data migration, no server-side change, no storage-schema change.

## 5. Testable acceptance mapping

| AC (spec) | Test file(s) | Concrete assertions |
|---|---|---|
| **AC-1 — T-12 joint** | `test/audit_log_tab_test.dart` (new; `_api`/`_caps`/`_pump` harness + recording MockClient from `admin_governance_security_test.dart:12-38,:147-161`) | (1) pump `AuditLogTab(api: api, capabilities: caps)`; (2) **exactly one** `GET /api/v1/audit/events` after initial pump, `queryParameters` deep-equals exactly `{'limit': '100'}`; **zero** requests to any other path (no `/facets`, no `/{id}`); (3) `tenant_id`/`trace_id` **absent** — explicit map-equality assertion, never a silent any-params check; (4) 200 with 2 real-shape events (`{'id','type','outcome','timestamp','actor_id','client_id','tenant_id'}`, e.g. `type: 'admin_client_created', outcome: 'success'`) → `find.text('2 entries')`, `find.textContaining('admin_client_created')`, subtitle without "on this device"; (4a) **zh-locale variant (FM-16 pin):** re-pump under `Locale('zh')` → `find.text('共 2 条')`, subtitle renders `'服务器记录的全部认证与管理事件。'` (parity enforced by the anchored `subtitle` scan extension); (5) pre-seed `AuditLogService().record(AuditEntry(path: '/api/v1/admin/forged', …))` + `addTearDown(service.clear)` → `find.textContaining('/api/v1/admin/forged')` findsNothing while server rows render; (6) **no-leak boundary:** type a search term, re-pump → every recorded request keeps `queryParameters` exactly `{'limit': '100'}` (search terms never leave the client) |
| **AC-2 — optional tenant/trace contract** | `test/audit_read_client_test.dart` (new, unit) | (1) `AuditReadClient(api)` → `list()` issues `GET /api/v1/audit/events?limit=100` — no `tenant_id`, no `trace_id` (explicit absence); (2) `AuditReadClient(api, tenantId: 'acme', traceId: 'tr-1')` → wire has `tenant_id=acme&trace_id=tr-1` + `limit=100`; per-call override shadows the constructor value; whitespace-only values omitted; (3) source grep pin: no `query: {` map literal in `audit_read_client.dart` (AuditQuery-only construction); (4) surface completeness: `facets()` hits `facetsPath` with the same AuditQuery semantics; `event('a/b')` hits `eventsPath/a%2Fb` with **no** query parameters |
| **AC-3 — ring inertness matrix** | `test/audit_log_tab_test.dart` (seeded ring as AC-1.5, caps **including** the trio) | (a) server success → server rows render, forged row absent everywhere in the tree, `2 entries` is the server page size; (b) server 500 (after ≤3 transport retries) → error state + retry render; forged row **still** absent — ring never a fallback; error text is `error.toString()`; (c) server `{'events': [], 'count': 0}` → `0 entries` + server-truth empty state; forged row absent — server truth wins even when the server has nothing |
| **AC-4 — capability gate, both halves** | `test/audit_log_tab_test.dart` + `test/admin_navigation_test.dart` | (1) *Page half:* pump with `_caps(['/api/v1/admin/endpoints'])` (raw caps, no catalog merge) → not-enabled state renders, MockClient records **zero** requests to any path; (2) *Positive:* `_caps(['/api/v1/audit/events'])` → exactly one request, server rows render (AC-1.4 fixture); (3) *Navigation half + predicate equivalence:* for the same endpoint set, `navigation.supportsAuditLog == navigation.capabilities.has('GET', '/api/v1/audit/events')` across (i) default documented-catalog merge → true; (ii) `AdminNavigationCapabilities(endpoints, documentedEndpoints: const [])` without the trio → **false — inventory without the audit trio hides the tab**; (iii) runtime set explicitly containing the trio → true. Module list offers `AdminModuleId.auditLog` iff `supportsAuditLog` (culling) |
| **AC-5 — wiring + grep gates** | `test/admin_navigation_test.dart` + `test/admin_shell_test.dart` + shell greps | (1) auditLog entry page constructed as `AuditLogTab(api: _api, capabilities: capabilities)` with the dashboard's instances; entry culled when `supportsAuditLog` is false; palette item absent when culled; (2) `grep -n 'const AuditLogTab()' lib/ test/` → **no hits**; `grep -rn '/api/v1/audit' lib/screens/admin/audit_log_tab.dart` → **no hits** (REQ-5) |
| **AC-6 — unchanged suites** | run, don't modify | `test/audit_contract_guard_test.dart` (scans 1–5), `test/admin_governance_security_test.dart`, `test/audit_query_test.dart`, `test/api_contract_test.dart`, `test/api_paths_test.dart`, `test/snaplink_admin_api_test.dart`, `test/sso_client_test.dart`, `test/service_contracts_test.dart`, `test/backend_contract_manifest_test.dart` — green unchanged. Only edited test files: `admin_support_tabs_test.dart` (rework), `admin_navigation_test.dart` + `admin_shell_test.dart` (extensions), `i18n_coverage_test.dart` (**mandatory** anchored `subtitle` scan extension, FM-16); new files: `audit_event_row_test.dart`, `audit_read_client_test.dart`, `audit_log_tab_test.dart` |

## 6. Out of scope (spec §6, enforced)

- B6-1b: `AuditLogService` `kDebugMode` demotion seam, `_recordAudit` removal, debug badges, Clear/CSV relabeling, palette description copy.
- B6-2: `client_id` constant alignment (`sso-admin-console`).
- B4-1 token-claim `tenant_id` parsing; BFF `trace_id` injection; any `bff` literal in `lib/`.
- B1-5 sink-side `audit.event.read` emission (server-side; this repo asserts request issuance only).
- `governance_tab.dart` behavior changes (its `_has` catalog fallback is pinned behavior — REQ-4 deliberately does not copy it).
- Portal (`PortalApi`) audit surface.

## 7. Risks

| Risk | Mitigation |
|---|---|
| No in-repo response schema (E14) | Validated real shape adopted; real-shape-first allowlist + defensive fallbacks; AC-1.4 fixture is real-shaped; acceptance asserts server-derived rows, never an invented schema |
| Tab accidentally re-introduces path literals or hand-built maps | D1/D2 by construction; scan 5 (AC-6) + AC-5.2 grep both fail red |
| Filesize gate (415-425 estimate) | §1.8 decision rule: atomic exemption in the same change as the rework (deterministic; precedent `governance_tab.dart`, `clients_tab.dart`) |
| zh regression on new copy | §1.7 pinned inventory (atomic keys + zh entries, `' on '`-free new keys); zh-parity test; **mandatory** anchored `subtitle` scan extension (FM-16) closes the coverage gap by intent, not by substring accident |
| tenant/trace contract unproven server-side | Dual assertion (default absence / presence-when-provided, AC-1.3/AC-2); never a silent any-params wire; B4-1/BFF documented as the extension point |
| Out-of-order refresh | Generation counter (FM-9) with a dedicated widget test |
| Clear semantics drift into B6-1b territory | Clear unchanged (ring only); §6 boundary |
| `audit_log_tab.dart` exceeded budget → exemption-forgets-to-land | Exemption is part of step 4, same change as the rework — not a follow-up |

## 8. Repository gates (unchanged baselines)

`flutter analyze`; `flutter test` (full); `dart format --set-exit-if-changed`; `checks/` gates (`engineering.yaml`); `test/backend_contract_manifest_test.dart` unaffected (no `docs/backend-contracts.json` edit). Baseline measured green at HEAD (2026-08-07): guard/query/navigation 38 tests, governance/support/contracts 55 tests.
