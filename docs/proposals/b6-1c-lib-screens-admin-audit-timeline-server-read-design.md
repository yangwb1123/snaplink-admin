# B6-1a/c — Design: AuditLogTab wired to the sink read API (module: lib/screens/admin)

> Upstream: `docs/auto/runs/wire-the-audit-timeline-page-to-the-sink-read-ap-cae0b264/artifacts/requirements-10762e10/requirements.md` (B6-1a/c requirements, verified 2026-08-08).
> This design pins the **already-restored pattern** (uncommitted B6-1a/1c work in the working tree) as the module contract. It is not a re-implementation spec: the direction's defect premise is superseded, and the requirements doc re-verified that reality (all `[ALREADY-LANDED]` markers). Every citation below was re-checked against the working tree on 2026-08-08, not taken from the evidence.

## 0. Evidence verification (claims re-checked, not trusted)

| Evidence claim | Verified working-tree reality | Verdict |
|---|---|---|
| `audit_log_tab.dart` ring-only rendering is stale; tab now requires `api`+`capabilities` | `AuditLogTab({super.key, required this.api, required this.capabilities})` at `:15-18`; `_client = AuditReadClient(widget.api)` `:48`; `_refresh()` gates on `widget.capabilities.has('GET', AuditReadClient.eventsPath)` `:68-79` (no catalog fallback), fetches `_client.list(limit: 100)` `:84`; search is client-side `_applyFilter` `:111-128`; ring demoted to `_debugRingBadge` + Clear under `kDebugMode && AuditLogService.ringCopyEnabled` `:293`; `_generation` stale-response guard `:77,:94,:106` | ✅ exact |
| `dashboard_screen.dart:563-566` unconditional `const AuditLogTab()` is stale | Registration is `if (navigation.supportsAuditLog)` at `:559` with `page: AuditLogTab(api: _api, capabilities: capabilities)` at `:567` (sibling of `GovernanceTab(api: _api, capabilities: capabilities)` `:557`). `grep -rn "const AuditLogTab()" lib/ test/` → zero hits | ✅ exact |
| `governance_tab.dart` proven read (`_queryAudit`) | `_auditPath` `:31`, `_facetPath` `:32`; `_queryAudit` `:166-196` — `AuditQuery.fromJson` `:172`, `toQueryParameters()` `:177`, `widget.api.get(_auditPath, query: parameters)` `:183`, facets twin gated `_has('GET', _facetPath)` `:184`, `Future.wait` `:187` | ✅ exact |
| `audit_query.dart` / `snaplink_admin_types.dart:310-312` / `admin_navigation.dart:147` | `AuditQuery` (`lib/api/audit_query.dart`, 174 lines): six fields, `supportedKeys` `:47-55`, `toQueryParameters()` `:116-128`, default wire exactly `{'limit': '100'}`; trio at `snaplink_admin_types.dart:310-312`; `supportsAuditLog => _has('GET', '/api/v1/audit/events')` at `admin_navigation.dart:147` | ✅ exact |
| `snaplink_admin_api.dart:128` `[CORRECTION]` | `get(String path, {Map<String,String>? query, bool forceRefresh})` at `:126-140`; query branch `_request('GET', path, query: query)` at `:134` (bypasses cache — correct for live reads) | ✅ correction confirmed |
| b6-1a design `:184` (F7), `:216` (AC-1); `implementation-gate.md:56` | F7 row = "Timeline never reads the ring → forged rows never render (T-12)"; `:216` = AC-1 row (exact path/query, 2 real-shape events → `2 entries`, no other path, no-leak search); `implementation-gate.md:56` console row 1 = 读路径接入 with T-12 joint | ✅ exact |
| `test/audit_log_tab_test.dart` exists, 572 lines / 15 tests | Confirmed: 572 lines, 15 `testWidgets`. Groups: `AuditLogTab server read (AC-1 / AC-3)` `:108-341`, `FM-9 stale-response race` `:343-412`, `B6-1b debug ring copy surface` `:414-572` | ✅ exact |
| Nav-gating tests | `admin_navigation_test.dart:235-286` (AC-4.3 supportsAuditLog contract, module-list culling); `admin_shell_test.dart:90-124` (AC-5.1 dashboard e2e) | ✅ exact |
| All pinned suites green | `flutter test` on `audit_log_tab_test` + guard + query + event_row + read_client (80 tests) and nav/shell/support/governance (29 tests) → **All tests passed** | ✅ |
| `bff` ban, path-literal inventory, filesize exemption | `grep -rni "bff" lib/` → zero hits; audit path literals in lib only at `audit_read_client.dart` (owner), `governance_tab.dart:31-32` (first consumer), `admin_live_events_tab.dart:167` ({id} detail, scan-exempt), `snaplink_admin_types.dart:310-312` (doc trio), `admin_operations_tab.dart` grouping prefix; `audit_log_tab.dart` (523 lines) already in `engineering.yaml` filesize exemptions (uncommitted `:41`) | ✅ |

