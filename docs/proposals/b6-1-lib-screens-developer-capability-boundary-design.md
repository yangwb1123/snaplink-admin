# B6-1 — Design: Capability-driven navigation boundary for the audit tab (module: lib/screens/developer)

> Upstream: `docs/proposals/b6-1-lib-screens-developer-capability-boundary-spec.md` (requirements, verified 2026-08-07).
> Every citation below was re-verified against the repo at HEAD `b82d2cf` (2026-08-07). The requirements' evidence table (15 rows) was treated as **untrusted claims** and re-checked; verdicts in §0.

## 0. Evidence verification (claims re-checked, not trusted)

| Spec citation | Verified reality | Verdict |
|---|---|---|
| HEAD is `b82d2cf` | `git log --oneline -3` → `b82d2cf verify: B6-1c harness prototype baseline (builder + guard + behavioral pins)` | ✅ |
| Durable spec exists with §1–§6 | `docs/proposals/b6-1-lib-screens-developer-capability-boundary-spec.md` present; §2 has 15 evidence rows; §3 REQ-1..5; §4 AC-1..4; §5 out-of-scope; §6 risks | ✅ |
| Pipeline artifact + meta | `docs/auto/runs/b6-1-capability-driven-navigation-boundary-audit-f161f833/artifacts/requirements-10762e10/requirements.md` (+ `.meta.json` with fingerprint `c6af2171…`) — pointer + verification summary per the B6-2 run convention | ✅ |
| `snaplink_admin_types.dart:310-312` audit trio | `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}` — exact | ✅ |
| `app_router.dart:13,31` | :13 doc comment on reverse-proxy `/developer/` route; :31 `ProductEntry.developer => const DeveloperScreen(),` — exact | ✅ |
| `developer_screen.dart:10-18` | Doc comment: no developer account/login; POST /register unauthenticated or operator-issued token; manage authenticated solely by `registration_access_token` — exact; `DeveloperScreen({DeveloperApi? api})` at :21 | ✅ |
| `dashboard_screen.dart` audit entry | `page: const AuditLogTab(),` at **:566** (entry :559-566, `module: AdminModuleId.auditLog` at :560, unconditional); governance contrast `page: GovernanceTab(api: _api, capabilities: capabilities),` at **:557**; `_api` late final :82; `capabilities` from `AdminNavigationCapabilities(_endpoints)` :243-244; `AdminLiveEventsTab(api: _api, endpoints: _endpoints)` :342; `if (navigation.supportsWebhooks)` :500 | ✅ (lines shifted vs direction citation, as recorded) |
| `governance_tab.dart` paths/gate/read | `_auditPath` :31, `_facetPath` :32, `_auditQuery` default `'{"limit": 100}'` :33; `_has(String, String)` **:81-85** — spec quotes :81-83 (`capabilities.has(...) || endpoints.any(...)`), but the full body adds a third branch (`SnaplinkAdminOperationCatalog.endpoints.any(...)` at :84-85) plus `_route` normalization :91-93; events read `widget.api.get(_auditPath, query: parameters)` at :183, facets twin gated `_has('GET', _facetPath)` at :184-186; gate `if (!_has('GET', _auditPath))` → `'Audit querying is not enabled on the connected replica.'` at :400-403, `if (_has('GET', _auditPath))` at :404; constructor `required api`/`required capabilities` :18-24 | ✅ (one nuance: the full gate body is :81-85, not :81-83 — design replicates the **full** body, §1.2) |
| `admin_module_groups.dart:84-92` | `id: 'developers'` :84; modules :88-92 (webhooks/liveActivity/operations/recoveryReleases); `AdminModuleId.auditLog` in `'system'` group at :102 | ✅ |
| `snaplink_admin_api.dart:126,134` | `get(String path, {Map<String, String>? query, bool forceRefresh = false})` at :126; `if (query != null) return _request('GET', path, query: query);` at :133-134 (cache bypass for query reads); `listEndpoints()` at :113 | ✅ |
| `audit_query.dart:17,68,148,167` | `class AuditQuery` :17, `factory fromJson` :68, `toQueryParameters()` :148 (int → `'$limit'` string coercion; default wire `{'limit': '100'}`), `AuditQueryParseException` :167 | ✅ |
| Guard Scan 5 | `test/audit_contract_guard_scans.dart:222-233` `scanSecondConsumer` — lib file with queryable audit literal **and** `query:` argument must contain `AuditQuery`; fixtures at `audit_contract_guard_test.dart:173`, `audit_contract_guard_mutation_test.dart:234`; scan driver runs all four scans over `lib/**/*.dart` at :88-100 | ✅ |
| `{id}` route precedent | `admin_live_events_tab.dart:167` — `'/api/v1/audit/events/${Uri.encodeComponent(id)}'` via `widget.api.get(...)`, no `query:` map | ✅ |
| `admin_operations_tab.dart:56` | `endpoint.path.startsWith('/api/v1/audit')` — UI grouping prefix, not a call (scan-1 whitelisted) | ✅ |
| `entry_ux_test.dart:134` | `testWidgets('developer discovery failure offers an in-place retry', ...)` at :134 | ✅ |
| `admin_gate_test.dart` / `admin_navigation_test.dart` | Exist; **zero** `audit`/`developer` matches (grep count 0) — boundary pins only | ✅ |
| `admin_support_tabs_test.dart:88,149` | Both lines pump `const MaterialApp(home: Scaffold(body: AuditLogTab()))` inside `group('AuditLogTab')` (:62-163); file **already has local `_api`/`_caps` helpers** at :24-43 (same shape as `admin_governance_security_test.dart:12-32`) | ✅ |
| `admin_navigation.dart:59-65,158-166` | `AdminNavigationCapabilities` merges `documentedEndpoints ?? SnaplinkAdminOperationCatalog.endpoints` with runtime inventory; `capabilities` is the merged `SnaplinkAdminCapabilities` | ✅ |
| `snaplink_admin_types.dart:89-101` | `SnaplinkAdminCapabilities` — `endpoints` :90, `has(method, path)` :94-101 with `_normalizePath` (`:param`) | ✅ |
| T-12 gate | `docs/campaigns/implementation-gate.md:56` — console row: audit page calls sink read API; T-12 joint: query triggers self-audit row; devtools forgery no longer evidence | ✅ |
| Regression floor green at HEAD | `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart test/admin_gate_test.dart test/admin_navigation_test.dart test/entry_ux_test.dart test/admin_support_tabs_test.dart test/admin_governance_security_test.dart` → **61 passed** (incl. the `:134` retry test and the AuditLogTab ring tests) | ✅ |

