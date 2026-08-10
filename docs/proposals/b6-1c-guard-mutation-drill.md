# B6-1c — Mutation drill: corrected guard scans trip on every planted regression, green against the current tree

> Task: *"Against the revised guard design, plant each target regression — F6 skins (Map.from/.cast/.toString interception, literal tenant_id=null), {id} drop at admin_live_events_tab.dart:167, default {'limit':'100'} drift, parse-error-no-request, catalog-trio drift — and empirically confirm the corrected scans trip on each while staying green against the current tree (per-line token extraction for the routes blob at snaplink_admin_types.dart:124, bare /api/v1/audit anchor, positive pins for scan 4, unified case-insensitive bff semantics); report any residual escape routes."*
> Revised design = `docs/proposals/b6-1c-audit-contract-guard-review.md` §4 applied to the design's §1.3 four scans, plus two verified extensions (scan-4 default-text/parse-surface pins; scan 5 second-consumer land-check).

## 0. Execution environment (honest account)

This task ran in a shared checkout with concurrent campaign sessions. Three facts shaped the evidence:

1. **A parallel implement-stage session committed `b82d2cf` mid-flight** ("verify: B6-1c harness prototype baseline", 2026-08-06 18:14:11 AKDT), capturing the `AuditQuery` builder, the `governance_tab.dart` migration, `test/audit_query_test.dart`, the AC-2 harness group (`admin_governance_security_test.dart`), and `test/admin_live_events_detail_read_test.dart`. **That snapshot is incomplete standalone**: its committed `test/audit_contract_guard_test.dart` imports `audit_contract_guard_scans.dart`, which the commit did not include (it was untracked at commit time). The coherent state is the working tree: the shared scan implementation (`test/audit_contract_guard_scans.dart`) + the corrected guard test + the mutation drill.
2. **A sibling reviewer (harness verifier) planted `{"limit": 50}` into `governance_tab.dart` at 18:14:16** as its M1 default-drift mutation, then moved to an isolated worktree (`/tmp/b6-1c-verify`) after detecting the collision. The mutation was left in the main checkout. This report captured its trip evidence **while it was live** (sections 3.4/3.6), then restored the design default `{"limit": 100}` once the sibling finished (18:22:13).
3. All evidence below is observed `flutter test` output on the real tree (drill mutations applied, run, reverted via backup) or in-memory scan runs of the identical scan functions the CI guard uses.

## 1. The corrected scans (as implemented and drilled)

| Scan | Revised semantics (review §4 → implementation) |
|---|---|
| 1 audit-path literals | State-machine Dart literal tokenizer (both quote styles, raw strings, escapes, comments skipped). Triple-quoted literals yield **per-line path tokens** (`/api/v1/audit[^\s'"]*`) so the `routes` blob at `snaplink_admin_types.dart:124` normalizes line-by-line. Shared normalizer: `:id`/`{id}` → `{id}` and the codebase idiom `\$\{Uri\.encodeComponent\(<ident>\)\}` → `{id}` (never blanket `${…}`). Bare `/api/v1/audit` (no trailing slash) allowed as the `admin_operations_tab.dart:56` grouping anchor; trailing-slash and method-prefixed literals trip. |
| 2 BFF literals | **Unified semantics**: case-insensitive `bff` substring over whole-file text — the Dart-native equivalent of the step-7 `grep -rni "bff" lib/`; literals, case variants, identifiers, and comments trip identically. |
| 3 catalog trio | Runtime-derived from `SnaplinkAdminOperationCatalog.endpoints` (structurally drift-free — derives from the same `routes` const); pins exactly `GET` × the trio; shares scan-1's normalizer. |
| 4 raw stringification | **Lib-wide** whitespace-tolerant absence of `MapEntry(key, '$value')` (both quote styles, line breaks between tokens) **+ positive pins**: `governance_tab.dart` must keep the `audit_query.dart` import, `AuditQuery.fromJson(`, `.toQueryParameters()`, and the `'{"limit": 100}'` field text (C1 default wire); `audit_query.dart` must keep `AuditQueryParseException` + the F2/F4 rejection messages and must contain **no `'null'` string literal** (C5/F6). |
| 5 second-consumer land-check (extension) | Every lib file whose literals normalize to `/api/v1/audit/events` or `/api/v1/audit/facets` **and passes a `query:` argument** must reference `AuditQuery` — when B6-1a's `AuditLogTab` lands, a hand-built `query: {'limit': '$_limit'}` map trips; reuse of `AuditQuery` is green. The `query:` discriminator prevents a split `{id}`-detail literal from false-positiving. |

## 2. Baseline — green against the current tree (post-restore)

