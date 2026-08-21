# B6-2 Design — Pin PortalApi session-expiry hook firing and token-state rollback semantics (module `lib/screens/portal`, test-only; REQ-1..REQ-4)

> Status: **implemented and verified (2026-08-20)**. The 42-test VM matrix, 13-test browser entry guard, and `make test-browser` wiring are landed; this document remains the design-of-record for the test-only contract. Sibling spec: `docs/proposals/b6-2-lib-screens-portal-session-expiry-rollback-pin-spec.md`.

## 0. Evidence verification verdict (re-checked at HEAD `de9b446`, 2026-08-08)

| Spec claim | Repository reality (executed) | Verdict |
|---|---|---|
| HEAD is `de9b446`; zero `lib/` working-tree diff | `git rev-parse HEAD` = `de9b446`; `git diff HEAD --stat -- lib/` → **0 lines (executed)**; `git status --short` shows only `docs/`+`test/` paths (unrelated B6-1 M2 delta) | ✅ exact |
| `_notifyIfSessionExpired` at `lib/api/portal_api.dart:103-110`; 403-preservation comment `:104-107`; 401-only guard `:108` | Function spans **:103-108**; comment **:104-107**; guard `if (r.statusCode == 401) onSessionExpired?.call();` at **:107** (spec's `:108` is off by one) | ✅ exact substance, guard cited :107≠:108 |
| Hook invoked at `get` `:114`, `post` `:167`, `patch` `:179`, `put` `:187`, `_delete` `:212` (shared by `delete`/`deleteWithQuery`) | `grep -n _notifyIfSessionExpired` → exactly **:114/:167/:179/:187/:212** | ✅ exact |
| SSE path: `notificationEvents` `:121-147`; inline 401 fire `:132-133`; no-token guard `:124`; hook fires **before** the throw | Doc comment `:121-123`, method `:125-151`; inline fire at **:133** (spec `:132-133`, off by one); no-token guard at **:128** (spec `:124`, off by four); `if (response.statusCode == 401) onSessionExpired?.call(); throw PortalApiError(...)` → hook before throw ✓; consumer `portal_screen_notifications.dart:18-20` = `notificationEvents().listen(..., onError: (_) {})` — the redirect depends on the hook having fired pre-throw | ✅ exact substance, two off-by-one/off-by-four citations |
| `login` `:233-257`: capture `:238-240`, tentative install `:241-243`, `get('/me')` probe `:245`, non-200 throw `:246-248`, rollback `:251-253`, `PortalApiError` rethrow `:254`, transport → `PortalApiError(0, …)` `:255` | **Exact** (sed-verified line-by-line) | ✅ exact |
| `fetchMe` `:270-276` throws non-200 (`:272-274`); `fetchListOrEmpty` `:282-290` = `const []` `:285` + catch-all `const []` `:288-289`; file ends `:292` | **Exact** (sed-verified; file `wc -l` = 292) | ✅ exact |
| JWT getters `:65`/`:70`; `_sidFromToken` `:72-74`; `_claimFromToken` `:76-99`; list-claim first element `:89-91`; null for ≠3 parts `:80-81`; catch-all null `:93-96` | Getters/helpers spans exact; list first-element at **:87** (spec `:89-91`, off by two); ≠3-parts null at **:79** (spec `:80-81`); catch-all null at **:92-96** (spec `:93-96`) | ✅ exact substance, minor drift |
| `test/portal_api_test.dart`: 5 tests/109 lines; only `:70-71` touch the getters; zero hook/rollback/fetchMe/fetchListOrEmpty/JWT coverage (premise holds) | 5 tests, 109 lines, `:70-71` = the opaque-token explicit-value leg; full-file grep shows zero `onSessionExpired`, zero rollback asserts | ✅ exact (premise **holds**) |
| B6-2 request-bound pins: `portal_entry_test.dart:301-338` (paste) + `:340-363` (resume), 6 testWidgets | Paste testWidgets at **:301-332**, resume at **:334-363** (spec boundaries off by a few lines); **6 testWidgets** total (grep: :185/:208/:224/:269/:301/:334) + 7 plain tests = 13 | ✅ exact substance |
| `portal_screen.dart` wiring `:125`/`:213`; `_handleSessionExpired` `:294-310` (disarm `:296`, `Session.clear()` `:298`, `_startHostedLogin()` `:302`); sibling `_signOut()` `:230-255` (`signOut()` `:242`, `Session.clear()` `:245`, hosted-login `:246-249`) | All **exact** (grep-verified: `:125`/`:213` arm; `_handleSessionExpired` def `:294`, disarm `:296`, clear `:298`, `_startHostedLogin` `:302`; `_signOut` def `:230`, `signOut()` `:242`, `Session.clear()` `:245`, `_startHostedLogin()` `:247`) | ✅ exact |
| `sessions_tab.dart:69-70`, `security_account_credentials.dart:64-65`, `trusted_devices_card.dart:70-71` read `currentClientId` for TrustedDeviceToken scoping | **Exact** (sed-verified; `TrustedDeviceToken.clear(clientId)` gates on non-null at both call sites; `_trustCurrentDevice` gates null/empty) | ✅ exact |
| Pin-neutrality: `portal_api_test.dart` remains uncounted; `portal_entry_test.dart` is now in the browser gate; `portal_api.dart` is a 3-line re-export shim | `portal_api_test.dart` is not in count pins; `Makefile:test-browser` explicitly includes `portal_entry_test.dart`; current liveness documentation is re-pinned to 19 after F12; shim remains a re-export | ✅ current |
| **AC-5 leg 1**: `flutter test test/portal_api_test.dart test/portal_entry_test.dart` → all green, portal_entry_test "re-run as the request-bound regression guard" | **⚠ MATERIAL DISCREPANCY.** `test/portal_entry_test.dart` is `@TestOn('browser')` (line 1). Executed: plain `flutter test` runs the file as **"No tests were found"** (0 tests) and the combined command exits 0 with only the 5 VM tests — a **false-green** of the exact M5 class the repo's own gate docs warn about. The file is also **not** in `make test-browser` (`.github/workflows/ci.yml` step runs that target with Chrome; `portal_entry_test.dart` absent from the 6-file list) → it executes **nowhere in CI at HEAD**. Executed `flutter test --platform chrome test/portal_entry_test.dart`: **13/13 green** (Chrome 151 available in this environment) — the file is runnable, just never run | ✗ claim false as written; corrected in §5 (AC-5 legs B1/B2) |

**Bottom line:** every substantive claim — the four gaps (S1-S4), every hook call site, every rollback span, and the original five-test coverage gap — was confirmed at the historical baseline. The browser-only false-green is now closed: AC-5 is split into a VM leg, a platform-explicit browser leg, and a zero-lib leg, with the `make test-browser` companion landed.

## 1. API changes

### 1.1 Production API — none (enforced constraint, zero `lib/`)

No production symbol changes. The contract being **pinned** (unchanged, cited at HEAD):

- `PortalApi.onSessionExpired` (public mutable callback, `lib/api/portal_api.dart:52-57`) — armed by `portal_screen.dart:125` (paste) / `:213` (resume), never during `login()`'s own probe.
- `_notifyIfSessionExpired` (`:103-108`): 401-only, 403-preserving (comment `:104-107`).
- Request surface: `get` (`:110-119`), `notificationEvents` (`:125-156`, inline 401 fire `:133` before `throw PortalApiError` `:134`), `post` (`:159-169`), `patch` (`:171-181`), `put` (`:183-189`), `delete` (`:191-192`)/`deleteWithQuery` (`:194-198`)→`_delete` (`:200-214`).
- `login` (`:233-257`) tentative-install/rollback state machine; `fetchMe` (`:270-276`); `fetchListOrEmpty` (`:282-290`); getters `currentSessionId`/`currentClientId` (`:65`/`:70`) with `_claimFromToken` decode (`:76-99`).

### 1.2 Test-suite API — 37 tests appended to `test/portal_api_test.dart` (uncounted file)

Imports unchanged (`package:http/testing.dart` `MockClient` already present; covers the `send()`-based SSE path because `MockClient` overrides `send()`). Existing 5 tests stay byte-identical. Four groups appended in-file, pure `test()` (no widgets, no binding):

**G1 — AC-1 hook matrix (21 data-driven tests).** Shared counter-seeded client: request #1 (login probe) → `http.Response('{}', 200)`; request #2 (path under test) → `http.Response('', status)`. Per scenario: fresh `api`, `api.onSessionExpired = () => fired++;`, `await api.login('t')`, then exactly one call through the path (`get('/me/roles')`, `post('/me/roles')`, `patch('/me/roles', {})`, `put('/me/roles', {})`, `delete('/me/roles')`, `deleteWithQuery('/me/roles', query: {'a':'b'})`, or `expectLater(api.notificationEvents(), throwsA(isA<PortalApiError>().having((e) => e.status, 'status', equals(status))))`). Asserts: `fired == 1` (401) / `fired == 0` (403, 500) **and `requests == 2`** — the counter pin makes the 403/500 negative legs non-vacuous (a path that silently stopped issuing requests cannot pass them). Reason strings cite `portal_api.dart:104-107`.

**G2 — AC-2 rollback + re-install (1 stateful test, 4 steps).** MockClient handler switches on request ordinal: `200 → 500 → throw http.ClientException('down') → 200`. Steps: (1) `login('first-token', sessionId: 's-1', clientId: 'c-1')` → installed; (2) `login('second-token')` → `throwsA(PortalApiError(status: 500))` → reverted to `'s-1'`/`'c-1'`/`hasToken` true; (3) `login('third-token')` → `throwsA(PortalApiError(status: 0))` → reverted again; (4) `login('good-token')` → installed, `hasToken` true, getters now `null` (opaque token, no decode fallback). Pins: all tokens opaque (no `.`), so the JWT fallback cannot mask a failed revert; previous state non-null so revert is observable on both getters **and** `hasToken`; hook **not armed** in this test (a 401 probe would otherwise fire it — 500 chosen precisely to keep the rollback legs decoupled from hook semantics).

**G3 — AC-3 error semantics (7 tests).** `fetchMe`: 404 → `PortalApiError(404)`, 500 → `PortalApiError(500)`, 200 `{'name':'x'}` → decodes. `fetchListOrEmpty('/me/roles', 'roles')`: 404 → `const []` (no throw), 500 → `const []`, throwing handler → `const []`, 200 `{'roles':['a']}` → `['a']` (positive control). Each test logs in first (probe = request #1, 200) so the paths ride a real installed token.

**G4 — AC-4 JWT decode via public getters (8 tests).** Each case `login(token)` (mock 200s `/me` — token shape is irrelevant to the probe), then asserts `hasToken` true + getters: (1) string claims `h.<b64url('{"sid":"s-9","aud":"console-client"}')>.s` → `'s-9'`/`'console-client'`; (2) list claims `{"sid":["s-list","s-2"],"aud":["c-1","c-2"]}` → `'s-list'`/`'c-1'` (first element); (3-5) `'no-dots'`, `'two.parts'`, `'a.b.c.d'` → both `null`; (6-8) `'a.!!!.c'` (invalid base64), `'a.<b64url("not json")>.c'`, `'a.<b64url("[1,2]")>.c'` (non-map JSON) → both `null`. Payloads built with `base64Url.encode(utf8.encode(...))` (unpadded — exercises `base64Url.normalize` in `:77`).

**Expected totals:** `test/portal_api_test.dart` = 5 existing + 37 new = **42 tests** on VM.

## 2. Compatibility constraints

1. **Zero `lib/` changes** — not `lib/api/portal_api.dart`, not the re-export shim, not `portal_screen.dart` wiring, not the TrustedDeviceToken call sites. Enforced by AC-5 leg C. Any behavioral change needed to make a test pass is a spec violation.
2. **Append-only, pin-neutral file** — `test/portal_api_test.dart` is referenced by no count pin, no Makefile target, no CI step (verified, §0); the existing 5 tests stay byte-identical. `test/portal_entry_test.dart` is executed-but-not-modified **in the corrected sense**: untouched as a file, and its browser leg is run platform-explicit (constraint 3).
3. **Platform split is mandatory, not cosmetic.** `portal_entry_test.dart` is `@TestOn('browser')`; the plain `flutter test` form silently skips it with exit 0 (the spec's AC-5 leg 1 as written is a false-green). The request-bound regression guard must be invoked as `flutter test --platform chrome test/portal_entry_test.dart` (13/13 verified green at HEAD under Chrome 151).
4. **Makefile/CI scope:** the landed companion only adds `test/portal_entry_test.dart` to the `test-browser` target — not `lib/`, not any count-gated file, and not the guard-count-pin target (its `GUARD_PIN_FILES`/`GUARD_PIN_COUNT` are unaffected).
5. **Companion landed:** `test/portal_entry_test.dart` is in the `make test-browser` file list, so the request-bound login leg executes in CI's Chrome job.
6. **No new dependencies** — `MockClient` covers the SSE `send()` path; payloads need only `dart:convert` (already imported by the file).
7. **Seeding rules** — (a) matrix probes must answer 200 so the matrix measures post-login paths only, mirroring `portal_screen`'s arm-after-login order (`:125`/`:213`); (b) the rollback test never arms the hook and uses 500 (not 401) for its non-200 leg; (c) rollback tokens are opaque so `_claimFromToken` cannot mask a revert.
8. **Import surface frozen** — new tests keep `package:sso_admin/screens/portal/portal_api.dart` (the shim), matching the file's existing imports; no churn.
9. **SSE 401 ordering is part of the pin** — `notificationEvents` fires the hook before throwing `PortalApiError(401)` (`:133-134`), because the only consumer (`portal_screen_notifications.dart:20`) swallows the error with `onError: (_) {}`; the redirect must not depend on the error.

## 3. Failure modes

| # | Failure mode (regression class) | Detection | Guard layer |
|---|---|---|---|
| F1 | Hook fires on 403 (spurious hosted-login redirect mid trusted-device enrollment) | Matrix 403 legs: `fired == 0` red | G1 (21×) |
| F2 | Hook fires on 500/transient errors (spurious redirect on server hiccup) | Matrix 500 legs: `fired == 0` red | G1 (21×) |
| F3 | Hook stops firing on 401 (silent stale bearer; session rides a dead token) | Matrix 401 legs: `fired == 1` red | G1 (7×) |
| F4 | Hook fires more than once per response (double redirect / double `_startHostedLogin`) | `fired == 1` (not `>= 1`) red | G1 exact-once assert |
| F5 | `login()` rollback regresses to partial restore (e.g. only `_token`) | G2 steps 2-3: getters must revert to `'s-1'`/`'c-1'` — red | G2 (opaque-token pin) |
| F6 | `login()` installs on non-200 / stops throwing | G2 steps 2-3 `throwsA(PortalApiError(500/0))` red | G2 |
| F7 | Transport error leaks the raw exception instead of `PortalApiError(0)` | G2 step 3 `throwsA(..., status: 0)` red | G2 |
| F8 | Successful re-install regresses (200 no longer installs) | G2 step 4: `hasToken` true + getters `null` red | G2 |
| F9 | `fetchMe` swallows non-200 (breaks the only throwing convenience method) | G3 `throwsA(PortalApiError(404/500))` red | G3 |
| F10 | `fetchListOrEmpty` throws on 404/500/transport (breaks "feature not wired" tolerance) | G3 `returns(const [])` + `doesNotThrow` red | G3 |
| F11 | JWT decode returns wrong claim / non-first list element / non-null for malformed tokens (stale `clientId` leaks into TrustedDeviceToken scoping) | G4 8 cases red | G4 |
| F12 | Decode throws instead of returning null on malformed payload (getter becomes a crash site) | G4 malformed cases red | G4 |
| F13 | A path silently stops issuing requests (negative legs become vacuous: `fired == 0` passes trivially) | `requests == 2` counter assert red | G1 counter pin |
| F14 | Entry-leg regression guard silently skipped (the spec's AC-5 false-green; the M5 class) | Corrected AC-5 leg B2 (`--platform chrome`) runs 13/13; leg B1 documents the VM zero-run as expected | AC-5 legs B1/B2 (+ optional `test-browser` companion) |
| F15 | Scope creep into `lib/` (behavioral "fix" smuggled in to make a test pass) | AC-5 leg C: `git diff --exit-code --stat -- lib/` non-empty → red | AC-5 leg C |

## 4. Migration steps

No production migration — zero `lib/` delta by contract; nothing to deploy. Repo steps:

1. **Append G1-G4 to `test/portal_api_test.dart`** (37 tests; existing 5 untouched). Use the G1 counter-seeded client, G2 stateful ordinal client, G3 login-then-path pattern, G4 `base64Url.encode` payload helper. No new imports beyond `dart:convert` if not already present (it is not needed — `base64Url`/`utf8` come from `dart:convert`; add the import if the analyzer requires it, `dart:async` already present for the stream leg).
2. **Run the VM leg** (AC-5 leg B1): `flutter test test/portal_api_test.dart` → expect **42/42** (5 + 37). Re-run the file alone first to isolate failures from the working tree's unrelated B6-1 M2 test deltas (`test/audit_contract_guard*`, `test/oidc_login_handle_success_census_test.dart`, `test/setup_screen_test.dart` are dirty but untouched by this direction).
3. **Run the browser leg** (AC-5 leg B2): `flutter test --platform chrome test/portal_entry_test.dart` → expect **13/13** (baseline re-executed green at HEAD under Chrome 151).
4. **Verify the zero-lib gate** (AC-5 leg C): `git diff --exit-code --stat -- lib/` → empty. If the working tree has other dirty files, the gate is scoped to `lib/` only by contract.
5. **Commit scope:** this direction = `test/portal_api_test.dart` (+37) + this design + the sibling spec. Do **not** sweep in the uncommitted B6-1 M2 delta (census/guard files, `tests/integration/audit_login_drill.py`) — that belongs to the B6-1 campaign.
6. **Optional companion (recommended, same or next commit):** add `test/portal_entry_test.dart` to the `test-browser` target in `Makefile:85`, closing the CI orphan (prerequisite — step 3 — already green). Safe: not `lib/`, not count-gated, `guard-count-pin` untouched, CI already provisions Chrome for that target.
7. **Count note:** the portal append is uncounted; the sibling F12 change re-pinned the liveness documentation from 15 to 19. Guard 82, entry_ux 10, and device API 4 remain unchanged.
8. **Future note:** any later direction touching `lib/api/portal_api.dart` or `lib/screens/portal/*` must re-run G1-G4 and the AC-5 legs; the matrix is the tripwire for the 403-preservation and rollback contracts.

## 5. Testable acceptance mapping

| # | Acceptance check (spec, preserved) | Corrected executable command | Expected | Fail-side proof |
|---|---|---|---|---|
| AC-1 (REQ-1) | Hook fires exactly once on 401, never on 403/500, across get/post/patch/put/delete/deleteWithQuery/notificationEvents; hook fires before the SSE throw | `flutter test test/portal_api_test.dart` (G1 group) | 21/21 green | F1-F4/F13 tripwires above; `fired == 1/0` + `requests == 2` per scenario |
| AC-2 (REQ-2) | Rollback on non-200 and transport error restores `_token`/`_sessionId`/`_clientId`; later 200 installs new state | `flutter test test/portal_api_test.dart` (G2) | 1/1 green (4-step sequence) | F5-F8; opaque tokens + non-null prior state make revert observable |
| AC-3 (REQ-3) | `fetchMe` throws on non-200, decodes on 200; `fetchListOrEmpty` swallows everything as `const []`, returns keyed list on 200 | `flutter test test/portal_api_test.dart` (G3) | 7/7 green (3 fetchMe + 4 fetchListOrEmpty) | F9/F10 |
| AC-4 (REQ-4) | Getters decode `sid`/`aud` incl. list-first-element; null for non-JWT and malformed payloads | `flutter test test/portal_api_test.dart` (G4) | 8/8 green | F11/F12 |
| AC-5 leg B1 (suite, VM) | Appended suite + existing 5 green | `flutter test test/portal_api_test.dart` | **42/42** | Any appended test red → suite red |
| AC-5 leg B2 (suite, browser — **corrected from spec's leg 1**) | Request-bound guard green, platform-explicit | `flutter test --platform chrome test/portal_entry_test.dart` | **13/13** (re-executed at HEAD) | F14: plain `flutter test test/portal_entry_test.dart` runs **0 tests** ("No tests were found") — the spec's original combined command is a false-green and must not be the gate |
| AC-5 leg C (zero-lib) | No `lib/` changes | `git diff --exit-code --stat -- lib/` | **0 lines, exit 0** | F15: any `lib/` path listed → exit 1 |

**Suite totals (this direction's scope):** VM `test/portal_api_test.dart` 42/42; browser `test/portal_entry_test.dart` 13/13; zero-lib gate empty. The appended VM file is uncounted; current neighboring pins are G7 82 / entry_ux 10 / liveness 19 / API 4.

## 6. References

- Build-request spec: `docs/proposals/b6-2-lib-screens-portal-session-expiry-rollback-pin-spec.md` (REQ-1..REQ-4 §2, AC-1..AC-5 §3, scope guard §4)
- Pinned production surface: `lib/api/portal_api.dart:52-57` (hook), `:103-108` (`_notifyIfSessionExpired`), `:110-119/:125-156/:159-169/:171-181/:183-189/:200-214` (paths), `:233-257` (`login`), `:270-276` (`fetchMe`), `:282-290` (`fetchListOrEmpty`), `:65-99` (getters + decode)
- Wiring: `lib/screens/portal/portal_screen.dart:125/:213` (arm), `:294-310` (`_handleSessionExpired`), `:230-255` (`_signOut`); `lib/screens/portal/portal_screen_notifications.dart:18-20` (error-swallowing consumer)
- Risk sites: `lib/screens/portal/sessions_tab.dart:69-70`, `lib/screens/portal/security_account_credentials.dart:64-65`, `lib/screens/portal/trusted_devices_card.dart:70-71`
- Request-bound pins: `test/portal_entry_test.dart:301-332` (paste) / `:334-363` (resume), `@TestOn('browser')` at `:1`
- Existing suite: `test/portal_api_test.dart` (5 tests, 109 lines)
- Gate arithmetic: `docs/campaigns/implementation-gate.md:79` (G7 row); `Makefile:85` (`test-browser` list); `.github/workflows/ci.yml` (CI steps incl. `make test-browser`)
