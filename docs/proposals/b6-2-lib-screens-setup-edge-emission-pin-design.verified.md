# B6-2 Verified Design — Setup→login edge emission pin: determinism audit of REQ-1/REQ-2/REQ-3, the 16 failure-mode rows, and the 50/50 joint gate (FM-7)

> Status: **validation record** for `docs/proposals/b6-2-lib-screens-setup-edge-emission-pin-design.md` (proposed, untracked) and its sibling spec, re-verified against HEAD `40acef7` + working tree on 2026-08-08. Method: every cited symbol/line re-read; the baseline suites **re-executed** (21/21 green: setup 4 + census 10 + client_id 3 + FG-3 wiring 1 + exactly-once 3); drift-mode reasoning checked against the actual guard code, not the design's guard column.
>
> Bottom line: **Q1 (stub determinism) — confirmed for all enumerated REQ-1 modes; REQ-2 confirmed for every mode except FM-4, whose guard attribution in the design is wrong (the real guard is the uncited FG-3 pin). Q2 (16-row audit) — 2 substantive gaps (FM-4 misattribution; REQ-3 first-query ingestion race) + 2 minor unenumerated vectors + 5 residual off-by-one citations in the design's own claims. Q3 (joint gate) — confirmed sound for the 43 pinned tests (skip/zero-run machine-red, deletion count-red); confirmed **unsound** for the 3 new tests in the unpinned file (FM-7 is real: `skip:`/whole-file `@TestOn`/tautology mutations all pass with exit 0); the design documents this honestly (D5, §8).**

---

## 0. Baseline re-execution (not trusted, run)

```
flutter test test/setup_screen_test.dart test/oidc_login_handle_success_census_test.dart \
  test/oidc_login_screen_client_id_test.dart test/app_router_client_id_wiring_test.dart \
  test/sso_client_login_exactly_once_test.dart   → 21/21 green (4+10+3+1+3)
```

Census is in **constant mode** at HEAD (strict `expect(actual, isEmpty)` for `test/`; lib/ single-site clause live): `grep -rn "sso-admin-console" lib/ test/` → exactly `lib/api/sso_client.dart:82`. Counts re-verified textually: setup 4, census 10, client_id 3, sso 17, exactly-once 3, entry_ux 10 (43 pinned), FG-3 1. 4 + 43 = 47 now; +3 = **50** as the design claims.

## 1. Q1 — REQ-1 stub capture and REQ-2 mirror: determinism verdict

### 1.1 REQ-1 (stub recorded URI) — CONFIRMED, deterministic for FM-1/2/3

