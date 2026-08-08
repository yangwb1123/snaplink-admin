# B6-2 Requirements Specification — Pin the client_id decision + anchor edge-verification at `_handleSuccess`

Module: `lib/screens/oidc_login` (analysis bucket `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`, direction 1) · Direction: B6-2 (edge generation verification, `auth.login.success` / client_id) · Value: 9 · Risk reduction: 9 · Effort: 3 · Confidence: 10
Status: requirements (decision recorded in REQ-0 — no code value change; contract exception already recorded)
Sibling instance: `docs/proposals/b6-2-lib-screens-client-id-alignment-spec.md` (+ `-design.md`) owns the `lib/screens`-wide `client_id` single-source-of-truth constant (its REQ-1) and the Branch A/B decision gate (its REQ-0). This spec is the **`lib/screens/oidc_login` lens**: it pins the decision for this module's wire, and adds what the screens bucket does not own — the `_handleSuccess` terminal-success choke point contract and its regression guard. Where the two overlap (constant value, `test/sso_client_test.dart:18`), both name the same artifacts.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. Six of seven hold; **one material correction**: the direction's gate citation misquotes `docs/campaigns/implementation-gate.md:57`.

| Direction citation | Verification result |
|---|---|
| `oidc_authorization_flow.dart:8` — `_handleSuccess` | **Exact.** `void _handleSuccess(LoginOutcome outcome) {` is the first member of the `_OidcAuthorizationFlow` extension (`:7-9`). It is the module's only terminal-success handler. |
| `oidc_authorization_flow.dart:242, :313, :379` — silent renewal / login / passkey call sites | **Exact.** `:242` in `_submitSilentRenewal` (`:229-244`), `:313` in `_submitLogin` (`:266-313`), `:379` in `_submitPasskeyLogin` (`:351-379`) — each `if (outcome.ok) { _handleSuccess(outcome); }`. |
| `oidc_challenge_flow.dart:150, :244`; `oidc_provider_flow.dart:60` — MFA / consent / federated call sites | **Exact.** `:150` in the MFA-complete submit (`:141-150`), `:244` in the consent-decision submit (`:237-244`), `:60` in the federated-return check (`_checkFederatedReturn`, `:52-60`). All are `if (outcome.ok) { _handleSuccess(outcome); }`. |
| `oidc_login_screen.dart:159-160` — `_effectiveClientId` | **Exact** (spans `:159-161`). `String get _effectiveClientId => _params.clientId.isNotEmpty ? _params.clientId : (widget.defaultClientId ?? '');` — URL-supplied `client_id` wins; the first-party default comes from `widget.defaultClientId`. |
| payload built at `oidc_authorization_flow.dart` ~283 with `payload['client_id'] = _effectiveClientId` | **Line correction.** The exact sites are `:238` (`_submitSilentRenewal`), `:295` (`_submitLogin`), `:370` (`_submitPasskeyLogin`). Two further sites carry `client_id` into the wire: `oidc_challenge_flow.dart:234` (MFA/consent payload spread) and `oidc_provider_flow.dart:54` (federated first-party POST). **All seven success paths therefore send `_effectiveClientId`.** |
| `app_router.dart:35` — `defaultClientId 'sso-admin-console'` | **Exact.** `defaultClientId: 'sso-admin-console',` — the only screens login-wiring literal, passed into `OidcLoginScreen` (`:34-37`). |
| `sso_client.dart:86,92`; `sso_client_test.dart:18` | **Exact.** `lib/api/sso_client.dart:86` `String clientId = 'sso-admin-console',`; `:92` `'client_id': clientId,` in the `/auth/login` body. `test/sso_client_test.dart:16-18` asserts the whole body incl. `'client_id': 'sso-admin-console',`. |
| No `auth.login.success` emission in the repo | **Exact.** `grep -rn "auth.login.success" lib/ test/` → 0 hits. Generation is server-side; this repo can only verify the request-side contract and (B6-1, other direction) read-side visibility. |
| `implementation-gate.md:57` — "console #2: login → auth.login.success, client_id=console, 无重复" | **MISQUOTED in the direction.** The row at `:57` currently reads: "边缘生成验证：login → `auth.login.success`（**client_id=sso-admin-console**）\| sink 出现 **sso-admin-console** login 事件；无重复 \| B4-5". The gate **already records `sso-admin-console`** — i.e., the "approved contract-exception note" the acceptance calls for **already exists**. The `client_id=console` text exists only in the analysis prompt at `docs/campaigns/campaign-console-b6.yaml:37` ("login must emit auth.login.success with client_id=console"), which is stale relative to the gate. The same misquote appears in the sibling spec's §1 ("Contract authority" paragraph). |

