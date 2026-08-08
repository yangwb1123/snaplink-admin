# B6-2 Requirements Specification — Resolve `client_id` contract mismatch + `auth.login.success` end-to-end verification drill

Module: `lib/i18n` (assigned analysis bucket; this direction touches **no** i18n surface — see §2) · Direction: B6-2 · Value: 8 · Risk reduction: 8 · Effort: 4 · Confidence: 8
Status: requirements (decision-gated: Branch A or Branch B, see REQ-0)
Supersedes: the prior `b6-2-lib-api-client-id-alignment-spec.md` requirements draft (this revision adds the Python-side census, fixes the drill-deliverable defect, and makes every acceptance check executable)

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. All six hold, with one functional correction and two new findings:

| Citation | Verification result |
|---|---|
| `lib/api/sso_client.dart:86` — `login` default `clientId = 'sso-admin-console'` | **Exact.** `:86` `String clientId = 'sso-admin-console',`; POST `/auth/login` body carries `'client_id': clientId` at `:92`; body keys at `:88-94` (provider/scope/resource/credential) are the full request shape. |
| `lib/app_router.dart:35` — `defaultClientId: 'sso-admin-console'` | **Exact.** `:34-36` `ProductEntry.login => OidcLoginScreen(defaultClientId: 'sso-admin-console', …)`. |
| `lib/screens/oidc_login/federated_login.dart:115-119,203` — builds `/auth/login` with `client_id` | **Exact.** `:119` `'client_id': clientId` in the `/auth/login` discovery query; `:203` `'client_id': clientId` in the `/token` exchange body. |
| `lib/screens/oidc_login/oidc_authorization_flow.dart:238,295,370` — `payload['client_id']` | **Exact.** All three sites set `payload['client_id'] = _effectiveClientId` (silent renewal `:238`, provider login `:295`, webauthn `:370`). |
| `tests/integration/e2e_runner.py`, `full_stack_verify.py`, `browser_test.py` — existing harness | **Files exist; functional correction:** none of the three *completes a login*. `browser_test.py` and `browser_login_test.py` only navigate (`page.goto`) — `browser_login_test.py:66-67` states "Flutter renders to canvas, so we can't easily find text fields". The harnesses that complete a real login are `tests/integration/api_login_e2e.py:59-77` (POST `{PROXY}/auth/login` with `CONFIG.login_payload()`, JWT decode, sub/iss checks) and `tests/integration/full_integration_test.py:46`. The drill (§REQ-4) therefore uses the proxy login path — the same wire path the console UI drives (`sso_client.dart:92`, `oidc_provider_flow.dart:54`) — and the browser-navigation harness remains its pre/post gate. Documented deviation, not a scope change. |
| `test/sso_client_test.dart:18` — asserts current client id | **Exact.** Whole-body assertion of the POST `/auth/login` JSON: `'client_id': 'sso-admin-console'`. |

Additional verified facts that shape the spec:

1. **No client-side `auth.login.success` emission path exists** — confirmed. `lib/services/audit_log_service.dart:66` is a localStorage ring (`_storageKey = 'sso_audit_log'`, `record`/`_save`); `lib/services/event_bus.dart:40-45` `DataChangedEvent` is UI-local. B6-2 is verification drill + constant alignment only.
2. **Contract authority** is `docs/campaigns/implementation-gate.md:57` row 2: "边缘生成验证：login → `auth.login.success`（client_id=sso-admin-console） | sink 出现 sso-admin-console login 事件；无重复 | B4-5" (quote corrected: the gate records `sso-admin-console`, not `console`). This is the "contract v2.1 client_id field" the acceptance names.
3. **Mismatch record** at `docs/proposals/audit-contract-batch-snaplink-console.md:12` is `[MISMATCH]` and correctly states code reality is `sso-admin-console`, but its **inner citation is stale** (`app_router.dart:55`; actual `:35`) — fixed when the record is closed (REQ-0).
4. **Full literal census** of `sso-admin-console` (excluding `docs/auto/`, build artifacts):

   | Site | Kind |
   |---|---|
   | `lib/api/sso_client.dart:86` | production default |
   | `lib/app_router.dart:35` | production wiring |
   | `test/sso_client_test.dart:18` | wire-body assertion |
   | `test/oidc_account_flow_test.dart:35,75,115,160` | `defaultClientId` args (no value assertions) |
   | `tests/integration/test_config.py:44` | `SNAPLINK_TEST_CLIENT_ID` default |
   | `tests/integration/README.md:17` | documents the env-var default |
   | `docs/proposals/audit-contract-batch-snaplink-console.md:12` | `[MISMATCH]` record |
   | `docs/campaigns/implementation-gate.md:57` | contract row (`client_id=sso-admin-console` — the *contract* value) |
   | `DEPLOY.md:29` | refers to the IdP-registered client's `allowed_resources` — registry reference, not a login default; unchanged by either branch |

   No central constant exists: "align the value" means "one aligned literal everywhere", so REQ-1 introduces the single source of truth.
