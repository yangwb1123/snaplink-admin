# B6-2 Design — missing T-12 joint positive: server-truth timeline renders the drill's `auth.login.success` row

Module: `lib/screens` (direction `add-the-missing-t-12-joint-positive-server-truth-5a7c0b56`, analysis `docs/auto/analyses/lib-screens-19d4d0ab.json`) · Direction: T-12 joint positive · Value: 8 · Risk reduction: 8 · Effort: 2 · Confidence: 9
Status: implemented and verified (2026-08-20; test-only change set; zero production diff)
Design for the requirements spec `docs/proposals/b6-2-lib-screens-t12-joint-positive-spec.md` (REQ-1 … REQ-4, AC-1 … AC-4).
Sibling instances: the B6-2 developer lens (`b6-2-lib-screens-developer-client-id-alignment-spec.md` REQ-4.3) assigns this rendering test to the B6-1 change set; the i18n lens (`b6-2-lib-i18n-verbatim-display-edge-design.md`) pins the same row's verbatim data-vs-copy boundary. This design is the **`lib/screens` lens**: one new widget test that proves the joint's positive half ("查询触发 self-audit 行" rendered from the sink read) while the negative half ("devtools 伪造不再构成证据") stays pinned by the existing guards.

---

## 0. TL;DR

One file touched: `test/audit_log_tab_test.dart`. One `testWidgets` is now landed inside the existing `AuditLogTab server read (AC-1 / AC-3)` group, plus the top-level const fixture `_drillEventsBody` that interpolates `SSOAdminClient.firstPartyClientId` and the required import.

The test pumps `AuditLogTab` with a `_recordingApi` mock serving the drill's sink row (`type: auth.login.success`, `outcome: success`, `tenant_id: '<t>'`, `client_id: <constant>`, `count: 1`), seeds the forged ring via the file's existing `_seedForgedRing()` helper, and asserts:

- `find.text('auth.login.success')` findsOneWidget (EVENT cell, verbatim machine data)
- `find.text('success')` findsOneWidget (OUTCOME chip — `StatusChip` renders `Text(label)`)
- `find.text('<t>')` findsOneWidget (TENANT cell, verbatim)
- `find.text('1 entries')` findsOneWidget (header count = `_rows.length` from server rows)
- `find.textContaining('forged entry')` / `find.textContaining('/api/v1/admin/forged')` findsNothing (ring is not evidence)
- exactly one recorded request to `/api/v1/audit/events`, query `{'limit': '100'}`

**No API changes** (production), no new endpoints, no columns, no i18n, no census edits. Post-landing acceptance is 43/43 for the three-file command; the mutation (empty-body mock) turns the test red; the `sso-admin-console` literal census stays green because the fixture interpolates the constant (C1).

---

## 1. Evidence verification (untrusted claims → working-tree facts)

Every claim in the requirements evidence was re-checked against the working tree. **All substantive claims hold** — verified live, including the landed acceptance run (`flutter test` on the three acceptance files → **43/43 passed**, 2026-08-20).

