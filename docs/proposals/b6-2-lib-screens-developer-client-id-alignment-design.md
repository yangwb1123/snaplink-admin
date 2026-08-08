# B6-2 Design — `lib/screens/developer` lens: DCR-backed drill (RFC 7591) + register→manage pivot regression pin + no-forgery joint check

Module: `lib/screens/developer` (analysis bucket `docs/auto/analyses/lib-screens-developer-3899da21.json`) · Direction: B6-2 · Value: 9 · Risk reduction: 7 · Effort: 2 · Confidence: 9 · Status: design
Design for the requirements spec `docs/proposals/b6-2-lib-screens-developer-client-id-alignment-spec.md` (REQ-0 … REQ-5, AC-1 … AC-4).
Sibling instances: `docs/proposals/b6-2-lib-api-client-id-alignment-design.md` (mechanism: `SSOAdminClient.firstPartyClientId` constant) and `docs/proposals/b6-2-lib-screens-client-id-alignment-design.md` (live login-wire pin + drill login leg). This design owns the **developer-module surface**: the DCR evidence channel (the only in-repo surface that creates OAuth clients), the drill's DCR leg, the register→manage pivot regression pin, and the no-localStorage-forgery joint check with B6-1 — and names the **same constant, drill file, and `[RESOLVED]` record** so all lenses land one change set.

Branch-parametric (REQ-0): Branch A (rename to `console`) vs Branch B (contract exception already recorded: `sso-admin-console`). The branch value enters this module **only at drill time** via the real DCR response; the module's production files and test fixtures are branch-neutral and byte-identical under both branches (REQ-3 nuance, REQ-5).

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

Every citation in the requirements evidence was re-checked line-exact against the repository. **All substantive claims hold.** The two corrections already recorded in the spec are confirmed; three new cross-instance line drifts and one new module fact are adopted below:

| Evidence claim | Verification result |
|---|---|
| `lib/app_router.dart:35` — `OidcLoginScreen(defaultClientId: 'sso-admin-console', …)`, `ProductEntry.login` arm `:34-37` | ✅ exact |
| `lib/api/sso_client.dart:86` (`String clientId = 'sso-admin-console',` default) and `:92` (`'client_id': clientId,` in POST `/auth/login` body, keys `:90-96`) | ✅ exact |
| `test/sso_client_test.dart:18` — whole-body map assertion (`:16-22`: provider/client_id/scope/resource/credential) | ✅ exact |
| `lib/screens/oidc_login/oidc_login_screen.dart:159-161` — `_effectiveClientId` fallback to `widget.defaultClientId` | ✅ exact |
| `lib/screens/developer/register_panel.dart:107,112` — `clientId = result['client_id']?.toString() ?? ''` at `:107`; `widget.onManage(clientId, rat, safeSnapshot)` at `:112`; response is the **only** source of `client_id` in the module | ✅ exact |
| `lib/screens/developer/developer_screen.dart:80` — **confirmed drift**: method `_openManageWithApp` declared at `:81`; `:78-80` is the doc comment; `:85-90` `_manageKey.currentState?.loadWithRegistration(clientId, token, registrationSnapshot)` (target `manage_panel.dart:46`) | ✅ correction adopted |
| `test/developer_api_test.dart:29,46` — mock `/register` 201 `{"client_id":"client-1"}` at `:29`; `expect(result['client_id'], 'client-1')` at `:46`; request-body assertion `:20-28` contains **no** `client_id` key | ✅ exact lines; overstated claim confirmed — the register→manage **pivot** is pinned by `test/dcr_widgets_test.dart:24-30` (`'client_id': 'client-1'` response map `:24-28` → `onManage: () => managed = true` at `:30`); `:111-129` (delete-dialog client_id entry, `'client-123'`) and `:168-212` (manage-panel `client-1`/`rat-1` entry) also use **server-assigned mock ids** |
| `docs/proposals/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` record with stale inner citation `app_router.dart:55` (actual `:35`) | ✅ exact (stale citation fixed when the record closes, REQ-0) |
| `[PROPOSED]` — IdP/sink registry state external; `grep -rn "auth.login.success" lib/ test/ tests/` → 0 hits; no client registry in this repo | ✅ confirmed (0 hits); `lib/services/audit_log_service.dart:66` (`_storageKey = 'sso_audit_log'`) and `event_bus.dart` are UI-local, not sink emitters |
| `dcr_models.dart:50-63` — `typedKeys` has **no** `client_id`; `:66-72` `protectedResponseKeys` lists `client_id`/`client_secret`/`client_id_issued_at`/`client_secret_expires_at`/`registration_access_token`/`registration_client_uri` (`client_id` at `:67`) | ✅ exact — RFC 7591 server-assigned, never sent |
| `dcr_models.dart:151-167` — `toRegistrationWire()` body keys: `client_name`, `redirect_uris`, `scope`, `token_endpoint_auth_method`, `token_strategy`, `grant_types`, `response_types`, `contacts`, `post_logout_redirect_uris`, `allowed_authenticators`, `allowed_resources`, conditional `tenant_id`, `require_pkce` | ✅ exact (new finding: this is the drill's register-body shape, §3.1) |
| `developer_api.dart:44-49` — `DeveloperApi` defaults `_baseUri = ProductApiOrigin.baseUri`; `:104` `_baseUri.resolve('/register')` in `_registerBody`; `registerMetadata` `:62-68`; `register` `:75-95`; RFC 7592 GET/PUT/DELETE `:118,137,156` | ✅ exact (new finding: the drill's `{PROXY}/register` mirrors the module origin) |
| `snaplink_admin_api.dart:82` — `AuditLogService().record(` (sole ring writer); `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/developer/` → exit 1 (zero hits) | ✅ exact |
| `snaplink_admin_types.dart:310-312` — `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}` | ✅ exact |
| `tests/integration/test_config.py:43-44` — `SNAPLINK_TEST_CLIENT_ID` default `'sso-admin-console'`; `IntegrationConfigurationError` at `:8`; `require_credentials()` at `:71` | ✅ exact |
| `api_login_e2e.py:59-77` — real `POST {PROXY}/auth/login` + JWT decode; SKIP idiom at `:27-36` (`try: CONFIG.require_credentials() … print SKIP; sys.exit(0)`) | ✅ exact |
| `full_integration_test.py:31-33` — `decode_jwt` helper | ✅ exact |
| `docs/campaigns/implementation-gate.md:57` — row 2: `边缘生成验证：login → auth.login.success（client_id=sso-admin-console） | sink 出现 sso-admin-console login 事件；无重复 | B4-5` | ✅ exact (contract authority; quote corrected — the gate records `sso-admin-console`) |
| `engineering.yaml:11` — `max_lines: 400` | ✅ exact |
| Harness wiring: `run_all.py` Gate 5 guard `if not args.skip_e2e and not args.ci` at `:125`; proxy start `:128-150`; e2e list with `e2e_runner.py` at `:164-166`; `full_stack_verify.py` step 5 = Full Integration `:104-105` + Detail API `:107-109`; step 6 at `:111-112`; proxy started at step 4 | ✅ exact |

**Cross-instance drifts corrected in this design:**

- **C1 — Canvas note line.** The api-sibling spec cites `browser_login_test.py:66-67` for the Flutter-canvas limitation; the actual comment `# Flutter renders to canvas, so we can't easily find text fields` is at `browser_login_test.py:89`. The drill header (§3.1) cites `:89`.
- **C2 — `full_stack_verify.py` wiring point.** The Detail API step spans `:107-109`; the live drill entry sits at `:113` (immediately after it — matching the sibling plans' `:106-108`/`:107-109` insertion points). It is an **uncommitted diff**: verify, do not re-insert; commit at M4.
- **C3 — `test/client_id_contract_test.dart` does not exist today.** The developer spec (REQ-0, AC-1) references it as the sibling-owned Branch B pin; the screens design resolves D1 (both-branches pin). This lens only **grep-references** it (§7) — no change here.
- **C4 — `register_panel.dart` wire path.** The panel calls `widget.api.registerMetadata(metadata: …, initialAccessToken: …)` (`register_panel.dart:75-86`), which posts `metadata.toRegistrationWire()` — the drill mirrors `toRegistrationWire()` keys (§3.1), not the legacy `register()` explicit-args path (`developer_api.dart:75-95`), so the drill shape tracks what the UI actually sends.

**Module-scope facts confirmed and folded in:**

1. The module is the **only in-repo OAuth-client creation surface**; the drill asserts the *response* `client_id` (RFC 7591), never sends one.
2. The register→manage handoff (`register_panel.dart:107` → `:112` → `developer_screen.dart:81` → `manage_panel.dart:46`) is pinned by `developer_api_test.dart:29,46` + `dcr_widgets_test.dart:24-30` — unchanged under both branches.
3. The module cannot forge sink rows (zero `AuditLogService` refs); the drill's evidence channel is the sink read API only.
4. **Module test fixtures use server-assigned mock ids** (`'client-1'`, `'client-123'`) — never the console's own id; under Branch A they must **not** be renamed (REQ-3 nuance vs. the `lib/api` lens, where literals *are* the console's own id sites).

---

## 2. Design summary

**Files touched: 0 production + 0 module test files + 1 new drill + 2 harness wiring lines + 1 doc record (+1 shared doc under Branch B). No new endpoints; no signature change anywhere in the module.**

1. **Adopt** the existing untracked `tests/integration/audit_login_drill.py` (same file the sibling lenses name — already wired at `run_all.py:169` / `full_stack_verify.py:113` by an uncommitted diff), **extending** it with the **DCR leg** (REQ-1) executed before the login leg; login uses the DCR-obtained `client_id` (REQ-2); sink assertions read only `GET /api/v1/audit/events` (REQ-4); ≤ 280 lines (REQ-5 — 214 today, extension budget ~66). Do not recreate or overwrite; commit the adopted file + wiring diff at M4.
2. `tests/integration/run_all.py` — **verify** the existing `run_e2e_test(...)` drill entry at `:169` (end of Gate 5, after `e2e_runner.py` — the `:164-166` insertion point; uncommitted diff; commit, do not re-insert).
3. `tests/integration/full_stack_verify.py` — **verify** the existing `step(...)` drill entry at `:113` (end of step 5, after the Detail API step `:107-109`; uncommitted diff; commit, do not re-insert).
4. `docs/proposals/audit-contract-batch-snaplink-console.md:12` — `[MISMATCH]` → `[RESOLVED]` naming the branch + drill evidence; stale `app_router.dart:55` → `:35` (REQ-0).
5. Branch B: no gate amendment (no-op — gate:57 already records `client_id=sso-admin-console`, shared with the screens lens §3.7); under Branch A the row flips to `client_id=console`.
6. The value change itself (`sso_client.dart:86`, `app_router.dart:35`, `sso_client_test.dart:18`, `test_config.py:44`, `DEPLOY.md:29`, `test/client_id_contract_test.dart`) is owned by the sibling change sets — this lens only **asserts** it (drill step 1) and **greps** it (REQ-5).

**Key decisions:**

- **D1 — Zero production diff is the design, not a constraint.** The module is a pure consumer: the aligned value enters only at drill time via the real DCR response. REQ-5 is enforced by `git diff` guards, so no module file appears in the change set at all. This is what makes the lens's rollback a no-op (F2, §6).
- **D2 — The drill's DCR leg asserts the RFC 7591 *response* id.** The register body mirrors `DcrClientMetadata.toRegistrationWire()` (`dcr_models.dart:151-167`) exactly and **must not** contain `client_id` (`typedKeys` has none; `protectedResponseKeys` at `:66-72` guards the round-trip). The assertion is `response.client_id == AGREED_CLIENT_ID`; any other issued id → FAIL with the response printed (REQ-0 evidence channel, no false PASS).
- **D3 — The drill login leg uses the DCR-obtained id**, mirroring the module's own handoff `register_panel.dart:107,112` → `developer_screen.dart:81` → `manage_panel.dart:46`, so the id the sink must attribute is exactly the id the module would pivot into manage.
- **D4 — Module mock ids are protected fixtures.** `'client-1'`/`'client-123'` in `developer_api_test.dart`/`dcr_widgets_test.dart` are server-assigned DCR response shapes. Under Branch A the sibling rename must **not** reach them — registration cannot choose `client_id` (REQ-3). Enforced by a byte-identical `git diff` guard on the two test files.
- **D5 — Drill placement is Gate 5 / step 5** (proxy dependency): `run_all.py` starts the proxy only inside Gate 5 (`:128-150`, guard `:125`); `full_stack_verify.py` starts it at step 4. The drill sits after `e2e_runner.py` (`:164-166`) and after Detail API (`:107-109`). `--ci` skips Gate 5 — same as `e2e_runner.py`/browser tests; documented, not a defect.
- **D6 — Drill SKIP semantics**: missing credentials → `SKIP:` + exit 0 (mirrors `api_login_e2e.py:27-36`); FAIL (exit 1) only for genuine contract violations. Prevents false harness failures in dev without a live stack.
- **D7 — `[proposed]` fallback (sibling-consistent)**: the sink-side legs (exactly-one-row, no-duplicates) depend on BFF/sink emission this repo cannot generate (0 grep hits, §1). Unverifiable → log the query + result, mark `[proposed]`, record the deviation in the `[RESOLVED]` note, exit without a false PASS. The DCR leg and the login round-trip are always asserted when a stack is present.
- **D8 — The no-forgery guarantee is grep-provable**: zero `AuditLogService`/`sso_audit_log` references in `lib/screens/developer/`; the drill queries only the server route; a ring row absent from the server response is not evidence.

---

## 3. API changes (concrete)

No production API in `lib/screens/developer/` changes. The lens's "API surface" is the drill file's wire contract + the harness wiring + the doc records.

### 3.1 `tests/integration/audit_login_drill.py` (existing untracked — adopt + extend with DCR leg; REQ-1 + REQ-2 + REQ-4, both branches)

Checked-in, runnable file (not a runbook pointer); the shared artifact named by all three sibling specs. Budget ≤ 280 lines (`engineering.yaml:11` = 400; reference `api_login_e2e.py` = 166). Header docstring cites the canvas limitation at `browser_login_test.py:89` (C1) as the reason the login leg is API-driven through the proxy — the same wire the screens drive (`sso_client.dart:92`).

```python
#!/usr/bin/env python3
"""B6-2 client_id contract drill — DCR leg (lib/screens/developer lens).

Proves: (a) the aligned first-party client_id is registerable via POST
/register (RFC 7591, server-assigned — never sent in the body), (b) a
login with the DCR-obtained id yields exactly one auth.login.success
row in the sink, no duplicates (implementation-gate.md:57 '无重复').
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
# Step 2 (REQ-1 DCR leg):   POST {CONFIG.proxy_url}/register
#   body keys mirror DcrClientMetadata.toRegistrationWire()
#   (dcr_models.dart:151-167): client_name, redirect_uris, scope,
#   token_endpoint_auth_method, token_strategy, grant_types,
#   response_types, contacts, post_logout_redirect_uris,
#   allowed_authenticators, allowed_resources, tenant_id?, require_pkce.
#   NO 'client_id' key (RFC 7591 server-assigned; dcr_models.dart:50-63
#   typedKeys has none, :66-72 protects it). Optional Bearer
#   initial_access_token mirrors register_panel.dart:75-86.
#   Assert 2xx; assert response['client_id'] == AGREED_CLIENT_ID.
#   Any other issued id → FAIL, print the full response: contract
#   evidence for REQ-0 (D2) — never a silent pass.
# Step 3 (REQ-2 login):     POST {CONFIG.proxy_url}/auth/login with
#   client_id = the DCR-obtained value (Step 2) + CONFIG.login_payload()
#   (the wire sso_client.dart:92 drives); assert access_token;
#   decode JWT; extract tenant_id claim → <t>; missing claim → FAIL
#   with the B4-1 dependency recorded (drill does NOT implement parsing)
# Step 4 (REQ-2 sink):      GET {CONFIG.api_url}/api/v1/audit/events
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

### 3.2 Harness wiring (REQ-1/REQ-2, both branches)

- `tests/integration/run_all.py` — **already wired at `:169`** (inside Gate 5, after the Python E2E Runner entry — the `:164-166` insertion point is where the live entry sits); uncommitted diff; verify, do not re-insert:
  ```python
  run_e2e_test('B6-2 Login Drill (client_id contract)',
               ['python3', 'tests/integration/audit_login_drill.py'], timeout=300)
  ```
- `tests/integration/full_stack_verify.py` — **already wired at `:113`** (end of step 5, after the Detail API step — the `:107-109` insertion point is where the live entry sits); uncommitted diff; verify, do not re-insert:
  ```python
  step('B6-2 Login Drill (client_id contract)',
       ['python3', 'tests/integration/audit_login_drill.py'], 300)
  ```

### 3.3 Doc records (REQ-0, both branches)

`docs/proposals/audit-contract-batch-snaplink-console.md:12` — replace the `[MISMATCH]` record (exact text shared with the sibling designs):

```markdown
- `[RESOLVED]`（B6-2, <date>）：Branch <A|B> chosen per drill evidence
  (<drill output attached>); code aligned on
  `SSOAdminClient.firstPartyClientId` (`app_router.dart:35`,
  `sso_client.dart:86`, `sso_client_test.dart:18` — citation corrected
  from the stale `:55`). DCR evidence: POST /register returned
  client_id=<agreed value> (or <issued value> → FAIL attached).
```

Branch B additionally **verifies** `docs/campaigns/implementation-gate.md:57` row 2 (shared with the screens lens §3.7) — **no amendment required**: the gate already records `client_id=sso-admin-console` with acceptance "sink 出现 sso-admin-console login 事件；无重复" (the earlier "amend the gate" narrative was based on a misquote; the described amendment is a no-op against the real text). Gate edit count under Branch B: zero.

### 3.4 Negative constraints (REQ-3/REQ-5, both branches — enforced, not aspirational)

The following must remain **byte-identical** at HEAD of the change set (guards in §7):

- Production: `register_panel.dart`, `developer_screen.dart`, `manage_panel.dart`, `developer_api.dart`, `dcr_models.dart`, `dcr_form_controller.dart`, `dcr_metadata_form.dart`, `dcr_validation.dart`, `dcr_credentials.dart`, `dcr_delete_dialog.dart`, `dcr_round_trip_notice.dart`, `dcr_update_projection.dart`, `discovery_region_notice.dart`.
- Tests: `test/developer_api_test.dart`, `test/dcr_widgets_test.dart`, `test/dcr_models_test.dart`, `test/developer_serving_region_test.dart`, `test/list_state_manager_test.dart` (all stay green and unchanged in shape; `'client-1'`/`'client-123'` fixtures untouched under Branch A — D4).

---

## 4. Compatibility constraints

1. **Zero module diff**: no `lib/screens/developer/**` file appears in the change set (REQ-5). The branch decision and constant land in the sibling change sets; this lens consumes them at drill time only.
2. **RFC 7591 wire semantics**: `client_id` is server-assigned — never sent in a registration body; `typedKeys` (`dcr_models.dart:50-63`) and `protectedResponseKeys` (`:66-72`) already enforce this on the Dart side; the drill body mirrors `toRegistrationWire()` keys (`:151-167`) and the drill's only registration assertion is on the **response** id.
3. **Test-shape stability (REQ-3)**: `developer_api_test.dart:29,46` and `dcr_widgets_test.dart:24-30,111-129,168-212` pin the module's round-trip with server-assigned mock ids; renaming them to the aligned value is prohibited (registration cannot choose `client_id`). The aligned value enters the module only via the real DCR response at drill time.
4. **No-forgery invariant (REQ-4)**: zero `AuditLogService`/`audit_log_service`/`sso_audit_log` references in `lib/screens/developer/` (grep-guarded); the drill reads only `GET /api/v1/audit/events` and never the localStorage ring (`audit_log_service.dart:66`); a ring-only row is not evidence.
5. **Shared-artifact naming**: `SSOAdminClient.firstPartyClientId`, `tests/integration/audit_login_drill.py`, and the `[RESOLVED]` record are the same artifacts the sibling specs name — one change set across all lenses.
6. **Harness semantics**: drill SKIP (exit 0) without live stack/credentials (D6); `run_all.py --ci` skips Gate 5 and therefore the drill — same as `e2e_runner.py` (documented, accepted); `api_login_e2e.py` stays unregistered (conventions reference only).
7. **Filesize gate**: `engineering.yaml:11` `max_lines: 400` applies to `.py`; drill budget ≤ 280 lines (reference `api_login_e2e.py` = 166).
8. **External constraint**: the IdP client registry is outside this repo; the DCR leg (step 2) is the only in-repo-adjacent evidence channel and feeds REQ-0. `test_config.py:43-44`'s `SNAPLINK_TEST_CLIENT_ID` default changes only under Branch A (sibling change set, `test_config.py:44`).
9. **Read-only JWT handling**: the drill decodes the login JWT with the `full_integration_test.py:29-33` idiom to extract `tenant_id` (B4-1 dependency declared, not implemented); no claim parsing, no token storage beyond the drill's process-local variable.

---

## 5. Failure modes

| # | Mode | Detection | Mitigation / rollback |
|---|---|---|---|
| F1 | DCR response `client_id` ≠ agreed value (deployed IdP assigns its own id) | Drill step 2 FAIL with response printed | Contract evidence for REQ-0: attach output to `[RESOLVED]`, re-examine the branch choice; **no code change** — rollback = current state. Never papered over. |
| F2 | IdP registers neither id | Drill step 2 FAIL / step 1 config mismatch | REQ-0 cannot conclude → do not land the sibling value commit; this lens's drill stays inert (SKIP) — zero module diff means zero rollback surface. |
| F3 | Sibling Branch A rename reaches module test fixtures (`'client-1'` → `'console'`) | `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` non-empty; tests still green but contract-wrong | REQ-3 guard (byte-identical diff) is an acceptance check; the rename is enumerated in the sibling change set, never pattern-based (screens design F4 analog). |
| F4 | Drill sends `client_id` in the register body | Drill step 2 4xx/ignored; RFC 7591 violation; grep `"client_id"` in the drill's register-body construction | Body mirrors `toRegistrationWire()` keys only (C4); code review + a `client_id`-absent assertion in the drill itself. |
| F5 | Drill FAIL at sink legs (no row / duplicates / wrong claim) | Drill exit 1 with query output | Attach FAIL output to `[RESOLVED]`; do **not** close the record; defer to B4-5 (gate row owner). No code revert needed. |
| F6 | Sink row lacks a `client_id` claim (external schema) | Step 4 FAIL on missing field | Recorded as a documented contract deviation; D7 `[proposed]` fallback applies — log instead of asserting when the emission/field cannot be verified from this repo. |
| F7 | `tenant_id` claim missing from the login JWT | Step 3 FAIL | Record the B4-1 dependency; the drill does not implement claim parsing — by design. |
| F8 | Sink read API rejects `event_types`/`tenant_id` query params | Step 4 4xx | FAIL is contract evidence for B4-5; no existing test uses these params (verified) — first consumer; the drill does not adapt. |
| F9 | Event-ingestion lag produces a transient "no row yet" | Step 4/5 count assertions fail transiently | Settle interval `max(10, SNAPLINK_DRILL_SETTLE_SECONDS)`s + count-unchanged re-query (step 5); env knob documented in the drill header. |
| F10 | Repeated drill runs accumulate registrations (registry pollution) | IdP registry grows per run | Documented: one registration per run is expected drill behavior; FAIL only on id mismatch (F1); the `[RESOLVED]` note records the run count. |
| F11 | Harness false-fail without a live stack | Drill exit 1 in a dev-only environment | D6 SKIP semantics: missing credentials → exit 0 with `SKIP:` line. |
| F12 | Drill grows past 400 lines | `python3 cli.py check-filesize` red | Budget ≤ 280 lines; extract shared helpers into a sibling `tests/integration/` module only if needed. |
| F13 | Stale `app_router.dart:55` citation resurrected in other docs | `grep -rn "app_router.dart:55" docs/` hits | Fixed once at §3.3; verified no other doc carries it today (proposals corpus grepped). |
| F14 | Harness wiring placed before the proxy is up | Drill connection-refused FAIL in `run_all.py`/`full_stack_verify.py` | Placement pinned after `e2e_runner.py` (`run_all.py:164-166`) / after Detail API (`full_stack_verify.py:107-109`); SKIP covers missing stack, not a live stack with a dead proxy — wiring order is the guard. |
| F15 | `SNAPLINK_DRILL_SETTLE_SECONDS` unset/negative | `max(10, …)` floor keeps the settle ≥ 10 s | Env knob parsed with a floor; documented in the drill header. |
| F16 | B6-1 joint rendering lands without the server-side row | T-12 joint test red in the B6-1 change set | This lens's guarantee is only: row exists server-side (REQ-2) + module cannot forge it (REQ-4); the rendering test lives in B6-1's change set, gated on this drill's evidence. |

---

## 6. Migration steps (each leaves the tree green; no data migration)

Ordering is branch-neutral until M3; the branch decision lands in the **sibling** change set as one atomic commit (value flip + mirrors must not straddle commits — the sibling grep guards would be red in CI). This lens contributes M4 (the drill) and the REQ-0 closure evidence.

1. **M1 — REQ-0 evidence (no code)**: operator runs the drill precondition (step 1) against the deployed IdP registry (`console` vs `sso-admin-console` vs neither); records the branch choice in the run's `DECISIONS.md`. Tree untouched.
2. **M2 — sibling mechanism lands (branch-neutral)**: `SSOAdminClient.firstPartyClientId` + wiring + constantized tests land in the sibling change sets; this lens verifies its REQ-5 diff guard stays green (module untouched).
3. **M3 — branch decision commit (sibling, atomic; REQ-0)**: value flip/mirrors + `test/client_id_contract_test.dart` (screens lens, both branches) + `[RESOLVED]` record closure (`audit-contract-batch-snaplink-console.md:12`, stale `:55` → `:35` fixed); Branch B verifies `implementation-gate.md:57` row 2 (no amendment needed — already records `sso-admin-console`). This lens: zero diff; module suites green.
4. **M4 — drill (branch-neutral; `AGREED_CLIENT_ID` mirrors M3's value)**: **adopt** the existing untracked `tests/integration/audit_login_drill.py` (§3.1 — extend with the DCR leg, do not recreate) and **commit** its already-present wiring (`run_all.py:169`, `full_stack_verify.py:113` — uncommitted diffs, §3.2). `git add` file + wiring diffs **first** (the artifact is `git clean`-fragile — untracked file, uncommitted wiring). May fold into M3 for a single review or stay separate; grep-verifiable either way.
5. **M5 — gates (REQ-3/REQ-4/REQ-5)**: `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart test/dcr_models_test.dart test/developer_serving_region_test.dart test/list_state_manager_test.dart test/sso_client_test.dart`; `python3 cli.py check-filesize`; the §7 grep guards; `git diff --stat lib/screens/developer/` empty; `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` empty.
6. **M6 — deploy + drill execution (REQ-1/REQ-2)**: deploy the aligned constant to the T-12/G7 environment, run `python3 tests/integration/audit_login_drill.py`; append PASS/FAIL output + sink query result to the `[RESOLVED]` record (§3.3).

**Rollback**: revert M4 (delete the drill + 2 harness wiring lines) — total and immediate. M1-M3/M5-M6 involve zero module code, so this lens has no other rollback surface; a wrong branch choice is reverted in the sibling change set (one-line constant flip + mirrors), after which the `[RESOLVED]` record is re-opened.

---

## 7. Testable acceptance mapping

| Supplied check (spec §4) | Testable form | Command / artifact |
|---|---|---|
| AC-1 — decision recorded (Branch A code change **or** Branch B already-recorded exception + regression pin); DCR evidence channel feeds the decision | REQ-0: `grep -n "\[RESOLVED\]" docs/proposals/audit-contract-batch-snaplink-console.md` names Branch A or B with drill evidence attached; `grep -n "app_router.dart:35" docs/proposals/audit-contract-batch-snaplink-console.md` hits (stale `:55` gone). Branch A: `flutter test test/sso_client_test.dart` green with `:18` asserting `SSOAdminClient.firstPartyClientId`; Branch B: `grep -n "client_id=sso-admin-console" docs/campaigns/implementation-gate.md` hits (already records the exception — verify-only `:57`) and the sibling `test/client_id_contract_test.dart` pins the `_effectiveClientId` chain end-to-end (C3) | grep commands; `flutter test test/sso_client_test.dart` (sibling suite) |
| AC-2 — DCR drill asserts the aligned `client_id` obtainable via POST `/register` (register_panel.dart path) and one login → exactly one `auth.login.success` row (`implementation-gate.md:57` "无重复") | REQ-1 + REQ-2: `python3 tests/integration/audit_login_drill.py` against the deployed stack — step 1 `CONFIG.client_id == AGREED_CLIENT_ID`; step 2 `POST {PROXY}/register` with `toRegistrationWire()`-mirrored body **without** `client_id` returns `client_id == AGREED_CLIENT_ID`; step 3 login with the DCR-obtained id returns `access_token` + JWT `tenant_id`; steps 4-5 `GET {CONFIG.api_url}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` → exactly one row with the agreed `client_id` claim; second login → 2 rows, no duplicate event id/trace_id, settle ≥ 10 s, count stable; sink legs `[proposed]`-marked when unverifiable (no false PASS, D7); exit 0 only on PASS/SKIP; `grep -n "audit_login_drill" tests/integration/run_all.py tests/integration/full_stack_verify.py` hits | `python3 tests/integration/audit_login_drill.py`; grep commands |
| AC-3 — server-side audit timeline (B6-1) renders the row without localStorage forgery | REQ-4: `grep -rn "AuditLogService\|sso_audit_log" lib/screens/developer/` → exit 1; `grep -n "audit/events" tests/integration/audit_login_drill.py` hits and `grep -n "sso_audit_log" tests/integration/audit_login_drill.py` → exit 1 (server route only); the T-12 joint rendering test is B6-1's change set, gated on the row existing server-side (dependency recorded in §8) | grep guards |
| AC-4 — existing `test/developer_api_test.dart` and `test/sso_client_test.dart` suites stay green | REQ-5 + REQ-3: `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart test/dcr_models_test.dart test/developer_serving_region_test.dart test/list_state_manager_test.dart test/sso_client_test.dart` green; `git diff --stat lib/screens/developer/` empty; `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` empty (mock ids `'client-1'`/`'client-123'` untouched under both branches — D4) | `flutter test …`; `git diff` guards |
| REQ-1 (both) — drill register body is server-assigned | the drill's register-body construction contains no `client_id` key (code review + `grep -n "client_id" tests/integration/audit_login_drill.py` shows the key only in *response* assertions); response-id equality asserted | grep + drill run |
| REQ-3 (both) — pivot regression pin | `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart` green **and** `git diff` on both files empty | `flutter test …`; `git diff` |
| REQ-5 (both) — zero-delta floor | `git diff --stat lib/screens/developer/` empty; no `lib/i18n` delta; no new endpoints; `grep -rn "auth.login.success" lib/ test/ tests/` → 0 hits (no emission code added) | `git diff`; grep |

Gate relationship preserved from the spec: AC-1 gates AC-2 (the drill asserts the branch's agreed value); AC-3 is a joint acceptance with B6-1 (this lens proves the server-side row + module non-forgery; B6-1 proves the rendering); AC-4 is the unconditional no-regression floor. All four are executable as written.

---

## 8. Out of scope (unchanged)

Sink/IdP client registry state (external; REQ-0 evidence channel only); the login-wire value change and its pins (`sso_client.dart:86`, `app_router.dart:35`, `sso_client_test.dart:18`, `test_config.py:44`, `DEPLOY.md:29`, `test/client_id_contract_test.dart` — sibling `lib/api`/`lib/screens` change sets); `auth.login.success` emission (no such code exists — 0 grep hits); B6-1/B6-1a server-read timeline rendering (dependency, its own change set); B4-1 (tenant claim parsing — drill dependency only, declared not implemented); B4-5 (drill gate row owner); BFF trace injection; any `lib/screens/developer/**` production or test file (zero diff, REQ-5); `lib/i18n` catalog (zero delta).
