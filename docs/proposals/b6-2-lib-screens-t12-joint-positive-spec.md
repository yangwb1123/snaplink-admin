# B6-2 Requirements Specification — missing T-12 joint positive: server-truth timeline renders the drill's `auth.login.success` row

Module: `lib/screens` (analysis bucket `docs/auto/analyses/lib-screens-19d4d0ab.json`) · Direction: T-12 joint positive · Value: 8 · Risk reduction: 8 · Effort: 2 · Confidence: 9
Status: implemented and verified (2026-08-20; test-only change set; zero production diff)
Sibling instances: the B6-2 developer lens (`b6-2-lib-screens-developer-client-id-alignment-spec.md` REQ-4.3) assigns this rendering test to the B6-1 change set; the i18n lens (`b6-2-lib-i18n-verbatim-display-edge-spec.md`) pins the same row's verbatim data-vs-copy boundary. This spec is the **`lib/screens` lens**: it adds the missing positive widget test for the drill row and keeps the T-12 joint's negative half pinned.

Implementation record: the positive widget test and constant-backed drill fixture are landed in `test/audit_log_tab_test.dart`; the three-file acceptance command passes 43/43 and the production implementation is unchanged.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the working tree at HEAD. All hold, with line drift (symbols unchanged, B6-1b landing) and two precision corrections (C1, C2):

| Direction citation | Verification result |
|---|---|
| `docs/proposals/b6-2-lib-screens-developer-client-id-alignment-spec.md` REQ-4.3 — the T-12 joint widget test "lives in the B6-1 change set" | **Exact.** REQ-4 item 3 (Joint acceptance): "that rendering test lives in the B6-1 change set; this lens only guarantees the row exists server-side and the module cannot forge it." |
| `docs/campaigns/implementation-gate.md:56` — console row 1: "T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5" | **Exact.** The positive half (查询触发 self-audit 行 rendered from the sink read) is what this change set adds; the negative half is already pinned (see below). |
| `grep -rn 'auth.login.success' test/` → hits only the census file | **Exact.** Sole hit: `test/oidc_login_handle_success_census_test.dart:97-104` ("no auth.login.success emission string in the module (REQ-4 #5)", scanning `lib/screens/oidc_login`). No positive rendering case exists anywhere in `test/`. |
| `test/audit_log_tab_test.dart:108-467` — server-read groups, no `auth.login.success` case | **Exact substance, line drift.** Group `AuditLogTab server read (AC-1 / AC-3)` at `:123-481`: AC-3a (server success renders the served page size) at `:309-327`, AC-4.2 (positive capabilities → exactly one request) at `:406-421`, and the tenantId/traceId wire-forwarding test at `:423-481`. All fixtures use `admin_client_created` / `admin_user_deleted` / `admin_role_created`; no drill event type. Direction's `:108-467`/`:409-455` → `:123-481`/`:423-481` (B6-1b landing added lines above the group). |
| `test/admin_support_tabs_test.dart:67,179` — T-12 negatives | **Exact substance, line drift.** Group `AuditLogTab` at `:62`; forged-ring negative "lists and filters server audit events; ring clear is inert" at `:64` (ring seeded `:70-76`; `find.textContaining('forged entry') findsNothing` at `:126-127`); CSV-export negative (`=SUM(A1:A2)` formula bait) at `:179` with `forged entry` findsNothing at `:145`. Direction's `:67` → `:64`. |
| `test/oidc_login_handle_success_census_test.dart:97-104` | **Exact.** |
| `lib/screens/admin/audit_log_tab.dart:78-101` — `_refresh` → `AuditReadClient.list` | **Exact substance, 1-line drift.** `_refresh()` at `:84-118`: capability gate `widget.capabilities.has('GET', AuditReadClient.eventsPath)` at `:86-96`, `await _client.list(limit: 100)` at `:102`. Direction's `:78-101` covers the doc comment through the gate. |
| `lib/screens/admin/audit_log_tab.dart:143-149` — outcome/type cell rendering | **Stale region, symbols exact.** `:143-149` is now `_applyFilter`/`_compareRows`. The cell builders moved with the B6-1b landing: EVENT column `:427-433` (`TableCellText(type, bold: true)`), OUTCOME `:435-460` (StatusChip, `label: row.outcome`, "never fabricates localized copy"), ACTOR `:461-468`, TENANT `:470-475`. `StatusChip` renders `Text(label)` (`lib/widgets/status_chip.dart:83-90`) so `find.text('success')` pins the OUTCOME chip exactly. |
| `lib/api/audit_read_client.dart:44-52` — eventsPath + AuditQuery wire | **Exact substance, line drift.** `eventsPath = '/api/v1/audit/events'` at `:15`; `list()` at `:35-51` — `AuditQuery(...).toQueryParameters()` and `_api.get(eventsPath, query: query)` at `:51`. |
| Baseline/landed green | **Verified.** The historical baseline was 40/40; the landed command now passes 43/43. |

### C1 — required testability correction: fixture must interpolate `SSOAdminClient.firstPartyClientId`, not the raw literal

