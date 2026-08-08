# B6-1a — Requirements Specification: close the audit read-client contract gap (module: lib/screens/device)

> Direction: "B6-1a: close the audit read-client contract gap — the timeline tab (`lib/screens/admin/audit_log_tab.dart`) still renders the localStorage ring and is registered with no server client, while the contract-named read path `lib/api/portal_api.dart` has zero audit surface" (`docs/auto/analyses/lib-screens-device-fb030ae1.json`).
> Value 9 · Risk reduction 8 · Effort 6 · Confidence 8.
>
> **Revision 1 (2026-08-08).** Every citation below was re-verified against the current working tree, not the tree the analysis was cut from. The repo has moved since the analysis: the read client, row model, guard suite, capability getter, dashboard wiring, i18n copy, ring debug-flag, and the timeline widget tests have all landed — the one unconverted piece is `lib/screens/admin/audit_log_tab.dart` itself. Drift from the direction's citations is marked `[CORRECTION]`; landed-but-uncompiled callers are marked `[WORKING-TREE]`.

## 1. Problem statement (verified against the current working tree)

`lib/screens/admin/audit_log_tab.dart` is the **only** unconverted piece of the B6-1 read path. It still:

- constructs `AuditLogService()` at `:23` (the localStorage ring, key `sso_audit_log` at `audit_log_service.dart:66`);
- reads the ring for every surface: `_refresh` filters `_logService.entries` at `:43`, header `{count} entries` at `:161`, `_errorRate` at `:130`;
- renders the device-scoped subtitle `'All authentication and administrative events recorded on this device.'` at `:158` (display truth = local device, which is exactly what T-12 forbids: `devtools 伪造不再构成证据`);
- ships a destructive `Clear log` action (`delete_sweep` at `:178`, `ConfirmDialog` `'Clear audit log?'` at `:183-191`);
- declares `const AuditLogTab({super.key})` at `:15-16` — no `api`, no `capabilities` — so the **current working tree fails to compile**: 32 analyzer errors from callers/tests that already use the new constructor shape (`dashboard_screen.dart:567`, `test/audit_log_tab_test.dart`, `test/admin_support_tabs_test.dart`). `[WORKING-TREE]`

Everything the rewrite needs already exists in the tree:

| Landed piece | Location | State |
|---|---|---|
| Typed read client (trio literals, `list()` builds wire exclusively via `AuditQuery`; optional `tenantId`/`traceId` constructor params, never derived/hardcoded) | `lib/api/audit_read_client.dart` (new) | ✅ |
| Typed row model + defensive, never-throwing, redact-first mapper (7-field allowlist) | `lib/api/audit_event_row.dart` (new) | ✅ |
| `AuditQuery.toQueryParameters()` — emits `limit` + `tenant_id`/`trace_id`/`cursor`/`event_type`/`outcome` iff non-empty after trim; default wire exactly `{'limit':'100'}` | `lib/api/audit_query.dart:148-165` | ✅ |
| Timeline widget tests: server-read AC-1/AC-3 (exactly-one-request, seeded-ring inert, capability gate, zh locale, F5 scrub, FM-9 race, B6-1b debug surface) | `test/audit_log_tab_test.dart` (638 lines, new) | ✅ (red until the rewrite) |
| Dashboard wiring `page: AuditLogTab(api: _api, capabilities: capabilities)` inside `if (navigation.supportsAuditLog)` | `dashboard_screen.dart:559,567` | ✅ `[CORRECTION]` — direction cited `:566 const AuditLogTab()` |
| `supportsAuditLog` getter (`_has('GET', AuditReadClient.eventsPath)`) + nav culling pin | `admin_navigation.dart:148`; `test/admin_navigation_test.dart` AC-4.3 | ✅ |
| Ring debug-only copy gate (`ringCopyEnabled` const-folded to `false` in release; debug-only Clear label) | `audit_log_service.dart:68-86` (B6-1b) | ✅ |
| Server-sourced i18n copy (en + zh, atomic): subtitle `'All authentication and administrative events recorded by the server.'` → `'服务器记录的全部认证与管理事件。'`; empty state `'No audit events returned by the server yet.'` → `'服务器尚未返回审计事件。'` | `app_strings_source_admin_core.dart`, `app_strings_source_admin_features.dart` | ✅ |
| Contract guard suite (audit-path literals, `bff` ban, catalog trio, scan-5 second-consumer, trio-literal ownership, raw-stringification) | `test/audit_contract_guard_scans.dart` (560 lines), `test/audit_contract_guard_test.dart`, `test/audit_contract_guard_mutation_test.dart` | ✅ |

