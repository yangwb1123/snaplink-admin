# B6-2 Requirements Specification — Resolve `client_id` mismatch (login wire) + `auth.login.success` edge-verification regression

Module: `lib/screens` (analysis bucket `docs/auto/analyses/lib-screens-19d4d0ab.json`, direction `resolve-the-b6-2-login-client-id-mismatch-code-s-ed88f81e`) · Direction: B6-2 · Value: 6 · Risk reduction: 6 · Effort: 3 · Confidence: 8
Status: requirements (decision-gated: Branch A or Branch B, see REQ-0)
Sibling instance: the same direction is specced for other buckets (`b6-2-lib-api-client-id-alignment-spec.md` + `-design.md`). This spec is the **`lib/screens` lens**: it owns the screens-side surface (login screen wiring, effective-client fallback chain, widget regressions, drill login leg) and carries the direction's full acceptance checks. Where the two instances overlap (constant, drill artifact), they name the same artifacts so the change set stays single.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. All five hold, with one line correction and two new screens-side findings:

| Direction citation | Verification result |
|---|---|
| `lib/api/sso_client.dart:86,92` — `clientId` default `'sso-admin-console'` → `'client_id'` in `/auth/login` body | **Exact.** `:86` `String clientId = 'sso-admin-console',`; `:92` `'client_id': clientId,` inside the POST `/auth/login` body whose remaining keys are at `:91-95` (`provider`/`scope`/`resource`/`credential`). |
| `test/sso_client_test.dart:18` — asserts `client_id 'sso-admin-console'` | **Exact.** `:16` `expect(jsonDecode(request.body), {` … `:18` `'client_id': 'sso-admin-console',` — a whole-body map assertion (provider/scope/resource/credential), which is what locks the mismatch and what AC-3 reuses. |
| `lib/sso_client.dart` — re-export shim of `lib/api/sso_client.dart` | **Exact.** Single-line `export 'package:sso_admin/api/sso_client.dart';` with a header saying new code should import the api path directly. |
| `lib/api/snaplink_admin_event_stream.dart` — consumer only | **Exact.** `SnaplinkAdminEventStream.open()` (`:28`) returns `Stream<SnaplinkAdminEvent>` over an `EventSource`; header (`:10`) notes EventSource cannot attach the console's bearer token. No emit call anywhere. |
| `lib/screens/oidc_login/oidc_login_screen.dart:159-160` — effective client fallback; no `auth.login.success` generation | **Exact.** `:159-161` `String get _effectiveClientId => _params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '');`. And `grep -rn "auth.login.success" lib/ test/ tests/` → **0 hits** (repo-wide): the console is an OIDC/REST client, so `auth.login.success` can only be generated on the IdP/BFF side. The "emit" requirement is verification-drill territory ([proposed] under AC-2), never new emitter code. |

