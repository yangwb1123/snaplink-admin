# B6-1a — Design: AuditLogTab rewired to the sink read API via injected SnaplinkAdminApi (module: lib/screens/admin)

> Durable repo copy of the design-stage deliverable for the module-scoped spec `docs/proposals/b6-1a-lib-screens-admin-auditlogtab-server-read-spec.md` (Revision 4). Upstream: `docs/proposals/b6-1a-lib-api-audit-read-client-spec.md` (lib/api deliverable, landed, referenced not re-specced here).
> **Verification posture (2026-08-08).** The evidence supplied was treated as untrusted and re-checked against the working tree (HEAD `26567d5` + uncommitted B6-1a/b/c change set). All 18 evidence rows hold, and the spec's own `[CORRECTION]` markers are themselves correct (re-verified below, §0). The target state is **already implemented** in the working tree; this design therefore (a) certifies the landed change set as the design, (b) specifies the single remaining in-scope addition (AC-5 tab-level Bearer pin, §1.2), and (c) maps every acceptance criterion to a runnable pin (§5).

## 0. Evidence verification (independent re-check; verdicts)

| # | Evidence claim | Re-verified reality | Verdict |
|---|---|---|---|
| E1 | `audit_log_tab.dart` ring-only citations stale; rewire landed (`api`/`capabilities` `:23-26`, `AuditReadClient(widget.api)` `:53`, gate `:68`, server subtitle `:284`) | Confirmed line-for-line: constructor `:26`; `_client` `:53`; gate `:68`; `_client.list(limit: 100)` `:85-86`; `_generation` `:60`; `_applyFilter` `:115`; `_sortRows` `:132`; `_exportCsv` `:169-211`; `_errorRate` `:217-224`; `_debugRingBadge` `:227`; subtitle `:284`; Clear `:307-318`; `onChanged: (_) => _refresh()` `:357`; empty state `:420`. `AuditLogService` references confined to `:33` + `:293` (debug badge). | ✅ |
| E2 | Dashboard wiring `:557`/`:567`, `supportsAuditLog` `:559`; capabilities binding `:244`; 17 injection sites | Confirmed: `capabilities` `:244`; `GovernanceTab(api:_api, capabilities: capabilities)` `:557`; `if (navigation.supportsAuditLog)` `:559`; `AuditLogTab(api: _api, capabilities: capabilities)` `:567`. Census: 18 `AuditLogTab(` matches = 1 constructor declaration + 17 instantiations (1 prod + 16 test), every one injecting both params; **zero** `const AuditLogTab()` empty-arg sites. | ✅ |
| E3 | `governance_tab.dart` `:31,166-190`; `_has` catalog fallback `:80-91` (contrast) | Confirmed: `_auditPath` `:31`; `_queryAudit` `:166-190` with `AuditQuery.fromJson` `:172`, `toQueryParameters()` `:177`, `widget.api.get(...)` `:183`; `_has` third clause consults `SnaplinkAdminOperationCatalog.endpoints` — the exact pattern the audit tab must not copy. | ✅ |
| E4 | `audit_query.dart` `toQueryParameters` `:148-165`; default wire `{'limit':'100'}` | Confirmed: `limit` emitted iff non-null, strings iff non-empty after trim → all-null construction yields exactly `{'limit':'100'}`. | ✅ |
| E5 | `SnaplinkAdminApi.get` `:126-141`; Bearer `[CORRECTION: 318→294]` | Confirmed: `get` at `lib/api/snaplink_admin_api.dart:126-141`, `query != null` branch `:134-135` calls `_request('GET', path, query: query)` — no cache read/write/dedup. Bearer at `:294` (`_request`) and `:163` (probe/login); the spec's correction is right. (`lib/screens/admin/snaplink_admin_api.dart` is a 3-line re-export shim — see §2.) | ✅ + ⚠️ |
| E6 | Trio `snaplink_admin_types.dart:310-312`; `has` `:94` | Confirmed exact: `GET /api/v1/audit/events`, `/facets`, `/events/{id}`; `has()` uses `_normalizePath` `{param}`-compare. | ✅ |
| E7 | Guard scans: bff `:101-123`→`:101-131`, trio `:132-162`, scan 5 `:163-206`; `scanSecondConsumer` `:222-260` | Confirmed group boundaries in `test/audit_contract_guard_test.dart` (`AC-3.2` `:101`, `AC-3.3` `:132`, `scan 5` `:163`) and `scanSecondConsumer` in `test/audit_contract_guard_scans.dart` (queryable-literal + `query:` discriminator). | ✅ |
| E8 | `admin_support_tabs_test.dart:62-163` rewrite (2 server-fixture tests, CSV guard kept) | Confirmed: `group('AuditLogTab')` `:62`; server-read test `:63-147` (pump `:114`); CSV-injection test `:148-248` (pump `:206`). | ✅ |
| E9 | Harness `admin_governance_security_test.dart:12-32` mirrored in `audit_log_tab_test.dart` | Confirmed: `_api` `:12-23`, `_caps` `:25-31`, `_pump` `:32-38`; tab test mirrors (`_api` `:29`, `_caps` `:41`, `_recordingApi` `:48`, `_pump` `:62`, `_seedForgedRing` `:89`). | ✅ |
| E10 | `implementation-gate.md:56` T-12 | Confirmed: console row 1 — read path via sink read API, ring demoted to debug record, "devtools 伪造不再构成证据". | ✅ |
| E11 | Validation shape doc: `{events,count}`, no method/path/status on wire | Doc exists; `audit_event_row.dart` allowlist mapper (`auditEventRowsFromResponse` `:48`) matches. | ✅ |
| E12 | `setup_api.dart:215` trace_id response-parse only; `portal_api.dart` zero audit | Confirmed: `trace_id` read at `:215-216` (response side); `grep -ci audit lib/api/portal_api.dart` → 0. | ✅ |
| E13 | i18n `[CORRECTION: 56→61]`; features `:142`; 5 B6-1b debug keys | Confirmed: server-sourced subtitle at `admin_core.dart:61-62` (zh `'服务器记录的全部认证与管理事件。'`); `features:142` `'No audit events returned by the server yet.'`; old `'recorded on this device'` key absent. | ✅ |
| E14 | Ring seam: `_ringCopyEnabled = kDebugMode` `:76`, `ringCopyEnabled` `:79`, `debugRingEnabled` `:82-84`; Makefile `:38-47` | Confirmed all; release greps include ring vocab, base64 masks, escaped-zh pins, fail-closed. | ✅ |
| E15 | Test counts | **Re-ran:** guard/query/read-client/row suite **47/47**; tab/support-tabs/navigation suite **33/33** — both green. | ✅ |
| E16 | AC-5 gap: `_recordingApi` records `request.url` only; Bearer pinned only at transport (`snaplink_admin_api_test.dart:99,141,303`) | Confirmed: `_recordingApi` `:48-61` captures `request.url` only; transport pins assert `request.headers['authorization'] == 'Bearer admin-token'`. The one required in-scope addition stands (§1.2). | ⚠️ |

