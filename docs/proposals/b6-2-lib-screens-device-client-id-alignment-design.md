# B6-2 Design — `lib/screens/device` lens: device-entry redirect-leg pin + drill login leg + no-forgery joint check

Module: `lib/screens/device` (analysis bucket `docs/auto/analyses/lib-screens-device-fb030ae1.json`) · Direction: B6-2 · Value: 7 · Risk reduction: 6 · Effort: 2 · Confidence: 9 · Status: design
Design for the requirements spec `docs/proposals/b6-2-lib-screens-device-client-id-alignment-spec.md` (REQ-0 … REQ-5, AC-1 … AC-3).
Sibling instances: `docs/proposals/b6-2-lib-api-client-id-alignment-design.md` (mechanism: `SSOAdminClient.firstPartyClientId` constant), `docs/proposals/b6-2-lib-screens-client-id-alignment-design.md` (live login-wire pin + post-login continuation), `docs/proposals/b6-2-lib-screens-developer-client-id-alignment-design.md` (DCR leg). This design owns the **device-module surface**: the device-entry login leg (`_redirectToLogin`, `device_verify_screen.dart:172-181`, call sites `:76/:226/:369`) and its regression pin in `test/entry_ux_test.dart`, the device-leg facts of the shared drill (`tests/integration/audit_login_drill.py`), and the no-localStorage-forgery joint check for this module — and names the **same constant, drill file, and `[RESOLVED]` record** so all lenses land one change set.

Branch-parametric (REQ-0): Branch A (rename to `console`) vs Branch B (contract amendment to `sso-admin-console`). The branch value enters this module **only at drill time** via `app_router.dart:35`; the module's production files and test fixtures are branch-neutral and byte-identical under both branches (REQ-5).

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

Every citation in the requirements evidence was re-checked line-exact against the repository. **All substantive claims hold.** The two corrections already recorded in the spec (stale `app_router.dart:55` inner citation; `preview['client_id']` reads) are confirmed; three new line drifts and two new module facts are adopted below:

| Evidence claim | Verification result |
|---|---|
| `lib/screens/device/device_verify_screen.dart:172-181` — `_redirectToLogin` → `/login/?redirect=/device/verify…` | ✅ exact. `:172` `void _redirectToLogin()`; `:174-177` target `Uri(path: '/device/verify', queryParameters: code.isEmpty ? null : {'user_code': code})`; `:178-180` `ProductApiOrigin.baseUri.resolve('/login/').replace(queryParameters: {'redirect': target})`; `:181` `BrowserNavigation.replaceLocation(login.toString())` |
| Call sites `:76/:226/:369` — all three invoke the one function | ✅ exact. `:76` `addPostFrameCallback((_) => _redirectToLogin())` in `initState` (no session); `:226` in `_verify` when `token == null \|\| token.isEmpty` (session-expiry re-entry); `:369` `signInAgain` TextButton `onPressed: _redirectToLogin` after 401 (`:248-249` `Session.clear()`) |
| `lib/app_router.dart:35` — `OidcLoginScreen(defaultClientId: 'sso-admin-console', …)`, `ProductEntry.login` arm `:34-37` | ✅ exact |
| `lib/api/sso_client.dart:86` (`String clientId = 'sso-admin-console',` default) and `:92` (`'client_id': clientId,` in POST `/auth/login` body, remaining keys `:91-95`) | ✅ exact |
| `test/sso_client_test.dart:18` — whole-body map assertion (`:16-22`) | ✅ exact |
| `lib/screens/device/device_verify_screen.dart:62` / `device_verify_widgets.dart:16` — `preview['client_id']` reads | ✅ exact (`:61-64` and `:16`); confirmed server-preview response reads (feeding `_hasSafeApprovalPreview`), **not** login-wire literals — the sibling claim "0 client_id literals in `lib/screens/device/`" is imprecise and stands corrected; no change under either branch |
| `docs/proposals/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` record with stale inner citation `app_router.dart:55` (actual `:35`) | ✅ exact (stale citation fixed when the record closes, REQ-0) |
| `docs/campaigns/implementation-gate.md:57` — B6-2 console row 2 (`边缘生成验证：login → auth.login.success（client_id=sso-admin-console） \| sink 出现 sso-admin-console login 事件；无重复 \| B4-5`) | ✅ exact (contract authority; quote corrected — the gate records `sso-admin-console`) |
| `test/device_verify_api_test.dart:31-50` — POST `/device/verify` carries no `client_id`; body pinned to `{user_code, approve}` | ✅ substantive claim exact; **line drift D-DEV-1**: approve test spans `:30-52` (not `:31-50`); the whole-body assertion is `:36-39` (not `:44-47` — that is the `api.verify(...)` call); the check-GET `queryParameters['check']` pin is `:21` (not `:22`) |
| `[PROPOSED]` — IdP/sink emission external; `grep -rn "auth.login.success" lib/ test/ tests/` → 0 hits; no client registry | ✅ confirmed (grep exit 1, 0 hits repo-wide); `lib/services/audit_log_service.dart:66` (`_storageKey = 'sso_audit_log'`) and `lib/services/event_bus.dart` are UI-local, not sink emitters; sole ring writer `lib/api/snaplink_admin_api.dart:82` |
| `lib/screens/oidc_login/oidc_login_screen.dart:159-161` — `_effectiveClientId` fallback to `widget.defaultClientId` | ✅ exact |
| `lib/screens/oidc_login/oidc_provider_flow.dart:54` — `'client_id': _effectiveClientId,` | ✅ exact |
| `lib/api/oidc_login_api.dart:47,52` — `probeProviders(clientId, …)` posts `'client_id': clientId` | ✅ exact |
| `lib/services/product_api_origin.dart:10,24` — VM `baseUri` = `ssoBaseUrlOverride ?? 'https://sso.ywbsd.site'` | ✅ exact (`:10` `nativeDefaultBaseUrl`; `:20` override expression; `:23-24` `baseUri` getter) |
| `lib/services/browser_navigation_stub.dart` — records `currentUri`; `resetForTest()`; `test/setup_screen_test.dart:13` pattern | ✅ exact (`:5` `_currentUri = Uri.base`; `:8` `currentUri()`; `:29/:36` `_parseLocation`; `:48-49` `resetForTest`); `replaceLocation` records synchronously → deterministic assertion |
| `test/entry_ux_test.dart:114-132` — existing `DeviceVerifyScreen` pump pattern | ✅ exact (`:114` `home: DeviceVerifyScreen(`, `:116` `accessTokenProvider: () => 'user-token'`); helper `_useNarrowViewport` at `:168` |
| `tests/integration/test_config.py:43-44` — `SNAPLINK_TEST_CLIENT_ID` default `'sso-admin-console'`; `:90` `'client_id': self.client_id` in `login_payload()` | ✅ exact |
| `tests/integration/api_login_e2e.py:59-77` — real `POST {PROXY}/auth/login` + JWT decode | ✅ exact (`:59-60` payload + curl POST; `:63-75` JWT split/decode/claims) |
| `lib/api/snaplink_admin_types.dart:310-312` — `GET /api/v1/audit/events`, `/audit/facets`, `/audit/events/{id}` | ✅ exact |
| Harness wiring points: `run_all.py:124` Gate 5; `full_stack_verify.py` steps 5-6 (`:100`, `:111`) | ✅ exact (see D-DEV-3: the drill is **already wired** at `run_all.py:169` / `full_stack_verify.py:113` — uncommitted diff) |
| `engineering.yaml:11` — `filesize.max_lines: 400` | ✅ exact |
| REQ-1 rationale "`accessTokenProvider: () => null` … without touching `Session.read()`" | ❌ **drift D-DEV-2** — see below |