- `lib/services/browser_navigation_stub.dart`: `assignLocation`/`replaceLocation` → `_replaceRoute` sets `_currentUri = _parseLocation(location)` **synchronously** (`:34-36`) *before* the deferred route replacement (`addPostFrameCallback`, `:38-45`); the callback no-ops when `AppNavigator.key.currentState == null` in a bare `MaterialApp` (`:40-41` guard — the design's `:40-41` citation is exact). `BrowserNavigation.currentUri` (`browser_navigation.dart:13`) reads `platform.currentUri()` → `_currentUri`. So after `tap` + `pumpAndSettle`, the assertion surface is fully settled; no timer/race component. ✓
- Exit 1: `setup_screen.dart:172` `BrowserNavigation.assignLocation('/admin/');` — exact; `_goToAdminConsole` wired to `SetupAlreadyInitializedPanel.onContinue` (`:194`); the panel's `FilledButton` is at `setup_widgets.dart:55-58` (design's §1 correction right; the spec still says `:96-97`); fixture `{"setup_required":false}` → `_checkStatus` (`setup_screen.dart:100-104`) → `_Step.alreadyInitialized` (design's `:145`-shape claim right). ✓
- Exit 2: `setup_screen.dart:362` `onDone: () => BrowserNavigation.replaceLocation('/admin/')` — exact. No-secret fixture `{'ok': true, 'created': {'admin': 'root'}}` → `SetupResult.success` (`setup_api.dart:183-191`; 200 + `ok == true`) → done state with `_createdClientSecret == null` → button enabled (`setup_widgets.dart:354-355`: `widget.clientSecret == null || _savedSecret`). ✓
- Drift modes: FM-1/FM-2 (any target ≠ `/admin/`) → `currentUri.path` mismatch → red. FM-3 (button gated) → `tap` no-ops, path stays `/` → red. All deterministic — **no enumerated REQ-1 drift mode passes**.

### 1.2 REQ-2 (mirror + `loginPosts == 1` + constant reference) — CONFIRMED for FM-5/14/15/D3; **FAILS FM-4 as attributed**

- Harness pattern confirmed: `_LoginHarness` at `oidc_login_screen_client_id_test.dart:27-66`; D9 filter `body['credential'] is Map` at `:34`; `lastClientId = body['client_id'] as String?;` at **:37** (design's §1 correction right; the spec's `:31` remains wrong). ✓
- Pump expression byte-matches `app_router.dart:36`: `defaultClientId: SSOAdminClient.firstPartyClientId`. `_effectiveClientId` (`oidc_login_screen.dart:159-161`): `_params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '')` — routeUri `https://sso.example/login/?redirect=/admin/` carries no `client_id` (`OAuthParams.fromUri` has no `redirect` field; `HostedLoginRoute.fromUri` parses only `flow`/`token`/`email`), so the fallback fires. `redirect` is read only by `_safeRedirectTarget` (`oidc_login_screen.dart:70-90`), and only in federated flows (`oidc_provider_flow.dart:99,140`) — the password path is unaffected; success goes through `_completeFirstPartyLogin` (no navigation that can throw in a bare `MaterialApp`; the pinned hosted test proves the shape). ✓
- Deterministic red: **FM-5** (`'client_id'` key renamed/removed at `sso_client.dart:98`) → `body['client_id']` → null → `lastClientId` null → assert red. **FM-14** (second credential-bearing POST) → harness `script.removeAt(0)` on an exhausted list throws `RangeError` (test error) and/or `loginPosts == 2` → red. **FM-15** → D9 filter excludes probe/branding — no red by design (correct scope). **D3** (drop `defaultClientId` from the pump) → `(widget.defaultClientId ?? '')` → `''` ≠ constant → red (compile-error surface if the arg were made required). ✓
- **FM-4 — guard misattribution (substantive gap).** The design's FM-4 row credits "REQ-2 `lastClientId` assert; census lib/ clause" for catching *`app_router.dart:36` wiring dropped/changed (removed or switched to a different constant)*. Neither guard can catch it:
  - REQ-2's pump **mirrors** the expression — it never reads `app_router.dart`. Dropping `defaultClientId:` at `:36` or switching it to `SSOAdminClient.<other>` leaves REQ-2 green (its own pump still passes the constant).
  - The census lib/ clause (`oidc_login_handle_success_census_test.dart`, `libCarriesValue` = literal or `sso-admin-` prefix) reddens only on **value** drift of the constant or a new/removed literal *site*. Reference drift (router points at a different constant) leaves exactly one literal site → census green.
  - The guard that actually closes FM-4 is the pre-existing **`test/app_router_client_id_wiring_test.dart` (FG-3 call-site pin)** — it renders the real `resolveProductScreen` and asserts `probePosts == 1` + `lastProbeClientId == SSOAdminClient.firstPartyClientId` (wiring dropped → probe never fires; switched → wrong value). Its own docstring states the design's REQ-2-style contract test "cannot observe a dropped wiring argument". The design file and spec **never cite FG-3** (grep: zero hits), and the §7 joint-gate command **omits its file** — so the sole router-wiring guard is outside the design's acceptance surface.
  - Fix (recommended): cite FG-3 in FM-4's guard column and add `test/app_router_client_id_wiring_test.dart` to the §7 joint command (50 → 51), or reword FM-4 to the honest claim ("REQ-2 pins the wire *value* through the fallback path; router call-site drift is guarded by FG-3, not by this direction").

### 1.3 Residual REQ-2 unenumerated drift (low severity, scope boundary)

- If a future setup-exit URL grew a `client_id` query param, `_params.clientId` would win in `_effectiveClientId` and REQ-2 would still pass (constant reached via the param path, not the fallback). The design documents this as a constraint (§4 "redirect query inertness") but has no guard that distinguishes the two paths. Real-world trigger requires a co-change in the setup exits, which REQ-1 would already redden on the `/admin/` target; noted as accepted residual.
- `OAuthParams.fromUri`'s own `client_id` key rename (`q['client_id']`) is unpinned by this direction (fallback path unaffected; FG-3's probe also uses the fallback). Out of the enumerated set; low severity.

## 2. Q2 — 16 failure-mode rows: audit result