No evidence row is contradicted; the only open item is the AC-5 harness extension.

## 1. API changes

### 1.1 Landed change set — certified as designed (no further production change)

The production surface is fixed by the working tree; the design below records the contracts it establishes. Files: `lib/screens/admin/audit_log_tab.dart`, `lib/screens/admin/dashboard_screen.dart`, `lib/screens/admin/admin_navigation.dart` (B6-2a sibling), `lib/services/audit_log_service.dart` (B6-1b seam), new `lib/api/audit_event_row.dart` + `lib/api/audit_read_client.dart`, i18n deltas in `app_strings_source_admin_core.dart` / `app_strings_source_admin_features.dart`.

- **`AuditLogTab`** — constructor becomes `const AuditLogTab({super.key, required SnaplinkAdminApi api, required SnaplinkAdminCapabilities capabilities})`. No self-constructed API, capability set, or display-data service. Read path: `initState`/`_refresh` → capability gate (`widget.capabilities.has('GET', AuditReadClient.eventsPath)`, **no** `SnaplinkAdminOperationCatalog` fallback) → `_client.list(limit: 100)` → `_rows`/`_displayed`. All UI surfaces (header count, error-rate badge, CSV, subtitle, empty state) derive from server rows only.
- **`AuditReadClient`** (new, `lib/api`) — sole owner of the audit trio path literals; `list()` builds the wire exclusively through `AuditQuery(limit: 100, ...).toQueryParameters()`; optional `tenantId`/`traceId` constructor params are omitted from the wire unless non-empty (never derived or hardcoded — B4-1 `[PROPOSED]`); `facets()`/`event()` exist for the documented trio but have no consumer in this direction.
- **`AuditEventRow`** (new, `lib/api`) — 7-field read-only allowlist (`timestamp, type, outcome, id, actorId, clientId, tenantId`); `auditEventRowsFromResponse` is redact-first, `is`-only, never-throws, N-in→N-out, `outcome == ''` fallback.
- **`SnaplinkAdminApi.get`** — `query != null` ⇒ `_request('GET', path, query: query)`, bypassing `DataCache` read/write/dedup: every timeline refresh is a fresh server read (live-timeline property, per `b6-1a-validation-audit-events-response-shape.md`).
- **`AuditQuery.toQueryParameters()`** — canonical wire builder; all-null ⇒ exactly `{'limit':'100'}`; never `tenant_id`/`trace_id`/`bff` literals from the tab.
- **`AuditLogService`** — additive seam: `static bool ringCopyEnabled` (const-folds `kDebugMode` → `false` in release), `@visibleForTesting debugRingEnabled` setter (no-op outside `kDebugMode`). Ring API itself unchanged.
- **i18n** — `'All authentication and administrative events recorded by the server.'` (en/zh) at `admin_core.dart:61-62`; `'No audit events returned by the server yet.'` (en/zh) at `features:142`; old `'recorded on this device'` key removed; 5 B6-1b debug keys land atomically with call sites.

