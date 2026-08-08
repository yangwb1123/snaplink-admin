# B6-2 Design — `developer` lens: land the missing DCR leg of `tests/integration/audit_login_drill.py` (【1b】 + register→login→sink keying, Branch B)

Module: `lib/screens/developer` (analysis bucket `docs/auto/analyses/lib-screens-developer-3899da21.json`) · Direction: B6-2 developer lens (DCR surface) · Value: 9 · Risk reduction: 7 · Effort: 2 · Confidence: 9
Status: **design** — implements the requirements spec `docs/proposals/b6-2-lib-screens-developer-client-id-alignment-spec.md` (REQ-0/REQ-1/REQ-2/REQ-3). Branch B locked by the `[RESOLVED]` record (`audit-contract-batch-snaplink-console.md:13`); not decision-gated. Sibling instances: `b6-2-lib-screens-oidc-login-client-id-alignment-{spec,design}.md`, `b6-2-lib-screens-device-client-id-alignment-{spec,design}.md`, `b6-2-lib-screens-client-id-alignment-{spec,design}.md`, `b6-2-lib-api-client-id-alignment-{spec,design}.md` — where lenses overlap (drill artifact, `AGREED_CLIENT_ID`, the `[RESOLVED]` record, `implementation-gate.md:57` row) they name the same artifacts so the change set stays single.

---

## 1. Verification verdict (evidence re-checked at HEAD, not trusted)

The requirements evidence (spec summary + spec file, 136 lines) was re-checked at HEAD `de9b446` against the working tree. Every substantive claim holds; three minor citation drifts are carried as corrections (no acceptance impact — all ACs are grep/symbol-pinned, not line-pinned).

| Evidence claim | Verification result at HEAD |
|---|---|
| Spec file at `docs/proposals/b6-2-lib-screens-developer-client-id-alignment-spec.md`, 136 lines, REQ-0…REQ-3, §4 seven ACs | ✅ `wc -l` → 136; all four requirements + 7-AC table + §5 deps + §6 risks present; §3 REQ-3.4 budget-deviation paragraph present |
| Drill: 439 lines, `0` `register` hits, docstring "device redirect-leg facts" | ✅ exact: `wc -l` → 439 (working tree, incl. uncommitted setup leg); `grep -c register` → 0; docstring `:2` |
| Drill steps 【1】-【7】 | ✅ with a form note: steps 【1】【2】【3】【3b】【4】【5】【6】 are bracketed prints (`:129,138,150,186,318,340,370`); step 7 is the comment-form report block (`# Step 7 — report.` `:430`) with `sys.exit(1 if FAIL else 0)` at `:439` |
| Drill tracked, commit `3b64c58`; working tree carries uncommitted setup-leg edits | ✅ exact: `git log` → `3b64c58` "verify(b6-1/b6-2): ring-isolation guards + client_id alignment drills"; `git diff --stat` → +147 lines (【3b】 setup leg) uncommitted |
| Wiring: `run_all.py:196`, `full_stack_verify.py:113`, timeout 300, skip_markers `SKIP/[proposed]` | ✅ substance exact; **Δ (off-by-one)**: `run_all.py` call is at **`:195`** (comment `:193-194`); `full_stack_verify.py:113` exact. Both carry `timeout=300, skip_markers=('SKIP:', 'SKIP', '[proposed]')` |
| `[RESOLVED]` at `audit-contract-batch-snaplink-console.md:13-14` — device + setup legs only, no DCR channel; `[MISMATCH]` already closed | ✅ exact: `:13` Branch B device leg, `:14` setup leg, `:15` `[PROPOSED]`; zero `register` tokens in the B6-2 block |
| `developer_api.dart:104` `_baseUri.resolve('/register')`; `registerMetadata` `:66`, `register` `:84`, `_registerBody` `:94-113` | ✅ exact (`:104` inside `_registerBody`; open registration when `initialAccessToken` null — no bearer sent) |
| `dcr_models.dart:50-69` — `typedKeys` no `client_id`, `protectedResponseKeys` yes | ✅ exact: `typedKeys` `:50-64` (13 keys), `protectedResponseKeys` `:66-71` with `'client_id'` at `:67` |
| `sso_client.dart:82` `firstPartyClientId='sso-admin-console'`; `:92` login wire | ✅ exact: `lib/api/sso_client.dart:82`; `login` default `clientId = firstPartyClientId` at `:92`, body `client_id` at `:94` |
| `test/developer_api_test.dart:29,46`; `test/dcr_widgets_test.dart:24-30`; `test_config.py:43-44` | ✅ exact: mock 201 `'client-1'` `:29`, expect `:46`, request-body assertion `:22-28` (no `client_id` key); `dcr_widgets_test.dart:24-30` onManage pivot; `test_config.py:43-44` `SNAPLINK_TEST_CLIENT_ID` default `'sso-admin-console'` |
| `snaplink_admin_api.dart:81` `_recordAudit` (sole ring writer) | ✅ exact; zero `AuditLogService`/`sso_audit_log` hits under `lib/screens/developer/` |
| `implementation-gate.md:57` row 2 — `client_id=sso-admin-console`, verify-only | ✅ exact |
| `checks/filesize.py:4` Dart-scoped cap; `engineering.yaml:11` 400 | ✅ exact: "Adapted from snaplink's checks/filesize.py **for .dart files**"; `max_lines: 400` — does not gate the `.py` drill |
| Register→manage pivot: `register_panel.dart:87/:107/:112` → `developer_screen.dart:81` → `manage_panel.dart:46` | ✅ exact (`:87` snapshot merge, `:107` `result['client_id']`, `:112` `widget.onManage(clientId, rat, safeSnapshot)`; `_openManageWithApp` `:81`; `loadWithRegistration` `:46`) |
| Credentials gate at drill `:113-118` (`SKIP` + `sys.exit(0)`) | ✅ exact; `PROXY`/`API` bound at `:122-123`; `AGREED_CLIENT_ID = 'sso-admin-console'` at `:31` |

