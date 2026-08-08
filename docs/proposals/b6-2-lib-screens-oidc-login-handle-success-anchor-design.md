# B6-2 Design — `oidc_login` lens: `_handleSuccess` choke-point anchor + client_id decision pin

Module: `lib/screens/oidc_login` (analysis `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`, direction 0 = spec's "direction 1") · Direction: B6-2 (edge generation verification, `auth.login.success` / client_id) · Value: 9 · Risk reduction: 9 · Effort: 3 · Confidence: 10
Status: **design** — implementation of the requirements spec `docs/proposals/b6-2-lib-screens-oidc-login-handle-success-anchor-spec.md` (REQ-0 … REQ-4).
Sibling instance: `docs/proposals/b6-2-lib-screens-client-id-alignment-design.md` owns the `lib/screens`-wide constant extraction and Branch A/B gate. **That design has NOT landed at HEAD** (verified: zero `firstPartyClientId` hits in `lib/ test/`; no `test/client_id_contract_test.dart`) — this design therefore asserts the literal and documents the co-change rule for when the sibling lands. This design is **branch-neutral**: it pins `'sso-admin-console'` (Branch B) and makes the flip to Branch A a documented atomic co-change.

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

Every citation in the requirements evidence was re-checked line-exact. **All substantive claims hold, including the material correction.** Independent findings:

| Evidence claim | Verification result |
|---|---|
| `oidc_authorization_flow.dart:8` — `_handleSuccess` declaration | ✅ exact; spans `:8-139` (verified end brace). First member of `_OidcAuthorizationFlow`. |
| Six call sites: `:242` (silent renewal), `:313` (password/TOTP/code/magic-link), `:379` (passkey), `oidc_challenge_flow.dart:150` (MFA), `:244` (consent), `oidc_provider_flow.dart:60` (federated) | ✅ all line-exact; every `if (outcome.ok) {` at `:241,312,378,149,243,59` is immediately followed by `_handleSuccess(outcome);`. |
| Non-terminal `outcome.ok` uses: `_sendProviderCode` `oidc_authorization_flow.dart:326` with `_codeSent = outcome.ok` at `:341-342` (assignment), probe `oidc_provider_flow.dart:279` (compound `if (outcome.ok && …)`) | ✅ exact — neither observes terminal success. |
| `oidc_account_flow.dart:76, :182` — non-login account actions, zero `_handleSuccess` | ✅ substance holds; ⚠️ **minor drift**: `:76` is the **reset-password** result ("Password updated"), not signup; `:182` is email-verify. Both call `_showAccountResult`, neither touches `_handleSuccess`. |
| Payload-builder sites: `:238, :295, :370` + `oidc_challenge_flow.dart:234` + `oidc_provider_flow.dart:54` all carry `client_id` from `_effectiveClientId` | ✅ all five line-exact. All seven success paths send `_effectiveClientId`. |
| `_effectiveClientId` getter `oidc_login_screen.dart:159-161`; URL-supplied `client_id` wins | ✅ exact (`:159` head, fallback `widget.defaultClientId ?? ''` at `:161`). |
| Probe fires from `initState` (`oidc_login_screen.dart:216-225`) | ✅ substance exact; ⚠️ **minor drift**: guard `:216-221`, `_probeProviders()` call at `:222`. Guard conditions verified (`_effectiveClientId.isNotEmpty && _route.requiresAuthentication &&` no pending federated/magic-link/prompt=none). |
| Probe POST: `lib/api/oidc_login_api.dart:47-55` — `probeProviders` body has `client_id` + optional `login_hint`, **no `credential`** | ✅ exact. Also: `lib/screens/oidc_login/oidc_login_api.dart` is a one-line re-export shim (`:3`); the real API is `lib/api/oidc_login_api.dart`. |
| `OidcLoginApi.login` verbatim passthrough at `:57-58`; covered by `test/oidc_login_api_test.dart` (`api.login({'client_id':'rp',…})` at `:76` asserts form-post branch) | ✅ exact. |
| `app_router.dart:35` `defaultClientId: 'sso-admin-console'`; `sso_client.dart:86,92`; `sso_client_test.dart:18` | ✅ all exact. |
| `implementation-gate.md:57` records **`client_id=sso-admin-console`** (direction's `client_id=console` citation misquotes) | ✅ **correction confirmed against the file**. The contract exception the acceptance asks for already exists at the gate. |
| `campaign-console-b6.yaml:37` — stale `auth.login.success with client_id=console` | ✅ exact — the only remaining `client_id=console` text. |
| `grep auth.login.success lib/ test/` → 0 hits | ✅ confirmed (0). |
| `hosted_login_models.dart:323-326` `requiresAuthentication` (login/magicLink/changeEmail/invitation) | ✅ exact (`:323` getter head). |
| Harness pattern in `test/oidc_account_flow_test.dart` (`defaultClientId` at `:35,75,115,160`; pump `OidcLoginScreen(api: OidcLoginApi(httpClient: MockClient…))`) | ✅ exact. |
| File-IO structural tests are an established pattern (`test/audit_contract_guard_mutation_test.dart:29-31`, `test/backend_contract_manifest_test.dart:11`, `test/i18n_coverage_test.dart:26`) | ✅ — REQ-4's census test has in-repo precedent. |

**Cross-instance defects and new findings adopted below:**

- **D1 — All eight sibling docs misquote the gate (21 `client_id=console` hits); the sweep must cover every one.** The gate actually says `client_id=sso-admin-console` at `docs/campaigns/implementation-gate.md:57` (row 2, console). Every sibling `b6-2-lib-*-client-id-alignment` doc (six screens-family: screens/developer/device spec+design; plus the api pair) repeats the misquote in one of four classes:

  | Class | Hits | Where (file:line) | Fix |
  |---|---|---|---|
  | 1. Direct gate quote with "exact / contract authority" claim | 10 | api-spec `:25`, `:38`; api-design `:22`, `:23`; screens-spec `:35`; screens-design `:32`; developer-spec `:30`; developer-design `:34`; device-spec `:20`; device-design `:24` | Quote the real text (`sso-admin-console`), drop the exactness claim |
  | 2. Branch-B "amend the gate" narrative | 6 | api-spec `:75`; api-design `:166`; screens-spec `:69`; screens-design `:185`; developer-design `:172`; device-design `:238` | Flip to "**no-op** — the gate already records the exception; verify-only" |
  | 3. Branch-conditional AC-2 acceptance hard-coding `console` | 2 | screens-spec `:126`; screens-design `:284` | Re-anchor to "the agreed value" |
  | 4. Legitimate Branch-A scenario lines | 3 | api-spec `:74`; screens-spec `:68`; screens-design `:38` (D2) | Keep — they describe the Branch-A world, not the gate |

  The requirements spec §5 already flags the sibling *spec*'s stale quote; the sibling **design** has the same defect, and so do the developer/device/api pairs. Class 2 deserves the explicit statement the anchor previously omitted: the Branch-B "amend the gate" narrative is **vacuous** — the amendment it describes (`client_id=console` → `client_id=sso-admin-console`) changes nothing against the real gate text, so Branch B is "exception already recorded; **no amendment required**" (gate edit count: zero). Fix timing: **executed in this revision** — the full 8-doc sweep landed here (all 21 hits; §8 step 5), so the sibling change-set inherits corrected documents; this change-set itself takes the gate as-is.
- **D2 — Sibling constant has not landed** (`firstPartyClientId` = 0 hits; no `client_id_contract_test.dart`). This change-set must not import a symbol that does not exist; REQ-2 asserts the literal. Co-change rule for the sibling landing is in §6.
- **D15 — Branch-A gate-row contradiction resolved (in both documents).** The anchor §5 co-changes gate/yaml rows under Branch A; the sibling design §4.5 previously listed `implementation-gate.md` as "untouched under Branch A". Resolution, now stated identically in the anchor and the sibling screens design (and the api design's parallel line): **the gate row flips under Branch A** — the gate must record the shipped value (`client_id=console` / `sink 出现 console login 事件`); keeping the `sso-admin-console` exception would record an exception for a value nothing ships, contradicting the gate's contract-authority role. Under **Branch B the gate is untouched** — it already records `sso-admin-console`, so the previously-specced Branch-B "amendment" (D1 class 2) is a **no-op**: the described diff has no match in the file, the gate edit count is zero, and Branch B verifies by grep only.
- **D3 — The drill exists only as an untracked working-tree artifact; all lenses must adopt, not create.** `tests/integration/audit_login_drill.py` (8.2 KB / 214 lines, device-lens framing — steps 1-6: REQ-0 evidence, device redirect-leg shape, login, sink, no-duplicates, report; `AGREED_CLIENT_ID` Branch A/B switch at `:31`) is wired into `run_all.py:169` and `full_stack_verify.py:113`. **Git-clean fragility:** `git ls-files tests/integration/audit_login_drill.py` is empty and `git log` has no commit for it — the file exists **only in the dirty working tree**; the `run_all.py`/`full_stack_verify.py` wiring is an **uncommitted diff**. One `git clean -f` deletes the drill; `git checkout -- tests/integration/run_all.py tests/integration/full_stack_verify.py` strips the wiring. The "already exists" premise holds only until then. **Adopt-vs-create adjudication:** the sibling screens design (§2 item 7, §3.8, §3.9) and the device design (D-DEV-3) plan to *create* this file and *insert* wiring "after `run_all.py:164-166`" / "after `full_stack_verify.py:106-108`" — **exactly the insertion points where the live entries already sit** (the developer and api designs repeat the same plan at `:165-166`/`:108` and `:164-166`/`:107-109`); verbatim execution would duplicate the wiring blocks and silently overwrite an untracked file. Adjudication: all three lenses (anchor, sibling screens design, device design) and the developer/api pairs flip to **adopt the existing untracked artifact + the existing wiring points** — verify shape, extend only if a lens adds a leg (developer DCR leg), and `git add` the file + wiring diffs together at the owning M-step (see §8 step 5). The spec's "[proposed] sink-side row generation" statement is therefore partially superseded for the *device* lens; the *oidc_login* lens drill is direction 3 of the same bucket (spec §2, AC-4) and stays out of scope. **This design must not create or modify a drill.**
- **D4 — `_handleSuccess` has seven terminal-delivery branches.** Within `:8-139` the function returns early on: JARM blocked, non-JARM delivery blocked, first-party form-post error, form-post submit, code delivery, token delivery, first-party completion (plus final blocked/error fallbacks). Any future client-side emission must therefore be inserted **at function entry** (after the controller clears, before the first branch) — a single call site that fires exactly once per terminal success regardless of delivery mode. This is the concrete shape of REQ-1.
- **D5 — `LoginOutcome.ok` semantics** (`lib/api/oidc_login_api.dart:11-29`): `status >= 200 && < 300 && data['error'] == null`. A 401 with JSON error body is a failure (`ok == false`); a 200 with `error` key is also a failure. The retry case in REQ-3 can use either; 401 + `{'error': 'invalid_credentials'}` is the natural script.
- **D6 — VM test stubs make the success path safe.** `BrowserNavigation` resolves to the in-memory stub on non-web (`lib/services/browser_navigation_stub.dart`, `replaceLocation` = in-memory route replace); `Session.store` writes `SessionStorage` (in-memory in tests). A widget test may complete a first-party login without navigation side effects; it still must **not** assert post-success navigation (out of scope, per spec).

Baseline at HEAD: `flutter test test/sso_client_test.dart test/oidc_login_api_test.dart` → **31/31 green** (verified).

---

## 2. Design summary

**Files touched: 2 new Dart test files + 1 doc line edit. Zero production code changes. No API changes. No new endpoints.**

| # | File | Change | Requirement |
|---|---|---|---|
| 1 | `docs/campaigns/campaign-console-b6.yaml:37` | `client_id=console` → `client_id=sso-admin-console` (stale prompt reconciliation) | REQ-0 |
| 2 | **new** `test/oidc_login_screen_client_id_test.dart` | Widget-level MockClient test: body `client_id` assertion + exactly-one-credential-bearing-login-POST-per-submit | REQ-2, REQ-3 |
| 3 | **new** `test/oidc_login_handle_success_census_test.dart` | Structural guard: 6 call sites, adjacency rule, single declaration, zero emission string | REQ-1, REQ-4 |

Untouched on purpose: `docs/campaigns/implementation-gate.md` (already records the contract exception — REQ-0), `test/sso_client_test.dart` (already asserts `sso-admin-console` — REQ-2's "same change-set" clause is vacuous at HEAD), `tests/integration/audit_login_drill.py` and its wiring (D3), `lib/` entirely.

---

## 3. Key decisions

- **D7 — No production code lands.** REQ-0 is a decision record, not a value change; the gate already records the exception. Shipping zero `lib/` edits makes the change-set trivially reviewable, reversible, and unable to affect login behavior. The regression value (REQ-2/3/4) is carried entirely by tests that must be green **at HEAD before any future B6-2 code change**.
- **D8 — REQ-2 and REQ-3 share one widget test file.** Both need the same pump + MockClient + request-capture harness; one file keeps the fixture logic single-sourced. REQ-4 is a separate plain Dart test (no widget harness needed; File IO).
- **D9 — Counting rule: path + `credential`-key filter.** A "login request" is a POST to `/auth/login` whose decoded body contains a `credential` map. This excludes (a) the mount-time probe (`oidc_login_api.dart:51-55`, no `credential`), (b) any `sendCode` traffic (`/auth/send-code`, different path). The filter is documented in the test comment so a future body-shape change is a conscious edit.
- **D10 — Body assertion is partial, not whole-map.** At the widget level the payload builder adds `provider`, `scope`, `credential`, and conditionally `device_token` (`oidc_authorization_flow.dart:295-300`). Whole-body equality would be brittle (trusted-device token, scope evolution). REQ-2 asserts `decoded['client_id'] == 'sso-admin-console'` plus `decoded['credential']['username']` as the proof this is the login POST, not the probe. Whole-body pinning stays where it belongs: `test/sso_client_test.dart:16-22` (API level, already exists).
- **D11 — Harness avoids auto-fire paths.** Route is `https://sso.example/login/` with no `prompt=none`, no fragment (`FederatedLogin.hasPendingReturn` false), no `flow` param, no magic-link token. This prevents `_submitSilentRenewal` (`oidc_provider_flow.dart:33-36` fires it only when `_isRpFlow && _params.hasPromptNone`) and `_resumeFederatedAuthorization` (`:8`) from injecting extra login POSTs — otherwise REQ-3's count is meaningless.
- **D12 — Census adjacency rule is syntactic, not semantic.** The guard matches lines of the exact form `if (outcome.ok) {` (no `&&`), asserts the next non-empty line equals `_handleSuccess(outcome);`, and requires exactly 6 such pairs at the pinned lines. Assignment uses (`_codeSent = outcome.ok` at `oidc_authorization_flow.dart:341-342`) and the compound probe condition (`:279`) are structurally excluded by the regex — no allowlist needed.
- **D13 — Line pins are the contract, not incidental test data.** A refactor that moves `_handleSuccess` or adds a seventh success path fails the census and forces a conscious update — that is REQ-1's enforcement mechanism (a new success path must either route through `_handleSuccess` and update the census, or be rejected).
- **D14 — yaml reconciliation is an edit, not a `[SUPERSEDED]` note.** REQ-0's grep guard is cleaner: `client_id=console` returns zero hits in the yaml. (The spec permits either; the batch owner may override — see §11.)

---

## 4. Detailed design

### 4.1 REQ-0 — decision pin + yaml reconciliation

- **No change** to `docs/campaigns/implementation-gate.md:57` — it already records `边缘生成验证：login → auth.login.success（client_id=sso-admin-console）| sink 出现 sso-admin-console login 事件；无重复 | B4-5`.
- **Edit** `docs/campaigns/campaign-console-b6.yaml:37`: `auth.login.success with client_id=console.` → `auth.login.success with client_id=sso-admin-console.`
- Grep guards (§10 AC-1): gate `:57` still hits `client_id=sso-admin-console`; yaml has no `client_id=console`; `lib/` still has `'sso-admin-console'` at `app_router.dart:35` + `sso_client.dart:86`.

### 4.2 REQ-2 + REQ-3 — `test/oidc_login_screen_client_id_test.dart`

Harness (mirrors `test/oidc_account_flow_test.dart:27-60`):

```dart
tester.view.physicalSize = const Size(900, 1600);
tester.view.devicePixelRatio = 1.0;
addTearDown(tester.view.reset);

var loginPosts = 0;          // credential-bearing /auth/login POSTs
String? lastClientId;
final script = <String>['ok'];  // per-test: ['fail', 'ok'] for the retry case

final api = OidcLoginApi(
  baseUri: Uri.parse('https://sso.example/'),
  httpClient: MockClient((request) async {
    final body = jsonDecode(request.body) as Map<String, dynamic>;
    final isLogin = request.url.path == '/auth/login' &&
        body['credential'] is Map;            // D9 filter — probe has no credential
    if (isLogin) {
      loginPosts++;
      lastClientId = body['client_id'] as String?;
      if (script.removeAt(0) == 'fail') {
        return http.Response(jsonEncode({'error': 'invalid_credentials'}), 401);
      }
      return http.Response(jsonEncode({'access_token': 't', 'session_id': 's'}), 200);
    }
    return http.Response('{}', 404);          // probe and everything else
  }),
);

await tester.pumpWidget(MaterialApp(
  home: OidcLoginScreen(
    api: api,
    defaultClientId: 'sso-admin-console',
    routeUri: Uri.parse('https://sso.example/login/'),   // D11: no prompt=none/fragment
  ),
));
await tester.pumpAndSettle();
```

**Constant rule — REQ-2 expectation source, enforced not prose:** at implementation time, if `SSOAdminClient.firstPartyClientId` exists (sibling landed first), the harness `defaultClientId:` and both `expect(lastClientId, …)` assertions **reference the constant** — a compile-time gate: the file fails to compile if the constant is absent or renamed, so a divergent literal can never silently land. If the constant does not exist yet (this change-set lands first), the literal `'sso-admin-console'` is used at the file's three sites (harness default + two expects; landed file: `:76`, `:136`, `:158`) and the **sibling's landing commit must constantize all three sites in the same commit** (its enumerated co-change list, sibling design §2 item 9 / §3.4) — after which the compile-time gate is active and this file carries zero literals. Under sibling Branch A the constant reference follows the flip automatically: no literal exists here to re-edit, and the Branch-A grep guard (`'sso-admin-console'` in `test/` → 0 hits) passes without a second edit. See §5 and §6.4.

**Case 1 — single submit, one login request, correct client_id (REQ-2 + REQ-3):**

1. After pump + settle (probe has fired): `expect(loginPosts, 0)` — proves the probe is excluded (D9).
2. `tester.enterText(find.widgetWithText(TextField, 'Username or email'), 'ada@example.com')`; same for the password field with `'pw'` (labels verified: `sign_in`, `username_or_email` i18n keys; field finders match the account-flow harness).
3. `await tester.tap(find.text('Sign in')); await tester.pumpAndSettle();`
4. `expect(loginPosts, 1)`; `expect(lastClientId, 'sso-admin-console')`; `expect(decodedCredentialUsername, 'ada@example.com')` (captured in the same MockClient).
5. Do **not** assert navigation/session state (D6; request-side facts only, per spec scope).

**Case 2 — retry after server rejection, cumulative exactly 2 (REQ-3):**

1. `script = ['fail', 'ok']`; submit once → 401 error displayed; `expect(loginPosts, 1)`.
2. `await tester.pumpAndSettle()` (clears `_loading` — the submit button re-enables), submit again → 200.
3. `expect(loginPosts, 2)` — each submit fires exactly one credential-bearing POST.

Both cases close with `api.close()` in `addTearDown` (mirrors `test/oidc_challenge_flow_test.dart`).

### 4.3 REQ-1 + REQ-4 — `test/oidc_login_handle_success_census_test.dart`

Plain Dart test using `File(...).readAsStringSync()` on `lib/screens/oidc_login/` part files (pattern: `test/audit_contract_guard_mutation_test.dart:29-31`; flutter test runs from the repo root, so relative `lib/…` paths resolve — same as `test/backend_contract_manifest_test.dart`).

Assertions:

1. **Declaration census:** exactly one `void _handleSuccess(` in the module, at `oidc_authorization_flow.dart:8`.
2. **Call-site census:** `_handleSuccess(outcome);` occurs exactly **6** times, at exactly the pinned lines `242, 313, 379` / `150, 244` / `60`; every other line in the module containing `_handleSuccess` is a violation.
3. **Adjacency rule:** in the three flow files, every line matching `^if \(outcome\.ok\) \{` (exact form, no `&&`) has `_handleSuccess(outcome);` as the next non-empty line — exactly 6 such pairs. Assignment (`oidc_authorization_flow.dart:341-342`) and compound (`:279`) uses are excluded by the pattern (D12).
4. **Account-flow isolation:** `oidc_account_flow.dart` contains zero `_handleSuccess` references.
5. **No emission string:** no `auth.login.success` substring in any `lib/screens/oidc_login/*.dart` file (repo-wide invariant per §1; a future emission anywhere in the module fails this until the drill proves the sink side).
6. **Conditional client_id literal census (single-source rule, §6.4):** scan `lib/api/sso_client.dart` for a `firstPartyClientId` declaration. If it exists (sibling mechanism landed), assert **zero** `'sso-admin-console'` literals in `test/` — every reference must go through the constant; if it does not exist (HEAD state), assert the literal census equals exactly the pinned allowlist: `sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`. The assertion auto-flips with the constant's existence — no co-change needed, enforced at every run in every landing ordering (§6.4 gate (c)).

The test is written against the verified census and **must pass at HEAD with zero source edits** (spec REQ-4).

---

## 5. API changes

**None.** Explicit inventory of what does *not* change and why:

- `OidcLoginApi.login(Map<String, dynamic>)` — passthrough unchanged; covered at `test/oidc_login_api_test.dart:76`.
- `OidcLoginApi.probeProviders(String clientId, {String? loginHint})` — unchanged; the REQ-3 filter relies on its no-`credential` body.
- `OidcLoginScreen.defaultClientId` — unchanged; value source stays `app_router.dart:35`.
- `SSOAdminClient.login` — unchanged; no `firstPartyClientId` constant exists yet (D2).
- No new production symbols, no signature changes, no new endpoints.

**Conditional future API surface** (not part of this change-set; the flip is enforced, not prose):

- **Required co-site of the sibling change-set:** `test/oidc_login_screen_client_id_test.dart` is in the sibling design's enumerated co-change list (§2 item 9 / §3.4) — its three literal sites (`:76` harness `defaultClientId:`, `:136/:158` `expect(lastClientId, …)`) are constantized to `SSOAdminClient.firstPartyClientId` in the same commit as the constant (sibling M2, both branches). After that commit the file derives its expectation from the constant (compile-time gate, §4.2). If the sibling lands first, the anchor implementation writes the constant reference directly and no literal ever lands. In **every** ordering, after both change-sets land, this file contains **no** `'sso-admin-console'` literal.
- If the value ever flips to `console` (sibling Branch A): atomic co-change of `sso_client.dart:86` + `app_router.dart:35` + `sso_client_test.dart:18` + `oidc_account_flow_test.dart:35,75,115,160` + this test file (already constantized — zero further edits) + **gate/yaml rows** (`implementation-gate.md:57` row 2 and `campaign-console-b6.yaml:37` flip to `console`; D15 — agreed with the sibling §3.6/§4.5) + the sibling's `test_config.py:44` / `README.md:17` / `DEPLOY.md:29`. The census test is value-agnostic (no client_id expectation) and unaffected by the flip; its conditional literal-census (REQ-4 item 6) tracks the constant's existence instead.

---

## 6. Compatibility constraints

1. **Zero production change** → no behavioral compatibility risk; all 31 baseline tests in the closest files verified green at HEAD (§1).
2. **New tests green at HEAD, before any B6-2 code change** — they are regression guards, not implementation tests; they must not be written against code that doesn't exist (D2: no `firstPartyClientId` import).
3. **`make test` / `flutter test` auto-discovery** — new files match `test/*_test.dart`; no runner edits (verified `Makefile:21`).
4. **Sibling landing order — enforced in every ordering, not prose** (mechanisms: §4.2 constant rule, §5 co-site, §10 AC-1 `test/` grep, REQ-4 item 6 literal-census):
   - *Sibling lands first:* REQ-2's file is written against `SSOAdminClient.firstPartyClientId` at all three sites — a compile-time gate: absent or renamed constant ⇒ the file does not compile ⇒ **red**, never a green tautology. A fresh literal instead of the constant reference is additionally caught by the AC-1 `test/` grep (zero `'sso-admin-console'` hits in `test/` once the constant exists) and by the census's conditional literal-census (REQ-4 item 6), both of which derive their expectation from the constant's existence.
   - *This change-set lands first:* the sibling's M2 commit constantizes this file's three sites in the same commit (its co-change list, sibling §2 item 9 / §3.4) — after M2 the file references the constant, so the forbidden state (literal + constant both present) is structurally impossible in this file, and AC-1's `test/` grep flags any residual literal anywhere else.
   - *Branch A (flip to `console`) in either ordering:* the constant reference follows the flip automatically; the Branch-A grep guard (`'sso-admin-console'` in `lib/ test/` → 0 hits) cannot trip on this file because it carries no literal post-M2 (a same-commit co-site, not an out-of-change-set file).
   - **Forbidden state after both land is enforced by three independent gates:** (a) the compile-time gate — the file's expectations reference the constant, so deleting/renaming it is a compile failure; (b) the AC-1 grep guard over `test/` — pinned-sites allowlist before M2, **zero hits after M2**; (c) the census literal-census — auto-flips to "zero literals in `test/`" the moment `firstPartyClientId` appears in `lib/api/sso_client.dart`. There is **no ordering that lands green-silent** (the Branch-A tautology — harness-injected `defaultClientId` keeping a stale literal green while the product ships `console` — is closed by same-commit constantization, and a stale literal trips (b)/(c) immediately) **and no ordering that lands red-blocking** (the sibling's Branch-A guard no longer trips on a file outside its change-set, because the file is in its co-change list and is constantized in the same commit).
5. **Drill compatibility** — this change-set neither creates nor modifies `tests/integration/audit_login_drill.py` or its `run_all.py:169` / `full_stack_verify.py:113` wiring (D3). The device-lens drill's `AGREED_CLIENT_ID` switch is unaffected (this design pins Branch B; a Branch A flip must co-change the drill's switch line — already documented in the drill header). **Fragility (D3):** the drill is untracked and the wiring is an uncommitted diff — `git clean -f` / `git checkout --` on `tests/integration/run_all.py tests/integration/full_stack_verify.py` removes the premise; the sibling change set must `git add` the drill and the wiring diff at its M4 step, before any tree cleanup.
6. **Census-test coupling is intentional** — line pins break on any refactor of the choke point; that breakage is the contract enforcement, not a bug (D13).
7. **Test isolation** — widget test must not depend on `BrowserNavigation` web behavior (VM stub, D6) and must close `api` in teardown (mirrors challenge-flow test) to avoid dangling timeout futures.

---

## 7. Failure modes and mitigations

| # | Failure mode | Detection | Mitigation (built into the design) |
|---|---|---|---|
| F1 | Probe POST counted as a login request → REQ-3 count off by one | Case 1 asserts `loginPosts == 0` after mount | D9 filter: path `/auth/login` AND `credential` is Map; documented in test comment |
| F2 | Silent-renewal or federated-resume auto-fire adds a login POST → count > 1 | Case 1's count assertion | D11: harness URL has no `prompt=none`, no fragment, no magic-link token; `_submitSilentRenewal` fires only under `_isRpFlow && _params.hasPromptNone` (`oidc_provider_flow.dart:33-36`) |
| F3 | Retry tap ignored while `_loading` disables the submit button → count stays 1 | Case 2 fails at `expect(loginPosts, 2)` | `pumpAndSettle()` after the 401 before the second submit (`_loading` cleared on failure) |
| F4 | Whole-body assertion brittleness (device_token/scope drift) → false failure | — | D10: partial assertion (`client_id` + `credential.username`); whole-body pin stays at API level (`sso_client_test.dart:16-22`) |
| F5 | Census false-positive from comments/strings containing `_handleSuccess` | — | D12: line-exact pins + content match at those lines + total count == 6; not substring counting |
| F6 | Census misses a *new* success path (e.g., new provider) → REQ-1 silently violated | Call-site count != 6 | D13: count assertion fails; the only way to land the path is to route through `_handleSuccess` and update the census deliberately |
| F7 | Future emission added outside `_handleSuccess` (per-path instrumentation) | Emission-string scan | REQ-4 item 5 fails on any `auth.login.success` in the module; REQ-1 names the sole allowed site (entry of `_handleSuccess`, before its seven branches — D4) |
| F8 | Emission placed inside one of `_handleSuccess`'s seven delivery branches → missed or double-emitted on JARM/form-post paths | Not directly testable (no emission exists) | D4: design rule pins the insertion point at function entry, after controller clears, before first branch |
| F9 | yaml reconciliation missed → stale `client_id=console` prompt regenerates a wrong-direction analysis | AC-1 grep guard | REQ-0 testable grep: zero `client_id=console` hits in the yaml |
| F10 | Sibling constant lands and REQ-2 literal diverges | AC-1 grep guard now covers `test/` (zero-literal post-M2, §10) + census literal-census (auto-flip on the constant's existence, REQ-4 item 6) + compile-time gate (file references the constant post-M2, §4.2) | §6.4 ordering matrix; co-change rule in §5 |
| F11 | Tree cleanup (`git clean -f`, `git checkout --`) strips the untracked drill or its uncommitted wiring before the sibling change-set lands | M4 grep guard `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` fails | D3: sibling M4 commits the drill file + wiring diff first; this change-set never relies on the drill's presence |

---

## 8. Migration steps (ordered, each with a verification gate)

1. **Reconcile the stale prompt (REQ-0).** Edit `docs/campaigns/campaign-console-b6.yaml:37` (`client_id=console` → `client_id=sso-admin-console`).
   *Gate:* `grep -c "client_id=console" docs/campaigns/campaign-console-b6.yaml` → 0; `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` → hits `:57` unchanged; `grep -rn "'sso-admin-console'" test/` → exactly the pinned allowlist (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`) — the AC-1 `test/` census (§10).
2. **Add `test/oidc_login_screen_client_id_test.dart`** (REQ-2/REQ-3) per §4.2.
3. **Add `test/oidc_login_handle_success_census_test.dart`** (REQ-1/REQ-4) per §4.3.
   *Gate (2+3):* `flutter test test/oidc_login_screen_client_id_test.dart test/oidc_login_handle_success_census_test.dart test/sso_client_test.dart test/oidc_login_api_test.dart` → all green with **zero `lib/` edits**.
4. **Full-suite regression:** `make test` (Flutter + Python unit) — no failures beyond the baseline; the two new files are the only additions.
5. **Cross-instance doc fix (executed in this revision):** the **full 8-doc misquote sweep (D1)** is applied now, not deferred — all `b6-2-lib-*-client-id-alignment` spec+design files (six screens-family docs + the api pair) now quote the real `implementation-gate.md:57` text (`sso-admin-console`), the 6 vacuous Branch-B "amend the gate" narratives are corrected to "exception already recorded — no-op, verify only", the Branch-A narratives flip the gate row + yaml to `console` (D15), and the screens sibling's co-change list includes this lens's test file (§5/§6.4). Same change-set as the sibling: **adopt** `tests/integration/audit_login_drill.py` (untracked) + its existing `run_all.py:169` / `full_stack_verify.py:113` wiring (uncommitted diff) — commit both, never re-create or re-insert (D3).
6. **T-12 joint acceptance evidence** — collect AC-1…AC-4 (§10) outputs.

No data migration, no schema change, no server interaction, no feature flags (nothing to flip in production).

---

## 9. Rollback

Trivially reversible: delete the two test files and revert the yaml line. Zero runtime exposure because no production code, configuration, or endpoint changes. The gate row (contract authority) is never touched, so the contract record stays consistent under rollback.

---

## 10. Testable acceptance mapping (T-12 joint)

| # | Direction acceptance (preserved from analysis direction 0) | Testable form | Verdict target |
|---|---|---|---|
| AC-1 | Unit/payload-builder test asserts `client_id` equals the contract constant; `test/sso_client_test.dart:18` updated in the same change | REQ-2 widget test asserts `'sso-admin-console'` on the captured credential-bearing `/auth/login` body (D10 partial assertion) — expectation source per §4.2 constant rule (constant reference once it exists; literal at the three pinned sites until the sibling M2 co-site constantizes them). `sso_client_test.dart:18` already asserts the identical value — the "updated in the same change" clause is vacuous at HEAD (value unchanged); if it ever flips, §5 co-change rule. REQ-0 greps: gate `:57` hits `sso-admin-console`; yaml zero `client_id=console`; `lib/` literal census unchanged (`app_router.dart:35`, `sso_client.dart:86`); **`test/` literal census — `grep -rn "'sso-admin-console'" test/` → exactly the pinned allowlist (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`) while the constant is absent, → **zero hits once the sibling mechanism (M2) has landed** (all references constantized — §5/§6.4). | REQ-2 + REQ-0 |
| AC-2 | Regression: widget test completing `OidcLoginScreen` login with MockClient asserts exactly one login request per interactive submit | REQ-3: credential-filtered POST count == 1 after a single submit; == 2 cumulative after a 401-then-200 retry (D9 filter; probe excluded and asserted == 0 at mount) | REQ-3 |
| AC-3 | `_handleSuccess` is the only function that can observe terminal success (no per-path instrumentation) | REQ-4 census: 6 pinned call sites + adjacency rule (`if (outcome.ok) {` → `_handleSuccess(outcome);`, 6 pairs) + single declaration at `:8` + zero `_handleSuccess` in `oidc_account_flow.dart` + zero `auth.login.success` string in the module — green at HEAD with zero source edits | REQ-4 + REQ-1 |
| AC-4 | Sink-side row generation (`auth.login.success` row with matching client_id, 无重复) remains [proposed] | Not asserted in this repo. Delegated to bucket direction 3's drill manifest. Note (D3): a device-lens drill already exists (`tests/integration/audit_login_drill.py`, wired at `run_all.py:169` / `full_stack_verify.py:113` — untracked file, uncommitted wiring); this change-set adds no emission and no drill, so it cannot fabricate an edge. | [proposed] |

---

## 11. Open questions

1. **yaml reconciliation style (D14):** this design edits `campaign-console-b6.yaml:37` in place. The spec permits a `[SUPERSEDED by implementation-gate.md:57]` annotation instead; the batch owner picks. Edit is recommended: the REQ-0 grep guard (`client_id=console` → 0 hits) stays clean.
2. **Sibling design's stale gate quote (D1):** corrected when the sibling change-set lands; flagging here so it is not re-copied into future specs/designs.
3. **Sibling constant timing (D2):** if `SSOAdminClient.firstPartyClientId` lands before this change-set, REQ-2 references it instead of the literal; if this change-set lands first, the sibling's M2 commit constantizes this lens's test file in the same commit (its co-change list, §5). Both orderings are now **enforced** — §6.4 matrix: no ordering lands green-silent or red-blocking.
4. **Field finder for the password field:** the harness uses the established `find.widgetWithText(TextField, …)` pattern (verified for 'Username or email'); the exact password-field label must be confirmed from the widget tree at implementation time (i18n keys verified: `sign_in`, `username_or_email`).