The contract-named path `lib/api/portal_api.dart` still has **zero** audit surface (`grep -in audit` → 0 hits; only `/me`, `/sessions/me`, `/consents/me`, `/roles/me`, `/permissions/me`, `/menus/me`, `/me/notifications/stream`, `/logout`). The scope doubt is recorded in the contract's own REFUSAL-CHECK deliverable (`audit-contract-batch-snaplink-console.md:6` `[PROPOSED]`; `:1` `REFUSAL-CHECK: OK`). The device module precedent the direction cites is exact: `lib/screens/device/device_verify_api.dart` is a pure re-export shim of `lib/api/device_verify_api.dart` — the actual client surface lives in `lib/api`, and so does the audit read surface (`lib/api/audit_read_client.dart`). `lib/screens/device/` itself remains untouched (zero ring references; `test/device_audit_visibility_guard_test.dart` pins the floor).

## 2. Evidence verification table (direction citations re-checked)

| # | Citation from direction | Verified working-tree reality | Status |
|---|---|---|---|
| E1 | `audit_log_tab.dart:29-32,40-52` (initState/_refresh read ring; 'recorded on this device' subtitle; clear-log UI) | `AuditLogService()` constructed at `:23` (not `:29`); `initState` `:34-38`; `_refresh` reads `_logService.entries` at `:43`; subtitle at `:158`; Clear-log dialog at `:183-191`. | ✅ `[CORRECTION: line drift]` |
| E2 | `dashboard_screen.dart:566` (`page: const AuditLogTab()` — no SnaplinkAdminApi injected) | **Stale.** Working tree `:567` is `page: AuditLogTab(api: _api, capabilities: capabilities)` wrapped in `if (navigation.supportsAuditLog)` at `:559` — the wiring landed; only `audit_log_tab.dart`'s constructor is unconverted (32 analyzer errors). | ❌ `[CORRECTION]` |
| E3 | `governance_tab.dart:18-33,167-190` (capability-injected server-read precedent) | Constructor `api`/`capabilities` at `:18-33` exact; `_queryAudit` at `:167-190` performs `widget.api.get(_auditPath, query: parameters)` where `_auditPath = AuditReadClient.eventsPath` and `parameters = AuditQuery.fromJson(...).toQueryParameters()` — now routed through the read client's constants. | ✅ |
| E4 | `lib/api/portal_api.dart` (whole file: no audit method) | `grep -in audit lib/api/portal_api.dart` → 0 hits. | ✅ |
| E5 | `snaplink_admin_types.dart:310-312` (documented trio) | Exact: `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}`. | ✅ |
| E6 | `lib/api/audit_query.dart` (toQueryParameters emits tenant_id/trace_id/limit/cursor/event_type/outcome) | `:148-165` exact; presence iff non-null/non-empty-after-trim; default wire exactly `{'limit':'100'}` (pinned by `test/audit_query_test.dart` and `test/audit_read_client_test.dart` first test). | ✅ |
| E7 | `lib/screens/device/device_verify_api.dart` (re-export shim of `lib/api/device_verify_api.dart`) | Exact — 3-line pure `export` shim. | ✅ |
| E8 | `docs/campaigns/implementation-gate.md:56` (B6-1 acceptance: ring debug-only, server records displayed, T-12 joint) | Console row 1 at `:56`: 读路径接入 (F-06), `localStorage ring 降级为调试记录`, `T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据`. Sink-side `audit.event.read` emission is B1-5 (`:47`). | ✅ |
| E9 | `[proposed]` tenant_id source (B4-1) and trace_id BFF injection absent; must be wired/injected at the edge, else omitted | Confirmed: no claim parsing in `lib/`; `AuditReadClient` constructor accepts optional `tenantId`/`traceId` and omits them from the wire unless non-empty; contract doc `:9` marks both `[PROPOSED]` (direction cited `:10` — the block is at `:6-9`). **This direction's AC-1 present-branch is only satisfiable by edge injection at the tab constructor** (REQ-2). | ✅ `[CORRECTION: :10→:9]` |
| E10 | Ring writer `snaplink_admin_api.dart:81-85` (single debug writer) | `_recordAudit` at `:81-85`, sole call site `:324` (non-GET 2xx). The GET read path adds zero ring writes. B6-1b's `ringCopyEnabled` flag landed in `audit_log_service.dart:68-86`; the writer itself is not demoted (B6-1b). | ✅ |
| E11 | REFUSAL-CHECK scope record | `audit-contract-batch-snaplink-console.md:1` `REFUSAL-CHECK: OK`; `:6` portal_api scope `[PROPOSED]`; `:9` tenant_id/trace_id `[PROPOSED]`. | ✅ `[CORRECTION: :10→:6/:9]` |

