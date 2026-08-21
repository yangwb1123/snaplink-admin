# B6-2 Requirements Specification — Pin the client_id decision + anchor edge-verification at `_handleSuccess`

Module: `lib/screens/oidc_login` (analysis bucket `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`, direction 1) · Direction: B6-2 (edge generation verification, `auth.login.success` / client_id) · Value: 9 · Risk reduction: 9 · Effort: 3 · Confidence: 10
Status: implemented and verified (2026-08-20; Branch B decision preserved). REQ-0 through REQ-5 are covered by the current constant-backed census and single-emission topology guard; the sink-side observation remains explicitly [proposed] when the deployed stack is unavailable.
Sibling instance: `docs/proposals/b6-2-lib-screens-client-id-alignment-spec.md` (+ `-design.md`) owns the `lib/screens`-wide `client_id` single-source-of-truth constant (its REQ-1) and the Branch A/B decision gate (its REQ-0). This spec is the **`lib/screens/oidc_login` lens**: it pins the decision for this module's wire, and adds what the screens bucket does not own — the `_handleSuccess` terminal-success choke point contract and its regression guard. Where the two overlap (constant value, `test/sso_client_test.dart:18`), both name the same artifacts.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. **All substantive claims hold** (the direction's gate quote is exact — the earlier direction's misquote was corrected in revision 1; revision 2 adds C1–C4 below).

| Direction citation | Verification result |
|---|---|
| `oidc_authorization_flow.dart:8` — `_handleSuccess` | **Exact.** `void _handleSuccess(LoginOutcome outcome) {` is the first member of the `_OidcAuthorizationFlow` extension (`:7-9`). It is the module's only terminal-success handler. |
| `oidc_authorization_flow.dart:242, :313, :379` — silent renewal / login / passkey call sites | **Exact.** `:242` in `_submitSilentRenewal` (`:229-244`), `:313` in `_submitLogin` (`:266-313`), `:379` in `_submitPasskeyLogin` (`:351-379`) — each `if (outcome.ok) { _handleSuccess(outcome); }`. |
| `oidc_challenge_flow.dart:150, :244`; `oidc_provider_flow.dart:60` — MFA / consent / federated call sites | **Exact.** `:150` in the MFA-complete submit (`:141-150`), `:244` in the consent-decision submit (`:237-244`), `:60` in `_resumeFederatedAuthorization` (`:47-60`, fired from `_checkFederatedReturn` `:8`). All are `if (outcome.ok) { _handleSuccess(outcome); }`. |
| `oidc_login_screen.dart:159-160` — `_effectiveClientId` | **Exact** (spans `:159-161`). `String get _effectiveClientId => _params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '');` — URL-supplied `client_id` wins; the first-party default comes from `widget.defaultClientId`. |
| payload built at `oidc_authorization_flow.dart` ~283 with `payload['client_id'] = _effectiveClientId` | **Line correction.** The exact sites are `:238` (`_submitSilentRenewal`), `:295` (`_submitLogin`), `:370` (`_submitPasskeyLogin`). Two further sites carry `client_id` into the wire: `oidc_challenge_flow.dart:234` (MFA/consent payload spread) and `oidc_provider_flow.dart:54` (federated first-party POST). **All seven success paths therefore send `_effectiveClientId`.** |
| `app_router.dart:35` — `defaultClientId 'sso-admin-console'` | **Exact.** `defaultClientId: 'sso-admin-console',` — the only screens login-wiring literal, passed into `OidcLoginScreen` (`:34-37`). |
| `sso_client.dart:86,92`; `sso_client_test.dart:18` | **Exact.** `lib/api/sso_client.dart:86` `String clientId = 'sso-admin-console',`; `:92` `'client_id': clientId,` in the `/auth/login` body. `test/sso_client_test.dart:16-18` asserts the whole body incl. `'client_id': 'sso-admin-console',`. |
| No `auth.login.success` emission in the repo | **Exact.** `grep -rn "auth.login.success" lib/ test/` → 0 hits. Generation is server-side; this repo can only verify the request-side contract and (B6-1, other direction) read-side visibility. |
| `implementation-gate.md:57` — gate row 2 quote | **Exact — the current direction quotes it correctly.** The row at `:57` reads: "边缘生成验证：login → `auth.login.success`（**client_id=sso-admin-console**）\| sink 出现 **sso-admin-console** login 事件；无重复 \| B4-5". The gate **already records `sso-admin-console`** — the approved contract-exception note the acceptance calls for **already exists**. The stale `client_id=console` prompt text was already reconciled at `docs/campaigns/campaign-console-b6.yaml:37` (now reads `client_id=sso-admin-console` — C2). |