**New drifts and module facts adopted in this design:**

- **D-DEV-1 — inner-citation drift in `device_verify_api_test.dart`.** The evidence's `:31-50` / `:44-47` citations for the approve test are off by the body-assertion block: the test spans `:30-52`, the whole-body map assertion is `:36-39`, and the check-GET `?check=` pin is `:21`. Substantive claim (device wire carries only `{user_code, approve}` / `?check=`) verified exact. No code change — citations in this design use the corrected lines.
- **D-DEV-2 — REQ-1's "without touching `Session.read()`" rationale is false as written.** `_accessToken()` is `widget.accessTokenProvider?.call() ?? Session.read()` (`device_verify_screen.dart:47-48`); a provider returning `null` falls through the `??` and **does** call `Session.read()`. The test still works: `SessionStorage` is memory-backed on VM (`lib/services/session_storage_memory.dart`, module-private `_values` map, fresh per test-file isolate) and `read()` returns `null` → the leg is taken. The design adds a defensive `Session.clear()` in the group's `setUp` and states the corrected rationale. (Note `() => ''` cannot substitute — `''` is non-null so the `initState` branch `_accessToken() == null` is false and no redirect occurs.)
- **D-DEV-3 — the drill exists as an untracked working-tree artifact, already wired; adopt, don't create.** `tests/integration/audit_login_drill.py` (214 lines, device-lens framing — its step 2 is this module's redirect-leg shape, §3.2's sketch) is **untracked** (`git ls-files` empty; no commit) and its wiring is an **uncommitted diff** at `run_all.py:169` / `full_stack_verify.py:113` — the `:164-166`/`:107-109` points the sibling plans name are exactly where the live entries sit. The earlier claim "does not exist today / new artifact" was true only of the committed tree. **Adopt-vs-create adjudication:** this change set and all siblings **adopt** the existing file and wiring; verbatim execution of the old "create + insert" plan would duplicate wiring blocks and overwrite an untracked file. **Git-clean fragility:** `git clean -f` deletes the drill; `git checkout -- tests/integration/run_all.py tests/integration/full_stack_verify.py` strips the wiring — M5 must `git add` file + wiring diffs **first**. The `grep -n "audit_login_drill" run_all.py full_stack_verify.py` acceptance already passes in the working tree and must stay green **after** M5's commit.
- **D-DEV-4 — `test/client_id_contract_test.dart` does not exist.** AC-2's testable form references it as the sibling-owned Branch B end-to-end pin (via `_effectiveClientId`, `oidc_login_screen.dart:159-161`); it must be created by the sibling `lib/screens`/`lib/api` change set (recorded as C3 in the developer lens design). This lens only grep-references it.
- **D-DEV-5 — `lib/screens/device/device_verify_api.dart` is a re-export shim** of `lib/api/device_verify_api.dart` (whose default constructor is inert: `http.Client()` + `ProductApiOrigin.baseUri`, no network at construction — so the REQ-1 pump omitting `api` is safe). The zero-diff guard covers the shim; "the device wire" is defined by the `lib/api` implementation file.
- **D-DEV-6 — no `AuthService`/ring refs in module + tests.** `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/device/ test/device_verify_api_test.dart test/entry_ux_test.dart` → exit 1 (0 hits), confirming REQ-4's module-side guard and the "no forgery channel" claim.

