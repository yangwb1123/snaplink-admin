# B6-1c — Review: `audit_contract_guard_test.dart` (4 scans) + harness coverage of audit paths

> Reviewed against: `docs/proposals/b6-1c-lib-screens-admin-audit-read-contract-design.md` (§1.3, §2 C9/C10, §3 F9-F12, §4 steps 3-5, §5 AC-3).
> Method: every scan was run against the current tree (regex empirically executed), and every harness claim re-verified against `test/` and `lib/`.

## 0. Verdict summary

| # | Claim being made | Verdict |
|---|---|---|
| V1 | Scan 1 (audit-path allowlist) is green on its own baseline | **False — fails its own baseline.** Empirically, 3 of 5 regex matches do not normalize into the trio. Migration step 4's "green against current tree" gate is unachievable as specified. |
| V2 | Scan 1's normalization (`:id`/`{id}` → `{id}`) covers the literal inventory | **Incomplete.** `admin_live_events_tab.dart:167` uses `${Uri.encodeComponent(id)}`; the rules as written never map it to `{id}`. |
| V3 | Scan 2 (BFF) matches the migration step-7 grep semantics | **Inconsistent.** Dart scan is case-sensitive and literals-only; grep is `-i` and whole-file. `'/BFF'`, `/api/v1/BFF/…`, identifiers, comments each evade one of the two mechanisms. |
| V4 | Scan 3 (catalog trio) is drift-safe | **Mostly yes** — runtime-derived, no line refs. But it is partly redundant with `api_paths_test.dart`'s `hasLength(215)` pin and does not cover `mergedWith` (server-advertised) additions; C10 overclaims. |
| V5 | Scan 4 (MapEntry absence) fails when raw stringification is reintroduced (F9) | **Only for the exact literal.** Absence-only → passes vacuously if `_queryAudit` is deleted or rewired via `.toString()`/`Map.from`/`.cast` — the F6 `tenant_id=null` bug has many syntactic skins. Scope (governance_tab only) also contradicts the step-7 lib-wide grep. |
| V6 | Harness gate narrative (E13/C9/F12): fixtures omitting audit paths → 'not enabled' render, no audit request | **Wrong mechanism.** `_has` (`governance_tab.dart:80-87`) has a catalog fallback; the trio is in `routes`, so `_has('GET', _auditPath)` is *unconditionally true* today. The audit query UI renders with empty `_caps`. Existing tests pass because nothing taps 'Query audit events' (zero hits in `test/`), not because of a gate. |
| V7 | Coverage: guard + harness fail on the regressions the design claims to prevent | **Insufficient.** Zero behavioral coverage of `_queryAudit` wire behavior; zero coverage of the trio's `{id}` member (`admin_live_events_tab.dart:167`); `audit_log_tab_test.dart` confirmed absent (B6-1a not landed: `audit_log_tab.dart:16`, `dashboard_screen.dart:566` still `const AuditLogTab()`). |

---

## 1. Scan-by-scan findings

### 1.1 Scan 1 — audit-path literal allowlist

