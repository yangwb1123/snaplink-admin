# B6-2 Requirements Specification — developer lens: land the missing DCR leg of `tests/integration/audit_login_drill.py` (REQ-0/REQ-1/REQ-2)

Module: `lib/screens/developer` (analysis bucket `docs/auto/analyses/lib-screens-developer-3899da21.json`) · Direction: B6-2 developer lens · Value: 9 · Risk reduction: 7 · Effort: 2 · Confidence: 9
Status: requirements (this document refreshes the previous draft at the same path; every citation re-verified against HEAD — §1)
Sibling instances: `b6-2-lib-api-client-id-alignment-spec.md`, `b6-2-lib-screens-client-id-alignment-spec.md`, `b6-2-lib-screens-device-client-id-alignment-spec.md`. This lens owns the **DCR surface**: the only in-repo OAuth-client creation path (`developer_api.dart:104` → RFC 7591 `/register`), the DCR leg of the shared drill, and REQ-0's DCR evidence channel into the `[RESOLVED]` record.

---

## 1. Verification outcome (every citation re-checked at HEAD)

All eleven direction citations hold. Three corrections versus the previous draft of this spec are marked **Δ**:

| Direction citation | Verification result at HEAD |
|---|---|
| `tests/integration/audit_login_drill.py` — 439 lines; steps 【1】-【7】; zero 'register' tokens; header 'device redirect-leg facts' | **Exact.** 439 lines; step blocks 【1】【2】【3】【3b】【4】【5】【6】【7】 (`print("【…")` at :129 etc.); `grep -c "register"` → **0**; docstring :2 "B6-2 client_id contract drill — device redirect-leg facts (lib/screens/device lens)". **Δ vs previous draft:** the file is **tracked** (committed `3b64c58` "verify(b6-1/b6-2): ring-isolation guards + client_id alignment drills") with uncommitted modifications at HEAD — not "untracked". |
| `tests/integration/run_all.py:196` — drill wired in Gate 5, skip_markers SKIP/[proposed] | **Exact.** `:196` `run_e2e_test('B6-2 Login Drill (client_id contract)', ['python3', 'tests/integration/audit_login_drill.py'], timeout=300, skip_markers=('SKIP:', 'SKIP', '[proposed]'))` — Gate 5, comment :193-194. **Δ vs previous draft:** wired at `:196`, not `:169`. |
| `tests/integration/full_stack_verify.py:113` — drill wired, timeout 300 | **Exact.** `:113` `step('B6-2 Login Drill (client_id contract)', …, 300, skip_markers=('SKIP:', 'SKIP', '[proposed]'))`. |
| `docs/proposals/b6-2-lib-screens-developer-client-id-alignment-spec.md` — REQ-0/REQ-1/REQ-2/REQ-4; Status: requirements | **Exact.** Present at this path, `Status: requirements`. **Δ:** its §1 still describes `audit-contract-batch-snaplink-console.md:12` as `[MISMATCH]` and cites `run_all.py:169`/untracked drill — both stale; this document supersedes it. |
| `docs/proposals/audit-contract-batch-snaplink-console.md:13-14` — `[RESOLVED]` Branch B covers device + setup legs, no DCR channel | **Exact.** `:13` `[RESOLVED]` (B6-2, 2026-08-07) Branch B — device-leg evidence; `:14` `[RESOLVED]` (B6-2, 2026-08-08) setup leg; `:15` `[PROPOSED]` (console has no native event emission). Zero DCR/register tokens in the whole B6-2 block. The `[MISMATCH]` record the previous draft targeted is **already closed** — the missing piece is only the DCR evidence channel (REQ-0). |
| `lib/screens/developer/developer_api.dart:104` — `_registerBody` POST `_baseUri.resolve('/register')` | **Exact.** `:104` `_baseUri.resolve('/register'),` inside `_registerBody` (`:94-113`), invoked by `registerMetadata` (`:66`) and `register` (`:84`). Request body comes from the caller's map — for the screen path, `DcrClientMetadata.toRegistrationWire()` (see `register_panel.dart:87` `_registrationSnapshot = {...metadata.toRegistrationWire(), ...result}`). |
| `lib/screens/developer/dcr_models.dart:50-69` — `typedKeys` has no `client_id`; `protectedResponseKeys` lists `client_id` | **Exact.** `typedKeys` `:50-64` (13 keys, no `client_id`); `protectedResponseKeys` `:66-71` with `'client_id'` at `:67` alongside `client_secret`/`client_id_issued_at`/`client_secret_expires_at`/`registration_access_token`/`registration_client_uri`. `toRegistrationWire()` `:128-139` emits only typed keys. RFC 7591: `client_id` is **server-assigned** — the drill must assert the *response* id, never send one. |
| `lib/api/sso_client.dart:82` — `static const firstPartyClientId = 'sso-admin-console'` | **Exact.** `:82` `static const String firstPartyClientId = 'sso-admin-console';` (Branch B constant already landed). The login wire is `:92-94` — `_post('/auth/login', {'provider': 'password', …'client_id': clientId …})`. |
| `test/developer_api_test.dart:29,46` — mock `/register` 201 `client_id 'client-1'`; no `client_id` in request body | **Exact.** `:29` `return http.Response('{"client_id":"client-1"}', 201);`; `:46` `expect(result['client_id'], 'client-1');`; the request-body assertion `:22-28` (`expect(jsonDecode(request.body), {…})`) contains no `client_id` key. |
| `test/dcr_widgets_test.dart:24-30` — `onManage` pivot fires | **Exact.** `:24-30` `OneTimeRegistrationCredentials(result: {…'client_id': 'client-1'…}, onManage: () => managed = true, …)`; pivot asserted thereafter. The in-repo handoff is `register_panel.dart:107` (`result['client_id']` — response is the only `client_id` source in the module) → `:112` (`widget.onManage(clientId, rat, safeSnapshot)`). |
| `tests/integration/test_config.py:43-44` — `SNAPLINK_TEST_CLIENT_ID` default `'sso-admin-console'` | **Exact.** `:43-44` `client_id=os.environ.get('SNAPLINK_TEST_CLIENT_ID', 'sso-admin-console').strip()`. `login_payload()` at `:86`. |

