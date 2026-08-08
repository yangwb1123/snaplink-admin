# B6-1a — Amendment spec: consolidated review fixes for the design doc

> Applies to: `docs/proposals/b6-1a-lib-api-audit-read-client-design.md` (and its content-identical pipeline artifact `docs/auto/runs/land-a-typed-audit-read-client-in-lib-api-auditr-23691df4/artifacts/design-4bb9e6d8/task-1-design.md`).
> Sources consolidated: security_reviewer report (REQ-4 deviation verification, 3 flags), api_contract_reviewer report (wire-surface validation, checks 1–4), test_design_reviewer report + `task-2-acceptance-audit.md` (acceptance enforceability audit).
> Verification: **every amended claim and every quoted `OLD` text in this spec was re-checked against HEAD (2026-08-07) before finalizing** — see Appendix A for the per-amendment evidence table. All `OLD` blocks quote the design doc verbatim; all line numbers cited here were confirmed against the live sources.
> Status of the design doc: frozen design-stage artifact. This spec is the change-control amendment; it is not applied to the doc in place. Implementation must treat the amended text as authoritative (amendments win over the underlying doc text where they overlap).

## 0. Tension-resolution ledger (the four reviewer positions, settled)

| # | Tension | Positions | Resolution |
|---|---|---|---|
| T1 | cursor/eventTypes/outcome client-forwarding | api_contract: "doc-note **or** key-mapping (`eventTypes`→`type`, `cursor`→`offset`); C4 makes the doc-note the only in-scope fix today". test_design: "pinned at the `AuditQuery` layer only — not at `AuditReadClient`; add one exact-query assertion (also pins `eventTypes`→`event_type`)". | **Doc-note + client-layer pin, no mapping (A1).** Key-mapping rejected: it changes the wire contract `AuditQuery` was pinned for and would make the client's wire diverge from `AuditQuery.supportedKeys` semantics — both violations of C4 ("`AuditQuery` untouched"), and functionally inert today (the trio backend ignores unknown params). The mapping is documented as the future filter-UI obligation, not implemented. |
| T2 | AC-5.1 assertability | design: "server rows render through the shell; palette item absent when culled". test_design: "not assertable as written — `_api` has no injectable client (flutter_test 400-stub); culling unexercisable through the shell (`listEndpoints()` always fails → catalog merge → trio always present)". | **Corrected AC-5.1 (A2):** shell asserts gate-passed + `'Admin request failed (400).'` wiring proof; cull/palette move to unit level (`admin_navigation_test`, `command_palette_commands_test`). No new `HttpOverrides` harness added (absent from repo; out of scope). |
| T3 | BFF token in code sketches | test_design: "§1.2 sketch doc comment contains 'BFF' — scan 2 is a case-insensitive whole-file substring scan over `lib/`; copying verbatim lands red". | **A6.4/A6.5:** both code-bound comments (audit_read_client.dart §1.2, audit_log_tab.dart §1.3) reworded to drop the token; design-doc prose may keep "BFF" (not code). |
| T4 | `_api` citation | design's E2 "correction" says `:92`; security: "the design's own correction of the spec is itself wrong by 10 lines — declaration is `:82`". | **A6.2/A6.3:** `:82` is the declaration, `:92` is the `initState` assignment; the spec's `:82` was right. |

All three reviewer reports' remaining positions (facets shape comment, FM-9 row, FM-10 fixture, FM-1 `TimeoutException`, three citation drifts, latent raw-map surface, FM-16 subtitle scan, 110-test baseline notation) are adopted below or explicitly rejected in §7.

---

## A1 — cursor / eventTypes / outcome client-forwarding: doc-note + `AuditReadClient`-layer pin (T1)

**Resolution (settled):** no key mapping; a wire-semantics doc note lands on `list()`/`facets()`, a new design decision **D6** records the rationale, and AC-2 gains the missing client-layer exact-wire pin.

