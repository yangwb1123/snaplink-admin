# B6-1 — Requirements Specification: Capability-driven navigation boundary for the audit tab (module: lib/screens/developer)

> Source direction: `B6-1 capability-driven navigation boundary — audit tab gains api/capabilities injection like governance_tab.dart:376, without touching the path-routed DCR module or guessing un-documented interfaces` (from `docs/auto/analyses/lib-screens-developer-3899da21.json`, direction 3).
> All file/line citations re-verified against the repository at HEAD `b82d2cf` on 2026-08-07. Corrections to the source citation are marked `[CORRECTION]`. This is a **boundary direction**: the module under contract is `lib/screens/developer` (zero delta), the change set lands in `lib/screens/admin/` + `test/`, and the acceptance proves the two surfaces stay decoupled.

## 1. Problem statement (verified)

The contract mandates keeping the capability-driven navigation pattern (no guessing interfaces). The audit page is the **only** admin tab without `api:`/`capabilities:` injection: `lib/screens/admin/dashboard_screen.dart:559-566` registers it as `page: const AuditLogTab(),` (`:566`), while the proven pattern sits one entry above it — `page: GovernanceTab(api: _api, capabilities: capabilities),` (`:557`) — reading `GET /api/v1/audit/events` + `GET /api/v1/audit/facets` through `widget.api.get(...)` (`governance_tab.dart:183-186`), gated by `_has('GET', _auditPath)` (`governance_tab.dart:81-83`, gates at `:400`/`:404`).

The developer module sits on the other side of the boundary:

- `lib/app_router.dart:13,31` — `ProductEntry.developer => const DeveloperScreen(),` is a **path-routed, unauthenticated** public entry (by design: `lib/screens/developer/developer_screen.dart:10-18` documents the no-account DCR flow, RFC 7591/7592, authenticated only by `registration_access_token`).
- The admin `'developers'` module group (`lib/screens/admin/admin_module_groups.dart:84-92`: webhooks/liveActivity/operations/recoveryReleases) is a **distinct, capability-gated surface** (`if (navigation.supportsWebhooks)` at `dashboard_screen.dart:500`).

Conflating these — e.g. gating the DCR portal by admin capabilities, or inventing audit routes beyond the documented trio at `lib/api/snaplink_admin_types.dart:310-312` (`GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}`) — would break the pattern. The audit read must stay on documented routes via `SnaplinkAdminApi` only.

**Repo state at verification time (relevant, not scope):** the B6-1c typed-query work has landed at HEAD — `AuditQuery` exists (`lib/api/audit_query.dart:17,68,148`) and `governance_tab.dart:170-178` already parses through `AuditQuery.fromJson`/`toQueryParameters`. The AC-3 guard suite (`test/audit_contract_guard_test.dart`, `test/audit_contract_guard_scans.dart`) includes **Scan 5 — second-consumer land-check** (`audit_contract_guard_scans.dart:222-233`): any lib file whose literals normalize to a queryable audit endpoint **and** passes a `query:` argument must construct those parameters through `AuditQuery`. The AuditLogTab change must therefore satisfy this guard, not fight it.

## 2. Evidence verification table