**Module-scope facts confirmed and folded in:**

1. The device login leg is a **pure redirect** — the module never POSTs `/auth/login` itself; the wire `client_id` is fully determined by `app_router.dart:35` + `sso_client.dart:86` (via `_effectiveClientId` → `oidc_provider_flow.dart:54` → `oidc_login_api.dart:47,52` → `sso_client.dart:92`). The redirect URL carries only `redirect`.
2. The module cannot contribute `client_id` evidence on its own wire (D-DEV-1 pins `{user_code, approve}` / `?check=`); the edge event is verifiable only via the redirect-leg drill plus constant alignment.
3. The redirect leg is VM-widget-testable: `BrowserNavigation.replaceLocation` records `currentUri()` synchronously; assertions are path + query only (host is `AppSettings`-dependent, `product_api_origin.dart:20`).
4. The two `preview['client_id']` reads (`device_verify_screen.dart:61-62`, `device_verify_widgets.dart:16`) are server-response reads; untouched under both branches.

---

## 2. Design summary

**Files touched: 0 production files + 1 test file (+1 group) + 1 new drill + 2 harness wiring lines + 1 doc record (+1 shared doc under Branch B). No new endpoints; no signature change anywhere in the module.**

1. **`test/entry_ux_test.dart`** — add the REQ-1 widget-test group (two cases: no-session pump with/without `user_code`; asserts `currentUri().path == '/login/'` and `queryParameters['redirect']`; host-independent) (REQ-1).
2. **Adopt** the existing untracked `tests/integration/audit_login_drill.py` (D-DEV-3) — the shared drill (same file the sibling lenses name); the **device redirect-leg shape step** (REQ-3 step 2) is **already present** as its step 2 (`/device/verify?user_code=…` and `/device/verify` construction checks); login uses `CONFIG.login_payload()` (which carries `client_id`); sink assertions read only `GET /api/v1/audit/events` (REQ-4); ≤ 280 lines (REQ-5 — 214 today). Do not recreate or overwrite.
3. `tests/integration/run_all.py` — **verify** the existing `run_e2e_test(...)` drill entry at `:169` (end of Gate 5, after `e2e_runner.py` — the `:164-166` insertion point; uncommitted diff; commit, do not re-insert).
4. `tests/integration/full_stack_verify.py` — **verify** the existing `step(...)` drill entry at `:113` (end of step 5, after the Detail API step `:107-109`; uncommitted diff; commit, do not re-insert).
5. `docs/proposals/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` → `[RESOLVED]` naming the branch + drill evidence; stale `app_router.dart:55` → `:35` (REQ-0).
6. Branch B: no gate amendment (no-op — gate:57 already records `client_id=sso-admin-console`, shared with the sibling lenses §3.7); under Branch A the row flips to `client_id=console`.
7. The value change itself (`sso_client.dart:86`, `app_router.dart:35`, `sso_client_test.dart:18`, `test_config.py:44`, `test/client_id_contract_test.dart` — D-DEV-4) is owned by the sibling change sets — this lens only **asserts** it (drill step 1) and **greps** it (REQ-5).

**Key decisions:**

- **D1 — Zero production diff is the design, not a constraint.** The module is a pure consumer: the aligned value enters only at drill time via `app_router.dart:35`. REQ-5 is enforced by `git diff` guards, so no `lib/screens/device/**` file appears in the change set at all. This makes the lens's rollback a no-op (F2, §5).
- **D2 — The REQ-1 pin asserts URL construction, not the wire value.** The widget test pins path + query of the login target (`/login/?redirect=/device/verify…`) — branch-independent. The branch's `client_id` is asserted at drill time only (REQ-3 step 3) and by the sibling-owned `sso_client_test.dart:18` / `client_id_contract_test.dart` pins.
- **D3 — The drill's device leg asserts the redirect-shape rule**, not a browser hop: the login entry URL is built by the same rule as `device_verify_screen.dart:174-180` and asserted (`redirect` query equals `/device/verify`, with the `user_code` form when a code is exercised). The API-driven login (canvas limitation, `browser_login_test.py:89` — C1 in the developer design) then carries the aligned `client_id` via `CONFIG.login_payload()` (`test_config.py:90`).
- **D4 — Defensive session isolation in the REQ-1 group**: `BrowserNavigation.resetForTest()` + `Session.clear()` per case (D-DEV-2). The stub's `replaceLocation` records synchronously, so the assertion after `pumpAndSettle()` is deterministic; `AppNavigator` navigation in `_replaceRoute`'s post-frame callback is a no-op in the test (key unregistered) — the screen stays mounted harmlessly.
- **D5 — Drill placement is Gate 5 / step 5** (proxy dependency): `run_all.py` starts the proxy only inside Gate 5 (`:128-150`, guard `:125`); `full_stack_verify.py` starts it at step 4. The drill sits after `e2e_runner.py` (`:164-166`) and after Detail API (`:107-109`). `--ci` skips Gate 5 — same as `e2e_runner.py`/browser tests; documented, not a defect.
- **D6 — Drill SKIP semantics**: missing credentials → `SKIP:` + exit 0 (mirrors `api_login_e2e.py:27-36`); FAIL (exit 1) only for genuine contract violations.
- **D7 — `[proposed]` fallback (sibling-consistent)**: the sink-side legs (exactly-one-row, no-duplicates) depend on BFF/sink emission this repo cannot generate (0 grep hits, §1). Unverifiable → log the query + result, mark `[proposed]`, record the deviation in the `[RESOLVED]` note, exit without a false PASS. The redirect-shape step and the login round-trip are always asserted when a stack is present.
- **D8 — The no-forgery guarantee is grep-provable**: zero `AuditLogService`/`sso_audit_log` references in the module + its tests (D-DEV-6); the drill queries only the server route; a ring row absent from the server response is not evidence.

