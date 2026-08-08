# B6-1 — Requirements Specification: developer-module debug-ring isolation floor (module: lib/screens/developer)

> Source direction: **"B6-1 isolation floor for the developer module: net-zero debug-ring guard + literal scan, mirroring the oidc_login sibling"** (value 8 / risk 8 / effort 2 / confidence 9), from `docs/auto/analyses/lib-screens-developer-3899da21.json`.
> All file/line citations below were re-verified against the repository on 2026-08-08 (HEAD `26567d5` + uncommitted B6-1a/b/c working-tree change set). Corrections to the source citation are marked `[CORRECTION]`.
> **Working-tree state (verified):** the B6-1a sibling rewire is **landed** — `AuditLogTab` is already server-fed with injected `api`/`capabilities` (`lib/screens/admin/audit_log_tab.dart:26,53,68,284`), and its forge joints (AC-3a/3b/3c) are pinned at `test/audit_log_tab_test.dart`. Unlike the oidc_login sibling spec (written pre-rewire with a two-phase acceptance), **every acceptance check in this spec is green-able at HEAD with zero `lib/` edits** — the deliverable is regression guards + the T-12 joint contract, no production-code change in `lib/screens/developer/`.

## 1. Problem statement (verified)

The localStorage ring (`lib/services/audit_log_service.dart`, key `'sso_audit_log'` at `:66`) is demoted to debug-only recording and the timeline displays server-side records (`docs/campaigns/implementation-gate.md:56`, console row 1: "localStorage ring 降级为调试记录；展示服务端记录"; T-12 联合: "devtools 伪造不再构成证据"). Against that contract, `lib/screens/developer/` — the console's only client-lifecycle mutation surface (`POST /register`, `PUT`/`DELETE /register/:client_id` via `DeveloperApi`; RFC 7591/7592) — is the only mutation surface with zero audit integration, and nothing pins the boundary:

- **Zero references today (verified):** `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/developer/` → exit 1 (zero hits across all 13 module files). No developer test file references the ring either (grep over `test/developer_api_test.dart`, `test/dcr_widgets_test.dart`, `test/entry_ux_test.dart`, `test/developer_serving_region_test.dart`, `test/dcr_models_test.dart` → exit 1).
- **Sole ring writer (verified):** `_recordAudit` at `lib/api/snaplink_admin_api.dart:81-84` (`AuditLogService().record(` at `:82`), invoked only from the admin mutation path `if (method != 'GET')` at `:323-324`. `AuditLogService().record(` has exactly one call site in `lib/`. The admin side of that write is itself pinned by `test/snaplink_admin_api_test.dart:331-413` — the positive counterpart to this direction's net-zero negative.
- **Nothing pins the developer boundary (verified):** no net-zero isolation test exists for this module (the oidc_login sibling has one at `test/oidc_login_ring_isolation_test.dart:104-137`), and no literal-scan guard covers `lib/screens/developer/` (grep over `test/*guard*.dart` + `test/*census*.dart` → exit 1; the sibling guard is `test/oidc_login_audit_visibility_guard_test.dart`).

Without the guard, a future commit could wire DCR mutations into the debug ring; a devtools-forged `sso_audit_log` row could then be rendered as evidence — or merged/duplicated into the server-fed timeline — breaking the T-12 joint ("devtools 伪造不再构成证据", `implementation-gate.md:56`).

## 2. Evidence verification table