| # | Citation from direction | Verified repository reality | Status |
|---|---|---|---|
| E1 | `dashboard_screen.dart:559-565` (`AuditLogTab` registered const, no api/capabilities — contrast `governance_tab.dart:166` widget.api) | Audit entry spans **559-566**; `page: const AuditLogTab(),` at **566**; `module: AdminModuleId.auditLog` at :560 — unconditional (no `if (navigation.supports...)` wrapper). Contrast: `GovernanceTab(api: _api, capabilities: capabilities)` at **557**; `_queryAudit` at **167** (not 166); `widget.api.get(_auditPath, query: parameters)` at **183**. | ✅ (lines shifted +1 vs citation) |
| E2 | `governance_tab.dart:30-31,175,376-380` (`_auditPath`/`_facetPath`; `_has('GET', _auditPath)` gate) | `_auditPath` at **31**, `_facetPath` at **32**; `_has(String, String)` at **81-83** (`widget.capabilities.has(method, path) \|\| widget.capabilities.endpoints.any(...)`); events read at **183**, facets twin at **184-186** (gated by `_has('GET', _facetPath)` at :184); `_auditArea` gate at **400** (`if (!_has('GET', _auditPath))` → `'Audit querying is not enabled on the connected replica.'` at :401-403) and **404** (`if (_has('GET', _auditPath)) ...[`). `GovernanceTab` constructor shape at **18-24** (`required this.api`, `required this.capabilities`). | ✅ (lines 31-32/183/400-404, not 30-31/175/376-380) |
| E3 | `snaplink_admin_types.dart:310-312` (documented audit routes) | Lines **310-312** exact: `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}` (documented endpoint listing in-file). `SnaplinkAdminCapabilities` at **89-101** (`endpoints` field :90, `has(method, path)` :94-101) — the gate primitive the tab must reuse. | ✅ |
| E4 | `app_router.dart:13,31` (path-routed public entries incl. `ProductEntry.developer → const DeveloperScreen()`) | Line 13 (doc: reverse proxy routes `/developer/`) and line **31** `ProductEntry.developer => const DeveloperScreen(),` — exact. | ✅ |
| E5 | `developer_screen.dart:10-18` (documented unauthenticated DCR design; no admin capabilities) | Doc comment at **10-18** exact: no developer account/login; POST /register unauthenticated (or operator-issued initial access token); manage authenticated solely by `registration_access_token`. `DeveloperScreen` takes only optional `DeveloperApi? api` — no admin capability surface anywhere in the module. | ✅ |
| E6 | `admin_module_groups.dart:84-91` (admin 'developers' group) | Group spans **84-92** (`id: 'developers'` at :84; modules at :88-92: webhooks :89, liveActivity :90, operations :91, recoveryReleases :92). `AdminModuleId.auditLog` belongs to the **'system'** group at **:102** — a different group than the 'developers' group; the two surfaces share no module ids. | ✅ (84-92, not 84-91) |
| E7 | `test/admin_gate_test.dart` (boundary regression) | Verified: 6 tests covering `adminLoginLocation` deep-link preservation, hosted-login payload, non-Admin fallback, encoded-slash resource ids. **Zero** references to `AuditLogTab`, developer screens, or audit paths — it pins the `/admin/` login boundary only. | ✅ |
| E8 | `test/admin_navigation_test.dart` (boundary regression) | Verified: `group('Admin navigation route mapping')` — capability-filtered entry mapping, unavailable-route fallback, documented-routes-when-inventory-empty, runtime-metadata precedence. **Zero** audit or developer references; it pins the `adminNavigationIndexForModule`/`adminNavigationModuleAt` mechanics. | ✅ |
| E9 | `test/entry_ux_test.dart:134` (developer discovery-retry) | Line **134** exact: `testWidgets('developer discovery failure offers an in-place retry', ...)` pumping `DeveloperScreen(api: api)` with a MockClient returning 503-then-discovery-document; asserts in-place retry (lines 134-160). | ✅ |
| E10 | `snaplink_admin_api.dart:134` (typed query) | `Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool forceRefresh = false})` at **126**; the typed query is forwarded to the transport at **134** (`return _request('GET', path, query: query);`). `listEndpoints()` at **113** (the runtime inventory source). | ✅ (signature :126, forwarding :134) |
| E11 | (new) Typed query builder already exists and is guard-pinned | `lib/api/audit_query.dart`: `class AuditQuery` :17, `factory AuditQuery.fromJson` :68, `Map<String, String> toQueryParameters()` :148, `AuditQueryParseException` :167. `governance_tab.dart:170-178` already migrates through it (b6-1c landed, HEAD `b82d2cf`). | ✅ |
| E12 | (new) AC-3 guard suite second-consumer scan | `test/audit_contract_guard_scans.dart:222-233` — Scan 5 (`scanSecondConsumer`, invoked from the scan driver at :97): a lib file with a queryable audit-endpoint literal **and** a `query:` argument must contain `AuditQuery`; `test/audit_contract_guard_test.dart:173` and `test/audit_contract_guard_mutation_test.dart:234` carry fixture `AuditLogTab` shapes for the scan. Scan 1 (`audit-path-literals`) whitelists exactly the trio plus `admin_operations_tab.dart:56` grouping prefix. | ✅ |
| E13 | (new) `{id}` route precedent | `lib/screens/admin/admin_live_events_tab.dart:167` — `'/api/v1/audit/events/${Uri.encodeComponent(id)}'`: the documented `{id}` variant, called via `widget.api.get(...)` with **no** query map (scan-1 normalization: `${Uri.encodeComponent(<ident>)}` → `{id}`). `admin_operations_tab.dart:56` — `endpoint.path.startsWith('/api/v1/audit')` is a UI grouping prefix, not a call (whitelisted by the guard). | ✅ |
| E14 | (new) T-12 joint gate | `docs/campaigns/implementation-gate.md:56` (console row B6-1): 审计页调 sink 读 API; T-12 联合 — 查询触发 self-audit 行；devtools 伪造不再构成证据. Sink-side self-audit emission is B1-5 (`:47`); this direction only asserts the console request/capability side. | ✅ |
| E15 | (new) In-scope test updates required by the DI change | `test/admin_support_tabs_test.dart:62-163` — `group('AuditLogTab')` pumps `const AuditLogTab()` at **:88** and **:149**; both break when the constructor gains required params and must be updated (the only existing-test edits in scope). Reusable harness: `test/admin_governance_security_test.dart:12-32` (`_api(routes)` MockClient keyed by `request.url.path`, `_caps(paths)`, `_pump`). | ✅ |