Choke-point census (verified line-exact, extends the direction's call-site list):

| Site | Path |
|---|---|
| `oidc_authorization_flow.dart:242` | silent renewal (`_submitSilentRenewal`, prompt=none) |
| `oidc_authorization_flow.dart:313` | password / TOTP / code / magic-link (`_submitLogin`) |
| `oidc_authorization_flow.dart:379` | passkey (`_submitPasskeyLogin`) |
| `oidc_challenge_flow.dart:150` | MFA factor completion |
| `oidc_challenge_flow.dart:244` | consent decision |
| `oidc_provider_flow.dart:60` | federated return (`_checkFederatedReturn`) |

Six call sites covering the seven named paths (password/TOTP/code share `:313`). The only other `outcome.ok` branches in the module are non-login account actions in `oidc_account_flow.dart:76, :182` (reset-password / email-verify status handling — `:76` is the reset-password result, "Password updated" at `:78`) and non-terminal uses (`_sendProviderCode` `oidc_authorization_flow.dart:326` with `_codeSent = outcome.ok` at `:341-342`, probe `oidc_provider_flow.dart:279`) — none observe terminal login success.

Widget-test harness facts (for REQ-2/REQ-3): `test/oidc_account_flow_test.dart` is the established pattern — pump `OidcLoginScreen(api: OidcLoginApi(httpClient: MockClient(...)), defaultClientId: 'sso-admin-console', routeUri: Uri.parse('https://sso.example/login/...'))`. On mount, `initState` fires `_probeProviders()` (`oidc_login_screen.dart:216-225`) whenever `_effectiveClientId.isNotEmpty && _route.requiresAuthentication` (true for the `login` flow, `hosted_login_models.dart:323-326`) — the probe is a POST to `../auth/login` with **no `credential`** (`oidc_login_api.dart:47-55`), so request-counting must filter on the `credential` key. `OidcLoginApi.login` is a verbatim passthrough (`oidc_login_api.dart:57-58`); the `client_id` value is decided by the private `_submitLogin` payload builder, reachable only through the widget.

---

## 2. Scope

**In scope**

- The decision record for this module's `client_id` value (REQ-0): keep `'sso-admin-console'`; the recorded contract exception is `implementation-gate.md:57` (already states it); reconcile the stale `client_id=console` text in `campaign-console-b6.yaml:37`.
- The `_handleSuccess` terminal-success choke-point contract (REQ-1): any future client-side `auth.login.success` emission or verification probe must live inside `_handleSuccess`; per-path instrumentation of `_submit*` / flow methods is forbidden.
- Regression tests (REQ-2/REQ-3/REQ-4): request-body `client_id` assertion, exactly-one-login-request-per-submit widget test, and a structural census guard pinning the six call sites and the emission-free invariant.
- Synchronization with `test/sso_client_test.dart:18` (it already asserts `sso-admin-console`; it must change in the same change-set iff the value ever flips — sibling REQ-0 Branch A).

**Out of scope (explicitly not changed)**

- Any `auth.login.success` emission code: no emission path exists in this repo (§1); generation is server-side. The sink-side row-generation drill is direction 3 of the same analysis bucket — referenced only as the [proposed] verification channel, not specced here. That direction's drill artifact already exists as an **untracked** working-tree file (`tests/integration/audit_login_drill.py`, wired at `run_all.py:169` / `full_stack_verify.py:113` by an uncommitted diff — D3 in the design): the sibling change-set **adopts** it (never re-creates), and the `git clean` / `git checkout` fragility of that premise is documented in the design.
- B6-1 (audit timeline read path), the localStorage debug ring, `AuditLogService` — direction 2's territory.
- The constant-extraction refactor (`lib/api/sso_client.dart` `static const firstPartyClientId`) — owned by the sibling `lib-screens` spec (its REQ-1); this spec only forbids value divergence and reuses that constant once it lands.
- `lib/api` transport, `lib/i18n`, UX/copy, no changes to any login-screen behavior.

---

## 3. Requirements

### REQ-0 — Decision record: `client_id` is pinned to `'sso-admin-console'`; contract exception already recorded

The decision the direction's acceptance names ("an approved contract-exception note referencing the verified code reality") **already exists in the contract**: `docs/campaigns/implementation-gate.md:57` row console #2 records `client_id=sso-admin-console` and its acceptance "sink 出现 sso-admin-console login 事件；无重复". Code reality matches it at every verified site (`app_router.dart:35`, `sso_client.dart:86`, `sso_client_test.dart:18`). The only conflicting text is the stale analysis prompt `campaign-console-b6.yaml:37` (`client_id=console`).

- The wire value **does not change**: `'sso-admin-console'` is the contract constant for this module.
- Reconcile the stale prompt: edit `campaign-console-b6.yaml:37` to `client_id=sso-admin-console`, or add a `[SUPERSEDED by implementation-gate.md:57]` note at that line — either is acceptable; the batch owner picks. The gate row itself needs **no** amendment (it already records the exception).
- If a future drill/registry check (sibling REQ-0, direction 3) ever proves the deployed IdP expects `console`, the flip follows sibling Branch A co-change: `sso_client.dart:86` + `app_router.dart:35` + `sso_client_test.dart:18` + `oidc_account_flow_test.dart:35,75,115,160` + `test/oidc_login_screen_client_id_test.dart` (constantized by the sibling's co-change list — REQ-2; if it still carries the literal it is constantized in the same commit) + **gate/yaml rows** (`implementation-gate.md:57` row 2 and `campaign-console-b6.yaml:37` flip to `console` — D15, agreed with the sibling design §3.6/§4.5) in one change-set.

**Testable:** `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (`:57`); `grep -n "client_id=console" docs/campaigns/campaign-console-b6.yaml` returns no hits (or only a `[SUPERSEDED]`-annotated line); `grep -rn "'sso-admin-console'" lib/` still hits `app_router.dart:35` + `sso_client.dart:86` (unchanged); `grep -rn "'sso-admin-console'" test/` → exactly the pinned allowlist (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`) while the sibling constant is absent, **zero hits once the sibling mechanism (M2) has landed** (all references constantized — REQ-2).

### REQ-1 — Choke-point contract: `_handleSuccess` is the sole terminal-success observation point

For this module, "terminal success" is defined by the six verified call sites (§1 census): silent renewal, password/TOTP/code, passkey, MFA, consent, federated. Every one of the seven success paths reaches `_handleSuccess` (`oidc_authorization_flow.dart:8`) and none observes success elsewhere. Consequence for B6-2 edge verification: **any** future client-side emission or verification probe must be added inside `_handleSuccess`; per-path instrumentation in `_submitLogin` / `_submitSilentRenewal` / `_submitPasskeyLogin` / MFA / consent / federated handlers is a design violation (it would miss paths or double-emit — e.g., a silent-renewal after an interactive login). This spec adds no emission; it pins the invariant so a later change cannot fork it.

**Testable:** REQ-4's structural guard (below).

### REQ-2 — Request-body `client_id` assertion on the `_submitLogin` payload builder

A new widget test (new file `test/oidc_login_screen_client_id_test.dart`, following the `test/oidc_account_flow_test.dart` harness) pumps `OidcLoginScreen` with `defaultClientId: 'sso-admin-console'`, `routeUri: Uri.parse('https://sso.example/login/')`, and a `MockClient` that captures every POST to `/auth/login`. Completing a password login must produce a request whose decoded body has `'client_id': 'sso-admin-console'` (the REQ-0 constant). **Expectation source (enforced, not prose):** assert the literal at the file's three sites (`:76` harness `defaultClientId:`, `:136/:158` expects) **only if `SSOAdminClient.firstPartyClientId` does not exist at implementation time**; if it exists (sibling landed first), reference the constant at all three sites — a compile-time gate (absent/renamed constant ⇒ compile error, never a green tautology). If the literal was used (this change-set landed first), the sibling's landing commit must constantize all three sites in the same commit — the file is in the sibling's co-change list (sibling design §2 item 9 / §3.4); after that commit the file derives from the constant and the AC-1 `test/` grep turns from pinned-allowlist to zero hits. `OidcLoginApi.login` is a verbatim passthrough (`oidc_login_api.dart:57-58`, already covered by `test/oidc_login_api_test.dart:76`), so the value assertion belongs at the payload-builder level, which is only reachable through the widget.

In the same change-set, `test/sso_client_test.dart:18` must assert the identical value (it already asserts `'sso-admin-console'` — no edit needed today; if REQ-0 ever flips, both files change together).

**Testable:** `flutter test test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` green; the captured `/auth/login` body's `client_id` equals the REQ-0 value; `grep -rn "'sso-admin-console'" test/` → pinned allowlist pre-sibling / zero hits post-sibling (REQ-0 testable).

### REQ-3 — Exactly one login request per interactive submit (no duplicate fire)

In the same widget test, the `MockClient` counts POSTs to `/auth/login` whose decoded body contains a `credential` map. The mount-time `probeProviders` POST (`oidc_login_screen.dart:216-225` → `oidc_login_api.dart:47-55`) has no `credential` and is excluded by that rule.

- One interactive submit (username + password, tap submit) → exactly **1** credential-bearing login request.
- A retry submit after a server-rejected attempt (MockClient returns 401, then 200) → cumulative count **2** (each submit fires exactly one).

**Testable:** assertion in `test/oidc_login_screen_client_id_test.dart`; count rule documented in the test comment (credential-filtered).

### REQ-4 — Structural choke-point guard: census, no per-path instrumentation, no emission string

A new plain Dart test `test/oidc_login_handle_success_census_test.dart` reads the module sources (File IO is available in `flutter_test`) and asserts:

1. **Census exact:** `_handleSuccess(outcome);` occurs exactly **6** times in `lib/screens/oidc_login/` — `oidc_authorization_flow.dart` lines 242/313/379, `oidc_challenge_flow.dart` lines 150/244, `oidc_provider_flow.dart` line 60 — and `void _handleSuccess(` occurs exactly once (line 8). Any new success path must add a call site, which fails the census until the test is updated — forcing the path through the choke point by construction.
2. **No per-path instrumentation:** every `if (outcome.ok) {` in those three files is immediately followed by `_handleSuccess(outcome);` (the six sites), and `oidc_account_flow.dart` (reset-password/email-verify account actions) contains zero `_handleSuccess` references — i.e., no flow method observes terminal success on its own.
3. **No emission string:** `grep "auth.login.success" lib/screens/oidc_login/` → 0 hits (repo-wide invariant from §1; a future emission added outside `_handleSuccess` or at all — until the drill proves the sink side — fails this assertion).
4. **Conditional client_id literal census (single-source rule):** the guard scans `lib/api/sso_client.dart` for a `firstPartyClientId` declaration. If present, it asserts **zero** `'sso-admin-console'` literals in `test/` (every reference must go through the constant — sibling REQ-1's single-source rule enforced at every run, no co-change needed); if absent, it asserts the literal census equals exactly the pinned allowlist (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`). The expectation derives from the constant's existence, so the gate is active in every landing ordering (§6.4).

**Testable:** `flutter test test/oidc_login_handle_success_census_test.dart` green at HEAD with zero source edits (the test is written against the verified census and must pass before any B6-2 code change); the literal-census assertion (item 4) auto-flips with the constant's existence.

---

## 4. Acceptance mapping (T-12 joint)

| # | Direction acceptance (preserved) | Testable form | Verdict |
|---|---|---|---|
| 1 | Unit/payload-builder test asserts `client_id` equals the contract constant; `test/sso_client_test.dart:18` updated in the same change | REQ-2: widget-level MockClient body assertion against `'sso-admin-console'` (the gate-recorded exception); `flutter test test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart` green. Decision recorded per REQ-0 (gate `:57` unchanged; yaml `:37` reconciled). | REQ-2 + REQ-0 |
| 2 | Regression: widget test completing OidcLoginScreen login with MockClient asserts exactly one login request per interactive submit | REQ-3: credential-filtered POST count == 1 per submit, == 2 after retry | REQ-3 |
| 3 | `_handleSuccess` is the only function that can observe terminal success (no per-path instrumentation) | REQ-4: structural census test (6 call sites, `if (outcome.ok)` → `_handleSuccess` adjacency, zero `_handleSuccess` in `oidc_account_flow.dart`, zero `auth.login.success` string in the module) | REQ-4 |
| 4 | Sink-side row generation (`auth.login.success` row with matching client_id, 无重复) remains [proposed] — not verifiable in this repo without the BFF/sink drill | Not asserted in this repo; delegated to direction 3's drill manifest. This spec adds no emission code, so it cannot fabricate an edge. | [proposed] |

## 5. Open questions / notes

- `campaign-console-b6.yaml:37` prompt correction (edit vs. `[SUPERSEDED]` note): batch-owner pick (REQ-0).
- All eight sibling `b6-2-lib-*-client-id-alignment` docs (six screens-family: screens/developer/device spec+design; plus the api pair) previously repeated the misquote — 21 `client_id=console` hits in three defect classes: 10 direct gate quotes claiming "exact / contract authority", 6 Branch-B "amend the gate" narratives that are **no-ops** against the real text (the gate already records the exception — Branch B requires verify-only, zero gate edits), and 2 branch-conditional AC-2 acceptances hard-coding `console` (3 Branch-A scenario lines are legitimate and stay). **The sweep is executed in this revision (design D1/D15):** every doc now quotes `implementation-gate.md:57`'s actual text (`sso-admin-console`), the Branch-B narratives are corrected to no-ops, the Branch-A narratives flip the gate row + yaml to `console`, and the screens sibling's co-change list includes `test/oidc_login_screen_client_id_test.dart` (REQ-2 expectation source).
- No code behavior changes are required by this spec at HEAD: it is decision + regression-guard only (effort 3, as scored).
