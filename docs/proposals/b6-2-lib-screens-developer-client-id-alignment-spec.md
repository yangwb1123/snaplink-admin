# B6-2 Requirements Specification — `client_id` contract alignment, developer-module lens: DCR-backed drill + register→manage pivot regression pin

Module: `lib/screens/developer` (analysis bucket `docs/auto/analyses/lib-screens-developer-3899da21.json`) · Direction: B6-2 · Value: 9 · Risk reduction: 7 · Effort: 2 · Confidence: 9
Status: requirements (decision-gated: Branch A or Branch B, see REQ-0)
Sibling instances: the same direction is specced for other buckets (`b6-2-lib-api-client-id-alignment-spec.md` + `-design.md`, `b6-2-lib-screens-client-id-alignment-spec.md` + `-design.md`). This spec is the **`lib/screens/developer` lens**: it owns the DCR surface (the only in-repo surface that creates OAuth clients), the DCR leg of the shared drill, the register→manage pivot regression pin, and the no-localStorage-forgery joint check with B6-1. Where the lenses overlap (decision record, `SSOAdminClient.firstPartyClientId` constant, `tests/integration/audit_login_drill.py` artifact, `[RESOLVED]` record at `audit-contract-batch-snaplink-console.md:12`), they name the same artifacts so the change set stays single.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. All nine hold, with two line corrections and three module-scope findings:

| Direction citation | Verification result |
|---|---|
| `lib/app_router.dart:35` — `OidcLoginScreen(defaultClientId: 'sso-admin-console')` | **Exact.** `:34-37` `ProductEntry.login => OidcLoginScreen(defaultClientId: 'sso-admin-console', api: …, routeUri: …)`. Outside this module; changed only by the shared decision (REQ-0). |
| `lib/api/sso_client.dart:86,90-92` — `login()` default `clientId` and POST `/auth/login` body | **Exact.** `:86` `String clientId = 'sso-admin-console',`; body keys `:90-94` with `'client_id': clientId` at `:92`. Outside this module; the single-source-of-truth constant lands here per the sibling specs (REQ-0/REQ-1). |
| `test/sso_client_test.dart:18` — asserts `'client_id': 'sso-admin-console'` | **Exact.** `:18` inside the whole-body map assertion (`:16-22`: provider/client_id/scope/resource/credential). |
| `lib/screens/oidc_login/oidc_login_screen.dart:159-161` — `_effectiveClientId` falls back to `widget.defaultClientId` | **Exact.** `:159-161` `String get _effectiveClientId => _params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '');`. The Branch B end-to-end regression pin (sibling `lib/screens` lens REQ-3) walks this chain. |
| `lib/screens/developer/register_panel.dart:107,112` — `client_id` from `/register` response → `onManage` pivot | **Exact.** `:107` `final clientId = result['client_id']?.toString() ?? '';`; `:112` `widget.onManage(clientId, rat, safeSnapshot);` — the response is the **only** source of `client_id` in this module: registration never sends one. |
| `lib/screens/developer/developer_screen.dart:80` — `_openManageWithApp` clientId/token handoff | **1-line drift.** Method declaration is at `:81` (`:78-80` is its doc comment); `:85-90` `_manageKey.currentState?.loadWithRegistration(clientId, token, registrationSnapshot)` (target `manage_panel.dart:46`). |
| `test/developer_api_test.dart:29,46` — register returns `client_id 'client-1'`; round-trip asserted | **Exact lines, overstated claim.** `:29` `return http.Response('{"client_id":"client-1"}', 201);` (mock `/register` response); `:46` `expect(result['client_id'], 'client-1');`. The register→manage **pivot** is actually pinned by `test/dcr_widgets_test.dart:24-30` (mock 201 with `client_id: 'client-1'` → `onManage` fires). Both stay green under REQ-5. |
| `docs/proposals/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` record; acceptance re-anchored | **Exact**, with one stale inner citation: the record says `app_router.dart:55`; actual site is `:35` — corrected when the record is closed (REQ-0). |
| `[PROPOSED]` — whether the IdP/sink registers `console` vs `sso-admin-console` is outside this repo | **Confirmed.** No client registry exists in this repo; `grep -rn "auth.login.success" lib/ test/ tests/` → 0 hits; `lib/services/audit_log_service.dart:66` (`_storageKey = 'sso_audit_log'`) and `lib/services/event_bus.dart` are UI-local, not sink emitters. |

Module-scope facts that shape the requirements:

1. **The module is the only in-repo OAuth-client creation surface.** `developer_api.dart:104` posts `_baseUri.resolve('/register')` (RFC 7591); the request body is built from `DcrClientMetadata.toRegistrationWire()` — `dcr_models.dart:50-63` `typedKeys` has **no** `client_id`, and `:67-69` `protectedResponseKeys` lists `client_id`/`client_secret`/`client_id_issued_at`/`registration_access_token`/`registration_client_uri`. Per RFC 7591 the `client_id` is **server-assigned**: the drill must assert the *response* `client_id`, never send one (REQ-1).
2. **The register→manage handoff is the in-repo round-trip the direction names:** `register_panel.dart:107` (response `client_id`) → `:112` (`onManage`) → `developer_screen.dart:81` (`_openManageWithApp`) → `manage_panel.dart:46` (`loadWithRegistration(clientId, token, snapshot)`). Pinned by `test/developer_api_test.dart:46` and `test/dcr_widgets_test.dart:24-30`.
3. **The module cannot forge sink rows:** `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/developer/` → **0 hits**; the sole ring writer is `lib/api/snaplink_admin_api.dart:82` (`_recordAudit`). The drill's evidence channel is therefore the sink read API only (REQ-4).
4. **Drill harness facts (shared with sibling lenses):** `tests/integration/test_config.py:43-44` defaults `SNAPLINK_TEST_CLIENT_ID` to `sso-admin-console` (the drill precondition asserts this equals the agreed value); `api_login_e2e.py:59-77` completes a real `POST {PROXY}/auth/login` (JWT decode pattern also at `full_integration_test.py:31-33`); the sink read route is documented at `lib/api/snaplink_admin_types.dart:310-312` (`GET /api/v1/audit/events`); harness wiring points `run_all.py` Gate 5 and `full_stack_verify.py` steps 5-6 — the shared drill `tests/integration/audit_login_drill.py` is an existing **untracked** artifact, already wired at `run_all.py:169` / `full_stack_verify.py:113` (uncommitted diff; adopted, not created, by this change set). Contract authority: `docs/campaigns/implementation-gate.md:57` row 2 — "边缘生成验证：login → `auth.login.success`（client_id=sso-admin-console）| sink 出现 sso-admin-console login 事件；无重复 | B4-5" (quote corrected).

---

## 2. Scope

**In scope (developer-module lens)**

- The DCR leg of the shared T-12/G7 drill: assert the **aligned `client_id` is obtainable via POST `/register`** — the `register_panel.dart` path (`developer_api.dart:104` wire), server-assigned per RFC 7591 (REQ-1).
- The drill's login leg keyed to the DCR-obtained `client_id` → **exactly one `auth.login.success` row** in the sink, no duplicates (`implementation-gate.md:57` "无重复") (REQ-2).
- The register→manage pivot regression pin: `register_panel.dart:107,112` → `developer_screen.dart:81` → `manage_panel.dart:46`, kept green by `test/developer_api_test.dart` and `test/dcr_widgets_test.dart` (REQ-3).
- The no-localStorage-forgery joint check with B6-1: the drill's row is evidenced only via `GET /api/v1/audit/events`; zero `AuditLogService` references in this module (REQ-4).
- The shared decision gate (REQ-0): closing the `[MISMATCH]` record at `audit-contract-batch-snaplink-console.md:12` (fixing its stale `app_router.dart:55` → `:35` citation) and, under Branch B, **verifying** `docs/campaigns/implementation-gate.md:57` (already records `client_id=sso-admin-console` — no-op); under Branch A, flipping it to `client_id=console`.

**Out of scope (explicitly not changed by this lens)**

- The login-wire value decision and its regression pins (`lib/api/sso_client.dart:86`, `lib/app_router.dart:35`, `test/sso_client_test.dart:18`, `test/client_id_contract_test.dart`): owned by the sibling `lib/api`/`lib/screens` specs; this lens references the same constant and `[RESOLVED]` record.
- Any `auth.login.success` emission code: no emission path exists in this repo (§1); the event is generated sink/IdP-side and verified only by the drill, marked `[proposed]` if unverifiable (REQ-2).
- B6-1 (server-side audit timeline tab rendering) is a **dependency**, not a change here; `lib/screens/developer/` production files are untouched (REQ-5).
- B4-1 (tenant claim parsing), B4-5 (drill gate owner), BFF trace injection — referenced only as dependencies.

---

## 3. Requirements

### REQ-0 — Decision gate (shared with sibling lenses; this lens adds the DCR evidence channel)

