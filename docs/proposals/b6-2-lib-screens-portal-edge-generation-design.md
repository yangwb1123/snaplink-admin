# B6-2 Design — portal edge-generation: pin the two real `/auth/login` emitters (SSOAdminClient / hosted login) and prove the portal paste-login path emits nothing

Module: `lib/screens/portal` (analysis bucket `docs/auto/analyses/lib-screens-portal-44bdd36d.json`, direction 2) · Direction: B6-2 (edge generation, `docs/campaigns/implementation-gate.md:57` row 2) · Value: 10 · Risk reduction: 9 · Effort: 2 · Confidence: 9
Status: **design** — implementation of the requirements spec `docs/proposals/b6-2-lib-screens-portal-edge-generation-spec.md` (REQ-1…REQ-5). Change set: **test-only + this design doc** — zero `lib/` and zero production-code changes (the spec's 8+/6− refresh is owned by the named docs commit, §6 step 8a — precedent `26782c5`/`b25ef9d` — never by the sibling B6-1 commit) (the emitters and the non-emitter are existing code; this direction proves and pins them). The working tree's existing `lib/` delta (sibling `SSOAdminClient.firstPartyClientId` constantization) is sibling-owned and untouched. Sibling instances: `b6-2-lib-screens-oidc-login-client-id-alignment-{spec,design}.md` (the M2 constant co-change), `b6-2-lib-screens-oidc-login-handle-success-anchor-spec.md` (the census gate this direction must stay green against).

---

## 1. Verification verdict (evidence re-checked at HEAD `e1073ce` + working tree, not trusted)

The requirements evidence (spec, 129 lines, tracked at HEAD in `7572539`, working-tree delta 8+/6− confirmed by `git diff --numstat` at verification time — extended to 10+/8− by this re-validation's mandated corrections: pinnedSites 7→8 reconciliation + chrome-flag command fixes, §6 step 8a) was re-checked line-by-line. **Every acceptance-relevant claim holds**; two cosmetic citation imprecisions were found and are corrected below (no acceptance impact).

| Evidence claim | Verification result |
|---|---|
| Spec tracked at HEAD (`7572539`), 129 lines, WT delta exactly 8+/6− | ✅ `git show 7572539 --stat` lists the spec as new; `wc -l` → 129; `git diff --numstat` → `8 6` |
| E1 `sso_client.dart:83-97` — `login`, default `'sso-admin-console'` :86, `_post('/auth/login'` :90 `auth: false`, `'client_id': clientId` :92 | ✅ exact at HEAD (`git show HEAD:lib/api/sso_client.dart`). **Correction (cosmetic):** the `'credential'` line is **:95** (`}, auth: false);` is :96), and the method body closes at **:102** (`return map;` :101), not :97 — :97 is `final map = body as Map…`. Spec E1's "credential at :96" and "body closes :97" are each off by one; the span :83-97 quoted in the direction citation is likewise a partial-body span. No line in the spec's requirements text depends on these |
| E2 `app_router.dart:35` — `defaultClientId: 'sso-admin-console'` | ✅ literal at :35 at HEAD; working tree :35 = `SSOAdminClient.firstPartyClientId` (M2 already applied) — matches the spec's re-verification stamp (HEAD = pinned-mode, WT = constant-mode) |
| E3 `portal_api.dart:233-257` — login = `GET /me` only, rollback :250-253 | ✅ exact at HEAD and WT: `login` :233, `get('/me')` :245, non-200 throw :247, rollback :250-253, `signOut` :259, `logout` :268 (`post('/logout')`), `fetchMe` :270; `auth/login` in file → 0 hits; SSE read `GET /me/notifications/stream` :125 |
| E4 `portal_screen.dart:119, :211` — exactly two `_api.login(` sites | ✅ `grep -n "_api.login("` → only :119 (`_tryResumeSession` → `_api.login(token, sessionId:…, clientId:…)`) and :211 (`_login` paste → `_api.login(t)`); `_api = widget.api ?? PortalApi()` at :90 |
| E5 census `oidc_login_handle_success_census_test.dart:97-104` emission-string census | ✅ test at :97-104 scans `lib/screens/oidc_login`; **byte-identical to HEAD** (`git diff HEAD -- test/oidc_login_handle_success_census_test.dart` → empty); repo-wide `grep -rn "auth\.login\.success" lib/` → exit 1; in `test/` only the census file |
| E6 `implementation-gate.md:57` row | ✅ exact: `\| 2 \| console \| lib/ 原生事件 \| 边缘生成验证：login → auth.login.success（client_id=sso-admin-console）\| sink 出现 sso-admin-console login 事件；无重复 \| B4-5 \|` |
| S1 `sso_client_test.dart:10-27` — in-handler body assert, literal :18, **no request counter** | ✅ HEAD literal `'sso-admin-console'` at :18; WT :18 = `SSOAdminClient.firstPartyClientId` (M2). The MockClient asserts the full decoded body map (provider/client_id/scope/resource/credential) inside the handler — a second POST would also pass; there is no counter. Gap confirmed: the exactly-once pin is absent |
| S2 hosted leg pins — harness :26-103, HEAD asserts :117/:135/:136/:149/:155/:158 | ✅ exact at HEAD: `loginPosts == 0` :117 (probe-excluded, D9 `body['credential'] is Map` filter), `== 1` :135/:149, `lastClientId == 'sso-admin-console'` :136/:158, `== 2` :155. WT is shifted +1 (:118/:136/:137/:150/:156/:159) by the M2 constantization comments — both orderings covered by the spec's stamp |
| S3 `oidc_login_api.dart:51-58` — `_postOutcome('../auth/login', …)` | ✅ :51-52 password flow, :58 code-sender `login`; `_resolve` :39 |
| S4 `_effectiveClientId` chain | ✅ `oidc_login_screen.dart:159-161` (ternary at :161), falls back to `widget.defaultClientId` = `app_router.dart:35`'s `'sso-admin-console'` for bare `/login/` |
| S5 portal module zero `/auth/login` | ✅ `grep -rn "auth/login" lib/screens/portal/` → exit 1; 33 `.dart` files |
| S6 post-login portal traffic = BFF GETs only | ✅ `notificationEvents()` → `GET /me/notifications/stream` (`portal_api.dart:125`), invoked from `portal_screen.dart:134/:222` |
| S7 drill — tracked; `AGREED_CLIENT_ID` :31; steps 3-6 at :141/:169/:192/:219; wiring `run_all.py:169` / `full_stack_verify.py:113` | ✅ all exact (`git ls-files` → tracked). **Executed, not just read:** no-stack face → `SKIP: live authenticated tests require SNAPLINK_TEST_USERNAME and …` **exit 0** — never a false PASS/FAIL |
| S8 console-shaped read wire | ✅ `audit_read_client.dart:15-17` trio path literals; `list()` :41-51 (`AuditQuery.toQueryParameters()` → `_api.get(eventsPath, query:)`) |
| S9 census :109-146 dual-mode + pinnedSites :116 (8 sites — 1+4+3: `sso_client_test:18`, `oidc_account_flow_test:35,75,115,160`, `oidc_login_screen_client_id_test:76,136,158`) + 30-test gate | ✅ exact; gate at :156-185 with `expect(censusCount+clientIdCount+ssoCount, 30)` :184; counts 10/3/17=30 (`grep -cE` → census 10, client_id 3, sso 17). **Executed both orderings:** `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → **30/30 green at HEAD** (temp worktree `e1073ce`, pinned-mode) **and 30/30 green in the working tree** (constant-mode, `isEmpty` branch) |
| S10 portal paste/resume test skeletons | ✅ `portal_entry_test.dart` `@TestOn('browser')` :1, `tearDown(Session.clear)` :16; paste-with-MockClient :163-195 (`GET /me` :167-171, invitation POST :171); stored-session 403-preservation :208+ (`Session.store` :211, MockClient `expect(request.url.path, '/me')` :215) |
| Design doc `b6-2-lib-screens-portal-edge-generation-design.md` absent | ✅ `ls` → No such file — this document is the design-stage deliverable |
| New guard/harness test files absent | ✅ `ls test/edge_generation_*` → none — implement-stage additions |

**Executed during this verification:** both census orderings 30/30 (§1 table S9), drill no-stack exit 0 (S7), the three repo greps (exit 1 each: `auth/login` in `lib/screens/portal/`, `auth.login.success` in `lib/`, `auth/login` in `lib/api/portal_api.dart`).

**Corrections carried into this design (cosmetic, no acceptance impact):** E1's `'credential'` line is :95 / `auth: false` at :96, and the `login` method body closes at :102 at HEAD — the spec's :96/:97 readings are off by one; nothing in REQ-1…REQ-5 or AC-1…AC-4 quotes those numbers.

---

## 2. Design summary

**Files touched: 3 test files (2 new, 1 appended). Zero `lib/`, zero drill edits, zero census-file edits in the operative ordering. The design work is the harness/guard shape + the landing-order pin.**

| # | File | Change | Requirement |
|---|---|---|---|
| 1 | `test/edge_generation_console_login_test.dart` (new) | Recording-MockClient harness for `SSOAdminClient.login`: exactly-one credential-bearing `POST /auth/login`, full-body assert, cumulative-2 on second login, fail on any other request | REQ-2 / AC-1 |
| 2 | `test/edge_generation_portal_negative_test.dart` (new) | Repo guard: scans every `.dart` file under `lib/screens/portal/` for `auth/login` and `auth.login.success`, asserts zero hits | REQ-1 / AC-2 |
| 3 | `test/portal_entry_test.dart` (append 2 testWidgets) | Request-bound paste + resume tests: zero POSTs, exactly one `GET /me` with the Bearer, all other traffic confined to `GET /me/*` | REQ-3 / AC-2 |

Derived, **zero-edit**: `test/oidc_login_handle_success_census_test.dart:109-146` stays green because the harness references `SSOAdminClient.firstPartyClientId` (constant-mode, zero literals — executed 30/30); the hosted leg (`test/oidc_login_screen_client_id_test.dart`, `loginPosts == 1` per submit) and `test/sso_client_test.dart` (untouched, 17-test gate) already pin their halves of AC-1. Verify-only: `tests/integration/audit_login_drill.py` + wiring (REQ-4/AC-3), `implementation-gate.md:57`, the three repo greps (REQ-5/AC-4).

**Key decisions:**

- **D1 — Names pinned at design stage (spec REQ-1/REQ-2 "or equivalent; name at design stage"):** `test/edge_generation_console_login_test.dart` and `test/edge_generation_portal_negative_test.dart`. Both are additive plain `test()` files, outside the three count-gated files — the 10/3/17=30 gate is untouched in every ordering.
- **D2 — Operative ordering is constant-mode (harness references `SSOAdminClient.firstPartyClientId`).** The working tree already carries the constant (`sso_client.dart:82`) and the census runs its `isEmpty` branch — executed green. A literal `'sso-admin-console'` in the new harness would fail that branch. Therefore the harness's expected client_id is a compile-time reference to the constant, zero literals, zero string-construction evasion (spec REQ-2's prohibition holds). The pinned-mode fallback (one literal site + census `pinnedSites` co-change) is documented in §3.3/§6 as a rejected-by-default ordering: it would additionally require extending the sibling M2 co-change list to constantize the new site, forking the sibling's 8-site pin.
- **D3 — The portal guard is a normalized two-scope scan, mirroring the census technique (`census_test.dart:97-104`), not a request mock (hardened per the security review).** Scope 1: `auth/login` in `lib/screens/portal/` only, **33 files pinned** (the route is legitimately emitted outside the module — `lib/api/sso_client.dart:96`, `lib/api/oidc_login_api.dart:51`, `lib/screens/oidc_login/*` — so a lib/-wide raw scan would false-hit). Scope 2: `auth.login.success` in **all of `lib/`** (recursive walk, the `i18n_coverage_test.dart` precedent) — the emission string must never be fabricated anywhere in production code, closing the constant-outside-the-module and router/api-wrapper bypass vectors and automating AC-4.1's manual grep as an independent backstop. Matching is **normalized** before comparison (quote seams, `' + '`, `$` interpolation stripped), so the split-literal evasion the census itself documents cannot hide a portal login surface. It lives in `test/`, so the repo-wide greps cannot self-hit.
- **D4 — The REQ-3 tests are request-bound by construction:** the recording MockClient `fail()`s on any POST and on any path not under `/me`, so the assertions are structural (a future `POST /auth/login` cannot be missed), not post-hoc filters.
- **D5 — Counting distinguishes credential-bearing POSTs from probes (D9 filter parity).** The hosted-leg harness excludes probe POSTs (`body['credential'] is Map`, `client_id_test.dart:36-37`). `SSOAdminClient.login` performs no probe — the harness asserts the *total* request count is exactly 1 per login, which is strictly stronger and catches a hypothetical added probe.
- **D6 — Scalar body asserts, credential value never enters a diff (hardened per the security review).** The harness asserts provider/client_id/scope/resource/username as exact scalars and the password as a non-empty `String` **shape-only** — D9-parity style, so a mismatch renders only the failing scalar, never the password value (whole-map equality would render the credential on failure). Default resources are deterministic (`AdminOAuthResources.values`), so the scalar asserts are stable. Fail-fast messages are pinned to `method` + `url.path` only — never body, headers, or query (the recording MockClient prints nothing; no `print`/`debugPrint` of decoded bodies anywhere in the harness).
- **D7 — Zero production-code change and zero drill edit.** `git diff --stat lib/` for this direction must be empty (the WT `lib/` delta is sibling M2); `tests/integration/audit_login_drill.py` stays byte-identical with `AGREED_CLIENT_ID = 'sso-admin-console'` (:31) — the drill is *not* constantized (Python side, sibling REQ-0 boundary).
- **D8 — Commit ordering: land after (or atomically with) the sibling M2 commit.** Both census orderings are green (executed), so the only hard constraint is that the new harness must never land *before* the constant in a way that leaves a literal behind; D2's constant-mode form makes the after-M2 landing trivially safe and the same-commit landing safe (constant visible to the harness).

---

## 3. API changes (concrete)

This direction introduces **no production API surface**. The "API" here is the new test surface and its two-state assertion-site contract.

### 3.1 New file — `test/edge_generation_console_login_test.dart` (REQ-2, AC-1)

Plain `test()` + recording `MockClient` (pattern per `test/sso_client_test.dart:10-27`), 6 tests:

1. **Exactly one credential-bearing `POST /auth/login` per `login()`.** Recording client records `(method, path, decodedBody)` for every request; after `await client.login('admin', 'password')`: `recorded.length == 1`, `method == 'POST'`, `path == '/auth/login'`.
2. **Scalar body contract (D9-parity, hardened).** Scalar asserts on `jsonDecode(body)`: `provider == 'password'`, `client_id == SSOAdminClient.firstPartyClientId` (the compile-time constant reference, D2), `scope` and `resource` exact (deep list equality vs `AdminOAuthResources.values`), `credential['username'] == 'admin'`, and `credential['password']` as a non-empty `String` **shape-only** — its value never enters an assertion diff. Fail-fast messages are pinned to `method` + `url.path` only (never body/headers/query); the harness prints nothing.
3. **No other request types during `login()`** (no probe, no `/me`): the recording client `fail()`s on any request whose `method != 'POST' || path != '/auth/login'`.
4. **Second login → cumulative 2** (`recorded.length == 2` after two calls; exactly one request per call) — the unit-level "无重复" pin, mirroring the hosted-leg retry pin at `client_id_test.dart:155`.
5. **Fail conditions are the inverse:** the counting assertions fail if a single `login()` issues 0 requests, 2+ requests, or any non-`/auth/login` request; the body assert fails on client_id drift, missing `credential` map, or altered credential values.

**Two-state contract (spec REQ-2, both orderings):** in the operative constant-mode ordering the expected client_id is `SSOAdminClient.firstPartyClientId` — zero literals, census `isEmpty` branch green (executed). The pinned-mode fallback (constant absent) would use exactly one literal site plus a census `pinnedSites` co-change in the same commit; it is documented in §6 as rejected-by-default (D2) because it forks the sibling M2 co-change list. The new file is **not** count-gated; no edit to the three count-gated files occurs in either ordering except the pre-permitted `pinnedSites` co-change in the fallback.

### 3.2 New file — `test/edge_generation_portal_negative_test.dart` (REQ-1, AC-2)

Two guard tests mirroring `census_test.dart:97-104` (hardened: normalized matching + widened emission walk):

- **Test 1 — portal `auth/login`:** iterate `Directory('lib/screens/portal')` (33 `.dart` files incl. the `portal_api.dart` re-export shim, **count pinned** — a partial module move goes red, never silent); assert zero `auth/login` matches after normalization. `auth/login` is *not* scanned lib/-wide: it is legitimately emitted outside the module (`sso_client.dart:96`, `oidc_login_api.dart:51`, `lib/screens/oidc_login/*`), so a raw lib/-wide scan would false-hit.
- **Test 2 — lib/-wide emission string:** recursively walk all of `lib/` (the `i18n_coverage_test.dart` precedent, 303 `.dart` files at HEAD+WT) and assert zero `auth.login.success` matches after normalization — the AC-4.1 manual grep, automated, closing the constant-outside-the-module and router/api-wrapper bypass vectors.
- **Normalization** strips quote seams (`'auth.' 'login'`), `' + '` concatenation, whitespace, and `$` interpolation markers before matching, so the split-literal evasion the census itself documents (`census_test.dart:113` self-host trick) cannot hide a surface. Substrings deliberately include path literals, request targets, and comments — the spec's invariant covers all three (REQ-1).
- No `lib/` change is required or permitted: `PortalApi.login` stays a `GET /me` probe (`portal_api.dart:233-257`); the two entry points stay at `portal_screen.dart:119/:211`.

### 3.3 Appended — `test/portal_entry_test.dart` (REQ-3, AC-2)

Two new `testWidgets` following the file's existing skeletons (S10); the file keeps `@TestOn('browser')` and `tearDown(Session.clear)`:

1. **Paste path** (skeleton :163-195): recording MockClient; `PortalScreen(api: PortalApi(httpClient: recording), redirectMissingSessionToLogin: false)`; `enterText` a bearer token; tap Continue; `pumpAndSettle`. Asserts: **zero** recorded POSTs (in particular zero `/auth/login`); **exactly one** `GET /me` carrying `Authorization: Bearer <pasted-token>`; every other recorded request is a GET whose path starts with `/me` (the SSE read `GET /me/notifications/stream` at `portal_api.dart:125` may fire — it is `/me`-rooted and allowed by construction since the client `fail()`s otherwise).
2. **Resume path** (skeleton :208+): `Session.store('still-valid-token', clientId: 'portal-client')`; pump the same screen; assert the same bounds (exactly one `GET /me` validation, zero POSTs, no `/auth/login`), with 403-preservation behavior preserved.

The recording client `fail()`s on any `POST` and on any path not under `/me` (D4) — the tests are structurally incapable of passing in the presence of a login-emission request.

### 3.4 Explicitly unchanged API surface

- `lib/api/sso_client.dart` — `login` signature/default, `_post` wire: untouched (HEAD :83-102; the WT `firstPartyClientId` at :82 is sibling M2, excluded).
- `lib/api/portal_api.dart` — `login`/`signOut`/`logout`/`fetchMe`/`notificationEvents`: untouched.
- `lib/screens/portal/portal_screen.dart` — `_tryResumeSession`/`_login` entry points: untouched.
- `tests/integration/audit_login_drill.py` + `run_all.py:169` + `full_stack_verify.py:113` — byte-identical, `AGREED_CLIENT_ID` stays the literal `'sso-admin-console'` (D7).
- `test/oidc_login_handle_success_census_test.dart`, `test/oidc_login_screen_client_id_test.dart`, `test/sso_client_test.dart` — untouched in the operative ordering; 10/3/17=30 gate invariant.

---

## 4. Compatibility constraints

- **C1 — Landing order vs. the sibling constant (D2/D8).** The harness requires `SSOAdminClient.firstPartyClientId` to exist at compile time. Land **after** the sibling M2 commit or atomically with it. Both census orderings are green (executed: HEAD pinned-mode 30/30, WT constant-mode 30/30), so either of these two orderings is safe; *before*-M2 is safe only via the pinned-mode fallback (literal + `pinnedSites` co-change + extended M2 co-change list), which this design rejects by default.
- **C2 — Zero-literal rule in constant-mode.** With the constant present, no `'sso-admin-console'` literal may appear in `test/` (census `isEmpty` branch, `census_test.dart:144-148`). The new harness uses the constant reference; the negative guard's search substrings are `auth/login`/`auth.login.success`, which the census does not scan for, so no interaction.
- **C3 — Count-gate invariance.** The three count-gated files hold exactly 10/3/17=30 tests before and after this direction (new files are uncounted; appended `portal_entry_test.dart` tests are uncounted — the gate regex covers only the three named files). Executed: 30/30 in both orderings today.
- **C4 — Grep-guard stability.** `grep -rn "auth/login" lib/screens/portal/` → exit 1 and `grep -rn "auth\.login\.success" lib/` → exit 1 remain true after landing: the new tests live in `test/`, so neither grep can self-hit.
- **C5 — Browser platform (REQ-3 gate commands).** The appended REQ-3 tests run under the file's existing `@TestOn('browser')` — every gate command naming `test/portal_entry_test.dart` **must** read `flutter test --platform chrome test/portal_entry_test.dart`. The un-flagged VM form silently runs **zero** tests (`@TestOn('browser')` skip, exit 0), and the VM-only census/client_id/sso files cannot move to chrome (`census_test.dart` uses `Directory().listSync()`, dart:io — VM-only), so step 5's acceptance is two commands (§6 step 5). **GitHub CI gap — documented, deliberately not code-changed:** `make test-browser`'s fixed 6-file list (`Makefile:58`) excludes `test/portal_entry_test.dart`, so GitHub `ci.yml` always skips REQ-3; the authoritative automated chrome gate is the gitea workflow's full-suite `flutter test --platform chrome` (`.gitea/workflows/build.yml`, every PR/push), which does run this file, plus the local step-4/5 commands. Adding the file to `test-browser` would widen this direction's change set beyond its named commits (step 8) — the explicit documentation here is that resolution.
- **C6 — Drill `[proposed]` semantics preserved (REQ-4).** No-stack/credential-less environments: `IntegrationConfigurationError` → SKIP, exit 0 (executed); unverifiable sink legs are `[proposed]` — never a false PASS. A deployed-stack PASS requires steps 4-5's exactly-one/no-duplicate assertions to hold.
- **C7 — No production delta.** This direction's implementation commit must contain only the 4 paths of §6 step 8b (3 test files + this design doc); the spec refresh lands in the named docs commit (step 8a). `git diff --stat lib/` must show no *new* changes beyond the sibling-owned deltas already in the tree (post-M2: B6-1's `lib/screens/admin/audit_log_tab.dart` + `lib/services/audit_log_service.dart`); the sibling's 5-file M2 set is committed separately.

---

## 5. Failure modes and mitigations

| # | Failure mode | Detection | Mitigation |
|---|---|---|---|
| F1 | A future implementer "fixes" B6-2 by adding a `/auth/login` surface to the portal client (treats `PortalApi.login` as an emitter) | `test/edge_generation_portal_negative_test.dart` red (normalized `auth/login` in `lib/screens/portal/`, 33-file pin enforced); `grep` guard exit 1 → non-zero | REQ-1 guard is the standing tripwire; normalization defeats split-literal evasion (`'auth.' 'login'`, `'/auth/' + 'login'`); the 33-file pin makes a partial module move red, never silent; the spec's AC-2 documents the intended reading (portal paste = `GET /me` probe only) |
| F2 | A future change makes the portal paste/resume path issue a POST (spurious or duplicate sink event) | REQ-3 recording client `fail()`s on any POST → both appended testWidgets red | D4 structural fail-fast; no post-hoc filtering that could mask a request |
| F3 | `SSOAdminClient.login` starts emitting 2+ credential POSTs per call (e.g., an added retry loop or refresh-as-`/auth/login`) | harness counts red (`recorded.length == 1` per login, cumulative 2 after two) | D5 total-count assert; mirrors the hosted-leg retry pin at `client_id_test.dart:155` |
| F4 | `client_id` drift (hardcoded new value, typo, or literal re-introduced in `test/`) | harness body assert red; constant-mode census `isEmpty` red on any literal | D2 constant reference + the census gate's dual-state logic (executed both orderings) |
| F5 | A probe request added inside `login()` (hosted-leg-style mount probe) | harness total-count assert red (any non-`POST /auth/login` request `fail()`s) | D5: total-count is stronger than the D9-filtered count used by the hosted leg |
| F6 | Guard/harness files deleted by a later refactor (silent acceptance regression) | the 30-test count gate does **not** cover the new files → gap | mitigated by the direction's spec language (files are named deliverables) and by commit review; the standing greps (C4) remain the independent backstop |
| F7 | Pinned-mode fallback used and the sibling M2 lands without constantizing the new site | constant-mode census `isEmpty` red on the harness literal after M2 | D2 rejects the fallback by default; if ever used, §6 step 8 requires the M2 co-change-list extension in the same commit |
| F8 | Sink-side semantics unverifiable (no deployed stack) | drill SKIPs, exit 0, `[proposed]` rows | REQ-4/AC-3 no-false-PASS semantics (executed: exit 0 SKIP); the G2/B4-5 gate owns deployed-stack observation |
| F9 | Browser-platform tests fail under the wrong runner configuration — or, worse, are **silently skipped** | the un-flagged `flutter test test/portal_entry_test.dart` exits 0 with **zero** tests run (`@TestOn('browser')` VM-skip); GitHub `make test-browser` (fixed 6-file list) always skips REQ-3 on GitHub CI | C5: every gate command names `--platform chrome`; the automated chrome gate is the gitea full-suite `flutter test --platform chrome` (`.gitea/workflows/build.yml`) + the local step-4/5 commands — the GitHub skip is documented explicitly in C5 (no Makefile change, keeping the named commit sets intact); the pre-existing tests enforce parity |
| F10 | Census co-change (fallback only) drifts from the actual literal line | pinned-mode census `actual` vs `pinnedSites` mismatch red | the census's pinned-allowlist equality (`census_test.dart:150`) is exact, line-numbered |
| F11 | A failure path renders the credential (whole-map diff, fail-fast message echoing body/headers) | review of the harness's failure output; grep for `print`/`debugPrint` in the harness | D6 scalar asserts (password shape-only) + fail-fast messages pinned to `method` + `url.path`; no prints in the harness — failure output never contains the decoded body, headers, or query |
| F12 | The emission string `auth.login.success` appears outside the portal module (router/api-wrapper/constant file) | guard test 2 red — the lib/-wide recursive walk catches it anywhere in `lib/` | widened normalized walk (D3); AC-4.1's manual grep stays the independent backstop |

---

## 6. Migration steps (ordered, each with a verification gate)

The working tree is contaminated with three change sets (sibling M2: 5 files; B6-1: 6+ files; this direction: none yet). Migration constructs this direction's commits (spec docs commit + implementation commit, step 8) by **staging exactly the named files**, never touching the sibling's.

1. **Precondition — confirm constant-mode tree.** `grep -n "firstPartyClientId" lib/api/sso_client.dart` → hit at :82; `git diff test/oidc_login_handle_success_census_test.dart` → empty. **Gate:** `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → 30/30 (executed today).
2. **Write `test/edge_generation_console_login_test.dart`** (§3.1, constant-mode form). **Gate:** `flutter test test/edge_generation_console_login_test.dart` → green; deliberately confirm the fail-side by temporarily expecting 0 requests (red) and reverting.
3. **Write `test/edge_generation_portal_negative_test.dart`** (§3.2). **Gate:** green; `grep -rn "auth/login" lib/screens/portal/` → exit 1 still (the guard did not mask a real hit: temporarily rename `portal_api.dart`-scoped substring? — no: the guard's correctness is cross-checked by the independent repo grep, which must stay exit 1 both before and after).
4. **Append the two testWidgets to `test/portal_entry_test.dart`** (§3.3). **Gate:** `flutter test --platform chrome test/portal_entry_test.dart` → **13/13 green** (7 redirect/route `test()`s + 6 testWidgets: 4 pre-existing + 2 appended — executed 13/13 in this tree). The un-flagged VM form runs zero tests (`@TestOn('browser')` skip) and `make test-browser` excludes the file — the `--platform chrome` flag is mandatory (C5); the new tests red if the recording client is momentarily configured to allow POSTs.
5. **Full acceptance command — two legs (VM + chrome; the census/client_id/sso files use dart:io and cannot run on chrome, and `portal_entry_test.dart` runs zero tests in VM).** **Gate (a) VM leg:** `flutter test test/edge_generation_console_login_test.dart test/edge_generation_portal_negative_test.dart test/sso_client_test.dart test/oidc_login_screen_client_id_test.dart test/oidc_login_handle_success_census_test.dart` → all green (**38 tests**: 6+2+17+3+10). **Gate (b) chrome leg:** `flutter test --platform chrome test/portal_entry_test.dart` → **13/13 green** (executed in this tree). Both legs green.
6. **Guards and invariants — post-M2 reference (evaluate after M2 lands, C1).** **Gate:** the three greps (C4) exit 1; `git diff HEAD -- test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → empty **post-M2 only** (before M2 lands, `oidc_login_screen_client_id_test.dart`/`sso_client_test.dart` carry M2's own co-changes — 8+/7− and 1+/1− today — so this gate would fail for the wrong reason; it is a post-M2 check); `git diff --stat lib/` shows only **sibling-owned** entries — post-M2 exactly B6-1's `lib/screens/admin/audit_log_tab.dart` + `lib/services/audit_log_service.dart` (expected, not from this direction), pre-M2 additionally M2's `sso_client.dart`/`app_router.dart` — and **no entry introduced by this direction** (zero `lib/` delta); `git ls-files tests/integration/audit_login_drill.py` → tracked and `git diff HEAD -- tests/integration/audit_login_drill.py` → empty.
7. **Drill no-stack face.** **Gate:** `env -u SNAPLINK_TEST_USERNAME -u SNAPLINK_TEST_PASSWORD -u SNAPLINK_TEST_USER_ID python3 tests/integration/audit_login_drill.py` → exit 0, SKIP (executed today); `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` → :169/:113 hits.
8. **Commit construction — two commits, each exact-path gated (no `git add -A` / `git commit -a` anywhere — forbidden, they would capture the sibling M2/B6-1 deltas).**
    8a. **Named docs commit — the spec refresh is owned here (precedent `26782c5`/`b25ef9d`).** Stage exactly `docs/proposals/b6-2-lib-screens-portal-edge-generation-spec.md` — the tracked spec's refresh (re-verification stamp, citation corrections, plus this re-validation's pinnedSites 7→8 reconciliation and chrome-flag command fixes). `git diff --cached --stat` must list exactly this **1 path**. Commit immediately (independent of M2 and of the implementation files): this is what removes the spec from the dirty set, so the sibling B6-1 commit **cannot sweep it** — B6-1's exact-path staging never includes B6-2 paths (neither the spec, nor the design doc, nor the test files). Message shape: `verify(b6-2 portal edge generation): spec refresh — re-verification stamp + pinnedSites 7→8 + chrome-flag corrections` (f8fdca7-style).
    8b. **Implementation commit — exactly 4 paths.** Stage exactly `test/edge_generation_console_login_test.dart`, `test/edge_generation_portal_negative_test.dart`, `test/portal_entry_test.dart`, and this design doc; `git diff --cached --stat` must list exactly these **4 paths** (contamination-visible boundary, sibling D6 idiom). Commit **after** the sibling M2 commit (or atomically with it — C1). **Gate:** `git diff --cached --stat` review (exactly the 4 paths, no spec — it is already committed in 8a) + step 5's two commands green on the commit.

**Rejected-by-default fallback (documented for completeness, spec REQ-2's two-state rule):** landing **before** M2 requires the harness's single literal site `'sso-admin-console'` + a `pinnedSites` co-change in the census file (pre-permitted by spec §5) in the same commit, and then an extension of the sibling M2 co-change list to constantize the new site. Not exercised: the working tree already carries the constant, so constant-mode is the operative ordering (D2).

---

## 7. Testable acceptance mapping (spec §4 table, 1:1)

| Spec check | Design artifact | Executable acceptance |
|---|---|---|
| **AC-1** (a) exactly-one credential-bearing `POST /auth/login`, `client_id == 'sso-admin-console'`, cumulative 2 | §3.1 harness (`test/edge_generation_console_login_test.dart`); hosted leg already pinned (`client_id_test.dart` `loginPosts == 1` :135/:149, `== 2` :155) | `flutter test test/edge_generation_console_login_test.dart` green; fails on 0/2+/non-`/auth/login` requests; two-state client_id site (constant reference in constant-mode — executed; literal + `pinnedSites` co-change documented fallback) |
| **AC-2** (b) portal paste/resume = `GET /me` only, zero `/auth/login` POSTs | §3.2 guard + §3.3 request-bound testWidgets | `flutter test test/edge_generation_portal_negative_test.dart` green (VM) **and** `flutter test --platform chrome test/portal_entry_test.dart` green (browser-only file — the un-flagged VM form runs zero tests, C5); `grep -rn "auth/login" lib/screens/portal/` → exit 1; any POST / non-`/me` request in the two paths `fail()`s the tests |
| **AC-3** (c) sink exactly-one `auth.login.success` row for sso-admin-console; no duplicates | §3.4 (drill untouched, REQ-4) | `python3 tests/integration/audit_login_drill.py` → exit 0 (PASS on a deployed stack: steps 4-5 exactly-one/no-duplicate assertions; SKIP + `[proposed]` without — executed exit 0); wiring hits at `run_all.py:169`, `full_stack_verify.py:113` |
| **AC-4** (d) census green in both orderings; zero `lib/` changes; emission string never in `lib/` | §2 D2/D7, §3.4 | census command (step 5, VM leg) green — **executed 30/30 at HEAD (pinned-mode) and in the working tree (constant-mode)**; `grep -rn "auth\.login\.success" lib/` → exit 1; `git diff --stat lib/` empty of new changes for this direction; count-gated files diff-empty |

Spec REQ-1↔AC-2, REQ-2↔AC-1, REQ-3↔AC-2, REQ-4↔AC-3, REQ-5↔AC-4 — a 1:1 mapping; no spec requirement is left without an executable check.

---

## 8. Out of scope (unchanged, explicitly)

- Any sink/IdP-side code, client registry, or row-generation change (B4-5 is a dependency, evidenced only via the drill).
- The Branch A/B `client_id` value decision and `SSOAdminClient.firstPartyClientId` — owned by the sibling `b6-2-lib-api-client-id-alignment-spec.md` / `b6-2-lib-screens-oidc-login-client-id-alignment-{spec,design}.md` (M2); the working tree's existing M2 delta is not part of this commit.
- The audit read path, `AuditQuery` wire, tenant/trace derivation — owned by B6-1/B6-1a.
- Any edit to `tests/integration/audit_login_drill.py` (it already satisfies AC-3; `AGREED_CLIENT_ID` stays the literal) or to the three count-gated test files (except the pre-permitted `pinnedSites` co-change in the rejected fallback ordering).
- The drill's device-leg URL-shape step (step 2) and its header lens — documentation observations, not defects to fix here.