Screens-module chain (verified line-exact, extends the direction's fifth citation):

| Site | Fact |
|---|---|
| `lib/app_router.dart:35` | `defaultClientId: 'sso-admin-console',` — the **only** screens login-wiring literal; passed into `OidcLoginScreen` (`:34-37`). |
| `lib/screens/oidc_login/oidc_provider_flow.dart:54` | `'client_id': _effectiveClientId,` in the first-party login POST; `:152-154` `_probeProviders()` → `_api.probeProviders(_effectiveClientId, …)`; `:84-90` `Session.store(…, clientId: _effectiveClientId)`. |
| `lib/api/oidc_login_api.dart:47,52` | `probeProviders(clientId, …)` posts `'client_id': clientId` to `../auth/login` (no default of its own — the default enters only via `OidcLoginScreen.defaultClientId`). |
| `lib/screens/oidc_login/federated_login.dart:119,203` | `'client_id': clientId` in the `/auth/login` discovery query and the `/token` exchange body (PKCE, `_clientIdKey = 'sso_pkce_client_id'` at `:54`). |
| `lib/screens/oidc_login/oauth_params.dart:59` | URL passthrough `clientId: q['client_id'] ?? ''` — a URL-supplied `client_id` wins over the default (`.isNotEmpty` at `oidc_login_screen.dart:159`). |
| `test/oidc_account_flow_test.dart:35,75,115,160` | Four widget tests pump `OidcLoginScreen(…, defaultClientId: 'sso-admin-console', …)` — screens-side literal sites that must move with the decision. |
| `lib/screens/device/device_verify_screen.dart:172-181` | Unauthenticated device entry redirects to `/login/` (`.resolve('/login/')` `:179`, `redirect` query `:180`) — funnels into the **same** `OidcLoginScreen`; no own `client_id` literal (grep: 0 hits in `lib/screens/device/`). |

Contract and record state:

- Contract authority: `docs/campaigns/implementation-gate.md:57` row 2 (console): "边缘生成验证：login → `auth.login.success`（client_id=sso-admin-console） | sink 出现 sso-admin-console login 事件；无重复 | B4-5" (quote corrected: the gate records `sso-admin-console`, not `console`) — the "contract decision" AC-1 names.
- Mismatch record: `docs/proposals/audit-contract-batch-snaplink-console.md:12` is `[MISMATCH]` and states code reality is `sso-admin-console`, but its inner citation is **stale** (`app_router.dart:55`; actual `:35`) — fixed when the record is closed (REQ-0).
- No `auth.login.success` emission code exists anywhere in this repo (0 grep hits, above); `lib/services/audit_log_service.dart` (`_storageKey = 'sso_audit_log'` localStorage ring) and `lib/services/event_bus.dart` (`DataChangedEvent`, UI-local) are not event emitters for the sink.

Drill-harness facts (for REQ-4): `tests/integration/api_login_e2e.py:59-77` completes a real login (`POST {PROXY}/auth/login` with `CONFIG.login_payload()`, JWT decode/claims); `browser_test.py`/`browser_login_test.py` only navigate (Flutter renders to canvas — `browser_login_test.py:89` "we can't easily find text fields"; `browser_test.py:86` skips the canvas check), so the drill's login leg is API-driven through the same `/auth/login` wire the screens drive (`oidc_provider_flow.dart:54`, `sso_client.dart:92`). `tests/integration/test_config.py:43-44` defaults `SNAPLINK_TEST_CLIENT_ID` to `sso-admin-console`. Harness wiring points: `tests/integration/run_all.py:121-122` (full integration) and `:164-171` (e2e list); `tests/integration/full_stack_verify.py` step runner (`step()` at `:15`, integration steps at `:104-115`).

---

## 2. Scope

**In scope (screens lens)**

- The screens-side `client_id` surface: `lib/app_router.dart:35` wiring and the `OidcLoginScreen` effective-client fallback chain (`oidc_login_screen.dart:159-161` → `oidc_provider_flow.dart:54,152-154` → `oidc_login_api.dart:47,52`), plus the federated flows that reuse it (`federated_login.dart:119,203`, `oauth_params.dart:59`).
- The decision gate (REQ-0) that reconciles code (`'sso-admin-console'`) with contract (`implementation-gate.md:57`, which **already records `sso-admin-console`**) — either Branch A (code+test rename to `'console'`; gate row flips to `console`) or Branch B (contract exception **already recorded — no amendment**, no-op), enforced by the updated `test/sso_client_test.dart` assertion (AC-1).
- Widget-level regression pinning the screens chain to the decided constant (REQ-3) and the existing widget-test literal sites (`test/oidc_account_flow_test.dart:35,75,115,160`).
- The T-12 joint edge-generation drill as a **checked-in, runnable file** `tests/integration/audit_login_drill.py` (REQ-4), with the AC-2 [proposed] fallback when sink-side emission cannot be verified from this repo.
- Closing the `[MISMATCH]` record at `docs/proposals/audit-contract-batch-snaplink-console.md:12` (fixing its stale `app_router.dart:55` → `:35` citation) and, under Branch B, **verifying** `docs/campaigns/implementation-gate.md:57` (it already records `client_id=sso-admin-console` — no amendment needed, no-op); under Branch A, flipping row 2 to `client_id=console` (REQ-2).

**Out of scope (explicitly not changed)**

- Any `auth.login.success` emission code: no emission path exists in this repo (§1); the event is generated on the IdP/BFF side and is verified only by the drill, marked [proposed] if unverifiable (AC-2).
- Sink/IdP-side client registry: whether the deployed IdP registers `console` or `sso-admin-console` is external — a precondition input to REQ-0, evidenced only by the drill (REQ-4 step 1).
- B6-1a (audit timeline server-read UI), B4-1 (console-side tenant claim parsing), B4-5 (drill gate owner), BFF trace injection — referenced only as dependencies.
- `lib/api` transport surface beyond the `clientId` default's value; `lib/i18n` catalog (zero delta); no login-screen UX or copy changes.

---

## 3. Requirements

### REQ-0 — Decision gate (must execute first; both branches need it)

The drift must be resolved by an explicit decision recorded in this repo before any code change. Evidence channel: the deployed IdP client registry, checked by the drill precondition (REQ-4 step 1) and any operator-supplied registry evidence.

- **Branch A (rename to `console`):** chosen when the drill/registry evidence confirms the deployed IdP accepts/expects `client_id=console`. The rename PR updates the login wire **together** — `lib/api/sso_client.dart:86`, `lib/app_router.dart:35` (screens wiring), `test/sso_client_test.dart:18` — plus every census site (REQ-2).
- **Branch B (contract exception — already recorded):** chosen when the deployed IdP only recognizes `sso-admin-console`. **No contract amendment is required**: `docs/campaigns/implementation-gate.md:57` already records `client_id=sso-admin-console` with acceptance "sink 出现 sso-admin-console login 事件；无重复"; Branch B verifies the row and records the exception in the mismatch record.
- Either branch: replace the `[MISMATCH]` record at `docs/proposals/audit-contract-batch-snaplink-console.md:12` with a `[RESOLVED]` note naming the branch and the evidence (drill output attached), and **fix its stale inner citation** `app_router.dart:55` → `app_router.dart:35`.

**Testable:** `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` returns the record naming Branch A or B with evidence; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits; under Branch B additionally `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits — **already present, unedited (no-op)**. Unselected-branch requirements below become void and are kept for traceability.

### REQ-1 — Single source of truth (both branches)

One named constant in `lib/api/sso_client.dart` — `static const String firstPartyClientId = 'console';` (Branch A) or `= 'sso-admin-console';` (Branch B). Use it as (a) the default of `SSOAdminClient.login`'s `clientId` parameter (`sso_client.dart:86`) and (b) the value of `defaultClientId` at `lib/app_router.dart:35` (screens wiring; import from `lib/api/sso_client.dart`). All Dart tests reference the constant; **no production or test file may carry the value as a fresh literal** (prevents the drift from forking again) — incl. the anchor lens's `test/oidc_login_screen_client_id_test.dart`, whose three literal sites are constantized in the same commit as the constant (co-site, REQ-2).

**Testable:** `grep -rn "sso-admin-console" lib/ --include="*.dart"` yields exactly the constant definition site under Branch B (zero hits under Branch A); `grep -rn "'console'" lib/ --include="*.dart"` yields exactly the constant site under Branch A; `grep -rn "'sso-admin-console'" test/` → 0 hits after the mechanism lands (anchor co-site included). `flutter test test/sso_client_test.dart test/oidc_account_flow_test.dart` green.

### REQ-2 — Branch A co-change (rename to `console`)

Only when Branch A is chosen. Updates the files AC-1 names **together** — `lib/api/sso_client.dart:86`, `lib/app_router.dart:35`, `test/sso_client_test.dart:18` — plus every remaining census site so no drifted literal survives:

- `test/sso_client_test.dart:18`: assert `'client_id': SSOAdminClient.firstPartyClientId` (resolves `'console'`).
- `test/oidc_account_flow_test.dart:35,75,115,160`: `defaultClientId: SSOAdminClient.firstPartyClientId`.
- `test/oidc_login_screen_client_id_test.dart:76,136,158` (anchor lens co-site): harness `defaultClientId:` + both `expect(lastClientId, …)` → `SSOAdminClient.firstPartyClientId` (constantized in the same commit as the constant, M2 — the anchor REQ-2 expectation derives from the constant, compile-time gate; without this co-site the REQ-2 grep below trips red on a file outside this change-set).
- `tests/integration/test_config.py:44`: `SNAPLINK_TEST_CLIENT_ID` default → `'console'`; `tests/integration/README.md:17` documents the new default.
- `docs/campaigns/implementation-gate.md:57` row 2 and `docs/campaigns/campaign-console-b6.yaml:37`: flip to `client_id=console` / `sink 出现 console login 事件` — the gate and the prompt record the shipped value (the `sso-admin-console` exception dissolves under Branch A).

**Testable:** `flutter test test/sso_client_test.dart test/oidc_account_flow_test.dart` green; `grep -rn "sso-admin-console" lib test tests/integration --include="*.dart" --include="*.py" --include="*.md"` → exit 1 (zero hits; passes because the anchor-lens co-site was constantized in the same commit, M2).

### REQ-3 — Screens-chain regression pin: `test/client_id_contract_test.dart` (both branches)

A widget test that pumps `OidcLoginScreen(defaultClientId: SSOAdminClient.firstPartyClientId, api: MockClient-backed OidcLoginApi, routeUri: Uri.parse('https://sso.example/login/'))` and asserts the provider-probe `POST /auth/login` body carries `'client_id': SSOAdminClient.firstPartyClientId` — pinning the value end-to-end through the exact fallback chain the direction names: `oidc_login_screen.dart:159-161` (`_effectiveClientId`) → `oidc_provider_flow.dart:152-154` (`_probeProviders`) → `oidc_login_api.dart:47,52` (`'client_id': clientId`). The assertion references the constant, never a literal. Model the MockClient wiring on `test/oidc_account_flow_test.dart` (MockClient pattern, `OidcLoginApi(httpClient: …)`). Also covers the URL-passthrough precedence at `oauth_params.dart:59` with a second case: a `routeUri` carrying `?client_id=<other>` must send `<other>`, not the default (that path is already contract-correct and must not be broken by the rename).

**Testable:** `flutter test test/client_id_contract_test.dart` green; mutating the constant makes it red (and the URL-passthrough case stays green — the chain, not the default, is what the test pins).

### REQ-4 — T-12 joint drill: checked-in `tests/integration/audit_login_drill.py` (both branches)

A **runnable test file**, not a runbook: follows `api_login_e2e.py` conventions (`check()`/`curl()` helpers, `CONFIG`) and is wired into `tests/integration/run_all.py` (alongside `full_integration_test.py` at `:121-122` and the e2e list at `:164-171`) and `tests/integration/full_stack_verify.py` (integration step block at `:104-110`). Steps and pass criteria:

1. **Precondition:** assert `CONFIG.client_id` (`tests/integration/test_config.py:43-44`) equals the agreed value for the chosen branch (evidence channel for REQ-0).
2. **Login (screens wire path):** one real login — `POST {PROXY}/auth/login` with `CONFIG.login_payload()` (carries `client_id`, mirroring `api_login_e2e.py:59-62` and the wire the screens drive at `oidc_provider_flow.dart:54` / `sso_client.dart:90-95`); assert `access_token` returned; decode the JWT (`decode_jwt` pattern, `full_integration_test.py:31-33`) and extract the `tenant_id` claim → `<t>`. Missing tenant claim → drill FAILs with the B4-1 dependency recorded (the drill does not implement claim parsing).
3. **Sink query:** `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` with the Bearer token; assert **exactly one row** whose `client_id` claim equals the agreed value (`'console'` after Branch A rename; `'sso-admin-console'` after Branch B — already the recorded value, no amendment — any other value is a documented contract deviation).
4. **No duplicates** (contract row `implementation-gate.md:57` "无重复"): re-run the login once; re-query; assert exactly two rows total (one per login) with no repeated event id/trace_id; wait a settle interval (≥10 s); re-query; assert the count is unchanged.
5. **Report:** print PASS/FAIL with the query output; the output is attached to the `[RESOLVED]` record (REQ-0).

**AC-2 [proposed] fallback (both branches):** the sink-side assertions (steps 3-4) depend on the BFF/sink emitting `auth.login.success` — a side this repo cannot generate (0 grep hits, §1). If the sink-side emission cannot be verified from this repo (no deployed stack, no emission observed), the drill report marks those assertions **`[proposed]` instead of asserting**: it logs the query and result, records the deviation in the `[RESOLVED]` note, and exits without a false PASS. Steps 1-2 are in-repo verifiable and always asserted.

**Testable:** `python3 tests/integration/audit_login_drill.py` against the deployed stack exits with PASS only when steps 1-2 hold and steps 3-4 either hold or are explicitly reported [proposed]; the file exists in `tests/integration/` and is listed in `run_all.py` (grep-verifiable); browser-harness limitation (`browser_login_test.py:89` — Flutter renders to canvas, no text-field access) is documented in the file header as the reason the login step is API-driven.

### REQ-5 — No-regression / zero-delta boundaries (both branches)

- `test/sso_client_test.dart` **continues to pin the full `/auth/login` body shape** — `provider`, `client_id`, `scope`, `resource`, `credential` (AC-3). Under Branch A only the `client_id` value changes; under Branch B the test file is untouched.
- No change to the `/auth/login` request shape other than the `client_id` value (`sso_client.dart:91-95` keys untouched); `SSOAdminClient.login` keeps its signature; `OidcLoginScreen.defaultClientId` parameter and the `_effectiveClientId` chain are unchanged in shape.
- No new endpoints, no audit-emission code anywhere in `lib/` (`grep -rn "auth.login.success" lib/` stays 0).
- No screens UI copy changes and no `lib/i18n` delta; `test/i18n_coverage_test.dart` green by construction.

**Testable:** `flutter test` fully green with no test edits other than those mandated by REQ-1/REQ-2/REQ-3; `git diff test/sso_client_test.dart` shows only the `client_id` line under Branch A, zero diff under Branch B; `git diff --stat` shows no `lib/i18n/` files and no new `lib/screens` files other than none (screens change is the `app_router.dart:35` value + tests).

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | T-12 joint: the login request body's `client_id` matches the contract decision (either `'console'` after code+test update, or an approved contract-exception note referencing this mismatch), enforced by the updated `sso_client_test.dart` assertion | REQ-0 + REQ-2/REQ-3: `flutter test test/sso_client_test.dart` green with `:18` asserting `'client_id': SSOAdminClient.firstPartyClientId` (resolves `'console'` under Branch A; unchanged literal under Branch B with the `[RESOLVED]` exception note at `audit-contract-batch-snaplink-console.md:12` and the already-recorded exception at `implementation-gate.md:57`, verified not amended); census grep guard from REQ-2 holds under Branch A |
| AC-2 | T-12 joint (drill): a recorded real login (integration harness against the BFF) produces an `auth.login.success` record with the agreed `client_id` (Branch B: `sso-admin-console`) retrievable via `GET /api/v1/audit/events` — executed as a verification drill with the result logged; if the sink-side emission cannot be verified from this repo, the drill report marks it `[proposed]` instead of asserting | REQ-4: `python3 tests/integration/audit_login_drill.py` against the deployed stack — login via the console's `/auth/login` wire (step 2), then `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` with exactly one row whose `client_id` claim equals the agreed value (step 3) and no duplicates (step 4); if sink-side emission is unverifiable from this repo, the drill report marks the sink assertions `[proposed]` (no false PASS) and the result is logged and attached to the `[RESOLVED]` record; file present in `tests/integration/` and listed in `run_all.py`/`full_stack_verify.py` (grep-verifiable) |
| AC-3 | Regression: `sso_client_test.dart` continues to pin the full `/auth/login` body shape (provider/scope/resource/credential) so the `client_id` fix cannot silently alter the auth contract | REQ-5: `flutter test test/sso_client_test.dart` green; `:16-22` whole-body map assertion still contains all five keys (`provider`, `client_id`, `scope`, `resource`, `credential`); `git diff test/sso_client_test.dart` shows only the `client_id` line under Branch A, zero diff under Branch B |

Gate relationship: AC-1 and AC-3 apply under both branches (AC-3 is the guard that makes AC-1's fix safe); AC-2's drill asserts the *agreed* value with the [proposed] fallback exactly as supplied. All three are executable as written above.

---

## 5. Dependencies and constraints

- **B4-5** owns the drill gate row (`implementation-gate.md:57`); the T-12 joint acceptance applies (G7 gate).
- **B6-1a** (audit timeline server-read UI) is the rendering half of the T-12 joint; B6-2 does not implement it and does not depend on it to land.
- **B4-1** (tenant claim parsing) is a drill dependency: `<t>` is read from the login JWT by the drill itself; a missing claim makes the drill FAIL with the dependency recorded (REQ-4 step 2).
- **Constraint:** the IdP client registry state is external; REQ-4 step 1 is the only evidence channel and feeds REQ-0.
- **Constraint:** zero emission code, zero `lib/i18n` delta, no transport surface change beyond the `clientId` default (REQ-5).
- **Consistency:** the constant (REQ-1) and drill artifact (REQ-4) match the sibling instance specs (`b6-2-lib-api-client-id-alignment-spec.md`/`-design.md`) so all module buckets land one change set.

## 6. Risks and rollback

- **Wrong branch choice** (drill evidence misread): the other branch's change is a one-line constant flip + test-literal updates — fully revertible in the same change set; the `[RESOLVED]` record must be re-opened.
- **IdP registration mismatch** (neither id registered): B6-2 cannot proceed past REQ-0; the drill FAIL result is reported, no code changes are made (rollback = keep current state).
- **Sink-side unverifiable** (no deployed stack/emission): AC-2's [proposed] fallback applies — the drill logs instead of asserting; the contract row keeps its T-12 joint status with the [proposed] note recorded, no code churn.
- **Stale citation** (`audit-contract-batch-snaplink-console.md:12` citing `app_router.dart:55`): corrected to `:35` as part of closing the record; no other doc carries the stale line reference (census §1 verified).
- **Canvas-driven browser login gap**: the drill's login leg is API-driven through the same `/auth/login` wire the screens drive (`browser_login_test.py:89` documented in the drill header); a future browser-login variant is explicitly out of scope here.