Module-scope facts that shape the requirements (unchanged, re-confirmed):

1. **`lib/screens/developer` is the only in-repo OAuth-client creation surface.** `developer_api.dart:104` posts `/register`; the body is built from `toRegistrationWire()` keys; `typedKeys` has no `client_id` and `protectedResponseKeys` protects it — the drill must never place `client_id` in a registration body.
2. **The register→manage handoff is the in-repo round-trip the DCR leg mirrors:** `register_panel.dart:107` → `:112` (`onManage`) → `developer_screen.dart:81` (`_openManageWithApp`) → `manage_panel.dart:46` (`loadWithRegistration`). The drill's login leg uses the DCR-obtained id exactly as the module pivots it into manage.
3. **The module cannot forge sink rows:** `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/developer/` → 0 hits; the sole ring writer is `lib/api/snaplink_admin_api.dart:81` (`_recordAudit`, invoked at `:324`). Evidence channel = `GET /api/v1/audit/events` only.
4. **Harness facts (re-verified):** drill tracked + wired at `run_all.py:196` / `full_stack_verify.py:113` (skip_markers `('SKIP:', 'SKIP', '[proposed]')` — an exit-0 `[proposed]` leg is a SKIP, never a PASS); `implementation-gate.md:57` row 2 already records `client_id=sso-admin-console` (Branch B — verify-only, no amendment); the no-credentials path SKIPs cleanly via `CONFIG.require_credentials()` at drill :113-118 (`sys.exit(0)` at :118).
5. **Budget fact (new, recorded per AC-6):** the drill is **439 lines at HEAD** (working tree; 292 tracked at `3b64c58`) — already past the sibling design's 280-line drill budget; `engineering.yaml:11`'s 400-line `filesize.max_lines` cap is Dart-scoped (`checks/filesize.py:4` "for .dart files") and does not gate the `.py` drill. The DCR leg adds **+52 lines (docstring +7, `【1b】` block +41, step-3 mutation +4) → 491 working-tree / 344 committed** — **measured** by applying the design's §3.4 block to a temp copy (the earlier ≈55-65 → ≈495-500 estimate is superseded). Deviation recorded in §2/§5.

