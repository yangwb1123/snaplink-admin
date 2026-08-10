# B6-1c — Requirements Specification: Typed audit read contract (AuditQuery) with tenant_id/trace_id correlation (module: lib/screens/admin)

> Source direction: `Add typed audit read contract with tenant_id/trace_id correlation and a real BFF-facing path definition` (from `docs/auto/analyses/lib-screens-admin-4276368d.json`, direction 2).
> All file/line citations below were re-verified against the repository on 2026-08-07. Corrections to the source citation are marked `[CORRECTION]`.

## 1. Problem statement (verified)

The only sink-read call in this repo is a raw JSON query text field in `lib/screens/admin/governance_tab.dart:32` (`_auditQuery`, default `'{"limit": 100}'`). `_queryAudit` (`governance_tab.dart:166-181`) parses that text with `_json(...)` (:167), stringifies every entry with `query.map((key, value) => MapEntry(key, '$value'))` (:169), and passes the result unvalidated as query parameters to `widget.api.get(_auditPath, query: parameters)` (:175) and — when capability-gated — to `_facetPath` (:176-177). Tenant scoping (`tenant_id` from token/claim per the contract) and `trace_id` propagation (BFF-injected per the B6 spec) are nowhere represented:

- `lib/api/portal_api.dart` contains **no audit methods** (verified: only `/me`, `/sessions/me`, `/consents/me`, `/roles/me`, `/permissions/me`, `/menus/me`, `/me/notifications/stream`, `/logout`).
- No BFF layer and no `trace_id` request plumbing exist in this repo (the only `trace_id` reference is a **response** field read at `lib/api/setup_api.dart:215`). The BFF path definition is `[PROPOSED]` (`docs/proposals/audit-contract-batch-snaplink-console.md:9`: `trace_id（BFF 注入机制本仓无）`) and must **not** be invented as an interface.
- `SnaplinkAdminApi.get(path, {query, forceRefresh})` already accepts typed `Map<String, String>? query` (`snaplink_admin_api.dart:126`), so a typed client-side query builder can be added without guessing server contracts.

The direction's deliverable is the typed query builder (the client-side audit read contract) plus migration of the raw-JSON path through it, with `tenant_id`/`trace_id` first-class fields that serialize only when present — and a guard that no repository code invents BFF endpoints.

## 2. Evidence verification table