**Empirical baseline run** (design's regex `'[^']*api/v1/audit[^']*'` over `lib/**/*.dart`):

| Match | File | Normalizes into trio? |
|---|---|---|
| `'\nGET /api/v1/admin/events/stream\nGET /api/v1/admin/authz/policy-bundle\n…'` (whole `routes` blob) | `snaplink_admin_types.dart:124` | **No → FP** |
| `'/api/v1/audit/events/${Uri.encodeComponent(id)}'` | `admin_live_events_tab.dart:167` | **No → FP** (`$` never normalized) |
| `'/api/v1/audit'` (bare) | `admin_operations_tab.dart:56` | Only via "exact grouping-prefix expression" whitelist → **formatting-brittle** |
| `'/api/v1/audit/events'`, `'/api/v1/audit/facets'` | `governance_tab.dart:30-31` | ✅ |

**FP-1 — the `routes` blob.** `const routes = '''…'''` at `snaplink_admin_types.dart:124` is one triple-quoted literal; the regex captures the entire blob (from the first `'` of `'''` to the first `'` of the closing `'''`), not the trio lines at `:310-312`. Any "normalize the matched literal" implementation fails on it. Fix: scan 1 must extract *path tokens* (`/api/v1/audit[^\s'"]*`) per line inside matches — or, cleaner, **skip triple-quoted literals in scan 1 entirely and let scan 3 own the catalog** (a call-site path is never triple-quoted; the trio lines are exactly what scan 3 validates). That decomposition also removes the only cross-scan ambiguity.

**FP-2 — `${…}` interpolation.** The design's normalization covers `:id`/`{id}` but not Dart interpolation. `admin_live_events_tab.dart:167` is a baseline member and must pass. Precise rule, grounded in codebase idiom (20+ sites, e.g. `sso_client.dart:158/177/183`): normalize `\$\{Uri\.encodeComponent\(<ident>\)\}` → `{id}`. Do **not** blanket-normalize any `${…}` → `{id}` — that would silently bless a genuinely new interpolated segment (`'/api/v1/audit/events/${featurePath}'`) as the `{id}` member.

**FP-3 — grouping-prefix whitelist is anchored to a formatting artifact.** "The exact whitelisted grouping-prefix expression `endpoint.path.startsWith('/api/v1/audit')`" breaks on any reformat (line wrap, spacing). Anchor instead on the *literal token*: allow bare `/api/v1/audit` (no trailing slash) as a prefix token — it is not a callable path, and the AC-2 "no request to any other path" assertion is the behavioral backstop. Optionally require same-line `startsWith(` context, but that reintroduces formatting sensitivity.

**FN-1 — quote styles.** The regex is single-quote-only. `prefer_single_quotes: true` (`analysis_options.yaml:73`) currently mitigates, but the guard then silently delegates enforcement to the linter; a double-quoted or `"""`/`'''` single-line literal is a valid-Dart evasion that only the lint catches. State this dependency explicitly, or match both quote styles (trivial to do).

**FN-2 — adjacent-literal concatenation.** `'/api/v1/audit/' 'events'` evades both guard and lint. Residual; document as accepted (it also defeats the lint, so it is an active circumvention, not an accident).

**FN-3 — interpolated segment assembly.** `'$prefix/audit/events'` evades; the mirror form `'$base/api/v1/audit/events'` trips loudly (FP direction — safe). Accept and document.

### 1.2 Scan 2 — BFF literals

- **Design-internal inconsistency.** Scan 2 (as specified) checks string literals, case-sensitively, for `'/bff'` prefix / `'/api/v1/bff'` substring. Migration step 7's canonical grep is `grep -rni "bff" lib/` — case-insensitive, whole-file (comments, identifiers, docs-in-code). `'/BFF'`, `/api/v1/BFF/events`, `bffClient`, `// bff path` all pass the Dart scan and fail the grep — two mechanisms, two contracts. Unify: lowercase-normalize literal contents and check the `bff` substring (semantics equal to the grep for literals), or drop the Dart scan and make the grep the CI step.
- **FN — concatenation** `'/api/v1/' 'bff'` evades both. Residual; document.
- Scope is correct: `docs/audit-contract-batch-snaplink-console.md:9` (`[PROPOSED]`) is docs, intentionally unscanned.

### 1.3 Scan 3 — catalog trio

- **Anchoring is sound**: derives from `SnaplinkAdminOperationCatalog.endpoints` at runtime; zero line references; and the "doc trio" at `snaplink_admin_types.dart:310-312` is literally inside the same `routes` const the catalog parses (`snaplink_admin_catalog.dart:10-12`) — doc and code **cannot** drift apart. This is the one structurally drift-free anchor in the design; say so explicitly.
- **Redundancy**: `test/api_paths_test.dart` already pins `hasLength(215)` + uniqueness + well-formedness; a fourth audit line in `routes` breaks that test too. Scan 3's marginal value is a precise failure message and survival of count-pin edits. Keep, but budget it as cheap insurance, not primary enforcement.
- **Scope gap**: `mergedWith(liveEndpoints)` (`snaplink_admin_catalog.dart:14+`) merges server-advertised endpoints; a fourth audit path advertised by the sink enters the merged list with scan 3 passing (static catalog only). The console doesn't call it, so this is acceptable — but C10's "any future audit path addition must be a deliberate doc+catalog+guard change" overclaims; add "server-advertised paths entering `mergedWith` are out of guard scope" to the doc.
- **Shared normalizer**: `{id}` normalization must be one helper shared by scans 1 and 3, so the two scans cannot drift from each other.

### 1.4 Scan 4 — `MapEntry(key, '$value')` absence

- **Vacuous pass (worst finding).** Absence-only: if `_queryAudit` is deleted, or rewired as `query.map((k, v) => MapEntry(k, v.toString()))` (wire-identical for `null` — reintroduces the F6 `tenant_id=null` literal-string bug for platform tokens), `Map<String, String>.from(query)`, `query.cast<String, String>()`, or a map literal — the guard passes and the regression the design says it prevents (F9) is live. Fix: add **positive pins** — `governance_tab.dart` must contain `AuditQuery.fromJson` and `toQueryParameters` (and the `audit_query.dart` import). Absence + presence fails on both removal and rewiring.
- **Exact-literal matching is whitespace-fragile**: `MapEntry( key, '$value')`, line-broken args, or `"$value"` (lint catches the latter) evade. Use a whitespace-tolerant regex (spaces/newlines between tokens) rather than a raw substring.
- **Scope inconsistency with step 7**: scan 4 reads only `governance_tab.dart`; the migration grep is `grep -n "MapEntry(key, '\$value')" lib/` — lib-wide. A second file reintroducing the pattern fails the grep but passes the guard. Make scan 4 lib-wide with the same tolerance; the E11 inventory says the pattern is unique today, so lib-wide is baseline-green.
- **Second-consumer hole (forward-looking)**: §1.2's "audit query parameters are constructed **only** via `AuditQuery`" is enforced for exactly one file. B6-1a's AC-1.5 (`b6-1a-lib-api-auditlogtab-server-read-spec.md:60`) explicitly contemplates `tenant_id`/`trace_id` on the wire; when `audit_log_tab_test.dart` lands, `AuditLogTab` can hand-build its query map with zero guard failure. Write the coordination into migration step 5: B6-1a must reuse `AuditQuery` (it is pure Dart, zero cost) or extend scan 4 at landing time. This is a `[PROPOSED]`-adjacent decision that must be made before, not after, the guard ships.

---

## 2. Drift-prone anchoring

- **The guard test itself is line-number-free as designed** — correct choice; keep it that way. The two prior drift incidents (E4: `:89-91` → `:126`; E12: `parseQuery` `:910`/`:927`) are *design-doc* drift, not test drift.
- **But the design's implementation instructions carry ~20 bare line refs** (`:166-181`, `:167-169`, `:175/177`, `:233-241`, `:392-396`, `:404`, `:12-32`, `:80-171`, `server.go:869/903/910/927`, `implementation-gate.md:56`). For the implementation ticket, convert block replacements to **symbol anchors** (`_queryAudit`'s `_json`/`map` block; `_has`; `_auditArea`) — those survive reformatting and merges. Keep line numbers only as "verified at write time" notes, which the design already does for §0 but not for §1.2/§3/§4.
- **The one line ref that is structurally safe**: the trio at `snaplink_admin_types.dart:310-312` — it lives inside the same `routes` const the catalog derives from, so doc/code drift is impossible (see 1.3). State that explicitly so reviewers stop re-verifying it.