---

## 2. Scope

**In scope (developer-module lens, drill-only delta + one record)**

- **REQ-1 — DCR leg of the shared drill:** a new additive step executed **before the login leg** that POSTs `{PROXY}/register` with the `register_panel` wire shape and asserts the RFC 7591 server-assigned response `client_id` equals the agreed value.
- **REQ-2 — login leg keyed to the DCR-obtained `client_id`:** the drill's login uses the DCR response id on `POST {PROXY}/auth/login` (sso_client.dart:92 wire) and the sink assertions (exactly one `auth.login.success` row, no duplicates, re-settle stable, zero matches → exit 1, `[proposed]` fallback without false PASS) key to that id.
- **REQ-0 — DCR evidence channel:** the `[RESOLVED]` record at `docs/proposals/audit-contract-batch-snaplink-console.md:13-14` (device + setup legs only today) gains a third B6-2 bullet naming Branch B with the drill output attached.
- **REQ-3 — zero-delta floor:** zero changes under `lib/screens/developer/` and `lib/`; `test/developer_api_test.dart` + `test/dcr_widgets_test.dart` green and unchanged; drill wiring at `run_all.py:196` / `full_stack_verify.py:113` preserved; drill line-budget deviation recorded here.

**Out of scope (explicitly not changed by this lens)**

- The Branch A/B login-wire value decision: **already resolved — Branch B**, constant landed at `sso_client.dart:82`, records closed at `audit-contract-batch-snaplink-console.md:13`. `implementation-gate.md:57` row 2 already records `client_id=sso-admin-console` — verify-only, no amendment.
- Any `auth.login.success` emission code (zero emission strings in this repo; emission is IdP-side, B4-5) — verified only by the drill, `[proposed]` when unverifiable.
- The sibling lenses' artifacts (`b6-2-lib-screens-client-id-alignment-spec.md` regression pins, `test/client_id_contract_test.dart`, `SSOAdminClient.firstPartyClientId` landing in `lib/api`) — referenced by name only.
- The device leg (steps 【2】【3】-【6】), the setup leg (【3b】) and the T-12 read leg (【6】): already landed; the DCR leg must not renumber or rewrite them (additive convention of 【3b】 applies to 【1b】).

---

## 3. Requirements

### REQ-0 — DCR evidence channel closes the `[RESOLVED]` record (Branch B)

The B6-2 block of `docs/proposals/audit-contract-batch-snaplink-console.md` (:13-14, device + setup legs) gains a **third `[RESOLVED]` bullet** for the DCR leg:

1. **Branch named:** Branch B (`AGREED_CLIENT_ID = 'sso-admin-console'` — the already-landed constant at `sso_client.dart:82`); no re-litigation of the branch choice.
2. **Drill output attached:** the recorded outcome of the drill's DCR leg (PASS/FAIL + the `/register` response and the sink query) — the in-repo-adjacent probe of whether the deployed IdP issues/accepts `sso-admin-console`; a non-matching issued id is contract evidence, never a silent pass.
3. **Deviation recorded:** if the sink legs ran `[proposed]` (B4-5 not landed / no emission), that deviation is named in the same bullet; the DCR register + login round-trip are always asserted when a stack is present.
4. **`implementation-gate.md:57` row 2:** verify-only (already `client_id=sso-admin-console`); no amendment under Branch B.

**Testable:** `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` returns a B6-2 record naming the DCR leg and Branch B with drill output attached; `grep -n "register" docs/proposals/audit-contract-batch-snaplink-console.md` hits in that bullet; `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` still hits at `:57`.

### REQ-1 — DCR drill leg: the aligned `client_id` is obtainable via POST `/register` (module wire)

`tests/integration/audit_login_drill.py` gains a DCR leg, executed **before the login leg**, additive and local-variable-only (the 【3b】 convention):

