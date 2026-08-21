# B6-1 — Requirements Specification: oidc_login audit-visibility boundary (module: lib/screens/oidc_login)

> Source direction: "Close the auth-event visibility gap: make the B6-1 server-fed timeline the display path for this module's login edge, and keep the oidc_login module out of the debug-only localStorage ring" (value 8 / risk 8 / effort 4 / confidence 9), from `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`.
> **Status (2026-08-20): implemented and verified.** The module ring-isolation guard and the Phase-B login→server-timeline joint test are green; the historical pre-B6-1 dependency snapshot below is retained for provenance.
> All file/line citations below were re-verified against the repository on 2026-08-07. Corrections to the source citation are marked `[CORRECTION]`.
> **Historical pre-B6-1 snapshot (verified 2026-08-07):** the AuditLogTab server-side read had not yet landed — the tab still used `AuditLogService`. The dependency is now resolved by the landed B6-1 surface; the current implementation record below is authoritative. The module-half and guard checks remain part of the acceptance contract.

## 1. Problem statement (verified)
> Current implementation record (2026-08-20): the previously described B6-1 dependency is landed. The new VM joint test `test/oidc_login_audit_timeline_joint_test.dart` drives the hosted login and AuditLogTab through one MockClient, asserts one credential-bearing login plus one server audit read, renders the server auth.login.success row, and verifies the local ring stays absent; the adapted request surface also pins the expected branding and mount-time probe calls.

`AuditLogTab`'s subtitle claims the timeline shows "All authentication and administrative events recorded on this device" (`audit_log_tab.dart:158`), but the tab's only data source is the localStorage ring: `AuditLogService().entries` (`audit_log_tab.dart:22,43,132`). The ring is written by exactly one caller — `_recordAudit` in `lib/api/snaplink_admin_api.dart:81-84`, invoked only from the admin `_request` mutation path (`snaplink_admin_api.dart:322-324`, `method != 'GET'`). `lib/screens/oidc_login/` — the console's only producer of authentication events — has zero references to `AuditLogService` / `audit_log_service` / the ring key `sso_audit_log` (grep exit 1, verified). Consequences, all verified:

- A fresh console login leaves the timeline empty: the login flow (`OidcLoginApi.login`, `oidc_login_api.dart:57-58`, POST `../auth/login`) is not an admin-API mutation and never passes through the ring writer.
- B6-2's `auth.login.success` edge becomes visible in the console only after B6-1 rewires the tab to `GET /api/v1/audit/events` — the client pattern already proven at `governance_tab.dart:31` (`_auditPath`) and `:183` (`widget.api.get(_auditPath, query: parameters)`).
- `docs/campaigns/implementation-gate.md:56` (B6-1 console row) requires the ring to be demoted to debug-only recording and T-12 joint evidence to come from the server feed ("devtools 伪造不再构成证据"). Module-side, "debug-only" means: this module's login edge is displayed **only** via the server-fed timeline, and **no code in this module may write authoritative entries to the ring**.

The module is already compliant today (zero audit references). This direction's deliverable is therefore **regression guards + the joint T-12 test contract** — no production-code change is expected in `lib/screens/oidc_login/` (mirroring the sibling finding that the console has no native event-generation capability and this leg is "验证 drill + 回归测试，无生产代码改动", `docs/proposals/audit-contract-batch-snaplink-console.md` B6-2 §).

## 2. Evidence verification table