Verified facts this amendment rests on:
- Trio backend `parseQuery` reads **exactly** `type, actor_id, client_id, tenant_id, provider, outcome, request_id, trace_id, since, until, limit, offset`; **no `cursor`, no `event_type`**; unknown params silently ignored (`snaplink` repo, `platform/audit/handlers.go:145-190`; `auditspi/query.go` has no Cursor/EventType fields). `outcome` **is** a real trio key, for events and facets (`handlers.go:20,:152`; `facets.go:48` non-dimension filters).
- Governance service `/api/v1/events` **does** read `event_type` and `cursor` (`snaplink-audit-governance` repo, `internal/httpapi/server.go:927`) — hence `AuditQuery.supportedKeys` is a union of two services' surfaces (`audit_query.dart:51-58`, pinned at `test/audit_query_test.dart:151-160`).
- `AuditQuery.toQueryParameters()` forwards `cursor`→`cursor`, `eventTypes`→`event_type` (singular), `outcome`→`outcome` verbatim (`audit_query.dart:148-165`).

**A1.1 — §1.2 sketch: add doc comments on `list()` and `facets()`.**

`OLD` (the two method signatures as sketched in §1.2):

```dart
  Future<List<AuditEventRow>> list({
    int limit = 100,
    String? cursor,
    String? eventTypes,
    String? outcome,
    String? tenantId,
    String? traceId,
  }) async {
```

`NEW` (doc comment inserted above `list(`):