The direction's acceptance writes the fixture `client_id` as the literal `'sso-admin-console'`. At HEAD the sibling constantization has landed: `SSOAdminClient.firstPartyClientId = 'sso-admin-console'` exists (`lib/api/sso_client.dart:82`, used at `:92` and `lib/app_router.dart:36`), and the client_id literal census runs its **constantExists** branch — `test/oidc_login_handle_success_census_test.dart:138-147`: `expect(actual, isEmpty)` — the raw literal must not appear in any `test/*.dart`. The new fixture therefore interpolates `SSOAdminClient.firstPartyClientId` (new import `package:sso_admin/api/sso_client.dart` in `test/audit_log_tab_test.dart`). Identical to the correction the sibling i18n spec recorded as C2. The census file itself is the only file containing the literal (self-split at `:112`).

### C2 — precision note: forged ring is seeded via `AuditLogService().record(...)`, not `debugRingEnabled`

`AuditLogService.debugRingEnabled` (`lib/services/audit_log_service.dart:66-71`) is a `@visibleForTesting` setter gating only the ring **copy surface** (`ringCopyEnabled`, `:60-64`); recording itself is unconditional (`record()` at `:73-80`). The established seeding pattern — used by AC-3a (`test/audit_log_tab_test.dart:65-73`) and `test/admin_support_tabs_test.dart:70-76` — is `AuditLogService().record(AuditEntry(...))` + `addTearDown(service.clear)`. The spec keeps that pattern; intent preserved (a forged ring row present must neither render nor change the count).

### Module-scope facts that shape the requirements

1. **The timeline has no CLIENT column** — TIME/EVENT/OUTCOME/ACTOR/TENANT only (`audit_log_tab.dart:416-475`). The direction's acceptance correctly asserts only EVENT/OUTCOME/TENANT cells; `clientId` rides the fixture and the drill-row shape (search filter and CSV export already carry it — pinned by the sibling i18n lens). No column work here.
2. **The rendering path is server-only by construction**: `_rows` is populated exclusively from `_client.list()`; the ring never feeds the table. The forged-row `findsNothing` guards (AC-3a/AC-3c/AC-3 joint, `admin_support_tabs_test.dart:126-127`) pin the negative half.
3. **The drill row's `client_id` is not rendered** anywhere in the table — the T-12 positive is asserted on the fields that *are* rendered: EVENT (`auth.login.success` verbatim), OUTCOME (`success`), TENANT (`<t>`), plus the server row count.

---

## 2. Scope

**In scope**

- One new `testWidgets` in `test/audit_log_tab_test.dart` inside the existing `AuditLogTab server read (AC-1 / AC-3)` group (REQ-1).
- The fixture for the drill row, interpolating `SSOAdminClient.firstPartyClientId` (C1).
- The mutation-red property (REQ-3) and the standing no-regression command (REQ-4).

**Out of scope (explicitly not changed by this lens)**