**Additional verified fact the design relies on:** the merged capabilities view always contains the documented catalog, so in production `_has('GET', '/api/v1/audit/events')` is true even with an empty runtime inventory — the existing governance test names this explicitly (`'…catalog fallback renders the UI even with empty capabilities'`). The in-tab gate is a **parity/defense-in-depth gate** with GovernanceTab; the placeholder is exercised when capabilities are constructed without the trio (tests, or a future catalog change). This is intended behavior, not a bug to "fix".

## 1. API changes

### 1.1 `lib/screens/admin/audit_log_tab.dart` — constructor DI (REQ-1)

Replace the parameterless constructor (:15-16) with the exact `GovernanceTab` shape (`governance_tab.dart:18-24`):

```dart
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart'; // SnaplinkAdminCapabilities, SnaplinkAdminEndpoint

class AuditLogTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const AuditLogTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  ...
}
```

- The tab **must not** construct its own `SnaplinkAdminApi` or capability set; no `http` import added to the tab.
- The raw-endpoints alternative (`AdminLiveEventsTab(api: _api, endpoints: _endpoints)`, `dashboard_screen.dart:342`) is **rejected** (spec REQ-1): it would duplicate the `_has` logic that `SnaplinkAdminCapabilities.has` already provides.
- `const AuditLogTab()` must no longer appear anywhere in `lib/` or `test/`.

### 1.2 Same file — in-tab capability gate, full governance body (REQ-2)

Replicate the **complete** governance gate, not just the two branches quoted in the spec at :81-83 (the third branch and `_route` normalization are part of the behavior the acceptance compares against):

```dart
static const _auditPath = '/api/v1/audit/events';

bool get _auditReadEnabled => _has('GET', _auditPath);

bool _has(String method, String path) =>
    widget.capabilities.has(method, path) ||
    widget.capabilities.endpoints.any(
      (endpoint) =>
          endpoint.method == method && _route(endpoint.path) == _route(path),
    ) ||
    SnaplinkAdminOperationCatalog.endpoints.any(
      (endpoint) =>
          endpoint.method == method && _route(endpoint.path) == _route(path),
    );

String _route(String path) => path
    .replaceAllMapped(RegExp(r'\{[A-Za-z_][A-Za-z0-9_]*\}'), (_) => ':id')
    .replaceAllMapped(RegExp(r':[A-Za-z_][A-Za-z0-9_]*'), (_) => ':id');
```

