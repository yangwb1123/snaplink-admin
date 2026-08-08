# B6-1c — Design: Typed audit read contract `AuditQuery` with tenant_id/trace_id correlation (module: lib/screens/admin)

> Upstream: `docs/proposals/b6-1c-lib-screens-admin-audit-read-contract-spec.md` (requirements).
> Every citation below was re-verified against the repo on 2026-08-07 (verification table in §0). The spec's `[CORRECTION]` (E4: `snaplink_admin_api.dart:89-91` → `:126`) and line-drift caveat (E12: `parseQuery` at `:910`, `TraceID` binding in the `:927` return) are carried forward.

## 0. Evidence verification (claims re-checked, not trusted)

| Spec citation | Verified reality | Verdict |
|---|---|---|
| `governance_tab.dart:30-32` — `_auditPath`/`_facetPath`/`_auditQuery` default `'{"limit": 100}'` | `:30` `static const _auditPath = '/api/v1/audit/events';`, `:31` `_facetPath = '/api/v1/audit/facets';`, `:32` `final _auditQuery = TextEditingController(text: '{"limit": 100}');` | ✅ exact |
| `governance_tab.dart:167-176` — raw JSON stringification + unvalidated pass-through | `_queryAudit` at `:166`; `_json(_auditQuery.text, 'Audit query')` `:167`; `query.map((key, value) => MapEntry(key, '$value'))` `:169`; `widget.api.get(_auditPath, query: parameters)` `:175`; facets gated `_has('GET', _facetPath)` `:176`, twin `get(_facetPath, query: parameters)` `:177`; `_json` returns `null` + sets `_error` `'$label must be a JSON object.'` for non-map/non-JSON `:233-241` | ✅ exact |
| `portal_api.dart` has no audit methods | Paths confirmed: `/me` (`:245,:271`), `/sessions/me`, `/consents/me`, `/roles/me`, `/permissions/me`, `/menus/me`, `/me/notifications/stream` (`:125`), `/logout` (`:268`). No audit path, no query-param support on any method | ✅ |
| `snaplink_admin_api.dart:89-91` typed query | `[CORRECTION]` real signature `get(String path, {Map<String, String>? query, bool forceRefresh = false})` at **`:126`**; `query != null` → `_request('GET', path, query: query)` at `:133-134` (bypasses cache, correct for live reads); `_request` builds `Uri.parse('$baseUrl$path').replace(queryParameters: query)` at `:288` (standard URI encoding) | ✅ (`:126`, not `:89-91`) |
| `snaplink_admin_types.dart:310-312` trio | `GET /api/v1/audit/events`, `GET /api/v1/audit/facets`, `GET /api/v1/audit/events/{id}` — exact; `SnaplinkAdminOperationCatalog.endpoints` is derived from this `routes` listing (`snaplink_admin_catalog.dart:10-12`) | ✅ |
| `governance_tab.dart:404` helper text | `'Example: {"tenant_id":"acme","outcome":"failure","limit":100}'` — exact; the only advertised audit-query vocabulary in the UI | ✅ |
| Only `trace_id` occurrence in `lib/` is a response read | `setup_api.dart:215` `data['trace_id']?.toString() ?? data['request_id']?.toString()` — error-detail display, not request plumbing | ✅ |
| No `bff` literals in `lib/` | `grep -rni "bff" lib/` → zero hits | ✅ |
| Audit-literal inventory (E11) | `snaplink_admin_types.dart:310-312` (doc trio), `governance_tab.dart:30-31` (calls), `admin_live_events_tab.dart:167` (`'/api/v1/audit/events/${Uri.encodeComponent(id)}'`), `admin_operations_tab.dart:56` (`endpoint.path.startsWith('/api/v1/audit')` grouping prefix, not a call). No other hits | ✅ complete |
| Sink query surface (E12) | `../snaplink-audit-governance/internal/httpapi/server.go`: `listAdminActions` reads `tenant_id` at `:869` (platform only); `tenantFor` at `:901` reads `tenant_id` for platform tokens at `:903`, non-platform always scoped to `claims.TenantID`; `parseQuery` at `:910` binds `event_type`, `outcome`, `trace_id`, `cursor`, `page_size`, etc. (`TraceID: values.Get("trace_id")` in the `:927` return) — server semantics real and already implemented | ✅ (function at `:910`, binding at `:927`) |
| B6-1a AC-1 exact `limit`-only assertion (E14) | `b6-1a-lib-api-auditlogtab-server-read-spec.md:57` asserts `request.url.queryParameters['limit'] == '100'` with `[PROPOSED, conditional]` tenant_id/trace_id branch at `:60` — builder default must keep `{limit: '100'}` exact | ✅ |
| T-12 joint (E15) | `docs/campaigns/implementation-gate.md:56` console row: `T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据` (sink B1-5 `audit.event.read` already implemented) | ✅ |
| Test harness (E13) | `test/admin_governance_security_test.dart:12-32` `_api(routes)` (MockClient keyed by `request.url.path`, 404 default), `_caps(paths)` (GET endpoints), `_pump(tester, child)`; `group('GovernanceTab')` at `:80-171` with fixtures omitting `/api/v1/audit/*` (audit section renders 'not enabled', no audit request issued) | ✅ |
| No existing `AuditQuery` type | `grep -rn "AuditQuery" lib/ test/` → zero hits | ✅ |
| `test/audit_log_tab_test.dart` landed? | **absent** — B6-1a not yet merged; AC-5's "if landed" condition applies | ✅ |
| `MapEntry(key, '$value')` uniqueness | The `'$value'` stringification exists only at `governance_tab.dart:169`. Other `MapEntry` maps use `.toString()` (`tenant_branding_tab.dart:84`, `admin_operations_tab.dart:351`, `connection_contract.dart:70`) — unrelated; guard must target the exact `'$value'` literal | ✅ |