| # | Citation from direction | Verified repository reality | Status |
|---|---|---|---|
| E1 | `lib/screens/oidc_login/` — no `audit_log_service` / `AuditLogService` import anywhere in module | `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → exit 1 (zero hits across all 28 module files). Module storage usage is `SessionStorage` only (`federated_login.dart:100-105`, PKCE verifier/state) — a different namespace, untouched by this direction. | ✅ exact |
| E2 | `lib/services/audit_log_service.dart:33,66-67` — `_storageKey 'sso_audit_log'`, 1000-entry ring | `static const int _maxEntries = 1000;` at **line 65** `[CORRECTION: :33 → :65]`; `static const String _storageKey = 'sso_audit_log';` at line 66; `LocalStorage.setItem(_storageKey, …)` at **:111**; `record()` at :70-76; `clear()` at :101-104. The 1000-entry ring claim is accurate. | ✅ (line 33 → 65) |
| E3 | `lib/api/snaplink_admin_api.dart:81-84,322-324` — sole ring writer, mutations only | `void _recordAudit(...)` at :81, `AuditLogService().record(` at :82, `AuditEntry(` at :83 — exact. `// Record mutation in audit log` :322, `if (method != 'GET') {` :323, `_recordAudit(method, path, response.statusCode);` :324 — exact. `grep -rn "AuditLogService" lib/` → only `snaplink_admin_api.dart`, `audit_log_service.dart`, `audit_log_tab.dart` (3 files); no other writer. | ✅ exact |
| E4 | `lib/screens/admin/audit_log_tab.dart:12,22-26` — timeline reads only `_logService.entries` | `class AuditLogTab extends StatefulWidget` at :15 (doc comment :12-14); `final _logService = AuditLogService();` at **:22** exact; `_logService.entries` reads at **:43** (`_refresh`) and **:132** (`_errorRate`); subtitle `'All authentication and administrative events recorded on this device.'` at **:158** `[CORRECTION: 22-26 → 22/43/132/158]`. | ✅ (subtitle at 158) |
| E5 | `lib/screens/admin/governance_tab.dart:30-31,166-182` — existing GET `/api/v1/audit/events` client pattern | `class _GovernanceTabState` at :30, `static const _auditPath = '/api/v1/audit/events';` at **:31** exact (`_facetPath` :32). `_queryAudit()` at **:167-183**: `AuditQuery.fromJson` :172, `toQueryParameters()` :177, `widget.api.get(_auditPath, query: parameters)` at **:183** `[CORRECTION: 166-182 → 167-183]`. | ✅ (api.get at 183) |
| E6 | `docs/campaigns/implementation-gate.md:56` — B6-1: localStorage ring → debug-only; T-12 联合: devtools 伪造不再构成证据 | Line 56 is the console row 1: "读路径接入（F-06）：审计页调 sink 读 API（tenant_id + trace_id 经 BFF）；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据". | ✅ exact |

Supplemental evidence (module testability, verified at HEAD):

| # | Fact | Location |
|---|---|---|
| S1 | `OidcLoginApi` accepts an injected `httpClient` (MockClient-servable): `OidcLoginApi({http.Client? httpClient, Uri? baseUri})` | `lib/api/oidc_login_api.dart:31-35` |
| S2 | `OidcLoginScreen` accepts injected `api` (and `defaultClientId`, `routeUri`) | `lib/screens/oidc_login/oidc_login_screen.dart:58-62` |
| S3 | Login leg widget-harness precedent: `_LoginHarness` — MockClient keyed by method+path with the credential-bearing `POST /auth/login` filter (`body['credential'] is Map`), mount-time probe excluded | `test/oidc_login_screen_client_id_test.dart:26-74` (class), `:67` (pump), `:88` (submit: Username/Password `enterText` + `FilledButton` 'Sign in' tap) |
| S4 | Timeline leg widget-harness precedent: `_api(routes)` MockClient keyed by `request.url.path`, `_caps(paths)` capability set — reusable as-is for the joint test's admin half | `test/admin_governance_security_test.dart:12-32` |
| S5 | Module-scan test precedent (census pattern, `@TestOn('vm')`, `dart:io` File scans of `lib/screens/oidc_login`) — the home for the new import-guard scan; includes the literal-split trick so the guard file never self-hits | `test/oidc_login_handle_success_census_test.dart:1-9,97-104` |
| S6 | `LocalStorage` on VM is an in-memory implementation with `keys()` — the "no localStorage write" assertion is deterministic in widget tests; `AuditLogService()` is a singleton with `record()`/`clear()` for pre-seeding | `lib/services/local_storage.dart:11-25`, `lib/services/local_storage_memory.dart:1-13`, `lib/services/audit_log_service.dart:70-76,101-104` |
| S7 | B6-1 has **not** landed: `audit_log_tab.dart` has no `SnaplinkAdminApi` import, no `api`/`capabilities` params; the B6-1 pipeline runs (`rewire-auditlogtab-…`, `wire-auditlogtab-…`, `b6-1a-…`) all stopped before implementation | HEAD tree + `docs/auto/state.jsonl` / run artifact listings |
| S8 | The approved B6-1 surface the joint test compiles against: `AuditLogTab({required SnaplinkAdminApi api, required SnaplinkAdminCapabilities capabilities})`; server-read ACs in the sibling spec | `docs/proposals/b6-1a-lib-api-auditlogtab-server-read-spec.md` REQ-2, AC-1/AC-2/AC-5 |

## 3. Requirements

### REQ-1 — Zero-audit-reference floor (static guard; module invariant)
`lib/screens/oidc_login/**` must keep **zero** references to `AuditLogService`, `audit_log_service`, and the ring key `sso_audit_log` — no imports, no construction, no reads, no writes, no string literals. This is the module-side encoding of "localStorage ring → debug-only recording" (`implementation-gate.md:56`): debug-only means the module's login edge is evidenced exclusively through the server feed, never through the ring. Verified compliant at HEAD (E1); enforced by a Dart scan test (AC-2) plus a grep guard.

### REQ-2 — The login flow leaves the ring untouched (behavioral isolation)
Completing an `OidcLoginScreen` login (all seven success paths funnel into `_handleSuccess`, `oidc_authorization_flow.dart:8`) must not create, modify, or clear the ring:
- `LocalStorage.keys()` must never gain `'sso_audit_log'` as a result of the login flow;
- pre-existing ring contents (debug entries seeded by `AuditLogService().record`) must be unchanged (same count, same entries) after the login flow completes;
- no request may be issued to any audit endpoint by the login flow itself (the module's HTTP surface is `OidcLoginApi` only).

Existing `SessionStorage` usage in the module (`federated_login.dart:100-105`, PKCE verifier/state) is a different storage namespace and is explicitly **out of scope** — REQ-2 targets the audit ring key only. Testable at HEAD with zero `lib/` edits (S6).

### REQ-3 — The login edge's display path is the server feed only (renderability, no fabrication)
The module must not fabricate or emit audit events client-side: the `'auth.login.success'` emission string must remain absent from the module (already pinned by the census test `test/oidc_login_handle_success_census_test.dart:97-104`, REQ-4 #5 — must stay green), and the module must not read the ring to render any login evidence. Renderability of the login edge is proven by the joint T-12 test (AC-1): the `auth.login.success` row displayed by the rewired timeline must originate from the `GET /api/v1/audit/events` server response served by the same backend mock that served the login POST — never from any local state.

### REQ-4 — Joint test contract (login leg + timeline leg on one backend mock)
The T-12 joint test must drive both legs through a **single path-keyed MockClient**:
- **Login leg:** `OidcLoginApi(baseUri: …, httpClient: mockClient)` injected into `OidcLoginScreen(api: …)`; complete an interactive login (Username/Password → 'Sign in'), exactly one credential-bearing `POST /auth/login` (D9 filter: `body['credential'] is Map`), answered 200 `{"access_token":"t","session_id":"s"}`.
- **Timeline leg (post-B6-1):** wrap the same `MockClient` in `SnaplinkAdminApi(baseUrl: …, accessToken: …, httpClient: mockClient)` and pump `AuditLogTab(api: …, capabilities: …)` per the B6-1 surface (S8); the mock answers `GET /api/v1/audit/events` 200 with a body whose rows include the `auth.login.success` entry (row field mapping is the B6-1 tab's defensive mapping per the sibling spec REQ-4; fixture uses `method`/`path`/`status`/`label` fields, with the login row as `label: 'auth.login.success'`, `path: '/auth/login'`).
- **Negative space:** the recorded request-path set of the whole test must be exactly `{/auth/login, /api/v1/audit/events}` (no `/api/v1/audit/facets`, no ring writes) — modulo the tab's own mount-time behavior defined by B6-1's change set.

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

**AC-1 — Direction acceptance (1): joint login → timeline rendering, ring untouched.**
Two-phase structure because B6-1 has not landed (S7); both phases use the single-mock contract of REQ-4.

- *Phase A — module half, green at HEAD (new file `test/oidc_login_ring_isolation_test.dart`, `@TestOn('vm')`):*
  1. Pre-seed the ring: `AuditLogService().record(AuditEntry(timestamp: DateTime.now(), method: 'POST', path: '/api/v1/admin/forged', statusCode: 200, label: 'forged'))`; record `count` and the seeded entries; `addTearDown(AuditLogService().clear)`.
  2. Pump `OidcLoginScreen(api: OidcLoginApi(baseUri: …, httpClient: mockClient))` with the `_LoginHarness`-style mock (S3); complete login via `_LoginHarness.submit` (Username `ada@example.com` / Password → tap 'Sign in'); `pumpAndSettle`.
  3. Assert: exactly one credential-bearing login POST; `LocalStorage.keys()` does **not** contain `'sso_audit_log'`; ring count and seeded entries are unchanged (login flow wrote nothing).
- *Phase B — timeline half, lands with B6-1's change set (new file `test/oidc_login_audit_timeline_joint_test.dart`):*
  4. Same single MockClient additionally serves `GET /api/v1/audit/events` → 200 with a body whose rows include `{…, "method": "POST", "path": "/auth/login", "status": 200, "label": "auth.login.success"}` (fields per the B6-1 tab's REQ-4 mapping; the tab's `_api`/`_caps` harness per S4).
  5. After the login completes, pump `AuditLogTab(api: snaplinkAdminApiOnSameMock, capabilities: capsIncluding('GET', '/api/v1/audit/events'))`; `pumpAndSettle`.
  6. Assert: the server-returned row renders — `find.textContaining('auth.login.success')` (EVENT column) and `find.textContaining('/auth/login')` (PATH column), and the entries counter shows the server count; **and** `LocalStorage.keys()` still has no `'sso_audit_log'` (no localStorage write occurred during the whole login+timeline flow).
  7. Assert the request-path set is exactly `{/auth/login, /api/v1/audit/events}` (no other audit endpoints).
  - Dependency record (goes in the B6-1 change set): the test's timeline leg compiles only after `AuditLogTab` gains `api`/`capabilities` (S8, b6-1a REQ-2); B6-1's change set must land it together with the tab rewrite — the same commit that updates `test/admin_support_tabs_test.dart` per b6-1a AC-5.

**AC-2 — Direction acceptance (2): static/import guard test.**
New file `test/oidc_login_audit_visibility_guard_test.dart` (census pattern, S5; `@TestOn('vm')`, `dart:io`):
1. Recursively scan `lib/screens/oidc_login/` for `.dart` files; assert **zero** occurrences of `AuditLogService`, `audit_log_service`, and the ring key `sso_audit_log` (split the literals in the guard source — `'sso_audit_' 'log'` — so the guard file itself can never trip the scan if it is widened to `test/`).
2. Grep form for CI and for the joint gate: `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → **exit 1** (verified at HEAD; a forgotten import fails this immediately, red not silent).
3. Must pass at HEAD with zero `lib/` edits (REQ-1 floor is already met — this test pins the floor).

**AC-3 — Direction acceptance (3): devtools-forged `sso_audit_log` content still never renders in the timeline (existing B6-1 acceptance).**
Delivered by B6-1's change set as b6-1a AC-2 (seed the ring with a distinctive forged entry, serve server rows via MockClient, assert the forged path/method/status never renders). This module's obligation: its change set adds **zero** ring reads or writes (REQ-1/REQ-2), so the forgery barrier holds. Verification at the joint gate:
- `grep -rn "AuditLogService\|sso_audit_log\|audit_log_service" lib/screens/oidc_login/` → exit 1 (AC-2);
- b6-1a AC-2 test remains green in the tree;
- no module file calls `LocalStorage.setItem` (grep `LocalStorage` in `lib/screens/oidc_login/` → exit 1; today only `SessionStorage` appears, E1).

## 5. Dependency, scope guard, and expected change set

**Dependencies (explicit):**
- B6-1's `AuditLogTab` rewrite (surface per `b6-1a-lib-api-auditlogtab-server-read-spec.md` REQ-2) is the compile-time prerequisite for AC-1 Phase B and for AC-3's timeline rendering. Not landed at HEAD (S7); the joint file ships with B6-1's change set, whose AC-1/AC-2/AC-5 it extends.
- B6-2 (client_id alignment / edge drill) is a sibling direction; the joint test asserts **rendering of a server-returned `auth.login.success` row** — it deliberately does not assert the `client_id` wire value or sink emission (those live in the B6-2 legs).

**Out of scope (no changes here):** `lib/screens/admin/audit_log_tab.dart` (B6-1), ring demotion/debug labeling (B6-1b), `lib/api/snaplink_admin_api.dart` ring writer (unchanged), `client_id` values (B6-2), `tests/integration/audit_login_drill.py` (device-leg sibling), and the `AuditQuery`/facets surface (B6-1). No production-code change is expected in `lib/screens/oidc_login/`; the change set is: `test/oidc_login_ring_isolation_test.dart` (AC-1 Phase A), `test/oidc_login_audit_visibility_guard_test.dart` (AC-2), and — with B6-1 — `test/oidc_login_audit_timeline_joint_test.dart` (AC-1 Phase B). If the implementer adds a doc comment in the module stating the debug-only boundary, it must not introduce the banned literals (REQ-1).