| # | Citation from direction | Verified repository reality | Status |
|---|---|---|---|
| E1 | `lib/screens/developer/developer_api.dart:30-58,80-87` — register/loadApp/saveApp/deleteApp, zero audit imports | `class DeveloperApi` at `:39`; injectable constructor `DeveloperApi({http.Client? httpClient, Uri? baseUri, Duration timeout = …})` at `:44-49`; `register` (POST `/register`) at `:75-93`; `loadApp` (GET `/register/:client_id`) at `:117-131`; `saveApp` (PUT) at `:136-153`; `deleteApp` (DELETE) at `:155-166`. Zero audit references: grep exit 1 (verified). `[CORRECTION: 30-58,80-87 → 39,44-49,75-93,117-131,136-153,155-166]` | ✅ exact substance, lines corrected |
| E2 | `lib/api/snaplink_admin_api.dart:81-82` — `_recordAudit`, sole `AuditLogService.record` caller in lib/ | `void _recordAudit(...)` at `:81`, `AuditLogService().record(` at `:82`, `AuditEntry(` at `:83`; mutation-only gate `if (method != 'GET')` at `:323` → `_recordAudit(...)` at `:324`. `grep -rn "AuditLogService().record(" lib/` → exactly `snaplink_admin_api.dart:82`. | ✅ exact |
| E3 | `lib/services/audit_log_service.dart:33,66-89` — localStorage ring `'sso_audit_log'` | `static const String _storageKey = 'sso_audit_log';` at **`:66`** `[CORRECTION: :33 → :66]`; `List<AuditEntry> get entries` at `:87`; `void record(...)` at `:89-94` (insert-at-0 + `_save()` at `:94`); `int get count` at `:125`; `_save()` `LocalStorage.setItem(_storageKey, …)` at `:127-132` (`:130`); `_load()` `LocalStorage.getItem(_storageKey)` at `:137-145` (`:138`). | ✅ (storage key at 66) |
| E4 | `lib/screens/admin/audit_log_tab.dart:22,43,130` — "timeline renders ring entries today" | **Stale — B6-1a rewire landed.** Current: `const AuditLogTab({super.key, required this.api, required this.capabilities})` at `:26`; `_client = AuditReadClient(widget.api)` at `:53`; capability gate at `:68`; fetch via `_client.list(limit: 100)`; server-sourced subtitle `'All authentication and administrative events recorded by the server.'` at `:284`; the only ring references are the B6-1b debug-only badge — `_logService` at `:33` (badge count `:241`) behind `kDebugMode && AuditLogService.ringCopyEnabled` at `:293`, Clear at `:300-318` (debug surface only; ring never feeds rows/CSV/empty-state). Ring rows never render on the timeline (AC-3a/3b/3c, see S3). `[CORRECTION]` | ⚠️ stale → landed |
| E5 | `test/oidc_login_ring_isolation_test.dart:104-137` — pre-seed/snapshot/assert-untouched harness to mirror | Exact. `testWidgets('login flow leaves the pre-seeded audit ring untouched', …)` at `:100`; pre-seed `AuditLogService().record(AuditEntry(path: '/api/v1/admin/forged', label: 'forged'))` at `:103-117` + `addTearDown(AuditLogService().clear)`; post-seed snapshots `LocalStorage.keys().toSet()` / `LocalStorage.getItem('sso_audit_log')` / `count` / `entries` at `:119-125` with seed-sanity expects; net-zero asserts at `:130-137` (keys set, stored value, count, entries; plus zero audit-path requests). | ✅ exact |
| E6 | `test/oidc_login_audit_visibility_guard_test.dart:39` — literal-scan guard pattern to mirror | `@TestOn('vm')` + `dart:io` recursive scan of `lib/screens/oidc_login`; `const banned = ['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log']` at `:22` (literal-split so the guard never self-hits); `expect(offenders, isEmpty, reason: …)` at **`:35-47`** `[CORRECTION: 39 → 35]`; grep form documented in the file header (must exit 1). | ✅ (expect at 35) |
| E7 | `docs/campaigns/implementation-gate.md` row 1 — T-12 | Line 56, console row 1, exact: "读路径接入（F-06）：审计页调 sink 读 API（tenant_id + trace_id 经 BFF）；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5". | ✅ exact |
| E8 | `test/developer_api_test.dart:29,46` — MockClient harness | MockClient-backed `DeveloperApi(baseUri: …, httpClient: MockClient(…))` instances at `:14-16`, `:52-54`, `:74-76`, `:123-125` (method/path/authorization/body asserts per request; canned 2xx). `[CORRECTION: 29,46 → 14-16,52-54,74-76,123-125]`. | ✅ (harness pattern exact) |
| E9 | AC-4 files: `test/dcr_widgets_test.dart`, `test/entry_ux_test.dart` | Both exist. `test/entry_ux_test.dart` "developer discovery failure offers an in-place retry" at `:136` (`DeveloperApi` + MockClient pumped into `DeveloperScreen(api: api)`); `test/dcr_widgets_test.dart` pumps `DeveloperScreen` with `DeveloperApi`/MockClient at `:164`, `:197`. | ✅ exact |