- Zero production diff: `lib/` untouched (no column, no rendering, no client, no i18n changes — the CLIENT-column surface and verbatim-data pins belong to the sibling i18n lens).
- No changes to the census files (`test/oidc_login_handle_success_census_test.dart` untouched — its 30-test gate counts only census/client_id/sso files, none touched here).
- No drill-file changes (`tests/integration/audit_login_drill.py` is the developer lens's artifact).
- No changes to `test/admin_support_tabs_test.dart` — its T-12 negatives already pin the forgery half.

---

## 3. Requirements

### REQ-1 — T-12 joint positive: the drill's `auth.login.success` row renders from the server response only

New `testWidgets` in `test/audit_log_tab_test.dart`, inside the existing `AuditLogTab server read (AC-1 / AC-3)` group, using the file's established harness (`_pump`, `_recordingApi`, `_caps`):

1. **Fixture** (module-level, alongside `_eventsBody`): one server row shaped exactly like the drill's sink row —
   `{"id":"drill-1","type":"auth.login.success","outcome":"success","timestamp":<ISO-8601>,"actor_id":"admin-1","client_id":<SSOAdminClient.firstPartyClientId>,"tenant_id":"<t>"}` with `"count":1`.
   The `client_id` must be interpolated from `SSOAdminClient.firstPartyClientId` (C1) — the raw literal is banned from `test/` by the active literal census.
2. **Seed the forged ring** via the file's existing `_seedForgedRing()` helper (C2) — `AuditLogService().record(AuditEntry(...))` + `addTearDown(service.clear)`.
3. **Serve** `GET /api/v1/audit/events` → 200 with the fixture body; capabilities include `/api/v1/audit/events` (positive gate, `_caps(['/api/v1/audit/events'])`).
4. **Assert (all findsOneWidget):**
   - `find.text('auth.login.success')` — EVENT cell, verbatim machine data;
   - `find.text('success')` — OUTCOME chip (`StatusChip` renders `Text(label)`; the closed dropdown shows only `All`, so the chip is the unique match);
   - `find.text('<t>')` — TENANT cell;
   - `find.text('1 entries')` — count == 1 from server rows (the header count is `_rows.length`, never the response `count` and never the ring);
   - `find.textContaining('forged entry')` findsNothing and `find.textContaining('/api/v1/admin/forged')` findsNothing — the ring is not evidence;
   - exactly one recorded request to `/api/v1/audit/events` (via `_recordingApi`) — the row comes from the server response only, behind the capability gate.

**Testable:** the test exists in `test/audit_log_tab_test.dart` with the asserts above; `flutter test test/audit_log_tab_test.dart` passes 25/25.

### REQ-2 — No raw `client_id` literal, census stays active

The new fixture must not introduce the literal `'sso-admin-console'` into `test/` — every reference goes through `SSOAdminClient.firstPartyClientId`.

**Testable:** `grep -rn "sso-admin-console" test/` → hits only `test/oidc_login_handle_success_census_test.dart` (its self-split `:112`); `flutter test test/oidc_login_handle_success_census_test.dart` green (constantExists branch, `expect(actual, isEmpty)`).

### REQ-3 — Mutation-red property

Removing the drill row from the mock response must turn the new test red: with `{"events":[],"count":0}`, `find.text('auth.login.success')`, `find.text('<t>')`, and `find.text('1 entries')` all fail.

**Testable:** temporarily point the mock at the empty body → the test fails; restoring the fixture body → green. Documented as the test's negative control (no separate test file).

### REQ-4 — No-regression / zero-delta boundaries

- `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart test/oidc_login_handle_success_census_test.dart` → all green (43 total in the landed tree).
- `git diff --stat lib/` empty for this change set (test-only).
- `test/admin_support_tabs_test.dart`, `test/oidc_login_handle_success_census_test.dart`, and the standing 30-test gate (`censusCount 10 + clientIdCount 3 + ssoCount 17`) untouched and green.

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | New widget test in `test/audit_log_tab_test.dart`: mock GET `/api/v1/audit/events` returning the drill row `{type:'auth.login.success', outcome:'success', client_id:'sso-admin-console', tenant_id:'<t>', actor_id:...}` with ring empty → assert EVENT/OUTCOME/TENANT cells render and count == 1 | REQ-1: fixture `client_id` interpolated from `SSOAdminClient.firstPartyClientId` (C1); asserts `find.text('auth.login.success')` findsOneWidget, `find.text('success')` findsOneWidget, `find.text('<t>')` findsOneWidget, `find.text('1 entries')` findsOneWidget, exactly one request to `/api/v1/audit/events` |
| AC-2 | Same response with a forged ring entry present (AuditLogService seeded) → row count still from server only, forged row findsNothing | REQ-1 steps 2/4: ring seeded via the established `_seedForgedRing()` pattern (C2); `find.textContaining('forged entry')` findsNothing, `find.textContaining('/api/v1/admin/forged')` findsNothing, count stays `1 entries` |
| AC-3 | Removing the row from the mock response makes the test red | REQ-3: empty-body mock → `auth.login.success`/`<t>`/`1 entries` asserts fail; documented negative control |
| AC-4 | `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart test/oidc_login_handle_success_census_test.dart` green | REQ-2/REQ-4: full command green (43 tests); `grep -rn "sso-admin-console" test/` hits only the census file; no production diff from this change |

T-12 joint mapping (`implementation-gate.md:56`): **positive half** = "查询触发 self-audit 行" — the drill's `auth.login.success` row (client_id resolved from the single source) renders from the sink read (this test); **negative half** = "devtools 伪造不再构成证据" — stays pinned by the existing `findsNothing` guards (`audit_log_tab_test.dart` AC-3a `:317-320`/AC-3c `:380-383`/AC-3 joint `:835-843`, `admin_support_tabs_test.dart:126-127`).

## 5. Dependencies and constraints

- **B6-1 / B6-1a** (server-read timeline): landed at HEAD — the `AuditLogTab server read` group is green; this change set only adds the missing positive case the B6-2 developer lens REQ-4.3 assigns here.
- **B6-2 sibling lenses**: `SSOAdminClient.firstPartyClientId` (lib/api, landed — `sso_client.dart:82`); i18n lens pins the verbatim data-vs-copy boundary for the same row's cells; the developer lens owns the drill artifact and the no-localStorage-forgery module guard.
- **Constraint:** zero production diff; zero new endpoints; zero column changes; no changes to any census or existing negative guard.
- **Consistency:** fixture strings stay in `test/` only (the zero-emission-string invariant scans `lib/` only); no `auth.login.success` emission anywhere in `lib/`.

## 6. Risks and rollback

- **Literal-census regression** (raw `'sso-admin-console'` sneaks into the fixture): caught immediately by the active census branch — the fixture must use the constant (C1). Rollback = remove the test; the census stays green.
- **`find.text('success')` over-match** (a second `success` text appears in the closed dropdown or elsewhere): mitigated by asserting `findsOneWidget` against the current tree (dropdown renders only `All` when closed; verified in the 40-test baseline). If a future UI change adds a duplicate, the assert fails loudly — a desired property, not a false positive.
- **Ring surface interplay** (marker chip text `Debug records` renders alongside the table when `ringCopyEnabled` is true in debug tests): unrelated to the row asserts; the existing AC-3 joint test already covers the badge-vs-rows boundary.