1. **Placement:** a new step block **【1b】** between 【1】 (precondition) and 【2】 (device URL shape) — i.e., before the login at 【3】; uses only local `dcr_*` names; never writes step 3's `login_data`/`token`/`tenant_id`.
2. **Register (module wire):** `POST {PROXY}/register` with `Content-Type: application/json`, body built from the `register_panel` request shape — the same keys `DcrClientMetadata.toRegistrationWire()` emits (`dcr_models.dart:128-139`): the mandatory five `client_name`, `redirect_uris`, `scope`, `token_endpoint_auth_method`, `token_strategy`, plus optional `grant_types`/`require_pkce` (and no other keys; no bearer unless an initial access token is configured — the drill sends none, matching open registration).
3. **No `client_id` in the body:** a runtime check asserts `'client_id' not in body` (RFC 7591 server-assigned; `dcr_models.dart:67` lists it in `protectedResponseKeys`). A body containing `client_id` FAILs the leg.
4. **Assert the aligned id is issued:** the 2xx response is parsed; check `response['client_id'] == AGREED_CLIENT_ID`. Any other issued id — or a non-2xx response — FAILs the check **with the response printed** (the `check()` detail carries the body) and the drill exits 1 via its existing report path. Never a silent pass; the output is the REQ-0 evidence channel.
5. **Never `[proposed]`:** the register round-trip is always asserted whenever a stack is configured (the file-top no-credentials gate SKIPs cleanly); an unverifiable DCR response is a FAIL, not a `[proposed]` mark.
6. **Docstring:** the module header (:2 "device redirect-leg facts") updates to name the DCR leg so the file's stated lens matches its content.

**Testable:** `grep -n "register" tests/integration/audit_login_drill.py` hits (POST to `/register` + equality assertion), with the DCR step block textually before the login POST block; `grep -n "client_id" tests/integration/audit_login_drill.py` shows the body-guard and the equality assertion; against the deployed stack, a DCR endpoint that issues any id other than `sso-admin-console` yields exit 1 with the response printed.

### REQ-2 — Login leg keyed to the DCR-obtained `client_id` → exactly one `auth.login.success` row, no duplicates

1. **Precondition stays:** step 【1】 `CONFIG.client_id == AGREED_CLIENT_ID` is unchanged (`test_config.py:43-44`).
2. **Login uses the DCR-obtained id:** step 【3】's `POST {PROXY}/auth/login` payload's `client_id` is sourced from the DCR response value (REQ-1 step 4) — mirroring the in-repo pivot `register_panel.dart:107` → `:112` → `developer_screen.dart:81` → `manage_panel.dart:46` — on the `sso_client.dart:92` wire (`CONFIG.login_payload()`, `test_config.py:86`). The existing equality check (`login_data.get('client_id') == AGREED_CLIENT_ID`) stays; the id the sink must attribute is exactly the id the module would pivot into manage.
3. **Sink assertions** (existing steps 4-5 semantics, filter keyed to the DCR-obtained id; server route only — REQ-4 of the module scope):
   - `GET {API}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` (Bearer; `<t>` from the JWT `tenant_id` claim) → **exactly one** row with the agreed `client_id`;
   - re-login once → **exactly two rows total**, no repeated event id/trace_id;
   - settle ≥ `max(10, SNAPLINK_DRILL_SETTLE_SECONDS)` s → re-query → count **unchanged**;
   - **zero matches → exit 1** (never a skip, never a PASS);
   - unverifiable sink/emission → legs marked `[proposed]` with the query + result logged and the deviation recorded in the REQ-0 bullet — **no false PASS** (the existing `[proposed]` convention, `run_all.py:196` treats exit-0 `[proposed]` as SKIP).

**Testable:** `python3 tests/integration/audit_login_drill.py` against the deployed stack — exactly-one-row + no-duplicates + re-settle-stable assertions hold or are explicitly `[proposed]`; the reported `client_id` equals the DCR-obtained value (== `AGREED_CLIENT_ID`); zero matches exits 1; `grep -n "audit/events" tests/integration/audit_login_drill.py` hits (server route only, no ring key in the drill).