Supplemental evidence (module testability, verified at HEAD):

| # | Fact | Location |
|---|---|---|
| S1 | `DeveloperApi` is pure Dart with injectable `httpClient`/`baseUri` — a plain `test()` (no `testWidgets`) can drive all three mutations | `developer_api.dart:44-49` |
| S2 | `LocalStorage` on VM is an in-memory implementation with `keys()`; `AuditLogService()` is a singleton with `record()`/`clear()`; `record()` persists synchronously via `setItem` — pre-seed/snapshot is deterministic | `lib/services/local_storage.dart:11-25`, `audit_log_service.dart:89-94,127-132` |
| S3 | The landed B6-1a forge joints: `test/audit_log_tab_test.dart` AC-3a/3b/3c (`:276-306`+), `_seedForgedRing()` at `:89-105` (forged path `/api/v1/admin/forged` — **non-matching** vocabulary); forged markers never render; ring never acts as fallback on server 500/empty. The developer floor's AC-3 adds the **matching-vocabulary** variant (forged label == server row type) | `test/audit_log_tab_test.dart` |
| S4 | Timeline widget harness to mirror: `_api(routes)` MockClient keyed by `request.url.path`, `_caps(paths)`, `_pump` — reusable verbatim | `test/audit_log_tab_test.dart:26-76` |
| S5 | No existing guard scans `lib/screens/developer/` (grep over `test/*guard*.dart`, `test/*census*.dart` → exit 1); no developer test file references the ring (E1 note) | verified |
| S6 | Admin ring-write positive pin (contrast): `test/snaplink_admin_api_test.dart:331-413` — admin `POST/PUT/DELETE` **do** write exactly one ring entry + `sso_audit_log` key; the developer module must be the mirror-image negative | `test/snaplink_admin_api_test.dart` |

## 3. Requirements

### REQ-1 — Zero-audit-reference floor (static guard; module invariant)
`lib/screens/developer/**` must keep **zero** references to `AuditLogService`, `audit_log_service`, and the ring key `sso_audit_log` — no imports, no construction, no reads, no writes, no string literals. This is the module-side encoding of "localStorage ring → debug-only recording" (`implementation-gate.md:56`): debug-only means this module's DCR mutations are evidenced exclusively through the server feed, never through the ring. Verified compliant at HEAD (E1); enforced by a Dart scan test (AC-2) plus a grep guard.

