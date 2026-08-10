# B6-2 Requirements Specification — `client_id` contract alignment, device-module lens: device-entry redirect-leg pin + drill login leg

Module: `lib/screens/device` (analysis bucket `docs/auto/analyses/lib-screens-device-fb030ae1.json`) · Direction: B6-2 · Value: 7 · Risk reduction: 6 · Effort: 2 · Confidence: 9
Status: requirements (decision-gated: Branch A or Branch B, see REQ-0)
Sibling instances: the same direction is specced for other buckets (`b6-2-lib-api-client-id-alignment-spec.md` + `-design.md`, `b6-2-lib-screens-client-id-alignment-spec.md` + `-design.md`, `b6-2-lib-screens-developer-client-id-alignment-spec.md` + `-design.md`). This spec is the **`lib/screens/device` lens**: it owns the device-entry login leg (`device_verify_screen.dart:172-181` and its call sites `:76/:226/:369`) and its regression pin in `test/entry_ux_test.dart`, the device-leg facts of the shared drill (`tests/integration/audit_login_drill.py`), and the no-localStorage-forgery joint check for this module. Where the lenses overlap (decision record, `SSOAdminClient.firstPartyClientId` constant, `audit_login_drill.py` artifact, `[RESOLVED]` record at `audit-contract-batch-snaplink-console.md:12`), they name the same artifacts so the change set stays single.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. All seven hold; one inner citation in the contract record is stale, and one sibling claim needed a correction (module-scope finding 4).

| Direction citation | Verification result |
|---|---|
| `lib/screens/device/device_verify_screen.dart:172-181` — `_redirectToLogin` → `/login/?redirect=/device/verify…`, the device-entry login leg | **Exact.** `:172` `void _redirectToLogin()`; `:174-177` target `Uri(path: '/device/verify', queryParameters: code.isEmpty ? null : {'user_code': code})`; `:178-180` `ProductApiOrigin.baseUri.resolve('/login/').replace(queryParameters: {'redirect': target})`; `:181` `BrowserNavigation.replaceLocation(login.toString())`. Call sites: `:76` (`initState`, no session — the primary entry leg), `:226` (`_verify`, token null/empty — session-expiry re-entry), `:369` (`signInAgain` TextButton after 401 at `:248-249`). All three share the one function, so a single pin covers the leg. |
| `lib/app_router.dart:35` — `OidcLoginScreen(defaultClientId: 'sso-admin-console')` | **Exact.** `:34-37` `ProductEntry.login => OidcLoginScreen(defaultClientId: 'sso-admin-console', api: …, routeUri: …)`. Outside this module; changed only by the shared decision (REQ-0). |
| `lib/api/sso_client.dart:86,90-92` — `login()` default `clientId` and POST `/auth/login` body | **Exact.** `:86` `String clientId = 'sso-admin-console',`; `:90` `_post('/auth/login', {`; `:92` `'client_id': clientId,` (remaining keys `:91-95`: provider/scope/resource/credential). Outside this module; the single-source-of-truth constant lands here per the sibling specs (REQ-0). |
| `test/sso_client_test.dart:18` — asserts `'client_id': 'sso-admin-console'` | **Exact.** `:16-22` whole-body map assertion (`provider`/`client_id`/`scope`/`resource`/`credential`); `:18` `'client_id': 'sso-admin-console',`. |
| `docs/proposals/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` record; acceptance re-anchored to code reality | **Exact, with one stale inner citation:** the record says `app_router.dart:55`; actual site is `:35` — fixed when the record is closed (REQ-0). |
| `docs/campaigns/implementation-gate.md:57` — B6-2 console row | **Exact.** Row 2 (console): "边缘生成验证：login → `auth.login.success`（client_id=sso-admin-console） | sink 出现 sso-admin-console login 事件；无重复 | B4-5" (quote corrected: the gate records `sso-admin-console`). This is the contract authority the acceptance names. |
| `test/device_verify_api_test.dart:31-50` — POST `/device/verify` carries no `client_id` | **Exact.** `:31-50` approve test pins the whole body: `expect(jsonDecode(request.body), {'user_code': 'WXYZ-1234', 'approve': true})` (`:44-47`); the check GET (`:18-29`) pins `?check=WXYZ-1234` only. The device wire carries no `client_id` and no tenant context. |
| `[PROPOSED]` — whether the IdP/sink registers `console` vs `sso-admin-console`, and `auth.login.success` emission, are outside this repo | **Confirmed.** `grep -rn "auth.login.success" lib/ test/ tests/` → 0 hits (only requirement text in `docs/campaigns/campaign-console-b6.yaml:37` and `implementation-gate.md:57`); no client registry exists in this repo; `lib/services/audit_log_service.dart` (`_storageKey = 'sso_audit_log'` localStorage ring, sole writer `lib/api/snaplink_admin_api.dart:82`) and `lib/services/event_bus.dart` (`DataChangedEvent`) are UI-local, not sink emitters. |