| Gate | Result |
|---|---|
| `flutter test test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/audit_query_test.dart` | **47/47 pass** |
| `flutter test test/admin_governance_security_test.dart test/admin_live_events_detail_read_test.dart` | **7/7 pass** |
| `flutter test` (full suite) | **722/722 pass** |
| `flutter analyze` | **No issues found** |
| `python3 cli.py harness` | **12 passed, 0 failures** |
| `python3 quality.py .` | 12 pre-existing violations, all in untouched Python files (`checks/`, `tests/integration/`, `tools/robust_proxy.py`) — none in this change |

## 3. Trip matrix — every planted regression caught (observed outcomes)

### 3.1 F6 skins (literal-level + pin-level)

| # | Planted regression (mutation) | Mechanism that tripped | Observed failure |
|---|---|---|---|
| 1 | `MapEntry(key, '$value')` re-added in `_queryAudit` (literal `tenant_id=null` bug) | scan 4 absence (lib-wide, whitespace-tolerant) | `[raw-stringification] screens/admin/governance_tab.dart: raw 'MapEntry(key, '$value')' stringification reintroduced (F6: JSON null becomes the literal wire string tenant_id=null for platform tokens)` |
| 2 | `Map<String, String>.from(query)` interception | scan 4 **positive pins** | `positive pin missing: AuditQuery.toQueryParameters usage (.toQueryParameters())` |
| 3 | `query.cast<String, String>()` interception | scan 4 positive pins | same pin violation |
| 4 | `query.map((k, v) => MapEntry(k, v.toString()))` interception | scan 4 positive pins | same pin violation |
| 5 | `tenantId == null → 'null'` literal coercion inside `toQueryParameters` | scan 4 `'null'`-literal ban (audit_query.dart) | `[raw-stringification] api/audit_query.dart: 'null' string literal present — an absent field may be serialized as the literal wire string null (C5/F6)` |

All five drilled both in-memory (permanent `test/audit_contract_guard_mutation_test.dart` rows) and, for 1–5, against the real files with backup/restore.

### 3.2 `{id}` drop at admin_live_events_tab.dart:167