## 3. Requirements

### REQ-1 — AuditLogTab dependency injection (api + endpoint inventory)
`lib/screens/admin/audit_log_tab.dart:15-16` (`const AuditLogTab({super.key})`) must gain the same constructor shape as `GovernanceTab` (`governance_tab.dart:18-24`):

- `required SnaplinkAdminApi api` and `required SnaplinkAdminCapabilities capabilities` (the endpoint-inventory carrier: `SnaplinkAdminCapabilities.endpoints` at `snaplink_admin_types.dart:90` — this is the direction's "endpoints param" delivered in the exact form the acceptance's governance pattern uses; `SnaplinkAdminCapabilities.has(method, path)` at :94-101 is the gate primitive the tab calls).
- The tab must not construct its own API client or capability set.
- The raw-endpoints alternative (`AdminLiveEventsTab(api: _api, endpoints: _endpoints)`, `dashboard_screen.dart:342`) is **rejected** — it would force the tab to re-implement the `_has` logic that already exists on the capabilities object and would diverge from the governance pattern this direction replicates.
- `dashboard_screen.dart:566` becomes `page: AuditLogTab(api: _api, capabilities: capabilities)` — both bindings are already in scope (`_api` at :82; `capabilities` derived at :243-244 from `AdminNavigationCapabilities(_endpoints)`, the documented+runtime merged view per `admin_navigation.dart:59-65,158-166`). `const AuditLogTab()` must no longer appear anywhere in `lib/` or `test/` (grep-provable).

### REQ-2 — Capability gate (governance pattern): hidden without the read capability
Replicate the governance `_has` gate exactly:

- The tab defines `_has(String method, String path)` identical to `governance_tab.dart:81-83` (`widget.capabilities.has(...) || widget.capabilities.endpoints.any(...)`), or reuses the same primitive.
- When `GET /api/v1/audit/events` is **not** in the endpoint inventory, the tab renders the same not-enabled placeholder as the governance audit area (`governance_tab.dart:400-403`: `'Audit querying is not enabled on the connected replica.'` or an equivalent `LocalizedText`) and issues **zero** requests to any `/api/v1/audit/*` path.
- When the endpoint is present, the server read proceeds (the data-source and response-mapping behavior of the tab is **B6-1a scope** — `docs/proposals/b6-1a-lib-api-auditlogtab-server-read-spec.md` — and is not re-specified here; this direction pins only the injection, the gate, and the request contract).
- No new navigation machinery: the audit entry stays an unconditional `AdminNavigationEntry` in the entries list (`dashboard_screen.dart:559-566`, same as the governance entry at :550-557); the gate lives inside the tab. Do **not** add a `supportsAuditLog` getter to `AdminNavigationCapabilities` (`admin_navigation.dart`) — the governance precedent has none and the direction's cited pattern is the in-tab `_has` gate.

### REQ-3 — Documented routes only, via SnaplinkAdminApi.get with typed AuditQuery parameters
- The tab may call **only** the documented trio: `GET /api/v1/audit/events`, `GET /api/v1/audit/facets` (`snaplink_admin_types.dart:310-311`), and the `{id}` variant `GET /api/v1/audit/events/{id}` using the `Uri.encodeComponent` form (`admin_live_events_tab.dart:167`). No new or un-documented routes — enforced repo-wide by guard scan 1 (`test/audit_contract_guard_test.dart`).
- Every request carrying a `query:` argument must be built through `AuditQuery` (`lib/api/audit_query.dart:17,68,148`): `AuditQuery.fromJson(...)`/direct construction → `toQueryParameters()` → `SnaplinkAdminApi.get(path, query: parameters)` (signature at `snaplink_admin_api.dart:126`, typed query forwarded at :134). Hand-built map literals (`query: {'limit': '100'}`) **trip guard scan 5** (`audit_contract_guard_scans.dart:222-233`) and are forbidden. The default limit query is `{'limit': '100'}` (governance default, `governance_tab.dart:33`).
- `SnaplinkAdminApi` remains the only transport: no new methods on `SnaplinkAdminApi`, no direct `http` usage, no BFF/path invention (`[PROPOSED]` interfaces stay in `docs/proposals/audit-contract-batch-snaplink-console.md` only).