Module-scope facts that shape the requirements:

1. **The device module's login leg is a pure redirect — it never POSTs `/auth/login` itself.** The leg is `_redirectToLogin` → `/login/?redirect=/device/verify…`; the login screen then carries the wire: `app_router.dart:34-37` `OidcLoginScreen(defaultClientId: 'sso-admin-console')` → `_effectiveClientId` (`lib/screens/oidc_login/oidc_login_screen.dart:159-161`) → `lib/screens/oidc_login/oidc_provider_flow.dart:54` (`'client_id': _effectiveClientId`) → `lib/api/oidc_login_api.dart:47,52` → `sso_client.dart:92` POST `/auth/login`. Therefore the device-entry login's wire `client_id` is **fully determined by `app_router.dart:35` (+ the `sso_client.dart:86` default)**; the redirect URL itself carries only `redirect`. The redirect target is honored by the login screen (`oidc_login_screen.dart:71-80` `_safeRedirectTarget` reads `queryParametersAll['redirect']`) — post-login continuation is screens-lens territory; this lens pins URL **construction** only.
2. **The module cannot contribute `client_id` evidence on its own wire:** `test/device_verify_api_test.dart:31-50` pins POST `/device/verify` to `{user_code, approve}` and the check GET to `?check=…` only. The device-driven login's edge event is therefore verifiable only via the redirect-leg drill plus constant alignment (exactly the direction's claim).
3. **The redirect leg is VM-widget-testable.** `BrowserNavigation.replaceLocation` on the test VM goes through `lib/services/browser_navigation_stub.dart`, which records `_currentUri`; `BrowserNavigation.currentUri` and `resetForTest()` exist and are already used in `test/setup_screen_test.dart:13` and `test/widgets_services_test.dart:24`. `ProductApiOrigin.baseUri` on VM resolves `AppSettings.instance.ssoBaseUrlOverride ?? 'https://sso.ywbsd.site'` (`product_api_origin.dart:10,24`) — the widget test asserts **path + query**, never host.
4. **Correction to the sibling `lib/screens` lens:** its claim "no own `client_id` literal (grep: 0 hits in `lib/screens/device/`)" is imprecise — `device_verify_screen.dart:62` and `device_verify_widgets.dart:16` read `preview['client_id']`. These are **server-preview response reads** (the device-owner client shown in the approval card, feeding `_hasSafeApprovalPreview`), not login-wire literals; there is no `'console'`/`clientId` **login** literal in this module. No change is needed to them under either branch.
5. **No forgery channel:** `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/device/ test/device_verify_api_test.dart test/entry_ux_test.dart` → 0 hits. The drill's evidence channel is the sink read API only (REQ-4).
6. **Drill harness facts (shared with sibling lenses):** `tests/integration/test_config.py:43-44` defaults `SNAPLINK_TEST_CLIENT_ID` to `sso-admin-console` (the drill precondition asserts this equals the agreed value); `tests/integration/api_login_e2e.py:59-77` completes a real `POST {PROXY}/auth/login` (`CONFIG.login_payload()`, JWT decode); the sink read route is documented at `lib/api/snaplink_admin_types.dart:310-312` (`GET /api/v1/audit/events`); harness wiring points `run_all.py` Gate 5 (`:124`) and `full_stack_verify.py` steps 5-6; `test/entry_ux_test.dart` already pumps `DeviceVerifyScreen` with `accessTokenProvider` + `MockClient` (`:114-132`) — the pattern REQ-1 extends. Contract authority: `docs/campaigns/implementation-gate.md:57` row 2.

---

## 2. Scope

**In scope (device-module lens)**