(`SnaplinkAdminOperationCatalog` comes from `package:sso_admin/api/snaplink_admin_catalog.dart`; `_has`/`_route` are byte-identical to `governance_tab.dart:81-93`.)

**Gated build** — when `!_auditReadEnabled`, `build` renders a minimal page (breadcrumb + placeholder) and **nothing else**:

```dart
if (!_auditReadEnabled)
  return ListView(
    padding: const EdgeInsets.all(16),
    children: const [
      AdminBreadcrumb(),
      SizedBox(height: 8),
      LocalizedText(
        'Audit querying is not enabled on the connected replica.',
      ),
    ],
  );
```

- Same string as `governance_tab.dart:401-403`. No header actions (refresh/export/clear), no search/filter, no ring UI in gated mode.
- The gate is derived in `build` from the injected `capabilities` (immutable) — no extra state field, no `initState` caching.
- **Zero-request guarantee:** `_refresh` (below) early-returns when `!_auditReadEnabled`; no code path issues any request to `/api/v1/audit/*` while gated.
- **No navigation machinery:** the dashboard entry stays an unconditional `AdminNavigationEntry` (`dashboard_screen.dart:559-566`); **no** `supportsAuditLog` getter on `AdminNavigationCapabilities` (spec REQ-2; governance has none).

### 1.3 Same file — request contract via `SnaplinkAdminApi.get` + `AuditQuery` (REQ-3)

Split the current synchronous `_refresh` (:40-53) into a sync ring refresh and an async read, so per-keystroke search/filter churn does not hit the network (B6-1a later re-defines re-query semantics; its REQ-1 owns that):

```dart
void _refreshRing() {          // existing _refresh body, unchanged: filter + _sortEntries + setState
  ...
}

Future<void> _refresh() async {
  _refreshRing();
  await _maybeFetchEvents();
}

Future<void> _maybeFetchEvents() async {
  if (!_auditReadEnabled) return;                       // zero-request guarantee
  final parameters = const AuditQuery(limit: 100).toQueryParameters(); // {'limit': '100'}
  try {
    final response = await widget.api.get(_auditPath, query: parameters);
    if (!mounted) return;
    _onEventsResponse(response);                        // seam — baseline no-op, B6-1a fills
  } catch (_) {
    if (!mounted) return;
    // Baseline containment: ring-backed rows remain; B6-1a defines the error UI.
  }
}

/// B6-1a seam: maps the server response to rows. Baseline (B6-1): no-op —
/// the timeline remains ring-backed until B6-1a lands.
void _onEventsResponse(Map<String, dynamic> response) {}
```

