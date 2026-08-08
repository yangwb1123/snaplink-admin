# B6-2 Design — `oidc_login` lens: `SSOAdminClient.firstPartyClientId` single-source constant + atomic 8-site co-change (Branch B)

Module: `lib/screens/oidc_login` (analysis bucket `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`, direction 1) · Direction: B6-2 (client_id 单一来源常量落地, Branch B) · Value: 9 · Risk reduction: 8 · Effort: 3 · Confidence: 9
Status: **design** — implementation of the requirements spec `docs/proposals/b6-2-lib-screens-oidc-login-client-id-alignment-spec.md` (REQ-1 … REQ-6). Branch B locked by the `[RESOLVED]` record (`audit-contract-batch-snaplink-console.md:13`); not decision-gated. Sibling instances: `b6-2-lib-api-client-id-alignment-{spec,design}.md`, `b6-2-lib-screens-client-id-alignment-{spec,design}.md`, `b6-2-lib-screens-developer-client-id-alignment-{spec,design}.md`, `b6-2-lib-screens-device-client-id-alignment-{spec,design}.md` — where lenses overlap (constant value, drill artifact, `[RESOLVED]` record, `implementation-gate.md:57` row) they name the same artifacts so the change set stays single.

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

The requirements evidence (spec, 145 lines) was re-checked at HEAD `e1073ce` and **every claim holds** — plus the dual-state gate was executed, not just read. Independent findings:

| Evidence claim | Verification result |
|---|---|
| Spec file exists, exactly 145 lines | ✅ `wc -l` → 145; §1 verification table + §2 scope + §3 REQ-1…REQ-6 + §4 six ACs + §5 deps + §6 risks all present |
| `lib/api/sso_client.dart:86` — `login` default `clientId = 'sso-admin-console'` | ✅ exact at HEAD; body map `:88-94` (provider/client_id/scope/resource/credential) as described |
| `lib/app_router.dart:35` — `defaultClientId: 'sso-admin-console'` | ✅ exact at HEAD (pre-import line; lands at `:36` after the M2 import — confirmed in working tree) |
| Exactly **10** literal sites at HEAD (2 production + 8 test) | ✅ `git grep "'sso-admin-console'" HEAD -- lib/ test/` → exactly the 10 cited lines, sorted, no others |
| 8 test sites line-exact; sibling-M2 comments at `oidc_login_screen_client_id_test.dart:77-78/:133-134/:156-157` | ✅ all four `oidc_account_flow_test.dart` pumps (`:35,75,115,160`), harness `:76`, expects `:136,158`, `sso_client_test.dart:18` — exact; comments verbatim ("Constantized to SSOAdminClient.firstPartyClientId in the sibling M2 commit (co-change list §3.4; design §4.2 constant rule)") |
| Census gate `test/oidc_login_handle_success_census_test.dart:109-187`, `constantDecl` at `:114`, pinned allowlist at `:116` | ✅ exact. **Executed, not just read:** with the working-tree constant present, `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → **30/30 green** — the `constantExists` branch asserts `isEmpty` and the tree has zero literals. The gate's dual-state logic (constant absent → pinned allowlist; present → `isEmpty`) is verified by reading both branches; split-landing redness follows from the same logic (constant-only commit: `isEmpty` fails on 8 literal sites; co-sites-only commit: allowlist mismatch) |
| 30-test counts (10/3/17) | ✅ regex `^\s*(test|testWidgets)\(` at HEAD → census 10, client_id 3, sso 17, sum 30; invariant under this change (constantization adds/removes no tests) |
| `[RESOLVED]` at `audit-contract-batch-snaplink-console.md:13`; `implementation-gate.md:57` row 2 | ✅ both exact — row 2 records `client_id=sso-admin-console` (Branch B verify-only, no amendment) |
| Drill `AGREED_CLIENT_ID = 'sso-admin-console'` at `:31`; precondition `:123-125`; payload check `:145-147`; `[proposed]` no-false-PASS at `:172-222`; wiring `run_all.py:169` / `full_stack_verify.py:113` | ✅ all exact. Minor range note (no acceptance impact): no-false-PASS legs continue past `:222` through the read legs to `:289`; the `:172-222` range is the login/sink leg set |
| Chain `_effectiveClientId` (`oidc_login_screen.dart:159-161`, URL param at `oauth_params.dart:59` wins via `.isNotEmpty`) → `oidc_provider_flow.dart:54,87` → `oidc_login_api.dart:48,52` | ✅ all exact; zero literals in the chain; `oidc_login_api.dart` has no default of its own |
| `firstPartyClientId` at HEAD in `lib/` → 0 hits (AC-3 unsatisfied) | ✅ `git grep firstPartyClientId HEAD -- lib/` exit 1; name appears only in docs + census `constantDecl` string + test comments |
| Sibling specs: `b6-2-lib-api-client-id-alignment-spec.md:84-85` REQ-1, AC-3 `:136`; `b6-2-lib-screens-client-id-alignment-spec.md` AC-1 `:127` / AC-3 `:129` | ✅ all unsatisfied at HEAD for the same reason (constant absent); this direction's landing makes them satisfiable |
| `auth.login.success` in `lib/` → 0 at HEAD | ✅ exit 1 |
| Working tree carries the prior implement attempt's **uncommitted M2 edits**; sibling-owned untracked tests exist | ✅ constant at `sso_client.dart:82`, `login` default at `:92` (`clientId = firstPartyClientId,`), `app_router.dart` import at `:3` + wiring at `:36`, all 8 test co-sites constantized, `test/` literal census already 0 (`grep` exit 1), `lib/` census = 1 (declaration only). Untracked `test/client_id_contract_test.dart` + `test/app_router_client_id_wiring_test.dart` present (sibling-owned — **excluded**), plus unrelated B6-1 working-tree changes (`audit_log_tab.dart`, `audit_contract_guard_*`, `implementation-gate.md` G7 count rows, developer guard tests) — **excluded** |
| The 5 M2 files carry **only** M2 hunks | ✅ `git diff --stat` on the 5-file set: 19 insertions / 10 deletions, nothing extraneous |
| **Step-7 baseline measured**: full `flutter test` at clean `e1073ce` (temp worktree, removed after) → **811/811 green**; `python3 -m unittest discover -s tests/unit -p 'test_*.py'` → **18/18 OK** | ✅ executed — the baseline failure set is empty, so the post-commit pass criterion is exact set-equality with zero reds and count 811 (+0, D7) |
| **Contaminated-tree full suite** (M2 + B6-1 working tree) → **827/827 green** (811 baseline + 16 B6-1 tests; M2 delta = 0) | ✅ executed — in-place post-commit runs will show 827, not 811; the worktree-run count pin is the gate (§6.7) |
| **Drill no-stack face**: `python3 tests/integration/audit_login_drill.py` without `SNAPLINK_TEST_USERNAME/PASSWORD/USER_ID` → **exit 0, `SKIP: live authenticated tests require …`** | ✅ executed — corrects the pre-amendment §7 AC-6 phrasing ("not executed — requires a deployed stack"): the credential-gated SKIP path (`audit_login_drill.py:104-109`, `api_login_e2e.py:27-36` idiom) makes the drill executable in a no-stack environment, exit 0, never a false PASS/FAIL |

**Correction carried into this design (no acceptance impact):** the working-tree constant already exists — this design's migration is a **staging + commit** plan (atomic-commit construction), not an edit plan. The constant's landed position is `sso_client.dart:82` (not `:76` as the api sibling's §3.1 draft suggested) and the `login` default lands at `:92`; the spec's AC-5 already pins these landed positions.

---

## 2. Design summary

**Files touched: 2 production + 3 test files, all already edited in the working tree — the design work is the atomic commit construction. Zero new tests, zero new files, zero drill edits, zero doc edits.**

| # | File | Change | Requirement |
|---|---|---|---|
| 1 | `lib/api/sso_client.dart` | `static const String firstPartyClientId = 'sso-admin-console';` (`:82`, next to `nativeDefaultBaseUrl`); `login` default `String clientId = firstPartyClientId,` (`:92`) | REQ-1, REQ-2 |
| 2 | `lib/app_router.dart` | `import 'api/sso_client.dart';` (`:3`); `defaultClientId: SSOAdminClient.firstPartyClientId,` (`:36`) | REQ-2 |
| 3 | `test/sso_client_test.dart` | `:18` → `'client_id': SSOAdminClient.firstPartyClientId` (whole-body map keeps all five keys) | REQ-3 |
| 4 | `test/oidc_account_flow_test.dart` | `:35,75,115,160` → `defaultClientId: SSOAdminClient.firstPartyClientId` (+ import) | REQ-3 |
| 5 | `test/oidc_login_screen_client_id_test.dart` | `:76` harness + `:136,158` expects → `SSOAdminClient.firstPartyClientId` (+ import; sibling-M2 comments fulfilled) | REQ-3 |

Derived, **zero-edit**: `test/oidc_login_handle_success_census_test.dart:109-187` flips from pinned-allowlist to `isEmpty` purely from the constant's existence (REQ-4). Verify-only: `docs/campaigns/implementation-gate.md:57` (already records Branch B), `audit-contract-batch-snaplink-console.md:13` (the `[RESOLVED]` record this commit fulfills), `tests/integration/audit_login_drill.py` + wiring (value already equals the constant; zero diff) (REQ-5).

**Key decisions:**

- **D1 — Constant lives on `SSOAdminClient`** (spec REQ-1): Dart requires default parameter values to be compile-time constants, so once `login`'s default reads `firstPartyClientId`, the compiler makes re-forking impossible at that site. The `app_router.dart` wiring is the residual risk, covered by REQ-2's grep guard.
- **D2 — Branch B is a pure refactor at the value level.** The constant's value equals the existing literal at all 10 HEAD sites and the drill's `AGREED_CLIENT_ID` — zero behavioral delta on the wire; the commit cannot change any request the console emits.
- **D3 — Atomicity is machine-enforced, not prose.** The census gate's dual-state design means: constant without co-sites → `isEmpty` red on 8 literal sites; co-sites without constant → pinned-allowlist red. The constant + 8 co-sites must land in exactly one commit (verified green as a unit: 30/30, §1).
- **D4 — The census gate file is not edited.** Its expectation derives from `File('lib/api/sso_client.dart').readAsStringSync().contains('static const String firstPartyClientId')` — the flip is a consequence of REQ-1, and `git diff test/oidc_login_handle_success_census_test.dart` must stay empty.
- **D5 — Pin symbols, not line numbers.** `app_router.dart`'s `defaultClientId:` moves `:35` → `:36` when the import lands; acceptance greps match `SSOAdminClient.firstPartyClientId`, never `:35`.
- **D6 — Commit construction from a contaminated tree.** The working tree mixes three change sets: the M2 set (5 files, only-M2 hunks — verified), unrelated B6-1 edits (6 files), and untracked sibling/B6-1 files (5). The commit stages **exactly** the 5 M2 files; `git diff --cached` boundaries make contamination visible before commit.
- **D7 — Test counts invariant.** Constantization adds/removes zero tests in the three counted files; the 10/3/17 = 30 pin holds pre- and post-commit (executed: 30/30).

---

## 3. API changes (concrete)

### 3.1 New public symbol — `SSOAdminClient.firstPartyClientId`

`lib/api/sso_client.dart`, adjacent to `nativeDefaultBaseUrl` (`:76-78`), landing at `:82`:

```dart
/// OAuth2 client identifier used by this first-party console for direct
/// login and admin access. Single source of truth: the hosted-login
/// wiring and every test reference this constant instead of a fresh
/// literal (single-source rule).
static const String firstPartyClientId = 'sso-admin-console';
```

This is the **only** production literal site after landing (`grep -rn "'sso-admin-console'" lib/ --include="*.dart"` → exactly 1 hit).

### 3.2 `SSOAdminClient.login` default value source

`lib/api/sso_client.dart:92`:

```dart
String clientId = firstPartyClientId,
```

**No other change to `login`:** signature `(String username, String password, {String clientId, List<String>? resources})` unchanged; body map (`:88-94` — provider, client_id, scope, conditional resource, credential) byte-identical. The default is now a compile-time constant reference — re-forking this site requires an explicit edit (D1).

### 3.3 `lib/app_router.dart` wiring

`import 'api/sso_client.dart';` added after `import 'api/oidc_login_api.dart';` (`:2`); wiring at `:36`:

```dart
defaultClientId: SSOAdminClient.firstPartyClientId,
```

`OidcLoginScreen.defaultClientId` stays `String?` with identical fallback semantics (`oidc_login_screen.dart:159-161`); the URL-param passthrough (`oauth_params.dart:59`) still wins when present. Chain after landing: `defaultClientId` (= constant) → `_effectiveClientId` → `oidc_provider_flow.dart:54` (login POST) / `:87` (`Session.store`) → `oidc_login_api.dart:48,52` (passthrough) — **by reference end-to-end, zero intermediate literals**.

### 3.4 Atomic 8-site test co-change (same commit, REQ-3)

| Site | Change |
|---|---|
| `test/sso_client_test.dart:18` | `'client_id': SSOAdminClient.firstPartyClientId` (whole-body map assertion `:16-22` keeps all five keys) |
| `test/oidc_account_flow_test.dart:35,75,115,160` | `defaultClientId: SSOAdminClient.firstPartyClientId` (+ `import 'package:sso_admin/api/sso_client.dart';`) — value-agnostic flows (forgot-password ×2, signup, verify-email) |
| `test/oidc_login_screen_client_id_test.dart:76,136,158` | harness `defaultClientId:` + both `expect(harness.lastClientId, …)` → `SSOAdminClient.firstPartyClientId` (+ same import); the file's own "sibling M2 commit" comments (`:77-78`, `:133-134`, `:156-157`) are fulfilled and may be updated to past tense |

Every reference resolves at compile time — an absent or renamed constant is a compile error, never a green tautology.

### 3.5 Explicitly unchanged API surface

- `OidcLoginScreen.defaultClientId` — parameter, semantics, fallback all unchanged.
- `OidcLoginApi.probeProviders(String clientId, {String? loginHint})` / `OidcLoginApi.login` — passthrough, no default added.
- `Session.store` signature — unchanged.
- `/auth/login` request shape — byte-identical (D2).
- `tests/integration/audit_login_drill.py` + `run_all.py:169` / `full_stack_verify.py:113` — zero diff; `AGREED_CLIENT_ID` already equals the constant.
- Negative constraint: `test/native_shell_test.dart:98,147,202` (`'native-client'`) is a **distinct value on the same parameter** — untouched, not part of the census.

---

## 4. Compatibility constraints

1. **Zero behavioral delta.** Branch B value == every existing literal == drill `AGREED_CLIENT_ID`; no request the console emits changes. Backward/forward wire compatibility is trivially satisfied (D2).
2. **Atomic-commit constraint.** The census gate is red in both split orderings (§1); the constant + 8 co-sites must be one commit. This is a *positive* constraint: it makes the change set self-validating at review time.
3. **Census gate file zero-diff.** `test/oidc_login_handle_success_census_test.dart` must show no diff; its flip is derived (D4). The 10/3/17 = 30 count pin holds (D7).
4. **Compile-time gate.** Dart const-default semantics make the `login` default re-fork a compile error; the `app_router` wiring is covered by the REQ-2 grep guard. Absent/renamed constant ⇒ the 8 co-sites fail to compile — no vacuous green.
5. **Sibling coordination.** The constant name/value/location match the api/screens/developer/device sibling lenses; `test/client_id_contract_test.dart` + `test/app_router_client_id_wiring_test.dart` are sibling-owned (screens spec REQ-3) and **must not** be folded into this commit — they land in the sibling's change set, and this commit's test-count pin (10/3/17) stays valid because those files are outside the three counted files.
6. **Working-tree hygiene.** Unrelated B6-1 edits (`lib/screens/admin/audit_log_tab.dart`, `test/audit_contract_guard_*`, `test/audit_log_tab_test.dart`, `docs/campaigns/implementation-gate.md`) and untracked B6-1 developer tests stay uncommitted — they belong to other change sets (D6). This commit's `git diff --cached --stat` must show exactly the 5 M2 files.
7. **Line-number fragility.** The `app_router` wiring moves `:35` → `:36` with the import; acceptance pins reference the symbol, not the line (D5). The drill/precondition line pins (`:31/:123-125/:145-147`) are verify-only reads — no edit, no drift.
8. **No scope expansion.** Zero new tests, zero new files, zero emission code (`auth.login.success` stays 0 in `lib/`), zero `lib/i18n` delta, no Branch A work.

---

## 5. Failure modes and mitigations

| # | Failure mode | Detection | Mitigation (built into the design) |
|---|---|---|---|
| F1 | **Split landing** — constant and co-sites in separate commits | Census gate red in the intermediate state, both orderings (constant-only → `isEmpty` fails on 8 literal sites; co-sites-only → pinned-allowlist mismatch) | Atomic commit is enforced by the gate, not prose (D3); rollback = revert the single commit (constant + 8 co-sites together) |
| F2 | **Forgotten future co-site** — a later edit writes a fresh `'sso-admin-console'` literal in `test/` | Census `isEmpty` branch fails immediately — red, never silent | The single-source rule is continuously enforced by the gate — this is the point of the mechanism (REQ-4 reason text: "a forgotten co-site fails here immediately") |
| F3 | **Working-tree contamination** — unrelated B6-1 edits or sibling-owned untracked files folded into the commit | `git diff --cached --stat` shows ≠ 5 files; `git diff --cached -- lib/` shows ≠ the constant + 2 defaults | D6 staging plan (§6 steps 1-3): stage exactly the 5 M2 files; boundary checks before commit make contamination visible |
| F4 | **Sibling file collision** — `client_id_contract_test.dart` / `app_router_client_id_wiring_test.dart` accidentally added | Untracked-file list in `git status`; staged-diff check | Explicitly excluded (§4 item 5); sibling's change set owns them; this commit's count pin (10/3/17) backstops any accidental inclusion *inside* the counted files |
| F5 | **Line-number pin drift** — acceptance greps pinned to `app_router.dart:35` after the import shifts it to `:36` | Grep fails on the stale pin | D5: pin `SSOAdminClient.firstPartyClientId`, never the line; spec AC-5 already carries the landed-`:36` note |
| F6 | **Branch A flip** — drill/registry evidence ever proves the deployed IdP expects `'console'` | Future drill deviation; `[RESOLVED]` record would need re-opening | Documented flip path (anchor spec `:79`, sibling REQ-0): constant value + `sso_client_test.dart:18` + `app_router` wiring + gate/yaml rows + drill `AGREED_CLIENT_ID` in one atomic change set; fully revertible; never a unilateral code change |
| F7 | **Vacuous green** — a co-site that "references the constant" by string interpolation or a renamed-away literal | Compile error (absent symbol) or census `isEmpty` red (fresh literal) | Compile-time references only (D1); the census scans raw file text for the quoted literal — a fresh literal is caught regardless of how it's produced |
| F8 | **Census self-hit / self-miss** — the census file scanning itself, or the derivation string drifting from the real declaration | Gate red in a way that looks like a false failure | Already handled at HEAD: the literal is split (`"'sso-admin-" "console'"`) so the file never self-hits; `constantDecl` is the exact declaration prefix (`static const String firstPartyClientId`) — a renamed constant flips the gate red (absent → pinned-allowlist mismatch on 0 vs 8 sites), forcing a conscious update |
| F9 | **Drill drift** — a later change set recreates or re-wires the drill | `git diff tests/integration/` non-empty in this commit; M4-style wiring grep (`audit_login_drill` at `run_all.py:169` / `full_stack_verify.py:113`) | Adopt-never-re-create rule (anchor design C5); this change set makes zero drill edits; the drill is committed at `3b64c58`, no cleanup hazard |

---

## 6. Migration steps (ordered, each with a verification gate)

The working tree already contains the complete M2 edit set (verified §1) — the migration is **atomic-commit construction**, not code editing.

1. **Baseline verification.** Confirm HEAD is `e1073ce`; confirm the 5 M2 files carry only M2 hunks (`git diff --stat` on the 5-file set → 19 insertions / 10 deletions, nothing else) and the census gate file is untouched.
   *Gate:* `git diff --stat test/oidc_login_handle_success_census_test.dart` empty; `git diff --stat lib/ test/` shows the 5 M2 files **plus** only the unrelated B6-1 files (audit_log_tab / audit_contract_guard_*).
2. **Stage exactly the M2 set (D6).**
   ```
   git add lib/api/sso_client.dart lib/app_router.dart \
         test/sso_client_test.dart test/oidc_account_flow_test.dart \
         test/oidc_login_screen_client_id_test.dart
   ```
   *Gate:* `git diff --cached --stat` → exactly these 5 files; `git diff --cached -- lib/` → constant (`:82`) + `login` default (`:92`) + app_router import + wiring (`:36`) only; `git status` still shows the unrelated files as modified/untracked (uncontaminated).
3. **Test acceptance (30/30).**
   ```
   flutter test test/oidc_login_handle_success_census_test.dart \
              test/oidc_login_screen_client_id_test.dart \
              test/sso_client_test.dart
   ```
   *Gate:* 30/30 green — the census literal-census executes its `constantExists == true` branch (`isEmpty`), and the 10/3/17 count sub-assertions hold. **Executed during design verification: 30/30 (§1).**
4. **Grep guards (REQ-1/2/3, spec §4 AC-1/AC-3/AC-5).**
   - `grep -n "static const String firstPartyClientId" lib/api/sso_client.dart` → hit at `:82` with `= 'sso-admin-console';`
   - `grep -rn "'sso-admin-console'" lib/ --include="*.dart"` → exactly 1 hit (the declaration)
   - `grep -rn "'sso-admin-console'" test/; echo $?` → exit 1 (zero hits)
   - `grep -n "defaultClientId" lib/app_router.dart` → exactly one hit, value `SSOAdminClient.firstPartyClientId`
   - `grep -n "clientId = firstPartyClientId" lib/api/sso_client.dart` → hit at `:92`
   *Gate:* all five as specified.
5. **Verify-only records (REQ-5).**
   - `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` → `:57` hit, file unedited
   - `grep -n "AGREED_CLIENT_ID" tests/integration/audit_login_drill.py` → `:31` `= 'sso-admin-console'`
   - `git diff tests/integration/` → empty
   - `git diff test/oidc_login_handle_success_census_test.dart` → empty (derived flip, D4)
   *Gate:* all as specified.
6. **Commit atomically.** Single commit: constant + 8 co-sites (+ fulfilled-comment updates in the client_id file). Message records the Branch B mechanism and the `[RESOLVED]` trigger.
   *Gate:* `git show --stat HEAD` → exactly the 5 files; `git log -1 --format=%s` names the constantization; working tree retains only the unrelated B6-1 changes (their own change sets).
7. **Full-suite regression — post-landing protocol (hardened).**

   **Baseline commit:** the M2 commit's parent, `e1073ce` — measured during design verification (clean worktree, removed after): full `flutter test` → **811/811 green**; python unit (`python3 -m unittest discover -s tests/unit -p 'test_*.py'`) → **18/18 OK**. The baseline failure set is **empty**, and D7 pins the post-commit count to **811 (+0)** — any count delta is a contamination signal (a folded B6-1 test file would add exactly 16).

   **Who runs (three, in order):**
   1. **Landing owner** (the agent/engineer executing step 6) — immediately after the commit, on a **clean worktree at the new HEAD**. This is mandatory because `flutter test` compiles the *working tree*, not HEAD: the in-place contaminated run shows 827 tests (811 + 16 B6-1), so it is continuity evidence only, never the gate.
   2. **CI** — `.github/workflows/ci.yml` `check` job (`make test` + `make test-browser`) on push: the machine gate. `make test` re-runs the census + co-site files (AC-2/AC-4 machine backstop); the browser suite is Chrome-gated and CI-owned.
   3. **Verification reviewer** — records both results (local + CI) in the campaign record; the drill's live face (AC-6) is owned by the deployment window (§7 table).

   **Commands (landing owner):**
   ```
   git log -1 --stat                       # exactly the 5 M2 files, 19+/10−
   git worktree add /tmp/m2-verify HEAD    # clean checkout of the M2 commit
   cd /tmp/m2-verify && flutter pub get
   flutter test                            # expect 811 tests, all green
   python3 -m unittest discover -s tests/unit -p 'test_*.py'   # 18 OK
   flutter test test/oidc_login_handle_success_census_test.dart \
              test/oidc_login_screen_client_id_test.dart \
              test/sso_client_test.dart    # 30/30 (AC-2/AC-4 on committed tree)
   git worktree remove /tmp/m2-verify
   ```
   then re-run the five step-4 grep guards in committed form `git grep <pattern> HEAD` (symbols, never lines — D5). `make test-browser` result comes from CI.

   **Pass/fail criteria:** post-commit flutter result-set **set-equal to baseline** (all green, count 811) AND python unit 18 OK AND 30/30 acceptance green AND `git log -1 --stat` = exactly the 5 files (19+/10−) AND census file zero-diff in the commit. **Any red, any count ≠ 811, any 6th file, or any census-file diff = FAIL.** Because the baseline is fully green, "no failures beyond the pre-existing baseline" resolves to **zero failures** — no known-red allowance exists.

   **Rollback path:** `git revert HEAD` (or `git reset --hard HEAD~1` if unpushed) — one command reverts constant + 8 co-sites together (F1's both-faces property; the split is impossible by construction). Re-verify: `flutter test` back to 811 green, `git status` shows only the unrelated B6-1 changes, then re-enter at step 2.

   **Atomic-fix path:** a regression fix is **never a second partial commit** (that would re-open F1). Fix within the 5 M2 files, re-stage (step 2), re-run gates 3-5 + 30/30, then `git commit --amend` (unpushed) or a fresh full M2 commit (pushed). A red in any file outside the 5 M2 files + census gate is *by construction* not this commit's (the commit touches only those files): revert first, then investigate the owning change set — never fix-forward across change sets.

No data migration, no schema change, no server interaction, no feature flags.

---

## 7. Testable acceptance mapping (spec §4 table, 1:1)

| # | Spec acceptance (supplied) | Testable form (verification status) |
|---|---|---|
| AC-1 | `grep -n "static const String firstPartyClientId" lib/api/sso_client.dart` hits, value `'sso-admin-console'` (Branch B; contract exception already recorded at `implementation-gate.md:57`) | **Executed (working tree):** `:82` = `static const String firstPartyClientId = 'sso-admin-console';`; lib census = exactly 1 hit (`sso_client.dart:82`); gate row `:57` unedited. Post-landing form: `git grep -n "static const String firstPartyClientId" HEAD -- lib/api/sso_client.dart` + `git grep -rn "'sso-admin-console'" HEAD -- lib/` → 1 hit. Owner: landing owner (step 4 + §6.7 re-run); grep ACs are not in CI — the long-term backstop is the census gate itself (CI runs `make test`). |
| AC-2 | `flutter test test/oidc_login_handle_success_census_test.dart` green — gate c auto-flips: `test/` literal census asserts `isEmpty`, 30-test count (10+3+17) holds | Command green; literal-census group (`:109-187`) executes the `constantExists == true` branch asserting `isEmpty`; count sub-assertions hold (10/3/17/30); `git diff test/oidc_login_handle_success_census_test.dart` empty ✅ (**executed: 30/30 green, §1**) |
| AC-3 | `grep -rn "'sso-admin-console'" test/` → exit 1 (zero drift literals; sibling co-change list = the 8 sites) | **Executed (working tree):** exit 1, zero hits. Post-landing form: `git grep -n "'sso-admin-console'" HEAD -- test/; echo $?` → exit 1. Owner: landing owner (§6.7 re-run); permanent enforcement after landing is the census `isEmpty` branch under CI — a forgotten future co-site is red on the next `make test`. |
| AC-4 | `flutter test test/sso_client_test.dart test/oidc_login_screen_client_id_test.dart test/oidc_account_flow_test.dart` green — client_id chain by constant reference, compile-time gate | Command green; all 8 co-sites resolve `SSOAdminClient.firstPartyClientId` at compile time; `grep -rn "'sso-admin-console'" lib/screens/oidc_login/ lib/api/oidc_login_api.dart` → 0 hits (chain by reference) ✅ (**executed within the 30/30 run**) |
| AC-5 | `grep -n "defaultClientId" lib/app_router.dart` → single hit referencing `SSOAdminClient.firstPartyClientId` (`sso_client.dart:92` default sync'd) | **Executed (working tree):** exactly one hit, `:36` `defaultClientId: SSOAdminClient.firstPartyClientId,`; `:92` `clientId = firstPartyClientId,`. Post-landing form: `git grep -n "defaultClientId" HEAD -- lib/app_router.dart` → 1 hit; `git grep -n "clientId = firstPartyClientId" HEAD -- lib/api/sso_client.dart` → `:92`. Owner: landing owner (§6.7 re-run); D1's const-default semantics are the compile-time backstop. |
| AC-6 | `python3 tests/integration/audit_login_drill.py` still asserts `client_id=sso-admin-console` (Branch B recorded value); un-deployed stack → sink legs `[proposed]`, no false PASS | **Executed — both faces:** static face — `AGREED_CLIENT_ID` at `:31` = `'sso-admin-console'` (Branch B); `git diff tests/integration/` empty; wiring at `run_all.py:169` / `full_stack_verify.py:113`; `[proposed]` legs at `:172-222` (extends to `:289` — read legs; no acceptance impact). Executable no-stack face — `python3 tests/integration/audit_login_drill.py` without `SNAPLINK_TEST_USERNAME/PASSWORD/USER_ID` → **exit 0, SKIP** (credential gate at `:104-109`; never a false PASS/FAIL). Live face (deployment window only): full run with credentials + stack, exit 0 = PASS or PASS-with-`[proposed]` (steps 4-6 unverifiable → recorded in the `[RESOLVED]` note per the drill's own step-7 instruction). |

**Post-landing execution owners and gates (every AC has an owner; none is left to the commit message):**

| AC | Post-landing owner | Gate / trigger | Fail action |
|---|---|---|---|
| AC-1 | Landing owner (§6.7), verification reviewer | `git grep` declaration + lib census + gate row at new HEAD, immediately post-commit, before push | Block push; re-stage (step 2) |
| AC-2 | Landing owner + **CI** (`make test` runs the census file) | 30/30 on the committed tree (§6.7 worktree command); CI green on push | Revert (atomic), re-enter step 2 |
| AC-3 | Landing owner + **CI** (census `isEmpty` branch enforces zero `test/` literals forever after landing) | `git grep -n "'sso-admin-console'" HEAD -- test/` → exit 1 (§6.7) | Revert (atomic), re-enter step 2 |
| AC-4 | Landing owner + **CI** (`make test` compiles all co-site files; D1 compile gate) | 30/30 on the committed tree; CI green | Revert (atomic), re-enter step 2 |
| AC-5 | Landing owner (§6.7), verification reviewer | `git grep "defaultClientId" HEAD -- lib/app_router.dart` → 1 hit; `:92` default sync | Block push; amend the 5-file set |
| AC-6 static | Landing owner (§6.7) | `:31` value + `git diff tests/integration/` empty + wiring `run_all.py:169`/`full_stack_verify.py:113` | Block push; restore drill zero-diff |
| AC-6 live | Deployment window owner (`make full-stack` → `full_stack_verify.py:113`; `run_all.py:169`); **not** CI `make integration` (drill is not wired there) | `python3 tests/integration/audit_login_drill.py` exit 0 — PASS, PASS-with-`[proposed]`, or SKIP (no credentials); FAIL = exit 1; `[proposed]` recorded in the `[RESOLVED]` note | Fix in the owning change set; never a code change to this commit |

Gate relationship (spec §4): all six apply unconditionally (Branch B locked — no branch disjunction remains). AC-2 and AC-3 are the same gate seen from the commit's two faces — AC-2 proves the census flipped, AC-3 proves no literal survived; with AC-4's compile-time references they pin the single-source rule from both directions.

---

## 8. Out of scope (unchanged, explicitly)

- **Any value change:** Branch B keeps `'sso-admin-console'` everywhere; Branch A (rename to `'console'`) is void, kept only for traceability (F6 flip path).
- **Any new test or test file:** counts 10/3/17 invariant; sibling-owned `test/client_id_contract_test.dart` / `test/app_router_client_id_wiring_test.dart` land in the sibling's change set.
- **`tests/integration/` entirely:** drill + wiring untouched; `[proposed]` sink semantics unchanged.
- **Request shape, signature, transport:** `/auth/login` body, `login` signature, `defaultClientId` parameter, `_effectiveClientId` chain — all as-is.
- **Emission code and `lib/i18n`:** zero `auth.login.success` in `lib/` (stays zero); zero i18n delta.
- **Docs:** `implementation-gate.md`, `audit-contract-batch-snaplink-console.md`, campaign yaml — no edits (verify-only records).
- **Unrelated working-tree changes:** B6-1 audit-guard work and developer-boundary tests stay out of this commit (D6, F3).