- The device-entry redirect-leg regression pin: two widget tests added to `test/entry_ux_test.dart` that pump `DeviceVerifyScreen` without a session and assert the login target URL carries `redirect=/device/verify` (with and without `user_code`) (REQ-1).
- The device-leg facts of the shared T-12/G7 drill: the login is performed through the device redirect leg (redirect param `=/device/verify`), the `/auth/login` wire carries the aligned `client_id`, and the deployed sink shows **exactly one** `auth.login.success` row with that `client_id`, no duplicates (`implementation-gate.md:57` "无重复") (REQ-3).
- The no-localStorage-forgery joint check with B6-1 for this module: zero `AuditLogService`/ring references; the drill reads only `GET /api/v1/audit/events` (REQ-4).
- Participation in the shared decision gate (REQ-0): closing the `[MISMATCH]` record at `audit-contract-batch-snaplink-console.md:12` (fixing its stale `app_router.dart:55` → `:35` citation) and, under Branch B, **verifying** `docs/campaigns/implementation-gate.md:57` (already records `client_id=sso-admin-console` — no-op); under Branch A, flipping it to `client_id=console`.

**Out of scope (explicitly not changed by this lens)**

- The login-wire value decision and its regression pins (`lib/api/sso_client.dart:86`, `lib/app_router.dart:35`, `test/sso_client_test.dart:18`, `test/client_id_contract_test.dart`): owned by the sibling `lib/api`/`lib/screens` specs; this lens references the same constant and `[RESOLVED]` record.
- Any `auth.login.success` emission code: no emission path exists in this repo (§1); the event is generated sink/IdP-side and verified only by the drill, marked `[proposed]` if unverifiable (REQ-3).
- Post-login redirect continuation (`_safeRedirectTarget` at `oidc_login_screen.dart:71-80`, `HostedLoginRoute`): owned by the `lib/screens` lens; this lens pins only the URL the device screen constructs.
- B6-1 (server-side audit timeline tab rendering) is a **dependency**, not a change here; `lib/screens/device/**` production files are untouched (REQ-5).
- B4-1 (tenant claim parsing), B4-5 (drill gate owner), BFF trace injection — referenced only as dependencies.

---

## 3. Requirements

### REQ-0 — Decision gate (shared with sibling lenses; this lens adds no new branch input)

The drift must be resolved by an explicit decision recorded before any code change, exactly as specced by the sibling instances: **Branch A** (rename to `console`: `sso_client.dart:86` + `app_router.dart:35` + `sso_client_test.dart:18`, constantized as `SSOAdminClient.firstPartyClientId`) or **Branch B** (contract exception: verify `implementation-gate.md:57` row 2 — it already records `sso-admin-console`, **no amendment (no-op)** — regression pin through `OidcLoginScreen._effectiveClientId` at `oidc_login_screen.dart:159-161` end-to-end). Either branch: replace `[MISMATCH]` at `audit-contract-batch-snaplink-console.md:12` with `[RESOLVED]` naming the branch + drill evidence, and fix the stale inner citation `app_router.dart:55` → `:35`.

This lens consumes the decision rather than feeding it: the device module contains no login-wire literal (module-scope finding 4), so both branches leave `lib/screens/device/` production code unchanged; the branch's value enters the device leg only via `app_router.dart:35` at drill time (REQ-3).

