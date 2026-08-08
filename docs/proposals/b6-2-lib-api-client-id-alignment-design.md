# B6-2 Design — Resolve `client_id` contract mismatch + `auth.login.success` end-to-end verification drill

Module: `lib/i18n` (assigned analysis bucket; **zero i18n delta** — see §4.7) · Direction: B6-2 · Status: design
Design for the approved requirements spec `docs/proposals/b6-2-lib-api-client-id-alignment-spec.md` (REQ-0 … REQ-5, AC-1 … AC-3).
Supersedes the prior `b6-2-lib-api-client-id-alignment-design.md` draft (which was aligned to the superseded spec's AC-1…AC-4 and the runbook deliverable; the new spec replaces AC-4 with the REQ-5 regression gate and REQ-4 with a checked-in runnable drill file).

This design is **branch-parametric** (REQ-0): Branch A (rename to `console`, contract authoritative) vs Branch B (contract exception already recorded at `implementation-gate.md:57`: `sso-admin-console`, repo value authoritative) differ in exactly one constant value plus the sites that mirror it. Every other element is branch-neutral.

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

All citations in the requirements evidence were re-checked against the repository. **Every factual claim holds** with four non-material line drifts and **one material citation defect** corrected below:

| Evidence claim | Verification result |
|---|---|
| `lib/api/sso_client.dart:86` — `login` default `clientId = 'sso-admin-console'`; `:92` `'client_id': clientId` in POST `/auth/login` body (`:88-94` shape: provider/scope/resource/credential) | ✅ exact |
| `lib/app_router.dart:35` — `defaultClientId: 'sso-admin-console'` | ✅ exact |
| `lib/screens/oidc_login/federated_login.dart:119,203` — `'client_id'` in `/auth/login` discovery query + `/token` exchange body | ✅ exact |
| `lib/screens/oidc_login/oidc_authorization_flow.dart:238,295,370` — `payload['client_id'] = _effectiveClientId` | ✅ exact |
| `test/sso_client_test.dart:18` — whole-body assertion incl. `'client_id': 'sso-admin-console'` | ✅ exact |
| Census: 2 prod sites + 5 Dart test sites (`sso_client_test.dart:18` + `oidc_account_flow_test.dart:35,75,115,160`) + `tests/integration/test_config.py:44` + `tests/integration/README.md:17` | ✅ exact — 9 code/doc sites; plus `docs/proposals/audit-contract-batch-snaplink-console.md:12` (`[MISMATCH]`), `docs/campaigns/implementation-gate.md:57` (contract row `client_id=sso-admin-console`), `DEPLOY.md:29` (IdP registry reference, unchanged by either branch) |
| `docs/campaigns/implementation-gate.md:57` row 2: login → `auth.login.success`（client_id=sso-admin-console）| sink 出现 sso-admin-console login 事件；无重复 | B4-5 | ✅ exact — the contract authority (quote corrected: the gate records `sso-admin-console`) |
| `docs/proposals/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` with **stale inner citation** `app_router.dart:55` (actual `:35`) | ✅ exact |
| No `auth.login.success` emission path: `audit_log_service.dart:66` (`_storageKey = 'sso_audit_log'` localStorage ring), `event_bus.dart:40-45` (`DataChangedEvent` UI-local); grep `auth.login.success` in `lib/` `test/` `tests/` → 0 hits | ✅ confirmed |
| No central constant exists (`firstPartyClientId` → 0 hits; only `nativeDefaultBaseUrl` at `sso_client.dart:76`) | ✅ confirmed |
| `_effectiveClientId` fallback chain: `oidc_login_screen.dart:159-161` (`_params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '')`), ctor `:54` `final String? defaultClientId` | ✅ exact |
| Chain → `oidc_provider_flow.dart:54` (`'client_id': _effectiveClientId` in login POST) → `oidc_login_api.dart:52` (`'client_id': clientId`, no default of its own; exactly **1** `client_id` occurrence in file) | ✅ exact for `:54` and `:52` |
| Chain → `oidc_provider_flow.dart:87` (spec: "probeProviders") | ❌ **MIS-CITED**: `:87` is `clientId: _effectiveClientId` in `Session.store(...)`. The probe is `_probeProviders()` at `oidc_provider_flow.dart:152-154` → `_api.probeProviders(_effectiveClientId, …)` (`:154`), invoked from `oidc_login_screen.dart:222` (part-file library, `part 'oidc_provider_flow.dart'` at `:34`). Corrected chain for REQ-3: `oidc_login_screen.dart:159-161` → `:222`/`oidc_provider_flow.dart:152-154` → `oidc_login_api.dart:50-52`. Materially relevant because REQ-3's probe-body assertion must target the **probe POST**, not the `Session.store` call. |
| Harnesses: `tests/integration/e2e_runner.py`, `full_stack_verify.py` (step 4 starts proxy `:73-99`, step 5 runs integration `:100-108`), `browser_test.py` exist; none completes a login; real logins only at `api_login_e2e.py:59-62` (POST `{PROXY}/auth/login` + JWT decode `:73-77`) and `full_integration_test.py:46` (login) / `:31-33` (`decode_jwt`) | ✅ exact. Canvas limitation at `browser_login_test.py:89` ("Flutter renders to canvas…"), not `:66-67` as the spec cites — **1-line-drift, substance holds** |
| Sink smoke test `full_integration_test.py:151` (`GET /api/v1/audit/events`, status < 500) | ⚠️ actual line `:150` — 1-line drift, immaterial |
| `run_all.py:121-122` (full_integration under Gate 4) and `:164-171` (E2E list: Curl Adversarial `:152`, `e2e_runner.py` `:165-166`, Playwright `:168-171`; Gate 5 gated on `not args.skip_e2e and not args.ci` `:125`) | ⚠️ `run_test('Python Integration Tests', …)` spans `:120-121` — 1-line drift; E2E list `:164-171` exact. `api_login_e2e.py` is **not** registered in `run_all.py` — it is a conventions reference only (as the spec states) |
| `oidc_provider_flow.dart:108-110` guard: `if (_effectiveClientId.isEmpty) { … 'No client is configured for this sign-in.' }` | ✅ exact |
| `test/oidc_account_flow_test.dart:19-20,65-66,99-100,144-145` — `OidcLoginApi(httpClient: MockClient(...))` idiom (REQ-3 reuses verbatim); `defaultClientId` sites `:35,75,115,160` carry no value assertions | ✅ exact |
| `test/native_shell_test.dart:98,147,202` — `defaultClientId: 'native-client'` (negative constraint; must not be touched) | ✅ exact |
| `test/api_contract_test.dart:24,29` — `client_id` in URL path templates only | ✅ exact |
| Dormant `SSOAdminClient.login` default: no production caller (all `.login(` sites are `OidcLoginApi` at `oidc_provider_flow.dart:53`, `oidc_challenge_flow.dart:237`, `oidc_authorization_flow.dart:239,310,376`, or `PortalApi` at `portal_screen.dart:118,210` with `clientId: Session.readClientId()` `:121`; `lib/session.dart:63`); flipping the default has **zero live-wire impact today** | ✅ confirmed — shrinks branch-flip blast radius to `app_router.dart:35` |
| `'console'` literal in `lib/` → 0 hits (Branch A grep guard sound); filesize gate `engineering.yaml:11` `max_lines: 400` covers `.py` (reference: `api_login_e2e.py` = 166 lines); `OidcLoginScreen.initState` → `_probeProviders()` at `:222` | ✅ confirmed |
| `lib/i18n` zero-delta: audit keys `app_strings_source_admin_features.dart:142`, `app_strings_source_admin_core.dart:303`; `test/i18n_coverage_test.dart` exists | ✅ confirmed |

Conclusion: the requirements evidence is reliable. One material correction is adopted into this design (§3.5 — REQ-3 assertion targets the probe POST via the corrected chain `oidc_provider_flow.dart:152-154`), and three stale line refs (`browser_login_test.py:66-67`→`:89`, `full_integration_test.py:151`→`:150`, `run_all.py:121-122`→`:120-121`) are noted for the implement stage.

---

## 2. Design summary

**Files touched (2 production + 5 Dart test + 2 Python test + 1 new drill + 1-2 doc files; no new endpoints, no signature change beyond one default's value source):**

1. `lib/api/sso_client.dart` — add `static const String firstPartyClientId` (single source of truth; value per branch); `login` default references it.
2. `lib/app_router.dart:35` — `defaultClientId: SSOAdminClient.firstPartyClientId` (+ import).
3. `test/sso_client_test.dart:18` — assertion references the constant.
4. `test/oidc_account_flow_test.dart:35,75,115,160` — args reference the constant (value-agnostic; green under both branches).
5. Branch A only: `tests/integration/test_config.py:44` default flip + `tests/integration/README.md:17` doc flip.
6. Branch B only: new `test/client_id_contract_test.dart` — widget test pinning the probe body end-to-end through the corrected chain.
7. Both branches: **adopt** the existing `tests/integration/audit_login_drill.py` — the REQ-4 drill as a checked-in, runnable file (untracked working-tree artifact, 214 lines, steps 1-6, `AGREED_CLIENT_ID` switch); **already wired** at `run_all.py:169` (Gate 5) and `full_stack_verify.py:113` (step 5) by an uncommitted diff. Commit file + wiring; never re-create or re-insert (§3.8).
8. Both branches: `docs/proposals/audit-contract-batch-snaplink-console.md:12` `[MISMATCH]` → `[RESOLVED]` (branch + drill evidence; stale `app_router.dart:55` → `:35` fixed). Branch B verifies `docs/campaigns/implementation-gate.md:57` row 2 (no amendment needed — it already records `client_id=sso-admin-console`).

**Key decisions:**

- **D1 — Constant lives in `SSOAdminClient`** (spec REQ-1): Dart requires default parameter values to be compile-time constants, so once `login`'s default reads `firstPartyClientId`, the compiler makes re-forking impossible for that site. The `app_router.dart:35` wiring is the residual risk, covered by the REQ-1/REQ-2 grep guards.
- **D2 — Branch choice is an evidence gate, not a code fork** (REQ-0): the branches differ in exactly 3 code tokens (constant value, 2 Python co-site values under A, 1 new test file under B) + 1-2 doc records. The mechanism (constant + wiring + constantized tests + drill) is branch-neutral and lands first; the value lands as a single atomic decision commit.
- **D3 — REQ-3 assertion target is the probe POST** (correction from §1): the probe chain is `oidc_login_screen.dart:159-161` (`_effectiveClientId`) → `:222` / `oidc_provider_flow.dart:152-154` (`_probeProviders` → `_api.probeProviders(_effectiveClientId, …)`) → `oidc_login_api.dart:50-52` (`'client_id': clientId`). The `Session.store` call at `oidc_provider_flow.dart:87` is a session side-effect, not a wire emission — it is **not** an assertion target.
- **D4 — Drill placement is Gate 5, not Gate 4**: REQ-4 logs in via `POST {PROXY}/auth/login`, which requires the proxy. `run_all.py` starts the proxy only in Gate 5 (`:128-150`), which is exactly the E2E list site (`:164-171`) the spec names; Gate 4 (full_integration, `:120-121`) has no proxy and must not host the drill. `full_stack_verify.py` starts the proxy at step 4 (`:73-99`), so the drill lands at the end of step 5 (`:108`). In `run_all.py --ci` mode Gate 5 is skipped by design (same as `e2e_runner.py`/browser tests) — documented, not a defect.
- **D5 — Drill SKIP semantics**: the drill exits 0 with a `SKIP:` line when credentials are unconfigured (mirroring `api_login_e2e.py:33-36`) so `run_all.py`/`full_stack_verify.py` don't false-fail in dev environments without a live stack; FAIL (exit 1) is reserved for genuine contract violations.
- **D6 — Grep guards are the fork-prevention** (REQ-1/REQ-2): verified `'console'` has 0 other hits in `lib/` and `'sso-admin-console'` has exactly the 9 census sites, so both branches' guards are sound and CI-able.

---

## 3. API changes (concrete)

### 3.1 `lib/api/sso_client.dart` (REQ-1, both branches)

Add next to the existing `nativeDefaultBaseUrl` constant (`:76`):

```dart
/// First-party OAuth client id this console presents to the IdP.
///
/// Single source of truth for the `client_id` sent on `/auth/login`.
/// Branch A (contract authoritative): 'console'.
/// Branch B (repo value authoritative): 'sso-admin-console'.
static const String firstPartyClientId = 'console'; // or 'sso-admin-console'
```

Change the `login` default (`:86`):

```dart
String clientId = firstPartyClientId,
```

No other change to `login`: the body map (`:88-94` — provider, client_id, scope, conditional resource, credential) stays byte-identical; the method signature `(String username, String password, {String clientId, List<String>? resources})` is unchanged.

### 3.2 `lib/app_router.dart` (REQ-1, both branches)

Add `import 'api/sso_client.dart';` after the existing `import 'api/oidc_login_api.dart';` (`:2`). Change `:35`:

```dart
defaultClientId: SSOAdminClient.firstPartyClientId,
```

`OidcLoginScreen.defaultClientId` stays `String?` with identical fallback semantics (`oidc_login_screen.dart:159-161`).

### 3.3 `test/sso_client_test.dart:18` (REQ-1, both; value flip under A)

```dart
'client_id': SSOAdminClient.firstPartyClientId,
```

Under Branch B the wire value is unchanged; under Branch A this is the mandated assertion flip. Either way, no literal.

### 3.4 `test/oidc_account_flow_test.dart:35,75,115,160` (REQ-1, both)

Replace each `defaultClientId: 'sso-admin-console',` with `defaultClientId: SSOAdminClient.firstPartyClientId,`. These tests assert no `client_id` value (forgot-password/signup/verify-email flows), so they are green under both branches at every migration step. **Do not touch** `test/native_shell_test.dart:98,147,202` (`'native-client'` — a distinct value on the same parameter, negative constraint).

### 3.5 `test/client_id_contract_test.dart` (new; REQ-3, Branch B only)

Widget test reusing the in-repo MockClient idiom (`oidc_account_flow_test.dart:19-20,27-29`), asserting the **probe POST body** through the corrected chain (§1, D3):

```dart
testWidgets('probe carries the aligned first-party client id', (tester) async {
  Map<String, dynamic>? probeBody;
  final api = OidcLoginApi(
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/login') {
        probeBody = jsonDecode(request.body) as Map<String, dynamic>;
      }
      return http.Response('{}', 404); // non-probe routes: proven-safe graceful 404
    }),
  );
  tester.view.physicalSize = const Size(900, 1600); // oidc_account_flow_test.dart:27-29 idiom
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: OidcLoginScreen(
      api: api,
      defaultClientId: SSOAdminClient.firstPartyClientId,
      routeUri: Uri.parse('https://sso.example/login/'),
    ),
  ));
  await tester.pumpAndSettle();
  expect(probeBody, isNotNull);
  expect(probeBody!['client_id'], SSOAdminClient.firstPartyClientId);
});
```

The probe fires from `initState` (`oidc_login_screen.dart:222`) with no `client_id` query param on `routeUri`, so `_effectiveClientId` resolves through the fallback to `widget.defaultClientId` (`:159-161`). Mutation of the constant makes the test red (compile-time for `lib/` callers, runtime for this assertion).

### 3.6 Branch A co-sites (REQ-2, Python)

- `tests/integration/test_config.py:44`: `'SNAPLINK_TEST_CLIENT_ID', 'console'`.
- `tests/integration/README.md:17`: document the new default (`console`).

Branch B: both keep `'sso-admin-console'` — no change.

### 3.7 Doc records (REQ-0, both branches)

`docs/proposals/audit-contract-batch-snaplink-console.md:12` — replace the `[MISMATCH]` record:

```markdown
- `[RESOLVED]`（B6-2, <date>）：Branch <A|B> chosen per drill evidence
  (<drill output attached>); code aligned on
  `SSOAdminClient.firstPartyClientId` (`app_router.dart:35`,
  `sso_client.dart:86`, `sso_client_test.dart:18` — citation corrected
  from the stale `:55`)
```

Branch B additionally **verifies** `docs/campaigns/implementation-gate.md:57` row 2 — **no amendment required**: the gate already records `client_id=sso-admin-console` with acceptance "sink 出现 sso-admin-console login 事件；无重复" (the earlier "amend the gate" narrative was based on a misquote; the described amendment is a no-op against the real text). Gate edit count under Branch B: zero.

### 3.8 `tests/integration/audit_login_drill.py` (existing untracked — adopt; REQ-4, both branches)

Checked-in runnable file, **not** a runbook pointer. Structure (budget ≤ 280 lines; filesize gate `engineering.yaml:11` = 400, reference `api_login_e2e.py` = 166):

```
header docstring: purpose, branch value, usage, and the canvas limitation
  (browser_login_test.py:89) as the reason the login step is API-driven
  through the proxy — the same wire path the console UI drives.
AGREED_CLIENT_ID = <'console' | 'sso-admin-console'>   # branch value, one line
helpers: check(label, ok, detail) / curl(method, url, data, headers)
  (conventions from api_login_e2e.py:17-29), decode_jwt (full_integration_test.py:29-33)
SKIP: if CONFIG.require_credentials() raises IntegrationConfigurationError → print SKIP, exit 0
Step 1 (REQ-0 evidence):  assert CONFIG.client_id == AGREED_CLIENT_ID
                          (else FAIL: "IdP registry evidence missing / branch mismatch")
Step 2 (login):           POST {CONFIG.proxy_url}/auth/login with CONFIG.login_payload()
                          assert access_token; decode JWT; extract tenant_id claim → <t>
                          missing claim → FAIL recording the B4-1 dependency (no parsing impl)
Step 3 (sink query):      GET {CONFIG.api_url}/api/v1/audit/events
                            ?event_types=auth.login.success&tenant_id=<t>
                          with Bearer token; assert exactly one row;
                          assert row client_id claim == AGREED_CLIENT_ID
                          (any other value = documented contract deviation → FAIL)
Step 4 (idempotency):     second login; re-query; assert exactly 2 rows total,
                          no repeated event id/trace_id;
                          sleep max(10, SNAPLINK_DRILL_SETTLE_SECONDS)s; re-query;
                          assert count unchanged
Step 5 (report):          PASS/FAIL summary; exit 0 on PASS, 1 on FAIL
```

Exit-code contract: 0 = PASS or SKIP (no live stack/creds), 1 = FAIL. This keeps `run_all.py`/`full_stack_verify.py` honest without false failures in dev (D5).

### 3.9 Harness wiring (REQ-4, both branches)

- `tests/integration/run_all.py` — **already wired at `:169`** (inside Gate 5, after `run_e2e_test('Python E2E Runner', …)` — the `:165-166` insertion point is where the live entry sits); uncommitted diff; verify, do not re-insert:
  ```python
  run_e2e_test('B6-2 Login Drill (client_id contract)',
               ['python3', 'tests/integration/audit_login_drill.py'], timeout=300)
  ```
- `tests/integration/full_stack_verify.py` — **already wired at `:113`** (end of step 5, after Detail API — the `:108` insertion point is where the live entry sits); uncommitted diff; verify, do not re-insert:
  ```python
  step('B6-2 Login Drill (client_id contract)',
       ['python3', 'tests/integration/audit_login_drill.py'], 300)
  ```

---

## 4. Compatibility constraints

1. **Wire/API surface**: `/auth/login` method, path, and every body key except the `client_id` *value* are unchanged (REQ-5). `SSOAdminClient.login` keeps its exact signature; only the default's value source changes.
2. **Dart compile-time const default**: `clientId = firstPartyClientId` is legal only because the constant is `static const`; any future non-const change is a compile error, not a silent drift — the regression-proofing property REQ-1 buys for the `login` site. The `app_router.dart:35` wiring is plain Dart and needs the grep guard (D6).
3. **Dormant default**: no production caller of `SSOAdminClient.login` omits `clientId` (§1). The flip cannot alter any live request through that class; the only live path is `app_router.dart:35` → `OidcLoginScreen` → `OidcLoginApi`. Under Branch A that is the branch-gated behavior change; under Branch B the wire value is identical to today.
4. **IdP registry is the real constraint** (REQ-0): `console` registered → Branch A; `sso-admin-console` registered → Branch B; neither → no branch merges (drill FAIL → no code change). External to this repo; drill step 1 + operator evidence is the only channel.
5. **Untouched**: `OidcLoginScreen.defaultClientId` (`String?`, same fallback); `'native-client'` sites (`native_shell_test.dart:98,147,202`); `PortalApi.login`'s `Session.readClientId()` source (`lib/session.dart:63`, `portal_screen.dart:121`); `api_contract_test.dart` URL templates; `federated_login.dart` and `oidc_authorization_flow.dart` sites (they consume `_effectiveClientId` — no literal, no change needed); `docs/campaigns/implementation-gate.md` **under Branch B** (already records the Branch-B value — no-op); **under Branch A row 2 flips to `client_id=console`** (the gate records the shipped value).
6. **Zero-delta boundaries** (REQ-5): no `lib/i18n/` changes (audit keys at `app_strings_source_admin_features.dart:142`, `app_strings_source_admin_core.dart:303` stay; `test/i18n_coverage_test.dart` green by construction); no new endpoints; no emission code anywhere in `lib/`.
7. **Filesize gate**: `engineering.yaml:11` `max_lines: 400` applies to `.py` (the `_test.dart` ignore pattern does not cover Python). The drill is budgeted ≤ 280 lines (reference: `api_login_e2e.py` = 166).
8. **Harness semantics**: the drill must SKIP (exit 0) without live stack/credentials so `run_all.py`/`full_stack_verify.py` don't false-fail; `run_all.py --ci` skips Gate 5 and therefore the drill — same as `e2e_runner.py` (documented, accepted).
9. **REQ-3 probe chain correction**: the assertion targets the probe POST (`oidc_provider_flow.dart:152-154` → `oidc_login_api.dart:50-52`), **not** the `Session.store` call at `oidc_provider_flow.dart:87`. Implementers must not "fix" `:87` — it is a session side-effect and correct as-is.
10. **Widget-test idiom**: `tester.view.physicalSize`/`devicePixelRatio` + `addTearDown(tester.view.reset)` (`oidc_account_flow_test.dart:27-29`) and `pumpAndSettle` after pump; MockClient responds synchronously so probe timing cannot flake.

---

## 5. Failure modes

| # | Mode | Detection | Mitigation / rollback |
|---|---|---|---|
| F1 | Wrong branch chosen (drill evidence misread; IdP registry later changes) | Post-deploy login 401/`invalid_client` on `/auth/login`; sink row missing | One-line constant flip + mirrors in the same change set; re-open `[RESOLVED]`. No data/schema/transport migration exists. |
| F2 | IdP registers neither id | Drill step 1/2 FAIL (no registered client; login rejected) | REQ-0 cannot conclude → do not merge the value commit; land only the branch-neutral mechanism or nothing. Rollback = current state. |
| F3 | Constant forks again (fresh literal re-inlined) | Branch A: `grep -rn "sso-admin-console" lib test tests/integration` hits; Branch B: literal outside the constant site | REQ-1/REQ-2 grep guards are acceptance checks, CI-able. Compile-time const default makes the `login` fork impossible; `app_router` wiring is the residual risk covered by grep. |
| F4 | Blanket find/replace hits `'native-client'` sites | `flutter test test/native_shell_test.dart` red | Negative constraint (§4.5); the §3.4 edits are enumerated, never pattern-based. |
| F5 | REQ-3 widget test flake (probe timing / overflow) | Intermittent red | `pumpAndSettle` + synchronous MockClient (proven at `oidc_account_flow_test.dart:19-66`); viewport idiom §4.10. |
| F6 | Drill FAIL at steps 3-4 (no sink row / duplicate rows / wrong claim) | Drill exit 1 with query output | Attach FAIL output to `[RESOLVED]`; do **not** close the record as resolved; defer to B4-5 drill owner (gate row 2). No code revert needed. |
| F7 | `tenant_id` claim missing from login JWT | Drill step 2 FAIL | Record the B4-1 dependency in the output (REQ-4 step 2); the drill does not implement claim parsing — by design. |
| F8 | Sink read API rejects `event_types`/`tenant_id` query params | Drill step 3 4xx | FAIL is contract evidence for B4-5; the drill does not adapt. No existing test uses these params (verified §1) — first consumer. |
| F9 | Event-ingestion lag produces false "no row yet" | Drill step 3/4 count assertions fail transiently | Settle interval `max(10, SNAPLINK_DRILL_SETTLE_SECONDS)`s + re-query count-unchanged assertion; env knob documented in the drill header. |
| F10 | `defaultClientId` nulled at the login route by future rewiring | `_effectiveClientId` → `''`; `oidc_provider_flow.dart:108-110` surfaces "No client is configured" | Guard already exists; REQ-3 test (Branch B) / `sso_client_test` + grep (Branch A) is the pin template for any rewiring. |
| F11 | Drill grows past 400 lines | `python3 cli.py check-filesize` red | Budget ≤ 280 lines; extract shared helpers into a sibling module only if needed (stays in `tests/integration/`). |
| F12 | Stale `app_router.dart:55` citation resurrected in other docs | `grep -rn "app_router.dart:55" docs/` | Fixed once at §3.7; verified no other doc carries it today. |
| F13 | `run_all.py`/`full_stack_verify.py` false-fail without live stack | Drill exit 1 in a dev-only environment | SKIP semantics (§3.8, D5): missing credentials → exit 0 with `SKIP:` line. |

---

## 6. Migration steps (each leaves the tree green; no data migration)

Ordering is branch-neutral until M3; the branch decision lands as **one atomic commit** (the value flip and its mirrors must not straddle commits — the grep guards would be red in CI).

1. **M1 — REQ-0 evidence (no code)**: operator runs drill step 1 precondition against the deployed IdP registry (`console` vs `sso-admin-console` vs neither); records the branch choice in the run's `DECISIONS.md` (pipeline `decision_log`). No code change; tree untouched.
2. **M2 — REQ-1 mechanism (branch-neutral, green under both)**: add `firstPartyClientId` to `lib/api/sso_client.dart` (value = current literal `'sso-admin-console'`), point `login`'s default at it, point `app_router.dart:35` at it (new import); constantize `test/sso_client_test.dart:18` and `test/oidc_account_flow_test.dart:35,75,115,160` to the constant. Wire values unchanged → full `flutter test` green.
3. **M3 — branch decision commit (atomic; REQ-2/REQ-3/REQ-0)**: under **Branch A** flip the constant to `'console'` **and** flip `tests/integration/test_config.py:44` + `tests/integration/README.md:17` in the same commit (REQ-2 guard covers `tests/integration`); under **Branch B** keep the value and add `test/client_id_contract_test.dart`. Both: close the `[MISMATCH]` record at `audit-contract-batch-snaplink-console.md:12` with branch + drill evidence and fix `:55` → `:35`; Branch B verifies `implementation-gate.md:57` row 2 (no amendment needed — already records `sso-admin-console`). Green: `flutter test` + grep guards (§7).
4. **M4 — REQ-4 drill (branch-neutral mechanics; `AGREED_CLIENT_ID` mirrors M3's value)**: **adopt** the existing untracked `tests/integration/audit_login_drill.py` (§3.8 — verify shape, do not recreate) and **commit** its already-present wiring (`run_all.py:169`, `full_stack_verify.py:113` — uncommitted diffs). `git add` file + wiring diffs **first** (the artifact is `git clean`-fragile — untracked file, uncommitted wiring). May be folded into M3 for a single review, or kept separate for review size; grep-verifiable either way.
5. **M5 — gates (REQ-1/REQ-5)**: `dart format --output=none --set-exit-if-changed lib`, `dart analyze`, `flutter test` (full), `make verify`, `python3 cli.py check-filesize`; repo grep guards per branch (§7); `git diff --stat` shows no `lib/i18n/` files.
6. **M6 — deploy + drill execution (REQ-4)**: build the aligned constant, deploy to the T-12/G7 environment, run `python3 tests/integration/audit_login_drill.py`; append the PASS/FAIL output + sink query result to the `[RESOLVED]` record (§3.7).

**Rollback**: revert M3 (one-line constant flip + mirrors + doc records) or M2+M3 together — full restoration of pre-B6-2 behavior; no data, no schema, no transport change. M4 is inert without M3's value and can stay or be reverted independently.

---

## 7. Testable acceptance mapping

| Supplied check (spec §4) | Testable form | Command / artifact |
|---|---|---|
| AC-1 — T-12 joint drill: complete a console login, query sink `GET /api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>`, assert exactly one row whose `client_id` claim equals the agreed value | REQ-4 steps 1-3: drill exit 0 with PASS lines — (a) `CONFIG.client_id == AGREED_CLIENT_ID`, (b) `access_token` + JWT `tenant_id` claim, (c) exactly one sink row with `client_id` claim == agreed value; drill file present in `tests/integration/` and wired (grep `audit_login_drill` in `run_all.py` + `full_stack_verify.py`); deviation (if any) recorded in `[RESOLVED]` | `python3 tests/integration/audit_login_drill.py`; `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` |
| AC-2 — No duplicates: re-running login yields no duplicated `auth.login.success` rows | REQ-4 step 4: two logins → exactly 2 rows, no repeated event id/trace_id; settle ≥ 10 s; re-query → count unchanged | drill step 4 output lines in the PASS report |
| AC-3 — Decision artifact: contract v2.1 `client_id` either amended to `'sso-admin-console'` or a rename PR lands (`app_router.dart:35` + `sso_client.dart:86` + `sso_client_test.dart:18` together); mismatch documented | REQ-0 + REQ-2/REQ-3: `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` names the branch with evidence; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits (stale `:55` gone). Branch A: `grep -rn "sso-admin-console" lib test tests/integration` → exit 1; `grep -rn "'console'" lib` → exactly the constant site. Branch B: `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits; `flutter test test/client_id_contract_test.dart` green | grep commands above; `flutter test test/client_id_contract_test.dart` (B) |
| REQ-1 (both) — single source of truth | `grep -rn "sso-admin-console" lib/ --include="*.dart"` → exactly the constant site (B) / 0 hits (A); `grep -rn "'console'" lib/ --include="*.dart"` → exactly the constant site (A); no test carries a fresh literal | grep guards |
| REQ-2 (A) — rename PR + census co-sites | `flutter test test/sso_client_test.dart test/oidc_account_flow_test.dart` green; zero-literal greps (above) | `flutter test …` |
| REQ-3 (B) — regression pin | `flutter test test/client_id_contract_test.dart` green; constant mutation makes it red | `flutter test test/client_id_contract_test.dart` |
| REQ-4 (both) — checked-in drill | file exists; wired (grep above); `python3 tests/integration/audit_login_drill.py` PASS per AC-1/AC-2; header documents `browser_login_test.py:89` canvas limitation | grep + drill run |
| REQ-5 (both) — no regression / zero-delta | full `flutter test` green; `git diff --stat -- lib/i18n` empty; `SSOAdminClient.login` signature and `/auth/login` body keys unchanged | `flutter test`; `make verify`; `git diff --stat` |

Gate relationship preserved from the spec: AC-1/AC-2 unconditional (the drill asserts the *agreed* value under either branch); AC-3 branch-disjunctive exactly as supplied.

---

## 8. Out of scope (unchanged)

Sink/IdP client registry state (external; REQ-0 evidence channel only); `auth.login.success` emission (no such code exists — 0 grep hits); B6-1a (timeline UI), B4-1 (tenant claim parsing — drill dependency only), B4-5 (drill gate owner); BFF trace injection; any `lib/api` surface change beyond one parameter default's value source; `PortalApi`'s `Session.readClientId()` source; `'native-client'` test sites; `lib/i18n` catalog (zero delta).