5. **`_effectiveClientId` chain confirmed end-to-end:** `lib/screens/oidc_login/oidc_login_screen.dart:159-161` (`_params.clientId.isNotEmpty ? _params.clientId : widget.defaultClientId ?? ''`) → `lib/screens/oidc_login/oidc_provider_flow.dart:54` (`'client_id': _effectiveClientId` in login POST), `:87` (`probeProviders`), `:138` → `lib/api/oidc_login_api.dart:52` (`'client_id': clientId`, no default of its own). The only two defaults in the repo are `sso_client.dart:86` and `app_router.dart:35`.
6. **Drill prerequisites exist as reusable patterns:** JWT decode at `full_integration_test.py:31-33` (`decode_jwt`) and `api_login_e2e.py:73-77`; sink read `GET /api/v1/audit/events` smoke-tested at `full_integration_test.py:151` (status < 500, admin token). **No existing test uses `event_types`/`tenant_id` query params** — the drill's filtered query is new. Sink base is `CONFIG.api_url` (`tests/integration/test_config.py:13`, default `http://localhost:8080`); tenant_id is a token claim per the audit contract (B4-1 dependency).
7. **i18n zero-delta confirmed:** the drill is Python-side and the direction adds no console UI copy; existing audit keys (`lib/i18n/app_strings_source_admin_features.dart:142`, `lib/i18n/app_strings_source_admin_core.dart:303`) and the `test/i18n_coverage_test.dart` gate are untouched.

---

## 2. Scope

**In scope**

- The `client_id` value emitted by this repo's login paths (`sso_client.dart:86`, `app_router.dart:35`) and every census site in §1.4.
- One named constant as the single source of truth, living in `lib/api/sso_client.dart` (REQ-1).
- Regression assertions: unit-level on the `SSOAdminClient.login` wire; widget-level on the `OidcLoginScreen` fallback chain (branch-gated).
- The T-12 joint edge-generation drill as a **checked-in, runnable test file** (`tests/integration/audit_login_drill.py`, REQ-4) — a real artifact, not a runbook pointer. **Adopt** the existing **untracked** artifact (already wired at `run_all.py:169` / `full_stack_verify.py:113` — uncommitted diff); the change set commits it, never recreates it.
- Closing the `[MISMATCH]` record at `docs/proposals/audit-contract-batch-snaplink-console.md:12` (with its stale `app_router.dart:55` → `:35` citation fixed) and, under Branch B, **verifying** the contract row at `docs/campaigns/implementation-gate.md:57` (it already records `client_id=sso-admin-console` — no amendment needed, no-op); under Branch A, flipping it to `client_id=console`.

**Out of scope (explicitly not changed by B6-2)**

- Any sink/IdP-side client registry: whether the deployed IdP registers `console` or `sso-admin-console` is outside this repo and is a **precondition input** to REQ-0, evidenced only by the drill.
- Any new event generation: no `auth.login.success` emission code is added anywhere in this repo (no emission path exists; see §1.1).
- B6-1a (audit timeline server-read UI), B4-1 (console-side tenant claim parsing), B4-5 (drill gate owner), BFF trace injection — referenced only as dependencies.
- **`lib/i18n` catalog changes: none.** No new UI copy is introduced; existing audit copy keys are untouched; `test/i18n_coverage_test.dart` remains green by construction.
- No transport/API surface changes in `lib/api` beyond the default value of the `clientId` parameter.

---

## 3. Requirements

### REQ-0 — Decision gate (must execute first; both branches need it)

The drift must be resolved by an explicit decision recorded in this repo before any code change. Evidence channel: the deployed IdP's client registry, checked by the drill precondition step (REQ-4 step 1) and any operator-supplied registry evidence.

- **Branch A (rename to `console`):** chosen when the drill/registry evidence confirms the deployed IdP accepts/expects `client_id=console` (client registered as `console`).
- **Branch B (contract exception — already recorded):** chosen when the deployed IdP only recognizes `sso-admin-console`. **No contract amendment is required**: `docs/campaigns/implementation-gate.md:57` already records `client_id=sso-admin-console` with acceptance "sink 出现 sso-admin-console login 事件；无重复" (earlier "amend the gate" wording was based on a misquote and is a no-op against the real text); Branch B verifies the row and records the exception.
- Either branch: replace the `[MISMATCH]` record at `docs/proposals/audit-contract-batch-snaplink-console.md:12` with a `[RESOLVED]` note naming the chosen branch and the evidence (drill output attached), and **fix its stale inner citation** `app_router.dart:55` → `app_router.dart:35`.