**Corrections carried into this design (no acceptance impact):**

1. **`run_all.py:196` → `:195`** (call site; comment `:193-194`). All AC-7 greps match the symbol `audit_login_drill`, never the line.
2. **`toRegistrationWire()` is at `dcr_models.dart:151-165`**, not `:128-139` (that range is the `fromWire` factory — `_wireStringList` decoding). The mandatory keys (client_name, redirect_uris, scope, token_endpoint_auth_method, token_strategy) + optional grant_types/require_pkce are unaffected; the spec's `:128-139` citation is stale.
3. **Step 7 is comment-form** (`# Step 7 — report.` at `:430`), not a bracketed `【7】` print; the exit path `sys.exit(1 if FAIL else 0)` is at `:439`. The "steps 【1】-【7】" claim holds at the block level (7 step blocks, 6 bracketed).

**Executed, not just read** (drill runtime faces): `python3 tests/integration/audit_login_drill.py` with no `SNAPLINK_TEST_USERNAME/PASSWORD` → exit 0, `SKIP: live authenticated tests require …` (credentials gate `:113-118`). The DCR leg must sit **after** this gate so no-stack runs keep SKIP semantics.

**Pin stability at the post-migration commit (measured, not assumed):** §3.4 was applied to a temp copy and validated — **491 lines** (439 + 52: docstring +7, `【1b】` block +41, step-3 mutation +4), `py_compile` clean, no-credentials run → exit 0 `SKIP:` with **zero network contact** (gate precedes `PROXY`/`API` binding), credentials-without-network run → exit 1 with the DCR leg FAILing loudly (`DCR response is parseable JSON` / `DCR register 2xx JSON` checks) — never `[proposed]`, never a skip. All §7 grep forms pass identically at the post-migration state (AC-1: 12 `register` hits, `【1b】` `:145` < `【3】` `:198`; AC-2 `:177/:180`; AC-3 `:200 < :203 < :207`; AC-4 `:376-387/:407/:409-414`; AC-7 `:196/:113` unchanged). **Line numbers in this document are pre-migration reference values unless marked post-migration; acceptance pins are symbols and textual order, never line numbers** (§7 rule).

---

## 2. Design summary

**Files touched: 2 — one drill edit + one record edit. Zero production delta, zero new files, zero test-file edits, zero wiring edits.**

| # | File | Change | Requirement |
|---|---|---|---|
| 1 | `tests/integration/audit_login_drill.py` | docstring names the DCR leg (+7: 6-line paragraph + blank separator, literal in §3.3); new `【1b】` step block + `register_client()` helper between step 1 and step 2 (+41 lines); step-3 login payload keyed to the DCR-obtained id (+4 lines). Net **+52 → 491 lines (measured** on an applied temp copy; 344 tracked at the landing commit vs 292 at `3b64c58`) | REQ-1, REQ-2 |
| 2 | `docs/proposals/audit-contract-batch-snaplink-console.md` | third `[RESOLVED]` B6-2 bullet (after `:14`, before the block-level `[PROPOSED]` at `:15`) naming Branch B, attaching the drill output, recording the deviation | REQ-0 |

