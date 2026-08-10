# B6-2 Requirements Specification — Land the `client_id` single-source constant (`SSOAdminClient.firstPartyClientId`, Branch B) and run the edge-generation drill

Module: `lib/screens/admin` (analysis bucket `docs/auto/analyses/lib-screens-admin-4276368d.json`, direction 2) · Direction: B6-2 · Value: 8 · Risk reduction: 7 · Effort: 2 · Confidence: 9
Status: requirements — **Branch B locked** (`[RESOLVED]` record at `docs/proposals/audit-contract-batch-snaplink-console.md:13-14`: code reality `sso-admin-console` is authoritative; "sibling 机制落地后统一对齐 `SSOAdminClient.firstPartyClientId`"). This direction **is** that sibling mechanism (the M2 constantization commit) plus the edge-generation drill verification (T-12 joint leg).
Sibling instances: `b6-2-lib-api-client-id-alignment-spec.md` (REQ-0 decision / REQ-1 constant definition / REQ-4 drill artifact), `b6-2-lib-screens-oidc-login-client-id-alignment-spec.md` (the oidc_login-bucket lens of the identical M2 commit), `b6-2-lib-screens-oidc-login-handle-success-anchor-spec.md` (the census anchor that owns the dual-state literal census), `b6-2-lib-screens-portal-edge-generation-spec.md` (the non-emitter negative half), `b6-2-lib-screens-t12-joint-positive-spec.md` (the rendering positive half). Where lenses overlap (constant value, census rule, drill artifact, `implementation-gate.md:57`), they name the same artifacts so the change set stays single.

---

## 1. Verification outcome

Every direction citation was re-checked against the repository at HEAD `e1073ce` **and** the current working tree. All hold; the working tree already carries the full M2 change set (uncommitted), so each citation records its HEAD (pinned-mode) and working-tree (constant-mode) reality.