| # | Citation from direction | Verified repository reality | Status |
|---|---|---|---|
| E1 | `governance_tab.dart:30-32` (`_auditPath`/`_facetPath`/`_auditQuery` default `'{"limit": 100}'`) | Line 30 `static const _auditPath = '/api/v1/audit/events';`, line 31 `_facetPath = '/api/v1/audit/facets';`, line 32 `final _auditQuery = TextEditingController(text: '{"limit": 100}');` — exact. | ✅ |
| E2 | `governance_tab.dart:167-176` (raw JSON passed unvalidated as query params) | Line 166 `_queryAudit()`, 167 `_json(_auditQuery.text, 'Audit query')`, 169 `query.map((key, value) => MapEntry(key, '$value'))`, 175 `widget.api.get(_auditPath, query: parameters)`, 176-177 facets twin (gated by `_has('GET', _facetPath)` at :176). Exact. | ✅ |
| E3 | `portal_api.dart` (no audit methods; full-file review) | Confirmed. Paths used: `/me` (:245, :271), `/sessions/me`, `/consents/me`, `/roles/me`, `/permissions/me`, `/menus/me` (via `fetchListOrEmpty`, :282), `/me/notifications/stream` (:125), `/logout` (:268). No audit path, no query-param support on any method. | ✅ |
| E4 | `snaplink_admin_api.dart:89-91` (typed query params) | `[CORRECTION]` lines 89-91 are the tail of `_recordAudit`. The typed signature is `Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool forceRefresh = false})` at **line 126** (query forwarded at :134). Substantive claim verified. | ✅ (line 126, not 89-91) |
| E5 | `usage_analytics_tab.dart:300` (tenant_id extraction) | Line 300 `(tenants[index] as Map)['tenant_id']?.toString()` — extraction of `tenant_id` from a response map (display path). Not claim parsing; confirms `tenant_id` as a recognized field name in this repo. | ✅ |
| E6 | `break_glass_tab.dart:145` (tenant_id query precedent) | Line 145 `if (_tenantId != null && _tenantId!.isNotEmpty) 'tenant_id': _tenantId` — conditional **body** inclusion. Query-param `tenant_id` precedents also exist: `tenant_branding_tab.dart:73` (`query: {'tenant_id': widget.tenantId}`) and `snaplink_admin_event_stream.dart:33-36` (conditional-omit pattern `if (tenantId?.trim().isNotEmpty ?? false) 'tenant_id': tenantId!`). | ✅ (body at :145; query precedents at :73/:33-36) |
| E7 | `snaplink_admin_types.dart:310-312` (documented audit paths) | Lines 310-312 exact: `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}` (documented endpoint listing in-file). | ✅ |
| E8 | `docs/proposals/audit-contract-batch-snaplink-console.md` (`[PROPOSED]` tenant_id/trace_id, BFF 机制本仓无) | Line 9 exact: `[PROPOSED]：tenant_id（token claim 解析，依赖 B4-1）、trace_id（BFF 注入机制本仓无）、full 部署 sink 独立上游的 nginx 分流配置本仓不存在`. No BFF code anywhere in `lib/`. | ✅ |
| E9 | No BFF layer / trace_id plumbing in repo | Confirmed: sole `trace_id` occurrence in `lib/` is the response read at `setup_api.dart:215` (`data['trace_id']?.toString() ?? data['request_id']...`). No request-side injection. | ✅ |
| E10 | (new) Governance tab already advertises tenant_id as an audit filter | `governance_tab.dart:404` helper text: `'Example: {"tenant_id":"acme","outcome":"failure","limit":100}'` — `tenant_id` and `outcome` are already documented UI-side as audit query params; the builder must keep this example valid. | ✅ |
| E11 | (new) Complete inventory of `/api/v1/audit` literals in `lib/` | `snaplink_admin_types.dart:310-312` (documented trio); `governance_tab.dart:30-31` (calls); `admin_live_events_tab.dart:167` (`'/api/v1/audit/events/${Uri.encodeComponent(id)}'` — the `{id}` variant, documented); `admin_operations_tab.dart:56` (`endpoint.path.startsWith('/api/v1/audit')` — UI grouping prefix, **not a call**). No other audit literals. | ✅ |
| E12 | (new) Sink query surface (cross-repo grounding for the joint T-12 leg) | `../snaplink-audit-governance/internal/httpapi/server.go`: `tenant_id` query param at :869 (admin-actions listing) and :903 (`tenantFor` — platform tokens may pass `tenant_id`; non-platform tokens are **always** scoped to `claims.TenantID`); `parseQuery` at :927 binds `trace_id`, `cursor`, `event_type`, `outcome`, `page_size` etc. as server-side filters. So `tenant_id` scoping and `trace_id` correlation are real, already-implemented server semantics — the console side only needs to represent them, not invent them. | ✅ |
| E13 | (new) Test harness for the regression test | `test/admin_governance_security_test.dart:12-32` provides reusable `_api(routes)` (MockClient keyed by `request.url.path`), `_caps(paths)`, `_pump(tester, child)` helpers; `group('GovernanceTab')` at :80-171 currently exercises read/write sections **without** the audit query (fixtures omit `/api/v1/audit/events`, so the capability gate at `governance_tab.dart:392` renders 'not enabled' and no audit request is issued). No `AuditQuery`-like type exists anywhere in `lib/` or `test/` (grep-verified). | ✅ |
| E14 | (new) Sibling B6-1a decision (consistency) | `docs/proposals/b6-1a-lib-api-auditlogtab-server-read-spec.md` AC-1 asserts an **exact `limit`-only** query (`{'limit': '100'}`) for `AuditLogTab`, with `tenant_id`/`trace_id` assertions behind a marked `[PROPOSED]` conditional. The builder's default (omit tenant_id/trace_id) must keep that assertion true. | ✅ |
| E15 | T-12 joint definition | `docs/campaigns/implementation-gate.md:56` (console row B6-1): 读路径接入（F-06）`tenant_id + trace_id 经 BFF`; `T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据`; :47 (sink row): `audit.event.read` self-audit on query (B1-5, already implemented per `docs/campaigns/campaign-console-b6.yaml:3`). | ✅ |