---

## 3. API changes (concrete)

No production API in `lib/screens/device/` changes. The lens's "API surface" is the REQ-1 widget-test group, the drill file's device leg, the harness wiring, and the doc records.

### 3.1 `test/entry_ux_test.dart` — REQ-1 widget-test group (new; both branches, module-owned)

Appended as a new `group` in the existing file (which already imports `device_verify_screen.dart` and defines `_useNarrowViewport` at `:168`). The pump omits `api` (safe: `late final _api = widget.api ?? DeviceVerifyApi()` at `device_verify_screen.dart:34`, inert constructor — D-DEV-5).

```dart
group('B6-2 device-entry redirect leg (REQ-1)', () {
  setUp(() {
    BrowserNavigation.resetForTest();
    Session.clear(); // memory-backed on VM (D-DEV-2); guarantees null session
  });

  testWidgets('no session with user_code redirects to /login/?redirect=/device/verify?user_code=…', (
    tester,
  ) async {
    await _useNarrowViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceVerifyScreen(
          accessTokenProvider: () => null,
          routeUri: Uri.parse('https://sso.example/device/verify?user_code=WXYZ-1234'),
        ),
      ),
    );
    await tester.pumpAndSettle(); // redirect scheduled via addPostFrameCallback (:76)
    expect(BrowserNavigation.currentUri.path, '/login/'); // static getter
    expect(
      BrowserNavigation.currentUri.queryParameters['redirect'],
      '/device/verify?user_code=WXYZ-1234',
    );
  });

  testWidgets('no session without code redirects to /login/?redirect=/device/verify', (
    tester,
  ) async {
    await _useNarrowViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceVerifyScreen(
          accessTokenProvider: () => null,
          routeUri: Uri.parse('https://sso.example/device/verify'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(BrowserNavigation.currentUri.path, '/login/'); // static getter
    expect(BrowserNavigation.currentUri.queryParameters['redirect'], '/device/verify');
    expect(
      BrowserNavigation.currentUri.queryParameters.containsKey('user_code'),
      isFalse,
    );
  });
});
```

Notes: (a) assertions are path + query only — never scheme/host (VM `baseUri` is `AppSettings`-dependent, `product_api_origin.dart:20`); (b) `() => null` triggers the leg through the `??` fallback (D-DEV-2); (c) because `:76/:226/:369` all invoke the one `_redirectToLogin`, the pin transitively covers the 401-expiry re-entry (`signInAgain`); (d) imports needed: `BrowserNavigation` (`lib/services/browser_navigation.dart`) and `Session` (`lib/session.dart`) — both already dependency-free on VM.

### 3.2 `tests/integration/audit_login_drill.py` (existing untracked — adopt; REQ-3 + REQ-4, both branches)

Checked-in, runnable file (not a runbook pointer); the shared artifact named by all sibling specs. Budget ≤ 280 lines (`engineering.yaml:11` = 400; reference `api_login_e2e.py` = 166). Header docstring cites the canvas limitation at `browser_login_test.py:89` (C1) as the reason the login leg is API-driven through the proxy — the same wire the screens drive (`sso_client.dart:92`).

The **device-lens contribution** is the redirect-leg shape step (REQ-3 step 2) plus the login-value assertion:

```python
#!/usr/bin/env python3
"""B6-2 client_id contract drill — device redirect-leg facts
(lib/screens/device lens).

Proves: (a) the device-entry login leg has the shape the module pins
(REQ-1: /login/?redirect=/device/verify[?user_code=…] — built by the
same rule as device_verify_screen.dart:174-180), (b) a login through
that leg carries the aligned client_id on POST /auth/login
(sso_client.dart:92 wire), (c) the deployed sink shows exactly one
auth.login.success row with that client_id, no duplicates
(implementation-gate.md:57 '无重复').
Branch value (REQ-0): AGREED_CLIENT_ID = 'console' (A) or
'sso-admin-console' (B), one line. The login leg is API-driven through
the proxy because Flutter renders to a canvas (browser_login_test.py:89).
"""
AGREED_CLIENT_ID = 'sso-admin-console'   # mirrors the REQ-0 decision

# helpers: check()/curl() per api_login_e2e.py:12-26; decode_jwt() per
# full_integration_test.py:29-33 (read-only JWT payload decode)

# SKIP (no live stack/creds): CONFIG.require_credentials() raises
# IntegrationConfigurationError → print "SKIP: …", exit 0
# (api_login_e2e.py:27-36 idiom)

# Step 1 (REQ-0 evidence):  assert CONFIG.client_id == AGREED_CLIENT_ID
#                           else FAIL (config misalignment, not a drill bug)
# Step 2 (REQ-3 device leg): build the device-entry login URL by the
#   module's rule (device_verify_screen.dart:174-180):
#     target = '/device/verify' + ('?user_code=…' when a code is
#              exercised, else '')
#     login_url = '{CONFIG.proxy_url}/login/?redirect=' + quote(target)
#   Assert the redirect query parameter equals the target — the leg
#   shape REQ-1 pins in the widget test. (No browser hop: the drill's
#   login is API-driven; this step pins URL *construction*.)
# Step 3 (REQ-3 login):     POST {CONFIG.proxy_url}/auth/login with
#   client_id = AGREED_CLIENT_ID + CONFIG.login_payload() (the wire
#   sso_client.dart:92 drives; app_router.dart:35 → oidc_login_screen.dart
#   :159-161 → oidc_provider_flow.dart:54); assert access_token; decode
#   JWT; extract tenant_id claim → <t>; missing claim → FAIL with the
#   B4-1 dependency recorded (drill does NOT implement parsing)
# Step 4 (REQ-3 sink):      GET {CONFIG.api_url}/api/v1/audit/events
#   ?event_types=auth.login.success&tenant_id=<t> with Bearer
#   (documented route snaplink_admin_types.dart:310-312); assert
#   exactly one row whose client_id claim == AGREED_CLIENT_ID.
#   The ring is never consulted (REQ-4: server route only).
# Step 5 (no duplicates):   second login; re-query → exactly 2 rows,
#   no repeated event id/trace_id; settle ≥ max(10,
#   SNAPLINK_DRILL_SETTLE_SECONDS)s; re-query → count unchanged.
# Step 6 (report):          PASS/FAIL summary; exit 0 on PASS/SKIP,
#   1 on FAIL.
#
# [proposed] fallback (D7): if sink-side emission cannot be verified
# from this repo (no deployed stack / no emission observed), steps 4-5
# log the query + result, mark [proposed], record the deviation in the
# [RESOLVED] note, and exit 0 — no false PASS. Steps 1-3 are always
# asserted when a stack is present.
```

Exit-code contract: `0` = PASS or SKIP, `1` = FAIL. This keeps `run_all.py`/`full_stack_verify.py` honest without false failures in dev (D6).

### 3.3 Harness wiring (REQ-3, both branches)

- `tests/integration/run_all.py` — **already wired at `:169`** (inside Gate 5, after the Python E2E Runner entry — the `:164-166` insertion point this plan earlier named is where the live entry sits); uncommitted diff; verify, do not re-insert:
  ```python
  run_e2e_test('B6-2 Login Drill (client_id contract)',
               ['python3', 'tests/integration/audit_login_drill.py'], timeout=300)
  ```
- `tests/integration/full_stack_verify.py` — **already wired at `:113`** (end of step 5, after the Detail API step — the `:107-109` insertion point is where the live entry sits); uncommitted diff; verify, do not re-insert:
  ```python
  step('B6-2 Login Drill (client_id contract)',
       ['python3', 'tests/integration/audit_login_drill.py'], 300)
  ```

### 3.4 Doc records (REQ-0, both branches)

`docs/proposals/audit-contract-batch-snaplink-console.md:12` — replace the `[MISMATCH]` record (exact text shared with the sibling designs):

```markdown
- `[RESOLVED]`（B6-2, <date>）：Branch <A|B> chosen per drill evidence
  (<drill output attached>); code aligned on
  `SSOAdminClient.firstPartyClientId` (`app_router.dart:35`,
  `sso_client.dart:86`, `sso_client_test.dart:18` — citation corrected
  from the stale `:55`). Device-leg evidence: login through the device
  redirect leg (redirect=/device/verify) carried client_id=<agreed
  value>; sink query returned exactly one auth.login.success row (or
  deviation → `[proposed]` attached).
```

Branch B additionally **verifies** `docs/campaigns/implementation-gate.md:57` row 2 (shared with the sibling lenses) — **no amendment required**: the gate already records `client_id=sso-admin-console` with acceptance "sink 出现 sso-admin-console login 事件；无重复" (the earlier "amend the gate" narrative was based on a misquote; the described amendment is a no-op against the real text). Gate edit count under Branch B: zero.

### 3.5 Negative constraints (REQ-2/REQ-5, both branches — enforced, not aspirational)

The following must remain **byte-identical** at HEAD of the change set (guards in §7):

- Production: `lib/screens/device/device_verify_screen.dart`, `device_verify_widgets.dart`, `device_verify_api.dart` (the re-export shim, D-DEV-5) — and transitively `lib/api/device_verify_api.dart`.
- Tests: `test/device_verify_api_test.dart` (D-DEV-1 pins `{user_code, approve}` / `?check=` — no `client_id` ever added to the device wire); all pre-existing tests in `test/entry_ux_test.dart` outside the REQ-1 group.
- No `auth.login.success` emission code anywhere (`grep` exit 1 today, §1).

---

## 4. Compatibility constraints