### REQ-3 — Zero-delta floor (both branches; Branch B is the state)

1. **Zero production delta:** no changes under `lib/screens/developer/` and `lib/` — the DCR leg is a drill-only delta plus the REQ-0 record. The module's register fixtures stay server-assigned mock ids (`'client-1'` at `test/developer_api_test.dart:29,46`, `test/dcr_widgets_test.dart:24-30`): registration cannot choose `client_id`, so the aligned constant never belongs in module fixtures.
2. **Tests stay green unchanged:** `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart` — zero diff to either file.
3. **Wiring preserved:** `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` still hits (`:196` / `:113`, skip_markers intact).
4. **Drill budget — deviation recorded:** the drill is 439 lines at HEAD (working tree; 292 tracked at `3b64c58`), already past the sibling design's 280-line drill budget (the `engineering.yaml:11` 400-line cap is Dart-scoped, `checks/filesize.py:4`); the DCR leg adds **+52 lines (docstring +7, `【1b】` block +41, step-3 mutation +4) → ≈491 working-tree / 344 committed** (measured by applying the design's §3.4 block to a temp copy; the earlier ≈55-65 → ≈495-500 estimate is superseded). **Deviation recorded here by this requirement**: the 280-line budget is exceeded at HEAD and remains exceeded after this change; mitigation = reuse the existing helpers (`check`/`curl`/`settle_seconds`/`sink_rows`), one new `register_client()` helper, no new imports or dependencies. If the landed leg stays within 280 lines, the deviation entry is marked moot.

**Testable:** `git diff --stat -- lib/` and `git status --porcelain lib/screens/developer/` empty; `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` empty; `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart` green; both wiring greps hit; this §3.REQ-3.4 paragraph exists as the budget-deviation record.

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | `grep -n "register" tests/integration/audit_login_drill.py` hits: a DCR leg executes before the login leg, POSTs `{PROXY}/register` with toRegistrationWire() keys (client_name/redirect_uris/scope/token_endpoint_auth_method/token_strategy, optional grant_types/require_pkce) and no client_id key in the body | `grep -n "register" tests/integration/audit_login_drill.py` → ≥1 hit; the DCR step block (【1b】) appears textually before the login POST block (【3】); the body-assembly line carries the five mandatory `toRegistrationWire()` keys and `grant_types`/`require_pkce` only optionally; a runtime `check("…no client_id…", 'client_id' not in dcr_body)` guard exists (grep-verifiable) — REQ-1 |
| AC-2 | Drill asserts the 2xx response client_id equals AGREED_CLIENT_ID ('sso-admin-console'); any other issued id → exit 1 with response printed, never a silent pass | `grep -n "AGREED_CLIENT_ID" tests/integration/audit_login_drill.py` shows the equality assertion with the parsed response as `check()` detail; non-2xx or mismatched id → `FAIL` → `sys.exit(1)` via the existing report path (symbol `sys.exit(1 if FAIL else 0)` — pre-migration `:438-439`; a symbol pin, never a line pin); run against the deployed stack to observe exit 1 on mismatch — REQ-1.4 |
| AC-3 | Drill precondition `CONFIG.client_id == AGREED_CLIENT_ID` stays (already at step 【1】); login leg uses the DCR-obtained client_id on POST {PROXY}/auth/login (sso_client.dart:92 wire) | Step 【1】 block unchanged (`grep -n "CONFIG.client_id == AGREED_CLIENT_ID"` hits at 【1】); step 【3】 derives the payload `client_id` from the DCR response value and POSTs `{PROXY}/auth/login` with `CONFIG.login_payload()` (grep-verifiable derivation line) — REQ-2.1-2 |
| AC-4 | Sink assertions via GET {API}/api/v1/audit/events only: exactly one auth.login.success row with the agreed client_id; re-login → exactly two rows total, no repeated event id; re-settle → count unchanged; zero matches → exit 1; unverifiable legs marked [proposed] with deviation logged, no false PASS | Existing steps 4-5 semantics keyed to the DCR-obtained id: `grep -n "audit/events"` hits (server route only); `len(matching) == 1` check; second login → `len(rows_after) == 2` + `len(event_ids) == len(set(event_ids))`; re-settle count-stable check; zero matches → `FAIL` → exit 1; unverifiable → `[proposed]` print + deviation logged (never a false PASS; `run_all.py:196` treats exit-0 `[proposed]` as SKIP) — REQ-2.3 |
| AC-5 | `[RESOLVED]` record at docs/proposals/audit-contract-batch-snaplink-console.md gains the DCR evidence channel (drill output attached, branch named) | `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` shows a third B6-2 bullet naming Branch B and the DCR leg with drill output attached; `grep -n "register"` hits in that bullet — REQ-0 |
| AC-6 | Zero changes under lib/screens/developer/ and lib/ (drill-only delta); flutter test test/developer_api_test.dart test/dcr_widgets_test.dart stay green unchanged; drill ≤ 280 lines or the budget deviation is recorded in the spec | `git diff --stat -- lib/` empty + `git status --porcelain lib/screens/developer/` empty; `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` empty and `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart` green; **budget deviation recorded in §3 REQ-3.4** (drill 439 lines at HEAD working tree / 292 tracked; 491 measured after the leg — 344 committed; mitigation: reuse existing helpers + one `register_client()` helper) — REQ-3 |
| AC-7 | `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` still hits (wiring preserved) | Both greps hit (`run_all.py:196`, `full_stack_verify.py:113`) with timeout=300 and skip_markers intact — REQ-3.3 |