Choke-point census (verified line-exact, extends the direction's call-site list):

| Site | Path |
|---|---|
| `oidc_authorization_flow.dart:242` | silent renewal (`_submitSilentRenewal`, prompt=none) |
| `oidc_authorization_flow.dart:313` | password / TOTP / code / magic-link (`_submitLogin`) |
| `oidc_authorization_flow.dart:379` | passkey (`_submitPasskeyLogin`) |
| `oidc_challenge_flow.dart:150` | MFA factor completion |
| `oidc_challenge_flow.dart:244` | consent decision |
| `oidc_provider_flow.dart:60` | federated return (`_resumeFederatedAuthorization`, fired by `_checkFederatedReturn`) |

Six call sites covering the seven named paths (password/TOTP/code share `:313`). The only other `outcome.ok` branches in the module are non-login account actions in `oidc_account_flow.dart:76, :182` (reset-password / email-verify status handling — `:76` is the reset-password result, "Password updated" at `:78`) and non-terminal uses (`_sendProviderCode` `oidc_authorization_flow.dart:326` with `_codeSent = outcome.ok` at `:341-342`, probe `oidc_provider_flow.dart:279`) — none observe terminal login success.

**Corrections relative to the current direction (C1–C4):**

- **C1 — the guard tests are committed at HEAD, not "untracked working-tree changes".** `test/oidc_login_handle_success_census_test.dart` and `test/oidc_login_screen_client_id_test.dart` landed in `3b64c58` ("verify(b6-1/b6-2): ring-isolation guards + client_id alignment drills"). Direction acceptance (1) is therefore runnable at HEAD as-is — nothing to adopt. Verified: the 3-file acceptance command runs **26/26 green at HEAD with zero `lib/screens/oidc_login/**` edits** (working tree carries only an unrelated `lib/screens/admin/audit_log_tab.dart` B6-1a modification).
- **C2 — `campaign-console-b6.yaml:37` is already reconciled** (`client_id=sso-admin-console`). REQ-0's reconciliation step is a no-op at HEAD; grep-verify only.
- **C3 — the drill's `[proposed]` fallback is already implemented.** `tests/integration/audit_login_drill.py` (untracked; wiring committed at `run_all.py:169` / `full_stack_verify.py:113`) Step 4 sets `proposed = True` and prints "sink legs marked [proposed] — no false PASS" on unverifiable sink queries; Step 5 skips the no-duplicates leg when `proposed`. Direction acceptance item (3)'s "marked [proposed] rather than faked" is satisfied by the existing artifact — adopt, never re-create (D3).
- **C4 — API shim:** `lib/screens/oidc_login/oidc_login_api.dart` is a one-line re-export (`:3`); the real `probeProviders` / `login` live at `lib/api/oidc_login_api.dart:47-58`.
- **G3 — boundary record corrected (carried into §1 and REQ-5):** the revision-2 boundary text labeled the PKCE **query** leg (`_checkFederatedReturn` → `consumeReturnIfPresent` → `_completeFirstPartyLogin`, `oidc_provider_flow.dart:13-18`) as the "fragment-return federated path … without a wire POST" — wrong on both counts. The **fragment** return is the census-covered continuation leg: route-fragment `login_transaction_id` (`federated_login.dart:18-27`, consumed at `oidc_login_screen.dart:101`) → `_resumeFederatedAuthorization` (`oidc_provider_flow.dart:47-77`) → `_api.login` POST (`:53`) → `_handleSuccess` (`:60`). The **query** leg's one wire mutation is the same-origin `/token` exchange (`federated_login.dart:197-201`, `grant_type=authorization_code` + `code_verifier`); "no wire POST" holds only under the census's `_api.login`/`_api.mfaComplete` vocabulary. REQ-5 additionally gains **G1/G2** (items 5-6 below).

**Single-emission topology (verified facts, basis for REQ-5):** `_submitLogin` dispatches federated / passkey with early `return;` (`oidc_authorization_flow.dart:268-274`) — no fall-through to a second POST; each of the six dispatch methods contains exactly one `_api.login(` / `_api.mfaComplete(` call (§1.1 table); silent renewal fires only from `_checkFederatedReturn` under `_isRpFlow && _params.hasPromptNone && flow == login` (`oidc_provider_flow.dart:35-41`, mount-time, early return). Boundary (recorded, not asserted — **G3-corrected**): the boundary is the PKCE **query** leg — `_checkFederatedReturn` → `consumeReturnIfPresent` (`federated_login.dart:137`, `code`+`state` in the query string) → `_completeFirstPartyLogin`, `oidc_provider_flow.dart:13-18`, immediate `return` — whose **one wire mutation is the same-origin `/token` exchange** (`federated_login.dart:197-201`, `grant_type=authorization_code` + `code_verifier`); the "without a wire POST" characterization holds **only under the census's `_api.login`/`_api.mfaComplete` vocabulary**, and it never reaches `_handleSuccess` (single-completes). The census-covered **fragment** return is the continuation leg `_resumeFederatedAuthorization` (`oidc_provider_flow.dart:47-77`; `_api.login` POST `:53`; `_handleSuccess` `:60`), fired when the route fragment carries `login_transaction_id` (`federated_login.dart:18-27`, consumed at `oidc_login_screen.dart:101`).

Widget-test harness facts (for REQ-2/REQ-3): `test/oidc_account_flow_test.dart` is the established pattern — pump `OidcLoginScreen(api: OidcLoginApi(httpClient: MockClient(...)), defaultClientId: 'sso-admin-console', routeUri: Uri.parse('https://sso.example/login/...'))`. On mount, `initState` fires `_probeProviders()` (`oidc_login_screen.dart:216-225`) whenever `_effectiveClientId.isNotEmpty && _route.requiresAuthentication` (true for the `login` flow, `hosted_login_models.dart:323-326`) — the probe is a POST to `../auth/login` with **no `credential`** (`oidc_login_api.dart:47-55`), so request-counting must filter on the `credential` key. `OidcLoginApi.login` is a verbatim passthrough (`oidc_login_api.dart:57-58`); the `client_id` value is decided by the private `_submitLogin` payload builder, reachable only through the widget.

---

## 2. Scope

**In scope**

- The decision record for this module's `client_id` value (REQ-0): keep `'sso-admin-console'`; the recorded contract exception is `implementation-gate.md:57` (already states it); the stale `client_id=console` text in `campaign-console-b6.yaml:37` is **already reconciled** (C2 — grep-verify only).
- The `_handleSuccess` terminal-success choke-point contract (REQ-1): any future client-side `auth.login.success` emission or verification probe must live inside `_handleSuccess`; per-path instrumentation of `_submit*` / flow methods is forbidden.
- Regression tests (REQ-2/REQ-3/REQ-4): **landed at HEAD (C1)** — request-body `client_id` assertion, exactly-one-login-request-per-submit widget test, and a structural census guard pinning the six call sites and the emission-free invariant.
- **Single-emission topology guard (REQ-5, NEW):** extend the census to assert at most one `_handleSuccess` reachable per successful interactive submit — direction acceptance item (2).
- Synchronization with `test/sso_client_test.dart:18` (it already asserts `sso-admin-console`; it must change in the same change-set iff the value ever flips — sibling REQ-0 Branch A).

**Out of scope (explicitly not changed)**

- Any `auth.login.success` emission code: no emission path exists in this repo (§1); generation is server-side. The sink-side row-generation drill is direction 3 of the same analysis bucket — referenced only as the [proposed] verification channel, not specced here. The drill artifact exists as an **untracked** file (`tests/integration/audit_login_drill.py`; wiring committed at `run_all.py:169` / `full_stack_verify.py:113` — D3 in the design): the sibling change-set **adopts** it (never re-creates), and the `git clean` fragility of that premise is documented in the design. The drill's `[proposed]` fallback for unobservable sink legs is already implemented (C3 — no false PASS).
- B6-1 (audit timeline read path), the localStorage debug ring, `AuditLogService` — direction 2's territory.
- The constant-extraction refactor (`lib/api/sso_client.dart` `static const firstPartyClientId`) — owned by the sibling `lib-screens` spec (its REQ-1); this spec only forbids value divergence and reuses that constant once it lands.
- `lib/api` transport, `lib/i18n`, UX/copy, no changes to any login-screen behavior.

---

## 3. Requirements

### REQ-0 — Decision record: `client_id` is pinned to `'sso-admin-console'`; contract exception already recorded

The decision the direction's acceptance names ("an approved contract-exception note referencing the verified code reality") **already exists in the contract**: `docs/campaigns/implementation-gate.md:57` row console #2 records `client_id=sso-admin-console` and its acceptance "sink 出现 sso-admin-console login 事件；无重复". Code reality matches it at every verified site (`app_router.dart:35`, `sso_client.dart:86`, `sso_client_test.dart:18`). The stale analysis prompt `campaign-console-b6.yaml:37` **has already been reconciled to `client_id=sso-admin-console`** (C2 — revision 2 verification).

- The wire value **does not change**: `'sso-admin-console'` is the contract constant for this module.
- Reconciliation status: **done** (C2) — REQ-0 is grep-verify only; no edit remains. The gate row needs **no** amendment (it already records the exception).
- If a future drill/registry check (sibling REQ-0, direction 3) ever proves the deployed IdP expects `console`, the flip follows sibling Branch A co-change: `sso_client.dart:86` + `app_router.dart:35` + `sso_client_test.dart:18` + `oidc_account_flow_test.dart:35,75,115,160` + `test/oidc_login_screen_client_id_test.dart` (constantized by the sibling's co-change list — REQ-2; if it still carries the literal it is constantized in the same commit) + **gate/yaml rows** (`implementation-gate.md:57` row 2 and `campaign-console-b6.yaml:37` flip to `console` — D15, agreed with the sibling design §3.6/§4.5) in one change-set.

**Testable:** `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (`:57`); `grep -n "client_id=console" docs/campaigns/campaign-console-b6.yaml` returns no hits (or only a `[SUPERSEDED]`-annotated line); `grep -rn "'sso-admin-console'" lib/` still hits `app_router.dart:35` + `sso_client.dart:86` (unchanged); `grep -rn "'sso-admin-console'" test/` → exactly the pinned allowlist (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`) while the sibling constant is absent, **zero hits once the sibling mechanism (M2) has landed** (all references constantized — REQ-2).

### REQ-1 — Choke-point contract: `_handleSuccess` is the sole terminal-success observation point

For this module, "terminal success" is defined by the six verified call sites (§1 census): silent renewal, password/TOTP/code, passkey, MFA, consent, federated. Every one of the seven success paths reaches `_handleSuccess` (`oidc_authorization_flow.dart:8`) and none observes success elsewhere. Consequence for B6-2 edge verification: **any** future client-side emission or verification probe must be added inside `_handleSuccess`; per-path instrumentation in `_submitLogin` / `_submitSilentRenewal` / `_submitPasskeyLogin` / MFA / consent / federated handlers is a design violation (it would miss paths or double-emit — e.g., a silent-renewal after an interactive login). This spec adds no emission; it pins the invariant so a later change cannot fork it.

**Testable:** REQ-4's structural guard (below).

### REQ-2 — Request-body `client_id` assertion on the `_submitLogin` payload builder

**Landed at HEAD (C1):** `test/oidc_login_screen_client_id_test.dart` (following the `test/oidc_account_flow_test.dart` harness) pumps `OidcLoginScreen` with `defaultClientId: 'sso-admin-console'`, `routeUri: Uri.parse('https://sso.example/login/')`, and a `MockClient` that captures every POST to `/auth/login`. Completing a password login must produce a request whose decoded body has `'client_id': 'sso-admin-console'` (the REQ-0 constant). **Expectation source (enforced, not prose):** assert the literal at the file's three sites (`:76` harness `defaultClientId:`, `:136/:158` expects) **only if `SSOAdminClient.firstPartyClientId` does not exist at implementation time**; if it exists (sibling landed first), reference the constant at all three sites — a compile-time gate (absent/renamed constant ⇒ compile error, never a green tautology). If the literal was used (this change-set landed first), the sibling's landing commit must constantize all three sites in the same commit — the file is in the sibling's co-change list (sibling design §2 item 9 / §3.4); after that commit the file derives from the constant and the AC-1 `test/` grep turns from pinned-allowlist to zero hits. `OidcLoginApi.login` is a verbatim passthrough (`lib/api/oidc_login_api.dart:57-58`, C4 shim; already covered by `test/oidc_login_api_test.dart:76`), so the value assertion belongs at the payload-builder level, which is only reachable through the widget.

In the same change-set, `test/sso_client_test.dart:18` must assert the identical value (it already asserts `'sso-admin-console'` — no edit needed today; if REQ-0 ever flips, both files change together).

**Testable:** `flutter test test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` green; the captured `/auth/login` body's `client_id` equals the REQ-0 value; `grep -rn "'sso-admin-console'" test/` → pinned allowlist pre-sibling / zero hits post-sibling (REQ-0 testable).

### REQ-3 — Exactly one login request per interactive submit (no duplicate fire)

**Landed at HEAD (C1)** in the same widget test: the `MockClient` counts POSTs to `/auth/login` whose decoded body contains a `credential` map (harness `test/oidc_login_screen_client_id_test.dart:26-74`, D9 filter at `:33`). The mount-time `probeProviders` POST (`oidc_login_screen.dart:216-225` → `lib/api/oidc_login_api.dart:47-55`) has no `credential` and is excluded by that rule.

- One interactive submit (username + password, tap submit) → exactly **1** credential-bearing login request.
- A retry submit after a server-rejected attempt (MockClient returns 401, then 200) → cumulative count **2** (each submit fires exactly one).

**Testable:** assertion in `test/oidc_login_screen_client_id_test.dart`; count rule documented in the test comment (credential-filtered).

### REQ-5 — Single-emission topology guard (direction acceptance item (2); NEW in revision 2)

Extend `test/oidc_login_handle_success_census_test.dart` with a **topology group** asserting that at most one `_handleSuccess` is reachable per successful interactive submit — no double-dispatch across the renewal/login/passkey paths. Structural assertions (brace-balanced method slicing over the three flow files — extract each method body by matching `{`/`}` from its signature, then assert within the body):

1. **Per-method uniqueness:** every method block containing a `_handleSuccess(outcome);` call site contains **exactly one** `_handleSuccess(` reference. A method that dispatches success twice (e.g., `_submitLogin` calling `_handleSuccess` and then falling through to another POST whose success also calls it) fails this assertion.
2. **Dispatch exclusivity in `_submitLogin` (`oidc_authorization_flow.dart:266-274`):** the line immediately following `_signInWithFederated(_provider);` is `return;` and the line immediately following `await _submitPasskeyLogin();` is `return;` — the federated and passkey branches cannot fall through to the primary login POST.
3. **One wire mutation per dispatch method:** each of the six methods containing a call site (§1.1 table) contains exactly one `_api.login(` or `_api.mfaComplete(` call — one request per method ⇒ at most one terminal-success observation per method.
4. **No seventh interactive dispatch:** `_submitLogin` is the only interactive entry named by a submit handler (`oidc_login_view_flow.dart:268` `onSubmit: _submitLogin`); the topology group asserts `_submitSilentRenewal` is referenced from `_checkFederatedReturn` only (the renewal path is mount-time, never an interactive submit).
5. **Choke point request-free (G1, presence-anchored):** the `_handleSuccess` body (D17 slice of the declaration at `oidc_authorization_flow.dart:8-139`) contains **zero** `_api.` references (verified at HEAD: nearest site is `:239`, outside the slice). Anchor: assert the slice is non-empty and contains the `void _handleSuccess(` declaration before the zero-count assert — a wire added inside the choke point (the double-request vector AC-2 targets), a slicer miss, or a renamed declaration all turn red.
6. **Delivery tails terminate (G2, presence-anchored):** within the `_handleSuccess` slice, assert the exact tail inventory — 4 `_authorizationDeliveryBlocked();` (`:66/:80/:101/:132`) and 4 `_error`-assigning `_update(...)` statements (`:28/:40/:54-58` + the function-final `:135-138`) — then for every tail whose terminating `;` is not the function-final statement, the next non-empty line is `return;`. Statement-based matching (scan from `_update(`/`_authorizationDeliveryBlocked()` to the terminating `;`) so the multi-line tails count once; the exact counts anchor presence — a removed `return;`, a removed/added tail, or a matcher typo turns red.

**Testable:** `flutter test test/oidc_login_handle_success_census_test.dart` green at HEAD with zero source edits (the extension is written against the verified topology above and must pass before any B6-2 code change); combined command per direction acceptance (1): `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` → all green.

**Documented boundary (recorded, not asserted — G3-corrected):** the boundary is the PKCE **query** leg (`_checkFederatedReturn` → `consumeReturnIfPresent`, `federated_login.dart:137` — `code`+`state` in the query string — → `_completeFirstPartyLogin`, `oidc_provider_flow.dart:13-18`). Its one wire mutation is the same-origin `/token` exchange (`federated_login.dart:197-201`, `grant_type=authorization_code` + `code_verifier`); the "no wire POST" characterization holds **only under the census's `_api.login`/`_api.mfaComplete` vocabulary** (this leg is mutation-free under it), and it never reaches `_handleSuccess` — it is outside the six-path census by construction and single-completes via its immediate early return at `:19`. The census-covered **fragment** return is the continuation leg `_resumeFederatedAuthorization` → `_api.login` POST (`:53`) → `_handleSuccess` (`:60`), fired from `_checkFederatedReturn` `:8` when the route fragment carries `login_transaction_id` (`federated_login.dart:18-27`, consumed at `oidc_login_screen.dart:101`). Any future instrumentation of the PKCE leg must be a conscious, reviewed change (it would not trip the census call-site count, and the topology group does not cover it because it never reaches `_handleSuccess`).

### REQ-4 — Structural choke-point guard: census, no per-path instrumentation, no emission string

**Landed at HEAD (C1):** plain Dart test `test/oidc_login_handle_success_census_test.dart` reads the module sources (File IO; established pattern) and asserts:

1. **Census exact:** `_handleSuccess(outcome);` occurs exactly **6** times in `lib/screens/oidc_login/` — `oidc_authorization_flow.dart` lines 242/313/379, `oidc_challenge_flow.dart` lines 150/244, `oidc_provider_flow.dart` line 60 — and `void _handleSuccess(` occurs exactly once (line 8). Any new success path must add a call site, which fails the census until the test is updated — forcing the path through the choke point by construction.
2. **No per-path instrumentation:** every `if (outcome.ok) {` in those three files is immediately followed by `_handleSuccess(outcome);` (the six sites), and `oidc_account_flow.dart` (reset-password/email-verify account actions) contains zero `_handleSuccess` references — i.e., no flow method observes terminal success on its own.
3. **No emission string:** `grep "auth.login.success" lib/screens/oidc_login/` → 0 hits (repo-wide invariant from §1; a future emission added outside `_handleSuccess` or at all — until the drill proves the sink side — fails this assertion).
4. **Conditional client_id literal census (single-source rule):** the guard scans `lib/api/sso_client.dart` for a `firstPartyClientId` declaration. If present, it asserts **zero** `'sso-admin-console'` literals in `test/` (every reference must go through the constant — sibling REQ-1's single-source rule enforced at every run, no co-change needed); if absent, it asserts the literal census equals exactly the pinned allowlist (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`). The expectation derives from the constant's existence, so the gate is active in every landing ordering (§6.4).

**Testable:** `flutter test test/oidc_login_handle_success_census_test.dart` green at HEAD with zero source edits (the test is written against the verified census and must pass before any B6-2 code change); the literal-census assertion (item 4) auto-flips with the constant's existence.

---

## 4. Acceptance mapping (T-12 joint, gate row 2, dep B4-5)

Direction acceptance preserved 1:1; each item is testable as written. The current direction's acceptance has three items (item (1) = the three-file command + census/body facts; item (2) = single-emission topology; item (3) = [proposed] sink leg).

| # | Direction acceptance (preserved) | Testable form | Verdict |
|---|---|---|---|
| AC-1 | (1) `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` green at HEAD with zero lib/ edits — census = exactly 6 `_handleSuccess(outcome);` call sites, single declaration, zero `auth.login.success` literal in `lib/screens/oidc_login/`, MockClient-captured login body decodes to `'client_id':'sso-admin-console'` with exactly one credential-bearing POST per submit (probe POST excluded via `body['credential']` map filter, per harness `test/oidc_login_screen_client_id_test.dart:26-74`) | **Executed at HEAD — 26/26 green, zero `lib/screens/oidc_login/**` edits** (C1: guard files committed at `3b64c58`, nothing to adopt). REQ-2 + REQ-3 + REQ-4 + REQ-0 greps. | REQ-2 + REQ-3 + REQ-4 + REQ-0 |
| AC-2 | (2) extend the census to assert single-emission topology: at most one `_handleSuccess` reachable per successful interactive submit (no double-dispatch across the renewal/login/passkey paths) | REQ-5: new topology group in `test/oidc_login_handle_success_census_test.dart` — per-method uniqueness, `_submitLogin` dispatch exclusivity (early `return;` after federated/passkey branches), one wire mutation per dispatch method, renewal never an interactive dispatch. Green at HEAD with zero source edits. | REQ-5 |
| AC-3 | Sink-side single-row observation (exactly one sso-admin-console event, 无重复) is **[proposed]** — requires the deployed stack via `tests/integration/audit_login_drill.py` and must be marked [proposed] in the drill output rather than faked when the sink leg is unobservable | Not asserted in this repo. Delegated to the drill (untracked artifact; C3 — Step 4 already sets `proposed = True` + "marked [proposed] — no false PASS"; Step 5 skips no-duplicates when `proposed`). This spec adds no emission and no drill edits — it cannot fabricate an edge. | [proposed] |

## 5. Open questions / notes

- `campaign-console-b6.yaml:37` prompt correction: **already executed** (C2 — the line now reads `client_id=sso-admin-console`); no batch-owner pick remains.
- C1 effect on scope: the direction assumed the guard tests were uncommitted working-tree changes ("adopt" framing). They are committed at HEAD; the implement stage has only REQ-5's topology-group extension to add (plus greps). The untracked artifact that remains is the drill (C3) — its adoption is the sibling change-set's M-step, not this lens's.
- Sibling constant timing (D2): if `SSOAdminClient.firstPartyClientId` lands before the implement stage, REQ-2's three sites reference the constant; if not, they keep the literal and the sibling's M2 commit constantizes them in the same commit.
- All eight sibling `b6-2-lib-*-client-id-alignment` docs (six screens-family: screens/developer/device spec+design; plus the api pair) previously repeated the misquote — 21 `client_id=console` hits in three defect classes: 10 direct gate quotes claiming "exact / contract authority", 6 Branch-B "amend the gate" narratives that are **no-ops** against the real text (the gate already records the exception — Branch B requires verify-only, zero gate edits), and 2 branch-conditional AC-2 acceptances hard-coding `console` (3 Branch-A scenario lines are legitimate and stay). **The sweep is executed in this revision (design D1/D15):** every doc now quotes `implementation-gate.md:57`'s actual text (`sso-admin-console`), the Branch-B narratives are corrected to no-ops, the Branch-A narratives flip the gate row + yaml to `console`, and the screens sibling's co-change list includes `test/oidc_login_screen_client_id_test.dart` (REQ-2 expectation source).
- No code behavior changes are required by this spec at HEAD: it is decision + regression-guard only (effort 3, as scored).
