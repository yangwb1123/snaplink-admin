# B6-2 M2 Requirements — `SSOAdminClient.firstPartyClientId` single-source constantization (landed-state verification)

Module: `lib/screens/oidc_login` (analysis bucket `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`, direction 1 "Land the M2 single-source constantization") · Direction id: `land-the-m2-single-source-constantization-ssoadm-6d86d228` · Value: 8 · Risk reduction: 7 · Effort: 4 · Confidence: 8

Status: **requirements — verification only.** The change set this direction specifies **is already landed at HEAD `40acef7`** by commit `db6e435` ("feat(b6-2): firstPartyClientId single-source constant (Branch B)"). Every acceptance check in the direction is satisfiable at HEAD; three of four are verified green by the runs recorded in §6. The anchor spec for the pre-landing state is `docs/proposals/b6-2-lib-screens-oidc-login-client-id-alignment-spec.md` (written at HEAD `e1073ce`); this spec supersedes its §1 verification table with the landed-state coordinates and preserves its requirements 1:1 as testable verification checks.

---

## 1. Verification outcome — every direction citation re-checked

All citations were re-checked against HEAD `40acef7` and the working tree (2026-08-08, requirements stage 13:11Z). Measured coordinates below.

| Direction citation | Verification result at HEAD `40acef7` / working tree |
|---|---|
| `test/oidc_login_handle_success_census_test.dart:114-151` — "literal-census branch: constant absent today → pinned-sites mode; flips to zero-tolerance mode once the constant exists" | **Stale premise, gate itself exact.** Group `client_id literal census (single-source rule, §6.4 gate c)` starts `:109` (both HEAD and WT). The gate is **runtime two-state**: `constantExists` reads `lib/api/sso_client.dart` for `static const String firstPartyClientId` at `:126` (HEAD; WT same). Since the constant landed (`sso_client.dart:82`), the gate **already runs the constantExists branch** (`:144-148` HEAD: `expect(actual, isEmpty)`), not the pinned-sites branch (`:150-154` HEAD, `pinnedSites` decl `:116-120`). The claim "currently runs the pre-sibling branch" was true only at analysis time; it is false at HEAD. |
| `lib/api/sso_client.dart:86` — "clientId = 'sso-admin-console' default" | **Shifted by the landing.** At HEAD `:82` is the declaration `static const String firstPartyClientId = 'sso-admin-console';`; the `login()` default is `:92` `String clientId = firstPartyClientId,`; the POST wire `'client_id': clientId` is `:98`. `:86` no longer exists as a literal site (the doc comment for the constant spans `:80-81`). |
| `lib/app_router.dart:35` — "defaultClientId: 'sso-admin-console'" | **Shifted +1, value constantized.** `:36` `defaultClientId: SSOAdminClient.firstPartyClientId,` inside `resolveProductScreen`'s `ProductEntry.login` arm. The shift is the added `import 'api/sso_client.dart';` — the anchor spec predicted exactly this (`:35 → :36`, "pin the reference, not the line number"). |
| `test/oidc_login_screen_client_id_test.dart:21,77,133,156` — "co-change comments: harness + expects constantized in the same commit" | **Exact in substance, ±1-4 line drift.** `:21-25` doc comment "the three literal sites below … are constantized to `SSOAdminClient.firstPartyClientId` in the same commit as the constant (sibling co-change list, §3.4)"; `:77` harness `defaultClientId: SSOAdminClient.firstPartyClientId,` with co-change comment `:78-79`; `:137`/`:159` `expect(harness.lastClientId, SSOAdminClient.firstPartyClientId)` with "Constantized:" comments `:134`/`:157`. The file carries **zero** literals; the harness counts `loginPosts` and records `lastClientId` per credential-bearing POST (D9 filter `:34`). |
| `test/oidc_account_flow_test.dart:35,75,115,160` — "pinned literal sites to constantize" | **Constantized, +1 line each.** The four pumps now pass `defaultClientId: SSOAdminClient.firstPartyClientId,` at `:36, :76, :116, :161` (forgot-password ×2, signup, verify-email). The +1 is the added `api/sso_client.dart` import. |
| `docs/auto/SUMMARY.md:11` — "lib/api B6-2 pipeline for this deliverable ended PIPELINE_FAILED" | **Off-by-one.** `:11` is the "B6-2 Branch B 收尾" row (DIRECTION_REJECTED, quota filled); the PIPELINE_FAILED row is `:12` (`b6-2-introduce-ssoadminclient-firstpartyclientid-29fd6b77`, failed at requirements). `:17` is the lib/api twin of this direction, RUNNING. Neither changes the requirement; the analysis-time snapshot predates `db6e435`. |
| `tests/integration/audit_login_drill.py:31` — AGREED_CLIENT_ID, step 4 exactly-one row | **Exact.** `:31` `AGREED_CLIENT_ID = 'sso-admin-console'  # Branch B (REQ-0 decision)`; step 1 `:123-125` (`CONFIG.client_id == AGREED_CLIENT_ID`); step 3 login payload `:143-147`; step 4 `:169-184` (exactly one `auth.login.success` row with that client_id; `[proposed]` when the sink is unverifiable `:172-180`); no-false-PASS summary `:286`; clean SKIP `:105-111` (exit 0) without live credentials. Wired at `tests/integration/run_all.py:169` and `tests/integration/full_stack_verify.py:113`. |
| Anchor documents | `docs/proposals/audit-contract-batch-snaplink-console.md:13` `[RESOLVED]` (B6-2) record — exact: Branch B chosen, "sibling 机制落地后统一对齐 `SSOAdminClient.firstPartyClientId`", cites `app_router.dart:35`/`sso_client.dart:86` (pre-landing coordinates, value unchanged). `docs/proposals/b6-2-lib-api-client-id-alignment-spec.md:84-85` REQ-1 — exact: Branch B constant definition + the two production reference sites. `docs/campaigns/implementation-gate.md:57` row 2 — exact: contract records `client_id=sso-admin-console`, acceptance "sink 出现 sso-admin-console login 事件；无重复", dependency B4-5. |