| Evidence claim | Verification result |
|---|---|
| `b6-2-lib-screens-developer-client-id-alignment-spec.md` REQ-4 item 3 — joint T-12 widget test "lives in the B6-1 change set" | ✅ **Exact.** REQ-4 item 3 (Joint acceptance): "that rendering test lives in the B6-1 change set; this lens only guarantees the row exists server-side and the module cannot forge it." |
| `docs/campaigns/implementation-gate.md:56` — console row 1: "T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5" | ✅ **Exact.** Line 56, verbatim. Positive half = this change set; negative half already pinned (`audit_log_tab_test.dart` AC-3a/AC-3c/AC-3 joint + `admin_support_tabs_test.dart:64,126-127`). |
| `grep -rn 'auth.login.success' test/` → sole hit in the census file | ✅ **Exact.** Two hits, both in `test/oidc_login_handle_success_census_test.dart:97,101` (absence census over `lib/screens/oidc_login` only). No positive rendering case anywhere. |
| Landed 43/43 on the three acceptance files | ✅ **Verified live.** `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart test/oidc_login_handle_success_census_test.dart` → `+43: All tests passed!` on 2026-08-20. |
| Server-read group `:108-467` → `:123-481`; wire-forwarding `:409-455` → `:423-481` | ✅ **Exact.** Group `AuditLogTab server read (AC-1 / AC-3)` opens `:123`; wire-forwarding `testWidgets` spans `:423-480` with group close at `:481`. Insertion point for the new test: between `:480` and `:481`. |
| `admin_support_tabs_test.dart` negative `:67` → `:64` | ✅ **Exact.** Group `AuditLogTab` at `:62`; "lists and filters server audit events; ring clear is inert" at `:64` (ring seeded `:70-76`, `forged entry` findsNothing `:126-127`). |
| `_refresh` `:78-101` → `:84-118` | ✅ **Exact.** Capability gate `widget.capabilities.has('GET', AuditReadClient.eventsPath)` at `:86-96`; `await _client.list(limit: 100)` at `:102`. |
| Cell builders `:143-149` → EVENT `:427-433` / OUTCOME `:435-460` / TENANT `:470-475` | ✅ **Exact.** `TableCellText(type, bold: true)`; OUTCOME `StatusChip(label: row.outcome)` — `lib/widgets/status_chip.dart` renders `Text(label)`; TENANT `TableCellText(row.tenantId)`. |
| `audit_read_client.dart` `:44-52` → `eventsPath` `:15`, `list()` `:35-51` | ✅ **Exact.** `static const eventsPath = '/api/v1/audit/events'` at `:15`; `list()` at `:35-51` builds `AuditQuery(...).toQueryParameters()` and calls `_api.get(eventsPath, query: query)`. |
| **C1** — `SSOAdminClient.firstPartyClientId` exists; census in constantExists branch | ✅ **Exact.** `lib/api/sso_client.dart:82` `static const String firstPartyClientId = 'sso-admin-console'`; census `test/oidc_login_handle_success_census_test.dart:138-147` runs `expect(actual, isEmpty)` (literal self-split at `:112`). **Design consequence:** the fixture interpolates the constant, never the raw literal. |
| **C2** — forged-ring seeding via `AuditLogService().record(...)`; `debugRingEnabled` gates only the copy surface | ✅ **Exact.** `_seedForgedRing()` at `test/audit_log_tab_test.dart:104-106` = `AuditLogService().record(AuditEntry(...))` + `addTearDown(service.clear)`. `debugRingEnabled` (`lib/services/audit_log_service.dart:66-71`) is a `@visibleForTesting` setter for `_ringCopyEnabled` (`ringCopyEnabled` getter `:60-64`); `record()` (`:73-80`) is unconditional. The new test reuses `_seedForgedRing()` verbatim — the flag is not part of seeding. |

**Working-tree note (design-level finding):** `lib/` currently carries *uncommitted* sibling landings (B6-2 constantization in `lib/api/sso_client.dart`, `lib/app_router.dart`, `lib/screens/admin/audit_log_tab.dart` — 18 insertions vs HEAD `e1073ce`). The requirements stage verified against this de facto HEAD (dirty tree), and so does this design. REQ-4's "`git diff --stat lib/` empty" is scoped to **this change set**: it must add zero production diff on top of the current tree.

**Second design-level finding:** the existing `_eventsBody`/`_eventsBodyRelative` fixtures carry `"client_id":"console"` — a *different* value, out of the census's scope (census scans the exact `sso-admin-console` literal). They stay untouched; only the new fixture must be census-clean.

---

## 2. Design

### 2.1 REQ-1 — the new `testWidgets` (fixture + asserts)

**New import** (sorted after the existing `sso_admin/api/snaplink_admin_api.dart` import):

```dart
import 'package:sso_admin/api/sso_client.dart';
```

Canonical path — the same import is used by `test/admin_detail_screens_test.dart:8`, `test/admin_shell_test.dart:8`, `test/app_router_client_id_wiring_test.dart:8`, etc. (The `package:sso_admin/sso_client.dart` shim exists but the `api/` path is the established test convention.)

**New fixture** (top-level const, placed directly after `_eventsBodyRelative` at `:29-40`):

```dart
/// The drill's sink row (T-12 joint positive): auth.login.success with the
/// first-party client_id resolved from the single source (C1 — the raw
/// literal is banned from test/ by the active literal census).
const _drillEventsBody =
    '{"events":['
    '{"id":"drill-1","type":"auth.login.success","outcome":"success",'
    '"timestamp":"2026-08-05T12:00:00Z","actor_id":"admin-1",'
    '"client_id":"${SSOAdminClient.firstPartyClientId}","tenant_id":"<t>"}],'
    '"count":1}';
```