**Testable:** `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` returns the record naming Branch A or B with evidence; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits; under Branch B additionally `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md:57` hits. Unselected-branch requirements below become void and are kept for traceability.

### REQ-1 — Single source of truth (both branches)

Introduce one named constant in `lib/api/sso_client.dart`:

- Branch A: `static const String firstPartyClientId = 'console';`
- Branch B: `static const String firstPartyClientId = 'sso-admin-console';`

Use it as (a) the default of `SSOAdminClient.login`'s `clientId` parameter (`sso_client.dart:86`) and (b) the value of `defaultClientId` at `lib/app_router.dart:35` (import from `lib/api/sso_client.dart`). All Dart tests reference the constant; **no test or production file may carry the value as a fresh literal** (prevents the drift from forking again and fixes the prior draft's literal-vs-grep-guard contradiction).

**Testable:** `grep -rn "sso-admin-console" lib/ --include="*.dart"` yields exactly the constant definition site under Branch B (zero hits under Branch A); `grep -rn "'console'" lib/ --include="*.dart"` yields exactly the constant site under Branch A.

### REQ-2 — Branch A co-change (rename to `console`)

Only when Branch A is chosen. The rename PR updates the three files the acceptance mandates **together** — `lib/app_router.dart:35`, `lib/api/sso_client.dart:86`, `test/sso_client_test.dart:18` — plus every remaining census site so no drifted literal survives:

- `test/sso_client_test.dart:18`: assert `'client_id': SSOAdminClient.firstPartyClientId` (resolves to `'console'`).
- `test/oidc_account_flow_test.dart:35,75,115,160`: `defaultClientId: SSOAdminClient.firstPartyClientId`.
- `tests/integration/test_config.py:44`: `SNAPLINK_TEST_CLIENT_ID` default → `'console'`.
- `tests/integration/README.md:17`: document the new default.

**Testable:** `flutter test test/sso_client_test.dart test/oidc_account_flow_test.dart` green; `grep -rn "sso-admin-console" lib test tests/integration --include="*.dart" --include="*.py" --include="*.md"` → exit 1 (zero hits).

### REQ-3 — Branch B regression pin (contract exception already recorded)

Only when Branch B is chosen. No production value change (REQ-1 keeps the value); add a widget test (`test/client_id_contract_test.dart`) that pumps `OidcLoginScreen(defaultClientId: SSOAdminClient.firstPartyClientId, api: MockClient-backed OidcLoginApi, routeUri: Uri.parse('https://sso.example/login/'))` and asserts the probe `POST /auth/login` body contains `'client_id': SSOAdminClient.firstPartyClientId` — pinning the value end-to-end through the exact fallback chain the direction names: `oidc_login_screen.dart:159-161` (`_effectiveClientId`) → `oidc_provider_flow.dart:54,87` → `oidc_login_api.dart:52`. The assertion references the constant, never a literal.