### 1.2 Required addition (the only remaining change): AC-5 tab-level Bearer pin

Scope: `test/audit_log_tab_test.dart` only. No production code changes.

**Design.** Extend the recording harness with a parallel header capture, keeping the existing `List<Uri> requests` assertions untouched (diff-minimal; the 33 green tests keep passing unchanged):

```dart
/// Recording MockClient: records url + headers for every request.
SnaplinkAdminApi _recordingApi(
  List<Uri> requests,
  List<Map<String, String>> requestHeaders,
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    requests.add(request.url);
    requestHeaders.add(request.headers);
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);
```

**Assertions added** (AC-1 test, after the existing query assertions):
- `expect(requestHeaders.single['authorization'], 'Bearer admin-token')` — caller identity on the events request.
- In the search re-query loop: each of the two recorded requests carries the same header (search-triggered re-queries must not drop caller identity).
- Optionally extend the FM-9 race test's hand-built `SnaplinkAdminApi` the same way; the AC-1 pins suffice for AC-5, so this stays optional.

**Rejected alternative** — replacing `List<Uri>` with `List<({Uri url, Map<String,String> headers})>`: cleaner long-term but rewrites ~6 existing assertion sites and the FM-9 harness; not warranted for a one-line security pin.

## 2. Compatibility constraints

| Constraint | State | Mitigation |
|---|---|---|
| `AuditLogTab` constructor is **breaking** (`const AuditLogTab()` → required `api`+`capabilities`) | In-repo: 17/17 sites updated, 0 empty-arg sites (census, E2). | External consumers must inject; the const constructor shape is preserved for const-ness. |
| `lib/screens/admin/snaplink_admin_api.dart` shim | 3-line re-export of `lib/api/snaplink_admin_api.dart`; old import paths keep compiling. | New code imports `package:sso_admin/api/...` directly (per shim header). |
| Wire contract: every timeline request is exactly `{'limit':'100'}` | Trio backend reads only trio keys and silently ignores unknown params (documented in `AuditReadClient.list` wire note). | Server must accept limit-only queries; no `tenant_id`/`trace_id` sent (B4-1/BFF `[PROPOSED]`, off the wire by design). |
| Cache semantics of `SnaplinkAdminApi.get` | `query != null` ⇒ uncached; query-less callers keep read/write/dedup. Existing governance callers already pass `query:` — same behavior. | Documented in §1.1; no caller of the audit path omits `query`. |
| i18n string removal (`'recorded on this device'`) | Breaking for any UI/test referencing the old key. | zh parity pinned (`i18n_coverage_test.dart`); AC-1 zh test asserts the new key renders. |
| Guard scans are behavioral contracts | AC-3.2: no `bff` literals in `lib/`; AC-3.3: audit paths are exactly the trio, GET-only; scan 5: any queryable audit literal + `query:` argument must build through `AuditQuery`; AC-3.4: no raw query maps/null-literal skins. | New audit consumers (facets UI, filters) must route through `AuditReadClient`; `eventTypes → type`, `cursor → offset` mapping belongs in that future consumer's layer. |
| Release bundle | `kDebugMode` const-folding removes the ring surface structurally; `debugRingEnabled` setter folds to `return;`. | `make release-artifact-check` (Makefile:38-47) greps ring vocab + base64/escaped-zh masks, fail-closed. |
| Response-shape allowlist | Real wire fields beyond the 7 (`request_id`, `trace_id`, `span_id`, `actor_ip`, `user_agent`, `metadata`, `hash`, …) never displayed/exported. | `auditEventRowsFromResponse` is the only row-construction path. |
| `lib/api/README.md` | Audit ring row demoted (audit client + row model listed). | Already updated in tree. |