1. **Zero module diff**: no `lib/screens/device/**` file appears in the change set (REQ-5). The branch decision and constant land in the sibling change sets; this lens consumes them at drill time only.
2. **The device wire stays `client_id`-free**: POST `/device/verify` body remains `{user_code, approve}` and the check GET `?check=…` only (D-DEV-1); the module cannot and must not attribute auth events itself. The value enters the device-entry login only through `app_router.dart:35` at drill time.
3. **URL-construction contract**: REQ-1 pins `path == '/login/'` + `redirect` query only — never scheme/host (VM `baseUri` is `AppSettings`-dependent, `product_api_origin.dart:20`). The `user_code` null branch (`:174-177`) is pinned separately.
4. **Session determinism in the REQ-1 group**: `accessTokenProvider: () => null` falls through to `Session.read()` (D-DEV-2); `SessionStorage` is memory-backed on VM (`session_storage_memory.dart`) and the group's `setUp` calls `Session.clear()` + `BrowserNavigation.resetForTest()` — both established test patterns (`setup_screen_test.dart:13`).
5. **No-forgery invariant (REQ-4)**: zero `AuditLogService`/`audit_log_service`/`sso_audit_log` references in `lib/screens/device/` + `test/device_verify_api_test.dart` + `test/entry_ux_test.dart` (D-DEV-6, grep-guarded); the drill reads only `GET /api/v1/audit/events` and never the localStorage ring (`audit_log_service.dart:66`); a ring-only row is not evidence.
6. **Shared-artifact naming**: `SSOAdminClient.firstPartyClientId`, `tests/integration/audit_login_drill.py`, and the `[RESOLVED]` record are the same artifacts the sibling specs name — one change set across all lenses. `audit_login_drill.py` is an **existing untracked artifact adopted and committed here** (D-DEV-3 — already wired at `run_all.py:169` / `full_stack_verify.py:113`); `test/client_id_contract_test.dart` is **new** (D-DEV-4), created by the sibling `lib/api`/`lib/screens` change sets.
7. **Harness semantics**: drill SKIP (exit 0) without live stack/credentials (D6); `run_all.py --ci` skips Gate 5 and therefore the drill — same as `e2e_runner.py` (documented, accepted); `api_login_e2e.py` stays unregistered (conventions reference only).
8. **Filesize gate**: `engineering.yaml:11` `max_lines: 400` applies to `.py`; drill budget ≤ 280 lines (reference `api_login_e2e.py` = 166). The widget-test file is exempt (`_test.dart` in `ignore_patterns`) but stays tidy.
9. **External constraint**: the IdP client registry is outside this repo; the drill (REQ-3) and the shared DCR leg are the only in-repo-adjacent evidence channels and feed REQ-0. `test_config.py:43-44`'s `SNAPLINK_TEST_CLIENT_ID` default changes only under Branch A (sibling change set, `test_config.py:44`).
10. **B6-1 joint**: server-read timeline rendering is B6-1's change set; this lens only guarantees the row exists server-side (drill) and the module cannot forge it (grep guard). Landing order: REQ-1 (module-owned, unconditional) → drill → B6-1 joint test.

---

## 5. Failure modes