### REQ-2 — DCR mutations leave the ring untouched (net-zero behavioral isolation)
Driving the module's three client-lifecycle mutations through `DeveloperApi` — `register` (POST `/register`), `saveApp` (PUT `/register/:client_id`), `deleteApp` (DELETE `/register/:client_id`) — must have **bit-identical** effect on the ring:
- `LocalStorage.keys()` must not gain `'sso_audit_log'` as a result of any mutation;
- the stored value `LocalStorage.getItem('sso_audit_log')` must be byte-for-byte identical before and after (exact string equality);
- `AuditLogService().count` and `AuditLogService().entries` must be identical (same count, same in-memory entry instances, same order). Because `record()` inserts into the in-memory list at `:89-94` **before** `_save()`, the in-memory comparisons catch even a write-then-restore of localStorage — a transient `record()` leaves a permanent trace in `_entries`;
- the developer HTTP surface must issue **no** request to any audit endpoint (mirroring the sibling's "no audit request from the login flow" assertion) — the MockClient's recorded request paths must be exactly the three DCR paths.

### REQ-3 — Forge-invisibility (T-12 joint: devtools-forged ring rows are never evidence)
The console's server-fed timeline (landed B6-1a `AuditLogTab`) renders server rows only. A pre-seeded forged ring entry whose vocabulary **matches** a server row (same label string as a server row's `type`, path naming the same resource) must: never render as a row, never merge with or duplicate the server row (`findsOneWidget`, not `findsNWidgets(2)`), never appear as fallback content on server empty/error, and never be written to by the timeline itself. This extends the landed admin-side joints (S3, non-matching path) with the dedup/misattribution hazard variant, pinned from the developer suite.

### REQ-4 — Joint test contract (guard shapes mirror the oidc_login sibling)
- The net-zero test (AC-1) mirrors the sibling harness `test/oidc_login_ring_isolation_test.dart:104-137` step-for-step: pre-seed → post-seed snapshot (with seed-sanity asserts) → drive → assert untouched → `addTearDown(AuditLogService().clear)`; the drive is the `test/developer_api_test.dart` MockClient harness (E8) and needs no widgets (S1, S2).
- The literal-scan test (AC-2) mirrors `test/oidc_login_audit_visibility_guard_test.dart` exactly, with the scan root swapped to `lib/screens/developer` and the same literal-split needles so the guard file can never trip its own scan.
- The forge-invisibility test (AC-3) compiles against the **landed** `AuditLogTab` surface (`required api`/`required capabilities`, `audit_log_tab.dart:26`) — no `[PROPOSED]` BFF/`trace_id`/`tenant_id` wire, no interface guessing.
- Deliverable is guards + tests only: **zero production-code change in `lib/screens/developer/` or `lib/`** (module is already compliant, E1).

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

**AC-1 — T-12 joint: net-zero ring-isolation test in the developer suite** (new file `test/developer_ring_isolation_test.dart`, mirroring `test/oidc_login_ring_isolation_test.dart:104-137`):
1. Pre-seed the ring: `AuditLogService().record(AuditEntry(timestamp: DateTime.now(), method: 'POST', path: '/api/v1/admin/forged', statusCode: 200, label: 'forged'))`; `addTearDown(AuditLogService().clear)`.
2. Post-seed snapshots: `keysBefore = LocalStorage.keys().toSet()`, `valueBefore = LocalStorage.getItem('sso_audit_log')`, `countBefore = AuditLogService().count`, `entriesBefore = AuditLogService().entries`; sanity: `keysBefore` contains `'sso_audit_log'`, `countBefore == 1`.
3. Drive all three mutations through one MockClient-backed `DeveloperApi` (baseUri `https://sso.example`, E8 harness): `register(clientName: 'Acme app', redirectUris: ['https://app.example.test/callback'], scope: 'openid', tokenEndpointAuthMethod: 'none', tokenStrategy: 'jwt', initialAccessToken: 'bootstrap-token')` → mock asserts `POST /register` + Bearer, returns `201 {"client_id":"client-1","registration_access_token":"rat-1"}`; `saveApp(clientId: 'client-1', token: 'rat-1', body: {…})` → mock asserts `PUT /register/client-1` + Bearer, returns `200 {}`; `deleteApp(clientId: 'client-1', token: 'rat-1')` → mock asserts `DELETE /register/client-1` + Bearer, returns `204` (empty body). Record every request URL.
4. Assert net-zero (bit-identical): `LocalStorage.keys().toSet() == keysBefore`; `LocalStorage.getItem('sso_audit_log') == valueBefore` (exact string equality); `AuditLogService().count == countBefore`; `AuditLogService().entries == entriesBefore` (same count, same instances — catches write-then-restore, REQ-2); and the recorded request paths contain no `/api/v1/audit` segment (exactly the three DCR paths).
5. Plain `test()` is sufficient (`DeveloperApi` is pure Dart, S1); VM in-memory `LocalStorage` keeps it deterministic (S2).