## 3. Failure modes

| # | Failure | Behavior | Pin |
|---|---|---|---|
| FM-9 | Stale in-flight response races a newer fetch (e.g., search-triggered re-query) | `_generation` guard: only the newest fetch commits; older response discarded even on error; gate path bumps `_generation` so stale responses can't overwrite the not-enabled state. | `test/audit_log_tab_test.dart:343-402` (race), AC-4 (gate) |
| FM-1 | Server 500 / error payload | `SnaplinkAdminApiError.toString()` excludes `data` (never the raw payload); error state + Retry issues a fresh request. | AC-3b `:247-285` (`op-1`/`secret` bait never surfaces) |
| FM-2 | Timeout | `TimeoutException` branch → same error surface as FM-1; Retry path. | AC-3b error/Retry joint |
| FM-3 | Capability absence (replica without audit surface) | Gate renders `'This feature is not enabled on the connected replica.'` with **zero requests**; no static-catalog guess (contrast `governance_tab.dart:80-91`). | AC-4.1/4.2 `:308-338` |
| FM-4 | Empty server result `{'events': [], 'count': 0}` | `'0 entries'` + empty-state copy; **ring never acts as fallback**. | AC-3c `:286-306` |
| FM-5 | Devtools-forged ring rows | Ring never renders on the timeline in any server outcome; Clear is debug-only and re-fetches server truth. | AC-3a/b/c (`_seedForgedRing` `:89`), AC-6 |
| FM-6 | Decoy `count` field (e.g., 999 vs 2 rows) | Header count = page length; response `count` never read. | AC-1 (`999` findsNothing) |
| FM-7 | Malformed/foreign payload | Defensive mapper: never throws, N-in→N-out, fallback row `outcome == ''`, `{}` → zero rows. | `test/audit_event_row_test.dart` |
| FM-8 | CSV formula injection | `=SUM(A1:A2)`-style bait neutralized at export; bait is server-served (never ring-seeded). | `admin_support_tabs_test.dart:148-248` |
| FM-10 | Release-bundle ring leakage | Ring vocabulary folded out; `make release-artifact-check` greps fail-closed. | `Makefile:38-47` |
| FM-11 | Caller identity missing on the wire | Transport Bearer pinned (`snaplink_admin_api_test.dart:99,141,303`); tab-level pin added by §1.2 (AC-5). Sink-side self-audit attribution pinned cross-repo (`read_selfaudit_test.go`). | AC-5 after §1.2 lands |
| FM-12 | Cache staleness | `get` with `query` bypasses cache; tab also calls `widget.api.skipCache()` (consumed defensively). | AC-1 single-request pin |

## 4. Migration steps

The change set is implemented but uncommitted over HEAD `26567d5`. Remaining work is one test addition + commit:

1. **Apply §1.2** — extend `_recordingApi` in `test/audit_log_tab_test.dart` with the header capture and add the AC-5 assertions.
2. **Re-run the pinned suites**: `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart test/admin_navigation_test.dart` (33 + new AC-5) and `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart test/audit_read_client_test.dart test/audit_event_row_test.dart` (47); plus `test/snaplink_admin_api_test.dart` (transport Bearer), `test/i18n_coverage_test.dart`, `test/admin_governance_security_test.dart`.
3. **Commit the change set atomically** (tests are lock-step with production): `lib/api/audit_event_row.dart`, `lib/api/audit_read_client.dart`, `lib/screens/admin/audit_log_tab.dart`, `lib/screens/admin/dashboard_screen.dart`, `lib/services/audit_log_service.dart`, i18n sources, `lib/api/README.md`, the test rewrites/new tests, `checks/b6_1b_gates.py`, `Makefile` release greps, and these proposal docs. Sibling B6-1b/B6-2a changes can ride the same commit (they are interdependent: debug badge + `supportsAuditLog`).
4. **Full-suite + release gates**: `make test` (CI parity); `make build-prod && make release-artifact-check` (fail-closed ring-vocab greps).
5. **Cross-repo verification** (no action required): sink-side `audit.event.read` emission pinned at `../snaplink-audit-governance/internal/service/read_selfaudit_test.go` (B1-5/T-12 joint).
6. **Scope guard** — do not expand: `trace_id`/`tenant_id` stay `[PROPOSED]` and off the wire; facets/detail reads and the filter-UI mapping stay out.

## 5. Testable acceptance mapping

| AC | Assertion (testable form) | Pin | Command |
|---|---|---|---|
| AC-1 | Exactly one request to `/api/v1/audit/events` with `queryParameters == {'limit':'100'}`; no `tenant_id`/`trace_id` keys; server rows render; decoy count never read; server-sourced subtitle; ring ignored; search re-query keeps identical wire (2 requests); zh twin | `audit_log_tab_test.dart:110-227` (group `:108`) | `flutter test test/audit_log_tab_test.dart` |
| AC-2 | Search terms never appear in any request; every request (incl. search-triggered re-queries) is exactly `{'limit':'100'}`; filter narrows the rendered page only (the "zero additional requests" literal is superseded by the approved re-query design) | AC-1 second half (`enterText` → `requests, hasLength(2)`); FM-9 `:343-402` | same |
| AC-3 | Forged ring markers never render under server-success (server-derived `'50% errors'`), server-500 (error state, `error.data` bait never surfaces, Retry re-fetches), server-empty (ring never a fallback) | AC-3a `:228-246`, AC-3b `:247-285`, AC-3c `:286-306`; `_seedForgedRing` `:89` | same |
| AC-4 | Caps lacking `GET /api/v1/audit/events` → not-enabled copy + **zero requests**, no catalog fallback; positive caps → exactly one request + rows | AC-4.1 `:308`, AC-4.2 `:325` (group `:308-338`) | same |
| AC-5 | `request.headers['authorization'] == 'Bearer admin-token'` on the events request **at the tab level** (after §1.2); transport pins unchanged | `audit_log_tab_test.dart` AC-1 (new, §1.2); `snaplink_admin_api_test.dart:99,141,303`; cross-repo `read_selfaudit_test.go` | `flutter test test/audit_log_tab_test.dart test/snaplink_admin_api_test.dart` |
| AC-6 | Server-fixture tests pump the injected tab; CSV formula-injection guard preserved (bait served by server, neutralization asserted); ring-seeded markers never render; Clear empties ring while server rows render | `admin_support_tabs_test.dart:62-248` (pumps `:114`/`:206`) | `flutter test test/admin_support_tabs_test.dart` |
| AC-7 | Zero `AuditLogTab(` instantiations without `api:` + `capabilities:` (17/17 inject); zero `const AuditLogTab()` empty sites; ring references confined to `kDebugMode`-folded debug badge (`:33`,`:293`); release bundle free of ring vocabulary | `grep -rn "AuditLogTab(" lib/ test/`; `Makefile:38-47`; B6-1b tests `audit_log_tab_test.dart:414-584` | `make release-artifact-check` |
| AC-8 | Guard scans green (audit-path literals, bff-literals, catalog-trio, second-consumer, raw-stringification); zh keys atomic | `audit_contract_guard_test.dart:101-206` + `:27`/`:208`; `i18n_coverage_test.dart` | `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart test/audit_read_client_test.dart test/audit_event_row_test.dart` (47) |

Verification commands (current state, pre-§1.2):

```bash
flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart \
  test/audit_read_client_test.dart test/audit_event_row_test.dart   # 47 passed (re-run)
flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart \
  test/admin_navigation_test.dart                                    # 33 passed (re-run)
grep -rn "AuditLogTab(" lib/ test/                                  # 17 sites, all injected
make test                                                           # full suite (CI parity)
```