Gate relationship: AC-2 gates AC-3 (the login uses the id only after the DCR assertion passes); AC-5 depends on AC-2/AC-4 outcomes (the record attaches the drill output); AC-6 and AC-7 are the unconditional no-regression floor. All seven are executable as written.

---

## 5. Dependencies and constraints

- **B4-5** owns the IdP-side sink emission (`implementation-gate.md:57` dependency column): until landed, the sink legs run `[proposed]` (AC-4 fallback); the DCR register + login round-trip (REQ-1, REQ-2.1-2) are never `[proposed]` on a configured stack.
- **B4-1** (tenant claim): the drill already decodes the JWT itself (`decode_jwt`); the DCR login leg reuses the step-3 decode — a missing `tenant_id` claim FAILs loudly, no new claim-parsing code.
- **Constraint — RFC 7591:** `client_id` is server-assigned; the registration body never carries it (`dcr_models.dart:67` `protectedResponseKeys`).
- **Constraint — zero production delta:** `lib/screens/developer/**` and `lib/**` untouched; no emission code; no `lib/i18n` delta; no new endpoints; drill-only delta + the REQ-0 record.
- **Constraint — additive drill:** the DCR leg is 【1b】-style additive (the 【3b】 convention); device/setup/read legs are not renumbered or rewritten.
- **Consistency:** shared artifacts (`AGREED_CLIENT_ID = 'sso-admin-console'`, the drill file, the `[RESOLVED]` record) match the sibling lens specs so all buckets land one change set.

## 6. Risks and rollback

- **Deployed IdP issues a different `client_id`** (or has no `/register`): drill FAILs with the response printed — contract evidence for REQ-0; no code change (rollback = current state); the branch choice is re-examined, never papered over.
- **Sink emission unverifiable** (B4-5 not landed / no stack): AC-4 `[proposed]` fallback — the legs log instead of assert; no false PASS; the deviation is named in the REQ-0 bullet.
- **Module-fixture literal drift** (renaming server-assigned mock ids `'client-1'` to the aligned value): prohibited by REQ-3.1 — registration cannot choose `client_id`; fixtures stay server-shaped.
- **Budget overrun** (drill grows past ≈491 lines): the deviation is pre-recorded (§3 REQ-3.4) with the helper-reuse mitigation — the figure is measured, not estimated; if the landed leg stays ≤ 280 the entry is marked moot.
- **Wiring regressions** (skip_markers lost): covered by AC-7's grep pair plus the existing Gate 5 review.