## 3. Requirements

### REQ-1 — Server read is the only timeline data source (the rewrite)
`lib/screens/admin/audit_log_tab.dart` must be rewritten so that:
- the constructor becomes `const AuditLogTab({super.key, required SnaplinkAdminApi api, required SnaplinkAdminCapabilities capabilities, String? tenantId, String? traceId})` — same `api`/`capabilities` shape as `GovernanceTab` (`governance_tab.dart:18-33`); the tab must not construct its own API client, capability set, or `AuditLogService` for the timeline;
- `initState`/`_refresh` issue the read via `AuditReadClient(widget.api, tenantId: widget.tenantId, traceId: widget.traceId).list(limit: 100)` — the sole sanctioned path (scan-5 green, trio literals stay in the read client);
- header count, error-rate badge, table rows, CSV export, empty state, and subtitle all derive from the **server response only**; the subtitle uses the landed key `'All authentication and administrative events recorded by the server.'` (`app_strings_source_admin_core.dart`), the empty state the landed key `'No audit events returned by the server yet.'` (`app_strings_source_admin_features.dart`);
- the destructive `Clear log` action becomes the landed B6-1b debug-only surface (`AuditLogService.ringCopyEnabled`-gated `'Clear local debug records'`, debug marker chip) — never a release-reachable destructive action on server truth.

### REQ-2 — tenant_id/trace_id ride the wire when injected at the edge (present-or-absent, never silent)
The direction's acceptance requires the timeline query to carry `tenant_id` and `trace_id` keys. No claim parsing (B4-1) and no BFF trace_id injection exist in-repo (E9), so the **only in-scope mechanism is constructor-level injection** — the direction's own words: "they must be wired or injected at the edge". Hence:
- the tab accepts optional `tenantId`/`traceId` and forwards them verbatim into `AuditReadClient` (which serializes through `AuditQuery`); values are trimmed, never derived, never hardcoded, never defaulted;
- with context absent (the current `dashboard_screen.dart:567` wiring, and every existing test pump), the wire stays exactly `{'limit':'100'}` — no tenant, no trace (pinned by the landed tests);
- any future claim-parsing/BFF mechanism is B4-1/out-of-scope; this spec only guarantees the forwarding seam exists and is exercised by the test present-branch.

### REQ-3 — AuditQuery-mandated wire; guard suite stays green
The rewritten consumer constructs query parameters exclusively through `AuditQuery`/`AuditReadClient` (scan 5 `second-consumer`, `test/audit_contract_guard_test.dart:165-226`, trips on hand-built `query: {'limit': ...}` maps); the audit trio path literals stay owned by `AuditReadClient` (`trio-literal-owner` scan); no `bff` literal may enter `lib/` (`bff-literals` scan); no fourth audit path and no non-GET method may be added (`catalog-trio` scan). The existing `{id}` detail reader (`admin_live_events_tab.dart:167`) is untouched.