| Row | Verdict | Note |
|---|---|---|
| FM-1, FM-2 (exit target drift) | ✅ | Deterministic (§1.1) |
| FM-3 (done-panel gating) | ✅ | No-secret fixture keeps button enabled; gating regression → tap no-op → path `/` |
| FM-4 (router wiring dropped/changed) | ❌ **guard misattributed** | REQ-2 + census cannot catch it; real guard is uncited FG-3, omitted from §7 command (§1.2) |
| FM-5 (`sso_client.dart:98` key rename/removal) | ✅ | `lastClientId` null → red |
| FM-6 (fresh literal in `test/*.dart`) | ✅ | Top-level `Directory('test')` scan covers tracked + untracked files; constant mode live at HEAD |
| FM-7 (skip token in `setup_screen_test.dart`) | ✅ **as documented** — hole real | silenceRe scans exactly 4 files (`sso_client_login_exactly_once`, `oidc_login_screen_client_id`, `sso_client`, `entry_ux`); the new tests' file is convention-only (§3) |
| FM-8 (409 on initialized stack) | ✅ | Status pre-check + POST check; `alreadyDone()` factory is at `setup_api.dart:98` (design cites `:68-71` — that's the class doc/declaration; off-by-region, non-load-bearing) |
| FM-9 (device-tenant contamination) | ✅ | Local `setup_token`/`setup_tenant_id`; same-tenant → untouched steps 4/5 redden |
| FM-10 (username merge forgotten) | ✅ | `login_payload(self, *, password=...)` param exists (`test_config.py:86-95`); username hardcoded (`self.username`) — D3 confirmed |
| FM-11 (B4-5 absent → zero matches) | ✅ | FAIL → exit 1; note exit is at `:292`, not `:291` (design & spec both off by one; file is 292 lines) |
| FM-12 (sink unverifiable) | ✅ | No proposed path in the leg — FAIL (device-leg `proposed` deliberately not reused) |
| FM-13 (i18n copy drift) | ✅ | Finder red, accepted; `go_to_admin_console` at `app_strings_additional.dart:63` exact |
| FM-14 (double dispatch) | ✅ | `loginPosts == 2` and script exhaustion `RangeError` first |
| FM-15 (probe/branding POSTs) | ✅ | D9 filter; correct scope (probe counting is the hosted sibling's pin) |
| FM-16 (future re-pin of setup file) | ✅ | File unpinned today; 4→7 gate-safe; precedent exists (device spec §5) |

**Gaps found in the row set:**

1. **FM-4 misattribution** (§1.2) — the only row whose *guard* column is factually wrong.
2. **REQ-3 first-query ingestion race (not in the rows).** The design's leg does its first sink query (step 4) with **no `settle_seconds()`** before `check(len(matching) == 1)`; the setup login is *immediate* after the wizard POST, so a fresh IdP-emitted row may not be ingested → 0 matches → FAIL → exit 1 on a healthy post-B4-5 stack. The re-settle stability check (step 5) cannot rescue the first check. The device leg has the same structure but its login precedes the query by several steps. Fix: settle once before the first query (or make the exactly-one check follow one `settle_seconds()`). Direction of failure is loud (exit 1, never a false PASS), so this is a false-red robustness gap in acceptance (c)'s "green" branch, not a soundness hole. Also: the design cites the device-leg stability mirror at `:219-221` — actual `count stable after re-settle` check is `:213-215` (`:219` is Step 6's comment); the spec's `:210-215` is closer. Non-load-bearing.
3. **Whole-file platform exclusion (stronger FM-7 variant, unenumerated).** `@TestOn('browser')` at the top of `setup_screen_test.dart` → "No tests ran", exit 0, no count pin on the file → gate green. The design's convention token list covers `@TestOn`≠vm textually, but enforcement is absent exactly as for `skip:` — one row covers both; the D5 mutation only demonstrates `skip: true`.
4. **Un-scanned guard files.** The census file itself and `app_router_client_id_wiring_test.dart` are outside the 4-file silenceRe list. Skip tokens in FG-3's file are undetectable; in the census file, deleting the ban *test* drops the count to 9 → red, but *modifying* the ban body keeps 10 → undetected (inherent self-referential limitation; census file is untouched by this direction — acceptable, should be stated).
5. **Spec-size changes: no gap.** No test or gate pins the spec byte size (grep: zero references to 23020/23426 anywhere in `test/`); the §1 correction is informational only, as the design states. ✓

**Residual citation drift in the design's own claims** (all non-load-bearing; assertions reference symbols): drill `sys.exit(1 if FAIL else 0)` at **:292** (design/spec: `:291`); SKIP `sys.exit(0)` at **:111** (design: `:112`); Step-5 stability at **:213-215** (design: `:219-221`); `SetupResult.alreadyDone()` at **:98** (design: `:68-71`); spec's `SetupAdmin` at `setup_api.dart:17` (spec: `:18-22`; the design's §1 already corrected this on its side). The design's §1 "corrections" table is therefore not exhaustive — same class of off-by-one it flags in the evidence.

## 3. Q3 — 50/50 joint gate vs skipped / mutated / zero-running tests (FM-7)

Gate = §7 command (6 files) + "50/50 green" + exit 0. Count math verified: 7 + 43 = 50.

**Pinned side (43, in 5 files) — gate is machine-sound for skip/zero-run/delete:**

| Vector | Pinned files (4 machine-scanned) | Census file (10) | New tests (unpinned) |
|---|---|---|---|
| `skip:` / `skipTag` / `@Skip` / `@Tags` / `tags:` | ❌ **red** — silenceRe (`census_test.dart`, 4-file loop) | ❌ not scanned (self-exemption; count 10 unchanged) | ✅ **passes** — no scan, no count (FM-7) |
| `@TestOn('browser')` / ≠vm whole-file zero-run | ❌ **red** — `@TestOn\s*\((?!['"]vm['"])` in silenceRe | ❌ not scanned | ✅ **passes** — "No tests ran", exit 0 |
| Test deletion | ❌ **red** — per-file count pins (10/3/17/3/10, sum 43, computed at runtime inside the census test) | ❌ red — count drops to 9 | ✅ passes (no count) |
| Assertion-body mutation (tautology), count/tokens kept | ✅ **passes** — structural pins only; inherent to count-based gates; no behavioral meta-verification | same | same |

- **Skipped pinned tests cannot pass the gate**: the silence ban + runtime counts are executed *inside* the gate command (census test is one of the 6 files). Verified by reading the ban loop and by re-running the census green.
- **The census file is the guard's blind spot** (skip there is undetected by the ban and the count is textual) — acceptable because the design keeps it untouched and count-pinned; a compromised guard defeats any gate.
- **The 7 side is nominal, not enforced**: the 43 side has a runtime count assertion; `setup_screen_test.dart` has none. "50/50" = 43 enforced + 7 nominal. FM-7 is exactly this asymmetry.
- **The gate command also omits FG-3's file** (1 test, un-pinned, un-scanned) — see §1.2.

**Conclusion for Q3:** the design's claim is true for **pinned** tests (skip/zero-run/deletion machine-red; body-mutation undetectable — an inherent, stated limitation of count-based pins) and **false for the 3 new tests**: `skip: true` ("6 passed, 1 skipped", exit 0), whole-file `@TestOn('browser')` ("No tests ran", exit 0), and tautology mutation all satisfy the gate's exit-code semantics. The design does not overclaim — FM-7 row, D5 mutation ("no red"), and §8 risk all state it; the D5 negative control is honest about the hole. The natural fix (widen the census ban list + add a setup-file count to the joint pin) is correctly deferred as out of scope (census file pinned).

## 4. Deliverable-level verdict

- REQ-1 (stub capture): **sound, deterministic** for every enumerated drift mode and D1/D2.
- REQ-2 (mirror + constant): **sound** for D3/D4-adjacent modes (FM-5/14/15), **mis-attributed for FM-4** — the design's guard column is wrong and the real guard (FG-3) is outside the joint command. Fix before landing: cite FG-3, add its file to the §7 command.
- REQ-3 (drill leg): sound never-skip semantics (FM-8/9/10/11/12 verified against `audit_login_drill.py` actual lines); **one robustness gap** — no settle before the first sink query (false-red race on healthy stacks).
- 16 rows: 2 substantive corrections (FM-4; ingestion race) + 2 minor unenumerated vectors (whole-file `@TestOn`, un-scanned guard files) + 5 residual off-by-one citations.
- 50/50 gate: pinned side machine-sound; new-tests side convention-only (FM-7 confirmed, honestly documented; D5 mutation demonstrates the no-red).
- Baseline green at HEAD (21/21 re-executed); census constant-mode strict at HEAD; zero `lib/` diff.