| # | Mode | Detection | Mitigation / rollback |
|---|---|---|---|
| F1 | Redirect leg changes shape (path, `redirect` key, `user_code` branch) | REQ-1 widget tests red | The pin is the module's standing regression floor; fix or deliberately re-spec the leg (spec change, not code-only). Rollback of this lens = revert the test group only. |
| F2 | Branch value mismatch at drill time (deployed IdP attributes a different `client_id`) | Drill step 1 or 3 FAIL with output recorded | Contract evidence for REQ-0: attach output to `[RESOLVED]`, re-examine the branch choice; **no code change** — rollback = current state. Never papered over. |
| F3 | Sink-side emission unverifiable (no deployed stack / no emission) | Drill steps 4-5 cannot assert | D7 `[proposed]` fallback — log instead of asserting; no false PASS; the contract row keeps its T-12 joint status with the `[proposed]` note recorded. |
| F4 | Sibling Branch A rename reaches module files or device tests | `git diff --stat lib/screens/device/` or `git diff test/device_verify_api_test.dart` non-empty | REQ-5 guards are acceptance checks; the rename is enumerated in the sibling change set, never pattern-based. |
| F5 | Widget-test flakiness on the redirect (post-frame callback) | Intermittent REQ-1 failures | `pumpAndSettle()` after `addPostFrameCallback` (`:76`); `resetForTest()` + `Session.clear()` in `setUp` (D4/D-DEV-2); stub records synchronously → deterministic. |
| F6 | Host-dependent assertion sneaks in | REQ-1 test asserts scheme/host | Prohibited by REQ-1; code review + the two assertions are path/query-only by construction. |
| F7 | Drill FAIL at sink legs (no row / duplicates / wrong claim) | Drill exit 1 with query output | Attach FAIL output to `[RESOLVED]`; do **not** close the record; defer to B4-5 (gate row owner). No code revert needed. |
| F8 | Sink row lacks a `client_id` claim (external schema) | Step 4 FAIL on missing field | Recorded as a documented contract deviation; D7 `[proposed]` fallback applies. |
| F9 | `tenant_id` claim missing from the login JWT | Step 3 FAIL | Record the B4-1 dependency; the drill does not implement claim parsing — by design. |
| F10 | Sink read API rejects `event_types`/`tenant_id` query params | Step 4 4xx | FAIL is contract evidence for B4-5; no existing test uses these params (verified) — first consumer; the drill does not adapt. |
| F11 | Event-ingestion lag produces a transient "no row yet" | Step 4/5 count assertions fail transiently | Settle interval `max(10, SNAPLINK_DRILL_SETTLE_SECONDS)`s + count-unchanged re-query (step 5); env knob documented in the drill header. |
| F12 | Harness false-fail without a live stack | Drill exit 1 in a dev-only environment | D6 SKIP semantics: missing credentials → exit 0 with `SKIP:` line. |
| F13 | Drill grows past 400 lines | `python3 cli.py check-filesize` red | Budget ≤ 280 lines; extract shared helpers into a sibling `tests/integration/` module only if needed. |
| F14 | Stale `app_router.dart:55` citation resurrected in other docs | `grep -rn "app_router.dart:55" docs/` hits | Fixed once at §3.4; verified no other doc carries it today. |
| F15 | Harness wiring placed before the proxy is up | Drill connection-refused FAIL in `run_all.py`/`full_stack_verify.py` | Placement pinned after `e2e_runner.py` (`run_all.py:164-166`) / after Detail API (`full_stack_verify.py:107-109`); SKIP covers missing stack, not a live stack with a dead proxy — wiring order is the guard. |
| F16 | `SNAPLINK_DRILL_SETTLE_SECONDS` unset/negative | `max(10, …)` floor keeps the settle ≥ 10 s | Env knob parsed with a floor; documented in the drill header. |
| F17 | `Session.read()` throws in the REQ-1 group (future storage swap) | REQ-1 tests red with a storage exception | D-DEV-2 is recorded in the test comment; if `SessionStorage` ever becomes channel-backed on VM, the group's `Session.clear()` + provider-null form still works as long as `read()` returns null; otherwise revisit the provider form — do not assert on `Session` internals. |
| F18 | B6-1 joint rendering lands without the server-side row | T-12 joint test red in the B6-1 change set | This lens's guarantee is only: row exists server-side (REQ-3) + module cannot forge it (REQ-4); the rendering test lives in B6-1's change set, gated on this drill's evidence. |

---

## 6. Migration steps (each leaves the tree green; no data migration)

Ordering is branch-neutral until M3; the branch decision lands in the **sibling** change set as one atomic commit (value flip + mirrors must not straddle commits — the sibling grep guards would be red in CI). This lens contributes M4 (REQ-1 group), M5 (drill) and the REQ-0 closure evidence.

