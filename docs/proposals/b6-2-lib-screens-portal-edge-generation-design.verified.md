# B6-2 Verified Design — Portal edge-generation negative boundary + console-emitter exactly-once harness (module `lib/screens/portal`, REQ-1/REQ-2, test-only)

> Status: **design of record for the landed implementation**, re-verified against current HEAD `40acef7` + working tree on 2026-08-08. Every claim in the supplied evidence (`docs/proposals/b6-2-lib-screens-portal-edge-generation-spec.verified.md`) was re-checked against the repository, and every acceptance command was **re-executed** rather than trusted. Sibling spec: `docs/proposals/b6-2-lib-screens-portal-edge-generation-spec.verified.md`; approved source spec/design: `docs/proposals/b6-2-lib-screens-portal-edge-generation-spec.md` / `...-design.md` (tracked at `3b22ed4`).
>
> Method note: the direction's core premise ("neither edge file exists in `test/`") is **stale** — it held at analysis basis `e1073ce` but both files landed at `a2b04fc`, the `firstPartyClientId` constant landed at `db6e435`, and the docs landed at `3b22ed4`. This document is therefore a **verification record, not a build request**: the design below is the *final contract as landed*, plus the residual work (commit the verification record; two known-stale comments).

## 0. Evidence verification verdict

