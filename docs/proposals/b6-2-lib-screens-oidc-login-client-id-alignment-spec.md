# B6-2 Requirements Specification — client_id 单一来源常量落地（Branch B）：`SSOAdminClient.firstPartyClientId` + 原子共变

Module: `lib/screens/oidc_login` (analysis bucket `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`, direction 1) · Direction: B6-2 (pending sibling M2 commit) · Value: 9 · Risk reduction: 8 · Effort: 3 · Confidence: 9
Status: requirements — **Branch B locked** by the `[RESOLVED]` record (`audit-contract-batch-snaplink-console.md:13`); not decision-gated. This is the constantization commit the record announces ("sibling 机制落地后统一对齐 `SSOAdminClient.firstPartyClientId`").
Sibling instances: `b6-2-lib-api-client-id-alignment-spec.md` + `-design.md`, `b6-2-lib-screens-client-id-alignment-spec.md` + `-design.md`, `b6-2-lib-screens-developer-client-id-alignment-spec.md` + `-design.md`, `b6-2-lib-screens-device-client-id-alignment-spec.md` + `-design.md`. Where the lenses overlap (constant value, drill artifact, `[RESOLVED]` record, `implementation-gate.md:57` row), they name the same artifacts so the change set stays single.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD (`e1073ce`). All ten hold exactly:

| Direction citation | Verification result |
|---|---|
| `lib/api/sso_client.dart:86` — `login` default `clientId = 'sso-admin-console'` | **Exact.** `:86` `String clientId = 'sso-admin-console',`; POST `/auth/login` body carries `'client_id': clientId` at `:92` (remaining keys `:88-94`: provider/scope/resource/credential). One of the only two production literal sites (`git grep "'sso-admin-console'" HEAD -- lib/` → exactly `sso_client.dart:86` + `app_router.dart:35`). |
| `lib/app_router.dart:35` — `defaultClientId: 'sso-admin-console'` | **Exact.** `:34-36` `ProductEntry.login => OidcLoginScreen(defaultClientId: 'sso-admin-console', …)`. |
| `test/sso_client_test.dart:18` — asserts current client id | **Exact.** `:18` `'client_id': 'sso-admin-console',` inside the whole-body map assertion (`:16-22`, five keys: provider/client_id/scope/resource/credential). |
| `test/oidc_account_flow_test.dart:35,75,115,160` — 4 literal sites | **Exact.** Four `defaultClientId: 'sso-admin-console',` widget pumps (forgot-password ×2, signup, verify-email). |
| `test/oidc_login_screen_client_id_test.dart:76,136,158` — 3 literal sites | **Exact.** `:76` harness `defaultClientId:`; `:136`/`:158` `expect(harness.lastClientId, 'sso-admin-console')`. The file's own comments announce the pending constantization: "Constantized to SSOAdminClient.firstPartyClientId in the sibling M2 commit (co-change list §3.4; design §4.2 constant rule)" (`:77-78`) and "expect: constantized to SSOAdminClient.firstPartyClientId … once the sibling constant exists" (`:133-134`, `:156-157`). |
| `test/oidc_login_handle_success_census_test.dart:109-187` — dual-state census gate (§6.4 gate c) | **Exact.** Group `client_id literal census (single-source rule, §6.4 gate c)` spans `:109-187`. `constantExists` is derived from scanning `lib/api/sso_client.dart` for `static const String firstPartyClientId` (`:114`): constant absent → literal census equals exactly the pinned allowlist `{sso_client_test.dart: [18], oidc_account_flow_test.dart: [35, 75, 115, 160], oidc_login_screen_client_id_test.dart: [76, 136, 158]}`; constant present → `expect(actual, isEmpty)` with reason "every reference goes through the constant". The same test carries the standing 30-test count gate (`:148-186`): census file 10 + client_id file 3 + sso file 17 = 30 (regex `^\s*(test|testWidgets)\(`). **The gate is red in any split landing ordering** (constant without co-sites → isEmpty fails on the 8 still-literal sites; co-sites without constant → pinned-allowlist fails) — atomic commit is enforced by the gate itself, not by prose. |
| `docs/proposals/audit-contract-batch-snaplink-console.md:13` — `[RESOLVED]` (B6-2) note | **Exact.** Line 13 (B6-2 边缘生成验证 section): "`[RESOLVED]`（B6-2, 2026-08-07）：**Branch B**（contract exception）chosen …；sibling 机制落地后统一对齐 `SSOAdminClient.firstPartyClientId`". The record already names this direction as the mechanism that lands the constant. |
| `docs/proposals/b6-2-lib-api-client-id-alignment-spec.md:84-85` — REQ-1 (Branch B constant) | **Exact.** REQ-1 at `:84-85` defines the constant: Branch A `'console'` / Branch B `'sso-admin-console'`, used as (a) `SSOAdminClient.login`'s `clientId` default and (b) `defaultClientId` at `app_router.dart:35`. Its AC-3 (`:136`) is unsatisfied at HEAD — `git grep firstPartyClientId HEAD -- lib/` → **0 hits** (the name appears only in docs + two test files' comments: the census `constantDecl` string at `census_test.dart:114` and the client_id file's co-change comments). |
| `docs/proposals/b6-2-lib-screens-client-id-alignment-spec.md` — AC-1/AC-3 | AC-1 (`:127`) and AC-3 (`:129`) are unsatisfied at HEAD for the same reason (constant absent); this direction's landing is what makes them satisfiable: AC-1's Branch B path = "unchanged literal … with the `[RESOLVED]` exception note" and AC-3's `git diff test/sso_client_test.dart` shows only the `client_id` line. Its REQ-1 testable form already states the post-landing guard: `grep -rn "'sso-admin-console'" test/` → 0 hits. |
| `docs/campaigns/implementation-gate.md:57` — contract row 2 | **Exact.** Row 2 (console): "边缘生成验证：login → `auth.login.success`（client_id=sso-admin-console）| sink 出现 sso-admin-console login 事件；无重复 | B4-5". The contract **already records `sso-admin-console`** — Branch B is verify-only, no amendment (no-op), per REQ-0 of the sibling specs. |
| `tests/integration/audit_login_drill.py` — drill asserts `client_id=sso-admin-console` | **Exact.** Exists (untracked artifact adopted by the sibling change set; wired at `tests/integration/run_all.py:169` and `tests/integration/full_stack_verify.py:113`). `AGREED_CLIENT_ID = 'sso-admin-console'` at `:31` (Branch B comment); precondition check `CONFIG.client_id == AGREED_CLIENT_ID` (`:123-125`); login-payload check (`:145-147`); sink legs marked `[proposed]` with "no false PASS" when no stack/emission (`:172-222`). **No change under this direction** — the value is already the Branch B constant value. |

Additional verified facts that shape the spec:

1. **The client_id chain is already constant-flow-ready (compile-time gate).** `OidcLoginScreen._effectiveClientId` (`lib/screens/oidc_login/oidc_login_screen.dart:159-161`, URL-param passthrough at `oauth_params.dart:59` wins via `.isNotEmpty`) → `lib/screens/oidc_login/oidc_provider_flow.dart:54` (`'client_id': _effectiveClientId` in the login POST) and `:87` (`clientId: _effectiveClientId` in `Session.store`) → `lib/api/oidc_login_api.dart:48,52` (`probeProviders(clientId, …)` → `'client_id': clientId` — passthrough, no literal, no default of its own). Once the two production defaults reference the constant, every emitted value derives from it by reference — no intermediate literal exists anywhere in the chain.
2. **HEAD literal census is exactly the 10 sites the direction names** (2 production + 8 test): `git grep "'sso-admin-console'" HEAD -- lib/ test/` → 10 hits, no others. `tests/integration/test_config.py:44`, `tests/integration/README.md:17`, `DEPLOY.md:29`, and the two docs carry the value as config/registry/contract text — not Dart literals, excluded from the census (consistent with the sibling specs' `lib/`/`test/` Dart scope).
3. **Test counts verified at HEAD** (same regex as the count gate): census 10, client_id 3, sso 17 — 30 total. Constantization adds/removes **zero** tests in these three files; the counts are invariant under this change.
4. **Working-tree state (observable, shapes the change set):** a prior implement attempt left the M2 edits **uncommitted** — constant at `sso_client.dart:82`, `app_router.dart:36` wiring, all 8 test co-sites constantized, `test/` literal census already 0. The change set for this direction must be one atomic commit containing exactly the constant + 8 co-sites (the census gate makes any split ordering red). The untracked `test/client_id_contract_test.dart` and `test/app_router_client_id_wiring_test.dart` are **sibling-owned** (screens spec REQ-3) — not deliverables of this direction; do not fold them into this commit.
5. **App-router line shift:** the `defaultClientId:` wiring moves from `:35` to `:36` when `import 'api/sso_client.dart';` is added — the direction's `:35` is the HEAD pre-change line; acceptance pinning references the symbol, not the fragile line number.

---

## 2. Scope

**In scope**

- The single-source-of-truth constant: `static const String firstPartyClientId = 'sso-admin-console';` on `SSOAdminClient` (`lib/api/sso_client.dart`), Branch B value (REQ-1).
- The two production defaults re-pointed at the constant: `SSOAdminClient.login`'s `clientId` default (`sso_client.dart:86`) and `defaultClientId:` in `lib/app_router.dart:35` (REQ-2).
- The atomic 8-site test co-change: `test/sso_client_test.dart:18`, `test/oidc_account_flow_test.dart:35,75,115,160`, `test/oidc_login_screen_client_id_test.dart:76,136,158` — all references through the constant, zero fresh literals (REQ-3).
- The derived census flip: `test/oidc_login_handle_success_census_test.dart:109-187` flips from pinned-allowlist to `isEmpty` in the same commit, **with zero edits to the gate file**; the 30-test count (10+3+17) holds (REQ-4).
- Branch B record consistency: `docs/campaigns/implementation-gate.md:57` verify-only (already records `client_id=sso-admin-console`; no amendment); `audit-contract-batch-snaplink-console.md:13` `[RESOLVED]` record is the authority this commit fulfills (REQ-5).

**Out of scope (explicitly not changed)**

- Any value change: Branch B keeps `'sso-admin-console'` everywhere; Branch A (rename to `'console'`) is void and kept only for traceability (flip path documented in the anchor spec REQ-0 / `b6-2-lib-screens-oidc-login-handle-success-anchor-spec.md:79`).
- Any new test file or new test in the three counted files (counts 10/3/17 invariant); the sibling-owned `test/client_id_contract_test.dart` / `test/app_router_client_id_wiring_test.dart` are not this direction's deliverables.
- `tests/integration/audit_login_drill.py` and its wiring (`run_all.py:169`, `full_stack_verify.py:113`): untouched — the value already equals the constant.
- Request-shape, signature, or transport changes: `/auth/login` body keys (`sso_client.dart:88-94`), `SSOAdminClient.login` signature, `OidcLoginScreen.defaultClientId` parameter, and the `_effectiveClientId` chain all stay as-is.
- Any `auth.login.success` emission code (none exists; `git grep "auth.login.success" HEAD -- lib/` → 0) and any `lib/i18n` delta.

---

## 3. Requirements

### REQ-1 — Constant declaration (single source of truth)

Declare on `SSOAdminClient` in `lib/api/sso_client.dart`:

```dart
static const String firstPartyClientId = 'sso-admin-console';
```

Branch B value, fixed by the `[RESOLVED]` record (`audit-contract-batch-snaplink-console.md:13`) and the already-recorded contract exception (`implementation-gate.md:57` row 2 — verify-only, no amendment). The declaration is the **only** production site that carries the value as a literal.

**Testable:** `grep -n "static const String firstPartyClientId" lib/api/sso_client.dart` hits, and the line carries `= 'sso-admin-console';`; `grep -rn "'sso-admin-console'" lib/ --include="*.dart"` → exactly 1 hit (the declaration); `grep -rn "firstPartyClientId" lib/` → ≥ 1 hit (was 0 at HEAD).

### REQ-2 — Production wiring references the constant

- `lib/api/sso_client.dart:86`: `String clientId = firstPartyClientId,` (the `login` default; unqualified inside the class).
- `lib/app_router.dart:35`: `defaultClientId: SSOAdminClient.firstPartyClientId,` with `import 'api/sso_client.dart';` added (line shifts to `:36` — pin the reference, not the line number).

**Testable:** `grep -n "defaultClientId" lib/app_router.dart` → exactly one hit whose value is `SSOAdminClient.firstPartyClientId`; `grep -n "clientId = firstPartyClientId" lib/api/sso_client.dart` hits; `grep -rn "'sso-admin-console'" lib/ --include="*.dart"` → 1 hit (REQ-1's declaration only).

### REQ-3 — Atomic 8-site test co-change (same commit as REQ-1/REQ-2)

Constantize all eight test literal sites in the **same commit** as the constant — the census gate (REQ-4) is red in any split ordering, so atomicity is machine-enforced:

| Site | Change |
|---|---|
| `test/sso_client_test.dart:18` | `'client_id': SSOAdminClient.firstPartyClientId` (whole-body map assertion keeps all five keys) |
| `test/oidc_account_flow_test.dart:35,75,115,160` | `defaultClientId: SSOAdminClient.firstPartyClientId` (+ `import 'package:sso_admin/api/sso_client.dart';`) |
| `test/oidc_login_screen_client_id_test.dart:76,136,158` | harness `defaultClientId:` and both `expect(harness.lastClientId, …)` → `SSOAdminClient.firstPartyClientId` (+ same import; the file's own "sibling M2 commit" comments at `:77-78`/`:133-134`/`:156-157` are fulfilled and may be updated to past tense) |

The three files are the anchor lens's co-change list (screens spec REQ-2, anchor design §4.2) plus the `lib/api` lens's `sso_client_test.dart` site — the direction names exactly these 8.

**Testable:** `grep -rn "'sso-admin-console'" test/` → exit 1 (zero hits); `flutter test test/sso_client_test.dart test/oidc_login_screen_client_id_test.dart test/oidc_account_flow_test.dart` green — every reference resolves `SSOAdminClient.firstPartyClientId` at compile time (absent/renamed constant ⇒ compile error, never a green tautology).

### REQ-4 — Census gate c derived flip (zero edits to the gate)

`test/oidc_login_handle_success_census_test.dart` is **not edited** by this change. Its `client_id literal census` group (`:109-187`) derives the expectation from the constant's existence: with REQ-1 landed, it asserts `test/` carries **zero** `'sso-admin-console'` literals (the "single-source rule active" branch, reason text "a forgotten co-site fails here immediately (red, not silent)"). The standing 30-test count gate (`:148-186`) must stay green: census 10 + client_id 3 + sso 17 — this change adds/removes no tests.

**Testable:** `flutter test test/oidc_login_handle_success_census_test.dart` green; `grep -cE '^\s*(test|testWidgets)\(' test/oidc_login_handle_success_census_test.dart` → 10, `test/oidc_login_screen_client_id_test.dart` → 3, `test/sso_client_test.dart` → 17 (sum 30, unchanged from HEAD).

### REQ-5 — Chain integrity, drill unchanged, Branch B records consistent

- The `client_id` chain flows by reference end-to-end: `OidcLoginScreen.defaultClientId` (= constant, `app_router.dart:36`) → `_effectiveClientId` (`oidc_login_screen.dart:159-161`) → `oidc_provider_flow.dart:54` (login POST) / `:87` (`Session.store`) → `oidc_login_api.dart:48,52` (passthrough `'client_id': clientId`). No intermediate literal exists; `oidc_login_api.dart` has no default of its own.
- `tests/integration/audit_login_drill.py` unchanged: `AGREED_CLIENT_ID = 'sso-admin-console'` (`:31`) equals the constant value; sink legs remain `[proposed]`-marked with no false PASS when no deployed stack/emission (`:172-222`); wiring at `run_all.py:169` / `full_stack_verify.py:113` untouched.
- `docs/campaigns/implementation-gate.md:57` row 2 unchanged (already records `client_id=sso-admin-console` — Branch B verify-only, no amendment); `audit-contract-batch-snaplink-console.md:13` `[RESOLVED]` record names this mechanism as the trigger it fulfills.

**Testable:** `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits at `:57` (unedited); `grep -n "AGREED_CLIENT_ID" tests/integration/audit_login_drill.py` → `:31` with value `'sso-admin-console'`; `git diff tests/integration/` empty.

### REQ-6 — No-regression / zero-delta boundaries

- No change to the `/auth/login` request shape (`sso_client.dart:88-94` keys untouched), `SSOAdminClient.login` signature, `OidcLoginScreen.defaultClientId` parameter, or the `_effectiveClientId` chain shape.
- The production diff is exactly: constant declaration + `sso_client.dart:86` default + `app_router.dart:35` wiring value (+ import). The test diff is exactly the 8 co-sites.
- No new endpoints, no emission code (`grep -rn "auth.login.success" lib/` stays 0), no `lib/i18n` delta.
- `test/oidc_login_handle_success_census_test.dart` and `tests/integration/audit_login_drill.py` show **zero** diff.

**Testable:** `git diff --stat lib/` shows only `lib/api/sso_client.dart` + `lib/app_router.dart`; full `flutter test` green; `git diff test/oidc_login_handle_success_census_test.dart` empty.

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | `grep -n "static const String firstPartyClientId" lib/api/sso_client.dart` 命中且值为 `'sso-admin-console'`（Branch B，contract exception 已记录于 implementation-gate.md:57，无需改契约） | `grep -n "static const String firstPartyClientId" lib/api/sso_client.dart` → hit on the declaration whose value is `'sso-admin-console'`; `grep -rn "'sso-admin-console'" lib/ --include="*.dart"` → exactly 1 hit (the declaration); `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` → `:57` hit, unedited (verify-only) |
| AC-2 | `flutter test test/oidc_login_handle_success_census_test.dart` 绿——gate c 自动翻转：test/ 下 `'sso-admin-console'` 字面量 census 断言 isEmpty，且 30-test 计数门（10+3+17）保持 | `flutter test test/oidc_login_handle_success_census_test.dart` green; the literal-census test (`:109-187`) executes its `constantExists == true` branch asserting `isEmpty`; count sub-assertions hold (census 10, client_id 3, sso 17, sum 30) — `git diff test/oidc_login_handle_success_census_test.dart` empty (the flip is derived, not hand-edited) |
| AC-3 | `grep -rn "'sso-admin-console'" test/` → exit 1（无漂移字面量，sibling 共变清单含 sso_client_test.dart:18、oidc_account_flow_test.dart 4 处、oidc_login_screen_client_id_test.dart 3 处） | `grep -rn "'sso-admin-console'" test/; echo $?` → exit 1, zero hits — the 8 co-sites of REQ-3 are constantized in the same commit as the constant (gate c makes any forgotten site red immediately) |
| AC-4 | `flutter test test/sso_client_test.dart test/oidc_login_screen_client_id_test.dart test/oidc_account_flow_test.dart` 全绿（client_id 链 `_effectiveClientId` → oidc_provider_flow.dart:54,87 → oidc_login_api.dart 经常量引用，编译期门） | Command green; compile-time gate: all 8 co-sites resolve `SSOAdminClient.firstPartyClientId` (absent/renamed constant ⇒ compile error); the chain `oidc_login_screen.dart:159-161` → `oidc_provider_flow.dart:54,87` → `oidc_login_api.dart:48,52` carries the value by reference with no intermediate literal (verified by `grep -rn "'sso-admin-console'" lib/screens/oidc_login/ lib/api/oidc_login_api.dart` → 0 hits) |
| AC-5 | `grep -n "defaultClientId" lib/app_router.dart` → :35 引用 SSOAdminClient.firstPartyClientId（lib/api/sso_client.dart:86 默认参数同步改引常量） | `grep -n "defaultClientId" lib/app_router.dart` → exactly one hit whose value is `SSOAdminClient.firstPartyClientId` (the wiring line lands at `:36` after the added import — the direction's `:35` is the HEAD pre-change line; pin the symbol, not the line number); `grep -n "clientId = firstPartyClientId" lib/api/sso_client.dart` → hit at the `login` default (`:92` in the landed file) |
| AC-6 | `python3 tests/integration/audit_login_drill.py` 仍断言 client_id=sso-admin-console（Branch B 已记录值）；未部署栈时 sink 断言 [proposed] 标记、无 false PASS | `grep -n "AGREED_CLIENT_ID" tests/integration/audit_login_drill.py` → `:31` `= 'sso-admin-console'` (matches the constant value, unchanged); `git diff tests/integration/` empty; drill exit 0 = PASS/SKIP only — sink legs marked `[proposed]` with "no false PASS" (`:172-222`) when no deployed stack/emission; wiring intact at `run_all.py:169` / `full_stack_verify.py:113` |

Gate relationship: all six apply unconditionally (Branch B is locked — no branch disjunction remains). AC-2/AC-3 are the same gate seen from the commit's two faces: AC-2 proves the census flipped, AC-3 proves no literal survived; together with AC-4's compile-time references they pin the single-source rule from both directions.

---

## 5. Dependencies and constraints

- **`[RESOLVED]` record as trigger:** `audit-contract-batch-snaplink-console.md:13` names this mechanism ("sibling 机制落地后统一对齐 `SSOAdminClient.firstPartyClientId`"); the commit fulfills it without re-opening the Branch A/B decision (Branch B value verified by the drill's `AGREED_CLIENT_ID`, `audit_login_drill.py:31`).
- **Contract authority:** `implementation-gate.md:57` row 2 already records `client_id=sso-admin-console` — verify-only, zero gate edits (B4-5 owns the row; no amendment needed).
- **Gate-c atomicity:** the census gate's dual-state design (`census_test.dart:109-187`) makes a split landing red in both orderings — the constant + 8 co-sites must be one commit.
- **Sibling consistency:** the constant name, value, and location match `b6-2-lib-api-client-id-alignment-spec.md` REQ-1 (`:84-85`) and the screens/developer/device sibling lenses, so all module buckets land one change set; the sibling-owned `test/client_id_contract_test.dart` (screens spec REQ-3) is **not** part of this commit.
- **Constraints:** zero new tests in the three counted files (10/3/17 invariant); zero `lib/i18n` delta; zero emission code; no request-shape or signature changes (REQ-6); the drill file is adopted as-is, never recreated.

## 6. Risks and rollback

- **Split landing** (constant and co-sites in separate commits): gate c red in the intermediate state — the commit is atomic by construction; rollback = revert the single commit (constant + 8 co-sites together).
- **Forgotten co-site later** (a future edit writes a fresh literal): gate c's `isEmpty` branch fails immediately (red, not silent) — the single-source rule is continuously enforced, which is the point of the mechanism.
- **Future Branch A flip** (drill/registry evidence ever proves the deployed IdP expects `console`): the documented flip path (`anchor-spec.md:79`, sibling REQ-0) — constant value + `sso_client_test.dart:18` + `app_router.dart` wiring + gate/yaml rows in one change set; fully revertible; the `[RESOLVED]` record must be re-opened.
- **Working-tree contamination** (prior uncommitted M2 edits already in the tree): the change set must commit exactly the constant + 8 co-sites and exclude sibling-owned untracked files (`client_id_contract_test.dart`, `app_router_client_id_wiring_test.dart`) and unrelated b6-1 working-tree changes — `git diff --stat` boundaries in REQ-6 make any contamination visible.