---

## 3. Harness coverage — what the guard cannot fail on because no test observes it

### 3.1 The gate narrative is wrong (E13/C9/F12)

`_has` (`governance_tab.dart:80-87`) is: capability `has` **OR** normalized endpoint match **OR** `SnaplinkAdminOperationCatalog.endpoints` match. The trio is in `routes`, therefore:

- `_has('GET', _auditPath)` and `_has('GET', _facetPath)` are **unconditionally true** in the current tree — even with `_caps([])`.
- The audit section renders the query UI (TextField + button, `:396`), never 'Audit querying is not enabled' (`:392-395`) — unless `routes` loses the trio. No test asserts that string (verified: zero hits in `test/`).
- The existing group `:80-171` passes because **no test taps 'Query audit events'** (`'Query audit events'` has zero hits in `test/`), not because a capability gate shields the section. `_refresh` never touches audit because `governanceReadSpecs` (`governance_models.dart:36`, `_readCatalog`) contains no audit paths — a different mechanism than the one C9/F12 cite.

Consequences for migration step 3:
- The positive fixture `_caps(['/api/v1/audit/events', '/api/v1/audit/facets'])` is a **no-op** for enabling the UI (catalog fallback already enables it). The wire assertions still work, but the design's stated rationale is inverted.
- A "no capability → no audit request" negative test **cannot exist** for this tab without changing `_has` or `routes`. If the team wants the audit area genuinely capability-gated (B6-1a REQ-5's model), that is a behavior change this design should either own or explicitly defer — not silently describe as current behavior.
- Step 3's "MockClient records `request.url.path` + `request.url.queryParameters` for every request" **overclaims the helper**: `_api` (`admin_governance_security_test.dart:12-22`) routes by path and 404s by default but records nothing. The new group must add its own recording handlers. Feasible (path routing is query-agnostic), but the migration text should say so.

### 3.2 Missing harness assertions that the guard cannot provide

| Regression the design claims to prevent | Caught by guard? | Needed behavioral pin (today absent) |
|---|---|---|
| F2 unknown key / F3 wrong type → no request | No | Widget-level: enter `{"tenat_id":1}` → banner + **zero requests** (unit tests can't prove "no request is issued") |
| C1 default wire `{'limit':'100'}` exact | No | AC-2 group: recorded `queryParameters` equality on `/api/v1/audit/events` |
| C6 facets twin identity | No | AC-2 group: facets request count == 1 with the identical map (catalog-gated — works with any `_caps`) |
| F10 new call path | Scan 1 (after fixes) | "No request to any other path" assertion in AC-2 |
| Trio `{id}` member (`admin_live_events_tab.dart:167`) | Literal only — not the `Uri.encodeComponent(id)` usage | **Zero behavioral coverage today**: `AdminLiveEventsTab` group (`admin_secondary_tabs2_test.dart:312-322`) only tests fail-closed with `endpoints: const []`. Add: stream-advertised fixture → tap row → assert `request.url.path == '/api/v1/audit/events/<encoded-id>'` and dialog renders. Dropping `encodeComponent` (injection) or changing the path passes every existing test and every guard scan. |
| B6-1a AC-1 server read | Out of scope until landed | `test/audit_log_tab_test.dart` absent — confirmed B6-1a not landed (`audit_log_tab.dart:16` `const AuditLogTab({super.key})`; `dashboard_screen.dart:566` `page: const AuditLogTab()`; `admin_support_tabs_test.dart:62-163` covers only the localStorage ring). Land-check item: B6-1a must reuse `AuditQuery` or extend scan 4 (see 1.4). |

### 3.3 Bottom line on "fails on the regressions it claims to prevent"

- After the scan fixes: F10 (literal-level) and F11 trip reliably; F9 trips only in the exact syntactic skin unless the positive pins are added; F2/F3/F5/F6/F12 wire semantics are enforced **only** by the AC-2 harness group, which must therefore include the parse-error-no-request, default-map, facets-twin-count, and no-other-path assertions listed above.
- The `{id}` trio member and the B6-1a consumer have **no enforcement path at all** until the two harness additions (3.2 rows 5-6) are accepted.

---

## 4. Required changes (minimum set)

1. **Scan 1**: per-line path-token extraction; skip triple-quoted literals (scan 3 owns the catalog); normalize `\$\{Uri\.encodeComponent\(<ident>\)\}` → `{id}` (never blanket `${…}`); allow bare `/api/v1/audit` prefix token (drop the exact-expression whitelist); cover both quote styles or document the lint dependency; document accepted evasions (adjacent concat, segment assembly).
2. **Scan 2**: case-insensitive substring `bff` on literal contents — matching the step-7 grep's semantics; declare one mechanism canonical.
3. **Scan 3**: keep as-is; note redundancy with the `hasLength(215)` pin and the `mergedWith` scope boundary; share the normalizer with scan 1.
4. **Scan 4**: lib-wide, whitespace-tolerant; add positive pins (`AuditQuery.fromJson` + `toQueryParameters` + import in `governance_tab.dart`); record the B6-1a second-consumer extension in migration step 5.
5. **Migration step 3**: correct the gate narrative (3.1); add own recording handlers; add parse-error-no-request, default-map, facets-twin-count, no-other-path, and (documented) catalog-fallback UI assertions.
6. **New harness work**: `AdminLiveEventsTab` detail-read test (encoded `{id}` on the wire, dialog renders); B6-1a landing checklist item reusing `AuditQuery`.
7. **Anchoring**: keep the guard line-ref-free; convert design implementation instructions to symbol anchors; mark the trio-in-`routes` ref as structurally drift-free so it stops being re-verified.