```dart
  /// Wire note: `cursor` and `event_type` are governance-service keys —
  /// the trio backend reads only `type, actor_id, client_id, tenant_id,
  /// provider, outcome, request_id, trace_id, since, until, limit, offset`
  /// and silently ignores unknown params, so [cursor] and [eventTypes]
  /// pass through unfiltered today; only `limit` and [outcome] are real
  /// trio keys. No mapping is applied (`AuditQuery` untouched, C4); a
  /// future filter UI must map `eventTypes → type` and `cursor → offset`
  /// in its own layer.
  Future<List<AuditEventRow>> list({
    int limit = 100,
    String? cursor,
    String? eventTypes,
    String? outcome,
    String? tenantId,
    String? traceId,
  }) async {
```

`OLD` (`facets()` signature in the same sketch):

```dart
  Future<Map<String, dynamic>> facets({
    int limit = 100,
    String? cursor,
    String? eventTypes,
    String? outcome,
    String? tenantId,
    String? traceId,
  }) async =>
```

`NEW` (doc comment inserted above `facets(`; note A5 also adds a shape comment here — merge both into one doc comment block, A5 text first, this wire note second):

```dart
  /// Same wire-forwarding semantics as [list] (see its wire note):
  /// `cursor`/`event_type` are governance-surface keys ignored by the
  /// trio backend; `outcome`/`limit` are real trio keys.
  Future<Map<String, dynamic>> facets({
    int limit = 100,
    String? cursor,
    String? eventTypes,
    String? outcome,
    String? tenantId,
    String? traceId,
  }) async =>
```

**A1.2 — §1.2 design decisions: append D6 after D5.**

`OLD`: `- **D5 — transport untouched.** No new HTTP behavior, retries, auth, cache, or BFF surface; `list()`/`facets()` ride the existing `query != null` branch of `get()` which bypasses `DataCache` entirely (`snaplink_admin_api.dart:133-134`) — correct for a live timeline. `skipCache()` is therefore redundant-but-harmless in the tab (kept for symmetry with governance; flag still consumed).`

`NEW`: same text, then a new bullet:

```
- **D6 — forward-only cursor/eventTypes/outcome.** `list()`/`facets()` forward the three params verbatim through `AuditQuery` (wire keys `cursor`, `event_type`, `outcome`). Only `outcome` and `limit` are real trio-backend keys (parseQuery reads `type, actor_id, client_id, tenant_id, provider, outcome, request_id, trace_id, since, until, limit, offset`; unknown params are ignored); `cursor`/`event_type` are governance-service keys (`snaplink-audit-governance` `/api/v1/events`). No key mapping is applied — C4 pins `AuditQuery` untouched, and the trio backend's ignore-unknown behavior makes mapping functionally inert today. Documented on the methods (A1.1); the tab never passes them (AC-1.6 no-leak boundary); a future filter UI owns the `eventTypes → type` / `cursor → offset` mapping.
```

**A1.3 — §5 AC-2 row: append assertion (5).**

`OLD` (end of the AC-2 row): `…; (4) surface completeness: `facets()` hits `facetsPath` with the same AuditQuery semantics; `event('a/b')` hits `eventsPath/a%2Fb` with **no** query parameters |`

`NEW`:

```
…; (4) surface completeness: `facets()` hits `facetsPath` with the same AuditQuery semantics; `event('a/b')` hits `eventsPath/a%2Fb` with **no** query parameters — this is a MockClient pattern assertion (`request.url.path` returns the encoded `a%2Fb`), not a routing claim (the Go 1.22 `http.ServeMux` matches the decoded path; real ids are 24-char hex so encoding is identity on the real id space); (5) **client-forwarding pin (exact wire, trio semantics):** `list(cursor: 'c-1')` → `queryParameters` deep-equals exactly `{'limit': '100', 'cursor': 'c-1'}`; `list(eventTypes: 'admin_client_created')` → exactly `{'limit': '100', 'event_type': 'admin_client_created'}` (singular wire key); `list(outcome: 'failure')` → exactly `{'limit': '100', 'outcome': 'failure'}` — forwarding is verbatim via `AuditQuery`, no mapping; `facets(cursor: 'c-1', eventTypes: 'x', outcome: 'failure')` forwards the same three keys identically |
```

---

## A2 — AC-5.1 corrected form: gate-passed + `'Admin request failed (400).'` wiring proof; cull/palette moved to unit level (T2)

Verified facts this amendment rests on:
- `DashboardScreen._api` is built **without** `httpClient` (`dashboard_screen.dart:92-96` → default `http.Client()`) → flutter_test's `HttpOverrides` returns an empty 400 body for every `_api` request (binding 400-stub; **no `HttpOverrides` usage anywhere in `test/`** — verified by grep). `SSOAdminClient`'s MockClient (as in `test/admin_shell_test.dart:13-24`) never reaches `_api`.
- Empty 400 body → `decodeSnaplinkAdminPayload` yields `{}` → `SnaplinkAdminApiError.status = 400`, `code`/`description` null → `toString()` = exactly `'Admin request failed (400).'` (`snaplink_admin_error.dart:41-44`).
- 400 is not a 5xx, so the transport's `maxRetries = 3` loop (`snaplink_admin_api.dart:330`) does not retry — one request, immediate error state.
- Culling is unexercisable through the shell: `listEndpoints()` 400s → `_endpoints` always empty → `AdminNavigationCapabilities(const [])` merges the full `SnaplinkAdminOperationCatalog` (trio present) → `supportsAuditLog` always true (`admin_navigation.dart:60-68`).
- Unit-level cull anchors exist: `admin_navigation_test.dart` ("Admin navigation capabilities" group, documented-catalog merge test at `:103-133`); `command_palette_commands_test.dart` SCIM include/exclude pattern at `:6-29`; cull logic at `lib/widgets/command_palette_commands.dart:289-299` (drops `/admin/*` items whose `routeModule` ∉ visible set; `/admin/audit-log` item at `:247`).

**A2.1 — §4 migration step 8.**

`OLD`: `8. **Extend `test/admin_navigation_test.dart`** (AC-4.3: `supportsAuditLog` true/false/true across the three variants + module culling + predicate equivalence) **and `test/admin_shell_test.dart`** (AC-5.1: endpoints fixture with the trio → navigate to audit-log in the System group → server rows render, proving the page is constructed with the dashboard's `_api`/`capabilities`; palette item absent when culled).`

`NEW`: `8. **Extend `test/admin_navigation_test.dart`** (AC-4.3: `supportsAuditLog` true/false/true across the three variants + module culling + predicate equivalence) **and `test/command_palette_commands_test.dart`** (palette cull at unit level: `commandPaletteItemsForModules` drops the `/admin/audit-log` item when `audit-log` ∉ the visible set — SCIM include/exclude pattern at `:6-29`) **and `test/admin_shell_test.dart`** (AC-5.1 revised, A2.2: navigate to audit-log in the System group → entry present (gate passed, not-enabled copy absent) and the tab renders the error state `'Admin request failed (400).'` — the flutter_test 400 stub is the wiring proof that the page is constructed with the dashboard's live `_api`; server rows are **not** assertable through the shell: `_api` has no injectable client (`dashboard_screen.dart:92-96`) and `listEndpoints()` 400s, so `_endpoints` is always empty and the catalog merge always presents the trio).`

**A2.2 — §5 AC-5 row (1).**

`OLD`: `(1) auditLog entry page constructed as `AuditLogTab(api: _api, capabilities: capabilities)` with the dashboard's instances; entry culled when `supportsAuditLog` is false; palette item absent when culled;`

`NEW`: `(1) **shell wiring proof (revised):** `DashboardScreen` builds `_api` without `httpClient`, so the shell harness cannot serve the trio — flutter_test's `HttpOverrides` 400-stubs every `_api` request (no `HttpOverrides` usage exists in `test/`; `SSOAdminClient`'s MockClient never reaches `_api`). With `SSOAdminClient` MockClient serving `/api/v1/admin/endpoints` + `/api/v1/admin/commerce/plans`, navigate to Audit Log (System group, `admin_module_groups.dart:99-102`) → the entry is present (gate passed — not-enabled copy absent) and the tab renders **`'Admin request failed (400).'`** (empty body → `code`/`description` null → `SnaplinkAdminApiError.toString()` at `snaplink_admin_error.dart:41-44`; 400 is not retried) — behavioral proof the page got the dashboard's live `_api` and catalog-merged `capabilities`. **Cull/palette assertions move to unit level:** `test/admin_navigation_test.dart` (module list offers `AdminModuleId.auditLog` iff `supportsAuditLog` — AC-4.3iii) and `test/command_palette_commands_test.dart` (`commandPaletteItemsForModules` drops the `/admin/audit-log` item when `audit-log` ∉ modules). No `HttpOverrides.global` dart:io harness is added (absent from the repo; out of scope);`

---

## A3 — FM-9 §5 AC-table row + FM-10 planted-count fixture

**A3.1 — §5: insert an FM-9 row between the AC-4 and AC-5 rows.**

`NEW` row (exact text):

```
| **FM-9 — stale-response race** | `test/audit_log_tab_test.dart` | Two in-flight `list()` requests complete **out of order**: MockClient handlers await manually-completed `Completer`s (the driver controls order; query GETs bypass cache/dedup at `snaplink_admin_api.dart:133-134`, so the requests are independent). Trigger the first via the initial pump, the second via search `onChanged` (the refresh button is disabled while `_loading`). Complete the **newer** response first, then the **older** — assert the newer rows are displayed and the older rows are not (`gen != _generation` guard; `mounted` alone insufficient). Discipline: explicit `pump()` only — never `pumpAndSettle` while a request is held (spinner → timeout); resolve **both** completers before test end (the 30 s `requestTimeout` timer otherwise trips the pending-timer check). |
```

**A3.2 — §5 AC-1 assertion (4): planted-count fixture.**

`OLD`: `(4) 200 with 2 real-shape events (`{'id','type','outcome','timestamp','actor_id','client_id','tenant_id'}`, e.g. `type: 'admin_client_created', outcome: 'success'`) → `find.text('2 entries')`, `find.textContaining('admin_client_created')`, subtitle without "on this device";`

`NEW`: `(4) 200 with 2 real-shape events (`{'id','type','outcome','timestamp','actor_id','client_id','tenant_id'}`, e.g. `type: 'admin_client_created', outcome: 'success'`) in a fixture that **plants a decoy `count: 999`** (FM-10) → `find.text('2 entries')` renders the served page size (`_rows.length`; the response `count` field is never read — E14), `find.textContaining('999')` findsNothing, `find.textContaining('admin_client_created')` findsOneWidget, subtitle without "on this device";`

**A3.3 — §5 AC-3 assertion (a): mirror the planted count.**

`OLD`: `(a) server success → server rows render, forged row absent everywhere in the tree, `2 entries` is the server page size;`

`NEW`: `(a) server success → server rows render, forged row absent everywhere in the tree, `2 entries` is the served page size (`_rows.length`), never the planted `count: 999` (FM-10);`

---

## A4 — FM-1: `_refresh` sketch must catch `TimeoutException`

Verified fact: the transport awaits `.timeout(requestTimeout)` (`snaplink_admin_api.dart:166` for `_request`, `:319` for downloads; `requestTimeout` defaults to 30 s at `:41`) — exhaustion throws `TimeoutException` from `dart:async`, which the sketch's single `on SnaplinkAdminApiError` clause does not catch. FM-1's own row already claims the timeout path ("on exhaustion → `SnaplinkAdminApiError`/`TimeoutException` → `_error = error.toString()`"); the sketch must match it or the timeout claim is an unhandled crash.

**A4.1 — §1.3 `_refresh` step 4.**

`OLD`: `4. `on SnaplinkAdminApiError catch (error)` → `if (!mounted || gen != _generation) return;` `_error = error.toString()` — **never `error.data`** (`SnaplinkAdminApiError.toString()` at `snaplink_admin_error.dart:44` excludes `data` by construction). `finally` clears `_loading` under the same guard.`

`NEW`: `4. `on SnaplinkAdminApiError catch (error)` → `if (!mounted || gen != _generation) return;` `_error = error.toString()` — **never `error.data`** (`SnaplinkAdminApiError.toString()` at `snaplink_admin_error.dart:44` excludes `data` by construction); `on TimeoutException catch (error)` → the identical guarded handling (`_error = error.toString()`; `TimeoutException` carries no sensitive fields) — mandatory because the transport's `.timeout(requestTimeout)` (`snaplink_admin_api.dart:166,:319`) throws `TimeoutException` on request timeout, and the tab must add `import 'dart:async';`. `finally` clears `_loading` under the same guard.`

**A4.2 — §3 FM-1 row: cross-reference the catch.**

`OLD`: `| FM-1 | Server 5xx / timeout / network loss | Transport retries GET ≤ `maxRetries` (3, backoff, `snaplink_admin_api.dart:61,:330`); on exhaustion → `SnaplinkAdminApiError`/`TimeoutException` → `_error = error.toString()` + inline retry (re-enters gate); **ring never shown as fallback** | AC-3b (seeded ring + 500 → error state, forged row absent) |`

`NEW`: append to the mitigation cell: `; timeout covered by the `on TimeoutException` clause in `_refresh` (A4.1) — without it FM-1's timeout path is an unhandled crash`.

---

## A5 — `facets()` doc comment citing the verified shape

Verified fact (sibling repo `snaplink`, re-checked at HEAD): envelope `{facets: …}` (`platform/audit/handlers.go:36` `KeyFacets`, response assembly at `:113-116`); `Facets` (`platform/audit/facets.go:19-38`) = `{total: int, outcomes: {outcome→int}, types: {type→int}, clients: {client_id→int}, providers: {provider→int}}`, all five members required; 501 when the sink lacks `FacetQuerier`; `limit`/`offset` "accepted but ignored". The untyped return stays justified (no consumer in this direction; AC-1 pins zero `/facets` requests; AC-2.4 pins unit-only), but the shape is known and must be cited so the pass-through is not mistaken for an undocumented surface.

**A5.1 — §1.2 sketch: doc comment on `facets()`** (merged with the A1.1 wire note into one comment block, this text first):

```dart
  /// Returns the raw facets envelope `{'facets': {total, outcomes, types,
  /// clients, providers}}` (verified shape: `total: int`; `outcomes`/
  /// `types` map key→count; `clients` keyed by `client_id`; `providers`
  /// by provider; all five members required; 501 when the sink lacks
  /// `FacetQuerier`). Pass-through is deliberate — there is no consumer
  /// in this direction; a typed `FacetResult` becomes groundable when
  /// the filter UI lands.
```

---

## A6 — Three citation fixes + BFF-token landing trap

### A6.1 — E1 row (constructor citation `:11` → `:16`)

`OLD` (E1 verified-reality cell): `Confirmed line-for-line: `_logService = AuditLogService()` `:22`, `_refresh` reads `_logService.entries` `:43`, file is 345 lines (wc)`

`NEW`: `Confirmed: `_logService = AuditLogService()` `:22`, `_refresh` reads `_logService.entries` `:43`, `{count} entries` `:161`, `_errorRate` `:129-130`, Clear `:180-192`, CSV `:97-124`, subtitle `:158`, empty state `:244`; 345 lines (wc). `[CORRECTION: constructor at :16, not :11]` — `const AuditLogTab({super.key});` is at `audit_log_tab.dart:16` (the E1 header quotes the spec's `:11`; the previous verified cell failed to pin it)`

### A6.2 — E2 row (`_api` `:92` → `:82` declaration; audit entry block pinned)

`OLD` (E2 verified-reality cell): `Confirmed. `[CORRECTION: :558 → :559]` — the auditLog entry block starts at `:559` (`:558` closes governance); `page: const AuditLogTab()` at `:566` exactly. `_api` declared at `:92` (spec says `:82` — field is `late final` at `:92`, assigned in `initState`; trivial).`

`NEW`: `Confirmed. `[CORRECTION: :558 → :559]` — the auditLog entry block is `:559-567`: `AdminNavigationEntry(` at `:559`, `module: AdminModuleId.auditLog` at `:560`, `page: const AuditLogTab()` at `:566`, closing `),` at `:567` (`:558` closes the governance entry). `[CORRECTION: _api declared at :82, not :92]` — `late final SnaplinkAdminApi _api;` is at `dashboard_screen.dart:82` (the spec's `:82` was right); `:92` is the `initState` assignment`

### A6.3 — §1.5 parenthetical

`OLD`: `(`_api` at `:92`, `navigation`/`capabilities` at `:243-244`, all in scope.)`

`NEW`: `(`_api` declared at `:82`, assigned in `initState` at `:92`; `navigation`/`capabilities` at `:243-244`, all in scope.)`

### A6.4 — §1.2 sketch doc comment: strip the BFF token

`OLD` (the two comment lines in the §1.2 sketch that become `audit_read_client.dart`'s class doc):

```
/// scan 5). `tenantId`/`traceId` are optional context parameters: neither
/// token-claim parsing nor BFF trace_id injection exists in this repo
/// (B4-1/BFF-dependent, [PROPOSED]); they are never hardcoded or derived,
```

`NEW`:

```
/// scan 5). `tenantId`/`traceId` are optional context parameters: neither
/// token-claim parsing nor proxy-side trace_id injection exists in this
/// repo (B4-1-dependent, [PROPOSED]); they are never hardcoded or derived,
```

### A6.5 — §1.3 state-model comment: strip the BFF token

`OLD` (the `_client` sketch lines that become `audit_log_tab.dart` code):

```dart
late final AuditReadClient _client;   // = AuditReadClient(widget.api) — tenant/trace context is
                                      // B4-1/BFF scope; nothing is passed today (D3)
```

`NEW`:

```dart
late final AuditReadClient _client;   // = AuditReadClient(widget.api) — tenant/trace context is
                                      // B4-1 scope; nothing is passed today (D3)
```

Verified trap mechanics (A6.4/A6.5): scan 2 (`scanBffLiterals`, `test/audit_contract_guard_scans.dart:170-185`) is a **case-insensitive whole-file `'bff'` substring scan over `lib/`** — comment-sensitive (the guard test's own probe `'// bff path is proposed only'` trips it, `test/audit_contract_guard_test.dart:113-116`). Both sketches land under `lib/`, so both must avoid the token; design-doc prose (E10 row, D3, D5, C10, §6, §7) may keep it. `command_palette_commands.dart` (palette cull) and `command_palette.dart` (`commandPaletteItemsForModules(widget.allModules)` at `:83`) live in `lib/widgets/`, not `lib/screens/admin/` — the doc's path shorthand `command_palette_commands.dart:247` is correct as a basename; no amendment needed beyond the unit-level move in A2.

---

## A7 — Remaining reviewer-flagged items (beyond the (a)–(f) enumeration, adopted for completeness)

### A7.1 — FM-16: make the `subtitle:` i18n scan extension **mandatory** (was "Recommended (optional per REQ-8)")

Verified facts: `localizedNamedCopy` regex is `(?:title|detail|body|emptyText):\s*(_literalSequence)\s*[,)]` (`test/i18n_coverage_test.dart:78-81`) — `subtitle:` uncovered; the only direct `subtitle:` literal in `lib/screens`+`lib/widgets` is `audit_log_tab.dart:158` (becomes localized in the rework), so the extension is tree-safe today. The extension without the entry would be red; the entry without the extension is an uncaught zh regression.

- §1.7 `OLD`: `Recommended (optional per REQ-8): extend `localizedNamedCopy` in `test/i18n_coverage_test.dart:78-81` to `(?:title|subtitle|detail|body|emptyText):` — tree-safe today (the only direct `subtitle:` literal in `lib/screens`+`lib/widgets` is `audit_log_tab.dart:158`, localized). If taken, it must land in the same change as the new subtitle key (extension without entry → red).` → `NEW`: `**Mandatory** (upgraded from optional after the acceptance audit — FM-16 is only automated with the extension): extend `localizedNamedCopy` in `test/i18n_coverage_test.dart:78-81` to `(?:title|subtitle|detail|body|emptyText):` — tree-safe (the only direct `subtitle:` literal in `lib/screens`+`lib/widgets` is `audit_log_tab.dart:158`, which becomes localized in this rework). It must land in the same change as the new subtitle key (extension without entry → red).`
- §4 step 4 `OLD`: `…+ i18n deltas (§1.7) + filesize decision (§1.8) in the same change.` → `NEW`: `…+ i18n deltas (§1.7, including the mandatory `subtitle:` scan extension) + filesize decision (§1.8) in the same change.`
- §5 AC-6 row `OLD`: `i18n_coverage_test.dart` (optional scan extension)` → `NEW`: `i18n_coverage_test.dart` (mandatory `subtitle:` scan extension)`.

### A7.2 — Latent raw-map surface pin (security flag 3)

Add to §1.3 (after the search/filter paragraph) and mirror in D4:

```
- **Raw-map discipline:** the reworked tab must **never** gain a detail dialog that renders `event()`'s raw `Map<String, dynamic>` (the pre-existing live-events dialog at `admin_live_events_tab.dart:166-190` already renders the full raw `{id}` map via `JsonEncoder` — out of scope here, but the new `event()` is its lib/api twin). Any future detail view must route through `auditEventRowsFromResponse`-style allowlisting. `event()`/`facets()` stay consumer-free in the tab (AC-2.4 pins them unit-only).
```

### A7.3 — Baseline-count notation

§0/§4/§8 say "38 + 55". These are suite-group subsets of the 110-test combined run (9 unchanged + 3 to-be-edited suites) measured green at HEAD. Add to §8: `(The "38 + 55" figures are group subsets; the combined 12-suite run is 110 tests at HEAD.)` — no number changes, notation only.

---

## 7. Explicitly rejected items (kept out of the amendment, with reasons)

| Item (reviewer) | Proposal | Verdict |
|---|---|---|
| Key-mapping `eventTypes`→`type`, `cursor`→`offset` in the client (api_contract) | Alternative to the doc-note | **Rejected (T1).** Violates C4 (`AuditQuery` untouched) and its pinned `supportedKeys`/`fromJson` semantics; functionally inert today (trio ignores unknown params); deferred to the future filter UI and documented as such (A1.1/D6). |
| `AuditQuery.supportedKeys` comment drift — "in the order the governance helper text advertises them" vs the actual helper text order (`tenant_id, outcome, limit`, `governance_tab.dart:413`) and `audit_query_test`'s "exactly the REQ-1 key set" wording (api_contract, cosmetic) | Fix the comment/test wording | **Rejected.** Both live in `AuditQuery`'s own file/test — touching them violates C4 ("`AuditQuery` untouched"; `test/audit_query_test.dart` stays green unchanged per AC-6). Cosmetic only. |
| Shell-level culling harness via `HttpOverrides.global` dart:io mock (test_design, as the only way to shell-test culling) | New harness capability | **Rejected.** No such harness exists in `test/`; adding it is a separate capability beyond this change. Unit-level culling (A2) covers the behavior. |
| Governance `_has` catalog fallback copied into the tab (any reviewer reading of REQ-4) | — | **Rejected.** Already pinned: direct `capabilities.has(...)`, no fallback; governance's own fallback is pinned behavior (§6). No amendment. |
| AC-2.4 `event('a/b')` → `a%2Fb` removed or reworded as a routing claim (api_contract caveat) | Clarify | **Adopted as clarification only** (A1.3): kept as a MockClient pattern assertion with an explicit non-routing note. No assertion change. |

---

## Appendix A — Verification evidence (each amended claim vs HEAD, 2026-08-07)

| Amendment | Claim verified | HEAD evidence |
|---|---|---|
| A1 | Trio backend query keys (no `cursor`/`event_type`; `outcome` real; events + facets) | `snaplink` repo: `platform/audit/handlers.go:145-190` (`parseQuery` reads `type, actor_id, client_id, tenant_id, provider, outcome, request_id, trace_id, since, until, limit, offset`); `handlers.go:15,:20` (`QueryType`, `QueryOutcome`); `facets.go:48` (outcome as non-dimension filter); `auditspi/query.go` — no Cursor/EventType fields |
| A1 | Governance surface reads `event_type` + `cursor` | `snaplink-audit-governance` repo: `internal/httpapi/server.go:927` |
| A1 | `AuditQuery` forwarding: `cursor`→`cursor`, `eventTypes`→`event_type` (singular), `outcome`→`outcome`; trim/omit semantics | `lib/api/audit_query.dart:51-58` (`supportedKeys`), `:148-165` (`toQueryParameters`); `test/audit_query_test.dart:151-160` (set pin) |
| A2 | `_api` built without `httpClient`; `:82` declaration, `:92` assignment | `lib/screens/admin/dashboard_screen.dart:82,92-96` |
| A2 | Empty 400 body → `'Admin request failed (400).'`; 400 not retried | `lib/api/snaplink_admin_error.dart:41-44` (`toString` = `description ?? code ?? 'Admin request failed ($status).'`); `lib/api/snaplink_admin_api.dart:330` (retry only `>= 500`); flutter_test binding 400-stub; zero `HttpOverrides` in `test/` (grep) |
| A2 | Culling unexercisable through the shell; catalog merge | `lib/screens/admin/admin_navigation.dart:60-68` (constructor merge); `test/admin_shell_test.dart:13-24` (MockClient is SSO-side only) |
| A2 | Palette cull logic + item; unit anchors | `lib/widgets/command_palette_commands.dart:247` (`/admin/audit-log`), `:289-299` (module-set cull); `test/command_palette_commands_test.dart:6-29` (SCIM include/exclude); `test/admin_navigation_test.dart:103-133` |
| A2 | auditLog in System group | `lib/screens/admin/admin_module_groups.dart:99-102` |
| A3 | FM-9 mechanics: cache/dedup bypass for query GETs; refresh disabled while loading; 30 s `requestTimeout` | `lib/api/snaplink_admin_api.dart:133-134` (query branch), `:41` (`requestTimeout` default 30 s), `:166,:319` (`.timeout(...)`); tab refresh button disabled while `_loading` (§1.3 states loading renders refresh disabled) |
| A3 | AC-1.4/AC-3a currently lack the planted count | `docs/proposals/b6-1a-lib-api-audit-read-client-design.md` §5 AC-1 (4), AC-3 (a) — quoted verbatim above |
| A4 | `TimeoutException` thrown by transport; sketch catches only `SnaplinkAdminApiError` | `lib/api/snaplink_admin_api.dart:166,:319` (`.timeout(requestTimeout)`); design §1.3 step 4 (quoted verbatim above) |
| A5 | Facets shape: envelope + five required members; 501 without `FacetQuerier` | `snaplink` repo: `platform/audit/handlers.go:36` (`KeyFacets`), `:113-116` (response assembly); `platform/audit/facets.go:19-38` (`Facets`), `:11-13` (501 note) |
| A6.1 | `const AuditLogTab({super.key});` at `audit_log_tab.dart:16` | `lib/screens/admin/audit_log_tab.dart:16` (line 15 = `class AuditLogTab … {`); design E1 header quotes `:11` |
| A6.2 | Entry block `:559-567`, module at `:560`, page at `:566`; `_api` declaration at `:82` | `lib/screens/admin/dashboard_screen.dart:559-567` (opens `:559`, `module:` `:560`, `page: const AuditLogTab()` `:566`, closes `:567`; `:558` closes governance), `:82` (declaration), `:92` (assignment) |
| A6.3 | §1.5 parenthetical cites `:92` | design §1.5 (quoted verbatim above) |
| A6.4/A6.5 | Scan 2 semantics; both sketches land in `lib/` | `test/audit_contract_guard_scans.dart:170-185` (`lower.indexOf('bff')` whole-file, case-insensitive); `test/audit_contract_guard_test.dart:101-123` (AC-3.2, comment probes trip); design §1.2/§1.3 sketches (quoted verbatim above) |
| A7.1 | `subtitle:` uncovered by the regex; single direct `subtitle:` literal in scope | `test/i18n_coverage_test.dart:78-81` (regex `(?:title|detail|body|emptyText):`); `lib/screens/admin/audit_log_tab.dart:158` |
| A7.2 | Live-events raw-map dialog is pre-existing | `lib/screens/admin/admin_live_events_tab.dart:166-190` (`JsonEncoder.withIndent('  ').convert(detail)` in a selectable dialog) |
| A7.3 | Baseline numbers are group subsets | design §0/§4/§8; task-2 audit: combined 12-suite run = 110 tests green at HEAD |

## Appendix B — Amendment application order

Apply in the design doc (both copies — proposal + pipeline artifact) in this order: §0 ledger row additions (optional) → E1/E2 rows (A6.1/A6.2) → §1.2 sketch (A5, A1.1, A6.4), D6 (A1.2), §1.3 (A6.5, A4.1, A7.2), §1.5 (A6.3), §1.7 + §4 step 4 + §5 AC-6 (A7.1) → §3 FM-1 row (A4.2) → §4 step 8 (A2.1) → §5 AC-1 (A3.2), AC-2 (A1.3), AC-3 (A3.3), FM-9 row (A3.1), AC-5 (A2.2) → §8 (A7.3). No other text changes.