### REQ-4 — Capability gate preserved (page + navigation)
- Page gate: the tab issues the read iff `widget.capabilities.has('GET', AuditReadClient.eventsPath)`; without it, a not-enabled state renders and **zero** requests are issued. Must not copy `governance_tab.dart` `_has`'s catalog fallback.
- Navigation gate: `supportsAuditLog` (`admin_navigation.dart:148`) + `if (navigation.supportsAuditLog)` culling in `dashboard_screen.dart:559` — already landed; the rewrite must keep them intact (pinned by `test/admin_navigation_test.dart` AC-4.3).

### REQ-5 — Ring isolation floor
- The timeline render path must contain no ring read: no `AuditLogService` reference for rendering, no `LocalStorage`/`sso_audit_log` access in `audit_log_tab.dart` (grep-level check, AC-2);
- the ring keeps its single debug writer `_recordAudit` (`snaplink_admin_api.dart:81-85`, call `:324`) — no new writer, no read path;
- `lib/screens/device/` stays zero-touch (guard `test/device_audit_visibility_guard_test.dart` stays green).

### REQ-6 — T-12 joint drill: the read query triggers the caller's own `audit.event.read`
The drill harness (`tests/integration/audit_login_drill.py`, wired at `tests/integration/run_all.py:169` and `tests/integration/full_stack_verify.py:113`) gains a read leg: with an admin bearer token + `tenant_id` (from JWT claims, `audit_login_drill.py:146-148`), issue the console-shaped query `GET /api/v1/audit/events?tenant_id=<t>&limit=100`, then re-query and assert an `audit.event.read` row attributed to the caller appears (implementation-gate.md:56 T-12; sink-side emission is B1-5). If the row is unobserved (B1-5 not deployed), the leg records the deviation and marks itself `[PROPOSED]` — exit 0 with explicit deviation, **never a false PASS** (mirror of the B6-2 branch pattern in the same file). Console-side, request issuance is pinned by AC-1; the self-audit row itself is sink-side and cannot be asserted from this repo.

## 4. Acceptance checks (the four supplied checks, preserved and made testable)

**AC-1 — supplied check (1) → widget test (`test/audit_log_tab_test.dart`, MockClient):**
1. *Absent-branch (default, already written):* pump `AuditLogTab(api: api, capabilities: caps)` with a recording MockClient → exactly one request to `GET /api/v1/audit/events` (single pump, no interaction), query exactly `{'limit':'100'}` (no `tenant_id`, no `trace_id`), rows rendered from the mock server body — the seeded ring entry (`AuditLogService().record`, key `sso_audit_log`) appears nowhere in the tree (`find.textContaining('/api/v1/admin/forged')` → nothing).
2. *Present-branch (mandatory addition):* pump `AuditLogTab(api: api, capabilities: caps, tenantId: 'acme', traceId: 'tr-1')` → exactly one request to `GET /api/v1/audit/events` whose query **contains `tenant_id` and `trace_id` keys** with the injected values (plus `limit`) — AuditQuery serialization end-to-end from the timeline; rendered rows still come from the mock server body, no local `AuditEntry` source.
3. Both branches assert request accounting (no `/api/v1/audit/facets`, no `/api/v1/audit/events/{id}`) and server-sourced copy (subtitle has no "on this device").

**AC-2 — supplied check (2) → ring not read by the render path, single debug writer:**
- `grep -n "LocalStorage" lib/screens/admin/audit_log_tab.dart` → no hits; `grep -n "sso_audit_log" lib/screens/admin/audit_log_tab.dart` → no hits; `grep -n "AuditLogService" lib/screens/admin/audit_log_tab.dart` → confined to the B6-1b debug surface only;
- writer census: `grep -rn "_recordAudit" lib/` → declaration `lib/api/snaplink_admin_api.dart:81` + sole call `:324` only;
- `flutter test test/audit_contract_guard_test.dart` green (scan 5, trio-ownership, bff ban, catalog trio) and `flutter test test/device_audit_visibility_guard_test.dart` green (device module untouched).

**AC-3 — supplied check (3) → devtools-forged entries cannot render (forgery ≠ evidence):**
Seeded-ring widget sub-cases (already written in `test/audit_log_tab_test.dart`, must be green after the rewrite): server success / server 500 (error state, ring still inert, never a fallback) / server empty (`{'events': [], 'count': 0}` → `0 entries` + server-truth empty state, forged row still absent). Server truth wins even when the server has nothing.