1. **M1 — REQ-1 widget-test group (branch-neutral, module-owned)**: add the group to `test/entry_ux_test.dart` (§3.1). Tree green immediately — the pin asserts URL construction only (D2), which holds under both branches.
2. **M2 — REQ-0 evidence (no code)**: operator runs the drill precondition (step 1) against the deployed IdP registry (`console` vs `sso-admin-console` vs neither); records the branch choice in the run's `DECISIONS.md`. Tree untouched.
3. **M3 — sibling mechanism lands (branch-neutral)**: `SSOAdminClient.firstPartyClientId` + wiring + constantized tests land in the sibling change sets; this lens verifies its REQ-5 diff guard stays green (module untouched).
4. **M4 — branch decision commit (sibling, atomic; REQ-0)**: value flip/mirrors + `test/client_id_contract_test.dart` (screens lens, both branches; D-DEV-4) + `[RESOLVED]` record closure (`audit-contract-batch-snaplink-console.md:12`, stale `:55` → `:35` fixed); **Branch B: no gate amendment (no-op — gate:57 already records `sso-admin-console`)**. This lens: zero diff; module suites green.
5. **M5 — drill (branch-neutral; `AGREED_CLIENT_ID` mirrors M4's value)**: **adopt** the existing untracked `tests/integration/audit_login_drill.py` (§3.2 — verify shape, do not recreate) and **commit** its already-present wiring (`run_all.py:169`, `full_stack_verify.py:113` — uncommitted diffs, §3.3). `git add` file + wiring diffs **first**: the premise is `git clean`-fragile (D-DEV-3). May fold into M4 for a single review or stay separate; grep-verifiable either way.
6. **M6 — gates (REQ-1/REQ-2/REQ-4/REQ-5)**: `flutter test test/entry_ux_test.dart test/device_verify_api_test.dart`; `python3 cli.py check-filesize`; the §7 grep guards; `git diff --stat lib/screens/device/` empty; `git diff test/device_verify_api_test.dart` empty; `git diff test/entry_ux_test.dart` contains only the REQ-1 group.
7. **M7 — deploy + drill execution (REQ-3)**: deploy the aligned constant to the T-12/G7 environment, run `python3 tests/integration/audit_login_drill.py`; append PASS/FAIL output + sink query result to the `[RESOLVED]` record (§3.4).

**Rollback**: revert M5 (delete the drill + 2 harness wiring lines) and/or M1 (drop the test group) — total and immediate. M2-M4/M6-M7 involve zero module code, so this lens has no other rollback surface; a wrong branch choice is reverted in the sibling change set (one-line constant flip + mirrors), after which the `[RESOLVED]` record is re-opened.

---

## 7. Testable acceptance mapping

| Supplied check (spec §4) | Testable form | Command / artifact |
|---|---|---|
| AC-1 — contract constant authoritative: `defaultClientId` + `sso_client.dart` default → `'console'`, `sso_client_test.dart:18` → `'console'`, plus the `entry_ux_test.dart` widget test asserting the redirect target carries `redirect=/device/verify` | REQ-0 + REQ-1: `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` names Branch A with drill evidence; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits (stale `:55` gone); Branch A rename pinned by the sibling-owned `flutter test test/sso_client_test.dart` green with `:18` asserting `'client_id': SSOAdminClient.firstPartyClientId` (resolves `'console'`); module-owned: `grep -n "'/login/'" test/entry_ux_test.dart` and `grep -n "'/device/verify'" test/entry_ux_test.dart` hit in the new widget-test group, and `flutter test test/entry_ux_test.dart` green | grep commands; `flutter test test/entry_ux_test.dart`; `flutter test test/sso_client_test.dart` (sibling suite) |
| AC-2 — `'sso-admin-console'` authoritative: already-recorded exception + end-to-end pin | REQ-0 Branch B: `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (already records the exception — verify-only `:57`); the sibling `test/client_id_contract_test.dart` (new artifact, D-DEV-4) pins the `_effectiveClientId` chain (`oidc_login_screen.dart:159-161`) end-to-end; REQ-1's widget pin is branch-independent and still green | grep commands; sibling `flutter test test/client_id_contract_test.dart` |
| AC-3 — drill logs in through the device redirect leg; deployed sink shows exactly one `auth.login.success` row with the aligned `client_id`; B6-1 timeline renders it without local forgery | REQ-3 + REQ-4: `python3 tests/integration/audit_login_drill.py` against the deployed stack — step 1 `CONFIG.client_id == AGREED_CLIENT_ID`; step 2 redirect-leg shape asserted (login URL built by the `device_verify_screen.dart:174-180` rule, `redirect=/device/verify`); step 3 `POST {PROXY}/auth/login` with the agreed `client_id` returns `access_token` + JWT `tenant_id`; steps 4-5 `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` → exactly one row with the agreed `client_id` claim; second login → 2 rows, no duplicate event id/trace_id, settle ≥ 10 s, count stable; sink legs `[proposed]`-marked when unverifiable (no false PASS, D7); exit 0 only on PASS/SKIP; `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` hits (already wired in the working tree; kept green through M5's commit — D-DEV-3); `grep -rn "AuditLogService\|sso_audit_log" lib/screens/device/ test/device_verify_api_test.dart test/entry_ux_test.dart` → exit 1; `grep -n "audit/events" tests/integration/audit_login_drill.py` hits and `grep -n "sso_audit_log" tests/integration/audit_login_drill.py` → exit 1 (server route only); the joint T-12 server-rendering of that row is B6-1's change set (dependency recorded in §8) | `python3 tests/integration/audit_login_drill.py`; grep guards |
| REQ-1 (both) — redirect-leg regression pin present and green | `grep -n "'/login/'" test/entry_ux_test.dart` and `grep -n "'/device/verify'" test/entry_ux_test.dart` both hit inside the new group (both `user_code` branches); `flutter test test/entry_ux_test.dart` green; `flutter test test/device_verify_api_test.dart` unchanged and green | grep + `flutter test` |
| REQ-2 (both) — device wire stays `client_id`-free, zero emission code | `grep -n "client_id" test/device_verify_api_test.dart` → exit 1; `grep -rn "auth.login.success" lib/screens/device/` → exit 1 (repo-wide 0 hits today, §1) | grep guards |
| REQ-5 (both) — zero-delta boundaries | `flutter test test/entry_ux_test.dart test/device_verify_api_test.dart` green; `git diff --stat lib/screens/device/` empty; `git diff test/device_verify_api_test.dart` empty; `git diff test/entry_ux_test.dart` contains only the REQ-1 group | `flutter test …`; `git diff` guards |

Gate relationship preserved from the spec: AC-1/AC-2 are mutually exclusive (the recorded decision picks one); REQ-1's widget pin is unconditional and gates neither — it is the module's standing regression floor. AC-3 is the T-12/G7 joint acceptance and depends on the decision (the drill asserts the branch's agreed value); its B6-1 rendering half is a dependency, not a change here. All three are executable as written.

---

## 8. Out of scope (unchanged)

Sink/IdP client registry state (external; REQ-0 evidence channel only); the login-wire value change and its pins (`sso_client.dart:86`, `app_router.dart:35`, `sso_client_test.dart:18`, `test_config.py:44`, `DEPLOY.md:29`, `test/client_id_contract_test.dart` — sibling `lib/api`/`lib/screens` change sets, D-DEV-4); `auth.login.success` emission (no such code exists — 0 grep hits); post-login redirect continuation (`_safeRedirectTarget` at `oidc_login_screen.dart:71-80`, `HostedLoginRoute` — screens-lens territory); B6-1/B6-1a server-read timeline rendering (dependency, its own change set); B4-1 (tenant claim parsing — drill dependency only, declared not implemented); B4-5 (drill gate row owner); BFF trace injection; any `lib/screens/device/**` production or test file (zero diff, REQ-5); `lib/i18n` catalog (zero delta).