**Net verdict:** the evidence is accurate. No uncited dependency, no missing symbol, no failing assertion. The design below therefore defines the *contract to preserve* and the *landing procedure*, not new code.

## 1. API changes (landed state = contract)

All of the following exist in the working tree (uncommitted). They are pinned here as the module contract; any future change must preserve the signatures and semantics, not merely compile.

### 1.1 `AuditLogTab` — constructor-injected (REQ-1)
```dart
const AuditLogTab({super.key, required this.api, required this.capabilities});
```
- `api: SnaplinkAdminApi` — all data access goes through `widget.api`; no global/static client.
- `capabilities: SnaplinkAdminCapabilities` — the gate source of truth; **no documented-catalog fallback** (differs from `governance_tab.dart`'s `_has` helper by design, defense in depth).
- Zero `const AuditLogTab()` call sites allowed in `lib/` or `test/` (grep gate, AC-4c).

### 1.2 `AuditReadClient` — new typed read client (`lib/api/audit_read_client.dart`, 88 lines)
- Single owner of the trio path literals: `eventsPath = '/api/v1/audit/events'`, `facetsPath = '/api/v1/audit/facets'`, `eventDetailPath = '/api/v1/audit/events/{id}'`.
- `list({int limit = 100, String? cursor, String? eventTypes, String? outcome, String? tenantId, String? traceId}) → Future<List<AuditEventRow>>` — query construction exclusively via `AuditQuery` (guard scan 5); wire for the default call is exactly `{'limit': '100'}`; `tenant_id`/`trace_id` omitted unless non-empty after trim (B4-1/BFF leg `[PROPOSED]`, never derived client-side).
- `facets(...)` pass-through (no consumer in this direction); `event(id)` mirrors the live-events `Uri.encodeComponent` split-literal precedent.

### 1.3 `AuditQuery` — typed query builder (`lib/api/audit_query.dart`, 174 lines)
- Six fields with pinned wire keys: `limit`, `tenant_id`, `trace_id`, `cursor`, `event_type`, `outcome` (`supportedKeys` `:47-55`, pinned by guard AC-3.4 + `test/audit_query_test.dart`).
- `fromJson` is the governance-tab parse path: strict (unknown key / non-scalar → `AuditQueryParseException`, error banner, zero requests).
- `toQueryParameters()`: `limit` via `'$limit'` coercion; strings contribute trimmed value iff non-empty. All-null → empty map.
- Presence/absence semantics are load-bearing: **absence of `tenant_id`/`trace_id` on the wire is the AC-1 assertion**, not a convenience.

### 1.4 `AuditEventRow` + `auditEventRowsFromResponse` (`lib/api/audit_event_row.dart`, 149 lines)
- Seven-field allowlist `{id, type, outcome, timestamp, actor_id, client_id, tenant_id}`; every other server field dropped at row construction (redact-first via `SensitiveData.redact`).
- Invariants (unit-pinned): N input elements → exactly N rows; fallback rows always `outcome == ''` (never fabricated success/failure); never throws; `{}`/`{'events': []}` → zero rows (server truth wins even when the server has nothing).

### 1.5 `AdminNavigationCapabilities.supportsAuditLog` (`admin_navigation.dart:147`)
- `bool get supportsAuditLog => _has('GET', '/api/v1/audit/events');` — same predicate as the tab gate by construction (S13); module-list culling (`adminNavigationModules`) and command-palette culling (`_visibleModules`) follow automatically. `admin_navigation.dart:41` `auditLog = 'audit-log'`.

### 1.6 No API change
- `SnaplinkAdminApi.get` unchanged (signature at `:126-140`); the audit consumer passes `query:` so the cache-bypass branch runs.
- `AuditLogService` public API untouched (B6-1b owns the ring seam); its only remaining surface is the debug badge/Clear under `kDebugMode && AuditLogService.ringCopyEnabled`.
- `GovernanceTab` untouched (first consumer of the trio; facets stay governance-tab scope).

## 2. Compatibility constraints

| # | Constraint | Enforcement |
|---|---|---|
| C1 | Wire must be exactly `GET /api/v1/audit/events` with `queryParameters == {'limit': '100'}` from `AuditLogTab`; `tenant_id`/`trace_id` keys **absent** | AC-1 (`requests.single.queryParameters` equality), guard scan 5 (hand-built `query:` map trips), AC-2 (every re-query identical) |
| C2 | No catalog fallback in the tab gate — injected `capabilities` alone decide; gate-off ⇒ **zero requests** | AC-4.1 (MockClient hit count == 0) |
| C3 | No `bff` literal anywhere in `lib/`; only the documented trio is callable; no fourth audit path, no non-GET trio method | Guard AC-3.2 (case-insensitive whole-file), AC-3.1 (trio-normalized literal scan), AC-3.3 (catalog trio) |
| C4 | `AuditQuery` mandatory for audit consumers (no `MapEntry(key, '$value')` stringification anywhere in `lib/`); `AuditReadClient` is the single path-literal owner | Guard AC-3.4 (whitespace-tolerant scan + positive pins), scan 5, AC-3.1 |
| C5 | Header count = served page size (`_rows.length`), never a response `count` field | AC-1 decoy `count: 999` never renders |
| C6 | Ring rows are never evidence: success, error, *and empty-server* cases keep forged rows out of the tree | AC-3 sub-cases (1)(2)(3); debug surface only under `kDebugMode && ringCopyEnabled` |
| C7 | Filesize budget: `audit_log_tab.dart` (523 lines) is exempted — entry exists in `engineering.yaml:41` (uncommitted); `audit_event_row.dart` (149), `audit_query.dart` (174), `audit_read_client.dart` (88) all ≤ 400 — no new exemption | `python cli.py harness` filesize check |
| C8 | Search/filter never alter the wire (limit-only surface = S10 transport-level leak bound) | AC-2: search terms absent from every URI/query/body |
| C9 | i18n: ring-scoped copy ("Debug records" / "local debug records") must not be relabelable to server truth; zh exact-key resolution | B6-1b test group (5 keys, zh atomic), `test/i18n_coverage_test.dart` |

## 3. Failure modes

| # | Failure | Behavior (pinned) | Test pin |
|---|---|---|---|
| FM-1 | Gate off (capability missing) | Not-enabled state ("This feature is not enabled on the connected replica."), zero requests, in-flight fetch invalidated via `_generation++` (stale response can never commit over not-enabled) | AC-4.1 (`:308-324`) |
| FM-2 | Server 500 / transport error | Error state + Retry; renders `error.toString()` only (never raw payload / `data`); ring still inert | AC-3 (2) (`:247-285`) |
| FM-3 | Empty server result (`{'events': [], 'count': 0}` or `{}`) | `0 entries` + server-truth empty state; forged ring rows still absent | AC-3 (3) (`:286-306`) |
| FM-4 | Stale-response race (rapid refresh) | Generation guard: only newest fetch commits (`gen != _generation` check after await, `mounted` insufficient alone) | FM-9 group (`:343-412`) |
| FM-5 | Stale cache | `widget.api.skipCache()` before fetch; `query:` branch bypasses cache entirely | AC-1 (fresh request per refresh) |
| FM-6 | Malformed/unexpected response shape | `auditEventRowsFromResponse` never throws, never drops records: redact-first → list extraction (`events`/`items`/`results`/`data`/`entries`) → `is`-only reads → per-row fallbacks (`outcome == ''`, type fallback `'audit event'`, null timestamp `--` sorts last) | `test/audit_event_row_test.dart` unit matrix |
| FM-7 | Ring forgery (devtools-seeded records) | Timeline never reads the ring; badge-only surface; forged rows never render in any server state | AC-3 all sub-cases + `AC-3 joint` (`:551`) |
| FM-8 | `count` decoy / page-size confusion | Header shows `_rows.length`; decoy `count: 999` never renders | AC-1 (`:109-177`) |
| FM-9 | Search-term leak | Every request keeps `{'limit': '100'}`; terms only in `_applyFilter` | AC-2 (`:157-175`) |
| FM-10 | BFF leg absent | `tenant_id`/`trace_id` omitted by default; nothing invents them; guard bans `bff` literals (a future B4-1 injection is pass-through-only, trim-only) | AC-1 absent-keys assertion; guard AC-3.2 |

## 4. Migration steps

The B6-1a/1c work is uncommitted in the working tree (B6-1a/1c files + `engineering.yaml` exemption + guard/mutation tests). Landing procedure:

1. **Gate the tree**: `python cli.py harness` (filesize + complexity + b6_1b_gates) — expected green; `flutter analyze` clean.
2. **Run the pinned suites** (must be all-green before commit; this is the AC-5 regression floor):
   - `flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/audit_read_client_test.dart test/audit_query_test.dart test/audit_event_row_test.dart`
   - `flutter test test/admin_navigation_test.dart test/admin_shell_test.dart test/admin_support_tabs_test.dart test/admin_governance_security_test.dart test/admin_live_events_detail_read_test.dart test/snaplink_admin_api_test.dart`
3. **Commit the filesize exemption with the tab, not separately** — `engineering.yaml:41` (`audit_log_tab.dart` under `filesize.exemptions`) is required for the harness to stay green; a commit that lands the 523-line tab without the exemption fails the gate deterministically.
4. **Commit grouping** (per repo convention): (a) contract layer — `lib/api/audit_query.dart`, `lib/api/audit_event_row.dart`, `lib/api/audit_read_client.dart` + their tests; (b) consumer layer — `lib/screens/admin/audit_log_tab.dart`, `dashboard_screen.dart`, `admin_navigation.dart`, i18n catalogs + `audit_log_tab_test.dart`/nav/shell tests; (c) guard layer — `test/audit_contract_guard_*.dart` + `engineering.yaml`. Each layer independently green.
5. **Release-artifact check** (B6-1b joint): `make release-artifact-check` after `make build-prod` — `sso_audit_log` absent from `build/web` (release ring inertness by const-folded `kDebugMode` guard).
6. **Rollback**: single-commit revert of the consumer layer restores pre-B6-1a behavior; no data migration, no server change, no storage schema change (pure-frontend convention).

**Future-change guardrails** (how the contract survives later edits):
- Any new audit UI (filters, pagination) must map its params (`eventTypes → type`, `cursor → offset`) in its own layer — `AuditQuery`/`AuditReadClient` untouched; a hand-built `query:` map in a consumer file trips scan 5.
- Any new audit path literal in `lib/` trips AC-3.1; any `bff` mention trips AC-3.2.
- Moving `AuditLogTab` to a different constructor shape breaks every call site at compile time AND the grep gate (AC-4c) — both must stay green.
- A typed `FacetResult` becomes groundable only when a filter UI consumer lands; until then `facets()` stays pass-through.

## 5. Testable acceptance mapping

| AC (requirements) | Test file + location | Concrete assertions (all currently green) |
|---|---|---|
| AC-1 — server-read wire + rendering joint (T-12) | `test/audit_log_tab_test.dart:108-177` | MockClient records exactly one request: `path == '/api/v1/audit/events'`, `queryParameters == {'limit': '100'}` exactly, `tenant_id`/`trace_id` keys absent, no other path; 2 real-shape events → `'2 entries'` + `admin_client_created` renders; decoy `count: 999` never renders; `'on this device'` absent; seeded forged ring entry absent |
| AC-2 — no-leak boundary (S10) | `test/audit_log_tab_test.dart:157-175` | After `enterText('admin_client')`: request count 2, every request `queryParameters == {'limit': '100'}`; filtered view shows `admin_client_created`, hides `admin_user_deleted` |
| AC-3 — forged ring never evidence (F7/T-12) | `test/audit_log_tab_test.dart:109-177` (success), `:247-285` (500), `:286-306` (empty), `:551` (joint) | `_seedForgedRing()` before pump; `find.textContaining('/api/v1/admin/forged')` and `'forged entry'` findsNothing in all three server states; error state + Retry render on 500; `0 entries` on empty |
| AC-4 — capability gate + wiring | (a) `test/admin_navigation_test.dart:235-286`; (b) `test/admin_shell_test.dart:90-124`; (c) grep gate | (a) `supportsAuditLog` true with documented catalog / explicit runtime endpoint, false with `documentedEndpoints: const []`; module list contains `AdminModuleId.auditLog` iff supported; (b) dashboard e2e: System → Audit Log navigates, page built with dashboard `_api` + merged capabilities, real fetch issued; (c) `grep -rn "const AuditLogTab()" lib/ test/` → zero hits |
| AC-4.1/4.2 — tab-level gate | `test/audit_log_tab_test.dart:308-341` | Trio-less caps → not-enabled, MockClient audit hit count == 0; positive caps → exactly one request + rows |
| AC-5 — regression floor | All suites in §4 step 2 + `test/i18n_coverage_test.dart` | All pass; `flutter analyze` clean; no `/api/v1/audit/facets` request from `AuditLogTab` (facets stay governance-tab scope); guard scans AC-3.1–3.4 + scan 5 green (structural trip on any hand-built query map, new path literal, `bff` literal, or `'$value'` stringification) |

## 6. Out of scope / open items

- **B6-1b** (ring storage seam, `ringCopyEnabled`, Clear/CSV debug relabeling): sibling direction, landed separately; this design only pins the debug-only surface.
- **B6-2** `client_id` alignment; **B4-1/BFF** `tenant_id` claim parsing + BFF `trace_id` injection (`[PROPOSED]`, never faked client-side — AC-1's absent-keys assertion is the canary); **B1-5** sink self-audit emission (console asserts request issuance only; the B6-1a integration canary `tests/integration/audit_self_audit_drill.py` FAILs loud when B1-5 is absent — no false PASS in this repo's scope).
- Facets UI / typed `FacetResult`; response-model changes; any new audit endpoint.
- **Open**: the uncommitted work needs a reviewer pass against this contract before landing (the requirements run's `cae0b264` artifacts vs. the memory-index `78d3cac1` run of the same direction title — the requirements doc cited here is the `cae0b264` copy; both exist under `docs/auto/runs/` with identical content, verified).
