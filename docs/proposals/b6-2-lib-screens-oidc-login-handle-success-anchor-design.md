# B6-2 Design — `oidc_login` lens: `_handleSuccess` choke-point anchor + client_id decision pin

Module: `lib/screens/oidc_login` (analysis `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`, direction 1) · Direction: B6-2 (edge generation verification, `auth.login.success` / client_id) · Value: 9 · Risk reduction: 9 · Effort: 3 · Confidence: 10
Status: **design** — implementation of the requirements spec `docs/proposals/b6-2-lib-screens-oidc-login-handle-success-anchor-spec.md` (REQ-0 … REQ-5). **Revision 3** (synced with spec Revision 3): the guard tests the revision-1 design planned to *create* are **already committed at HEAD** (C1), the yaml reconciliation it planned as an edit is **already done** (C2), the drill it called "untracked with uncommitted wiring" is **committed** (C5 — revision-1 D3's git-clean fragility is moot), the acceptance mapping is re-based on the spec's 3-item table with **REQ-5 (topology group) as the only remaining implement work**, and the security-review pins land: **G3** corrects the boundary record (the no-wire-POST boundary is the PKCE **query** leg, whose one wire mutation is the same-origin `/token` exchange — re-scoped to the census's `_api.login`/`_api.mfaComplete` vocabulary; the fragment return is the census-covered continuation leg) and **G1/G2** add two presence-anchored choke-point-hygiene assertions to the topology group (zero `_api.` in the `_handleSuccess` slice; every blocked/error delivery tail followed by `return;`).
Sibling instance: `docs/proposals/b6-2-lib-screens-client-id-alignment-design.md` owns the `lib/screens`-wide constant extraction and Branch A/B gate. **That design has NOT landed at HEAD** (verified: zero `firstPartyClientId` hits in `lib/ test/`; no `test/client_id_contract_test.dart`) — this design therefore asserts the literal and documents the co-change rule for when the sibling lands. This design is **branch-neutral**: it pins `'sso-admin-console'` (Branch B) and makes the flip to Branch A a documented atomic co-change.

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

The requirements evidence (run artifact `docs/auto/runs/b6-2-anchor-edge-generation-verification-at-the--9ac33c6f/artifacts/requirements-10762e10/requirements.md`, spec Revision 2) was re-checked line-exact at HEAD `26782c5`. **All substantive claims hold, including every pinned line number.** Independent findings:

| Evidence claim | Verification result |
|---|---|
| `oidc_authorization_flow.dart:8` — `_handleSuccess` declaration | ✅ exact; first member of `_OidcAuthorizationFlow` (spans `:8-139`, seven terminal-delivery branches — D4). |
| Six call sites: `:242` (silent renewal), `:313` (password/TOTP/code/magic-link), `:379` (passkey), `oidc_challenge_flow.dart:150` (MFA), `:244` (consent), `oidc_provider_flow.dart:60` (federated) | ✅ all line-exact via `grep -n`; every `if (outcome.ok) {` at `:241,312,378,149,243,59` is immediately followed by `_handleSuccess(outcome);`. |
| `client_id` wire sites `:238/:295/:370` + `oidc_challenge_flow.dart:234` + `oidc_provider_flow.dart:54` — all send `_effectiveClientId` | ✅ all five line-exact. All seven success paths send `_effectiveClientId`. |
| `_effectiveClientId` getter `oidc_login_screen.dart:159-161`; URL-supplied `client_id` wins | ✅ exact (`:159` head, fallback `widget.defaultClientId ?? ''` at `:161`). |
| `app_router.dart:35` `defaultClientId: 'sso-admin-console'`; `sso_client.dart:86,92`; `sso_client_test.dart:18` | ✅ all exact (`sso_client_test.dart:18` = `'client_id': 'sso-admin-console',` in the whole-body assert at `:16-22`). |
| `implementation-gate.md:57` records **`client_id=sso-admin-console`** | ✅ exact — `sed -n 57p` matches the quoted row verbatim. The contract exception already exists; no gate edit under Branch B (D1/D15). |
| `campaign-console-b6.yaml:37` already reads `client_id=sso-admin-console` (C2) | ✅ exact — reconciliation is done; REQ-0 is grep-verify only. |
| Zero `auth.login.success` in `lib/` | ✅ confirmed (only the guard test's own needle at `test/oidc_login_handle_success_census_test.dart:97-101`). |
| Harness filter at `test/oidc_login_screen_client_id_test.dart:26-74` (D9 `credential`-map filter) | ✅ exact — `MockClient` harness spans `:26-74`; `isLogin = body['credential'] is Map; // D9 filter` at `:33`. |
| Probe POST `lib/api/oidc_login_api.dart:47-55` (no `credential`); `login` passthrough `:57-58`; shim `lib/screens/oidc_login/oidc_login_api.dart:3` (C4) | ✅ all exact. |
| **C1 — guard tests committed at `3b64c58`**, not working-tree changes | ✅ `git show 3b64c58` adds `test/oidc_login_handle_success_census_test.dart` (158 lines) + `test/oidc_login_screen_client_id_test.dart` (162 lines) + the drill + wiring. Working tree carries only `lib/screens/admin/audit_log_tab.dart` (B6-1a, unrelated). |
| **C3 — drill `[proposed]` fallback implemented** | ✅ `tests/integration/audit_login_drill.py:172-289`: Step 4 sets `proposed = True` ("sink legs marked [proposed] — no false PASS"), Step 5 skips no-duplicates when `proposed` (`:194`), read legs `:225-281`. |
| **C5 (NEW, corrects revision-1 D3) — the drill AND its wiring are committed, not untracked** | ✅ `git ls-files tests/integration/audit_login_drill.py` returns the path; `git log -1 -- tests/integration/audit_login_drill.py` = `3b64c58`; `git show 3b64c58 --stat` includes `tests/integration/full_stack_verify.py | 4 +` and `tests/integration/run_all.py | 5 +` (wiring at `run_all.py:169` / `full_stack_verify.py:113`). Revision-1 D3's "untracked file + uncommitted diff + `git clean` fragility" premise is **false at HEAD** — the adopt-never-re-create rule stands, but no tree-cleanup hazard exists. |
| **AC-1 executed: three-file command 26/26 green at HEAD, zero `lib/` edits** | ✅ re-executed: `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → **26/26 passed**. |
| **REQ-5 topology facts (spec §1, basis for the new group):** | |
| `_submitLogin` dispatch exclusivity `:266-274` — early `return;` after federated/passkey branches | ✅ exact: `:268` `_signInWithFederated(_provider);` → `:269` `return;`; `:272` `await _submitPasskeyLogin();` → `:273` `return;`. |
| One wire mutation per dispatch method | ✅ exact: `_api.login(` at `:239` (silent renewal), `:310` (`_submitLogin`), `:376` (passkey), `oidc_challenge_flow.dart:237` (consent), `oidc_provider_flow.dart:53` (federated); `_api.mfaComplete(` at `oidc_challenge_flow.dart:141` (MFA). Six methods, six single mutations. |
| Renewal never an interactive dispatch | ✅ exact: `_submitSilentRenewal` referenced at exactly one site, `oidc_provider_flow.dart:36` inside `_checkFederatedReturn` (`_isRpFlow && _params.hasPromptNone && flow == login` gate `:33-41`); `oidc_login_view_flow.dart:268` `onSubmit: _submitLogin,` is the only login submit handler (other submits: `:177` forgot-password, `:187` reset, `:198` signup, `:302` `_submitMfa` — the MFA phase's own single dispatch). |
| Documented boundary: PKCE query leg (**G3-corrected**) | ✅ The boundary is the **query** leg, not a fragment return: `_checkFederatedReturn` → `consumeReturnIfPresent` (`federated_login.dart:137`, `code`+`state` in the query string) → `_completeFirstPartyLogin(` at `oidc_provider_flow.dart:15-18` (call spans `:15-18`; spec's `:13-18` range is a minor prose drift, no acceptance impact) → immediate `return;` at `:19`. Its **one wire mutation is the same-origin `/token` exchange** (`federated_login.dart:197-201`, `grant_type=authorization_code` + `code_verifier`); the "no wire POST" characterization holds **only under the census's `_api.login`/`_api.mfaComplete` vocabulary**, under which this leg is mutation-free, and it never reaches `_handleSuccess`. The census-covered **fragment** return is the continuation leg: route-fragment `login_transaction_id` (`oidc_login_screen.dart:101` → `hostedFederatedTransactionId`, `federated_login.dart:18-27`) → `_resumeFederatedAuthorization` (`oidc_provider_flow.dart:47-77`) → `_api.login` POST (`:53`) → `_handleSuccess` (`:60`, census site #6). |
| Non-terminal `outcome.ok` uses | ✅ `_sendProviderCode` `:341-342` (assignment), probe `:279` (compound `if (outcome.ok && …)`), account actions `oidc_account_flow.dart:76,182` (reset-password / email-verify) + compounds `:126,131` (email-verify status — excluded by the adjacency rule's exact-form pattern). |

**Corrections carried into this revision (C1–C5):** C1 guard tests committed at `3b64c58`; C2 yaml `:37` already reconciled; C3 drill `[proposed]` fallback already implemented; C4 `oidc_login_api.dart` re-export shim; **C5 (new)** drill + wiring committed — revision-1 D3's fragility premise is superseded (the design's adopt rule and §6.5 stand, the cleanup hazard does not).

**G3 (NEW, boundary record corrected — §1/§4.4/§10):** the revision-2 "fragment-return federated path … without a wire POST" label described the wrong leg. The **fragment** return is the census-covered continuation leg `_resumeFederatedAuthorization` (`oidc_provider_flow.dart:47-77`) → `_api.login` POST (`:53`) → `_handleSuccess` (`:60`), fired when the route fragment carries `login_transaction_id` (`federated_login.dart:18-27`, consumed at `oidc_login_screen.dart:101`); the documented no-wire-POST boundary is the PKCE **query** leg (`consumeReturnIfPresent`, `federated_login.dart:137`) whose **one wire mutation is the same-origin `/token` exchange** (`:197-201`, `grant_type=authorization_code` + `code_verifier`) — the "no wire POST" claim holds only under the census's `_api.login`/`_api.mfaComplete` vocabulary. The topology group additionally gains **G1** (zero `_api.` references in the `_handleSuccess` slice) and **G2** (every blocked/error delivery tail followed by `return;`), both presence-anchored (§4.4 assertions 5-6; F17/F18).

---

## 2. Design summary

**Files touched: 1 test file extended. Zero production code changes. Zero new files. No API changes. No drill edits.**

| # | File | Change | Requirement |
|---|---|---|---|
| 1 | `test/oidc_login_handle_success_census_test.dart` | **Add a `topology (REQ-5)` group** (≈95 lines): per-method `_handleSuccess` uniqueness, `_submitLogin` dispatch exclusivity, one wire mutation per dispatch method, renewal never an interactive dispatch, choke point request-free (G1), delivery tails terminate (G2) | REQ-5 |

Landed at HEAD (C1), taken as-is: `test/oidc_login_screen_client_id_test.dart` (REQ-2/REQ-3), the census group + literal-census group inside file #1 (REQ-1/REQ-4), `docs/campaigns/campaign-console-b6.yaml:37` (REQ-0 — C2). Untouched on purpose: `docs/campaigns/implementation-gate.md` (already records the exception), `test/sso_client_test.dart` (already asserts `sso-admin-console`), `tests/integration/audit_login_drill.py` + its `run_all.py:169` / `full_stack_verify.py:113` wiring (committed at `3b64c58` — C5; adopt, never re-create), `lib/` entirely.

---

## 3. Key decisions

- **D7 — No production code lands.** REQ-0 is a decision record, not a value change; the gate already records the exception. Shipping zero `lib/` edits makes the change-set trivially reviewable, reversible, and unable to affect login behavior. The regression value is carried entirely by tests that must be green **at HEAD before any future B6-2 code change**.
- **D8 — REQ-5 lives in the existing census test file.** It shares the file's `linesOf` helper and the three `flowFiles` constants; a separate file would duplicate the module-path fixture and split the choke-point guard story.
- **D16 — REQ-5 assertions are structural, not runtime.** The topology group reads the three flow files (established File-IO pattern, same as the census group) and asserts the verified facts (§1). No widget harness: the widget test already proves exactly-one-credential-POST-per-submit behaviorally (REQ-3); the topology group proves the *reachability* invariant that a behavioral test cannot (dispatch exclusivity, renewal non-interactivity).
- **D17 — Method slicer is brace-balanced, anchored on signature lines.** Extract each method body by scanning for a signature line of the form `^[ \t]+(Future<void>|Future<bool>|void|Future<.*>) \w+\(` ending in `{` (or `async {`), then count `{`/`}` to the balancing close. The six dispatch methods all use the 2-space-indent `Future<void> _name(...) async {` shape (verified §1); `if (`/`for (`/`switch (` lines are excluded by the signature prefix. Single-line getters (`String get _effectiveClientId => …`) contain no `{` and are skipped. Fallback: if the slicer ever fails to balance (e.g., a `{` inside a string literal), the group's reason text names the method by its pinned call-site line — the test fails loudly, never silently.
- **D9 — Counting rule: path + `credential`-key filter** (landed at HEAD with REQ-2/REQ-3): a "login request" is a POST to `/auth/login` whose decoded body contains a `credential` map. Excludes the mount probe and `sendCode` traffic. Unchanged in this revision.
- **D11 — Harness avoids auto-fire paths** (landed at HEAD): no `prompt=none`, no fragment, no magic-link token. Unchanged.
- **D12 — Census adjacency rule is syntactic, not semantic** (landed at HEAD): exact form `if (outcome.ok) {`, next non-empty line `_handleSuccess(outcome);`, exactly 6 pairs. The REQ-5 group's per-method uniqueness extends the same principle from pair-level to method-level.
- **D13 — Line pins are the contract, not incidental test data.** REQ-5's topology assertions pin *structure* (early returns, single wire mutation) rather than raw line numbers where a refactor should be tolerated only via conscious update — same enforcement philosophy as the census pins.
- **D14 — yaml reconciliation already executed (C2); no edit remains.** REQ-0's grep guard (`client_id=console` → 0 hits in the yaml) is the acceptance.
- **D18 — The REQ-5 group must pass at HEAD with zero source edits.** It is written against the verified topology (§1) and lands as a pure test addition; any failure at implementation time means the topology facts drifted, not that the code needs touching.
- **D4 — future-emission insertion point** (carried from revision 1): any future client-side emission belongs at `_handleSuccess` entry, before its seven delivery branches (`:8-139`).

---

## 4. Detailed design

### 4.1 REQ-0 — decision pin (grep-verify only, C2)

- **No change** to `docs/campaigns/implementation-gate.md:57` — already records `边缘生成验证：login → auth.login.success（client_id=sso-admin-console）| sink 出现 sso-admin-console login 事件；无重复 | B4-5`.
- **No change** to `docs/campaigns/campaign-console-b6.yaml:37` — already reads `client_id=sso-admin-console` (C2).
- Grep guards (§10 AC-1): gate `:57` hits `sso-admin-console`; yaml has zero `client_id=console`; `lib/` still has `'sso-admin-console'` at `app_router.dart:35` + `sso_client.dart:86`; `test/` literal census equals the pinned allowlist (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`) while the sibling constant is absent → zero hits after the sibling M2 lands (REQ-4 item 6 auto-flips).

### 4.2 REQ-2 + REQ-3 — `test/oidc_login_screen_client_id_test.dart` (landed at HEAD, C1)

Taken as-is: MockClient harness at `:26-74` (D9 filter `:33`), Case 1 single submit → exactly 1 credential-bearing POST with `'client_id': 'sso-admin-console'` (expects at `:136`, `:158`; harness `defaultClientId:` at `:76`), Case 2 retry after 401 → cumulative 2. Constant rule (enforced, not prose): the file's three literal sites reference `SSOAdminClient.firstPartyClientId` iff the sibling constant exists at implementation time — a compile-time gate; otherwise the literal stays and the sibling's M2 commit constantizes all three sites in the same commit (sibling design §2 item 9 / §3.4; this file is on its co-change list).

### 4.3 REQ-1 + REQ-4 — census group + literal-census group (landed at HEAD, C1)

Taken as-is: single declaration at `:8`; exactly 6 call sites at the pinned lines; adjacency rule (6 pairs, exact form); account-flow isolation; zero `auth.login.success` in the module; conditional literal-census (expectation derives from `firstPartyClientId` existence).

### 4.4 REQ-5 — topology group (NEW; the only implement work)

Add to `test/oidc_login_handle_success_census_test.dart`, after the existing census group:

```dart
group('single-emission topology (REQ-5)', () {
  // D17: brace-balanced method slicer over the three flow files.
  // Returns (name, startLine, endLine, bodyLines) for every method whose
  // signature matches `Future<void>|Future<bool>|void|Future<…> name(…`
  // (2-space indent; single-line getters have no `{` and are skipped).
  final methods = <String, List<List<String>>>{}; // path -> [name, start, end, body]

  test('per-method uniqueness: one `_handleSuccess(` per dispatch method', () {
    // Every method body containing `_handleSuccess(outcome);` contains
    // exactly one `_handleSuccess(` reference — a method dispatching
    // success twice (fall-through double POST) fails here.
  });

  test('_submitLogin dispatch exclusivity: early return after federated/passkey',
      () {
    // In the _submitLogin body: the next non-empty line after
    // `_signInWithFederated(_provider);` is `return;` (verified :269);
    // same for `await _submitPasskeyLogin();` → `return;` (verified :273).
    // No fall-through to the primary login POST.
  });

  test('one wire mutation per dispatch method', () {
    // Each of the six methods containing a call site contains exactly one
    // `_api.login(` or `_api.mfaComplete(` — one request per method ⇒ at
    // most one terminal-success observation per method (verified :239,
    // :310, :376, challenge :141, :237, provider :53).
  });

  test('renewal is never an interactive dispatch', () {
    // `_submitSilentRenewal` appears at exactly one call site in the
    // module: oidc_provider_flow.dart:36 inside `_checkFederatedReturn`
    // (mount-time, prompt=none gate). No `onSubmit:` line references it;
    // `onSubmit: _submitLogin,` occurs exactly once (view_flow:268) and
    // `onSubmit: _submitMfa,` exactly once (view_flow:302, MFA phase's own
    // single dispatch).
  });

  test('_handleSuccess is request-free: zero `_api.` in its slice (G1)', () {
    // Presence-anchored: the D17 slice of the declaring method
    // (authorization_flow:8-139) must be non-empty and contain the
    // `void _handleSuccess(` line BEFORE the zero-count assert — a slicer
    // miss or renamed declaration turns red, never vacuously green. A wire
    // added inside the choke point fails here (nearest `_api.` today is
    // authorization_flow:239, outside the slice).
  });

  test('delivery tails terminate: blocked/error branches always return (G2)',
      () {
    // Presence-anchored: assert the exact tail inventory first — 4
    // `_authorizationDeliveryBlocked();` (:66/:80/:101/:132) and 4
    // `_error`-assigning `_update(...)` statements (:28/:40/:54-58, plus the
    // function-final :135-138) — then for every tail whose terminating `;`
    // is not the function-final statement, the next non-empty line is
    // `return;`. Removing a `return;` or a tail turns red.
  });
});
```

Assertion details:

1. **Per-method uniqueness:** slice the three flow files (D17). For each method body that contains `_handleSuccess(outcome);`, assert `'_handleSuccess('` occurs exactly once in the body. Fails if a method observes terminal success twice (e.g., `_submitLogin` calling `_handleSuccess` and then falling through to another POST whose success also calls it).
2. **Dispatch exclusivity in `_submitLogin`:** within the `_submitLogin` body, locate the line containing `_signInWithFederated(_provider);` — the next non-empty line must be `return;`; locate `await _submitPasskeyLogin();` — same. This is the structural form of the verified `:268-274` facts; a refactor that inlines either dispatch into a shared helper without the early return fails here (the conscious-update rule, D13).
3. **One wire mutation per dispatch method:** each of the six methods identified in (1) contains exactly one occurrence of `_api.login(` or `_api.mfaComplete(`. This closes the "one request per method" premise that bounds terminal-success observation to one per interactive submit.
4. **Renewal never an interactive dispatch:** module-wide scan — `_submitSilentRenewal` has exactly one call site (`oidc_provider_flow.dart:36`); `oidc_login_view_flow.dart` contains `onSubmit: _submitLogin,` exactly once (`:268`) and `onSubmit: _submitMfa,` exactly once (`:302`); no `onSubmit:` line contains `_submitSilentRenewal` (implied by the one-call-site assertion, asserted explicitly for the reason text).
5. **Choke point request-free (G1, presence-anchored):** slice the declaring method (D17 signature `void _handleSuccess(`, authorization_flow:8-139) and assert the slice contains **zero** `_api.` references (verified at HEAD: nearest `_api.` site is `:239`, outside the slice). Anchor: assert the slice is non-empty **and** contains the `void _handleSuccess(` declaration before the zero-count assert — a wire added inside the choke point (exactly the double-request vector AC-2 targets; all four assertions above scan dispatch methods only and would stay green), a slicer miss, or a renamed declaration all turn red (REQ-4's declaration census `:8` backstops the rename).
6. **Delivery tails terminate (G2, presence-anchored):** within the `_handleSuccess` slice, assert the exact tail inventory — 4 `_authorizationDeliveryBlocked();` (`:66/:80/:101/:132`) and 4 `_error`-assigning `_update(...)` statements (`:28`, `:40`, `:54-58`, plus the function-final `:135-138`) — then for every tail whose terminating `;` is not the function-final statement, the next non-empty line is `return;`. Statement-based matching (scan from `_update(`/`_authorizationDeliveryBlocked()` to the terminating `;` at depth 0) so the multi-line tails (`:54-58`, `:135-138`) count once. The exact counts anchor presence: a removed `return;` (success-after-failure / double-delivery fall-through), a removed or added tail, or a matcher typo all turn red — no vacuous pass.

**Documented boundary (recorded, not asserted — G3-corrected):** the boundary is the PKCE **query** leg (`_checkFederatedReturn` → `consumeReturnIfPresent`, `federated_login.dart:137` — `code`+`state` in the query string — → `_completeFirstPartyLogin`, `oidc_provider_flow.dart:15-18`, immediate `return;` at `:19`). Its **one wire mutation is the same-origin `/token` exchange** (`federated_login.dart:197-201`, `grant_type=authorization_code` + `code_verifier`); the "no wire POST" characterization holds **only under the census's `_api.login`/`_api.mfaComplete` vocabulary**, under which this leg is mutation-free, and it never reaches `_handleSuccess` — outside the six-path census by construction and single-completes via its immediate `return;`. The census-covered **fragment** return is the continuation leg `_resumeFederatedAuthorization` (`oidc_provider_flow.dart:47-77`; `_api.login` POST `:53`; `_handleSuccess` `:60`), fired from `_checkFederatedReturn` `:8` when the route fragment carries `login_transaction_id` (`federated_login.dart:18-27`, consumed at `oidc_login_screen.dart:101`). Any future instrumentation of the PKCE leg must be a conscious, reviewed change (it would not trip the census call-site count, and the topology group's assertions do not cover it because it never reaches `_handleSuccess`).

**Testable:** `flutter test test/oidc_login_handle_success_census_test.dart` green at HEAD with zero source edits (D18); combined acceptance command in §10 AC-1.

---

## 5. API changes

**None.** Explicit inventory of what does *not* change and why:

- `OidcLoginApi.login(Map<String, dynamic>)` — passthrough unchanged; covered at `test/oidc_login_api_test.dart:76`.
- `OidcLoginApi.probeProviders(String clientId, {String? loginHint})` — unchanged; the REQ-3 filter relies on its no-`credential` body.
- `OidcLoginScreen.defaultClientId` — unchanged; value source stays `app_router.dart:35`.
- `SSOAdminClient.login` — unchanged; no `firstPartyClientId` constant exists yet (D2).
- No new production symbols, no signature changes, no new endpoints. REQ-5 adds a test-only group — zero API surface.

**Conditional future API surface** (not part of this change-set; the flip is enforced, not prose): unchanged from revision 1 — the sibling's `SSOAdminClient.firstPartyClientId` constant co-change (`test/oidc_login_screen_client_id_test.dart` three sites constantized in the sibling M2 commit; §6.4 ordering matrix) and the Branch-A atomic flip (`sso_client.dart:86` + `app_router.dart:35` + `sso_client_test.dart:18` + `oidc_account_flow_test.dart:35,75,115,160` + this lens's test file (already constantized — zero further edits) + gate/yaml rows `implementation-gate.md:57` / `campaign-console-b6.yaml:37` flip to `console` (D15) + the drill's `AGREED_CLIENT_ID` switch + sibling `test_config.py:44` / `README.md:17` / `DEPLOY.md:29`). The census and topology groups are value-agnostic and unaffected by the flip.

---

## 6. Compatibility constraints

1. **Zero production change** → no behavioral compatibility risk; all 26 acceptance-file tests verified green at HEAD (§1), full baseline untouched.
2. **New test code green at HEAD, before any B6-2 code change** — the topology group is a regression guard, not an implementation test; it must pass immediately (D18). It is written against the verified topology (§1) and must not reference symbols that don't exist (no `firstPartyClientId` import — D2).
3. **`make test` / `flutter test` auto-discovery** — no new files, no runner edits; the topology group rides inside the existing census test file.
4. **Sibling landing order — enforced in every ordering, not prose** (unchanged from revision 1; mechanisms: §4.2 constant rule, §5 co-site, §10 AC-1 `test/` grep, REQ-4 item 6 literal-census). REQ-5 adds no ordering sensitivity: the topology group scans method shapes (`_signInWithFederated`, `_submitPasskeyLogin`, `_submitSilentRenewal`, `_api.login`, `_api.mfaComplete`), none of which the sibling constant extraction touches.
5. **Drill compatibility** — this change-set neither creates nor modifies `tests/integration/audit_login_drill.py` or its `run_all.py:169` / `full_stack_verify.py:113` wiring. **C5 (revises revision-1 §6.5):** both are **committed at `3b64c58`** — the `git clean` / `git checkout` fragility documented in revision 1 **no longer exists**; the adopt-never-re-create rule stands for the sibling change-set (its M-step `git add` is a no-op), and this change-set never relies on the drill's presence either way. The drill's `[proposed]` fallback (C3) is verified.
6. **Census-test coupling is intentional** — line pins break on any refactor of the choke point; that breakage is the contract enforcement, not a bug (D13). The topology group adds structural pins (early returns, single wire mutation) that break on dispatch-shape refactors — same intent.
7. **Test isolation** — the topology group is pure File IO (no widget harness, no timers, no `api.close()` concern); it must stay in the `@TestOn('vm')` file scope already declared at the top of the census test.

---

## 7. Failure modes and mitigations

Carried from revision 1 (all still live; F11 revised by C5):

| # | Failure mode | Detection | Mitigation (built into the design) |
|---|---|---|---|
| F1 | Probe POST counted as a login request → REQ-3 count off by one | Case 1 asserts `loginPosts == 0` after mount | D9 filter (landed at HEAD) |
| F2 | Silent-renewal or federated-resume auto-fire adds a login POST → count > 1 | Case 1's count assertion | D11 harness URL (landed at HEAD) |
| F3 | Retry tap ignored while `_loading` disables the submit button → count stays 1 | Case 2 fails at `expect(loginPosts, 2)` | `pumpAndSettle()` after the 401 (landed at HEAD) |
| F4 | Whole-body assertion brittleness (device_token/scope drift) → false failure | — | D10 partial assertion (landed at HEAD) |
| F5 | Census false-positive from comments/strings containing `_handleSuccess` | — | D12 line-exact pins + total count (landed at HEAD) |
| F6 | Census misses a *new* success path → REQ-1 silently violated | Call-site count != 6 | D13 count assertion (landed at HEAD) |
| F7 | Future emission added outside `_handleSuccess` (per-path instrumentation) | Emission-string scan | REQ-4 item 5 (landed at HEAD); REQ-1 names the sole allowed site (D4) |
| F8 | Emission placed inside one of `_handleSuccess`'s seven delivery branches → missed or double-emitted | Not directly testable (no emission exists) | D4 design rule pins the insertion point at function entry |
| F9 | yaml reconciliation missed → stale `client_id=console` prompt regenerates a wrong-direction analysis | AC-1 grep guard | C2 — already reconciled; grep is the acceptance |
| F10 | Sibling constant lands and REQ-2 literal diverges | AC-1 `test/` grep + census literal-census + compile-time gate | §6.4 ordering matrix (unchanged) |
| F11 | Drill drift / re-creation by a sibling change-set | M4 grep guard `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` | **C5 (revised):** drill + wiring committed at `3b64c58` — no cleanup hazard; adopt-never-re-create rule; this change-set makes zero drill edits |

New for REQ-5:

| # | Failure mode | Detection | Mitigation (built into the design) |
|---|---|---|---|
| F12 | Brace-balanced slicer mis-slices a method (brace in comment/string, multi-line signature) → wrong body boundaries → false failure | Topology group red at implementation time | D17: signature-line anchoring + `{`/`}` depth count; six dispatch methods verified to use the 2-space `Future<void> _name(…) async {` shape (§1); reason text names the pinned call-site line when a method fails to balance — loud, never silent |
| F13 | Topology false PASS: per-method uniqueness counts the census group's own scanning or counts `_handleSuccess` in a *called* helper rather than the method body | — | D17: uniqueness counted only within the sliced method body (not module-wide); helper calls are separate methods with their own slices — a helper observing success is itself a method containing `_handleSuccess(` and is caught by (1) |
| F14 | `_submitLogin` dispatch refactored (dispatch inlined into a shared helper without early return) → double-dispatch risk regresses silently | Topology test 2 fails on the exact-line rule | The failure *is* the enforcement (D13): the refactor must consciously preserve the early-return topology and update the test, or be rejected |
| F15 | Silent renewal wired to a new interactive handler (e.g., a retry button calling `_submitSilentRenewal`) → renewal becomes an interactive dispatch | Topology test 4 fails (call-site count != 1 / `onSubmit:` reference) | Asserted: exactly one `_submitSilentRenewal` call site (provider_flow:36); `onSubmit:` lines never reference it |
| F16 | A seventh success path added that reaches `_handleSuccess` (e.g., a new provider) → census count 6 fails and topology method-uniqueness may or may not trip | Census group red | Both groups fail together, forcing the conscious census update and the topology review — the choke-point contract (REQ-1) stays intact by construction |
| F17 | G1 vacuous pass: `_handleSuccess` slice not found (slicer miss, renamed declaration) → "zero `_api.`" passes with no body scanned | Topology test 5 red | G1 presence anchor: slice non-empty + contains the `void _handleSuccess(` declaration before the zero-count assert; REQ-4's declaration census (`:8`) backstops |
| F18 | G2 vacuous pass or silent drift: tail matcher matches nothing (regex typo), a `return;` removed from a blocked/error branch, or a tail added without `return;` | Topology test 6 red | G2 exact-count anchors (4 `_authorizationDeliveryBlocked();` + 4 `_error`-assigning `_update(...)`) + statement-terminating-`;` adjacency rule; function-final statement exempt |

---

## 8. Migration steps (ordered, each with a verification gate)

1. **Add the REQ-5 topology group** to `test/oidc_login_handle_success_census_test.dart` (§4.4). No other code change: REQ-0 is grep-verify (C2), REQ-2/REQ-3/REQ-4 landed (C1).
   *Gate:* `flutter test test/oidc_login_handle_success_census_test.dart` → all green with **zero `lib/` edits** (D18); the group's six tests appear in the runner output.
2. **Grep verification (REQ-0):** `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` → hits `:57`; `grep -n "client_id=console" docs/campaigns/campaign-console-b6.yaml` → 0 hits; `grep -rn "'sso-admin-console'" lib/` → `app_router.dart:35` + `sso_client.dart:86`; `grep -rn "'sso-admin-console'" test/` → exactly the pinned allowlist (pre-sibling) / zero hits (post-sibling M2).
3. **Acceptance command (AC-1):** `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → **26 + 4 = 30/30 green**.
4. **Full-suite regression:** `make test` (Flutter + Python unit) — no failures beyond the baseline; the only addition is the topology group inside an existing test file.
5. **T-12 joint acceptance evidence** — collect AC-1…AC-3 (§10) outputs. Sibling change-set, separately: adopt the drill (already committed — C5; `git add` no-op), land the constant extraction per its own M-steps, execute the 8-doc sweep (revision-1 D1 — already applied to the sibling docs at `26782c5`; verified by the `sso-admin-console` sweep grep at the sibling gate).

No data migration, no schema change, no server interaction, no feature flags.

---

## 9. Rollback

Trivially reversible: delete the topology group from the census test file (reverts to the revision-1 test state, which is itself the landed-at-HEAD state plus the group). Zero runtime exposure because no production code, configuration, or endpoint changes. The gate row (contract authority) is never touched, so the contract record stays consistent under rollback.

---

## 10. Testable acceptance mapping (T-12 joint, spec Revision 2 table)

| # | Direction acceptance (preserved) | Testable form | Verdict target |
|---|---|---|---|
| AC-1 | (1) `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` green at HEAD with zero lib/ edits — census = exactly 6 `_handleSuccess(outcome);` call sites, single declaration, zero `auth.login.success` literal in `lib/screens/oidc_login/`, MockClient-captured login body decodes to `'client_id':'sso-admin-console'` with exactly one credential-bearing POST per submit (probe excluded via `body['credential']` map filter, harness `test/oidc_login_screen_client_id_test.dart:26-74`) | **Executed at HEAD — 26/26 green, zero `lib/screens/oidc_login/**` edits** (C1). Re-executed at design stage: 26/26. REQ-2 + REQ-3 + REQ-4 + REQ-0 greps (§8 steps 2-3). After step 1: 30/30. | REQ-2 + REQ-3 + REQ-4 + REQ-0 |
| AC-2 | (2) extend the census to assert single-emission topology: at most one `_handleSuccess` reachable per successful interactive submit (no double-dispatch across the renewal/login/passkey paths) | **REQ-5 — the only implement work.** Topology group in `test/oidc_login_handle_success_census_test.dart` (§4.4): per-method `_handleSuccess` uniqueness (D17 slicer), `_submitLogin` dispatch exclusivity (early `return;` after federated/passkey branches — verified `:269/:273`), one wire mutation per dispatch method (six methods, six single `_api.login(`/`_api.mfaComplete(`), renewal never an interactive dispatch (`_submitSilentRenewal` call-site count == 1, provider_flow:36; `onSubmit: _submitLogin,` exactly once at view_flow:268). Green at HEAD with zero source edits. Choke-point hygiene (G1/G2): the `_handleSuccess` slice (authorization_flow:8-139) contains zero `_api.` references, and all 8 blocked/error delivery tails are followed by `return;` (function-final exempt) — both presence-anchored. PKCE query leg (`_completeFirstPartyLogin`, provider_flow:15-18 → same-origin `/token` exchange, federated_login.dart:197-201) recorded as documented boundary under the census `_api.login`/`_api.mfaComplete` vocabulary (G3), not asserted. | REQ-5 |
| AC-3 | (3) sink-side single-row observation (exactly one sso-admin-console event, 无重复) is **[proposed]** — requires the deployed stack via `tests/integration/audit_login_drill.py` and must be marked [proposed] in the drill output rather than faked when the sink leg is unobservable | Not asserted in this repo. Delegated to the drill (committed at `3b64c58` — C5; `[proposed]` fallback verified at `:172-289` — C3). This change-set adds no emission and no drill edits — it cannot fabricate an edge. | [proposed] |

---

## 11. Open questions

1. **Sibling constant timing (D2):** if `SSOAdminClient.firstPartyClientId` lands before this change-set, REQ-2's three sites reference it; if this change-set lands first, the sibling's M2 commit constantizes them in the same commit. Both orderings enforced (§6.4). REQ-5 is ordering-independent.
2. **Drill ownership (C5):** the drill and its wiring are committed at `3b64c58` (revising revision-1 D3). The sibling change-set's "adopt" M-step is a no-op `git add`; the drill's `AGREED_CLIENT_ID` switch remains the Branch-A co-change site. No batch-owner action needed for this lens.
3. **Topology slicer robustness (D17/F12):** the brace-balanced slicer is written against the six verified method shapes; a future multi-line signature or brace-in-string would fail loudly (reason text names the pinned call-site line). No action needed at design time.
4. **`_submitMfa` status:** `oidc_login_view_flow.dart:302` wires the MFA phase's submit to the challenge-flow MFA dispatch — a *second-phase* interactive submit, not a duplicate of the login submit; the census counts its `_handleSuccess` site (`oidc_challenge_flow.dart:150`) once, and the topology group's per-method uniqueness + single-wire-mutation assertions bound it to one observation per submit. The spec's REQ-5 item 4 wording ("`_submitLogin` is the only interactive entry") covers the *renewal* non-interactivity claim; the MFA submit is a distinct phase, documented here for the implementer so the topology group's `onSubmit: _submitMfa,` assertion reads as intentional.