**AC-2 — Literal-scan guard** (new file `test/developer_audit_visibility_guard_test.dart`, mirroring `test/oidc_login_audit_visibility_guard_test.dart:21-47`):
- `@TestOn('vm')`; `dart:io` recursive scan of `lib/screens/developer` for `const banned = ['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log']` over every `*.dart` file; `expect(offenders, isEmpty, reason: …)`.
- Document the CI grep form in the file header (must exit 1): `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/developer/`.

**AC-3 — Forge-invisibility: matching-vocabulary forged ring entry never renders** (new file `test/developer_forge_invisibility_test.dart`, developer suite; widget test on the B6-1 server-fed timeline):
1. Pre-seed the ring with a forged entry whose label **matches** a server row's type and whose path names the same resource: `AuditLogService().record(AuditEntry(timestamp: DateTime.now(), method: 'POST', path: '/api/v1/admin/clients', statusCode: 200, label: 'admin_client_created'))`; `addTearDown(AuditLogService().clear)`.
2. Pump the landed timeline with the S4 harness: `SnaplinkAdminApi(baseUrl: 'https://sso.example.test', accessToken: 'admin-token', httpClient: MockClient)` serving `GET /api/v1/audit/events` → `200` with a canned body whose rows include `{"id":"e-1","type":"admin_client_created","outcome":"success","timestamp":"2026-08-05T12:00:00Z","actor_id":"admin-1","client_id":"console","tenant_id":"acme"}`, `count: 2`; `AuditLogTab(api: api, capabilities: capsIncluding('GET', '/api/v1/audit/events'))`.
3. Assert (T-12): the server row renders exactly once — `find.textContaining('admin_client_created')` → `findsOneWidget` (never `findsNWidgets(2)` — the forged duplicate never merges); the forged path/label never render as separate evidence — `find.textContaining('/api/v1/admin/clients')` → `findsNothing`, `find.textContaining('forged')` → `findsNothing`; the header count is server-derived (`'2 entries'`, never `3`).
4. Post-pump: `LocalStorage.keys()` unchanged (the timeline writes nothing to the ring).
- This test is green at HEAD (the timeline is already server-fed, S3/S4); it complements the landed admin AC-3a/3b/3c (non-matching path) with the matching-vocabulary variant.

**AC-4 — Existing suites stay green**: `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart test/entry_ux_test.dart` (plus `test/developer_serving_region_test.dart test/dcr_models_test.dart`, the full module suite) passes unchanged; `test/audit_log_tab_test.dart` (landed AC-3a/3b/3c) stays green alongside the new AC-3.

## 5. Out of scope (no expansion)

- **No production-code change** in `lib/screens/developer/` or anywhere in `lib/` — the module is already compliant (E1); the deliverable is guards + tests.
- The B6-1a timeline rewire itself, the B6-1b ring-demotion mechanism, and their i18n keys — landed sibling change sets, referenced here only as the test surface (E4, S3).
- B6-2 (login-edge generation drill, client_id alignment, census for `auth.login.success`) — sibling directions (`b6-2-*` proposals), out of this direction's scope.
- The BFF audit read (`lib/api/portal_api.dart`, `trace_id`/`tenant_id` wire) — `[PROPOSED]` per the audit-contract batch; the AC-3 timeline leg uses the landed `SnaplinkAdminApi` carrier only.
- Sink-side `audit.event.read` self-audit emission (B1-5) — cross-repo, server-side.
- Ring-demotion release-grep machinery (`Makefile:38-47`) — landed B6-1b.