### REQ-4 — DCR portal zero-delta floor (the module under contract)
`lib/screens/developer/` and its routing boundary are **untouched**:

- No file under `lib/screens/developer/` changes; no admin capability, audit path, or `SnaplinkAdminApi` reference is added to the module (guard scans 1-2 make this grep-provable).
- `lib/app_router.dart:31` (`ProductEntry.developer => const DeveloperScreen(),`) stays as-is — no capability gate, no constructor change to `DeveloperScreen` (its optional `DeveloperApi? api` injection at `developer_screen.dart:21` is the DCR module's own seam and is not part of this direction).
- `lib/screens/admin/admin_module_groups.dart:84-92` (admin 'developers' group) and its capability gates (`dashboard_screen.dart:500` `if (navigation.supportsWebhooks)`, etc.) stay as-is.

### REQ-5 — Decoupling regression floor (existing boundary tests stay green)
- `test/entry_ux_test.dart:134` (developer discovery-retry) passes unchanged.
- `test/admin_navigation_test.dart` and `test/admin_gate_test.dart` pass unchanged — they pin the admin navigation/login boundary and must not gain or lose audit/developer coupling.
- `test/audit_contract_guard_test.dart` (+ mutation drill) stays green — the AuditLogTab change is scan-1- and scan-5-compliant (REQ-3).
- `test/admin_support_tabs_test.dart:88,149` are updated to construct the tab with injected `api`/`capabilities` (reusing the `_api`/`_caps` harness from `test/admin_governance_security_test.dart:12-32`) — the only in-scope edits to existing tests. Their assertions that depend on the localStorage ring (`AuditLogService`) belong to B6-1a/B6-1b and must not be re-asserted here.
- `flutter analyze` clean.

## 4. Acceptance checks (direction acceptance preserved 1:1, made testable)

**AC-1 — Direction acceptance (1): DI + capability-gated visibility.**
1. Compile/grep check: `grep -rn "const AuditLogTab()" lib/ test/` → **no hits**; `dashboard_screen.dart:566` reads `AuditLogTab(api: _api, capabilities: capabilities)`.
2. Widget test (new `test/audit_log_tab_test.dart`, modeled on `test/admin_governance_security_test.dart:12-32` helpers): pump `AuditLogTab(api: api, capabilities: caps)` with `caps = _caps(['/api/v1/admin/endpoints'])` (inventory **without** the audit read) and a MockClient that 404s everything; assert the not-enabled placeholder renders (governance string at `governance_tab.dart:401-403` or equivalent) and the MockClient recorded **zero** requests whose path starts with `/api/v1/audit`.
3. Same test with `caps = _caps(['/api/v1/audit/events', '/api/v1/audit/facets'])`: the tab issues the server read (≥1 request to `/api/v1/audit/events`) — gate satisfied, request issued.

**AC-2 — Direction acceptance (2): documented routes only, typed query.**
1. MockClient-backed widget test records `request.url.path` and `request.url.queryParameters` for every request; serve 200 `'{}'` (or B6-1a's fixture shape) for `/api/v1/audit/events` and `/api/v1/audit/facets`.
2. Assert every recorded path ∈ `{/api/v1/audit/events, /api/v1/audit/facets, /api/v1/audit/events/{id}}` (with `{id}` percent-encoded per `admin_live_events_tab.dart:167`) and **no** request to any other path — no new/un-documented routes.
3. Assert every query-carrying request has `queryParameters` exactly `{'limit': '100'}` (default) — proving the parameters came from `AuditQuery.toQueryParameters()` (`audit_query.dart:148`), not a hand-built map.
4. Guard enforcement (already in repo): `flutter test test/audit_contract_guard_test.dart` green — scan 1 (trio whitelist) and scan 5 (second-consumer `AuditQuery` requirement at `audit_contract_guard_scans.dart:222-233`) both pass with the new tab code; the tab source contains `AuditQuery` and no `MapEntry(key, '$value')` stringification.

**AC-3 — Direction acceptance (3): DCR portal behavior unchanged.**
1. `flutter test test/entry_ux_test.dart` passes — in particular the `'developer discovery failure offers an in-place retry'` test at `:134`.
2. Grep/diff check: `git diff --stat` shows **no** changes under `lib/screens/developer/`; `lib/app_router.dart:31` unchanged (`ProductEntry.developer => const DeveloperScreen(),`).
3. Grep check: no `SnaplinkAdminApi`/`SnaplinkAdminCapabilities`/`/api/v1/audit` tokens introduced into `lib/screens/developer/` (guard scan 1 also enforces the audit-literal half).

**AC-4 — Direction acceptance (4): admin boundary tests green, surfaces decoupled.**
1. `flutter test test/admin_navigation_test.dart test/admin_gate_test.dart` pass unchanged (no edits to either file).
2. Grep check: `test/admin_navigation_test.dart` and `test/admin_gate_test.dart` contain **zero** audit-path or developer-screen references after the change — same as today (E7/E8).
3. `grep -n "auditLog" lib/screens/admin/admin_module_groups.dart` still shows only `:102` (system group) and the 'developers' group (`:84-92`) remains untouched — the audit surface and the developer/developers surfaces stay decoupled.
4. `flutter test test/admin_support_tabs_test.dart` green with the REQ-5 constructor updates (the only in-scope existing-test edits).

## 5. Out of scope (explicitly not covered by this direction)

- **B6-1a** (`docs/proposals/b6-1a-lib-api-auditlogtab-server-read-spec.md`): AuditLogTab's server-response data model, response-to-rows mapping, localStorage-ring removal from the timeline — sibling direction; the shared `test/audit_log_tab_test.dart` file is split by concern (this direction: request/capability contract; B6-1a: response rendering).
- **B6-1b**: demoting `AuditLogService`/`_recordAudit` to debug-only, debug labeling of CSV/Clear actions.
- **B6-2**: `client_id` contract alignment (`sso-admin-console` vs `console`) — separate direction.
- Any change to `lib/screens/developer/` internals, `DeveloperScreen` constructor semantics, or DCR routes (POST/PUT/DELETE `/register...`).
- Any change to `admin_module_groups.dart` groups, `AdminNavigationCapabilities` getters, or nav-entry culling for the audit module (the governance precedent keeps the entry unconditional and gates in-tab).
- New endpoints, BFF path definitions, `trace_id` injection, token-claim `tenant_id` parsing — all `[PROPOSED]` per `docs/proposals/audit-contract-batch-snaplink-console.md:9-11`.
- Sink-side self-audit emission (B1-5) and any cross-repo drill execution — asserted only at the console request/capability layer (T-12 joint per `implementation-gate.md:56`).

## 6. Risks

| Risk | Mitigation |
|---|---|
| Direction line drift (E1/E2: `:559-565`→`:559-566`/`:566`, `:30-31`→`:31-32`, `:175`→`:183`, `:376-380`→`:400-404`) | This spec re-anchors every citation at HEAD `b82d2cf`; implementation and review must use the verified numbers. |
| Hand-built query maps in the new tab code trip guard scan 5 | REQ-3 makes `AuditQuery` mandatory for any `query:`-carrying audit call; AC-2.4 asserts the guard suite stays green, so the failure is caught in-repo before acceptance. |
| The DI change breaks `test/admin_support_tabs_test.dart:88,149` | Pre-identified as the only in-scope existing-test edit (REQ-5, AC-4.4); the `_api`/`_caps` harness at `admin_governance_security_test.dart:12-32` makes the update mechanical. |
| Scope bleed into B6-1a response mapping or B6-1b ring demotion | Section 5 draws the line; acceptance here asserts only injection, gate, request paths/query, and boundary tests — not row rendering from server responses. |
| Overlap of the shared `test/audit_log_tab_test.dart` with sibling directions | Test file is organized per concern (this direction's AC-1/AC-2 request-and-gate assertions are additive; B6-1a's rendering assertions are additive; neither re-asserts the other's behavior). |
| `AuditQuery` default drift (e.g. `{'limit': '100'}` vs `{'limit': 100}`) | `toQueryParameters()` serializes ints as strings (`audit_query.dart:148`); AC-2.3 pins the exact wire map `{'limit': '100'}`, matching the b6-1a AC-1 assertion. |
