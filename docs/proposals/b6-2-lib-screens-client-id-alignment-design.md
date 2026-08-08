# B6-2 Design — `lib/screens` lens: `client_id` alignment, screens-chain regression pin, T-12 login drill

Module: `lib/screens` (direction `resolve-the-b6-2-login-client-id-mismatch-code-s-ed88f81e`, analysis `docs/auto/analyses/lib-screens-19d4d0ab.json`) · Direction: B6-2 · Status: design
Design for the requirements spec `docs/proposals/b6-2-lib-screens-client-id-alignment-spec.md` (REQ-0 … REQ-5, AC-1 … AC-3).
Sibling instance: `docs/proposals/b6-2-lib-api-client-id-alignment-design.md` (mechanism design). This design owns the **screens-side surface** — the live login wire (`OidcLoginScreen.defaultClientId` → `_effectiveClientId` chain), the screens-chain widget regression, and the drill login leg — and names the **same constant and drill artifact** so the change set stays single.

Branch-parametric (REQ-0): Branch A (rename to `console`, contract authoritative) vs Branch B (contract amendment to `sso-admin-console`, repo value authoritative). They differ in exactly one constant value plus its mirror sites; everything else is branch-neutral.

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

Every claim in the requirements evidence was re-checked line-exact against the repository. **All substantive claims hold.** Six non-material drifts and two cross-instance defects were found and are adopted below:

| Evidence claim | Verification result |
|---|---|
| `lib/api/sso_client.dart:86,92` — `login` default `clientId = 'sso-admin-console'`; `'client_id': clientId` in POST `/auth/login` body (keys `:91-95`) | ✅ exact |
| `test/sso_client_test.dart:18` — whole-body map assertion locking `'client_id': 'sso-admin-console'` | ✅ exact (`:16-22` whole-body map: provider/client_id/scope/resource/credential) |
| `lib/sso_client.dart` — one-line re-export shim | ✅ exact |
| `lib/api/snaplink_admin_event_stream.dart` — consume-only (`open()` `:28` → `Stream<SnaplinkAdminEvent>`; no emitter) | ✅ exact |
| `oidc_login_screen.dart:159-160` — `_effectiveClientId` fallback | ⚠️ **drift**: getter spans `:159-161`; the `widget.defaultClientId ?? ''` fallback is at `:161`. Spec text itself cites `:159-161`; the evidence summary understated by one line. |
| `grep auth.login.success lib/ test/ tests/` → 0 hits | ✅ confirmed (exit 1; no emission code anywhere; `audit_log_service.dart:66` localStorage ring and `event_bus.dart` `DataChangedEvent` are not sink emitters) |
| `app_router.dart:35` — only screens wiring literal (`defaultClientId: 'sso-admin-console'` at `:35`, `ProductEntry.login` arm `:34-37`) | ✅ exact |
| `oidc_provider_flow.dart:54` — `'client_id': _effectiveClientId` in login POST | ✅ exact |
| `oidc_provider_flow.dart:152-154` — probe | ⚠️ **drift**: `_probeProviders()` is defined at `:152`; the `_api.probeProviders(` call spans `:154-156` with the `_effectiveClientId` argument at `:155`; invoked from `oidc_login_screen.dart:222` (initState, part-file `part 'oidc_provider_flow.dart'` at `:34`). Substance holds. |
| `oidc_login_api.dart:47,52` — probe posts `'client_id': clientId` | ⚠️ **path drift**: the real file is **`lib/api/oidc_login_api.dart`** (`probeProviders(String clientId` at `:48`, `'client_id': clientId` at `:52`); `lib/screens/oidc_login/oidc_login_api.dart` is itself a one-line re-export shim. No default of its own — the default enters only via `OidcLoginScreen.defaultClientId`. |
| `federated_login.dart:119,203` — `'client_id': clientId` in `/auth/login` discovery query + `/token` exchange body; `_clientIdKey = 'sso_pkce_client_id'` at `:54` | ✅ exact |
| `oauth_params.dart:59` — `clientId: q['client_id'] ?? ''` URL passthrough | ✅ exact |
| `device_verify_screen.dart:172-181` — `_redirectToLogin()` resolves `/login/` with `redirect` query; funnels into the same `OidcLoginScreen`; no own literal | ✅ exact (grep `client_id|clientId` in `lib/screens/device/` → only `preview['client_id']` at `:62`, a preview model, not a wire literal) |
| `docs/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` with stale inner citation `app_router.dart:55` (actual `:35`) | ✅ exact content; ⚠️ **path drift**: file is `docs/proposals/audit-contract-batch-snaplink-console.md` |
| Census of `sso-admin-console` (2 prod + 5 Dart test + 2 Python/doc sites): `sso_client.dart:86`, `app_router.dart:35`, `sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `test_config.py:44`, `tests/integration/README.md:17` | ✅ exact — 9 sites; `'console'` has **0 hits in `lib/`** (Branch A grep guard sound, re-verified) |
| `docs/campaigns/implementation-gate.md:57` row 2 — `client_id=sso-admin-console` | sink 出现 sso-admin-console login 事件；无重复 | B4-5 | ✅ exact — the contract authority (quote corrected: the gate records `sso-admin-console`, not `console`) |
| Harness facts: `api_login_e2e.py:59-77` real login + JWT decode; `browser_login_test.py:89` canvas note; `test_config.py:43-44` `SNAPLINK_TEST_CLIENT_ID` default; `run_all.py` integration `:121-122` / e2e list `:164-171`; `full_stack_verify.py` `step()` `:15`, integration block `:104-115` | ✅ substance exact (canvas note at `browser_login_test.py:89` "Flutter renders to canvas, so we can't easily find text fields"; SKIP idiom `api_login_e2e.py:28-36`; Gate 5 guard `not args.skip_e2e and not args.ci` at `run_all.py:125`, proxy start `:128-150`, e2e list `:164-171`; `full_stack_verify.py` proxy step 4 `:73-99`, integration steps 5 `:104-108`) |

**Cross-instance defects found (corrected in this design):**

- **D1 — REQ-3 branch scope conflict.** The screens spec (REQ-3) mandates `test/client_id_contract_test.dart` for **both branches**; the sibling design (§2 item 6, §3.5) scopes it **Branch B only**. The screens spec is authoritative for this lens: under **Branch A** the live login wire changes value, and the only value-asserting Dart test (`sso_client_test.dart:18`) covers the **dormant** `SSOAdminClient.login` (no production caller — all live `.login(` sites are `OidcLoginApi` at `oidc_provider_flow.dart:53`, `oidc_challenge_flow.dart:237`, `oidc_authorization_flow.dart:239,310,376`). Without the screens widget test, Branch A's live-wire change is **unguarded**. This design adopts REQ-3 for both branches (§3.5).
- **D2 — Census gap: `DEPLOY.md:29`.** `DEPLOY.md:29` documents the IdP registry expectation ("The `sso-admin-console` client's `allowed_resources` … must agree"). The sibling design marks it "unchanged by either branch" — correct under Branch B, **stale under Branch A** (the console would present `client_id=console`). This design adds `DEPLOY.md:29` as a **Branch A co-site** (§3.6).
- **D3 — Branch-B "amend the gate" is a no-op (this doc and the full 8-doc sweep).** The gate at `:57` already records `client_id=sso-admin-console` with acceptance "sink 出现 sso-admin-console login 事件；无重复" (§1). Every earlier Branch-B "amend the gate" narrative (previously §2 item 8, §6 M3) described a `client_id=console → sso-admin-console` diff that has **no match in the file** — the amendment is vacuous. Branch B therefore **drops the gate edit** (edit count: zero) and verifies by grep only (AC-1). Under **Branch A the gate row flips** to `client_id=console` / `sink 出现 console login 事件`（§3.6）— the gate must record the shipped value (D4).
- **D4 — Branch-A gate-row contradiction resolved (with the anchor lens).** §4.5 previously listed `implementation-gate.md` as untouched under Branch A, while the anchor design (§5, D15) co-changes gate/yaml rows under A. Agreed resolution, stated identically in both documents: the gate row **flips under Branch A** (an `sso-admin-console` exception for a value nothing ships contradicts the gate's contract-authority role) and stays untouched under Branch B (already correct). `campaign-console-b6.yaml:37` follows the same rule (anchor reconciles it to `sso-admin-console` under B; Branch A flips it back to `console`). The api design's parallel "untouched under Branch A" line is corrected the same way.
- **D5 — Anchor-lens test co-site (enforced single-source).** `test/oidc_login_screen_client_id_test.dart` (anchor REQ-2) carries the literal `'sso-admin-console'` at `:76` (harness `defaultClientId:`) and `:136/:158` (expects). It must be **constantized in the same commit as the constant** (M2, both branches): without it, under Branch A the REQ-2 grep guard (`'sso-admin-console'` in `test/` → 0 hits) trips red on a file outside this change-set, and under Branch B the single-source rule is violated. Co-site enumerated in §2 item 9 / §3.4; the anchor derives its REQ-2 expectation from the constant after this commit (compile-time gate).

**Screens-side chokepoint property (new finding, verified):** `_effectiveClientId` is read at **14 sites**, all inside the `lib/screens/oidc_login/` part-library:

| Site | Role |
|---|---|
| `oidc_login_screen.dart:159-161` | definition (URL passthrough wins over `defaultClientId`) |
| `oidc_login_screen.dart:216,222` | probe guard + `_probeProviders()` call (initState) |
| `oidc_provider_flow.dart:54` | first-party login POST body `'client_id'` |
| `oidc_provider_flow.dart:87,138` | `Session.store(clientId:)`; PKCE/trusted-device scope |
| `oidc_provider_flow.dart:108` | empty-client guard ("No client is configured") |
| `oidc_provider_flow.dart:155` | `probeProviders(_effectiveClientId, …)` |
| `oidc_challenge_flow.dart:9,234` | `TrustedDeviceToken.clear/…`; challenge login POST body |
| `oidc_authorization_flow.dart:144,238,295,296,370,371` | silent-renewal/authorization payloads; `TrustedDeviceToken.read` |

There is **no `client_id` literal in `lib/screens/`** — the value enters solely through `OidcLoginScreen.defaultClientId` (`app_router.dart:35`) or a URL query param. Changing the constant therefore cannot fork the screens side.

---

## 2. Design summary

**Files touched: 2 production + 6-7 Dart test (incl. the anchor lens's `oidc_login_screen_client_id_test.dart` co-site, D5) + 1-2 Python + 1 new drill + 1-2 docs; no new endpoints; no signature change beyond one default's value source.**

1. `lib/api/sso_client.dart` — add `static const String firstPartyClientId`; `login` default references it (REQ-1).
2. `lib/app_router.dart:35` — `defaultClientId: SSOAdminClient.firstPartyClientId` (+ import) (REQ-1).
3. `test/sso_client_test.dart:18` — assertion references the constant (REQ-1; AC-3 keeps the whole-body pin).
4. `test/oidc_account_flow_test.dart:35,75,115,160` — args reference the constant (REQ-1; value-agnostic, green under both branches).
5. **New** `test/client_id_contract_test.dart` — screens-chain pin through the probe POST, **both branches** (REQ-3; resolves D1; two cases: default fallback + URL-passthrough precedence).
6. Branch A only: `tests/integration/test_config.py:44`, `tests/integration/README.md:17`, **`DEPLOY.md:29`** (D2).
7. Both branches: **adopt** the existing `tests/integration/audit_login_drill.py` (REQ-4) — an untracked working-tree artifact (8.2 KB / 214 lines, steps 1-6, `AGREED_CLIENT_ID` switch at `:31`), **already wired** at `run_all.py:169` and `full_stack_verify.py:113` (uncommitted diff). Commit file + wiring; never re-create or re-insert (D-DRILL-1, §3.8).
8. Both branches: `docs/proposals/audit-contract-batch-snaplink-console.md:12` `[MISMATCH]` → `[RESOLVED]` (stale `:55` → `:35` fixed). **`docs/campaigns/implementation-gate.md:57` row 2 is NOT edited under Branch B** — it already records `client_id=sso-admin-console` (verified §1; the previously-specced amendment is a **no-op**, D3); under Branch A it flips to `client_id=console` (§3.6).
9. **Both branches (anchor-lens co-site, D5):** `test/oidc_login_screen_client_id_test.dart` — constantize its three literal sites (`:76` harness `defaultClientId:`, `:136/:158` expects) to `SSOAdminClient.firstPartyClientId` in the same commit as the constant (M2). REQUIRED: without it, the Branch-A guard trips red on a file outside this change-set and Branch B violates single-source (§3.4).

**Key decisions:**

- **D3 — Constant lives in `SSOAdminClient`** (spec REQ-1). Dart requires default parameter values to be compile-time constants: once `login`'s default reads `firstPartyClientId`, re-forking that site is a compile error. The `app_router.dart:35` wiring is the residual risk, covered by grep guards (REQ-1/REQ-2).
- **D4 — The live wire is the screens chain, not `SSOAdminClient`.** `SSOAdminClient.login` has no production caller (verified §1); every live login POST body is built from `_effectiveClientId` (14-site chokepoint, §1). Therefore (a) the decision-critical change is `app_router.dart:35` + the constant, and (b) the regression pin that matters is the screens widget test (REQ-3), for **both** branches (D1).
- **D5 — Branch choice is an evidence gate, not a code fork** (REQ-0): branches differ in exactly the constant value + mirror sites (§3.6) + one doc record. The mechanism (constant + wiring + constantized tests + drill) is branch-neutral and lands first; the value lands as one atomic commit.
- **D6 — REQ-3 assertion target is the probe POST** (`oidc_login_screen.dart:222` → `oidc_provider_flow.dart:152-156` → `lib/api/oidc_login_api.dart:48-52`), **not** the `Session.store` call (`oidc_provider_flow.dart:87` — a session side-effect, correct as-is; implementers must not "fix" it).
- **D7 — Drill placement is Gate 5 / step 5** (proxy dependency): `run_all.py` starts the proxy only inside Gate 5 (`:128-150`, guard `:125`); `full_stack_verify.py` starts it in step 4 (`:73-99`). The drill is inserted after `e2e_runner.py` (`run_all.py:164-166`) and after the Detail API step (`full_stack_verify.py:106-108`). `--ci` skips Gate 5 — same as `e2e_runner.py`/browser tests; documented, not a defect.
- **D8 — Drill SKIP semantics**: missing credentials → `SKIP:` + exit 0 (mirrors `api_login_e2e.py:28-36`); FAIL (exit 1) only for genuine contract violations. Prevents false failures in dev without a live stack.

---

## 3. API changes (concrete)

### 3.1 `lib/api/sso_client.dart` (REQ-1, both branches)

Add next to `nativeDefaultBaseUrl` (`:76`):

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

No other change: `login`'s signature `(String username, String password, {String clientId, List<String>? resources})` and the body map (`:91-95` — provider, client_id, scope, conditional resource, credential) are byte-identical except the value source.

### 3.2 `lib/app_router.dart` (REQ-1, both branches)

Add `import 'api/sso_client.dart';`; change `:35`:

```dart
defaultClientId: SSOAdminClient.firstPartyClientId,
```

`OidcLoginScreen.defaultClientId` stays `String?` (`oidc_login_screen.dart:54,60`) with identical fallback semantics (`:159-161`). No screens file gains or loses an import beyond the router.

### 3.3 `test/sso_client_test.dart:18` (REQ-1; value flip under A)

```dart
'client_id': SSOAdminClient.firstPartyClientId,
```

The whole-body map assertion (`:16-22`, all five keys) is preserved — AC-3's regression pin. Under Branch B the file is unchanged except this constantization (same value).

### 3.4 `test/oidc_account_flow_test.dart:35,75,115,160` (REQ-1, both)

Replace each `defaultClientId: 'sso-admin-console',` with `defaultClientId: SSOAdminClient.firstPartyClientId,`. These tests assert no `client_id` value (forgot-password/signup/verify-email), so they are green under both branches at every migration step. **Do not touch** `test/native_shell_test.dart:98,147,202` (`'native-client'` — a distinct value on the same parameter; negative constraint). Do not touch `test/oidc_login_api_test.dart:220-228` (probe test passes an explicit `'rp-client'` — value-agnostic).

**`test/oidc_login_screen_client_id_test.dart` (anchor lens; REQ-1/REQ-2 co-site, both branches — D5):** replace the harness `defaultClientId: 'sso-admin-console',` (`:76`) and both `expect(harness.lastClientId, 'sso-admin-console')` (`:136, :158`) with `SSOAdminClient.firstPartyClientId`. This is the anchor REQ-2 expectation source: after this edit the file derives from the constant (compile-time gate — absent/renamed constant = compile error), the AC-1 `test/` grep turns from pinned-allowlist to zero hits, and under Branch A the assertion follows the flip with zero further edits. The file belongs to the anchor lens but is a **mandatory co-site of this change-set** — the constantization must land in the same commit as the constant (M2), not later.

### 3.5 `test/client_id_contract_test.dart` (new; REQ-3, **both branches** — D1)

Widget test reusing the in-repo MockClient idiom (`test/oidc_account_flow_test.dart:19-29`: `OidcLoginApi(httpClient: MockClient(...))` with no `baseUri` — resolves `ProductApiOrigin.baseUri`, so the probe's `'../auth/login'` POST lands on path `/auth/login`; viewport idiom `tester.view.physicalSize`/`devicePixelRatio` + `addTearDown(tester.view.reset)`; synchronous MockClient so `pumpAndSettle` cannot flake).

```dart
testWidgets('probe POST carries the aligned first-party client id', (tester) async {
  Map<String, dynamic>? probeBody;
  final api = OidcLoginApi(
    httpClient: MockClient((request) async {
      if (request.url.path == '/auth/login') {
        probeBody = jsonDecode(request.body) as Map<String, dynamic>;
      }
      return http.Response('{}', 404); // non-probe routes: graceful 404
    }),
  );
  tester.view.physicalSize = const Size(900, 1600);
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
  expect(probeBody, isNotNull,
      reason: 'probe must fire from initState for the /login/ route');
  expect(probeBody!['client_id'], SSOAdminClient.firstPartyClientId);
});

testWidgets('URL-supplied client_id wins over the default', (tester) async {
  // same harness; routeUri: Uri.parse('https://sso.example/login/?client_id=rp-client')
  // expect(probeBody!['client_id'], 'rp-client');
});
```

Probe firing conditions (verified, `oidc_login_screen.dart:216-222` + `hosted_login_models.dart:323-328`): `_effectiveClientId.isNotEmpty` ✓ (fallback), `_route.requiresAuthentication` ✓ for path `/login/` (flow == login, not malformed), no federated continuation, no pending PKCE return, no magic-link autosubmit, `hasPromptNone` false — all true for a bare `/login/` URI. **The first case pins the `_effectiveClientId` fallback chain** (`:159-161` → `:222` → `oidc_provider_flow.dart:152-156` → `oidc_login_api.dart:48-52`) against the constant, and turns red if the constant mutates. **The second case pins `oauth_params.dart:59` precedence** (URL wins) — contract-correct today, must survive the rename.

### 3.6 Branch A co-sites (REQ-2; includes D2)

- `tests/integration/test_config.py:44`: `'SNAPLINK_TEST_CLIENT_ID', 'console'`.
- `tests/integration/README.md:17`: document the new default (`console`).
- **`DEPLOY.md:29` (D2)**: update the IdP registry instruction to the `console` client (`console` client's `allowed_resources` … must agree).
- **`docs/campaigns/implementation-gate.md:57` row 2 (D3/D4)**: flip cell 3 `（client_id=sso-admin-console）` → `（client_id=console）`; acceptance cell `sink 出现 sso-admin-console login 事件` → `sink 出现 console login 事件`（无重复 unchanged）— the gate records the shipped value.
- **`docs/campaigns/campaign-console-b6.yaml:37`**: flip back to `client_id=console` (the anchor lens reconciles it to `sso-admin-console` under Branch B; under A the prompt must name the shipped value).

Branch B: all five keep `'sso-admin-console'` — no change (the gate/yaml already record the Branch-B value; no-op).

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

### 3.8 `tests/integration/audit_login_drill.py` (existing untracked artifact — adopt, don't create; REQ-4, both branches)

**Adopt-vs-create adjudication (D-DRILL-1):** the file **already exists** in the working tree — untracked (`git ls-files` empty, no commit), 214 lines ≤ 280 budget, device-lens framing with steps 1-6 matching this section's sketch nearly 1:1 (REQ-0 evidence, device redirect-leg shape, login via `CONFIG.login_payload()` + JWT `tenant_id`, exactly-one-row sink query, no-duplicates, report) and `AGREED_CLIENT_ID = 'sso-admin-console'` at `:31`. **This change set must not create or overwrite it**; it verifies the shape against this sketch, extends only if a lens adds a leg (developer DCR leg — that lens's co-change), and `git add`s the file at M4. **Git-clean fragility:** the artifact and its wiring survive only in the dirty working tree — `git clean -f` deletes the file; `git checkout -- tests/integration/run_all.py tests/integration/full_stack_verify.py` strips the wiring. M4 must commit both before any tree cleanup; the grep acceptance below passes only after the wiring diff is committed.

Checked-in runnable file (not a runbook pointer). Budget ≤ 280 lines (filesize gate `engineering.yaml:11` = 400; reference `api_login_e2e.py` = 166). Header docstring: purpose, branch value, usage, and the canvas limitation (`browser_login_test.py:89`) as the reason the login leg is API-driven through the proxy — the same wire the screens drive (`oidc_provider_flow.dart:54`, `sso_client.dart:92`).

```
AGREED_CLIENT_ID = <'console' | 'sso-admin-console'>   # branch value, one line
helpers: check/curl (api_login_e2e.py:12-26), decode_jwt (full_integration_test.py:29-33)
SKIP:  CONFIG.require_credentials() raises IntegrationConfigurationError
       → print SKIP, exit 0 (api_login_e2e.py:28-36 idiom)
Step 1 (REQ-0 evidence): assert CONFIG.client_id == AGREED_CLIENT_ID, else FAIL
Step 2 (login):          POST {CONFIG.proxy_url}/auth/login with CONFIG.login_payload()
                         assert access_token; decode JWT; extract tenant_id claim → <t>
                         missing claim → FAIL with the B4-1 dependency recorded (no parsing impl)
Step 3 (sink query):     GET {CONFIG.api_url}/api/v1/audit/events
                           ?event_types=auth.login.success&tenant_id=<t>  (Bearer)
                         assert exactly one row; assert row client_id claim == AGREED_CLIENT_ID
                         (any other value = documented contract deviation → FAIL)
Step 4 (no duplicates):  second login; re-query → exactly 2 rows, no repeated event id/trace_id;
                         settle ≥ max(10, SNAPLINK_DRILL_SETTLE_SECONDS)s; re-query → count unchanged
Step 5 (report):         PASS/FAIL summary; exit 0 on PASS/SKIP, 1 on FAIL
```

**AC-2 [proposed] fallback (both branches):** steps 3-4 depend on BFF/sink-side emission this repo cannot generate (0 grep hits, §1). If the sink-side emission cannot be verified (no deployed stack, no emission observed), the drill logs the query and result, marks those assertions `[proposed]` in the report, records the deviation in the `[RESOLVED]` note, and exits without a false PASS. Steps 1-2 are in-repo verifiable and always asserted.

### 3.9 Harness wiring (REQ-4, both branches)

- `tests/integration/run_all.py` — **already wired at `:169`** (inside Gate 5, immediately after `run_e2e_test('Python E2E Runner', …)` — the `:164-166` insertion point this plan earlier named is exactly where the live entry sits). Verify, do not re-insert; verbatim insertion would duplicate the block. The wiring is an uncommitted diff — commit it at M4:
  ```python
  run_e2e_test('B6-2 Login Drill (client_id contract)',
               ['python3', 'tests/integration/audit_login_drill.py'], timeout=300)
  ```
- `tests/integration/full_stack_verify.py` — **already wired at `:113`** (end of step 5, after the Detail API step — the `:106-108` insertion point is where the live entry sits). Verify, do not re-insert; uncommitted diff — commit at M4:
  ```python
  step('B6-2 Login Drill (client_id contract)',
       ['python3', 'tests/integration/audit_login_drill.py'], 300)
  ```

---

## 4. Compatibility constraints

1. **Wire/API surface**: `/auth/login` method, path, and every body key except the `client_id` *value* are unchanged (REQ-5). `SSOAdminClient.login` keeps its exact signature; `OidcLoginScreen.defaultClientId` stays `String?` with the same fallback; `OidcLoginApi.login/probeProviders` signatures unchanged (probe `clientId` stays a required positional).
2. **Dart compile-time const default**: `clientId = firstPartyClientId` is legal only because the constant is `static const`; any future non-const change is a compile error, not silent drift — the fork-proofing property for the `login` site. The `app_router.dart:35` wiring needs the grep guard (D6 in §2).
3. **Live vs dormant wire**: `SSOAdminClient.login` is dormant in production (§1); the live wire is `app_router.dart:35` → `OidcLoginScreen.defaultClientId` → `_effectiveClientId` (14-site chokepoint). Under Branch A that is the branch-gated behavior change; under Branch B the wire value is identical to today. The screens widget test (REQ-3) is the pin for the live wire under **both** branches (D1).
4. **IdP registry is the real constraint** (REQ-0): `console` registered → A; `sso-admin-console` registered → B; neither → no branch merges. External to this repo; drill step 1 + operator evidence is the only channel.
5. **Untouched**: `'native-client'` sites (`native_shell_test.dart:98,147,202`); `PortalApi.login`'s `Session.readClientId()` source (`lib/session.dart`, `portal_screen.dart:122`); `test/api_contract_test.dart:24,29` (URL path templates only); `federated_login.dart:119,203`, `oidc_authorization_flow.dart:238,295,370`, `oidc_challenge_flow.dart:234` (consume `_effectiveClientId` — no literal, no change); `device_verify_screen.dart` (no literal); the event stream; `docs/campaigns/implementation-gate.md` **under Branch B** (already records the Branch-B value — no-op; **under Branch A it is amended**, §3.6); `docs/campaigns/campaign-console-b6.yaml` under Branch B (the anchor lens owns its reconciliation; under Branch A it flips back to `console`, §3.6).
6. **Zero-delta boundaries** (REQ-5): no `lib/i18n/` changes (`test/i18n_coverage_test.dart` green by construction); no new endpoints; no emission code anywhere in `lib/` (`grep auth.login.success lib/` stays 0); no screens UI copy/UX changes; `test/sso_client_test.dart` keeps the full body-shape pin.
7. **Filesize gate**: `engineering.yaml:11` `max_lines: 400` applies to `.py`; drill budget ≤ 280 lines (reference `api_login_e2e.py` = 166).
8. **Harness semantics**: drill SKIP (exit 0) without live stack/credentials (D8); `run_all.py --ci` skips Gate 5 and therefore the drill — same as `e2e_runner.py` (documented, accepted); `api_login_e2e.py` stays unregistered (conventions reference only).
9. **REQ-3 probe chain**: assertion targets the probe POST (`oidc_provider_flow.dart:152-156` → `oidc_login_api.dart:48-52`), **not** `Session.store` (`oidc_provider_flow.dart:87` — session side-effect, correct as-is).
10. **Widget-test environment**: `OidcLoginApi` with no `baseUri` resolves `ProductApiOrigin.baseUri` → probe path `/auth/login`; synchronous MockClient + `pumpAndSettle` → no timing flake (proven idiom at `oidc_account_flow_test.dart:19-66`).

---

## 5. Failure modes

| # | Mode | Detection | Mitigation / rollback |
|---|---|---|---|
| F1 | Wrong branch chosen (drill evidence misread; registry later changes) | Post-deploy login 401/`invalid_client`; sink row missing | One-line constant flip + mirrors in the same change set; re-open `[RESOLVED]`. No data/schema/transport migration exists. |
| F2 | IdP registers neither id | Drill step 1/2 FAIL | REQ-0 cannot conclude → do not merge the value commit; land only the branch-neutral mechanism or nothing. Rollback = current state. |
| F3 | Constant forks again (fresh literal re-inlined) | Branch A: `grep -rn "sso-admin-console" lib test tests/integration` hits; Branch B: literal outside the constant site | REQ-1/REQ-2 grep guards are acceptance checks, CI-able. Compile-time const default makes the `login` site fork-proof; `app_router` wiring is the residual risk covered by grep. The anchor lens's test file is a co-site (§3.4, D5) — constantized in the same commit, so this guard cannot trip on a file outside the change-set |
| F4 | Blanket find/replace hits `'native-client'` sites | `flutter test test/native_shell_test.dart` red | Negative constraint (§4.5); the §3.4 edits are enumerated, never pattern-based. |
| F5 | Probe never fires in the widget test (route parsing change, `requiresAuthentication` regression) | `probeBody == null` → REQ-3 red | First assertion carries an explicit reason message; routeUri pinned to `/login/`; the `hosted_login_models.dart:323-328` flow conditions are documented in the test header. |
| F6 | URL-passthrough precedence broken by the rename | REQ-3 second case red | That case pins `oauth_params.dart:59` (`isNotEmpty` wins) and must stay green under both branches. |
| F7 | Drill FAIL at steps 3-4 (no sink row / duplicates / wrong claim) | Drill exit 1 with query output | Attach FAIL output to `[RESOLVED]`; do **not** close the record; defer to B4-5 drill owner (gate row 2). No code revert needed. |
| F8 | Sink row schema lacks a `client_id` claim (external schema, unverifiable from this repo) | Drill step 3 FAIL on missing field | Recorded as a documented contract deviation; AC-2 `[proposed]` fallback applies — log instead of asserting when the emission/field cannot be verified from this repo. |
| F9 | `tenant_id` claim missing from login JWT | Drill step 2 FAIL | Record the B4-1 dependency; the drill does not implement claim parsing — by design. |
| F10 | Sink read API rejects `event_types`/`tenant_id` query params | Drill step 3 4xx | FAIL is contract evidence for B4-5; no existing test uses these params (verified) — first consumer; the drill does not adapt. |
| F11 | Event-ingestion lag produces transient "no row yet" | Step 3/4 count assertions fail transiently | Settle interval `max(10, SNAPLINK_DRILL_SETTLE_SECONDS)`s + re-query count-unchanged assertion; env knob documented in the drill header. |
| F12 | `defaultClientId` nulled at the login route by future rewiring | `_effectiveClientId` → `''`; `oidc_provider_flow.dart:108-110` surfaces "No client is configured" | Guard already exists; REQ-3 test is the pin template for any rewiring. |
| F13 | Drill grows past 400 lines | `python3 cli.py check-filesize` red | Budget ≤ 280 lines; extract shared helpers into a sibling module only if needed (stays in `tests/integration/`). |
| F14 | Stale `app_router.dart:55` citation resurrected in other docs | `grep -rn "app_router.dart:55" docs/` | Fixed once at §3.7; verified no other doc carries it today (proposals corpus grepped). |
| F15 | `run_all.py`/`full_stack_verify.py` false-fail without live stack | Drill exit 1 in a dev-only environment | SKIP semantics (§3.8, D8): missing credentials → exit 0 with `SKIP:` line. |
| F16 | Branch A lands without a §3.6 co-site (`DEPLOY.md:29`, gate:57, yaml:37, anchor test) | Deploy docs / gate / prompt / tests contradict the shipped client id | D2/D4/D5: all four are in the §3.6 co-change list and reviewed with the atomic branch commit; the anchor test co-site is additionally enforced by the AC-1 `test/` grep and the anchor census literal-census |

---

## 6. Migration steps (each leaves the tree green; no data migration)

Ordering is branch-neutral until M3; the branch decision lands as **one atomic commit** (the value flip and its mirrors must not straddle commits — the grep guards would be red in CI).

1. **M1 — REQ-0 evidence (no code)**: operator runs the drill precondition (step 1) against the deployed IdP registry (`console` vs `sso-admin-console` vs neither); records the branch choice in the run's `DECISIONS.md`. Tree untouched.
2. **M2 — REQ-1 mechanism (branch-neutral, green under both)**: add `firstPartyClientId` to `lib/api/sso_client.dart` (value = current literal `'sso-admin-console'`), point `login`'s default at it, point `app_router.dart:35` at it (new import); constantize `test/sso_client_test.dart:18`, `test/oidc_account_flow_test.dart:35,75,115,160`, **and the anchor lens's `test/oidc_login_screen_client_id_test.dart:76,136,158` (co-site §3.4/D5 — same commit, REQUIRED)**. Wire values unchanged → full `flutter test` green; `grep -rn "'sso-admin-console'" test/` → 0 hits.
3. **M3 — branch decision commit (atomic; REQ-0/REQ-2/REQ-3)**: under **Branch A** flip the constant to `'console'` **and** flip `tests/integration/test_config.py:44`, `tests/integration/README.md:17`, `DEPLOY.md:29`, **`implementation-gate.md:57` row 2, and `campaign-console-b6.yaml:37`** in the same commit (D2/D3/D4, §3.6); under **Branch B** keep the value. **Both**: add `test/client_id_contract_test.dart` (D1 — the live-wire pin is required under A precisely because the value changed) and close the `[MISMATCH]` record (`audit-contract-batch-snaplink-console.md:12`, stale `:55` → `:35` fixed); **Branch B: no gate amendment (no-op — gate:57 already records `sso-admin-console`, D3)**. Green: `flutter test` + grep guards (§7).
4. **M4 — REQ-4 drill (branch-neutral; `AGREED_CLIENT_ID` mirrors M3's value)**: **adopt** the existing untracked `tests/integration/audit_login_drill.py` (§3.8 — verify shape, do not recreate) and **commit** its already-present wiring (`run_all.py:169`, `full_stack_verify.py:113` — uncommitted diff; do not re-insert after `:164-166`/`:106-108`). `git add` the drill file and the two wiring diffs **first** — the premise is `git clean`-fragile (D-DRILL-1). May fold into M3 for a single review or stay separate; grep-verifiable either way.
5. **M5 — gates (REQ-1/REQ-5)**: `dart format --output=none --set-exit-if-changed lib`, `dart analyze`, full `flutter test`, `make verify`, `python3 cli.py check-filesize`; branch grep guards (§7); `git diff --stat` shows no `lib/i18n/` files and no `lib/screens` files other than none.
6. **M6 — deploy + drill execution (REQ-4)**: deploy the aligned constant to the T-12/G7 environment, run `python3 tests/integration/audit_login_drill.py`; append PASS/FAIL output + sink query result to the `[RESOLVED]` record (§3.7).

**Rollback**: revert M3 (one-line constant flip + mirrors + doc records) or M2+M3 together — full restoration of pre-B6-2 behavior; no data, no schema, no transport change. M4 is inert without M3's value and can stay or be reverted independently.

---

## 7. Testable acceptance mapping

| Supplied check (spec §4) | Testable form | Command / artifact |
|---|---|---|
| AC-1 — login body `client_id` matches the decision (code+test update **or** approved contract-exception note), enforced by updated `sso_client_test.dart` | REQ-0 + REQ-2/REQ-3: `flutter test test/sso_client_test.dart test/client_id_contract_test.dart` green; `:18` asserts `SSOAdminClient.firstPartyClientId` (no literal); `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` names the branch with evidence; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits (stale `:55` gone). Branch B: `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits `:57` — **already present, unedited (no-op, D3)** | `flutter test test/sso_client_test.dart test/client_id_contract_test.dart`; grep commands |
| AC-2 — drill: recorded real login → `auth.login.success` with the agreed `client_id` (Branch B: `sso-admin-console`) retrievable via `GET /api/v1/audit/events`; `[proposed]` fallback when sink-side emission unverifiable from this repo | REQ-4: `python3 tests/integration/audit_login_drill.py` — steps 1-2 always asserted (branch value match, login + JWT `tenant_id`); steps 3-4 (exactly one row with agreed `client_id` claim; two logins → 2 rows, no duplicates, settle ≥ 10 s, count stable) asserted or explicitly `[proposed]`; exit 0 only on PASS/SKIP; file wired: `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` | `python3 tests/integration/audit_login_drill.py`; grep commands |
| AC-3 — regression: `sso_client_test.dart` continues to pin the full `/auth/login` body shape | REQ-5: `flutter test test/sso_client_test.dart` green; `:16-22` whole-body map still contains all five keys; `git diff test/sso_client_test.dart` shows only the `client_id` line under A, zero diff under B | `flutter test test/sso_client_test.dart`; `git diff test/sso_client_test.dart` |
| REQ-1 (both) — single source of truth | `grep -rn "sso-admin-console" lib/ --include="*.dart"` → exactly the constant site (B) / 0 hits (A); `grep -rn "'console'" lib/ --include="*.dart"` → exactly the constant site (A); no test carries a fresh literal — incl. the anchor lens's `test/oidc_login_screen_client_id_test.dart` (co-site §3.4, D5): `grep -rn "'sso-admin-console'" test/` → 0 hits after M2 | grep guards |
| REQ-2 (A) — rename + census co-sites (incl. `DEPLOY.md:29` D2, gate/yaml D3/D4) | `flutter test test/sso_client_test.dart test/oidc_account_flow_test.dart` green; `grep -rn "sso-admin-console" lib test tests/integration DEPLOY.md --include="*.dart" --include="*.py" --include="*.md"` → exit 1 (passes because the anchor-lens co-site was constantized in the same commit, D5) | `flutter test …`; grep guard |
| REQ-3 (both) — screens-chain regression pin | `flutter test test/client_id_contract_test.dart` green (both cases); constant mutation makes case 1 red; case 2 (URL passthrough) stays green | `flutter test test/client_id_contract_test.dart` |
| REQ-4 (both) — checked-in drill | file exists in `tests/integration/`; wired (grep above); header documents `browser_login_test.py:89` canvas limitation; drill run per AC-1/AC-2 with `[proposed]` handling | grep + `python3 tests/integration/audit_login_drill.py` |
| REQ-5 (both) — no regression / zero-delta | full `flutter test` green with no test edits beyond REQ-1/2/3; `git diff --stat -- lib/i18n` empty; no new `lib/screens` files; `SSOAdminClient.login` signature and `/auth/login` body keys unchanged; `grep -rn "auth.login.success" lib/` → 0 hits | `flutter test`; `make verify`; `git diff --stat`; grep |

Gate relationship preserved from the spec: AC-1 and AC-3 apply under both branches; AC-2's drill asserts the *agreed* value with the `[proposed]` fallback exactly as supplied.

---

## 8. Out of scope (unchanged)

Sink/IdP client registry state (external; REQ-0 evidence channel only); `auth.login.success` emission (no such code exists — 0 grep hits); B6-1a (timeline UI), B4-1 (tenant claim parsing — drill dependency only), B4-5 (drill gate owner); BFF trace injection; any `lib/api` surface change beyond one parameter default's value source; `PortalApi`'s `Session.readClientId()` source; `'native-client'` test sites; `lib/i18n` catalog (zero delta); `device_verify_screen.dart` behavior (redirect target unchanged).