- `initState` calls `_refresh()` (async; `unawaited(...)` or plain call — fire-and-forget is the existing codebase pattern); the `AdminListHeader(onRefresh:)` callback and the refresh `IconButton` keep calling `_refresh()`.
- Search `onChanged`, method-filter `onChanged`, and `_onSort` switch to `_refreshRing()` (no network).
- **Only** `GET /api/v1/audit/events` is called by this direction (facets and the `{id}` detail are B6-1a's read surface; scan 1 pins the trio). Every `query:`-carrying audit call goes through `AuditQuery.toQueryParameters()` — never a hand-built map (guard scan 5, `audit_contract_guard_scans.dart:222-233`).
- No new methods on `SnaplinkAdminApi`; no direct `http`; no BFF/path invention (`[PROPOSED]` stays doc-only per `docs/proposals/audit-contract-batch-snaplink-console.md:9-11`).

### 1.4 `lib/screens/admin/dashboard_screen.dart:566` — wiring (REQ-1/REQ-6)

```dart
page: AuditLogTab(api: _api, capabilities: capabilities),
```

Both bindings are already in scope (`_api` :82; `capabilities` :243-244, the documented+runtime merged view). `const` is dropped — the entries list is already non-const (cf. `GovernanceTab(...)` at :557).

### 1.5 Test changes

**`test/admin_support_tabs_test.dart` (:88, :149 — the only in-scope existing-test edits, spec E15):**

```dart
// :88 (lists, filters and clears local audit entries) and :149 (CSV export) —
await tester.pumpWidget(
  MaterialApp(
    home: Scaffold(
      body: AuditLogTab(
        api: _api({}),                                   // file-local helper :24-37; 404s everything
        capabilities: _caps(['/api/v1/audit/events']),   // file-local helper :39-43; gate passes
      ),
    ),
  ),
);
```

The file's local `_api`/`_caps` already exist (:24-43). With the gate satisfied, `initState` fires one contained read (404 → caught, ring rows remain), so all existing ring assertions (`'2 entries'`, export, formula-injection) hold **unchanged**. Their ring-semantics assertions are not re-asserted anywhere new (they belong to B6-1a/B6-1b).

**New `test/audit_log_tab_test.dart` (B6-1 slice; shared file, split by concern — B6-1a appends its rendering groups later):** helpers `_api(routes)`, `_caps(paths)`, `_pump(tester, child)` modeled on `test/admin_governance_security_test.dart:12-32`; `_api` records every `request.url.path` + `request.url.queryParameters` and 404s unregistered paths. Groups:

1. `'AuditLogTab capability gate'` — caps **without** the audit read; assert placeholder text `'Audit querying is not enabled on the connected replica.'` renders and **zero** recorded requests have `path.startsWith('/api/v1/audit')`.
2. `'AuditLogTab server read'` — caps with `/api/v1/audit/events` (+ `/api/v1/audit/facets`), MockClient 200 `'{}'` on both; assert ≥1 request to `/api/v1/audit/events` (gate satisfied ⇒ request issued).
3. `'AuditLogTab request contract'` — same fixture; assert every recorded path ∈ `{/api/v1/audit/events, /api/v1/audit/facets, /api/v1/audit/events/{id}}` (percent-encoded form per `admin_live_events_tab.dart:167`) and every query-carrying request has `queryParameters` **exactly** `{'limit': '100'}`.

**No changes** to `test/audit_contract_guard_test.dart`, `test/audit_contract_guard_mutation_test.dart`, `test/admin_gate_test.dart`, `test/admin_navigation_test.dart`, `test/entry_ux_test.dart` — they pass against the new code unchanged (scan 1 trio membership, scan 5 `AuditQuery` presence, boundary pins).

## 2. Compatibility constraints

| # | Constraint | Grounding / guarantee |
|---|---|---|
| C1 | **Constructor change is breaking but fully internal.** All call sites of `AuditLogTab()` are in-repo: `dashboard_screen.dart:566` + `admin_support_tabs_test.dart:88,149`. All three are updated in this change set; `const AuditLogTab()` is grep-prohibited afterwards (AC-1.1). No external consumers (app-internal widget, not exported). | REQ-1; AC-1.1 |
| C2 | **Wire contract unchanged for the read:** default parameters are exactly `{'limit': '100'}` — `AuditQuery(limit: 100).toQueryParameters()` stringifies via `'$limit'` (`audit_query.dart:148`), identical to the governance default `'{"limit": 100}'` (`governance_tab.dart:33`) and to B6-1a AC-1's exact-limit assertion. | REQ-3; AC-2.3 |
| C3 | **Route surface frozen to the documented trio** (`snaplink_admin_types.dart:310-312`). B6-1 adds only the `/api/v1/audit/events` literal to `lib/`; guard scan 1 rejects any fourth audit path; scan 5 rejects hand-built `query:` maps. | REQ-3; AC-2.2/2.4 |
| C4 | **Zero-request guarantee when gated** is a new behavior (today the tab always renders ring data). It applies only to `/api/v1/audit/*` network reads; `AuditLogService` (localStorage) reads are not requests and remain permitted until B6-1a removes them. | REQ-2; AC-1.2 |
| C5 | **Merged-view semantics (production gate always passes).** `dashboard_screen.dart:243-244` builds capabilities from `AdminNavigationCapabilities(_endpoints)` whose documented merge includes the catalog trio (`admin_navigation.dart:59-65,158-166`), so in production `_auditReadEnabled` is true. The placeholder is exercised only for directly-constructed capability sets without the trio. This is **parity with GovernanceTab** (its own tests name the catalog fallback) — do not "fix" it by dropping the documented merge. | §0 additional fact; REQ-2 |
| C6 | **Sequencing with B6-1a:** B6-1 lands with the ring still backing the timeline and the server read fired-and-contained (`_onEventsResponse` no-op). B6-1a lands after, replacing the ring source and filling the seam; until then `test/admin_support_tabs_test.dart` ring assertions are the correct green floor. | REQ-5; §4 step 5 |
| C7 | **Sibling-spec conflict resolved in this direction's favor:** B6-1a spec REQ-5 suggests navigation culling for the audit entry; this spec's REQ-2 (later, re-verified at HEAD) forbids culling and mandates the in-tab gate. The in-tab gate satisfies B6-1a's substance ("no page offered / no request" ⇒ placeholder + zero requests) without touching `admin_navigation.dart`. B6-1a's implementer must follow this design, not its own REQ-5 wording. | REQ-2; AC-1.2 |
| C8 | **DCR zero-delta:** `lib/screens/developer/`, `lib/app_router.dart:31`, `admin_module_groups.dart:84-92`, `dashboard_screen.dart:500` group gates — all untouched. No `SnaplinkAdminApi`/`SnaplinkAdminCapabilities`/audit tokens enter the developer module. | REQ-4; AC-3 |
| C9 | **Gate identity with governance:** the tab's `_has` replicates the **full** 3-branch body (`governance_tab.dart:81-85` + `_route` :91-93), not the 2-branch quote in the spec's E2. Behavioral identity matters more than the spec's line span; the catalog branch is redundant under the merged view (C5) but harmless and keeps future divergence impossible. | REQ-2; AC-1 |
| C10 | **Async-surface compatibility:** `Future<void> _refresh()` remains assignable to the existing `void Function()` callback slots (`AdminListHeader.onRefresh`, `IconButton.onPressed`); `initState` fire-and-forget matches codebase pattern; every post-await `setState` is `mounted`-guarded (precedent `admin_live_events_tab.dart:166-171`). | §1.3; F6 |
| C11 | **No new API surface:** zero changes to `lib/api/*` (the b6-1c `AuditQuery` already covers the read), zero changes to `AdminNavigationCapabilities`, zero new getters, zero `[PROPOSED]` interfaces coded. | REQ-3; §6 |

## 3. Failure modes

| # | Failure | Trigger | Symptom / impact | Mitigation | Acceptance |
|---|---|---|---|---|---|
| F1 | Gate false (caps without audit read) | `_caps([...])` lacking `/api/v1/audit/events`, or future catalog change | Placeholder renders, **zero** audit requests — intended behavior | `_has` early-return in `_maybeFetchEvents`; gated build branch | AC-1.2 |
| F2 | Gate accidentally removed by a future edit | refactor deletes `_has`/gated branch | Requests fire without capability → capability-blind reads | AC-1.2 zero-request assertion is the regression pin | AC-1.2 |
| F3 | Hand-built query map in new tab code (`query: {'limit': '100'}`) | implementer bypasses `AuditQuery` | Guard scan 5 fails in CI before merge (`audit_contract_guard_scans.dart:222-233`); AC-2.3 wire assertion also fails | REQ-3 mandates `AuditQuery`; guard is repo-wide | AC-2.3/2.4 |
| F4 | Non-trio audit literal introduced | e.g. a `/api/v1/audit/export` path | Guard scan 1 fails CI (whitelist = trio + `admin_operations_tab.dart:56` grouping prefix) | scan 1; §1.3 only adds the events literal | AC-2.2 |
| F5 | Missed `const AuditLogTab()` call site | another file constructs the tab | Analyzer compile error (required params) + AC-1.1 grep fails | C1 lists all three call sites; grep proof in AC-1.1 | AC-1.1 |
| F6 | `setState` after dispose (async read completes late) | user navigates away mid-read | Flutter `setState() called after dispose` exception | `if (!mounted) return;` before `_onEventsResponse` and in both catch paths | AC-1/AC-2 (pumpAndSettle clean) |
| F7 | Read failure 4xx/5xx/network in not-gated mode | sink down, 401/403, timeout | Contained: ring rows remain, no crash, no error UI (baseline; B6-1a defines the banner) | try/catch-all in `_maybeFetchEvents` | AC-1.3 (200 fixture); B6-1a error tests |
| F8 | Per-keystroke network churn | search/filter handlers calling the async `_refresh` | Repeated identical reads per keystroke | handlers use `_refreshRing()`; only initState + explicit refresh call `_refresh()` | AC-2 (recorded request set bounded) |
| F9 | Updated ring tests fail because the gate accidentally fails | `admin_support_tabs_test.dart` fixtures without audit endpoints | `'2 entries'`/export assertions fail (placeholder instead of ring UI) | fixtures inject `_caps(['/api/v1/audit/events'])` (C1/§1.5) | AC-4.4 |
| F10 | Duplicate initState read | `initState` + first build both fetch | Two identical requests; harmless for AC (asserts ≥1, exact map) but wasteful | fetch only in `initState`/`_refresh`; build is pure | AC-1.3 (≥1) |
| F11 | Concurrent B6-1a edit of the shared `test/audit_log_tab_test.dart` | both directions add groups | Merge conflict / assertion overlap | concern-split convention: B6-1 owns gate+request groups, B6-1a appends rendering groups; neither re-asserts the other's behavior | §5; spec §6 risk row |
| F12 | Reviewer "fixes" C5 (removes documented merge / treats always-true gate as a bug) | misunderstanding of merged-view semantics | Production gate no longer a parity gate; governance divergence | §0 additional fact + C5 documented; governance tests name the catalog fallback | AC-1.2 (direct-construction fixture) |

## 4. Migration steps (ordered; each step leaves the tree green)

> Note: the working tree carries unrelated in-flight pipeline changes (`pbatch/*`, guard-test formatting, `docs/proposals/`, `docs/campaigns/`, `docs/auto/runs/` — uncommitted). The steps below gate on the feature change set only, against the current tree (61-test baseline already verified green in §0).

1. **Lib change + call-site fix in one commit** (§1.1-§1.4): constructor DI, `_has`/`_route`/`_auditReadEnabled`, gated build, `_refreshRing`/`_refresh`/`_maybeFetchEvents`/`_onEventsResponse`, dashboard wiring `:566`, and the `admin_support_tabs_test.dart:88,149` constructor updates (they are *required* for the tree to compile — step 1 must include them). Gate: `flutter analyze` clean; `flutter test test/admin_support_tabs_test.dart` green (ring assertions hold via C1 fixtures); `flutter test test/audit_contract_guard_test.dart` green (scan 1 + scan 5 compliance of the new code).
2. **Add `test/audit_log_tab_test.dart`** (B6-1 slice, §1.5): gate group, server-read group, request-contract group. Gate: new file green; `flutter test test/audit_contract_guard_test.dart` still green.
3. **Boundary/regression suites**: `flutter test test/admin_gate_test.dart test/admin_navigation_test.dart test/entry_ux_test.dart test/audit_query_test.dart` — all pass **unchanged** (AC-3.1, AC-4.1). Gate: green.
4. **Grep/diff proofs** (AC-1.1, AC-3.2/3.3, AC-4.2/4.3): `grep -rn "const AuditLogTab()" lib/ test/` → no hits; `git diff --stat` → no entries under `lib/screens/developer/`; `lib/app_router.dart` and `admin_module_groups.dart` show zero diff; `test/admin_gate_test.dart`/`test/admin_navigation_test.dart` still contain zero `audit`/`developer` references; `grep -n "auditLog" lib/screens/admin/admin_module_groups.dart` → only `:102`.
5. **Sequencing hand-off to B6-1a** (sibling direction): B6-1a lands after, replacing the ring as the render source through the `_onEventsResponse` seam, adding facets/`{id}` reads and error UI, and appending rendering groups to the shared test file. Full-suite gate: `flutter test` + `flutter analyze` at each landing.

## 5. Testable acceptance mapping

| Spec check | Test file / artifact | Concrete assertions (pinned) |
|---|---|---|
| AC-1.1 (DI; no const) | analyzer + grep | `flutter analyze` clean; `grep -rn "const AuditLogTab()" lib/ test/` → **no hits**; `dashboard_screen.dart:566` reads `AuditLogTab(api: _api, capabilities: capabilities)` |
| AC-1.2 (gate: placeholder + zero requests) | `test/audit_log_tab_test.dart` group 1 | pump with `_caps(['/api/v1/admin/endpoints'])` + recording MockClient (404 default): `find.text('Audit querying is not enabled on the connected replica.')` findsOneWidget; recorded requests where `path.startsWith('/api/v1/audit')` → **zero** |
| AC-1.3 (gate satisfied ⇒ read issued) | same, group 2 | `_caps(['/api/v1/audit/events', '/api/v1/audit/facets'])`, 200 `'{}'` on both: requests to `/api/v1/audit/events` ≥ 1 |
| AC-2.1/2.2 (trio only) | same, group 3 | every recorded `request.url.path` ∈ `{/api/v1/audit/events, /api/v1/audit/facets, /api/v1/audit/events/{id}}` (id form percent-encoded per `admin_live_events_tab.dart:167`); no request to any other path |
| AC-2.3 (typed query on the wire) | same, group 3 | every query-carrying request has `request.url.queryParameters` **exactly** `{'limit': '100'}` — proving `AuditQuery.toQueryParameters()` (`audit_query.dart:148`), not a hand-built map |
| AC-2.4 (guard-enforced) | `flutter test test/audit_contract_guard_test.dart` | scan 1 (trio whitelist) and scan 5 (second-consumer `AuditQuery` requirement) green with the new tab code; tab source contains `AuditQuery` and no raw `query: {` literal on audit calls |
| AC-3.1 (DCR unchanged) | `flutter test test/entry_ux_test.dart` | passes unchanged, incl. `'developer discovery failure offers an in-place retry'` at `:134` |
| AC-3.2/3.3 (zero-delta proof) | `git diff --stat` + grep | no changes under `lib/screens/developer/`; `lib/app_router.dart:31` unchanged; zero `SnaplinkAdminApi`/`SnaplinkAdminCapabilities`/`/api/v1/audit` tokens in `lib/screens/developer/` |
| AC-4.1 (boundary tests unchanged) | `flutter test test/admin_navigation_test.dart test/admin_gate_test.dart` | both pass with **no edits** to either file |
| AC-4.2 (decoupling grep) | grep | both files still contain zero `audit`/`developer` references after the change |
| AC-4.3 (module groups decoupled) | grep | `grep -n "auditLog" lib/screens/admin/admin_module_groups.dart` → only `:102` (system group); `'developers'` group (`:84-92`) untouched |
| AC-4.4 (in-scope test updates only) | `flutter test test/admin_support_tabs_test.dart` | green with constructor updates at `:88,:149` (fixtures per C1/§1.5); `git diff --stat test/` shows **no other** existing test file edited |
| REQ-1..REQ-5 traceability | §1.1-1.5 + C1-C11 | REQ-1 → §1.1/1.4; REQ-2 → §1.2; REQ-3 → §1.3; REQ-4 → §1.4+AC-3; REQ-5 → AC-4 + guard suite |

## 6. Out of scope / risks

**Out of scope** (per spec §5, carried forward): B6-1a server-response data model, response-to-rows mapping (the `_onEventsResponse` seam is the hand-off), localStorage-ring removal/demotion (B6-1b), facets and `{id}` reads (B6-1a), B6-2 client_id alignment, any `lib/screens/developer/` change, nav culling / `supportsAuditLog` machinery, new endpoints/BFF paths/`trace_id` injection/claim parsing (all `[PROPOSED]` per `docs/proposals/audit-contract-batch-snaplink-console.md:9-11`), sink-side self-audit emission (B1-5).

**Risks and mitigations** (spec §6 carried forward, plus design-level additions):
- **Line-drift risk** (spec §2 corrections): all citations re-anchored at HEAD `b82d2cf` in §0; implementation must use the verified numbers, not the direction's originals.
- **Gate-copy divergence risk:** the tab's `_has` is a private duplicate of governance's. If governance's gate ever changes, the audit tab's must change with it — mitigate by keeping the bodies byte-identical and noting the shared provenance in a comment on `_has`.
- **Intermediate-state risk (ring-backed timeline with fired-and-contained reads):** bounded by C6 sequencing — B6-1a lands immediately after and takes over rendering; the seam and the AC-1/AC-2 request contract are the stable surface B6-1a builds on.
- **Guard brittleness:** the new tab's audit literal is a member of the pinned trio (scan 1 whitelist), so no allowlist change is needed; scan 5's `query:`-presence discriminator is already proven against `AuditLogTab`-shaped fixtures (`audit_contract_guard_test.dart:173`, `audit_contract_guard_mutation_test.dart:234`).
- **Working-tree noise:** the uncommitted pipeline/guard files are unrelated to this change set; migration gates run against the current tree (61-test baseline green, §0).