| # | Direction citation | Verified repository reality | Status |
|---|---|---|---|
| E1 | `lib/api/sso_client.dart:86` — `clientId` default literal | HEAD: `:86` `String clientId = 'sso-admin-console',` (login at `:83-97`, body `'client_id': clientId` at `:92`). Working tree: `static const String firstPartyClientId = 'sso-admin-console';` declared at **`:82`** (with single-source doc comment `:78-81`), default re-pointed at **`:92`** `String clientId = firstPartyClientId,`, body site shifted to `:98`. `git grep firstPartyClientId HEAD -- lib/` → **0 hits** (constant absent at HEAD); working tree → exactly the one declaration site | ✅ exact (line shift recorded) |
| E2 | `lib/app_router.dart:35` — `defaultClientId` literal | HEAD: `:35` `defaultClientId: 'sso-admin-console',` (in `ProductEntry.login => OidcLoginScreen(` at `:34-36`). Working tree: `import 'api/sso_client.dart';` added at `:4`, wiring at **`:36`** `defaultClientId: SSOAdminClient.firstPartyClientId,` — the direction's `:35` is the pre-change line; pins reference the symbol, not the fragile line number | ✅ exact (1-line shift from the import) |
| E3 | `lib/screens/oidc_login/oidc_authorization_flow.dart:238/295/370` — `payload['client_id'] = _effectiveClientId` | All three verified in the working tree (file untouched by the change set, so HEAD = working tree): `:238` `_submitSilentRenewal`, `:295` provider/password login, `:370` webauthn leg — each `payload['client_id'] = _effectiveClientId;` | ✅ exact |
| E4 | `lib/screens/oidc_login/oidc_login_screen.dart:159` — `_effectiveClientId = params.clientId or widget.defaultClientId` | **`:159-161`** `String get _effectiveClientId => _params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '');` — direction's `:159` is the getter's first line | ✅ exact |
| E5 | `test/oidc_login_handle_success_census_test.dart:110-165` — literal census + 30-test count gate (10+3+17) | Group `client_id literal census (single-source rule, §6.4 gate c)` at **`:109-188`** (direction's `:110-165` spans the gate test). `constantDecl = 'static const String firstPartyClientId'` at `:114`; `constantExists` derived at `:127`; constant **absent** → `expect(actual, pinnedSites)` at `:150` (allowlist `sso_client_test.dart:[18]`, `oidc_account_flow_test.dart:[35,75,115,160]`, `oidc_login_screen_client_id_test.dart:[76,136,158]` at `:116-120`); constant **present** → `expect(actual, isEmpty)` at `:144` ("every reference goes through the constant"). Count gate at `:156-186`: census file 10 (`:176`), client_id file 3 (`:179`), sso file 17 (`:182`), sum 30 (`:184`), regex `^\s*(test|testWidgets)\(`. **The gate file is byte-identical at HEAD and in the working tree** (`git diff HEAD -- test/oidc_login_handle_success_census_test.dart` → empty) — the flip between orderings is derived, not edited | ✅ exact |
| E6 | `test/oidc_login_handle_success_census_test.dart:96-102` — REQ-4 #5: zero `auth.login.success` strings in `lib/screens/oidc_login` | Test at **`:97-104`** (1-line drift from `96-102`): scans `moduleDir = 'lib/screens/oidc_login'` (`:16`) and asserts no file contains `auth.login.success`. Executed: `grep -rn "auth.login.success" lib/screens/oidc_login/` → 0; repo-wide `grep -rn "auth.login.success" lib/` → 0. Invariant unchanged by this direction (it adds no emission code) | ✅ exact (span corrected) |
| E7 | Pinned literal sites: `test/sso_client_test.dart:18`, `test/oidc_account_flow_test.dart:35/75/115/160`, `test/oidc_login_screen_client_id_test.dart:76/136/158` | HEAD (`git grep`): all seven sites carry the literal — `sso_client_test.dart:18` (in-handler whole-body `'client_id'` assert), `oidc_account_flow_test.dart` ×4 `defaultClientId:` pumps, `oidc_login_screen_client_id_test.dart` `:76` harness `defaultClientId:` + `:136/:158` `expect(harness.lastClientId, …)`. Working tree: all 8 co-sites (7 lines — account-flow 4 + client_id 3 + sso 1) constantized in **3 files** via `SSOAdminClient.firstPartyClientId` with `import 'package:sso_admin/api/sso_client.dart';` added to each; the client_id file's co-change comments updated to "Constantized: … since the sibling M2 commit" (`:77-78`, `:134-135`, `:156-157`) | ✅ exact |
| E8 | `firstPartyClientId` absent from `lib/` at baseline (grep = 0) | `git grep firstPartyClientId HEAD -- lib/` → exit 1 (0 hits). Working tree: exactly one occurrence in `lib/` — the declaration at `sso_client.dart:82` (plus the two re-pointed references, which name the symbol, not the value) | ✅ exact |
| E9 | `docs/campaigns/implementation-gate.md:57` — "sink 出现 sso-admin-console login 事件；无重复" | Row 2 (console) at **`:57`** exact: `\| 2 \| console \| lib/ 原生事件 \| 边缘生成验证：login → auth.login.success（client_id=sso-admin-console）\| sink 出现 sso-admin-console login 事件；无重复 \| B4-5 \|`. Working-tree diff of the file touches only the G7 count row (`:76`) and 要点④ (`:82`) — **row 2 is untouched**: Branch B is verify-only, no amendment (no-op) | ✅ exact |
| E10 | `tests/integration/audit_login_drill.py:31` — `AGREED_CLIENT_ID` | **`:31`** `AGREED_CLIENT_ID = 'sso-admin-console'  # Branch B (REQ-0 decision)` — exact. Precondition step 1 (`:123-125`) asserts `CONFIG.client_id == AGREED_CLIENT_ID` (`tests/integration/test_config.py:44` env default `sso-admin-console`) | ✅ exact |
| E11 | `tests/integration/audit_login_drill.py:169-183` — exactly-one row check | Step 4 at **`:169-190`** (direction's `:169-183` spans the block head through the check): `rows = sink_rows(token, tenant_id)` at `:174`; unverifiable → `proposed = True` + "sink legs marked [proposed] — no false PASS" (`:175-178`); else `matching = [r for r in rows if r.get('client_id') == AGREED_CLIENT_ID]` at `:182` and `check("exactly one auth.login.success row with client_id=…", len(matching) == 1, …)` at `:183-185`. Step 5 at `:192-216`: second login → `len(rows_after) == 2` at `:207` + no repeated event id/trace_id at `:209` + count stable after re-settle; skipped `[proposed]` when step 4 was unverifiable. Step 3 at `:141-167`: one real `POST {PROXY}/auth/login` with `CONFIG.login_payload()`, JWT 3-part + `tenant_id` claim (missing claim → FAIL with B4-1 dependency, `:162-165`). Exit: `sys.exit(1 if FAIL else 0)` (`:292`) | ✅ exact (span corrected) |

**Executed acceptance evidence (this session, working tree):**

| Check | Command | Result |
|---|---|---|
| Literal census, constant mode | `grep -rn "'sso-admin-" test/` (contiguous quoted literal) | 0 hits — the census file self-hosts via a **split** literal (`:112` `const literal = "'sso-admin-" "console'";`) and its reason string (`:146`) carries no closing quote; no other `test/*.dart` file contains the value |
| 30-test acceptance command | `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` | **All tests passed! 30/30** (10 census + 3 client_id + 17 sso — the count gate's own arithmetic, green in the same run) |
| REQ-4 #5 zero-emission invariant | `grep -rn "auth.login.success" lib/` | 0 hits (module-scoped census `lib/screens/oidc_login` also 0) |
| Drill offline behavior | `python3 tests/integration/audit_login_drill.py` (no stack/credentials) | `SKIP: live authenticated tests require SNAPLINK_TEST_USERNAME and SNAPLINK_TEST_PASSWORD and SNAPLINK_TEST_USER_ID` → **exit 0** — sink legs never false-PASS |

**Repository state note:** HEAD `e1073ce` is the pinned-mode baseline (constant absent, 8 literal co-sites, census in the `pinnedSites` branch — all confirmed by `git grep`). The working tree already carries the entire M2 change set uncommitted (constant + 2 production re-points + 3 test-file constantizations; `git diff --stat` = `lib/api/sso_client.dart`, `lib/app_router.dart`, `test/sso_client_test.dart`, `test/oidc_account_flow_test.dart`, `test/oidc_login_screen_client_id_test.dart`). The change set must land as **one atomic commit**: the census gate makes any split ordering red by construction (constant without co-sites → `isEmpty` fails on the 8 still-literal sites; co-sites without constant → the `pinnedSites` branch fails). No test count changes (10/3/17 invariant — constantization replaces literals, adds/removes zero tests), so the standing 30-test gate cannot regress from this commit.

## 2. Scope

**In scope**

- The single-source constant on `SSOAdminClient`: `static const String firstPartyClientId = 'sso-admin-console';` in `lib/api/sso_client.dart` (Branch B value per REQ-1 of the anchor spec).
- The two production re-points: `SSOAdminClient.login`'s `clientId` default (`sso_client.dart:86` → constant) and `defaultClientId:` at `app_router.dart:35` → constant (import added).
- The atomic 8-site test co-change in 3 files (`test/sso_client_test.dart:18`, `test/oidc_account_flow_test.dart:35,75,115,160`, `test/oidc_login_screen_client_id_test.dart:76,136,158`) — every reference through the constant, zero fresh literals.
- The derived census flip: the dual-state gate at `test/oidc_login_handle_success_census_test.dart:109-188` flips to its `constantExists` branch in the same commit **with zero edits to the gate file**; the 30-test count (10+3+17) holds.
- The edge-generation drill verification: `tests/integration/audit_login_drill.py` steps 3-5 (one `POST /auth/login` with `client_id=sso-admin-console` → exactly one `auth.login.success` sink row; second login adds no duplicate), `[proposed]` deviation when the sink is unverifiable — never a false PASS.
- Branch B record consistency: `implementation-gate.md:57` verify-only (already records the value); the `[RESOLVED]` note (`audit-contract-batch-snaplink-console.md:13-14`) is the authority this commit fulfills.

**Out of scope (explicitly not changed)**

- Any value change (Branch A `'console'` is void; the flip path is documented in the anchor spec and is not this direction's deliverable).
- Any new test file or new test in the three counted files (counts 10/3/17 invariant); sibling-owned test files (e.g., `client_id_contract_test.dart` / `app_router_client_id_wiring_test.dart` if any are introduced by the screens lens REQ-3) are not this direction's deliverables.
- Any local event fabrication: REQ-4 #5's zero-emission-string invariant means the console never emits `auth.login.success` itself — only the wire `client_id` is guaranteed; the sink event is server-side (B4-5).
- Any change to `lib/screens/admin/` itself: the admin module contains no literal sites and no emitter; this direction's footprint is the constant, the two re-points, the three test files, and the drill run.
- `tests/integration/test_config.py:44` / `README.md:17` (`SNAPLINK_TEST_CLIENT_ID` default) and `DEPLOY.md:29` carry the value as config/registry text, not Dart literals — outside the Dart census, unchanged.

## 3. Requirements

### REQ-1 — Single-source constant exists and is the only value-bearing site in `lib/`
`lib/api/sso_client.dart` declares `static const String firstPartyClientId = 'sso-admin-console';` on `SSOAdminClient`. No other `lib/` file may carry the value as a fresh literal; references name the symbol.

**Testable:** `grep -n "static const String firstPartyClientId = 'sso-admin-console'" lib/api/sso_client.dart` hits; `grep -rn "'sso-admin-console'" lib/ --include="*.dart"` → exactly the declaration line; `grep -rn firstPartyClientId lib/` → exactly 3 lines (declaration + 2 re-points).

### REQ-2 — Both production defaults derive from the constant
`SSOAdminClient.login`'s `clientId` default param and `app_router.dart`'s `defaultClientId:` reference `SSOAdminClient.firstPartyClientId` (with the necessary import). The login wire (`payload['client_id'] = _effectiveClientId` at `oidc_authorization_flow.dart:238/295/370`, resolved through `oidc_login_screen.dart:159-161`) therefore always emits the constant's value when no URL `client_id` param overrides it.

**Testable:** `grep -n "String clientId = firstPartyClientId" lib/api/sso_client.dart` hits; `grep -n "defaultClientId: SSOAdminClient.firstPartyClientId" lib/app_router.dart` hits; `grep -n "import 'api/sso_client.dart'" lib/app_router.dart` hits.

### REQ-3 — The three pinned test files are constantized in the same commit
`test/sso_client_test.dart:18`, `test/oidc_account_flow_test.dart:35,75,115,160`, and `test/oidc_login_screen_client_id_test.dart:76,136,158` replace every literal with `SSOAdminClient.firstPartyClientId` (adding the import to each file). The commit is atomic with REQ-1/REQ-2 — the census gate makes any split ordering red. No test is added, removed, or renamed in these files (counts 10/3/17 invariant).

**Testable:** `git show <commit> --stat` lists exactly the two `lib/` files + three `test/` files (plus none of the counted test counts changing); `git show <commit> -- test/` shows only literal→constant replacements and import additions.

### REQ-4 — Literal census flips to the constantExists branch, zero literals remain in `test/`
With the constant present, the dual-state gate (`census_test.dart:109-188`, unchanged) asserts `expect(actual, isEmpty)` — the contiguous quoted literal `'sso-admin-console'` must not appear in any `test/*.dart`. The census file's own self-split (`:112`) and reason strings are excluded by construction (no contiguous quoted literal); the reason string at `:146` carries no closing quote and must not gain one.

**Testable:** `grep -rn "'sso-admin-" "console'"` as one contiguous quoted literal across `test/` → 0 hits (equivalently, the census gate test itself is green); `git diff HEAD -- test/oidc_login_handle_success_census_test.dart` → empty (gate file untouched by this commit).

### REQ-5 — REQ-4 #5 zero-emission invariant is unchanged; T-12 joint stays honest
The census test at `:97-104` ("no auth.login.success emission string in the module") stays green: the console fabricates no `auth.login.success` locally, in `lib/screens/oidc_login` or anywhere in `lib/`. Devtools/local-ring forgery is never evidence. Only the wire `client_id` is guaranteed by this direction.

**Testable:** `grep -rn "auth.login.success" lib/` → exit 1; the census test is part of the 30/30 acceptance command (REQ-6).

### REQ-6 — Edge-generation drill: exactly one sink row, no duplicates, never a false PASS
`tests/integration/audit_login_drill.py` steps 3-5, executed against a live stack (B4-5 dependent):

- **Step 3** — one real `POST {PROXY}/auth/login` carrying `client_id == AGREED_CLIENT_ID` (`'sso-admin-console'`); `access_token` returned, JWT 3-part, `tenant_id` claim extracted (missing claim → FAIL with the B4-1 dependency recorded).
- **Step 4** — `GET {API}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` → **exactly one** row with `client_id == AGREED_CLIENT_ID` (`:182-185`). Sink unverifiable (no response / non-JSON / no token) → leg marked `[proposed]`, deviation recorded, **never a false PASS** (`:175-178`).
- **Step 5** — second identical login → exactly two rows total, no repeated event id/trace_id, count stable after re-settle (`:192-216`); skipped `[proposed]` when step 4 was unverifiable.
- Exit: `1` iff any check failed, else `0`.

**Testable:** against the deployed stack, `python3 tests/integration/audit_login_drill.py` → PASS on steps 3-5 with exit 0; without a stack → SKIP/`[proposed]` with exit 0 (executed: `SKIP … EXIT=0`). Static gate: `grep -n "AGREED_CLIENT_ID = 'sso-admin-console'" tests/integration/audit_login_drill.py` hits at `:31`.

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form | Status |
|---|---|---|---|
| AC-1 | Add `static const String firstPartyClientId = 'sso-admin-console'` to `SSOAdminClient` | REQ-1: declaration grep hits at `lib/api/sso_client.dart`; value-bearing literal count in `lib/` == 1 | ✅ satisfied in working tree |
| AC-2 | Use it as the default param (`lib/api/sso_client.dart:86`) and at `lib/app_router.dart:35` | REQ-2 greps (`String clientId = firstPartyClientId`; `defaultClientId: SSOAdminClient.firstPartyClientId`; import) | ✅ satisfied in working tree |
| AC-3 | Constantize the three pinned test files in the same commit | REQ-3: commit `--stat` shows exactly the 5 files; diff shows literal→constant only; REQ-4 `test/` grep == 0 (the census gate enforces atomicity itself) | ✅ satisfied in working tree (commit not yet made — see §1 state note) |
| AC-4 | `grep "sso-admin-console" test/` == 0 (census flips to constantExists branch) | Contiguous quoted literal grep across `test/` == 0; census gate test green. Note: `grep "sso-admin-console" test/` naively still hits the census's split-const source (`:112`) and reason string (`:146`) — the **contiguous quoted literal** is the census's own semantics and is 0 | ✅ executed: 0 |
| AC-5 | `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` = 30/30 green | Exact command, 30 = 10 + 3 + 17 verified by the count gate inside the run itself (silent test deletion turns the run red) | ✅ executed: **30/30 passed** |
| AC-6 | T-12 joint stays green; REQ-4 #5 zero-emission-string invariant unchanged — devtools/local forgery is never evidence | REQ-5: `grep -rn "auth.login.success" lib/` → exit 1; census REQ-4 #5 test green within the AC-5 run | ✅ executed: 0 hits, 30/30 green |
| AC-7 | Drill Steps 3-5: one POST `/auth/login` with client_id=sso-admin-console → exactly one `auth.login.success` sink row; second login adds no duplicate; unverifiable stack → `[PROPOSED]` deviation, exit 0 | REQ-6: live-stack run exit 0 with PASS on steps 3-5; offline run → SKIP exit 0 (executed: `SKIP … EXIT=0`); drill asserts `CONFIG.client_id == AGREED_CLIENT_ID` (step 1) before any sink leg | ✅ offline leg executed; live-stack leg is B4-5-dependent by contract |

## 5. Dependencies and constraints

- **B4-5** owns the sink-side row generation (`implementation-gate.md:57` dependency column) — the drill's live PASS requires a deployed stack; without one the `[proposed]` deviation branch is the required outcome, never a false PASS.
- **B4-1** (tenant claim parsing) — the drill reads `tenant_id` from the login JWT itself (`:159-165`); a missing claim FAILs with the dependency recorded. The drill does not implement claim parsing.
- **T-12 joint** — the drill is the executable form of the joint's edge-generation half; the rendering half (`audit_log_tab.dart` server read, B6-1a) is owned elsewhere and not required for this direction to land.
- **Sibling commit orderings** — the census gate is ordering-agnostic (dual-state), so this commit may land before or after the anchor's other lenses; the `[RESOLVED]` record names this mechanism as the one that lands the constant.
- **Constraint:** no `lib/screens/admin/` code change; no new emitter; no i18n delta; no test-count change.

## 6. Risks and rollback

- **Split landing (constant or co-sites alone):** red by the census gate itself — the gate is the enforcement, not prose; the fix is completing the other half in the same commit.
- **Reason-string edit at `census_test.dart:146` gaining a closing quote:** would self-hit the census scan and turn the gate red. Rollback: revert the wording; keep the string free of the contiguous quoted literal.
- **Branch A flip later (registry evidence proves `console`):** one-line constant value change + the anchor's REQ-2 co-change list — fully revertible; the census stays green in both orderings (the gate derives from constant existence, not value).
- **Drill run without a stack:** the `[proposed]` path prints the deviation and exits 0 — a false PASS is structurally impossible (`proposed` legs never call `check` with True), verified by the offline execution.
- **Line-number drift (`sso_client.dart:86`→`:92`, `app_router.dart:35`→`:36`):** pins reference the symbols (`firstPartyClientId`, `defaultClientId:`), never the fragile numbers; the census file is byte-identical and line-stable.