**Testable:** `flutter test test/client_id_contract_test.dart` green; mutating the constant makes it red; `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (amended contract row).

### REQ-4 — T-12 joint drill: checked-in `tests/integration/audit_login_drill.py` (both branches)

The drill is a **runnable test file**, not a runbook: follow the conventions of `api_login_e2e.py` (`check()`/`curl()` helpers, `CONFIG`) and wire it into the harnesses the direction cites — `tests/integration/run_all.py` (alongside `full_integration_test.py` at `run_all.py:121-122` and the e2e list at `:164-171`) and `tests/integration/full_stack_verify.py` (step 5). Steps and pass criteria:

1. **Precondition:** read the deployed IdP registry for the registered client id; assert `CONFIG.client_id` (`tests/integration/test_config.py:43-44`) equals the agreed value for the chosen branch. This is the evidence REQ-0 records.
2. **Login:** one real login through the console's wire path — `POST {PROXY}/auth/login` with `CONFIG.login_payload()` (carries `client_id`, mirroring `api_login_e2e.py:59-62` and `sso_client.dart:88-94`); assert `access_token` returned; decode the JWT (`decode_jwt` pattern, `full_integration_test.py:31-33`) and extract the `tenant_id` claim → `<t>`. Missing tenant claim → drill FAILs with the B4-1 dependency recorded (the drill does not implement claim parsing).
3. **Sink query:** `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` with the Bearer token; assert **exactly one row** whose `client_id` claim equals the agreed value (`'console'` after Branch A rename; `'sso-admin-console'` after Branch B amendment — any other value is a documented contract deviation).
4. **No duplicates:** re-run the login once; re-query; assert exactly two rows total (one per login) with **no duplicated row** (no repeated event id/trace_id); wait a settle interval (≥10 s); re-query; assert the count is unchanged.
5. **Report:** print PASS/FAIL with the query output; the output is attached to the `[RESOLVED]` record (REQ-0).

**Testable:** `python3 tests/integration/audit_login_drill.py` against the deployed stack exits with PASS only when steps 1-4 all hold; the file exists in `tests/integration/` and is listed in `run_all.py` (grep-verifiable). Browser-harness limitation (`browser_login_test.py:66-67`) is documented in the file header as the reason the login step is API-driven through the proxy.

### REQ-5 — No regression / zero-delta boundaries (both branches)

- No change to the `/auth/login` request shape other than the `client_id` value (`sso_client.dart:88-94` keys untouched); `SSOAdminClient.login` keeps its signature.
- No new endpoints or audit-emission code anywhere in `lib/`.
- **No `lib/i18n` changes:** no catalog keys added or removed; existing audit copy keys (`app_strings_source_admin_features.dart:142`, `app_strings_source_admin_core.dart:303`) untouched; `test/i18n_coverage_test.dart` green by construction.

**Testable:** full `flutter test` green with no test edits other than those mandated by REQ-2/REQ-3 and the census updates; `git diff --stat` shows no `lib/i18n/` files.

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | T-12 joint (edge generation): integration drill — complete a console login (browser_test.py) then query sink `GET /api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` and assert exactly one row whose `client_id` claim equals the agreed value (`'console'` after rename, else documented deviation in the contract) | REQ-4 steps 1-3: `python3 tests/integration/audit_login_drill.py` PASS — login via the console's wire path, one sink row with `client_id` == agreed value (`'console'` under Branch A, `'sso-admin-console'` under Branch B — already the recorded value, no amendment); deviation (if any) recorded in the `[RESOLVED]` record |
| AC-2 | No duplicates: re-running login/idempotency check yields no duplicated `auth.login.success` rows | REQ-4 step 4: two logins → exactly two rows, no repeated event id/trace_id; settle re-query → unchanged count |
| AC-3 | Decision artifact: contract v2.1 `client_id` field either amended to `'sso-admin-console'` or a rename PR lands (`app_router.dart:35` + `sso_client.dart:86` + `sso_client_test.dart:18` updated together); mismatch documented in `docs/proposals/audit-contract-batch-snaplink-console.md` | REQ-0 + REQ-2/REQ-3: `[RESOLVED]` record naming the branch with drill evidence; Branch A → the three mandated files + census co-sites changed together (REQ-2 grep guards); Branch B → `implementation-gate.md:57` amended (grep-verifiable); stale `app_router.dart:55` citation corrected to `:35` |

Gate relationship: AC-1 and AC-2 apply under both branches (the drill asserts the *agreed* value); AC-3 is branch-disjunctive exactly as supplied. All three are executable as written above.

---

## 5. Dependencies and constraints

- **B4-5** owns the drill gate row (`implementation-gate.md:57`); T-12 joint acceptance applies.
- **B6-1a** renders the audit timeline from server records — the rendering half of the T-12 joint; B6-2 does not implement it and does not depend on it to land.
- **B4-1** (tenant claim parsing) is a drill dependency: `<t>` is read from the login JWT by the drill itself; a missing claim makes the drill FAIL with the dependency recorded.
- **Constraint:** the IdP client registry state is external; REQ-4 step 1 is the only evidence channel and feeds REQ-0.
- **Constraint:** zero `lib/i18n` delta and zero new emission code (REQ-5).

## 6. Risks and rollback

- **Wrong branch choice** (drill evidence misread): the other branch's change is a one-line constant flip + test-literal updates — fully revertible in the same change set; the `[RESOLVED]` record must be re-opened.
- **IdP registration mismatch** (neither id registered): B6-2 cannot proceed past REQ-0; the drill FAIL result is reported, no code changes are made (rollback = keep current state).
- **Stale citation** (`audit-contract-batch-snaplink-console.md:12` citing `app_router.dart:55`): corrected as part of closing the record; no other doc carries the stale line reference (census §1.4 verified).
- **Browser-login gap**: if a future harness can drive the Flutter canvas, an optional browser-login variant of REQ-4 may be added — explicitly out of scope here.
