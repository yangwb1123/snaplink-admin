# B6-2 Requirements Specification — Setup→login edge emission pin: both post-wizard exits record `/admin/` on the navigation stub, and the subsequent login leg carries `client_id=sso-admin-console` exactly once

Module: `lib/screens/setup` (analysis bucket `docs/auto/analyses/lib-screens-setup-9fcea98d.json`) · Direction: B6-2 ("setup→login edge emission pin") · Value: 9 · Risk reduction: 8 · Effort: 3 · Confidence: 9
Status: implemented
Completes: `docs/campaigns/implementation-gate.md:57` console-row acceptance ("sink 出现 sso-admin-console login 事件；无重复") for the **setup-originated** entry path (the device leg is pinned by `test/entry_ux_test.dart:174-224` and `tests/integration/audit_login_drill.py`)
Sibling instances: `b6-2-lib-screens-device-firstparty-exactly-once-spec.md` (device leg), `b6-2-lib-screens-oidc-login-client-id-alignment-spec.md` (hosted leg)

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. **All nine are substantively accurate; two carry minor line drift** (corrected below). The wire value and both navigation exits are confirmed fully determined downstream; the un-pinned surface is exactly as the direction states — `test/setup_screen_test.dart` asserts neither the navigation target nor the login `client_id`.