## 1. API changes

### 1.1 New file `lib/api/audit_query.dart` — pure Dart, zero Flutter imports (REQ-1)

Sits beside the other transport types under `lib/api/` (import convention `package:sso_admin/api/...`). VM-unit-testable, no widget harness.

```dart
/// Typed builder for audit read query parameters.
///
/// The only sanctioned way to construct query parameters for
/// `GET /api/v1/audit/events` and `GET /api/v1/audit/facets`
/// (documented trio: `snaplink_admin_types.dart:310-312`).
/// Field wire keys are grounded in `governance_tab.dart:404` helper text
/// and the sink `parseQuery` filter surface (`snaplink-audit-governance
/// internal/httpapi/server.go:910`).
class AuditQuery {
  final int? limit;         // wire key: 'limit'      — `'$limit'` coercion, identical to today's `'$value'`
  final String? tenantId;   // wire key: 'tenant_id'  — omitted unless non-empty after trim
  final String? traceId;    // wire key: 'trace_id'   — omitted unless non-empty after trim
  final String? cursor;     // wire key: 'cursor'     — omitted unless non-empty after trim
  final String? eventTypes; // wire key: 'event_type' — omitted unless non-empty after trim
  final String? outcome;    // wire key: 'outcome'    — omitted unless non-empty after trim

  const AuditQuery({
    this.limit,
    this.tenantId,
    this.traceId,
    this.cursor,
    this.eventTypes,
    this.outcome,
  });

  /// Parses the governance text-field content (a JSON object with the wire
  /// keys above). Values may be `int` (stringified, matching today's
  /// `'$value'` behavior) or `String` (trimmed). `null` values are treated
  /// as absent. Unknown keys and non-scalar values throw
  /// [AuditQueryParseException] — this is the fix for the unvalidated
  /// pass-through at `governance_tab.dart:169`.
  factory AuditQuery.fromJson(Map<String, dynamic> json) { ... }

  /// Serializes to the wire map. Order-insensitive; consumers must compare
  /// as maps. Default construction yields exactly `{'limit': '100'}`
  /// (or the caller's limit) — no `tenant_id`, no `trace_id`.
  Map<String, String> toQueryParameters() { ... }
}