## 3. Requirements

### REQ-1 — Typed audit query builder `AuditQuery` (new pure-Dart type)
Add `AuditQuery` in a new pure-Dart file `lib/api/audit_query.dart` (no Flutter imports; unit-testable on the VM). It is the **only** sanctioned way to construct query parameters for the audit read endpoints.

- Fields (Dart name → wire query key), all nullable:
  | Field | Wire key | Grounding |
  |---|---|---|
  | `limit` (int?) | `limit` | `governance_tab.dart:32` (default 100), `governance_tab.dart:404` example; serialized as `'$limit'` (string coercion, identical to today's `'$value'` at :169) |
  | `tenantId` (String?) | `tenant_id` | `governance_tab.dart:404` example; sink `server.go:903` (`tenantFor`); in-repo query precedent `tenant_branding_tab.dart:73`, `snaplink_admin_event_stream.dart:35` |
  | `traceId` (String?) | `trace_id` | audit-contract doc `[PROPOSED]` (E8); sink filter `server.go:927` |
  | `cursor` (String?) | `cursor` | sink filter `server.go:927` |
  | `eventTypes` (String?) | `event_type` | sink filter `server.go:927` (single-value key; multi-value semantics are server-defined — the console passes the raw value through) |
  | `outcome` (String?) | `outcome` | `governance_tab.dart:404` example; sink filter `server.go:927` |
- **Presence/absence semantics:** a field serializes **iff** it is non-null and non-empty (for strings: after trim); `tenant_id`/`trace_id` are **omitted by default** — the default wire is exactly `{'limit': '100'}` (or the caller's limit), preserving B6-1a AC-1's exact `{limit: 100}` assertion (E14). Empty-string omission matches the in-repo conditional-omit precedent (`break_glass_tab.dart:145`, `snaplink_admin_event_stream.dart:33-36`).
- `AuditQuery.fromJson(Map<String, dynamic>)` accepts the governance text-field content (JSON object with the wire keys above, int or string values) and **rejects unknown keys** with a typed parse error — the unvalidated-pass-through at `governance_tab.dart:169` is the defect this direction fixes.
- `Map<String, String> toQueryParameters()` returns the serialized map (order-insensitive; consumers must compare as sets/maps).

### REQ-2 — GovernanceTab migrates to the builder (no raw JSON on the wire)
`_queryAudit` (`governance_tab.dart:166-181`) must:
1. Parse the text field through `AuditQuery.fromJson(...)` (reusing the existing `_json` error surface and `'Audit query'` label at :167/:237 for malformed JSON and unknown keys).
2. Pass **only** `AuditQuery.toQueryParameters()` to `widget.api.get(_auditPath, query: ...)` (:175) and, when gated by `_has('GET', _facetPath)` (:176), the identical map to `_facetPath` (:177).
3. Remove the raw stringification `query.map((key, value) => MapEntry(key, '$value'))` (:169) — after the change, no line in `governance_tab.dart` may construct audit query params from an unvalidated map.
4. Keep the helper text at :404 valid: `{"tenant_id":"acme","outcome":"failure","limit":100}` must remain an accepted example (all three keys are in the REQ-1 set). No other UI behavior changes.

The wire-equivalence invariant: entering `'{"limit": 100}'` (the current default) produces exactly the same request query as today — `{'limit': '100'}`.

### REQ-3 — BFF path boundary (no invented endpoints)
The console calls **only** the documented audit paths (`snaplink_admin_types.dart:310-312`): `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}`. No new audit path literal may be introduced anywhere in `lib/`, and no `bff` path literal may be introduced at all (the BFF path definition stays `[PROPOSED]` per E8 — it is recorded in docs, never coded as an interface). Existing non-call usage (`admin_operations_tab.dart:56` prefix grouping) is exempt as a UI classification, not a request.

### REQ-4 — Joint T-12 correlation (cross-repo, executable)
The console-side contract for the T-12 joint drill (`implementation-gate.md:56`): `tenant_id` and `trace_id` are first-class `AuditQuery` fields (REQ-1) whose wire values are the exact values entered/obtained at call time (no transformation beyond trim); when absent, they are absent from the wire. Server-side semantics are already implemented in the sink (E12): `tenant_id` scopes results (server-enforced for non-platform tokens), `trace_id` filters rows. The drill (AC-4) asserts scoping and echo end-to-end; the BFF leg is `[PROPOSED]` and conditional on B4-1.

## 4. Acceptance checks (preserved from the direction, made testable)

**AC-1 — Builder contract/unit test** (new `test/audit_query_test.dart`; pure Dart, no widgets):
1. `AuditQuery(limit: 100).toQueryParameters()` equals `{'limit': '100'}` exactly — **no** `tenant_id`, **no** `trace_id` (default omission, explicit not silent).
2. `AuditQuery(tenantId: 'tenant-a', traceId: 'tr-1', limit: 100).toQueryParameters()` equals `{'limit': '100', 'tenant_id': 'tenant-a', 'trace_id': 'tr-1'}` (map equality; order-insensitive).
3. `AuditQuery(tenantId: '  ', traceId: 'tr-1', limit: 100)` → `{'limit': '100', 'trace_id': 'tr-1'}` — empty/whitespace `tenantId` omitted (precedent: `snaplink_admin_event_stream.dart:33-36`).
4. `AuditQuery.fromJson({'limit': 100, 'tenant_id': 'acme', 'outcome': 'failure'})` round-trips to `{'limit': '100', 'tenant_id': 'acme', 'outcome': 'failure'}` (the advertised helper-text example at `governance_tab.dart:404` must work).
5. `AuditQuery.fromJson({'limit': 100, 'unknown_key': 'x'})` throws a typed parse error (validation is the fix for the unvalidated pass-through).
6. `cursor`, `eventTypes` (→ `event_type`) serialize when present, omitted when absent (same presence/absence rule).

**AC-2 — GovernanceTab wire-equivalence regression test** (extend `test/admin_governance_security_test.dart`, reusing `_api`/`_caps`/`_pump` helpers at :12-32):
1. Fixture: `_caps(['/api/v1/audit/events', '/api/v1/audit/facets'])`; MockClient records `request.url.path` and `request.url.queryParameters` for every request; `/api/v1/audit/events` and `/api/v1/audit/facets` respond 200 `'{}'` (or `{'events': []}`).
2. Pump `GovernanceTab(api: api, capabilities: caps)`, tap the `Audit` section, tap `Query audit events` **without editing the field** (default `'{"limit": 100}'`).
3. Assert: every recorded request to `/api/v1/audit/events` has `queryParameters` exactly `{'limit': '100'}` — **same wire query as today** (regression for `'{"limit":100}'` equivalence); the facets request (if gated in) carries the identical map; **no request to any other path**; no query parameter outside the REQ-1 key set on any request.
4. Assert: entering `'{"limit": 100, "tenant_id": "acme"}'` produces `{'limit': '100', 'tenant_id': 'acme'}` on the wire (tenant_id reaches the wire when the operator supplies it; omitted when not).
5. Source guard (same test file or a grep step in CI): `grep -n "MapEntry(key, '\$value')" lib/screens/admin/governance_tab.dart` returns **no hits** after the change — the raw-JSON stringification is gone; audit query params come only from `AuditQuery`.

**AC-3 — No-invented-BFF-endpoints guard test** (new `test/audit_contract_guard_test.dart`):
1. Scan `lib/**/*.dart` for string literals containing `'/api/v1/audit'`; normalize each (`:id`/`{id}` → `{id}`); assert every hit is one of `{/api/v1/audit/events, /api/v1/audit/facets, /api/v1/audit/events/{id}}` (E11 inventory is the current baseline) **or** the exact documented grouping prefix expression `endpoint.path.startsWith('/api/v1/audit')` in `admin_operations_tab.dart:56`.
2. Assert no string literal in `lib/` starts with `'/bff'` or contains `'/api/v1/bff'` — the BFF path definition remains `[PROPOSED]` in docs only (`audit-contract-batch-snaplink-console.md:9`), never coded as an interface.
3. Assert `SnaplinkAdminOperationCatalog` (or the `snaplink_admin_types.dart` listing at :310-312) gains no audit path beyond the trio (guards against catalog drift).

**AC-4 — Joint T-12 drill (cross-repo; executable legs split by dependency):**
- **Leg 1 (sink, executable today):** against the verification stack of `snaplink-audit-governance`, using a platform token: `GET /api/v1/events?tenant_id=tenant-a` → every returned row's `tenant_id == 'tenant-a'`; `GET /api/v1/events?trace_id=<T>` (T = a trace_id present in ingested fixtures) → every returned row's `trace_id == <T>` (echo-back correlation, `server.go:927`). Non-platform token without `tenant_id` → rows scoped to the token's tenant claim (`server.go:903` — server-enforced; console cannot widen scope).
- **Leg 2 (console, executable today):** AC-1/AC-2 round-trip — `AuditQuery(tenantId: ..., traceId: ...)` puts exactly those values on the wire, nothing else.
- **Leg 3 `[PROPOSED, conditional on B4-1/BFF]`:** once a BFF exposes the documented console paths, query via `GET /api/v1/audit/events?tenant_id=tenant-a&trace_id=<T>` and assert: only tenant-a rows, every row's `trace_id == <T>`, and a self-audit `audit.event.read` row appears for the caller (T-12 联合 per `implementation-gate.md:56`, sink B1-5). Until the BFF exists, Leg 3 is recorded as blocked and is **not** faked by a console-side fixture.

**AC-5 — Existing tests stay green:** `test/admin_governance_security_test.dart` (GovernanceTab group at :80-171 — its fixtures omit the audit path, so the capability gate keeps them passing), `test/api_paths_test.dart`, `test/snaplink_admin_api_test.dart`, and `test/audit_log_tab_test.dart` (B6-1a, if landed) continue to pass unchanged; `flutter analyze` is clean. If the B6-1a `AuditLogTab` implementation later adopts `AuditQuery`, its AC-1 exact-`{limit: 100}` assertion must hold with default construction (REQ-1 guarantees it).

## 5. Out of scope (explicitly not covered by this direction)

- B6-1a: `AuditLogTab` server-side read wiring, capability gate, response-to-rows mapping (`docs/proposals/b6-1a-lib-api-auditlogtab-server-read-spec.md`) — sibling direction.
- B6-1b: demoting the localStorage ring / `_recordAudit` to debug-only.
- B6-2: `client_id` alignment (`sso-admin-console` vs `console`).
- BFF implementation, BFF path definition in code, `trace_id` injection mechanism, token-claim `tenant_id` parsing (B4-1) — all `[PROPOSED]`, depend on other batches (E8).
- Sink-side changes (tenant-consistency 422, self-audit emission B1-5) — already implemented server-side per the campaign; this repo only asserts request/query behavior.
- Any new audit response model or typed response parsing (governance tab keeps rendering raw JSON via `_safe`).

## 6. Risks

| Risk | Mitigation |
|---|---|
| Direction line drift (E4: `snaplink_admin_api.dart:89-91` → `:126`) | This spec re-anchors every citation; implementation reviews must use the verified numbers. |
| Unknown-key rejection in `AuditQuery.fromJson` is a behavior change for the diagnostic field | Bounded to the documented key set (REQ-1, all grounded in :404 example and sink `parseQuery`); helper text already advertises only supported keys; error goes through the existing `'Audit query'` surface. |
| Guard test brittleness (string-literal scanning) | Restricted to path-like literals; baseline inventory (E11) is small and stable; the `admin_operations_tab.dart:56` grouping prefix is whitelisted explicitly. |
| Joint T-12 (AC-4 Leg 3) depends on B4-1/BFF and on sink B1-5 | Legs 1-2 are executable today against the real sink; Leg 3 is explicitly `[PROPOSED]` and never faked client-side — consistent with the direction's no-invented-interface rule. |
| Wire-behavior conflict with B6-1a's exact `{limit: 100}` assertion | REQ-1 default omits `tenant_id`/`trace_id`; they appear only when explicitly supplied (AC-1.1, AC-2.3) — B6-1a AC-1 stays true. |