The drift must be resolved by an explicit decision recorded before any code change, exactly as specced by the sibling instances: **Branch A** (rename to `console`: `sso_client.dart:86` + `app_router.dart:35` + `sso_client_test.dart:18`, constantized as `SSOAdminClient.firstPartyClientId`) or **Branch B** (contract exception: verify `implementation-gate.md:57` row 2 — it already records `sso-admin-console`, **no amendment (no-op)** — regression pin through `OidcLoginScreen._effectiveClientId` at `oidc_login_screen.dart:159-161` end-to-end). Either branch: replace `[MISMATCH]` at `audit-contract-batch-snaplink-console.md:12` with `[RESOLVED]` naming the branch + evidence, and fix the stale inner citation `app_router.dart:55` → `:35`.

This lens contributes the **DCR evidence channel**: the drill's DCR leg (REQ-1) is the in-repo-adjacent probe of whether the deployed IdP registers/accepts the aligned `client_id`. If the deployed DCR endpoint returns a `client_id` different from the agreed value, the drill FAILs with output recorded — that output is contract evidence for (or against) the branch choice and is attached to the `[RESOLVED]` record; no false PASS.

**Testable:** `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` returns a record naming Branch A or B with drill evidence attached; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits (stale `:55` gone); under Branch B additionally `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (verify-only — the exception is already recorded at `:57`). Drill output file (PASS/FAIL + sink query) is attached to the record.

### REQ-1 — DCR drill leg: the aligned `client_id` is obtainable via POST `/register` (both branches)

The shared drill artifact `tests/integration/audit_login_drill.py` (named by the sibling specs; wired into `run_all.py` Gate 5 and `full_stack_verify.py` steps 5-6) gains a **DCR leg** executed before its login leg:

1. **Precondition:** assert `CONFIG.client_id` (`tests/integration/test_config.py:43-44`, env `SNAPLINK_TEST_CLIENT_ID`) equals the agreed value for the chosen branch (Branch A `'console'` / Branch B `'sso-admin-console'`).
2. **Register (module wire):** `POST {PROXY}/register` with the `register_panel.dart` request shape — the same body `developer_api.dart:104` sends (`client_name`, `redirect_uris`, `scope`, `token_endpoint_auth_method`, `token_strategy`, optional `grant_types`/`require_pkce`, optional `initial_access_token` bearer). The body **must not** contain `client_id` (RFC 7591 server-assigned; `dcr_models.dart:67-69` protects it).
3. **Assert the aligned id is registered/registerable:** the 2xx response carries `client_id`; assert it **equals the agreed value** (`'console'` under Branch A, `'sso-admin-console'` under Branch B). Any other issued id → drill FAIL with the response printed; this is contract evidence for REQ-0, never a silent pass.
4. **Pivot (module mirror):** use the returned `client_id` for the drill's login leg — mirroring the in-repo handoff `register_panel.dart:107,112` → `developer_screen.dart:81` → `manage_panel.dart:46` — so the id the sink must attribute is exactly the id the module would pivot into manage.

**Testable:** `python3 tests/integration/audit_login_drill.py` against the deployed stack exits PASS only when the DCR response `client_id` equals the agreed value (or is explicitly reported `[proposed]` per REQ-2's fallback); the file contains a `POST` to `/register` and a `client_id` equality assertion (grep-verifiable); `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` hits.

### REQ-2 — Login leg with the DCR-obtained `client_id` → exactly one `auth.login.success` row, no duplicates (both branches)

Extends the sibling-spec drill steps to the DCR-sourced id:

1. **Login:** one real `POST {PROXY}/auth/login` with `client_id` = the DCR-obtained value (REQ-1 step 3) and `CONFIG.login_payload()` (the wire the screens drive at `sso_client.dart:92`); assert `access_token` returned; decode the JWT and extract the `tenant_id` claim → `<t>` (missing claim → drill FAIL with the B4-1 dependency recorded; the drill does not implement claim parsing).
2. **Sink query:** `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` with the Bearer token (documented route `snaplink_admin_types.dart:310-312`); assert **exactly one row** whose `client_id` claim equals the agreed value.
3. **No duplicates** (`implementation-gate.md:57` "无重复"): re-run the login once; re-query; assert exactly two rows total (one per login) with no repeated event id/trace_id; settle ≥ `max(10, SNAPLINK_DRILL_SETTLE_SECONDS)` s; re-query; assert the count is unchanged.
4. **`[proposed]` fallback (sibling-consistent):** sink-side emission is generated outside this repo (0 grep hits, §1). If it cannot be verified from this repo (no deployed stack / no emission observed), the drill logs the query and result, marks steps 2-3 `[proposed]`, records the deviation in the `[RESOLVED]` note, and exits without a false PASS. The DCR leg (REQ-1 steps 2-3) and the login round-trip (step 1) are always asserted when a stack is present.

**Testable:** `python3 tests/integration/audit_login_drill.py` against the deployed stack — exactly-one-row + no-duplicates assertions (steps 2-3) hold or are explicitly `[proposed]`; the reported `client_id` matches the branch's agreed value; exit 0 only on PASS/SKIP.

### REQ-3 — Register→manage pivot regression pin (both branches)

The module's round-trip stays pinned by the **existing** tests, which must remain green and unchanged in shape:

- `test/developer_api_test.dart:29,46` — mock `/register` 201 returns `client_id 'client-1'`; `api.register` surfaces it.
- `test/dcr_widgets_test.dart:24-30` — `OneTimeRegistrationCredentials` with `client_id 'client-1'` fires `onManage` (the pivot contract); `:111-129`/`:168-212` cover the manage-panel client_id entry path.

**Nuance (differs from the sibling `lib/api` lens):** the module's tests use **server-assigned mock ids** (`'client-1'`, `'client-123'`) as fixtures of DCR responses — they are *not* literal sites of the console's own client id. Under Branch A they must **not** be renamed to `'console'`: registration cannot choose `client_id` (REQ-1), so the aligned constant never belongs in this module's register fixtures. The aligned value enters this module only at drill time, via the real DCR response (REQ-1).

**Testable:** `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart` green; `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` is empty under both branches.

### REQ-4 — No-localStorage-forgery joint check with B6-1 (both branches)

The drill's row must be renderable by the server-side audit timeline **without localStorage forgery**:

1. **Module-side guard:** `lib/screens/developer/` keeps zero references to `AuditLogService` / `audit_log_service` / `sso_audit_log` (verified 0 hits today; the sole ring writer is `snaplink_admin_api.dart:82`). The module neither writes nor reads the ring `audit_log_service.dart:66`.
2. **Evidence channel:** the drill's row assertions (REQ-2) read only `GET /api/v1/audit/events` — the ring is never consulted by the drill; a row present in the ring but absent from the server response is not evidence.
3. **Joint acceptance (dependency on B6-1):** once B6-1's server-read timeline lands (`lib/screens/admin` module, `b6-1a-lib-api-auditlogtab-server-read-spec.md`), the T-12 joint widget test pumps the server-backed timeline and asserts the drill's row (identified by `client_id` + `event_types=auth.login.success`) renders from the server response — that rendering test lives in the B6-1 change set; this lens only guarantees the row exists server-side and the module cannot forge it.

**Testable:** `grep -rn "AuditLogService\|sso_audit_log" lib/screens/developer/` → exit 1 (zero hits); `grep -n "audit/events" tests/integration/audit_login_drill.py` hits (server route only, no `sso_audit_log` string in the drill).

### REQ-5 — No-regression / zero-delta boundaries (both branches)

- `lib/screens/developer/**` production files (register_panel, developer_screen, manage_panel, developer_api, dcr_models, dcr_form_controller, dcr_metadata_form, dcr_validation, dcr_credentials, discovery_region_notice) have **zero diff** — the value decision lives outside the module (`sso_client.dart:86`, `app_router.dart:35`).
- `test/developer_api_test.dart`, `test/dcr_widgets_test.dart`, `test/dcr_models_test.dart`, `test/developer_serving_region_test.dart`, `test/list_state_manager_test.dart`, and the sibling-owned `test/sso_client_test.dart` all stay green.
- No new endpoints; no `/auth/login` or `/register` request-shape change beyond the shared constant's value; no `lib/i18n` delta; the drill file respects `engineering.yaml:11` (`max_lines: 400`, ≤ 280 budget per the sibling design).

**Testable:** `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart test/dcr_models_test.dart test/developer_serving_region_test.dart test/list_state_manager_test.dart test/sso_client_test.dart` green; `git diff --stat lib/screens/developer/` empty.

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | Decision recorded — either change `lib/app_router.dart:35` + `lib/api/sso_client.dart:86` default to `'console'` and update `test/sso_client_test.dart:18`, or verify the already-recorded contract exception (`implementation-gate.md:57`) and add a regression test pinning `'sso-admin-console'` through `OidcLoginScreen._effectiveClientId` (`oidc_login_screen.dart:159`) end-to-end | REQ-0: `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` names Branch A or B with drill evidence; stale `app_router.dart:55` citation fixed (`:35` hits). Branch A: `flutter test test/sso_client_test.dart` green with `:18` asserting `'client_id': SSOAdminClient.firstPartyClientId` (resolves `'console'`); Branch B: `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (verify-only — already records the exception) and the sibling `test/client_id_contract_test.dart` pins the `_effectiveClientId` chain end-to-end. The DCR evidence channel (REQ-1) feeds this decision |
| AC-2 | A DCR drill asserts the aligned `client_id` is obtainable via POST `/register` (register_panel.dart path) and that a login with that `client_id` yields exactly one `auth.login.success` row in the sink (`implementation-gate.md:57` "无重复") | REQ-1 + REQ-2: `python3 tests/integration/audit_login_drill.py` against the deployed stack — POST `/register` (developer_api.dart:104 wire, no `client_id` in body) returns `client_id` == agreed value (REQ-1 step 3); login with that id → `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` returns exactly one row with the agreed `client_id` claim; second login → 2 rows, no duplicate event id/trace_id, settle ≥ 10 s, count stable; sink-side assertions `[proposed]`-marked (no false PASS) when emission is unverifiable from this repo; file present in `tests/integration/` and listed in `run_all.py`/`full_stack_verify.py` (grep-verifiable) |
| AC-3 | The server-side audit timeline (B6-1) renders that row without localStorage forgery | REQ-4: `grep -rn "AuditLogService\|sso_audit_log" lib/screens/developer/` → exit 1; the drill asserts the row only via `GET /api/v1/audit/events` (no ring key in the drill file); joint T-12 rendering of the server-backed timeline is B6-1's change set, gated on the row existing server-side (dependency recorded in §5) |
| AC-4 | Existing `test/developer_api_test.dart` and `test/sso_client_test.dart` suites stay green | REQ-5: `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart test/dcr_models_test.dart test/developer_serving_region_test.dart test/list_state_manager_test.dart test/sso_client_test.dart` green; `git diff --stat lib/screens/developer/` empty; `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` empty |

Gate relationship: AC-1 gates AC-2 (the drill asserts the branch's agreed value); AC-3 is a joint acceptance with B6-1 (this lens proves the server-side row + module non-forgery; B6-1 proves the rendering); AC-4 is the unconditional no-regression floor. All four are executable as written.

---

## 5. Dependencies and constraints

- **B4-5** owns the drill gate row (`implementation-gate.md:57`); the T-12/G7 joint acceptance applies.
- **B6-1 / B6-1a** (server-side audit timeline, `lib/screens/admin`) is the rendering half of AC-3; this lens does not implement it and does not depend on it to land (the drill's sink query is stack-side).
- **B4-1** (tenant claim parsing) is a drill dependency: `<t>` is read from the login JWT by the drill itself; a missing claim FAILs with the dependency recorded (REQ-2).
- **Constraint:** the IdP client registry state is external; the DCR leg (REQ-1 step 3) is the only in-repo-adjacent evidence channel and feeds REQ-0.
- **Constraint:** zero production diff in `lib/screens/developer/`; zero emission code; zero `lib/i18n` delta; RFC 7591 server-assigned `client_id` — never sent in a registration body.
- **Consistency:** the shared artifacts (`SSOAdminClient.firstPartyClientId`, `tests/integration/audit_login_drill.py`, `[RESOLVED]` record) match the sibling instance specs (`b6-2-lib-api-client-id-alignment-spec.md`, `b6-2-lib-screens-client-id-alignment-spec.md` + `-design.md`) so all module buckets land one change set.

## 6. Risks and rollback

- **DCR response `client_id` ≠ agreed value** (deployed IdP assigns its own id): drill FAIL with response output — contract evidence for REQ-0; no code change (rollback = current state); the branch choice must be re-examined, not papered over.
- **Wrong branch choice** (drill evidence misread): one-line constant flip + mirror updates in the sibling change set; fully revertible; the `[RESOLVED]` record must be re-opened.
- **Sink-side emission unverifiable** (no deployed stack/emission): AC-2's `[proposed]` fallback applies — the drill logs instead of asserting; no false PASS; the contract row keeps its T-12 joint status with the `[proposed]` note recorded.
- **Module-test literal drift** (renaming server-assigned mock ids to the aligned value): explicitly prohibited by REQ-3 — registration cannot choose `client_id`; the pivot fixtures stay server-shaped.
- **Stale citation** (`audit-contract-batch-snaplink-console.md:12` citing `app_router.dart:55`): corrected to `:35` when the record is closed (REQ-0); census in §1 verified no other doc carries it.