Const interpolation of `SSOAdminClient.firstPartyClientId` is valid Dart (`static const String`), so the fixture keeps the file's top-level-const convention — no getter/function needed (D1). The `tenant_id` value `'<t>'` is a deliberately hostile string (angle brackets) proving verbatim passthrough (D6).

**New test** — inserted at the end of the `AuditLogTab server read (AC-1 / AC-3)` group, between the wire-forwarding test's close (`:480`) and the group close (`:481`):

```dart
    testWidgets(
      'T-12 joint positive: the drill auth.login.success row (client_id '
      'from the single source) renders from the server response only '
      '(REQ-4.3)',
      (tester) async {
        _seedForgedRing();
        final requests = <Uri>[];
        final api = _recordingApi(requests, {
          '/api/v1/audit/events': (_) => http.Response(_drillEventsBody, 200),
        });
        await _pump(
          tester,
          AuditLogTab(
            api: api,
            capabilities: _caps(['/api/v1/audit/events']),
          ),
        );

        // EVENT cell — verbatim machine data.
        expect(find.text('auth.login.success'), findsOneWidget);
        // OUTCOME chip — StatusChip renders Text(label); the closed
        // dropdown shows only 'All', so the chip is the unique match.
        expect(find.text('success'), findsOneWidget);
        // TENANT cell — verbatim, hostile string passthrough.
        expect(find.text('<t>'), findsOneWidget);
        // Header count = _rows.length (server rows), never response
        // count and never the ring.
        expect(find.text('1 entries'), findsOneWidget);
        // The forged ring is not evidence.
        expect(find.textContaining('forged entry'), findsNothing);
        expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
        // The row comes from exactly one server read, behind the
        // capability gate, with the established default query.
        expect(requests, hasLength(1));
        expect(requests.single.path, '/api/v1/audit/events');
        expect(requests.single.queryParameters, {'limit': '100'});
      },
    );
```

Design decisions:

- **D2 — placement.** Append inside the group (after `:480`): purely additive, keeps every line-pinned citation in the sibling docs stable, and satisfies REQ-1's "inside the `AuditLogTab server read (AC-1 / AC-3)` group" requirement.
- **D3 — `_recordingApi`, not `_api`.** REQ-1 requires "exactly one recorded request"; the recording harness (`test/audit_log_tab_test.dart:63-76`) is the established pattern (AC-1.2, AC-4.2). The `hasLength(1)` + path + query asserts are the request census.
- **D4 — `_seedForgedRing()` reuse (C2).** The helper already does `AuditLogService().record(...)` + `addTearDown(service.clear)` (`:104-106`). Do **not** touch `debugRingEnabled` — it gates only the ring *copy surface*; recording is unconditional, and AC-3a (`:309-327`) proves the seeded-ring-with-server-rows configuration is the file's own precedent.
- **D5 — exact-match `find.text` is collision-safe.** The ring-copy marker (visible in tests because `_ringCopyEnabled` defaults to `kDebugMode`) renders the single full string `Debug records: 1 entries` — `find.text('1 entries')` (exact match) cannot collide; `find.text('success')` is a different full string from `auth.login.success` and from the marker. If a future UI adds a duplicate, `findsOneWidget` fails loudly — a desired property.
- **D7 — assert `hasLength(1)` before touching `requests.single`** (avoid a confusing `StateError` masking the real failure).

### 2.2 REQ-2 — census-safe fixture (C1)

The only new string constant is `_drillEventsBody`, and its only literal of interest is absent: `client_id` is interpolated from `SSOAdminClient.firstPartyClientId`. The word `sso-admin-console` appears **nowhere** in the new code. The census (`oidc_login_handle_success_census_test.dart` constantExists branch, `expect(actual, isEmpty)`) therefore stays green with zero edits.

### 2.3 REQ-3 — mutation-red negative control (documented, not a separate file)

The empty-body mock (`{"events":[],"count":0}`) is the test's negative control, executed ad hoc at landing (M5) and documented in the spec — not a second committed test. Rationale: a committed duplicate test would double-maintain the same fixture and add no coverage (the AC-3c empty-result test at `:367` already pins the empty state positively).

### 2.4 REQ-4 — no-regression boundaries