## 2. Substantive findings

1. **The direction is landed, not pending.** `db6e435` (2026-08-08) is exactly the atomic M2 commit the census gate was designed to enforce: constant declaration (`sso_client.dart:82`), both production defaults re-pointed (`:92`, `app_router.dart:36`), all eight test literal sites constantized (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:36/76/116/161`, `oidc_login_screen_client_id_test.dart:77/137/159`), plus the sibling-owned `test/client_id_contract_test.dart` and `test/app_router_client_id_wiring_test.dart`. The census gate therefore flipped to zero-tolerance mode by derivation — with zero edits to the gate file (its own "flip is derived, not hand-edited" invariant).
2. **Literal census is clean in both scopes.** `grep -rn "'sso-admin-console'" test/` → **0 hits** (exit 1); `grep -rn "sso-admin-console" lib/ --include="*.dart"` → **exactly 1 hit** (the declaration, `sso_client.dart:82`). `grep -rn "firstPartyClientId" lib/` → `:82` (decl), `:92` (login default), `:98` (wire), plus `app_router.dart:36`. No drift site exists between the two production references — the sink-side attribution the drill asserts is compile-time linked.
3. **The 30-test count gate is green.** `flutter test` on the direction's three files → **30/30 passed** (census 10 + client_id 3 + sso 17), including the literal-census test executing its `constantExists == true` branch with the `isEmpty` assertion and the 30-sum sub-assertions (`:184-185` HEAD).
4. **Working-tree observables (do not conflate with this direction).** The working tree carries **uncommitted** changes from the in-flight "pin exactly-once" sibling session: the census file gains a `lib/` single-source clause (`libOffenders` walk, `:138-182`) and the count gate is upgraded from 30 to 43 (`:228-275`: +3 `sso_client_login_exactly_once_test.dart`, +10 `entry_ux_test.dart`), plus untracked `test/sso_client_login_exactly_once_test.dart`, `test/developer_login_attribution_census_test.dart`. All measured tests pass in this state too (43-gate satisfied). These are **out of scope** for this direction (its AC-2 pins the standing 30-test gate; no new tests are deliverables).
5. **Drill behavior is exactly the direction's deviation branch.** Without live credentials/stack the drill exits 0 with `SKIP` (`:105-111`, "never a false PASS or FAIL"); with credentials, steps 1-2 (`CONFIG.client_id == AGREED_CLIENT_ID`, redirect-leg URL construction) are value-asserted, and step 4's sink row is asserted only when verifiable, else marked `[proposed]` (`:172-180`, `:286`). The value chain `SSOAdminClient.firstPartyClientId` == `AGREED_CLIENT_ID` == `CONFIG.client_id` default (`tests/integration/test_config.py:43-44`, both `'sso-admin-console'`) holds by grep inspection.

## 3. Requirements (preserving the direction's four acceptance checks 1:1)

### REQ-1 — Single-source constant declared and referenced (direction AC-1)

`lib/api/sso_client.dart` declares `static const String firstPartyClientId = 'sso-admin-console';`; `login()`'s `clientId` default and `lib/app_router.dart`'s `defaultClientId:` reference the constant; no fresh literal anywhere in `lib/`.

**Testable:**
- `grep -n "static const String firstPartyClientId = 'sso-admin-console';" lib/api/sso_client.dart` → hit at `:82`.
- `grep -n "clientId = firstPartyClientId," lib/api/sso_client.dart` → hit at `:92`.
- `grep -n "defaultClientId" lib/app_router.dart` → exactly one hit whose value is `SSOAdminClient.firstPartyClientId` (`:36`).
- `grep -rn "sso-admin-console" lib/ --include="*.dart"` → exactly 1 hit, and that line carries the declaration (`:82`).
- **Measured:** all green at HEAD `40acef7`.

### REQ-2 — Census gate active in zero-tolerance mode; standing 30-test gate green (direction AC-2)

The literal-census test's `constantExists` branch passes — zero hits of the quoted literal in `test/` (every reference goes through the constant) — and the standing 30-test count gate holds (census 10 + client_id 3 + sso 17).

**Testable:**
- `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → all 30 pass; the literal-census test executes the `constantExists == true` branch (`census_test.dart:144-148` HEAD) asserting `expect(actual, isEmpty)`; the count sub-assertions (`census 10`, `client_id 3`, `sso 17`, sum 30, `:184-185` HEAD) hold.
- `grep -rn "'sso-admin-console'" test/ --include="*.dart"` → exit 1 (zero hits).
- **Measured:** 30/30 green; grep exit 1.

### REQ-3 — Widget harness asserts the constant on single-submit and retry; exactly one credential-bearing POST per submit (direction AC-3)

`test/oidc_login_screen_client_id_test.dart` asserts `lastClientId == SSOAdminClient.firstPartyClientId` on the single-submit and retry paths, and exactly one credential-bearing `/auth/login` POST per submit (no duplicates).

**Testable:** the two `testWidgets` in the file — "single submit sends one credential-bearing login POST with the contract client_id" (`loginPosts == 1`, `lastClientId == SSOAdminClient.firstPartyClientId`, `:104-138`) and "retry after 401: exactly one login POST per submit, cumulative 2" (`loginPosts == 2`, `lastClientId == SSOAdminClient.firstPartyClientId`, `:140-161`). Covered by the REQ-2 command; also runnable alone as `flutter test test/oidc_login_screen_client_id_test.dart` (3/3).
- **Measured:** green.

### REQ-4 — T-12 joint: drill value chain and exactly-one sink row, `[proposed]` deviation branch honored (direction AC-4)

Drill steps 1-2 green — `CONFIG.client_id == AGREED_CLIENT_ID == SSOAdminClient.firstPartyClientId`; step 4: exactly one `auth.login.success` sink row with that `client_id`, marked `[proposed]` until the B4-5/B1-5 stack is deployed, per the drill's own deviation branch (never a false PASS).

**Testable:**
- Value chain by inspection: `AGREED_CLIENT_ID = 'sso-admin-console'` (`drill:31`) == `CONFIG.client_id` default (`test_config.py:43-44`) == `SSOAdminClient.firstPartyClientId` value (`sso_client.dart:82`) — `grep -n "sso-admin-console" tests/integration/audit_login_drill.py tests/integration/test_config.py lib/api/sso_client.dart` → the three named sites, all `'sso-admin-console'`.
- `python3 tests/integration/audit_login_drill.py` → exit 0 (PASS or SKIP): with live credentials, steps 1-2 (`:123-139`) and the step-3 payload check (`:143-147`) run green; step 4 (`:169-184`) asserts exactly one row when the sink answers, else `[proposed]`; without credentials the drill SKIPs (`:105-111`) — no false PASS or FAIL in either case.
- **Measured:** exit 0, `SKIP: live authenticated tests require SNAPLINK_TEST_USERNAME and SNAPLINK_TEST_PASSWORD and SNAPLINK_TEST_USER_ID` (no stack/credentials in this environment — the direction's own deviation branch).

## 4. Scope

**In scope:** verification only. The change set (REQ-1 constant + REQ-2 census flip + REQ-3 harness co-change + REQ-4 drill alignment) is already committed at `db6e435`; this direction's deliverable is the evidence-backed verification recorded in §1-§3 and §6. **Zero `lib/` edits are required** unless a check regresses (any regression must be reported, not silently re-landed).

**Out of scope (explicitly not changed):**
- Any value change: Branch B `'sso-admin-console'` is fixed by the `[RESOLVED]` record (`audit-contract-batch-snaplink-console.md:13`) and the contract exception (`implementation-gate.md:57`); Branch A (`'console'`) stays void.
- Any new or removed test in the three counted files (counts 10/3/17 invariant per REQ-2).
- The drill and its wiring (`run_all.py:169`, `full_stack_verify.py:113`): untouched — the value already equals the constant.
- Sibling-owned files: `test/client_id_contract_test.dart`, `test/app_router_client_id_wiring_test.dart` (landed with `db6e435` per the screens anchor REQ-3), `test/sso_client_login_exactly_once_test.dart`, `test/developer_login_attribution_census_test.dart`, and the uncommitted census `lib/` clause + 43-test gate in the working tree (in-flight "pin exactly-once" session) — do not fold them into this direction's change set.
- Any `auth.login.success` emission code (none exists in `lib/`) and any `lib/i18n` delta.

## 5. Requirements traceability

| Requirement | Direction acceptance check | Status at HEAD `40acef7` |
|---|---|---|
| REQ-1 | AC-1 (constant + references + no fresh literal in lib/) | **Landed** (`db6e435`) — verified green |
| REQ-2 | AC-2 (census flips; zero literal in test/; 30-test gate) | **Landed** — verified green (30/30) |
| REQ-3 | AC-3 (harness asserts constant; exactly one POST per submit) | **Landed** — verified green |
| REQ-4 | AC-4 (drill steps 1-2; step 4 `[proposed]` deviation) | **Runnable** — exit 0 SKIP without stack; sink legs `[proposed]` by design |

## 6. Acceptance procedure (executed 2026-08-08, HEAD `40acef7` + working tree)

| # | Command | Expected | Measured |
|---|---|---|---|
| 1 | `grep -rn "sso-admin-console" lib/ --include="*.dart"` | exactly 1 hit, the declaration | ✅ `lib/api/sso_client.dart:82` only |
| 2 | `grep -rn "'sso-admin-console'" test/ --include="*.dart"` | exit 1 (0 hits) | ✅ exit 1 |
| 3 | `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` | 30/30 green, constantExists branch active, 30-sum gate holds | ✅ `+30: All tests passed!` |
| 4 | `flutter test test/oidc_login_screen_client_id_test.dart` | 3/3 green (loginPosts 1/2, lastClientId == constant) | ✅ covered by #3 |
| 5 | `python3 tests/integration/audit_login_drill.py` | exit 0; without stack/credentials: SKIP, no false PASS | ✅ `SKIP: live authenticated tests require SNAPLINK_TEST_USERNAME…`, exit 0 |
| 6 | Value-chain grep | `sso_client.dart:82` == `drill:31` == `test_config.py:43-44` == `'sso-admin-console'` | ✅ all three sites |

## 7. References

- Anchor (pre-landing) spec: `docs/proposals/b6-2-lib-screens-oidc-login-client-id-alignment-spec.md` (§1 verification table, §4 change set, AC-1..AC-4)
- Landing commit: `db6e435` "feat(b6-2): firstPartyClientId single-source constant (Branch B)"
- Census gate: `test/oidc_login_handle_success_census_test.dart:109-186` (HEAD) / `:109-275` (working tree)
- Drill: `tests/integration/audit_login_drill.py` (steps 1-4; wiring `run_all.py:169`, `full_stack_verify.py:113`)
- Contract: `docs/campaigns/implementation-gate.md:57` row 2 (B4-5 dependency; `[proposed]` until deployed)
- Decision record: `docs/proposals/audit-contract-batch-snaplink-console.md:13` (`[RESOLVED]` Branch B)
- Analysis: `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json` (direction 1)