| Direction citation | Verification result at HEAD |
|---|---|
| `lib/screens/setup/setup_screen.dart:172` — `_goToAdminConsole` → `BrowserNavigation.assignLocation('/admin/')` | **Exact.** `:171-173` `void _goToAdminConsole() { BrowserNavigation.assignLocation('/admin/'); }`. Call sites: `:191` (`SetupUnavailablePanel.onContinue`), `:194` (`SetupAlreadyInitializedPanel.onContinue`). The already-initialized panel is a `FilledButton` labeled `strings.goToAdminConsole` (`setup_widgets.dart:96-97`; English copy `'Go to admin console'`, `lib/i18n/app_strings_additional.dart:63`) — the testable trigger for exit 1. |
| `lib/screens/setup/setup_screen.dart:362` — `SetupDonePanel.onDone` → `replaceLocation('/admin/')` | **Exact.** `:354-362` `_buildDone` → `SetupDonePanel(... onDone: () => BrowserNavigation.replaceLocation('/admin/'))`. The done panel's single action is a `FilledButton` labeled `strings.goToAdminConsole` (`setup_widgets.dart:354-358`), **enabled only when `clientSecret == null \|\| _savedSecret`** (`setup_widgets.dart:355-356`) — a fixture carrying `client_secret` requires ticking the secret-saved `CheckboxListTile` first. |
| `lib/app_router.dart:35` — `defaultClientId: 'sso-admin-console'` | **Off by one line.** `:35` is `ProductEntry.login => OidcLoginScreen(`; `:36` is `defaultClientId: SSOAdminClient.firstPartyClientId,`. Value confirmed: `SSOAdminClient.firstPartyClientId == 'sso-admin-console'` (`lib/api/sso_client.dart:82`, sole `lib/` literal site). `OidcLoginScreen.defaultClientId` field at `oidc_login_screen.dart:54`, consumed via `_effectiveClientId` fallback `:159-161`. |
| `lib/api/sso_client.dart:86-92` — `login()` → POST `/auth/login` body `'client_id'` | **Approximate (shifted ~4 lines).** `login()` spans `:89-99`; signature default `String clientId = firstPartyClientId` at `:92`; `_post('/auth/login', {...})` at `:96`; `'client_id': clientId` wire at `:98`. Wire claim holds. |
| `test/setup_screen_test.dart:13,17,99,145,161` — `resetForTest` used, four tests, zero navigation/client_id assertions | **Exact.** 177 lines; `setUp` `BrowserNavigation.resetForTest()` at `:13`; `testWidgets` at `:17` (walk-through), `:99` (skips application), `:145` (already-initialized), `:161` (fails closed). Full-file read confirms zero `BrowserNavigation`/`currentUri`/`client_id` assertions. File is **not** in any count pin (see §5) — the natural home for the new tests. |
| `test/entry_ux_test.dart:174-224` — B6-2 group pins device-entry leg only | **Exact.** Group `B6-2 device-entry redirect leg (REQ-1)` at `:174` (comment `:171-173`); two `testWidgets` at `:180`/`:200` assert `BrowserNavigation.currentUri.path == '/login/'` + `redirect` query for `DeviceVerifyScreen` only. **Count-pinned at 10 tests** (census gate, see §5) — no test may be added here. |
| `tests/integration/audit_login_drill.py:31` — `AGREED_CLIENT_ID`, device redirect leg only | **Exact.** Docstring `:4-10` declares device-leg facts; `AGREED_CLIENT_ID = 'sso-admin-console'` at `:31`; exit contract `sys.exit(1 if FAIL else 0)` (`:291`); sink query `GET {API}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` at `:81-82` (`sink_rows`); exactly-one row check at `:183-186` (`len(matching) == 1`, filter `r.get('client_id') == AGREED_CLIENT_ID`); no-duplicates stability at step 5 (`:192-219`). No setup-originated leg exists. |
| `test/oidc_login_screen_client_id_test.dart:31` — `harness.lastClientId` pattern on POST `/auth/login` to reuse | **Exact.** `_LoginHarness` at `:27-66`; `lastClientId = body['client_id'] as String?;` at `:31`; D9 credential-key filter (`body['credential'] is Map`) distinguishes login POSTs from the mount-time probe; screen pumped with `defaultClientId: SSOAdminClient.firstPartyClientId`; assertions at `:77,:137,:159`. |
| `test/oidc_login_handle_success_census_test.dart:97-101` — zero `auth.login.success` emission strings in console module | **Exact** (test spans `:97-105`; the direction's `:97-101` covers the declaration and the offenders walk). Test `no auth.login.success emission string in the module (REQ-4 #5)` at `:97`; recursive `Directory(moduleDir)` walk asserts `offenders` empty (`:98-105`). Sink-side emission has no code path in this repo — the drill extension is `[PROPOSED]` (IdP-side, B4-5). |
| `docs/campaigns/implementation-gate.md:57,79` — B6-2 acceptance (`sso-admin-console` login event, 无重复) and G7 `entry_ux +10` count | **Exact.** `:57` console row: "边缘生成验证：login → `auth.login.success`（client_id=sso-admin-console）\| sink 出现 sso-admin-console login 事件；无重复 \| B4-5". `:79` G7 pins `entry_ux 10〔含 B6-2 组〕` — adding tests to `entry_ux_test.dart` would redden the G7/census count gate. |

Corrections to the direction's premises (all verified):

1. **Line numbers**: `app_router.dart:35` → the `defaultClientId` wiring is at **`:36`** (`:35` is the route arm); `sso_client.dart:86-92` → the login method is `:89-99` with the `'client_id'` body key at **`:98`**. Both are the same symbols the direction names; assertions must reference `SSOAdminClient.firstPartyClientId`, never line numbers.
2. **Exit-1 trigger surface**: `_goToAdminConsole` is reachable in tests through the **already-initialized panel** (`setup_required:false` fixture → `FilledButton 'Go to admin console'`), which requires no wizard steps — the minimal testable path for the `assignLocation` exit. The done-panel exit (`replaceLocation`) requires the wizard flow; with a no-secret fixture (`{'created': {'admin': 'root'}}`, the `:99` test's shape) the button is enabled directly.
3. **Entry-ux is count-pinned**: the landed census count gate (`test/oidc_login_handle_success_census_test.dart:249-273`) pins `entry_uxCount == 10` and a 43-test joint total. The new tests must land in `test/setup_screen_test.dart` (unpinned, 4 tests), not `entry_ux_test.dart`.
4. **`setup_screen_test.dart` carries the split-literal census constraint**: the literal census scans all of `test/*.dart` (`:127-148`); new test code must reference `SSOAdminClient.firstPartyClientId` and carry no `'sso-admin-console'` token in code, comments, or reason strings (established convention, device spec REQ-1). The silencing ban (`skip:`, `@Skip`, `@Tags`, non-VM `@TestOn` — `:283+`) applies to the new tests as well.

---

## 2. Scope

**In scope (this direction's T-12/G7 joint, no more, no less)**

- REQ-1 — Two new `testWidgets` in `test/setup_screen_test.dart` pinning both post-wizard exits on the navigation stub's recorded URI (`BrowserNavigation.currentUri`, not a mock interface): exit 1 via `_goToAdminConsole` (already-initialized panel) and exit 2 via `SetupDonePanel.onDone` (done panel), each asserting `currentUri.path == '/admin/'`.
- REQ-2 — One new `testWidgets` in `test/setup_screen_test.dart` pinning the login-wire value of the setup-originated leg: `OidcLoginScreen` built with the exact `app_router.dart:36` wiring (`defaultClientId: SSOAdminClient.firstPartyClientId`) yields `harness.lastClientId == SSOAdminClient.firstPartyClientId` on the credential-bearing POST `/auth/login` (oidc harness pattern, `oidc_login_screen_client_id_test.dart:27-66`).
- REQ-3 — `[PROPOSED]`, sink-side (no emission path in this repo — census `:97-105`): drill extension in `tests/integration/audit_login_drill.py` adding the setup-originated leg — setup POST → immediate login → sink query → exactly one `auth.login.success` row with the agreed `client_id`, zero duplicates; **zero matches → exit 1, never skipped**.

**Out of scope (explicitly not changed by this direction)**

- `test/entry_ux_test.dart` (B6-2 device group, count-pinned at 10), `test/oidc_login_screen_client_id_test.dart` (3), `test/sso_client_test.dart` (17), `test/sso_client_login_exactly_once_test.dart` (3), the census file itself (10) — all untouched; the 43-test gate stays as-is.
- Any production change in `lib/` — both exits and the wire are correct at HEAD (`setup_screen.dart:172,362`, `app_router.dart:36`, `sso_client.dart:82,89-99`); the `lib/` single-source clause (census `:154-175`) stays green with exactly the declaration site `sso_client.dart:82`.
- The IdP-side emission (B4-5, `implementation-gate.md:57` dependency column) — owned by the deployment repo; this repo's census pins its absence.
- The device-leg drill steps (`audit_login_drill.py` steps 1-5) — untouched; the extension is additive.

---

## 3. Requirements

### REQ-1 — Both post-wizard exits record `/admin/` on the navigation stub (2 tests in `test/setup_screen_test.dart`)

The file's existing `setUp` (`:13`, `BrowserNavigation.resetForTest()`) already guarantees a clean `Uri.base` per test; the stub records every `assignLocation`/`replaceLocation` target into `_currentUri` (`lib/services/browser_navigation_stub.dart` `_replaceRoute`/`_setSameDocumentLocation`), read via the static `BrowserNavigation.currentUri` getter (`browser_navigation.dart:16`) — the same assertion surface `entry_ux_test.dart:193,213` uses. **Assert on the stub's recorded URI, never a mock interface.**

1. **Exit 1 — already-initialized panel → `assignLocation`** (`_goToAdminConsole`, `setup_screen.dart:172`): fixture `{"setup_required":false}` (the `:145` test's shape); pump `SetupScreen(api: api)` in a `MaterialApp`; `pumpAndSettle`; tap `find.text('Go to admin console')` (the panel's `FilledButton`, `setup_widgets.dart:96-97`); then `expect(BrowserNavigation.currentUri.path, '/admin/')`.
2. **Exit 2 — done panel → `replaceLocation`** (`SetupDonePanel.onDone`, `setup_screen.dart:362`): walk the wizard with the no-secret fixture `{'created': {'admin': 'root'}}` (the `:99` test's shape — no `client_secret`, so the action button is enabled without the secret-saved checkbox, `setup_widgets.dart:355-356`); tap `find.text('Skip and finish')`; `pumpAndSettle`; tap `find.text('Go to admin console')` (the done panel's `FilledButton`, `setup_widgets.dart:354-358`); then `expect(BrowserNavigation.currentUri.path, '/admin/')`.

Hard constraints:

- Assertions reference the recorded URI only (`BrowserNavigation.currentUri`), matching the direction's "stub's recorded URI, not a mock interface".
- The `'Go to admin console'` label is the i18n key `go_to_admin_console` (`app_strings_additional.dart:63`); the file's existing tests already use English literal text finders (e.g. `'Skip and finish'`), so this is consistent — but the finder must target the panel's action button (a bare `find.text` is unambiguous: only one such button is on screen at a time).
- No `'sso-admin-console'` token anywhere in the new test code or comments (test/ literal census; split-literal convention).

**Testable:** `flutter test test/setup_screen_test.dart` → 6/6 green (4 existing + 2 new) at HEAD state, no production changes. Mutations: change `setup_screen.dart:172` or `:362` to any other target → the corresponding test fails; revert → green.

### REQ-2 — Setup-originated login wire carries the first-party client_id (1 test in `test/setup_screen_test.dart`)

Reuse the oidc harness pattern (`test/oidc_login_screen_client_id_test.dart:27-66`): a `MockClient` over `OidcLoginApi` that counts **credential-bearing** POST `/auth/login` requests (D9 filter: `jsonDecode(request.body)['credential'] is Map` — excludes the mount-time provider probe) into `loginPosts`, captures `lastClientId = body['client_id'] as String?`, and serves `{'access_token': 't', 'session_id': 's'}` on login (probe/branding → 404, treated as absence).

The test builds the screen with the **exact `app_router.dart:36` wiring** — `OidcLoginScreen(api: api, defaultClientId: SSOAdminClient.firstPartyClientId, routeUri: Uri.parse('https://sso.example/login/?redirect=/admin/'))` (the `redirect=/admin/` query is the shape the setup exits produce via `AdminGateScreen`, per the `app_router.dart` doc comment) — submits the admin form, and asserts:

- `loginPosts == 1` (exactly one credential-bearing POST — the direction's "emit exactly one" client-side half; sink-side emission is IdP-owned, REQ-3);
- `lastClientId == SSOAdminClient.firstPartyClientId` — the wire value `app_router.dart:36` → `OidcLoginScreen._effectiveClientId` fallback (`oidc_login_screen.dart:159-161`) → `sso_client.dart:98` `'client_id'` body key.

Hard constraints:

- The assertion references `SSOAdminClient.firstPartyClientId` — **never** the literal `'sso-admin-console'` (strict-mode census scans `test/*.dart`).
- No `skip:`/`@Skip`/`@Tags`/non-VM `@TestOn` tokens (silencing ban, census `:283+`).
- The harness lives in `test/setup_screen_test.dart` (unpinned file); the pinned harness files stay untouched.

**Testable:** `flutter test test/setup_screen_test.dart` → 7/7 green. Mutations: drop `defaultClientId` from the pump (or change it) → `lastClientId` assertion fails; revert → green. The test pins the router's wiring expression by construction (same constant reference), so `app_router.dart:36` drift to a different value reddens this test only if the constant changes — which the census `lib/` clause would also redden.

### REQ-3 — Drill extension: setup-originated leg, exactly-one row, zero duplicates, zero matches → exit 1 (`[PROPOSED]`, sink-side)

Extend `tests/integration/audit_login_drill.py` with a new step **after Step 3** (device-funnel login), additive — steps 1-6 untouched. The leg mirrors the direction's acceptance (c) verbatim: *login immediately after wizard completion, then sink query returns exactly one row with `client_id=sso-admin-console`, zero duplicates; zero matches → exit 1, never skipped*.

1. **Wizard completion wire** — `POST {PROXY}/api/v1/setup` with the module's payload shape (`setup_api.dart:161-162`: `{'admin': admin.toJson(), if (application != null) 'application': application.toJson()}`; `SetupAdmin` = `{'username', 'password'}`, `setup_api.dart:18-22`). A fresh username (e.g. `drill-setup-<epoch>`) keeps the leg repeatable.
2. **Immediate login** — `POST {PROXY}/auth/login` with the created admin and `CONFIG.login_payload()` (carries `'client_id': self.client_id`, `test_config.py:86-90`); decode the JWT for `tenant_id` (B4-1 claim dependency — existing Step-3 convention).
3. **Sink query** — `GET {API}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` (the existing `sink_rows` builder, `:81-82`); filter `r.get('client_id') == AGREED_CLIENT_ID` (Step-4 idiom, `:184`).
4. **Hard checks** (mirroring Step 4's `check(...)` semantics — a failed `check` flips `FAIL` and the drill exits 1 at `:291`):
   - `len(matching) == 1` — **zero matches is a FAIL → exit 1, never a skip, never a PASS**; duplicates also FAIL;
   - re-settle (`settle_seconds()`) → re-query → count stable (mirror of Step 5's `:210-215` stability check) — pins 无重复 over ingestion lag.

**Never-skipped rule**: the `[proposed]` marking (`:170-190` pattern) applies **only** to the pre-existing infra-unavailability path (`CONFIG.require_credentials` → SKIP, exit 0, `:115-119`). A runnable leg (token + tenant_id obtained) must never route a zero-match or duplicate query result into `proposed` — the check is unconditional and fails the drill. Step banner and docstring must state `[proposed]`: emission is IdP-side (B4-5, `implementation-gate.md:57` dependency column), zero `auth.login.success` emission strings in this repo (census `:97-105`).

**Testable:** with a deployed stack (`SNAPLINK_*` env, `test_config.py:36-44`), `python3 tests/integration/audit_login_drill.py` → setup leg checks pass once B4-5 emission lands; before B4-5, the leg reports FAIL (exit 1) on zero matches — never skipped, per the acceptance. Without credentials: pre-existing SKIP (exit 0) — unchanged.

---

## 4. Acceptance checks (supplied T-12/G7 checks preserved 1:1, made testable)

| # | Supplied check | Testable form (this spec) |
|---|---|---|
| (a) | Widget test completing the wizard via both exits (`_goToAdminConsole` and `SetupDonePanel.onDone`) asserts BrowserNavigation stub records target `/admin/` — assert on the stub's recorded URI, not a mock interface | REQ-1: two `testWidgets` in `test/setup_screen_test.dart` — exit 1 via the already-initialized panel's `'Go to admin console'` (`setup_screen.dart:194` → `assignLocation` `:172`), exit 2 via the done panel's `'Go to admin console'` (`:362` → `replaceLocation`); both `expect(BrowserNavigation.currentUri.path, '/admin/')` on the stub's recorded URI (`browser_navigation_stub.dart` `_currentUri`, `currentUri()` getter). `flutter test test/setup_screen_test.dart` → 6/6 green; mutating `:172`/`:362` targets reddens the corresponding test |
| (b) | Login-wire pin reusing the oidc harness pattern — `OidcLoginScreen` built with `app_router.dart:35` defaultClientId yields `harness.lastClientId == 'sso-admin-console'` on POST `/auth/login` | REQ-2: one `testWidgets` in `test/setup_screen_test.dart` — pump `OidcLoginScreen` with the `app_router.dart:36` expression `defaultClientId: SSOAdminClient.firstPartyClientId` + routeUri `/login/?redirect=/admin/` + a credential-filtered `MockClient` harness (mirror of `oidc_login_screen_client_id_test.dart:27-66`); submit login → `loginPosts == 1` and `lastClientId == SSOAdminClient.firstPartyClientId` (constant reference — the census forbids the literal). 7/7 green; dropping the `defaultClientId` arg reddens the test |
| (c) | [proposed, sink-side — no emission path in this repo] Drill extension: login immediately after wizard completion, then sink query `GET /api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` returns exactly one row with `client_id=sso-admin-console`, zero duplicates; zero matches → exit 1, never skipped | REQ-3: new drill step after Step 3 — `POST {PROXY}/api/v1/setup` (`setup_api.dart:161-162` wire) → immediate `POST /auth/login` (`login_payload`, `test_config.py:90`) → `sink_rows` query (`:81-82`) → hard `check(len(matching) == 1)` (zero matches → FAIL → `sys.exit(1)` at `:291`) + re-settle stability check (无重复). `[proposed]` marking restricted to the infra-unavailability SKIP path (`:115-119`); a runnable leg never converts a zero-match into a skip or PASS |

Joint gate: `flutter test test/setup_screen_test.dart` → **7/7 green** (4 existing + REQ-1's 2 + REQ-2's 1); `test/entry_ux_test.dart`, `test/oidc_login_screen_client_id_test.dart`, `test/sso_client_test.dart`, `test/sso_client_login_exactly_once_test.dart`, `test/oidc_login_handle_success_census_test.dart` unchanged and green (census 43-test gate untouched); `git diff --stat lib/` → empty; `python3 tests/integration/audit_login_drill.py` → exit 0 on a B4-5-landed stack, exit 1 on zero matches (never skipped), pre-existing SKIP only without credentials.

---

## 5. Dependencies and constraints

- **Count pins (G7, `implementation-gate.md:79`; census gate `:249-273`)**: `entry_ux_test.dart` is pinned at **10** tests and the joint gate at **43**; `setup_screen_test.dart` is in no pin (4 tests). All new tests land in `setup_screen_test.dart` (4 → 7); no gate re-pin is required, and touching `entry_ux_test.dart` is prohibited by this direction.
- **Literal hygiene (census `:127-148`)**: the new tests reference `SSOAdminClient.firstPartyClientId`; the `'sso-admin-console'` token must not appear in code, comments, or reason strings; no `skip:`/`@Skip`/`@Tags`/non-VM `@TestOn` tokens (silencing ban `:283+`).
- **`lib/` single-source clause (census `:154-175`)**: this direction changes zero `lib/` files; the walk stays green with exactly the declaration site (`sso_client.dart:82`). No production edit is required or permitted by this direction.
- **Done-panel gating (`setup_widgets.dart:355-356`)**: with a `client_secret` fixture the exit-2 test must tick the secret-saved checkbox before the button enables; REQ-1 uses the no-secret fixture to keep the button directly enabled (same fixture shape as the existing `:99` test).
- **Drill contract**: `AGREED_CLIENT_ID` (`:31`) is the single agreed value; the extension reuses it and `CONFIG.client_id` (`test_config.py:90`) — no new literal. The drill remains the only deployed-evidence channel for IdP-side emission; the `[RESOLVED]` note convention (`audit-contract-batch-snaplink-console.md`, drill `:278-280` precedent) applies: until B4-5 lands, the setup leg records its deviation, never a false PASS.
- **B4-5 dependency**: the sink row is emitted by the IdP (deployment repo), not by this module — census `:97-105` pins zero emission strings here. REQ-3's checks become green only after B4-5 lands; before that they fail loud (exit 1), which is the intended gate behavior for `implementation-gate.md:57` and must not be converted to a skip.

## 6. Risks and rollback

- **Line-drift corrections** (`app_router.dart:35→36`, `sso_client.dart` wire at `:98`): no assertion depends on a line number — the wiring is pinned by the constant reference in the pump and the harness capture; drift is compile-visible.
- **i18n copy drift**: the exit tests tap `'Go to admin console'` (key `go_to_admin_console`). A copy change reddens the finder — acceptable, matches the file's existing literal-finder convention; the finder is unambiguous (single action button per panel).
- **Count-gate interaction**: adding tests to `setup_screen_test.dart` cannot redden the 43-test gate (file unpinned). If a future spec re-pins this file, the gate must be extended in the same commit (device-spec §5 precedent).
- **Drill red until B4-5**: the never-skipped rule makes the drill exit 1 on the current stack until IdP-side emission lands. This is the intended loud-failure gate per `implementation-gate.md:57`; the pre-existing SKIP path (no credentials) is the only legitimate non-red outcome.
- **Rollback**: the change set is test-only (3 tests in one unpinned file + one additive drill step); reverting restores the pre-direction guard state with zero production impact (`git diff --stat lib/` empty either way).