| Planted mutation | Mechanism | Observed |
|---|---|---|
| `${Uri.encodeComponent(id)}` → `${id}` (encodeComponent dropped — injection skin) | scan 1 (the encodeComponent normalization rule does not match `${id}`) | `[audit-path-literals] screens/admin/admin_live_events_tab.dart: unexpected audit path token "/api/v1/audit/events/${id}" (normalizes to "/api/v1/audit/events/${id}")` |
| `/…/{id}` + `/details` segment appended | scan 1 | unexpected token, not in trio |
| Behavioral backstop (sibling's committed `admin_live_events_detail_read_test.dart`) | wire shape | id `ev 1/2` must appear as `ev%201%2F2`; dropping `encodeComponent` turns it into `ev%201/2` |

### 3.3 Catalog-trio drift

| Planted mutation | Mechanism | Observed |
|---|---|---|
| 4th audit route `GET /api/v1/audit/events/{id}/export` added to `routes` | scan 3 (runtime catalog) **and** scan 1 (per-line blob token extraction); `api_paths_test.dart` `hasLength(215)` as redundant third layer | `[catalog-trio] SnaplinkAdminOperationCatalog.endpoints: audit-prefixed endpoints {GET …} differ from the pinned trio` |
| Non-GET method on a trio path (`POST /api/v1/audit/events`) | scan 3 (method included in the pin) | trips |

### 3.4 Default `{'limit':'100'}` drift

The sibling reviewer's live plant (`'{"limit": 50}'` in the tree) was itself the real-tree experiment:

- **scan 4 default-text pin**: `[raw-stringification] screens/admin/governance_tab.dart: positive pin missing: default limit-100 field text (C1 wire) ({"limit": 100})`
- **AC-2 harness**: `Expected: {'limit': '100'} / Actual: {'limit': '50'}` on recorded `/api/v1/audit/events` queryParameters.

Both mechanisms trip; after the sibling finished, the design default was restored (file now equals HEAD).

### 3.5 Parse-error-no-request

| Planted mutation | Mechanism | Observed |
|---|---|---|
| Unknown-key throw removed from `fromJson` (lenient) | scan 4 **parse-surface pin** (`'Audit query: unsupported key'` message gone) **and** AC-2 harness zero-request pin | harness: `a rejected query must never reach the wire` (the `{"tenat_id":1}` typo issued events+facets requests) |

### 3.6 BFF (unified semantics)

| Planted mutation | Mechanism | Observed |
|---|---|---|
| `/api/v1/BFF/audit/events` (case variant — evaded the original case-sensitive scan) | scan 2 whole-file case-insensitive | `[bff-literals] screens/admin/governance_tab.dart: bff token near "...robe = '/api/v1/BFF/audit/events..."` |
| `bffClient` identifier, `// bff path` comment, lowercase `'/bff/…'` literal | scan 2 | all trip identically (drill rows) |

### 3.7 Second consumer (forward-looking, verified by sibling + drilled)

| Planted mutation | Mechanism | Observed |
|---|---|---|
| Simulated B6-1a `AuditLogTab` with `query: {'limit': '$_limit'}` map literal | scan 5 | `queries /api/v1/audit/events but never constructs parameters through AuditQuery` |

## 4. Residual escape routes (accepted, with backstops)

Each is a permanent probe row in `test/audit_contract_guard_mutation_test.dart` asserting the scans stay green, so the list cannot silently change:

| # | Evasion | Status | Backstop |
|---|---|---|---|
| R1 | Call to the bare `/api/v1/audit` (grouping anchor used as a call path) | accepted (review §1.1 FP-3 trade-off) | AC-2 harness: recorded path set must be exactly `{/api/v1/audit/events, /api/v1/audit/facets}` |
| R2 | Adjacent-literal split `'/api/v1/audit' '/events/…'` (bare token + non-audit fragment) | accepted (review FN-2) | none literal-level; note the mirror split `'/api/v1/audit/' 'events'` **does** trip (trailing slash) |
| R3 | Segment assembly `'$prefix/audit/events'` (prefix variable) | accepted (review FN-3) | mirror form `'$base/api/v1/audit/events'` trips loudly (safe direction) |
| R4 | Case-variant path literal `/API/V1/audit/events` | accepted (scan 1 detection is case-sensitive) | AC-2 no-other-path pin is exact-match; a case-variant request 404s |
| R5 | `bff` via concatenation `'/api/v1/' 'b' 'ff/audit'` | accepted (defeats both the guard and the step-7 grep — active circumvention) | none; documented |
| R6 | Split `{id}`-detail literal `'/api/v1/audit/events' + '/' + id` (runtime assembly) | accepted for scan 1 (each literal normalizes into the trio) | behavioral `admin_live_events_detail_read_test.dart` wire-shape pin (`%2F`); scan 5's `query:` discriminator deliberately does not flag it |
| R7 | Weakened `fromJson` that keeps the rejection messages but doesn't throw | scan 4 pin is message-presence-based | AC-2 zero-request harness pin |
| R8 | Triple-quoted literal introducing a new audit path *with* per-line tokens that are trio members in different lines | theoretical; per-line token extraction treats each line independently | scan 3 (runtime catalog) is the authoritative layer |
| R9 | Scan 6/6b negative-boundary spellings — `\u0061`/`\x61` escapes, adjacent-literal/concat splits (`'au' 'ditLog'`), interpolation fragmentation (`'${id}uditLog'`), line-split words, confusable glyphs (Cyrillic `а` U+0430 / fullwidth `ａ` U+FF41 / ZWJ U+200D) | accepted (deliberate circumvention — the contiguous ASCII `audit` substring is absent from raw source by construction; mirror of R2/R5 for scans 1/2/7) | none scan-level; code review is the gate (permanent probe row in the mutation drill) |

Closed holes (verified, not residual): second consumer (scan 5), default-text drift (scan 4 pin), `'null'`-coercion inside the builder (scan 4 ban), whitespace/line-broken `MapEntry` skins (scan 4 tolerance), double-quoted literals (both quote styles scanned), case-variant `bff` (scan 2 unified).

## 5. Files

- `test/audit_contract_guard_scans.dart` — shared scan implementation (scans 1–5), normalizer, tokenizer, violation model; lives under `test/` so the guard itself cannot introduce scannable literals into `lib/`.
- `test/audit_contract_guard_test.dart` — CI-native guard test (green against the tree; unit probes for each scan).
- `test/audit_contract_guard_mutation_test.dart` — permanent trip matrix: baseline-green assertion + 21 planted-regression rows + 9 documented-escape rows (all in-memory, no tree mutation).
- Committed baseline carried forward: `lib/api/audit_query.dart`, `governance_tab.dart` migration, `test/audit_query_test.dart`, AC-2 harness group, `test/admin_live_events_detail_read_test.dart` (lint fix: unnecessary import removed).

## 6. Caveats

1. Commit `b82d2cf` is an incomplete snapshot (guard test references the untracked scans file); the working tree is the coherent state and the next round commit captures it.
2. The default-text pin and parse-surface pins strengthen the review minimum (the sibling verifier's M1/M2 rows show the review-minimum guard passes on those); the AC-2 harness remains the authoritative wire-level layer for both.
3. `python3 quality.py .` reports 12 pre-existing Python violations unrelated to this change.