**Testable:** `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` returns a record naming Branch A or B with drill evidence attached; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits (stale `:55` gone); under Branch B additionally `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (verify-only — the exception is already recorded at `:57`).

### REQ-1 — Device-entry redirect-leg regression pin: unauthenticated entry → `/login/?redirect=/device/verify` (both branches, module-owned)

`test/entry_ux_test.dart` gains a widget test group (extending the existing `DeviceVerifyScreen` pump pattern at `:114-132`) that drives `_redirectToLogin` (`device_verify_screen.dart:172-181`) and pins the login leg:

1. **No session, code in route:** `BrowserNavigation.resetForTest()`; pump `DeviceVerifyScreen(accessTokenProvider: () => null, routeUri: Uri.parse('https://sso.example/device/verify?user_code=WXYZ-1234'))`; `pumpAndSettle()` (the redirect is scheduled via `addPostFrameCallback` at `:76`); assert `BrowserNavigation.currentUri.path == '/login/'` and `currentUri.queryParameters['redirect'] == '/device/verify?user_code=WXYZ-1234'`.
2. **No session, no code:** same pump with `routeUri: Uri.parse('https://sso.example/device/verify')` (or no `routeUri`); assert `redirect == '/device/verify'` with no `user_code` key (`:174-177` null branch).

The assertion is on path + query only (never scheme/host — VM baseUri is `AppSettings`-dependent, §1 finding 3). `accessTokenProvider: () => null` guarantees the leg is taken without touching `Session.read()`. Because call sites `:76/:226/:369` all invoke the same `_redirectToLogin`, this pin transitively covers the 401-expiry re-entry (`signInAgain` after `Session.clear()` at `:248-249`) — no additional flow-driving is required for the direction's claim.

**Testable:** `grep -n "'/login/'" test/entry_ux_test.dart` hits and `grep -n "'/device/verify'" test/entry_ux_test.dart` hits (both assertions present, both branches of the `user_code` query); `flutter test test/entry_ux_test.dart` green; `flutter test test/device_verify_api_test.dart` unchanged and green.

### REQ-2 — The device wire and module surface stay `client_id`-free and emission-free (both branches)

- `test/device_verify_api_test.dart:31-50` keeps pinning POST `/device/verify` to `{user_code, approve}` — no `client_id` is added to the device wire, now or later; the module cannot and must not attribute auth events itself (module-scope finding 2).
- No `auth.login.success` emission code is added anywhere in this repo (0 grep hits today, §1); the device module neither emits nor records auth events.
- The two `preview['client_id']` reads (`device_verify_screen.dart:62`, `device_verify_widgets.dart:16`) are server-preview response reads and stay untouched under both branches (module-scope finding 4).

**Testable:** `grep -n "client_id" test/device_verify_api_test.dart` → exit 1 (0 hits; the check GET pins `queryParameters['check']` at `:22`, the POST pins `{user_code, approve}` at `:44-47`); `grep -rn "auth.login.success" lib/screens/device/` → exit 1.

### REQ-3 — Drill: login through the device redirect leg → exactly one `auth.login.success` row with the aligned `client_id`, no duplicates (both branches)

The shared drill artifact `tests/integration/audit_login_drill.py` (named by the sibling specs; wired into `run_all.py` Gate 5 and `full_stack_verify.py` steps 5-6) performs its login leg **through the device redirect leg**, i.e. the exact leg `_redirectToLogin` constructs and REQ-1 pins:

1. **Precondition:** assert `CONFIG.client_id` (`tests/integration/test_config.py:43-44`, env `SNAPLINK_TEST_CLIENT_ID`) equals the agreed value for the chosen branch (Branch A `'console'` / Branch B `'sso-admin-console'`).
2. **Device redirect-leg shape:** the drill's login entry URL is `/login/?redirect=/device/verify` — built by the same rule as `device_verify_screen.dart:174-180` (assert the `redirect` query parameter equals `/device/verify`, with the `user_code` form used when a code is exercised). This identifies the leg as the device-entry one; the exact construction is pinned by REQ-1's widget tests.
3. **Login:** one real `POST {PROXY}/auth/login` with `client_id` = the agreed value and `CONFIG.login_payload()` — the same wire the device-funneled `OidcLoginScreen` drives (`app_router.dart:35` → `oidc_login_screen.dart:159-161` → `oidc_provider_flow.dart:54` → `sso_client.dart:92`); assert `access_token` returned; decode the JWT and extract the `tenant_id` claim → `<t>` (missing claim → drill FAIL with the B4-1 dependency recorded; the drill does not implement claim parsing).
4. **Sink query:** `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` with the Bearer token (documented route `snaplink_admin_types.dart:310-312`); assert **exactly one row** whose `client_id` claim equals the agreed value.
5. **No duplicates** (`implementation-gate.md:57` "无重复"): re-run the login once; re-query; assert exactly two rows total (one per login) with no repeated event id/trace_id; settle ≥ `max(10, SNAPLINK_DRILL_SETTLE_SECONDS)` s; re-query; assert the count is unchanged.
6. **`[proposed]` fallback (sibling-consistent):** sink-side emission is generated outside this repo (0 grep hits, §1). If it cannot be verified from this repo (no deployed stack / no emission observed), the drill logs the query and result, marks steps 4-5 `[proposed]`, records the deviation in the `[RESOLVED]` note, and exits without a false PASS. Steps 1-3 are always asserted when a stack is present.

**Testable:** `python3 tests/integration/audit_login_drill.py` against the deployed stack — the drill asserts the redirect leg shape (step 2), the login POST carries the aligned `client_id` (step 3), and exactly-one-row + no-duplicates assertions (steps 4-5) hold or are explicitly `[proposed]`; exit 0 only on PASS/SKIP; `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` hits.

### REQ-4 — No-localStorage-forgery joint check with B6-1 (both branches)

The drill's row must be renderable by the server-side audit timeline **without localStorage forgery**:

1. **Module-side guard:** `lib/screens/device/` keeps zero references to `AuditLogService` / `audit_log_service` / `sso_audit_log` (verified 0 hits today, §1 finding 5; the sole ring writer is `snaplink_admin_api.dart:82`). The module neither writes nor reads the ring `audit_log_service.dart:66`.
2. **Evidence channel:** the drill's row assertions (REQ-3 steps 4-5) read only `GET /api/v1/audit/events` — the ring is never consulted; a row present in the ring but absent from the server response is not evidence.
3. **Joint acceptance (dependency on B6-1):** once B6-1's server-read timeline lands (`lib/screens/admin` module, `b6-1a-lib-api-auditlogtab-server-read-spec.md`), the T-12 joint widget test pumps the server-backed timeline and asserts the drill's row (identified by `client_id` + `event_types=auth.login.success`) renders from the server response — that rendering test lives in the B6-1 change set; this lens only guarantees the row exists server-side and the module cannot forge it.

**Testable:** `grep -rn "AuditLogService\|sso_audit_log" lib/screens/device/ test/device_verify_api_test.dart test/entry_ux_test.dart` → exit 1 (zero hits); `grep -n "audit/events" tests/integration/audit_login_drill.py` hits (server route only, no `sso_audit_log` string in the drill).

### REQ-5 — No-regression / zero-delta boundaries (both branches)

- `lib/screens/device/**` production files (`device_verify_screen.dart`, `device_verify_api.dart`, `device_verify_widgets.dart`) have **zero diff** — the value decision lives outside the module (`sso_client.dart:86`, `app_router.dart:35`), and the module contains no login-wire literal to update (§1 finding 4).
- `test/entry_ux_test.dart` gains only the REQ-1 test group; its existing device tests (`:114-132` and neighbors) are unchanged.
- `test/device_verify_api_test.dart` is unchanged and green under both branches.
- `test/sso_client_test.dart` is updated only by the sibling `lib/api`/`lib/screens` change set (REQ-0); this lens does not touch it.
- No new endpoints; no request-shape change to `/device/verify` or `/auth/login` beyond the shared constant's value; no `lib/i18n` delta; the drill file respects `engineering.yaml:11` (`max_lines: 400`, ≤ 280 budget per the sibling design).

**Testable:** `flutter test test/entry_ux_test.dart test/device_verify_api_test.dart` green; `git diff --stat lib/screens/device/` empty; `git diff test/device_verify_api_test.dart` empty; `git diff test/entry_ux_test.dart` contains only the REQ-1 group.

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | If the contract constant is authoritative — change `defaultClientId` (`app_router.dart:35`) and `sso_client.dart:86` default to `'console'`, update `test/sso_client_test.dart:18` to assert `'client_id': 'console'` in the POST `/auth/login` body, and extend `entry_ux_test.dart` with a widget test that drives `DeviceVerifyScreen`'s redirect (`device_verify_screen.dart:172-181`) and asserts the target login URL carries `redirect=/device/verify` | REQ-0 + REQ-1: `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` names Branch A with drill evidence; stale `app_router.dart:55` citation fixed (`:35` hits); Branch A rename pinned by the sibling-owned `flutter test test/sso_client_test.dart` green with `:18` asserting `'client_id': SSOAdminClient.firstPartyClientId` (resolves `'console'`); module-owned: `grep -n "'/login/'" test/entry_ux_test.dart` and `grep -n "'/device/verify'" test/entry_ux_test.dart` hit in the new widget test, and `flutter test test/entry_ux_test.dart` green |
| AC-2 | If `'sso-admin-console'` is authoritative — verify the already-recorded contract exception (`implementation-gate.md:57`) and pin it end-to-end | REQ-0 Branch B: `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (verify-only — already records the exception); the sibling `test/client_id_contract_test.dart` pins the `_effectiveClientId` chain (`oidc_login_screen.dart:159-161`) end-to-end; REQ-1's widget pin is branch-independent and still green |
| AC-3 | Either way, a drill logs in through the device redirect leg and asserts the deployed sink shows exactly one `auth.login.success` row whose `client_id` equals the aligned constant, and the B6-1 timeline renders that row server-side without local forgery | REQ-3 + REQ-4: `python3 tests/integration/audit_login_drill.py` against the deployed stack — redirect-leg shape asserted (redirect `=/device/verify`), login POST with the agreed `client_id`, `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` returns exactly one row with the agreed `client_id` claim; second login → 2 rows, no duplicate event id/trace_id, settle ≥ 10 s, count stable; sink-side assertions `[proposed]`-marked (no false PASS) when emission is unverifiable from this repo; file present in `tests/integration/` and listed in `run_all.py`/`full_stack_verify.py` (grep-verifiable); `grep -rn "AuditLogService\|sso_audit_log" lib/screens/device/` → exit 1; the joint T-12 server-rendering of that row is B6-1's change set (dependency recorded in §5) |

Gate relationship: AC-1/AC-2 are mutually exclusive (the recorded decision picks one); REQ-1's widget pin is unconditional and gates neither — it is the module's standing regression floor. AC-3 is the T-12/G7 joint acceptance and depends on the decision (the drill asserts the branch's agreed value); its B6-1 rendering half is a dependency, not a change here. All three are executable as written.

---

## 5. Dependencies and constraints

- **B4-5** owns the drill gate row (`implementation-gate.md:57`); the T-12/G7 joint acceptance applies.
- **B6-1 / B6-1a** (server-side audit timeline, `lib/screens/admin`) is the rendering half of AC-3; this lens does not implement it and does not depend on it to land (the drill's sink query is stack-side).
- **Sibling B6-2 lenses** own the value decision and its pins (`sso_client.dart:86`, `app_router.dart:35`, `sso_client_test.dart:18`, `test/client_id_contract_test.dart`, DCR leg); this lens's change set is only `test/entry_ux_test.dart` + the drill file's device-leg steps + the `[RESOLVED]` record participation.
- **B4-1** (tenant claim parsing) is a drill dependency: `<t>` is read from the login JWT by the drill itself; a missing claim FAILs with the dependency recorded (REQ-3 step 3).
- **Constraint:** the IdP client registry state is external; the drill (REQ-3) and the shared DCR leg are the only in-repo-adjacent evidence channels and feed REQ-0.
- **Constraint:** zero production diff in `lib/screens/device/`; zero emission code; zero `lib/i18n` delta; POST `/device/verify` body stays `{user_code, approve}`; the widget test asserts path + query only (VM baseUri dependence, §1 finding 3).
- **Consistency:** the shared artifacts (`SSOAdminClient.firstPartyClientId`, `tests/integration/audit_login_drill.py`, `[RESOLVED]` record) match the sibling instance specs (`b6-2-lib-api-client-id-alignment-spec.md`, `b6-2-lib-screens-client-id-alignment-spec.md`, `b6-2-lib-screens-developer-client-id-alignment-spec.md` + `-design.md`) so all module buckets land one change set.

## 6. Risks and rollback

- **Branch value mismatch at drill time** (deployed IdP attributes a different `client_id`): drill FAIL with output recorded — contract evidence for REQ-0; no code change (rollback = current state); the branch choice must be re-examined, not papered over.
- **Wrong branch choice** (drill evidence misread): one-line constant flip + mirror updates in the sibling change set; fully revertible; the `[RESOLVED]` record must be re-opened.
- **Sink-side emission unverifiable** (no deployed stack/emission): AC-3's `[proposed]` fallback applies — the drill logs instead of asserting; no false PASS; the contract row keeps its T-12 joint status with the `[proposed]` note recorded.
- **Widget-test flakiness on the redirect** (post-frame callback): the REQ-1 test uses `pumpAndSettle()` after `addPostFrameCallback` (`device_verify_screen.dart:76`) and `BrowserNavigation.resetForTest()` before each case (pattern already at `setup_screen_test.dart:13`); on the stub, `replaceLocation` records `_currentUri` synchronously, so the assertion is deterministic.
- **Host-dependent assertion** (basing the widget test on `ProductApiOrigin.baseUri`'s scheme/host): prohibited by REQ-1 — assertions are path + query only; the host is `AppSettings`-dependent on VM (§1 finding 3).
- **Stale citation** (`audit-contract-batch-snaplink-console.md:12` citing `app_router.dart:55`): corrected to `:35` when the record is closed (REQ-0); census in §1 verified no other doc carries it.
- **Sibling claim drift** (the "0 client_id literals" claim in `b6-2-lib-screens-client-id-alignment-spec.md`): corrected by §1 finding 4 — the two `preview['client_id']` reads are server-response reads; neither branch touches them.