/// Typed parse error carrying a human-readable message for the
/// governance tab's `_error` banner.
class AuditQueryParseException implements Exception {
  final String message;
  const AuditQueryParseException(this.message);
  @override
  String toString() => message;
}
```

**`fromJson` rules (pinned):**
1. Input `json` must be a `Map<String, dynamic>` (the tab's `_json` already guarantees this; the factory still guards).
2. Every key must be one of the six wire keys; anything else → `AuditQueryParseException('Audit query: unsupported key "X". Supported: limit, tenant_id, trace_id, cursor, event_type, outcome.')` — **no request is issued**.
3. Value typing per key:
   - `limit`: `int`, or `String` that parses via `int.tryParse` (else throw `'Audit query: limit must be an integer.'`); `null` → absent.
   - `tenant_id`, `trace_id`, `cursor`, `event_type`, `outcome`: `String` (trimmed), or `int` (coerced via `toString()`, matching today's `'$value'` wire behavior); `null` → absent; any other type (`bool`, `double`, `List`, `Map`) → `AuditQueryParseException('Audit query: key "K" must be a string or integer, got <type>.')`.
4. Presence/absence: a field serializes **iff** non-null and (for strings) non-empty after trim — same conditional-omit precedent as `break_glass_tab.dart:145` and `snaplink_admin_event_stream.dart:33-36`.

**`toQueryParameters` rules (pinned):** `limit` → `'$limit'` (identical to today's `'$value'` coercion); each string field contributes its trimmed value iff non-empty; empty map is legal (all-null construction).

### 1.2 `governance_tab.dart` — `_queryAudit` migrates through the builder (REQ-2)

Replace the `:167-169` block exactly:

```dart
  Future<void> _queryAudit() async {
    final query = _json(_auditQuery.text, 'Audit query');
    if (query == null) return;
    final AuditQuery auditQuery;
    try {
      auditQuery = AuditQuery.fromJson(query);
    } on AuditQueryParseException catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final parameters = auditQuery.toQueryParameters();
```

- `:175` `widget.api.get(_auditPath, query: parameters)` and the `:176-177` facets twin are **unchanged** — the identical map goes to both endpoints (REQ-2.2).
- The `MapEntry(key, '$value')` line `:169` is deleted. After this change, audit query parameters are constructed **only** via `AuditQuery`.
- The `_json` path (`:233-241`, `'Audit query must be a JSON object.'`) is untouched — malformed JSON keeps its existing error surface (F1).
- Helper text `:404` unchanged — `{"tenant_id":"acme","outcome":"failure","limit":100}` is accepted by the builder (all three keys in the REQ-1 set), keeping the advertised example valid (AC-1.4).
- Error strings stay plain English (matching the existing `'$label must be a JSON object.'` pattern, which is not `.localized`); the i18n-coverage scanner has no new key surface to cover (C7).
- No other UI behavior changes: section gate, `_loading`/`_error` lifecycle, `_safe` rendering, capabilities gate all untouched.

### 1.3 New file `test/audit_contract_guard_test.dart` — repo-wide contract guard (REQ-3)

One Dart test file, CI-native (no new infra), four assertions:

1. **Audit-path literal scan**: walk `lib/**/*.dart`, extract string literals containing `'/api/v1/audit'` (regex `'[^']*api/v1/audit[^']*'`), normalize each (`:id`/`{id}` → `{id}`), assert membership in `{/api/v1/audit/events, /api/v1/audit/facets, /api/v1/audit/events/{id}}` **or** the exact whitelisted grouping-prefix expression `endpoint.path.startsWith('/api/v1/audit')` (`admin_operations_tab.dart:56`, UI classification, not a request). Baseline inventory (§0 E11) is the starting allowlist.
2. **No-BFF-literal scan**: assert no string literal in `lib/` starts with `'/bff'` or contains `'/api/v1/bff'` — the BFF path stays `[PROPOSED]` in docs only (`audit-contract-batch-snaplink-console.md:9`), never coded.
3. **Catalog drift guard**: `SnaplinkAdminOperationCatalog.endpoints` (derived from the `routes` listing) contributes exactly the normalized trio for the `/api/v1/audit` prefix — no fourth audit path may enter the catalog.
4. **Raw-stringification source guard**: read `lib/screens/admin/governance_tab.dart`; assert the literal `MapEntry(key, '$value')` is absent (the `'$value'` form is unique to `:169` per §0; the `.toString()` MapEntry sites at `tenant_branding_tab.dart:84`, `admin_operations_tab.dart:351`, `connection_contract.dart:74` are unrelated and untouched).

### 1.4 No transport/portal/catalog changes

`SnaplinkAdminApi`, `portal_api.dart`, `SnaplinkAdminCapabilities`, `SnaplinkAdminOperationCatalog` (beyond the drift guard), `SnaplinkAdminApiError` — all untouched. The query-param branch of `get` already bypasses the cache (`:133-134`), which is correct for live audit reads; no change needed.

## 2. Compatibility constraints

| # | Constraint | Grounding / guarantee |
|---|---|---|
| C1 | **Wire equivalence for the default query**: entering `'{"limit": 100}'` (the current default, `:32`) yields exactly `{'limit': '100'}` on the wire — byte-identical to today | `'$limit'` coercion == today's `'$value'` for ints; AC-2.3 asserts `request.url.queryParameters` exactly `{'limit': '100'}` |
| C2 | **B6-1a AC-1 stays true**: default construction omits `tenant_id`/`trace_id`; they appear only when explicitly supplied | `b6-1a-lib-api-auditlogtab-server-read-spec.md:57/60`; AC-1.1, AC-2.3 |
| C3 | **No endpoint-surface change**: only the documented trio (`snaplink_admin_types.dart:310-312`) may be called; no BFF literals in `lib/` | AC-3 scan; `[PROPOSED]` boundary per `audit-contract-batch-snaplink-console.md:9` |
| C4 | **Backward-compatible input set**: every JSON value today's pass-through would send as an int or string scalar is still accepted (`int` → same string; `String` → trimmed) | `fromJson` rule 3; AC-1.4 |
| C5 | **Bounded behavior changes, all in the diagnostic field**: (a) unknown keys now rejected with a visible banner instead of being sent to the wire; (b) `bool`/`double`/`List`/`Map` values rejected (today they stringify via `'$value'`); (c) `null` values now omitted (today `'null'` reaches the wire — worse: sink `tenantFor` would scope to the literal `"null"` tenant for platform tokens); (d) whitespace-only strings omitted (precedent `snaplink_admin_event_stream.dart:33-36`). All four tighten, never loosen; the helper text `:404` already advertises only supported keys | REQ-1 semantics; F2-F6 |
| C6 | **Facets twin receives the identical map** — `_has('GET', _facetPath)` gate and call sites unchanged; no request is issued to any path outside the trio | REQ-2.2; AC-2.3 |
| C7 | **i18n parity**: new error strings are plain English like the existing `'$label must be a JSON object.'` (not `.localized`); no new localized key surface | `governance_tab.dart:233-241` pattern |
| C8 | **No new dependencies, no Flutter imports in the builder** — `AuditQuery` is pure Dart, VM-testable; test harness reuse (`_api`/`_caps`/`_pump` at `admin_governance_security_test.dart:12-32`) | AC-1, AC-2, AC-5 |
| C9 | **Existing tests unaffected**: `test/admin_governance_security_test.dart` group `:80-171` fixtures omit audit paths → capability gate keeps them passing; `test/api_paths_test.dart`, `test/snaplink_admin_api_test.dart` untouched | AC-5 |
| C10 | **Catalog stays the doc-derived trio** — any future audit path addition must be a deliberate doc+catalog+guard change | AC-3.3 |

## 3. Failure modes

| # | Failure | Trigger | Symptom / impact | Mitigation | Acceptance |
|---|---|---|---|---|---|
| F1 | Malformed JSON in the audit field | `_json` FormatException / non-map | `_error = 'Audit query must be a JSON object.'`, no request — **unchanged behavior** | existing `_json` surface `:233-241` kept verbatim | AC-2.3 (only valid inputs exercised) |
| F2 | Unknown JSON key (typo, e.g. `tenat_id`) | `AuditQuery.fromJson` unknown-key rule | typed banner listing the key + supported set; **no request issued** (previously the typo reached the wire and was silently ignored by the sink) | error message enumerates the six keys; helper text `:404` already advertises only valid keys | AC-1.5 |
| F3 | Wrong-typed value (`bool`/`double`/`List`/`Map`) | `fromJson` rule 3 | typed banner; no request | key-name + accepted-type message | AC-1.5 extension |
| F4 | `limit` as non-integer string (`"abc"`) | `fromJson` `limit` parse | typed banner; no request (today the sink would 400 `invalid limit` at `server.go:874-876` — failure moved client-side, strictly earlier) | `int.tryParse` + explicit message | AC-1.5 extension |
| F5 | Whitespace-only `tenant_id`/`trace_id` | trim rule | silent omission, request proceeds — **documented semantics, not an error**; sink scopes to token claim for non-platform (`server.go:903`) | presence/absence rule; AC-1.3 pins omission | AC-1.3 |
| F6 | `null` value in JSON (`"tenant_id": null`) | `fromJson` null rule | omitted (today: literal `tenant_id=null` on the wire, which the sink would treat as the string tenant `"null"` for platform tokens — a real latent bug fixed by omission) | null → absent rule | AC-1.1/AC-1.6 |
| F7 | Sink rejects a validly-typed filter (`cursor` format, `page_size` interplay) | server 4xx | existing `SnaplinkAdminApiError` banner (`_error`), request counted — unchanged surface | `_queryAudit` `on SnaplinkAdminApiError` at `:180-182` untouched | AC-5 |
| F8 | Auth failure on audit read | 401/403 from sink | `onUnauthorized` callback + error banner — unchanged transport behavior | `SnaplinkAdminApi` untouched | AC-5 |
| F9 | Reintroduction of raw stringification in `governance_tab.dart` | future edit re-adds `MapEntry(key, '$value')` | guard test fails CI | AC-3.4 source guard | AC-2.5 |
| F10 | New audit path literal added to `lib/` | future feature | guard test fails CI — by design; inventory must be updated deliberately (doc + catalog + guard allowlist together) | AC-3.1/3.3; whitelist is the E11 baseline | AC-3 |
| F11 | BFF path coded before B4-1 | future edit adds `'/bff'` literal | guard test fails CI; prevents inventing an interface that violates the `[PROPOSED]` boundary | AC-3.2 | AC-3 |
| F12 | Capability gate behavior | fixture without audit paths | 'not enabled' render, no audit request — unchanged (`governance_tab.dart:392-395`) | `_has` untouched | AC-2/AC-5 |
| F13 | Concurrent edits during flight | user edits field while request in flight | `_loading` disables the button and field (`:402`, `:412`) — unchanged; no torn state introduced | no change to lifecycle | AC-5 |

## 4. Migration steps (ordered; each step leaves the tree green)

1. **Add `lib/api/audit_query.dart`** (pure Dart class + exception, §1.1). Add `test/audit_query_test.dart` covering AC-1.1–1.6. Gate: `flutter test test/audit_query_test.dart` green; `flutter analyze` clean (new file, no imports).
2. **Migrate `_queryAudit`** (`governance_tab.dart:166-181`, §1.2): add `import 'package:sso_admin/api/audit_query.dart';`, replace the `:167-169` block with the fromJson/try-catch/toQueryParameters sequence, delete the `MapEntry` line. Gate: `flutter test test/admin_governance_security_test.dart` green (existing group `:80-171` must pass unchanged — fixtures omit audit paths, so the capability gate shields them); `flutter analyze` clean.
3. **Extend `test/admin_governance_security_test.dart`** with a new `group('GovernanceTab audit query')` reusing `_api`/`_caps`/`_pump` (AC-2): fixture `_caps(['/api/v1/audit/events', '/api/v1/audit/facets'])`; MockClient records `request.url.path` + `request.url.queryParameters` for every request, responds 200 `'{}'` on both audit paths; default-field tap asserts exact `{'limit': '100'}` on `/api/v1/audit/events`, identical map on `/api/v1/audit/facets`, no request to any other path, no param outside the REQ-1 key set; tenant-supplied variant asserts `{'limit': '100', 'tenant_id': 'acme'}`. Gate: new group green.
4. **Add `test/audit_contract_guard_test.dart`** (§1.3, AC-3): the four scans (path literals, BFF literals, catalog trio, `MapEntry(key, '$value')` absence). Gate: green against current tree — this *proves* the baseline inventory matches the E11 allowlist.
5. **Full-suite gate**: `flutter test` (all tests incl. `test/api_paths_test.dart`, `test/snaplink_admin_api_test.dart`, and `test/audit_log_tab_test.dart` **if** B6-1a has landed by then) + `flutter analyze` + `python quality.py` (if the repo gate is invoked). AC-5.
6. **Cross-repo drill (AC-4)**: against the verification stack of `../snaplink-audit-governance` — Leg 1 (sink, executable today): platform token `GET /api/v1/events?tenant_id=tenant-a` → every row `tenant_id == 'tenant-a'`; `GET /api/v1/events?trace_id=<T>` → every row `trace_id == <T>` (`server.go:910/927`); non-platform token → rows scoped to token claim (`server.go:903`). Leg 2 (console): AC-1/AC-2 round-trip. Leg 3 `[PROPOSED, blocked on B4-1/BFF]`: recorded as blocked, **not** faked client-side.
7. **Optional CI wiring**: the guard test is CI-native (Dart test); no `Makefile`/`checks/` change required. If a grep step is preferred, the exact patterns are `grep -n "MapEntry(key, '\$value')" lib/` (expect zero hits) and `grep -rni "bff" lib/` (expect zero hits).

## 5. Testable acceptance mapping

| Spec check | Test file / artifact | Concrete assertions (pinned) |
|---|---|---|
| AC-1.1 | `test/audit_query_test.dart` | `AuditQuery(limit: 100).toQueryParameters()` == `{'limit': '100'}`; **no** `tenant_id`/`trace_id` keys |
| AC-1.2 | same | `AuditQuery(tenantId: 'tenant-a', traceId: 'tr-1', limit: 100)` → `{'limit': '100', 'tenant_id': 'tenant-a', 'trace_id': 'tr-1'}` (map equality) |
| AC-1.3 | same | `tenantId: '  '` → omitted; `traceId: 'tr-1'` present (conditional-omit precedent) |
| AC-1.4 | same | `AuditQuery.fromJson({'limit': 100, 'tenant_id': 'acme', 'outcome': 'failure'})` round-trips to `{'limit': '100', 'tenant_id': 'acme', 'outcome': 'failure'}` — the `:404` helper-text example must work |
| AC-1.5 | same | `fromJson({'limit': 100, 'unknown_key': 'x'})` throws `AuditQueryParseException`; message lists the six supported keys; plus F3/F4 variants (bool value; `limit: 'abc'`) |
| AC-1.6 | same | `cursor`/`eventTypes` → `cursor`/`event_type` serialize when present, omitted when absent; `null` values omitted (F6) |
| AC-2.1–2.4 | `test/admin_governance_security_test.dart` new group | recorded `queryParameters` on `/api/v1/audit/events` exactly `{'limit': '100'}` for the default field; facets request carries the identical map; **no request to any other path**; no param outside the six-key set; `'{"limit": 100, "tenant_id": "acme"}'` → `{'limit': '100', 'tenant_id': 'acme'}` |
| AC-2.5 | `test/audit_contract_guard_test.dart` scan 4 | `MapEntry(key, '$value')` absent from `governance_tab.dart` |
| AC-3.1 | same, scan 1 | every `/api/v1/audit` literal in `lib/` normalizes into the trio (or is the exact whitelisted grouping-prefix expression) |
| AC-3.2 | same, scan 2 | zero `'/bff'`/`'/api/v1/bff'` literals in `lib/` |
| AC-3.3 | same, scan 3 | catalog contributes exactly the normalized trio for the audit prefix |
| AC-4 Leg 1 | `../snaplink-audit-governance` verification stack (executable today) | tenant-scoped and trace-echo rows per `server.go:903/910/927`; non-platform token cannot widen scope |
| AC-4 Leg 2 | AC-1/AC-2 tests | `AuditQuery(tenantId:…, traceId:…)` puts exactly those values on the wire, nothing else |
| AC-4 Leg 3 | recorded as blocked | `[PROPOSED]`, conditional on B4-1/BFF; never faked by a console fixture |
| AC-5 | full suite | `flutter test` green incl. `test/admin_governance_security_test.dart`, `test/api_paths_test.dart`, `test/snaplink_admin_api_test.dart` (+ `test/audit_log_tab_test.dart` if B6-1a landed); `flutter analyze` clean; `quality.py` gate if invoked |

## 6. Out of scope / risks

**Out of scope** (per spec §5, unchanged): B6-1a `AuditLogTab` wiring, B6-1b localStorage-ring demotion, B6-2 client_id alignment, BFF implementation/path definition in code, `trace_id` injection mechanism, token-claim `tenant_id` parsing (B4-1), sink-side changes (tenant-consistency 422, B1-5 self-audit — already implemented server-side), any typed audit response model (the tab keeps rendering raw JSON via `_safe`).

**Risks and mitigations** (spec §6 carried forward, plus design-level additions):
- **Typed-error banner is a UX change for a diagnostic field** → error text enumerates the supported keys (F2), bounded to the documented vocabulary; no request is half-sent.
- **Guard-test brittleness** → allowlist is the small stable E11 baseline; grouping-prefix expression whitelisted explicitly; only path-like literals scanned.
- **`null`/whitespace omission changes today's wire** → strictly tighter (F5/F6); the sink's own semantics (`tenantFor` non-platform override, `!= ""` checks) make the old literal-string behavior strictly worse; pinned by AC-1.1/1.3/1.6.
- **Leg-3 dependency on B4-1/BFF** → Legs 1-2 executable today against the real sink; Leg 3 recorded blocked, never faked (no-invented-interface rule).
- **Line drift** → this design re-verified every citation (§0); `parseQuery` is at `server.go:910` (spec said `:927` — the `trace_id` binding line); implementation reviews use §0 numbers.