**AC-4 — supplied check (4) → drill: the query triggers the caller's own `audit.event.read` self-audit row:**
Run `python3 tests/integration/audit_login_drill.py` (wired at `run_all.py:169`, `full_stack_verify.py:113`) against a deployed stack: the read leg's query triggers an `audit.event.read` row attributed to the caller via the sink read (T-12, implementation-gate.md:56). Until B1-5 is deployed: the drill output records the deviation and marks the leg `[PROPOSED]` — no false PASS. Console-side request issuance is pinned by AC-1 (this repo asserts the request, not the sink row).

**Gate:** after the rewrite, `flutter analyze` clean (the current 32 errors are the unconverted constructor) and the full B6-1 joint green: `flutter test test/audit_log_tab_test.dart test/audit_read_client_test.dart test/audit_event_row_test.dart test/audit_query_test.dart test/audit_contract_guard_test.dart test/admin_navigation_test.dart test/admin_support_tabs_test.dart`.

## 5. Carrier decision record (recorded, not guessed)

- **Carrier:** `SnaplinkAdminApi` + `lib/api/audit_read_client.dart` — the actual path (device-module precedent: `lib/screens/device/device_verify_api.dart` is a pure re-export shim of `lib/api/device_verify_api.dart`; the audit read surface likewise lives in `lib/api`). `lib/api/portal_api.dart` (BFF, contract-named) remains `[PROPOSED]` per `audit-contract-batch-snaplink-console.md:6` — it is a portal-only client with zero audit surface (E4), and the `bff-literals` guard bans `bff` in `lib/`.
- **tenant_id/trace_id:** edge-injected constructor seam (REQ-2), present-or-absent explicit branches in AC-1 — never derived, never hardcoded, never silent. B4-1 claim parsing and BFF trace_id injection stay out of scope.
- **Sink-side self-audit:** `audit.event.read` emission is B1-5 (implementation-gate.md:47) — the drill leg (AC-4) is the honest joint; no in-repo assertion of the sink row.

## 6. Out of scope (explicitly not covered)

- B6-1b: demoting the `_recordAudit` writer itself, release bundle surgery beyond the landed `ringCopyEnabled` gate, palette description copy.
- B6-2: `client_id` alignment (`sso-admin-console`), `auth.login.success` emission census, redirect-leg work (landed in `test/entry_ux_test.dart`).
- B4-1 token-claim parsing for `tenant_id`; BFF `trace_id` injection; nginx split-routing.
- B1-5 sink-side `audit.event.read` emission; any sink/IdP change.
- `lib/screens/device/` production changes — zero-touch by design (guard-pinned).
- `PortalApi` — no audit method may be added here (BFF `[PROPOSED]`).

## 7. Risks

| Risk | Mitigation |
|---|---|
| Working tree currently red (32 analyzer errors: callers/tests already use the new constructor; `audit_log_tab.dart` unconverted) | The rewrite lands atomically with the landed tests; `flutter analyze` clean is the gate. The lib change is the direction's core gap, not collateral. |
| AC-1 present-branch could drift into inventing B4-1 claim parsing | REQ-2 pins injection-only forwarding (trim, never derive/hardcode); the absent-branch test asserts the default wire is untouched. |
| Guard scans are behavioral contracts; a hand-built query map or raw trio literal in the rewritten tab trips them | REQ-3: read via `AuditReadClient` + `AuditQuery` only; scan-5/trio-ownership tests green are part of the gate. |
| T-12 drill false-PASS without a deployed B1-5 sink | AC-4 hard-requires the `[PROPOSED]` deviation branch — no false PASS (B6-2 precedent in the same drill file). |
| Regression of the landed B6-1b debug surface (Clear/CSV relabeling) or i18n atomicity during the rewrite | `test/audit_log_tab_test.dart` B6-1b group + `test/admin_support_tabs_test.dart` + `test/i18n_coverage_test.dart` stay green; the rewrite consumes the landed keys verbatim. |