**Zero-edit (derived):** `lib/**` (incl. `lib/screens/developer/**`) — no diff; `test/developer_api_test.dart` + `test/dcr_widgets_test.dart` — green unchanged; `tests/integration/test_config.py` — `login_payload()` untouched (no override param added); `run_all.py` / `full_stack_verify.py` — wiring intact; `implementation-gate.md:57` — verify-only.

**Key decisions:**

- **D1 — Drill-only delta.** The DCR leg is an additive step block following the `【3b】` precedent: local `dcr_*` names only, never writes step 3's `login_data`/`token`/`tenant_id`, no renumbering of existing steps. Insertion anchor (pre-edit, current working tree): after step 1's `check("CONFIG.client_id == AGREED_CLIENT_ID", …)` block (ends `:132`) and the blank line `:133`, before `# Step 2 —` `:134`. Apply in order docstring → block → mutation (M2); post-edit the anchor sits at `:139`/`:140`/`:141` — the acceptance greps never depend on it.
- **D2 — Provenance, not value.** The DCR response id equals `AGREED_CLIENT_ID` by the REQ-1.4 assertion; step 3 then re-sources `login_data['client_id']` from the DCR response via a **local mutation** (no `test_config.py` change — `login_payload()` has no override param and gains none). Wire bytes are identical; the change is the *source* of the value, mirroring the module pivot `register_panel.dart:107 → 112 → developer_screen.dart:81 → manage_panel.dart:46`.
- **D3 — Sink steps 4-5 need zero textual change.** Step 4 already filters `r.get('client_id') == AGREED_CLIENT_ID`; step 5's exactly-two/no-repeated-id/re-settle-stable checks (`len(rows_after) == 2` / `len(event_ids) == len(set(event_ids))` / count-stable, post-migration `:407`/`:409-410`/`:412-414`) operate on the same rows. The equality chain *DCR response id → login payload → sink rows* is closed by REQ-1's assertion alone; the design documents the chain, it does not duplicate it.
- **D4 — DCR failure is loud, evidence-producing, never `[proposed]`.** A failed register (non-JSON, error body, mismatched id) FAILs via `check()` with the raw response printed, accumulates into `FAIL`, and the drill exits 1 through the existing report path (single `sys.exit(1 if FAIL else 0)`, pre-migration `:439` / post-migration `:491`). `dcr_client_id` stays `None`; step 3 falls back to `CONFIG.client_id` (still == AGREED) so downstream sink legs still produce evidence for the REQ-0 record. No path yields a silent pass.
- **D5 — Fresh registration per run: deterministic, bounded, never rate-limit-flaky.** `register_client()` POSTs without a bearer (matches `developer_api.register()` with `initialAccessToken: null` — the module's open-registration path) and makes **exactly one POST `/register` per run — no retry loop, no re-registration** (steps 3-6 consume `dcr_client_id`; nothing re-calls the helper). `client_name` carries a per-run Unix timestamp so consecutive runs cannot collide; body keys are exactly the five mandatory `toRegistrationWire()` keys + `grant_types`/`require_pkce` — the same key set the request-body assertion pins at `test/developer_api_test.dart:22-28`. **IdP load is bounded: 1 registration per stacked run; zero under `run_all.py --ci`/`--skip-e2e`** (Gate 5 returns before the proxy starts, `run_all.py:163-166`); zero on no-credentials runs (gate exits before any network). Every DCR failure path (non-JSON, error body, rate-limit/429, mismatched id) FAILs loudly with the response printed and exits 1 — the run outcome is a **deterministic function of stack state** (no credentials → SKIP; reachable IdP → PASS/FAIL per REQ-1.4; unreachable → FAIL), never a timing race, never a SKIP on a runnable leg. Run-to-run outcome differences (e.g., a first registration issued the agreed id, a later one a unique id) are deterministic contract findings the REQ-0 record attaches — the IdP's issuance policy is exactly what REQ-1.4 probes (F2).
- **D6 — Budget deviation pre-recorded and measured.** Drill is 439 lines in the working tree at HEAD (292 tracked at `3b64c58`) vs. the 280-line sibling budget (`b6-2-lib-screens-client-id-alignment-design.md:199` — reference `api_login_e2e.py` = 166; the 400-line `engineering.yaml:11` cap is Dart-scoped per `checks/filesize.py:4` and does not gate the `.py` drill). The §3.4 block lands **+52 → 491 working-tree / 344 committed** (measured on an applied temp copy, `py_compile` clean) — both figures exceed 280. The spec's earlier estimate (≈55-65 → ≈495-500, REQ-3.4) is **superseded by the measured figure** and both docs record the same deviation. Mitigation: reuse `check`/`curl`/`settle_seconds`/`sink_rows`, one new `register_client()` helper, zero new imports.
- **D7 — Commit construction from a contaminated tree.** The working tree mixes the committed `3b64c58` drill, the uncommitted setup leg (+147), and unrelated B6-1 edits. The landing commit stages **exactly** the DCR-leg drill hunks + the record bullet; `git diff` boundaries are checked before commit (§6).

---

## 3. API changes (concrete)

### 3.1 Wire-level contract exercised (the only "API" this change touches)

**`POST {PROXY}/register`** — RFC 7591 Dynamic Client Registration, as the module emits it (`developer_api.dart:94-113`):

Request:
```json
{
  "client_name": "drill-dcr-<unix-ts>",
  "redirect_uris": ["https://app.example.test/callback"],
  "scope": "openid profile",
  "token_endpoint_auth_method": "client_secret_basic",
  "token_strategy": "jwt",
  "grant_types": ["authorization_code", "refresh_token"],
  "require_pkce": true
}
```
- `Content-Type: application/json`; **no `Authorization` header** (open registration, mirroring `register()` with `initialAccessToken: null`).
- **`client_id` is never in the body** (RFC 7591 server-assigned; `dcr_models.dart:67` `protectedResponseKeys`). Enforced by a runtime guard: `check("DCR body has no client_id (RFC 7591 server-assigned)", 'client_id' not in body)`.

Response (2xx): parsed JSON; **`response['client_id']` must equal `AGREED_CLIENT_ID`**. The parsed id is bound to `dcr_client_id` and consumed by step 3's login payload.

**`POST {PROXY}/auth/login`** (step 3, unchanged wire — `sso_client.dart:92-94`): payload from `CONFIG.login_payload()` with `login_data['client_id'] = dcr_client_id` (guarded: only when the DCR assertion passed). Value unchanged (`sso-admin-console`); provenance now the DCR response.

### 3.2 In-repo API surface: zero changes

| Symbol | Status |
|---|---|
| `DeveloperApi.register/registerMetadata/_registerBody` (`developer_api.dart:66,84,94-113`) | untouched |
| `DcrClientMetadata.toRegistrationWire/typedKeys/protectedResponseKeys` (`dcr_models.dart:50-71,151-165`) | untouched |
| `SSOAdminClient.firstPartyClientId` (`lib/api/sso_client.dart:82`) + `login` (`:92-94`) | untouched |
| `test_config.py:login_payload()` (`:86`) | untouched — **no `client_id` override parameter added**; the drill mutates the returned dict locally (D2) |
| `run_all.py` / `full_stack_verify.py` wiring | untouched — skip_markers `('SKIP:', 'SKIP', '[proposed]')` preserved verbatim |

### 3.3 Drill-internal API (the only new symbols)

```python
def register_client():
    """POST {PROXY}/register with the register_panel wire shape
    (developer_api.dart:104 → toRegistrationWire() keys); return
    (parsed_response_or_None, raw_body)."""
```
- New module-level binding `dcr_client_id` (parsed response id, or `None` on DCR failure) — consumed by step 3 only.
- One new step block `【1b. DCR: POST /register issues the agreed client_id (REQ-1)】` between `【1】` and `【2】`.
- Docstring (`:2-21` pre-migration) gains one DCR-leg paragraph (**+7 lines incl. blank separator**; literal pinned below) so the file's stated lens matches its content (REQ-1.6). The paragraph lands after the `【3b】` paragraph, before `Branch value (REQ-0):`:

```
Step 【1b】 adds the DCR leg (REQ-1): POST {PROXY}/register with
the register_panel wire shape (developer_api.dart:104 →
DcrClientMetadata.toRegistrationWire(), dcr_models.dart:151-165); the
RFC 7591 server-assigned response client_id must equal AGREED_CLIENT_ID
(REQ-1.4) — a failed/mismatched register exits 1 with the response
printed, never a skip, never [proposed].
```

### 3.4 Concrete `【1b】` block (lands as-is)

```python
# Step 1b — REQ-1 DCR leg: POST /register with the module's wire shape
# (developer_api.dart:104 → DcrClientMetadata.toRegistrationWire(),
# dcr_models.dart:151-165). RFC 7591: client_id is server-assigned —
# never sent in the body; the response id must equal AGREED_CLIENT_ID.
print("\n【1b. DCR: POST /register issues the agreed client_id (REQ-1)】")


def register_client():
    """POST {PROXY}/register with the register_panel wire shape; return
    (parsed response dict or None, raw body)."""
    body = {
        'client_name': f'drill-dcr-{int(time.time())}',
        'redirect_uris': ['https://app.example.test/callback'],
        'scope': 'openid profile',
        'token_endpoint_auth_method': 'client_secret_basic',
        'token_strategy': 'jwt',
        'grant_types': ['authorization_code', 'refresh_token'],
        'require_pkce': True,
    }
    check("DCR body has no client_id (RFC 7591 server-assigned)",
          'client_id' not in body)
    raw = curl('POST', f'{PROXY}/register', data=body,
               headers={'Content-Type': 'application/json'})
    try:
        return json.loads(raw), raw
    except Exception:
        check("DCR response is parseable JSON", False, raw[:200])
        return None, raw


dcr_resp, dcr_raw = register_client()
if dcr_resp is None:
    check("DCR register 2xx JSON", False, f"POST {PROXY}/register")
    dcr_client_id = None
else:
    dcr_client_id = dcr_resp.get('client_id')
    check("DCR response client_id == AGREED_CLIENT_ID",
          dcr_client_id == AGREED_CLIENT_ID,
          f"issued {dcr_client_id!r}, agreed {AGREED_CLIENT_ID!r}")
    print(f"    register response: {dcr_raw[:300]}")
```

Step-3 delta (after the existing `check("login payload carries the agreed client_id", …)` block, before the `auth_resp = curl('POST', f'{PROXY}/auth/login', …)` call — textual order: payload check `:200-202` < mutation `:203-206` < POST `:207` post-migration):

```python
if dcr_client_id is not None:
    login_data['client_id'] = dcr_client_id
    check("login client_id sourced from DCR response (register→manage pivot)",
          login_data['client_id'] == AGREED_CLIENT_ID)
```

Note on the "2xx" inference (D5): `curl()` (`:39-52`) does not capture HTTP status; a non-2xx JSON error body (`{"error": …}`) parses but lacks `client_id` → equality FAIL with the body printed; an HTML/empty body fails JSON parsing → FAIL with a prefix printed; a 2xx with a mismatched id → FAIL. Every failure path prints the response (REQ-1.4) and exits 1 via the single existing exit (pre-migration `:439` / post-migration `:491`). No silent pass exists.

---

## 4. Compatibility constraints

1. **RFC 7591** — `client_id` is server-assigned; the registration body never carries it (`protectedResponseKeys`, `dcr_models.dart:67`); the drill asserts the *response* id, never sends one.
2. **Additive drill convention** — the `【3b】` precedent: `【1b】` slots between `【1】` and `【2】`; existing steps are not renumbered or rewritten; local `dcr_*` names only; step 3's `login_data`/`token`/`tenant_id` are never written by the new block.
3. **Zero production delta** — `lib/**` untouched; `test/developer_api_test.dart` + `test/dcr_widgets_test.dart` green unchanged (module fixtures stay server-shaped mock ids `'client-1'` — registration cannot choose `client_id`, so the aligned constant never belongs in module fixtures).
4. **Branch B locked** — `AGREED_CLIENT_ID = 'sso-admin-console'` (drill pre-migration `:31`; `sso_client.dart:82`) is not re-litigated; `implementation-gate.md:57` row 2 stays verify-only.
5. **No-credentials gate position** — the `CONFIG.require_credentials()` gate stays at file top (pre-migration `:113-118`; post-migration `:120-125`), *before* `【1b】` and before `PROXY`/`API` are even bound (`:127-128` post-migration) — **zero network contact precedes the gate**; a no-stack run exits 0 with `SKIP: …`, never FAIL (validated: exit 0, no curls issued). The DCR leg is only reachable on a configured stack.
6. **Wiring/skip semantics** — both harness runners demote an exit-0 run whose output contains `SKIP:`/`SKIP`/`[proposed]` to **SKIP, never PASS** (`run_all.py:35-37` — stdout+stderr scan; `full_stack_verify.py:32-34` — stdout scan); exit ≠ 0 and harness timeout are always **FAIL** (`run_all.py:43-49`, `full_stack_verify.py:37-45`) — **no path demotes a FAIL to SKIP**. The drill prints `SKIP: …` only on the no-credentials gate (exit 0) and `[proposed]` only on unverifiable sink/read legs; the DCR leg is never `[proposed]`. Without network but with credentials the drill exits 1 deterministically (all curls bounded: `--max-time 15` + subprocess timeout 20; worst case ≈ 12 curls ≈ 200 s < the 300 s harness timeout — no harness-timeout flake either).
7. **Dependencies** — B4-5 (IdP-side sink emission): sink legs stay `[proposed]`-capable until landed; B4-1 (tenant claim): the drill's existing `decode_jwt` is reused; a missing `tenant_id` claim FAILs loudly, no new parsing code.
8. **Budget** — the 400-line `engineering.yaml:11` cap is Dart-scoped (`checks/filesize.py:4`) and does not gate the `.py` drill; the 280-line sibling budget (`b6-2-lib-screens-client-id-alignment-design.md:199`) is already exceeded at HEAD (439 working-tree / 292 tracked) and remains exceeded after landing (**491 working-tree / 344 committed**, measured) — deviation pre-recorded in spec §3 REQ-3.4 and carried in the REQ-0 record bullet.
9. **IdP registration load is bounded and skip-safe** — exactly one POST `/register` per stacked drill run (D5); `--ci`/`--skip-e2e` never execute Gate 5 (`run_all.py:163-166`), so CI issues zero registrations; a rate-limited/429 response parses as a JSON error body without `client_id` → equality FAIL with the body printed (F11) — never a retry, never a silent pass.

---

## 5. Failure modes

| # | Failure | Detection / drill behavior | Recovery / rollback |
|---|---|---|---|
| F1 | Deployed IdP has no `/register`, or registration requires an initial access token (open registration refused) | Non-2xx error body → no `client_id` → FAIL with response printed; exit 1. Never `[proposed]` | Contract evidence for REQ-0; no code change (rollback = current state). IdP-side config, not console |
| F2 | IdP issues `client_id != sso-admin-console` (e.g., per-tenant prefix, random suffix) | `check("DCR response client_id == AGREED_CLIENT_ID")` FAIL with `issued …` detail; exit 1; response printed | The REQ-0 evidence channel — Branch B is re-examined, never papered over; single-line `AGREED_CLIENT_ID` change if the contract demands it |
| F3 | DCR-obtained id rejected on `POST /auth/login` | Step-3 login check FAIL (no access_token / parse error); exit 1 | Evidence of IdP login/registration surface mismatch; record in REQ-0 bullet |
| F4 | Sink emission absent (B4-5 not landed) | Sink legs `[proposed]` with query + result logged (existing convention — step-4 unverifiable print, post-migration `:376-380`); DCR register+login legs still asserted; deviation named in the REQ-0 bullet; `run_all.py` maps exit-0 `[proposed]` → SKIP — no false PASS | B4-5 landing makes the legs runnable; no console change |
| F5 | Zero sink matches on a runnable leg | `len(matching) == 1` FAIL → exit 1 (never skip, never `[proposed]` for a runnable query) — existing rule | Investigate id attribution; record evidence |
| F6 | Re-registration conflicts / rate-limit (duplicate `client_name`, 429) | Per-run timestamped `client_name` prevents collisions; a 429/error body parses without `client_id` → equality FAIL with response printed — never a retry, never a skip | Adjust `client_name`/URI set in the drill body only; registration load is 1/run by design (D5), zero under `--ci` |
| F7 | Drill growth past budget | 491 lines (working tree; 344 committed) vs. 280-line sibling budget — pre-recorded deviation (spec §3 REQ-3.4, REQ-0 bullet), **measured** (temp-copy application) not estimated, with helper-reuse mitigation; if the landed leg keeps the drill ≤ 280, the entry is marked moot | No action; budget entry documents the trade |
| F8 | Credentials gate regressed (DCR leg placed before the `CONFIG.require_credentials()` gate, `:120-125` post-migration) | No-stack run would FAIL instead of SKIP | AC-1 greps pin `【1b】` between `【1】` and `【2】` (after the gate); no-stack run in migration step M4 |
| F11 | IdP rate-limits open registration (429 / throttle) | Error body parses without `client_id` → equality FAIL with the response printed; exit 1 — never a retry, never a skip, never `[proposed]` | Evidence for REQ-0; registration load is 1/run by design, zero under `--ci` (Gate 5 skip, `run_all.py:163-166`); space out stacked runs if the IdP enforces a window |
| F9 | Wiring skip_markers lost | AC-7 grep pair (`run_all.py` / `full_stack_verify.py`) + Gate 5 review | Restore markers; a lost marker turns `[proposed]` legs into false PASSes — highest-impact regression, hence pinned |
| F10 | JWT `tenant_id` claim missing | Existing step-3 FAIL ("B4-1 dependency…") — loud, exit 1 | B4-1 landing; no new claim-parsing code in the drill |

---

## 6. Migration steps

All steps execute against the working tree (contaminated: committed `3b64c58` drill + uncommitted setup leg + unrelated B6-1 edits). The DCR hunks are staged alone.

- **M1 — Baseline.** `git diff --stat -- lib/` → empty; `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart` → green; `python3 tests/integration/audit_login_drill.py` (no credentials) → exit 0 `SKIP: …`.
- **M2 — Drill edit.** Apply in order: the §3.3 docstring paragraph (+7 incl. blank separator), the §3.4 `【1b】` block + `register_client()` + `dcr_client_id` binding (+41), the step-3 mutation (+4) — total **+52 → 491 lines**. Syntax check `python3 -m py_compile tests/integration/audit_login_drill.py`.
- **M3 — Static ACs (executable now, no stack).** Run the grep forms of AC-1/AC-2/AC-3/AC-4/AC-7 (§7) and the `git diff` forms of AC-6. Confirm `grep -c register` on the drill is **12** (≥ 4 required; measured on the applied block) and `【1b】` appears textually before `【3. Login…】`.
- **M4 — Runtime faces.** No-stack run → exit 0 SKIP (gate intact, F8). Stacked run (when a stack is available) → DCR leg PASS/FAIL per §5 F1-F5; record the output — it is the REQ-0 attachment.
- **M5 — REQ-0 record.** Append the third `[RESOLVED]` bullet to `docs/proposals/audit-contract-batch-snaplink-console.md` after `:14` (draft below); it names Branch B, attaches the drill output (or the deviation if not yet run on a stack), and records the budget deviation. `implementation-gate.md:57` row 2 is *not* amended (verify-only).
- **M6 — Commit.** Stage exactly the DCR-leg drill hunks + the record bullet (`git add -p`); verify `git diff --cached` shows only those two files' DCR/record hunks (setup-leg +147 and B6-1 edits stay unstaged/untracked per D7). Single commit, sibling-consistent message: `verify(b6-2): DCR leg 【1b】 lands the /register evidence channel (REQ-0/1/2)`.
- **M7 — Post-commit.** Re-run AC-6 diff forms (empty `lib/` diff, two test files green, unchanged) and AC-7 greps; `git status --porcelain lib/screens/developer/` empty. Re-run the **full AC-1…AC-7 grep battery against the landing commit's tree** (fresh `git worktree`/`git stash` checkout or `git show <commit>:tests/integration/audit_login_drill.py` piped to the greps) — all pins are symbols/textual order (M7 results identical to M3); line numbers shift by construction (+7/+41/+4) and are never acceptance pins.

REQ-0 record bullet draft (appended after `:14`):

```
- `[RESOLVED]`（B6-2, 2026-08-08）：**DCR 腿落地**（`b6-2-lib-screens-developer-client-id-alignment-spec.md` REQ-1/REQ-2，status → implemented）——drill 新增 `【1b】` 块（step 1 与 step 2 之间，additive）：`POST {PROXY}/register`（module wire：`developer_api.dart:104` → `toRegistrationWire()` 键 `dcr_models.dart:151-165`；body 无 client_id，RFC 7591 server-assigned）→ 响应 `client_id == AGREED_CLIENT_ID`（Branch B，`sso-admin-console`）否则 exit 1 且响应打印；step 3 登录 payload 的 client_id 取自 DCR 响应（register→manage pivot 镜像：`register_panel.dart:107→112`→`developer_screen.dart:81`→`manage_panel.dart:46`）；sink 断言（恰一行 / 二次登录恰两行无重复 / re-settle 稳定 / 零匹配 exit 1）以该 id 为准。drill 输出（DCR register 响应 + sink 查询）附后。**deviation**：sink 发射 IdP 侧（B4-5）——未落地时 sink 腿 `[proposed]`（无 false PASS）；drill 439→**491** 行（工作树；commit 292→344；实测值）超 280 行预算（deviation 已记录于 spec §3 REQ-3.4，helper 复用缓解：复用 check/curl/settle_seconds/sink_rows + 单一 register_client() 助手，零新依赖；每次 stacked 运行仅 1 次 POST /register，`--ci` 零注册）。
```

---

## 7. Testable acceptance mapping

Each supplied AC from spec §4 maps to an executable form. Grep forms run at HEAD-with-edits (M3) and again at the landing commit (M7); runtime forms need a deployed stack (M4).

**Pin-stability rule (post-migration commit):** every executable form below is a **symbol/text pin** — grep literals, textual-ordering relations (`【1b】` before `【3】`; payload check before mutation before POST), or `git diff` forms. Parenthetical line numbers are **post-migration measured values** (validated by applying §3.4 to a temp copy: gate `:120-125`, `【1b】` `:145`, `【3】` `:198`, exit `:491`); they are reference values, **never acceptance pins** — the migration shifts every drill line by construction (+7 docstring, +41 block, +4 mutation), and M3 and M7 produce identical grep results. AC-7's `:196`/`:113` are additionally stable because the wiring files are untouched by this change set.

| # | Acceptance (spec §4, preserved 1:1) | Executable form | Expected | Requirement |
|---|---|---|---|---|
| AC-1 | DCR leg before the login leg; POSTs `{PROXY}/register` with `toRegistrationWire()` keys, no `client_id` in the body | `grep -n 'register' tests/integration/audit_login_drill.py` → ≥ 4 hits; the `【1b. DCR: …】` block line number < the `【3. Login …】` block line number (textual order); `grep -n "check(\"DCR body has no client_id"` hits; the body literal carries the five mandatory keys (`client_name`, `redirect_uris`, `scope`, `token_endpoint_auth_method`, `token_strategy`) + `grant_types`/`require_pkce` | all greps hit; ordering holds | REQ-1 |
| AC-2 | 2xx response `client_id == AGREED_CLIENT_ID`; mismatch → exit 1 with response printed | `grep -n 'DCR response client_id == AGREED_CLIENT_ID' tests/integration/audit_login_drill.py` hits; `grep -n 'register response:'` hits (response printed); `grep -n 'sys.exit(1 if FAIL else 0)'` — the **single existing** exit path (post-migration `:491`), no new exit; stacked run: mismatched id → exit 1 | greps hit; stacked behavior per §5 F2 | REQ-1.4 |
| AC-3 | Step-1 precondition stays; login uses the DCR-obtained id on the `sso_client.dart:92` wire | `grep -n 'CONFIG.client_id == AGREED_CLIENT_ID'` hits in the `【1】` block (unchanged); `grep -n "login_data\['client_id'\] = dcr_client_id"` hits in the `【3】` block; `grep -n 'CONFIG.login_payload()'` hits in the `【3】` block | all hit; textual order holds: payload check line < mutation line < login POST line (post-migration `:200-202` < `:203-206` < `:207`) | REQ-2.1-2 |
| AC-4 | Sink via `GET {API}/api/v1/audit/events` only: exactly-one / two-after-relogin / no repeated event id / re-settle stable / zero matches → exit 1 / `[proposed]` fallback without false PASS | `grep -n 'audit/events'` hits (server route only — no ring key); existing check literals unchanged — `len(matching) == 1` (post-migration `:383-387`), `len(rows_after) == 2` (`:407`), `len(event_ids) == len(set(event_ids))` (`:409-410`), count-stable (`:412-414`); zero matches → FAIL → exit 1; unverifiable → `[proposed]` print (post-migration `:376-380`) + deviation logged | greps hit; zero textual change to steps 4-5 (D3) | REQ-2.3 |
| AC-5 | `[RESOLVED]` record gains the DCR evidence channel (branch named, drill output attached) | `grep -n '\[RESOLVED\]' docs/proposals/audit-contract-batch-snaplink-console.md` → three B6-2 bullets; the third contains `DCR`, `Branch B`/`AGREED_CLIENT_ID`, and the drill output (PASS/FAIL + `/register` response); `grep -n 'register' docs/proposals/audit-contract-batch-snaplink-console.md` hits in that bullet | 3 bullets; DCR terms present; `register` hits | REQ-0 |
| AC-6 | Zero changes under `lib/screens/developer/` and `lib/`; the two test files green unchanged; budget deviation recorded | `git diff --stat -- lib/` → empty; `git status --porcelain lib/screens/developer/` → empty; `git diff test/developer_api_test.dart test/dcr_widgets_test.dart` → empty; `flutter test test/developer_api_test.dart test/dcr_widgets_test.dart` → green; `grep -n 'REQ-3.4' docs/proposals/b6-2-lib-screens-developer-client-id-alignment-spec.md` hits (deviation paragraph exists) | all hold | REQ-3 |
| AC-7 | Drill wiring preserved | `grep -n 'audit_login_drill' tests/integration/run_all.py tests/integration/full_stack_verify.py` hits (call sites `:195`/`:113` — reference values; wiring files are untouched by this change set, so they are also post-commit stable); `grep -n 'skip_markers'` shows `('SKIP:', 'SKIP', '[proposed]')` at both sites | both hit, markers intact | REQ-3.3 |

**Gate relationship** (unchanged from spec §4): AC-2 gates AC-3 (the mutation consumes the id only after the DCR assertion passed — enforced by the `if dcr_client_id is not None` guard); AC-5 depends on AC-2/AC-4 outcomes (the record attaches the drill output); AC-6/AC-7 are the unconditional no-regression floor.

---

## 8. Rollback

- **Revert:** `git revert` the landing commit (drill hunks + record bullet) — restores the 439-line drill with the setup leg and the two-leg `[RESOLVED]` block; zero production code is ever touched, so no runtime rollback exists.
- **Stack-facing failures** (F1-F5) require no code rollback: they are contract evidence captured in the REQ-0 bullet; the drill's exit 1 is the loud, non-silent outcome by design.
- **Wiring regressions** (F9) are prevented by AC-7's grep pair and are outside this change set (the wiring files are untouched).