- Three-file command goes 40 → 41 green.
- `git diff --stat lib/` adds **zero** production diff on top of the current working tree (this change set touches `test/` + docs only).
- `test/admin_support_tabs_test.dart`, `test/oidc_login_handle_success_census_test.dart`, and the standing 30-test gate (censusCount 10 + clientIdCount 3 + ssoCount 17 files) untouched.
- No changes to `tests/integration/audit_login_drill.py` (developer lens's artifact), no i18n delta, no new endpoints.

---

## 3. API changes

**Production: none.** No new endpoints, no signature changes, no new dependencies, no `lib/` edits.

**Test-surface additions** (all in `test/audit_log_tab_test.dart`):

| Symbol | Kind | Notes |
|---|---|---|
| `import 'package:sso_admin/api/sso_client.dart'` | import | For `SSOAdminClient.firstPartyClientId` (C1); canonical path per §2.1 |
| `const String _drillEventsBody` | top-level const fixture | Const-interpolates the static const; sibling of `_eventsBody` |
| one `testWidgets(...)` | test | Name carries provenance: "T-12 joint positive … (REQ-4.3)" |

No other file — including `test/admin_support_tabs_test.dart` (negatives), the census file, and all of `lib/` — is modified.

---

## 4. Compatibility constraints

1. **Zero production diff (this change set).** `lib/` already carries uncommitted sibling landings; the design adds nothing on top. Gate: `git diff --stat lib/` shows no *new* entries attributable to this change set.
2. **Literal census is active and decisive.** The raw `sso-admin-console` must not appear in any `test/*.dart` except the census file's self-split (`:112`). Violation → census red (`expect(actual, isEmpty)`).
3. **Group membership.** REQ-1 requires the test inside `AuditLogTab server read (AC-1 / AC-3)` (`:123-481`); placement after `:480` keeps all existing line citations valid.
4. **Const-ness contract.** The fixture relies on `SSOAdminClient.firstPartyClientId` being `static const`; if a future refactor drops `const`, the fixture becomes a compile error (loud, immediate — FM-4).
5. **Existing fixture convention.** `_eventsBody`'s `"client_id":"console"` (a different value) is out of census scope; leave it untouched.
6. **No i18n/CLIENT-column surface.** The timeline has no CLIENT column (TIME/EVENT/OUTCOME/ACTOR/TENANT only, `audit_log_tab.dart:416-475`); the sibling i18n lens owns verbatim-copy pins. This test asserts only rendered fields.
7. **No new dependencies** — `flutter_test`, `http`/`http/testing`, `flutter_localizations` all already in the file.
8. **30-test gate untouched** — none of the census/client_id/sso test files are edited here.

---

## 5. Failure modes

| # | Failure mode | Trigger | Detection / mitigation |
|---|---|---|---|
| FM-1 | Literal census regression: raw `'sso-admin-console'` sneaks into the fixture | Implementer copies the direction's literal instead of the constant | Census red immediately (`constantExists` branch); grep guard `grep -rn "sso-admin-console" test/` → hits only the census file. Mitigation: interpolation is mandated in §2.1; no other path to the value exists in the test. |
| FM-2 | `find.text('success')` over-match | Future UI renders a second exact `success` text (e.g., filter dropdown item) | `findsOneWidget` fails loudly. Documented as a desired property (spec §6); not masked by `findsWidgets` or `findsAtLeast` |
| FM-3 | Request-count drift: `hasLength(1)` fails | Double fetch (e.g., double initState, lost `_generation` guard, future capability re-check) | Same assert family as AC-1.2/AC-4.2 — the test doubles as a duplicate-fetch regression pin |
| FM-4 | Fixture compile failure | `firstPartyClientId` loses `const` | Const-interpolation compile error at fixture — immediate, before any test run |
| FM-5 | Ring-copy marker interplay | Marker chip `Debug records: 1 entries` renders (default `kDebugMode` → `ringCopyEnabled`) | Exact-match `find.text` cannot collide with the badge's full string; the marker never contains `forged entry` (count badge only). AC-3 joint (`:827-843`) independently pins the badge-vs-rows boundary. If a future marker lists labels, `findsNothing('forged entry')` trips — desirable |
| FM-6 | OUTCOME chip refactor (localized label) | `StatusChip` label no longer verbatim | `find.text('success')` red; sibling i18n lens pins the same boundary independently — double coverage |
| FM-7 | Row off-viewport / table virtualization | Harness viewport change hides the single row | `findsOneWidget` red; harness `physicalSize 1200x2200` (`_pump`, `:78-84`) already proven by AC-3a for the same table |

All failure modes are **loud and test-local** — none can silently pass, and none affects production behavior (zero production surface).

---

## 6. Migration steps

No runtime migration exists (test-only change). The landing sequence is complete:

| Step | Action | Verification |
|---|---|---|
| M1 | Add import `package:sso_admin/api/sso_client.dart` (sorted after `sso_admin/api/snaplink_admin_api.dart`) | `dart format` clean |
| M2 | Add `_drillEventsBody` const after `_eventsBodyRelative` (`:27-40`) | Compiles (const interpolation valid) |
| M3 | Add the `testWidgets` block between `:480` and `:481` (end of the server-read group) | `flutter analyze test/audit_log_tab_test.dart` clean |
| M4 | Run the three-file command | **43/43 green** in the landed tree |
| M5 | Mutation check (negative control): temporarily point the mock at `http.Response('{"events":[],"count":0}', 200)` → run the single test → expect red on `auth.login.success` / `<t>` / `1 entries`; restore the fixture body and re-run → green | Red then green, same command |
| M6 | Census + diff guards | `grep -rn "sso-admin-console" test/` → only the census file; `git diff --stat lib/` → no new entries from this change set; `git status` shows only `test/audit_log_tab_test.dart` (+ this doc) |
| M7 | Commit | Single test file + docs; message records T-12 joint positive + REQ-4.3 provenance |

Rollback: revert the single test file — zero production surface, no runtime rollback, no data migration.

---

## 7. Testable acceptance mapping

| Spec | Acceptance (observable) | Test / mechanism | Gate command |
|---|---|---|---|
| AC-1 (REQ-1) | Mock `GET /api/v1/audit/events` serves the drill row (`type: auth.login.success`, `outcome: success`, `client_id: <constant>`, `tenant_id: '<t>'`); EVENT/OUTCOME/TENANT render; count == 1 | New `testWidgets` asserts `find.text('auth.login.success')` / `find.text('success')` / `find.text('<t>')` / `find.text('1 entries')` all findsOneWidget; `hasLength(1)` + path + query on `_recordingApi` | `flutter test test/audit_log_tab_test.dart` |
| AC-2 (REQ-1/REQ-2) | Same response with forged ring seeded → count still server-only; forged row findsNothing | `_seedForgedRing()` (C2); `find.textContaining('forged entry')` / `('/api/v1/admin/forged')` findsNothing; `1 entries` holds | same |
| AC-3 (REQ-3) | Removing the row from the mock response turns the test red | M5 mutation drill: empty-body mock → `auth.login.success` / `<t>` / `1 entries` asserts fail; fixture restored → green | manual, documented (M5) |
| AC-4 (REQ-2/REQ-4) | Three-file command green; census green; zero production diff | 43/43; census untouched (constantExists branch); `grep -rn "sso-admin-console" test/` → census only; no new production diff from this change | `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart test/oidc_login_handle_success_census_test.dart`; census file run; git guards |

T-12 joint mapping (`implementation-gate.md:56`): **positive half** = "查询触发 self-audit 行" — the drill's `auth.login.success` row renders from the sink read, client_id resolved from the single source (this test); **negative half** = "devtools 伪造不再构成证据" — stays pinned by the existing findsNothing guards (`audit_log_tab_test.dart` AC-3a `:309-327`/AC-3c `:367-388`/AC-3 joint `:827-843`, `admin_support_tabs_test.dart:126-127`), untouched by this change set.

---

## 8. Risks and scope exclusions

**Risks** (all low, all test-local):

- **Test-name collision with future B6-2 additions** — the name embeds "T-12 joint positive" + "(REQ-4.3)" provenance; a future sibling test must use its own name. No conflict today (`grep -c 'T-12 joint positive' test/` → 0 before landing).
- **Line-citation drift** — inserting inside the group shifts lines *after* `:481` (FM-2 group, TIME-column group, B6-1b group). No committed citation references those later regions by line; the server-read citations (`:123-481`) are unaffected (insertion is at the group's end). Sibling docs' cell-builder citations (`:427-475`) are all before the insertion point.
- **kDebugMode marker visibility** — the ring-copy marker renders in the test environment; FM-5 explains why the asserts are collision-safe.

**Scope exclusions (explicitly not this change set):**

- No production code (`lib/`) — zero diff.
- No CLIENT column work — the timeline has no such column; verbatim copy/data-vs-copy pins belong to the sibling i18n lens.
- No edits to `test/admin_support_tabs_test.dart` (negatives), the census file, or any file in the 30-test gate.
- No drill-file changes (`tests/integration/audit_login_drill.py` — developer lens's artifact).
- No i18n catalog changes, no new endpoints, no new dependencies.