| Evidence claim | Repository reality (re-verified at HEAD `40acef7`) | Verdict |
|---|---|---|
| HEAD is `40acef7`; `test/edge_generation_console_login_test.dart` exists, tracked, unmodified, green | `git rev-parse HEAD` = `40acef7`; both edge files tracked (landed `a2b04fc`, "verify(b6-2): console-emitter exactly-once + portal negative-boundary guards"); **re-executed 8/8 green** (6 + 2) | ✅ exact |
| `firstPartyClientId` landed at `lib/api/sso_client.dart:82`; consumed at `:92` (login default) and `lib/app_router.dart:36` | `static const String firstPartyClientId = 'sso-admin-console';` at **:82**; `String clientId = firstPartyClientId` at **:92**; `defaultClientId: SSOAdminClient.firstPartyClientId` at **app_router.dart:36** (landed `db6e435`) | ✅ exact |
| `sso_client_test.dart:10-27` in-handler asserts, no request counter (gap S1) | `test(` at :10; MockClient handler :13-27 with whole-map `expect(jsonDecode(request.body), {...})` :16-24; `'client_id': SSOAdminClient.firstPartyClientId` at **:18** (constant reference, not literal); no counter anywhere in the file | ✅ exact substance |
| `PortalApi.login` (`lib/api/portal_api.dart:233-257`) is a token-paste probe with zero `/auth/login` | `Future<Map<String, dynamic>> login(` at **:233**; state capture :238-240; install :241-243; `get('/me')` :245; non-200 throw :247; rollback :251-253; rethrow/`PortalApiError(0,…)` :254-255. `grep -rn 'auth/login' lib/screens/portal/` → **exit 1 (executed)**; `grep -rn 'auth\.login\.success' lib/` → **exit 1 (executed)** | ✅ exact |
| Exactly two portal call sites: `portal_screen.dart:119` / `:211` | `_api.login(` at **:119** (inside `_tryResumeSession` :108-175) and **:211** (inside `_login` :199-227); grep shows exactly these two | ✅ exact |
| Census `pinnedSites` = 3 files / 8 sites at `:116-120`; `:116` comment stale | `const literal` :113 (split, self-host-safe); `constantDecl` :115; stale comment "while the sibling constant is absent (HEAD state)" at **:116** (constant landed at `db6e435` — comment is a known-stale note, `isEmpty` branch live); `pinnedSites` :117-121 = `sso_client_test.dart:[18]`, `oidc_account_flow_test.dart:[35,75,115,160]`, `oidc_login_screen_client_id_test.dart:[76,136,158]` (1+4+3 = 8) | ✅ exact (comment staleness confirmed) |
| `oidc_login_screen_client_id_test.dart` positions `:118/:136/:150/:156/:159` (`[CORRECTION]` vs direction's `:117/:135/:149/:155`) | `loginPosts == 0` :118; single-submit `loginPosts == 1` :136 + `lastClientId == SSOAdminClient.firstPartyClientId` :137; retry `loginPosts == 1` :150; cumulative `loginPosts == 2` :156 + `lastClientId` :159 | ✅ exact |
| Console harness internals: strict recording client; `recorded.add` :42; shared gates :74/:94; scalar body asserts; binding tests | `recorded.add(` :42; `_expectExactlyOneCredentialLogin` :74; `_expectCumulativeTwo` :94; scalar asserts (provider/client_id/scope/resource/username exact, password shape-only `isA<String>()` + non-empty) :139-160; binding tests :205-252 (empty/doubled :211/:230; one/three :246/:250) | ✅ exact |
| Portal guard internals: 33-file pin :39, `offendersFor` :95-101, zero-hit assert :106 | `const portalFileCount = 33;` :39; `offendersFor` :78 with `expect(scanned, pinnedCount)` :94-95; first test :104-106 (`offendersFor(portalDir, 'auth/login', pinnedCount: portalFileCount)`); second test :114-121 (lib/-wide recursive). `ls lib/screens/portal/*.dart` = **33 files** | ✅ exact |
| `git diff HEAD -- lib/` empty (test-only change set) | `git diff HEAD -- lib/` → **0 lines (executed)**; `git status --short` shows no `lib/` paths | ✅ exact |
| Implementation gate `:57` row: "sink 出现 sso-admin-console login 事件；无重复" | `docs/campaigns/implementation-gate.md:57` = `| 2 | console | \`lib/\` 原生事件 | 边缘生成验证：login → \`auth.login.success\`（client_id=sso-admin-console） | sink 出现 sso-admin-console login 事件；无重复 | B4-5 |` | ✅ exact |
| Drill `audit_login_drill.py` :31/:141/:169/:192; wiring at `run_all.py:169` / `full_stack_verify.py:113`; `[proposed]` never false PASS | `AGREED_CLIENT_ID = 'sso-admin-console'` :31 (Branch B); step 3 :141 (login payload check + real `POST /auth/login`); step 4 :169-190 (exactly-one `auth.login.success` row with agreed client_id, else `proposed = True`); step 5 :192+ (second login, no duplicates); step 6 :219 (console-shaped read); wiring at `run_all.py:169` and `full_stack_verify.py:113`; without a deployed stack the sink legs self-mark `[proposed]` and print ⚠/⏭️ — exit 0 = PASS **or** SKIP | ✅ exact |
| Census/client_id/sso suite green 30/30; working-tree B6-1 M2 delta in census file (out of scope) | **Re-executed: 30/30 green** (census 10 + client_id 3 + sso 17). `git diff --stat` on census file: +118/−9 uncommitted (B6-1 M2 43-test gate + lib/ single-source clause — out of this direction's scope; does not touch emission-string census :97-104 or `pinnedSites` group) | ✅ exact |
| REQ-3 landed in the same commit (`portal_entry_test.dart` +2 testWidgets) | `git show --stat a2b04fc` lists `portal_entry_test.dart` among the changed files; noted out of scope here | ✅ exact |

**Bottom line:** the evidence is accurate in every structural and state claim checked. The only divergences found are the two *self-identified* known-stale comments (`census_test.dart:116`; harness header's `:155` retry-pin citation — see §4), both pre-existing and out of scope. The design below is the contract as landed, with residual work limited to committing the verification record.

## 1. API changes (final contract, as landed)

### 1.1 Production API — none new (negative constraint, enforced)

Zero `lib/` changes were required or made (`git diff HEAD -- lib/` empty). The relevant production surface is unchanged and pinned:

- `SSOAdminClient.login` (`lib/api/sso_client.dart:89-102`): `_post('/auth/login', {...}, auth: false)` with `'client_id': clientId` where the default is the **compile-time constant** `SSOAdminClient.firstPartyClientId` (`:82`, landed `db6e435`) — not a literal. No probe: the only request a `login()` call may issue is the credential-bearing `POST /auth/login`.
- `PortalApi.login` (`lib/api/portal_api.dart:233-257`): stays a token-paste **probe** — install token → `get('/me')` (:245) → non-200 throw (:247) → rollback (:250-253). It must never acquire a `/auth/login` emission surface.
- `lib/screens/portal/portal_screen.dart` `:119` / `:211`: the only two entry points into `PortalApi.login`; both must remain `GET /me` probes.

### 1.2 Test-suite API — the landed contract (2 files, landed `a2b04fc`)

**A. `test/edge_generation_console_login_test.dart` (256 lines) — REQ-2/AC-1 exactly-once harness.**

```dart
class _LoginHarness {           // strict-by-construction recording MockClient
  _LoginHarness() { ... }       // :25-44: any request that is not a
                                // credential-bearing POST /auth/login → fail();
                                // credential-less POST also fails; :42 recorded.add
  late final MockClient client;
  final List<_RecordedLogin> recorded = [];
}

void _expectExactlyOneCredentialLogin(List<_RecordedLogin> recorded, {String? reason}) // :74
void _expectCumulativeTwo(List<_RecordedLogin> recorded)                                 // :94
```

- Both gates are **shared functions** executed by the acceptance tests **and** the binding meta-tests (:205-252), so "the assert cannot pass while a second POST occurs" is executed, not just intended.
- Body asserts are D9-parity **scalars** (:139-160): `provider`/`client_id`/`scope`/`resource`/`username` exact; `password` asserted shape-only (`isA<String>()` + non-empty) so its value can never enter a failure diff; fail-fast messages pin `method` + `url.path` only; zero `print`/`debugPrint`.
- The `client_id` site is the compile-time constant reference (constant-mode, zero literals — census `isEmpty` branch stays green).

**B. `test/edge_generation_portal_negative_test.dart` (127 lines) — REQ-1/AC-2 negative-boundary guard.**

- `normalizeForMatch(String source)` (:48-83): strips quote seams (`'auth.' 'login'`), `' + '` concatenation, whitespace, and `$` interpolation markers — closing the split-literal evasion the census itself documents.
- `offendersFor(dir, needle, {recursive, pinnedCount})` (:78-101): recursive `dart:io` walk; when `pinnedCount` given, asserts the scanned file count (`:94-95`) so a module rename, an emptied directory, or an unlisted new file goes **red** — the zero-hit assert is non-vacuous.
- Two tests, needles byte-identical to the standing greps (the guard can never disagree with them):
  1. `auth/login` in `lib/screens/portal/` **with the 33-file pin** (`pinnedCount: portalFileCount`, `:39`) — the route legitimately lives outside the module (`sso_client.dart:96`, `oidc_login_api.dart:51`), hence module-scoped.
  2. `auth.login.success` **lib/-wide recursive** — the emission string must never be fabricated anywhere in production code (closes constant-outside-the-module and router/api-wrapper bypass vectors).

## 2. Compatibility constraints

1. **Two-state rule (constant-mode is live).** The census (`test/oidc_login_handle_success_census_test.dart:109-146`) branches on `constantExists` (declaration at `sso_client.dart:82`): while the constant exists, `lib/`+`test/` must carry **zero** occurrences of the split literal `'sso-admin-' + "console'"` outside the declaration; the `pinnedSites` branch (`:116-120`, 3 files/8 sites) is the **dormant fallback** — it must not be deleted, because removing the constant re-activates it.
2. **Single-source rule:** new code must reference `SSOAdminClient.firstPartyClientId`; fresh literals and split-literal construction are forbidden (reddens the census in constant-mode).
3. **Count gates are immutable by this direction:** the census file (30-test gate at HEAD; 43-test gate with the uncommitted B6-1 M2 delta in the working tree), `oidc_login_screen_client_id_test.dart` (3), and `sso_client_test.dart` (17) are **not to be edited** by B6-2 work. The two edge files are uncounted and may be extended.
4. **Zero `lib/` diff:** any B6-2 follow-up that touches `lib/` breaks the "test-only" contract and must be a separate direction.
5. **33-file pin is layout-coupled:** adding/removing a `.dart` file under `lib/screens/portal/` requires updating `portalFileCount` in the same change (the pin reddens otherwise — by design).
6. **Grep parity:** the guard's needles must stay identical to `grep -rn 'auth/login' lib/screens/portal/` and `grep -rn 'auth\.login\.success' lib/`, so the manual greps remain an independent backstop and can never contradict the guard.
7. **Drill semantics:** `audit_login_drill.py` exits 0 for PASS **or** SKIP (`[proposed]` self-marked when no deployed stack); a red sink leg must fail loudly, never be silently skipped. Wiring at `run_all.py:169` / `full_stack_verify.py:113` must stay byte-identical.
8. **No test-only production seams:** the harness drives the real `SSOAdminClient` public constructor + `login()` through an injected `http.Client` — no `@visibleForTesting` hooks were added.

## 3. Failure modes

| # | Failure mode | Detection | Guard layer |
|---|---|---|---|
| F1 | Implementer adds a `/auth/login` emission surface to `PortalApi` or any portal file (the misread the direction guards against) | Normalized scan finds `auth/login` in `lib/screens/portal/` | Portal guard test 1 (33-file pin); grep backstop |
| F2 | Any `lib/` file fabricates `auth.login.success` (constant-outside-module or router/api-wrapper bypass) | Lib/-wide recursive scan | Portal guard test 2 |
| F3 | Split-literal evasion: `'auth.' 'login'`, `'/auth/' + 'login'`, `'/auth/$segment'` | `normalizeForMatch` reassembles before `contains` | Portal guard normalization |
| F4 | Module layout drift: portal dir renamed/emptied/new unlisted file | `expect(scanned, 33)` fails — zero-hit assert becomes vacuous or miscounts | 33-file pin |
| F5 | S1 regression: `SSOAdminClient.login` issues a second credential-bearing POST (or 0), or a probe/non-login request | Strict MockClient `fail()`s inside the handler (no post-hoc filtering possible); gates red | Harness strict client + `_expectExactlyOneCredentialLogin` |
| F6 | Cumulative drift: two `login()` calls yield 1-then-0 or 2-in-one | `_expectCumulativeTwo` red; acceptance test 4 asserts per-call increments (`1` then `2`) | Cumulative-2 gate |
| F7 | Gate self-silencing (the gate function passes while a second POST occurs) | Binding meta-tests (`:205-252`) prove empty/doubled/tripled/dropped-second inputs all `throwsA(TestFailure)` | Shared-gate + binding tests |
| F8 | Credential leakage into failure diffs | Password asserted shape-only; whole-map equality never used | Scalar asserts |
| F9 | Fresh `'sso-admin-console'` literal in test/ or lib/ (outside the declaration) | Census literal scan red (constant-mode `isEmpty` branch) | Census two-state rule |
| F10 | Drill false PASS without a deployed stack | Sink legs self-mark `[proposed]` (exit 0 = PASS or SKIP); the unit leg (AC-1) still proves the request side | Drill `proposed` flag |
| F11 | Guard/grep disagreement | Guard needles byte-identical to the greps — disagreement is impossible by construction; if needles drift, the greps catch it | Parity constraint |
| F12 | Count-gated file edited by B6-2 work (accidental scope creep) | Test-count arithmetic red (30 at HEAD, 43 with B6-1 M2 delta); `git diff` review | Scope guard |

## 4. Migration steps

No production migration exists — there is no API to deploy and no data to move; `PortalApi.login` and `SSOAdminClient.login` behavior is **unchanged** from the approved design. The remaining steps are repo hygiene:

1. **Commit the verification record (this document + the sibling verified spec)** as a doc-only change (`docs/proposals/` only; no `lib/`, no `test/`). This is the only genuine remaining work — the implementation landed at `a2b04fc`/`db6e435` and the docs at `3b22ed4`.
2. **Do not touch the count-gated files.** The uncommitted census delta (+118/−9, B6-1 M2 43-test gate + lib/ single-source clause) belongs to the B6-1 campaign and must land through that direction's own commit.
3. **Optional (deferred, doc-nit only):** the harness header cites the hosted-leg retry pin as `oidc_login_screen_client_id_test.dart:155`; the HEAD position is `:156` (the file's own comments at `:134`/`:157` document the constantization). Fixing the header comment is safe (the harness file is uncounted) but not required for correctness — tests are green either way.
4. **Known-stale comment, deliberately untouched:** `oidc_login_handle_success_census_test.dart:116` ("while the sibling constant is absent (HEAD state)") is stale since `db6e435`; the file is count-gated, so the comment stays until the B6-1 M2 delta commits.
5. **For a hypothetical new implementer:** run the §5 acceptance commands against the working tree; the guard suite is self-verifying (binding meta-tests prove the fail side).
6. **When a deployed stack exists:** run `python3 tests/integration/audit_login_drill.py` (and `run_all.py`/`full_stack_verify.py`); sink legs will leave `[proposed]` and execute the real exactly-one/no-duplicates checks against the sink.

## 5. Testable acceptance mapping

| # | Acceptance check (from approved spec) | Testable command (executed 2026-08-08) | Result at HEAD `40acef7` | Fail-side proof |
|---|---|---|---|---|
| AC-1 | Exactly one credential-bearing `POST /auth/login` per `login()` with `client_id == 'sso-admin-console'` and credential `{username, password}`; second login → cumulative 2; any 0/2+/non-`/auth/login` request fails | `flutter test test/edge_generation_console_login_test.dart` | **6/6 green** (4 acceptance + 2 binding) | Strict-client trips (test 3); binding tests prove empty/doubled/tripled/dropped-second all `throwsA(TestFailure)` |
| AC-2 | Portal module zero `/auth/login`; `lib/` zero `auth.login.success` | `flutter test test/edge_generation_portal_negative_test.dart` + `grep -rn 'auth/login' lib/screens/portal/` + `grep -rn 'auth\.login\.success' lib/` | **2/2 green**; both greps **exit 1** | 33-file pin makes the zero-hit non-vacuous; normalization defeats split-literal evasion |
| AC-3 | Census guards stay green in both orderings (constant-mode or pinned-literal mode) | `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` | **30/30 green** (10 + 3 + 17); constant-mode branch live; edge files reference the constant only (zero fresh literals) | Census's own binding arithmetic + dormant `pinnedSites` fallback |
| AC-4 | Maps to T-12 joint: unit leg proves the request side of sink row `auth.login.success (client_id=sso-admin-console)`; joint sink leg via drill steps 3-5 | `python3 tests/integration/audit_login_drill.py` — step 3 (`:141`) real login with `AGREED_CLIENT_ID`; step 4 (`:169`) exactly-one sink row with agreed client_id; step 5 (`:192`) two rows after second login, distinct ids, stable after re-settle | Sink legs `[proposed]` (no deployed stack — self-marked, **no false PASS**); unit leg proven by AC-1; wiring verified at `run_all.py:169` / `full_stack_verify.py:113` | `proposed = True` path prints ⚠/⏭️ and skips — a red sink never masquerades as PASS |

**Suite totals (re-executed):** edge files 8/8; census/client_id/sso 30/30; total 38/38 in this direction's scope. Gate row at `docs/campaigns/implementation-gate.md:57` ("sink 出现 sso-admin-console login 事件；无重复") is satisfied by AC-1 + AC-4 jointly.

## 6. References

- Approved spec: `docs/proposals/b6-2-lib-screens-portal-edge-generation-spec.md` (REQ-1 `:53-60`, REQ-2 `:61-70`, AC-1 `:103-106`, AC-2 `:108-110`, AC-4 `:118-120`), tracked `3b22ed4`
- Approved design: `docs/proposals/b6-2-lib-screens-portal-edge-generation-design.md` (D3 `:56`, D5 `:58`, D6 `:59`, F4/F5/F6 `:127-130`)
- Verified spec (this batch's evidence): `docs/proposals/b6-2-lib-screens-portal-edge-generation-spec.verified.md`
- Precedent: `docs/proposals/b6-1-lib-screens-developer-negative-boundary-design.verified.md` / `-spec.md` (same M2 verification-record pattern)
- Landed implementation: `a2b04fc` (edge harness + portal guard + REQ-3 legs), `db6e435` (Branch B constant), `3b22ed4` (spec + design docs)
- Pipeline run record: `docs/auto/runs/land-b6-2-console-emitter-exactly-once-harness-p-48957ac6/`
- Source analysis: `docs/auto/analyses/lib-screens-portal-44bdd36d.json`
