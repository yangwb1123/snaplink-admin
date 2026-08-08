# B6-1a — Design: convert `audit_log_tab.dart` to the server read (module: lib/screens/device)

> Durable repo copy of the design stage for the direction "close the audit read-client contract gap — the timeline tab (`lib/screens/admin/audit_log_tab.dart`) still renders the localStorage ring and is registered with no server client".
> Upstream: `docs/proposals/b6-1a-lib-screens-device-audit-read-client-gap-spec.md` (requirements, rev-1).
> Prior art (binding for tab internals where not contradicted here): `docs/proposals/b6-1a-lib-api-audit-read-client-design.md` §1.3 (tab rewire — superseded in §1.2 here by the spec's tenant/trace seam), §1.7 (i18n inventory — landed), §1.8 (line budget); `docs/proposals/b6-1a-validation-audit-events-response-shape.md` (real response shape).
> **This design's job is narrow:** everything the rewrite needs has landed (read client, row model, `AuditQuery`, guard suite, capability getter, dashboard wiring, i18n, B6-1b surface, 638-line widget suite). The tree is red because `audit_log_tab.dart` is the one unconverted piece. Four artifacts are still missing and are designed here: the AC-1 **present-branch** widget test (`tenantId`/`traceId` seam), the AC-4 drill **read leg**, and — closing the last unpinned failure modes (§3.1 adjudication) — three widget-level error-state tests pinning FM-2 (timeout), FM-3 (401) and FM-7 (malformed envelope) (§1.6C).

## 0. Evidence verification (claims re-checked at HEAD, 2026-08-08, before writing)

The evidence block was treated as untrusted and every citation was re-verified against the working tree. All substantive claims hold. Three deltas found at design time (D1–D3). The post-review amendments — drill_harness_reviewer **A1/A2** + **D4/D5**, test_plan_reviewer **D6/D7** — and the blocking B6-1b integration gap **D8** are folded into the affected sections (§1.4, §1.6B, §1.7, §2, §3, §4, §5); the amendment log at the end of this section maps each review item to its fold-in point.

| Evidence claim | Verified working-tree reality | Verdict |
|---|---|---|
| Gap is exactly one file: `audit_log_tab.dart` unconverted | `audit_log_tab.dart` (345 lines) still: `const AuditLogTab({super.key})` `:15-16`; `AuditLogService()` `:23`; `_refresh` reads `_logService.entries` `:43`; `_errorRate` `:129-131`; device-scoped subtitle `:158`; `delete_sweep` Clear `:177-192`; CSV `:93-125`; empty state `:242-250`. All other B6-1 pieces present (E-tables below). | ✅ |
| Tree fails to compile; "32 analyzer errors" | `flutter analyze` → **36** errors, all `undefined_named_parameter` for `api`/`capabilities` on `AuditLogTab`: `dashboard_screen.dart` ×2 (`:567`), `test/admin_support_tabs_test.dart` ×4 (`:114,:206`), `test/audit_log_tab_test.dart` ×30 (**15** call sites — D5 — × 2 params). `make analyze` = `flutter analyze`: 40 issues total = the 36 errors + 4 pre-existing `info` lints (`test/entry_ux_test.dart:252/:269/:287/:292`, `no_leading_underscores_for_local_identifiers`) — unrelated file, outside the 36. | ⚠️ **D1: 36, not 32** — count delta only; direction and sites confirmed |
| Read client landed | `lib/api/audit_read_client.dart` (88 lines): trio literals, `list()`/`facets()`/`event()`; wire exclusively via `AuditQuery`; optional `tenantId`/`traceId` ctor params, never derived/hardcoded. | ✅ |
| Row model landed | `lib/api/audit_event_row.dart` (197 lines): 7-field allowlist, redact-first, `is`-only, never-throws, count-preserving mapper. | ✅ |
| `AuditQuery.toQueryParameters` `:148-165`; default wire `{'limit':'100'}` | Exact at `audit_query.dart:148`; presence iff non-empty after trim; `limit` serialized as `'$limit'`. | ✅ |
| Guard suite (scan 5 second-consumer, trio-literal owner, bff ban) | `test/audit_contract_guard_scans.dart` (560 lines): scans `second-consumer` (`:226`), `bff-literals` (`:170`), `catalog-trio` (`:32`), trio-literal ownership; + `audit_contract_guard_test.dart` (362 lines), `audit_contract_guard_mutation_test.dart`. | ✅ |
| Dashboard wiring `dashboard_screen.dart:567`, gate `:559` | Exact: `if (navigation.supportsAuditLog)` `:559`, `page: AuditLogTab(api: _api, capabilities: capabilities)` `:567`. | ✅ |
| `supportsAuditLog` + nav culling | `admin_navigation.dart:148` (`_has('GET', AuditReadClient.eventsPath)`); nav culling pin in `admin_navigation_test.dart`. | ✅ |
| Server-sourced i18n (en+zh) landed | Subtitle `app_strings_source_admin_core.dart:61-62`; empty `app_strings_source_admin_features.dart:142`; `{n}% errors` core `:65`; not-enabled features `:92`; `Retry` common `:30`; `'All'` common `:11`; `'success'`/`'failure'` core `:63-64`; `'Search...'` common `:28`; CSV snackbar core `:108`; 5 B6-1b debug keys landed; anchored `subtitle:` scan in `test/i18n_coverage_test.dart:78-81` (FM-13 — D7 renumber). ⚠️ The coverage test itself is **red at HEAD**: zh-parity fails on 6 tab raw literals (baseline, fixed by the rewrite — see below). | ✅ + ⚠️ |
| B6-1b ring debug flag landed | `audit_log_service.dart:68-86`: `_ringCopyEnabled = kDebugMode` (const-folded), `ringCopyEnabled` getter, `@visibleForTesting debugRingEnabled` setter. | ✅ |
| 638 lines of timeline widget tests | `test/audit_log_tab_test.dart` exactly 638 lines; groups: server read AC-1/AC-3 (`:108`), FM-9 stale-response race (`:409`), B6-1b debug ring copy (`:480`). | ✅ |
| Drift: `audit_log_tab.dart:29-32` → `:23/:34-38` | `AuditLogService()` at `:23`; `initState`/`_refresh` at `:34-38`. | ✅ |
| Drift: REFUSAL-CHECK/`[PROPOSED]` at `audit-contract-batch-snaplink-console.md:1/:6/:9` | Confirmed at `:1` (`REFUSAL-CHECK: OK`), `:6` (portal_api `[PROPOSED]`), `:9` (tenant_id/trace_id `[PROPOSED]`). | ✅ |
| Trio routes `snaplink_admin_types.dart:310-312` | Exact: events `:310`, facets `:311`, events/{id} `:312`. | ✅ |
| `device_verify_api.dart` re-export shim (actual-path precedent) | **Precise form:** the shim is `lib/screens/device/device_verify_api.dart` (3-line `export`); `lib/api/device_verify_api.dart` is the real implementation. Precedent substance confirmed: actual client surface lives in `lib/api`, device module holds a pure shim. | ⚠️ **D2: shim is in `lib/screens/device/`, not `lib/api/`** — evidence phrasing ambiguous; spec E7 states it correctly |
| `_recordAudit` single writer `snaplink_admin_api.dart:81-85`, call `:324` | Exact: declaration `:81-85`; sole call `:324` inside non-GET 2xx branch. GET read path writes nothing. | ✅ |
| `implementation-gate.md:56` T-12 | `docs/campaigns/implementation-gate.md:56` console row 1: 读路径接入 (F-06), ring demoted, T-12 联合; sink-side emission B1-5 at `:47`. | ✅ |
| Zero audit surface in `portal_api.dart` | `grep -in audit` → 0 hits; only `/me`-family, notifications stream, `/logout`. | ✅ |
| Gap-spec artifact | The full spec is the 123-line `docs/proposals/b6-1a-lib-screens-device-audit-read-client-gap-spec.md`; `requirements.md` is a 21-line summary artifact, not load-bearing. | ⚠️ **D3** — evidence phrasing; the spec is authoritative |
| `audit_log_tab.dart` filesize exemption | **Already exempt:** the working-tree diff adds `- "lib/screens/admin/audit_log_tab.dart"` to `filesize.exemptions` in `engineering.yaml` (`:41`, alongside `governance_tab.dart`/`clients_tab.dart`); committed HEAD lacks it. | ⚠️ **D4** — §1.7/step-5 premise stale; exemption is present, step 5 is a no-op verification, **no `engineering.yaml` diff** |
| Tab call-site census | `grep -c "AuditLogTab(" test/audit_log_tab_test.dart` → **15** sites (not 16) — makes D1's 30 = 15×2 internally consistent; repo-wide 19 occurrences = 1 constructor definition + 18 call sites. | ⚠️ **D5** — 15 call sites |
| AC citations | AC-3a test at `:294` (cited `:289`), AC-3b `:313` (cited `:310`), AC-3c `:352` (cited `:334`), AC-4.1 `:374` (cited `:381`), AC-4.2 `:391` (cited `:400`); AC-1 body `:110`, AC-1.6 `:148`, zh `:164`, FM-9 `:409`, B6-1b group `:480` correct. | ⚠️ **D6** — citation drift; all cited tests exist, numbers only |
| FM-16 numbering | The FM table's FM-16 (search re-query storm, AC-1.6 `:148`) and §0/§1.5's "FM-16 anchored `subtitle:` scan" (`i18n_coverage_test.dart:78-81`) are **two different pins** sharing one number. | ⚠️ **D7** — split: FM-16 = search storm; the anchored subtitle scan belongs to FM-13 |
| B6-1b harness contract vs rewritten tab | `checks/b6_1b_gates.py` (wired at `cli.py:144` / `ci.yml:41`) pins `tab_kdebug_count: 1` (`checks/config.py:90`) — an **occurrence** count (`rg -o`) — plus `service_kdebug_count: 6` / `guard_line` ×4 / `_storageEnabled = kDebugMode` (post-seam values, intentionally red until the storage seam lands, W-1/W-2). Working-tree tab has **0** `kDebugMode`; design §1.4 as written ("render iff `ringCopyEnabled`") produces **0** → the landed gate stays red. | ⚠️ **D8 — blocking integration gap.** Resolution (§1.4): exactly **one** `kDebugMode` occurrence — the ring-copy gate `if (kDebugMode && AuditLogService.ringCopyEnabled)` — with a **plain** `import 'package:flutter/foundation.dart';` (`show kDebugMode` would be a second occurrence). Gate config untouched. |

Additional facts verified for the failure-mode and migration sections:

- **Transport:** `SnaplinkAdminApi.get` with `query:` never consults/populates `DataCache` (`snaplink_admin_api.dart:133-134`); GET is retried up to `maxRetries = 3` with exponential backoff (`:307,:330`); 401 fires `onUnauthorized` (`:336`); non-2xx → `SnaplinkAdminApiError` via `snaplinkAdminError` (`snaplink_admin_error.dart:62-77`; `description = error_description ?? message ?? detail`; `toString()` at `:44` excludes `data`).
- **Governance precedent:** `GovernanceTab` ctor `governance_tab.dart:18-33` (`required api`, `required capabilities`, `const`); `_queryAudit` routes through `AuditReadClient.eventsPath` + `AuditQuery` — the pattern the tab must mirror.
- **Line budget (D4):** `engineering.yaml:11` `max_lines: 400`; `audit_log_tab.dart` **already exempt** (`engineering.yaml:41`, working-tree diff; committed HEAD lacks it). Budget check cannot fail for this file; §1.7 collapses to verification — **no `engineering.yaml` diff**.
- **B6-1b harness surface (landed):** `checks/b6_1b_gates.py` + `checks/config.py` `B61bGatesConfig`: old-key needles (en ×3 / zh ×3), new-key uniqueness, service seam pins (`guard_line` ×4, `_storageEnabled = kDebugMode`, `service_kdebug_count: 6` — post-seam, red until the storage seam lands, W-1/W-2), `_ringCopyEnabled = kDebugMode` initializer (green), **`tab_kdebug_count: 1`** (occurrence count via `rg -o`; **red today — found 0**), `sso_audit_log` residence, mask ban, recursive `build/web` artifact scan (stale pre-seam bundle: `sso_audit_log` ×2). Empirical baseline: 19 passed / 6 failures; 2 in B6-1a scope (old-en needles found 4 — the tab's raw literals; tab kDebugMode 0), 4 in B6-1b scope (service guard 1≠4, storage initializer 0≠1, service kDebugMode 2≠6, stale artifact ×2).
- **i18n baseline red:** `test/i18n_coverage_test.dart` fails at HEAD on exactly **6** raw literals in `audit_log_tab.dart` — `'All methods'`, `'Modify'`, `'No audit entries yet. Operations will appear here.'`, `'Clear log'`, `'Search by path, label...'`, `'Clear audit log?'` (zh-parity test `:116`). The old `'…on this device.'` subtitle is *not* in the flagged set (zh pattern-matched) but is replaced by the landed key anyway. All 6 are removed by the rewrite (§1.3/§1.4).
- **Drill:** `tests/integration/audit_login_drill.py` currently has only the `auth.login.success` leg (B6-2) with the `proposed`-flag deviation pattern (`:159-190`, `[proposed]` markers, `[RESOLVED]` note idiom at `:210`); invoked at `tests/integration/run_all.py:169` and `tests/integration/full_stack_verify.py:113` — **both already invoke the drill; no wiring change needed, only a new leg inside the drill**.
- **AC-1 present-branch test does not exist** (`grep tenantId|traceId test/audit_log_tab_test.dart` → 0 hits) — it is the mandatory addition (§1.6).
- **Drill read leg does not exist** (`grep audit.event.read audit_login_drill.py` → 0 hits) — it is the second addition (§1.6).

### Amendment log (post-review fold-in, 2026-08-08)

| ID | Source | Folded into | Status |
|---|---|---|---|
| A1 | drill_harness_reviewer | §4 step 1 — record pre-existing harness reds (filesize ×11, directory-fanout ×1, b6_1b ×6) **and** the `i18n_coverage_test.dart` baseline red (6 literals) | folded |
| A2 | drill_harness_reviewer | §4 step 7 — re-scoped to "zero **new** violations + step-1 reds documented" (absolute harness green is unsatisfiable: the storage-seam pins are a sibling deliverable) | folded |
| D4 | drill_harness_reviewer | §1.7, §2, §3 FM-14, §4 step 5 — `audit_log_tab.dart` already exempt; exemption rule → verification-only, no diff | folded |
| D5 | drill_harness_reviewer | §0 (table above), §1.1, §2 — **15** call sites (30 = 15×2) | folded |
| D6 | test_plan_reviewer | §0 (table above), §3, §5 — AC-3a `:294`, AC-3b `:313`, AC-3c `:352`, AC-4.1 `:374`, AC-4.2 `:391` (FM-1 already carried `:313`) | folded |
| D7 | test_plan_reviewer | §1.5, §3 FM-13/FM-16 — subtitle scan → FM-13; FM-16 = search storm only | folded |
| D8 | blocking integration gap (test_plan_reviewer's D5 finding) | §1.4, §2, §3 FM-9, §4 steps 1/6/7 — single `kDebugMode` gate + plain `foundation.dart` import; `tab_kdebug_count: 1` satisfiable, gate config untouched | resolved |

## 1. API changes

### 1.1 `lib/screens/admin/audit_log_tab.dart` — constructor (REQ-1, REQ-2)

Breaking change, `GovernanceTab` shape + the tenant/trace forwarding seam:

```dart
class AuditLogTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  /// Optional tenant/trace context, forwarded verbatim into
  /// [AuditReadClient]. Never derived, never hardcoded, never defaulted —
  /// B4-1 claim parsing / BFF trace_id injection are [PROPOSED] and out of
  /// scope; when absent the wire stays exactly {'limit':'100'} (AC-1).
  final String? tenantId;
  final String? traceId;

  const AuditLogTab({
    super.key,
    required this.api,
    required this.capabilities,
    this.tenantId,
    this.traceId,
  });
  ...
}
```

- `const` with required params — same as `GovernanceTab` (const-compatible: both fields are final).
- **Compatibility:** every existing producer already uses this shape (D1 sites); the change turns 36 red errors green with zero call-site edits. No other producer exists in `lib/` or `test/` (grep-confirmed).
- The tab must **not** construct its own API client, capability set, or `AuditLogService` for the timeline.
- **New imports (exact, both load-bearing):** `import 'package:sso_admin/api/snaplink_admin_api.dart';` (exports `SnaplinkAdminApi` + `SnaplinkAdminCapabilities` — `governance_tab.dart` precedent) and **plain** `import 'package:flutter/foundation.dart';` for `kDebugMode` — **not** `show kDebugMode` (D8: the harness counts `kDebugMode` *occurrences* (`rg -o`), so the import line would be a second occurrence and fail `tab_kdebug_count: 1`; verified empirically). `flutter/material.dart` does not export `kDebugMode` (SDK-verified), so the import is mandatory.

### 1.2 State model + read flow (REQ-1, REQ-4, REQ-5)

Supersedes prior-art §1.3 state model by adding the tenant/trace seam and dropping the `skipCache()` call (deviation noted below):

```dart
late final AuditReadClient _client;   // = AuditReadClient(widget.api,
                                      //   tenantId: widget.tenantId, traceId: widget.traceId)
List<AuditEventRow> _rows = [];       // server truth; raw response never retained
List<AuditEventRow> _displayed = [];  // client-side filtered/sorted view
bool _loading = false;
String? _error;                       // error.toString() only — never error.data
bool _notEnabled = false;
int _generation = 0;                  // FM-9 stale-response guard
String _outcomeFilter = 'ALL';        // 'ALL' | 'success' | 'failure'
```

**`_refresh()` flow** (from `initState` and every user-initiated refresh — refresh button, retry, search `onChanged`, outcome filter change):

1. **Gate first:** `if (!widget.capabilities.has('GET', AuditReadClient.eventsPath))` → `_notEnabled = true`, `_rows = []`, **return without issuing any request** (AC-4.1 zero-request pin). Consults the injected `SnaplinkAdminCapabilities` directly — deliberately **no** copy of governance's catalog fallback (`governance_tab.dart:85-91`; REQ-4's one documented deviation; dashboard hands the tab the merged view, so production behavior is unchanged — only the hiding clause becomes testable).
2. `_loading = true`, `_error = null`, capture `final gen = ++_generation`.
3. `final rows = await _client.list(limit: 100);` — the **sole** sanctioned path (scan-5 green by construction: no audit literal, no hand-built `query:` map in this file; trio literals stay owned by `AuditReadClient`).
4. `if (!mounted || gen != _generation) return;` — commit `_rows = rows`, recompute `_displayed` (filter + sort), `_loading = false`.
5. `on SnaplinkAdminApiError catch (error)` → same guard → `_error = error.toString()` (`SnaplinkAdminApiError.toString()` excludes `data` by construction — AC-3b's op-1/secret bait never surfaces). `on TimeoutException catch` / catch-all → same error state with `e.toString()` (dynamic data; never `LocalizedText`-wrapped, prior-art C11/FM-12). `finally` clears `_loading` under the same guard.

**Deviation from prior-art §1.3, with rationale:** the prior design called `widget.api.skipCache()` before the fetch; **this design omits it.** Verified: `SnaplinkAdminApi.get(path, query: q)` with a non-null query returns `_request(...)` directly (`snaplink_admin_api.dart:133-134`) — the cache is never consulted or populated on this path, so `skipCache()` is a no-op here. Smaller diff, spec §REQ-1 flow does not include it, and AC-1.6's "search re-queries with the identical exact query" is cache-independent (MockClient passthrough). If the cache behavior ever changes, this note is the place to re-add it.

### 1.3 Derived UI (server response only, REQ-1/REQ-3)

- **Header count:** `LocalizedText('{count} entries', args: {'count': _rows.length})` — page length, **never** the response `count` field (decoy-999 pin) and never the ring count.
- **Error-rate badge:** `'{n}% errors'` via `context.tr` (`app_strings_source_admin_core.dart:65`), rate = `outcome == 'failure'` rows ÷ total — AC-3a pins `50% errors` for 1-of-2.
- **Subtitle:** landed key `'All authentication and administrative events recorded by the server.'` (`admin_core:61-62`) — replaces `'...on this device.'`.
- **Empty state:** `_rows.isEmpty && !_loading && _error == null && !_notEnabled` → landed key `'No audit events returned by the server yet.'` (`admin_features:142`).
- **Not-enabled state:** breadcrumb + landed key `'This feature is not enabled on the connected replica.'` (`admin_features:92`); search/filter/table not rendered; zero requests.
- **Error state:** `_error` text + `'Retry'` button (`common:30`) that re-invokes `_refresh()` — re-enters the gate, never a raw fetch.
- **Search** (`hintText: 'Search...'`, `common:28`): `onChanged` re-invokes `_refresh()` (fresh page, then filter — AC-1.6 pins exactly one extra request with the identical `{'limit':'100'}` query), then client-side case-insensitive match over `type`/`outcome`/`actorId`/`clientId`/`tenantId`/`id`. Never contributes query parameters.
- **Outcome filter** replaces the ring-vocabulary METHOD dropdown: `DropdownButton<String>` with `LocalizedText('All')` / `LocalizedText('success')` / `LocalizedText('failure')` (lowercase keys, `admin_core:63-64`; values stay raw `'ALL'|'success'|'failure'`); change re-invokes `_refresh()` and filters `_displayed` by `outcome`.
- **Table columns:** TIME (`timestamp`, `--` when null, sorts last), EVENT (`type`), OUTCOME (`StatusChip`, `-` when `''`), ACTOR (`actorId`, `-` when empty), TENANT (`tenantId`, `-` when empty). Sortable over timestamp/type/outcome. Headers raw (TIME/EVENT/OUTCOME/ACTOR/TENANT — machine labels, no zh, prior-art §1.7 deliberate non-items).
- **CSV export:** operates on `_displayed`; header `timestamp,type,outcome,id,actor_id,client_id,tenant_id` (machine format, no zh); hardened `_csvCell` (CR/LF normalization first, quote doubling, OWASP `= + - @ \t \r` + unicode-lookalike prefix set, always-quote); null timestamps export `--` (no `toUtc()` throw); snackbar `LocalizedText('Exported {n} entries as CSV to clipboard', args: {'n': _displayed.length})` (exact-key args path — zh test pins `已将 2 条记录以 CSV 导出到剪贴板`).
- **Refresh button:** `onPressed: _loading ? null : _refresh` (FM-9 test relies on the disabled-while-loading behavior).

### 1.4 B6-1b debug ring surface (consume the landed surface, REQ-5) — D8 gate form

The destructive Clear action becomes the landed debug-only surface — **never** a release-reachable destructive action on server truth. **Gate form (D8 — the blocking integration gap, resolved):** the surface renders under exactly **one** `kDebugMode` occurrence in this file:

```dart
// The tab's ONLY kDebugMode reference. Landed B6-1b harness pin
// `tab_kdebug_count: 1` (checks/config.py:90) is an OCCURRENCE count
// (rg -o) — one gate, one occurrence; the plain foundation import
// contributes none (a `show kDebugMode` import would be a second).
if (kDebugMode && AuditLogService.ringCopyEnabled) ...[
```

- **Why both operands** (mirrors the landed B6-1b writer-gate form, `b6-1b-lib-screens-admin-ring-debug-flag-design.md` D1): (1) release-bundle elimination is structural — `kDebugMode` is a per-build const, `false && _` const-folds marker + Clear action + dialog out of the release artifact; (2) runtime behavior is identical to flag-only gating in every mode: debug `kDebugMode` = true → the landed `ringCopyEnabled` flag rules, so the B6-1b tests' `debugRingEnabled` flips (`audit_log_tab_test.dart:481/:525-526/:577-578`) keep working and the 2a/2c flag-off pins stay satisfiable; release → `kDebugMode` = false → absent. A `kDebugMode`-only gate would break 2a/2c (flag flips inert in debug); a flag-only gate leaves 0 occurrences and keeps the harness pin red.
- Surface body (unchanged from the pre-amendment design): render marker `'Debug records'` + `LocalizedText('Debug records: {n} entries', args: {'n': AuditLogService().count})` — ring count only (B6-1b 2a/AC-3 joint pins ring=1 vs server rows and decoy 999 pairwise) — and `Icons.delete_sweep` action: `ConfirmDialog` with `'Clear local debug records?'` / `'This will permanently delete all {n} local debug records.'` / confirm `'Clear local debug records'` (n = ring count), on confirm `_logService.clear()` then `_refresh()` (server re-fetch; server rows untouched — 2b pin).
- Flag off → no marker, no `delete_sweep` icon (2a/2c pins — via the flag operand; `kDebugMode` is true in tests).
- **Ring read isolation:** the tab's only `AuditLogService` references are `ringCopyEnabled` (static), `.count`, and `.clear()` — **no `.entries` read anywhere** (AC-2 grep floor). No `LocalStorage`/`sso_audit_log` access in the file.

### 1.5 i18n — zero new keys (consume verbatim)

All strings this rewrite needs already exist with en+zh (verified in §0). The rewrite replaces raw literals with the landed keys; **no key additions, no catalog edits**. Table headers and CSV header remain deliberate non-items (machine format). The anchored `subtitle:` scan (`i18n_coverage_test.dart:78-81`, **FM-13** — D7 renumber) is already in place and covers the new subtitle literal; the same file's zh-parity test is currently red on the tab's 6 raw literals and goes green with this rewrite (§0 baseline).

### 1.6 The net-new artifacts (this direction's new code)

**A. AC-1 present-branch widget test** — add to `test/audit_log_tab_test.dart` (group "AuditLogTab server read (AC-1 / AC-3)"):

```dart
testWidgets('present-branch: injected tenantId/traceId ride the wire (REQ-2)', ...);
// pump AuditLogTab(api: api, capabilities: caps, tenantId: 'acme', traceId: 'tr-1')
// expect: exactly one request, path '/api/v1/audit/events';
//   query == {'limit':'100','tenant_id':'acme','trace_id':'tr-1'};
//   rows from the mock body; no forged text; no /facets and no /events/{id} requests.
```

Mirrors the absent-branch test (`:110`) 1:1 with the two injected values; exercises `AuditQuery` serialization end-to-end from the timeline. Also assert the trim semantics corner in the same test or a sibling: whitespace-padded values are trimmed by `AuditQuery` (documented behavior, `audit_query.dart`).

**B. AC-4 drill read leg** — add to `tests/integration/audit_login_drill.py` as new Step 6, inserted after the no-duplicates step; the report block renumbers to **Step 7** and its `[RESOLVED]` note extends to "steps 4-6" (amended). The file is already invoked from `run_all.py:169` and `full_stack_verify.py:113` — **no wiring change, zero bytes of either harness** (success iff rc==0; PASS / `[proposed]` / SKIP all exit 0 — the no-false-PASS guarantee lives inside the drill's own PASS counter + deviation print). **Hygiene pin (drill_harness_reviewer A3):** the leg reuses the existing `curl` / `settle_seconds` / `check` helpers and adds a one-line `read_events(token, tenant_id)` mirror of `sink_rows` minus the `event_types=` filter — no duplicated fingerprint/complexity for the harness scans of `tests/integration/*.py`:

```
【6. T-12 joint: console-shaped read triggers the caller's own audit.event.read】
1. If token and tenant_id (JWT claims, :146-148): issue the console-shaped query
   GET {API}/api/v1/audit/events?tenant_id=<t>&limit=100
   (limit serialized as a string, matching AuditQuery's '$limit' wire).
2. settle (SNAPLINK_DRILL_SETTLE_SECONDS, existing helper), re-query via read_events.
3. Assert a caller-attributed audit.event.read row in the re-query rows — P4
   load-bearing pin: (a) canonical type match for the sink's read event (exact
   match on the sink's documented vocabulary, never a bare substring) AND
   (b) actor == caller identity (JWT sub / drill client identity) — a concurrent
   same-tenant read cannot decoy a PASS (the token is fresh and singly held).
4. Row observed → check(...) pass. Unobserved → mark the leg [proposed],
   print the deviation, exit 0 — mirror of the existing `proposed`-flag pattern
   (:159-190): NO false PASS until B1-5 lands (sink-side emission is B1-5,
   implementation-gate.md:47; the tab path stays pinned by AC-1/AC-2/AC-3 widget
   tests + guard greps, which go red independently).
5. No token/tenant_id → [proposed] deviation branch, same as the existing Step 4.
```

**FM-15 path-by-path outcome contract (exhaustive, amended):** P1 no token/tenant → `[proposed]` (mirror `:173-176`); P2 unverifiable response (non-JSON / 4xx/5xx / timeout) → `[proposed]` (mirror `:161-166`); P3 verifiable, B1-5 absent → no read row → `[proposed]` (documented deviation — §0 REFUSAL-CHECK/`[PROPOSED]` idiom); P4 row present but wrong actor/type → must NOT pass (attribution + canonical-type pins above); P5 ordering bug (assert on the first response) → self-audit row is written *after* the triggering query → provably absent → `[proposed]` (fail-safe by construction); P6 malformed envelope → AttributeError → traceback → rc 1 (noisy red, same as `sink_rows`); tab-still-ring-served → curl cannot reach browser localStorage and the ring cannot inject rows into `{API}/api/v1/audit/events` responses → impossible. **No path false-PASSes.**

**C. FM-2 / FM-3 / FM-7 widget-level error-state pins** — add to `test/audit_log_tab_test.dart` as a new group `'FM-2 / FM-3 / FM-7 error-state variants'`, inserted between the AC group close (current `:407`) and the FM-9 group (current `:409`). Target landing lines (file grows +135; the landed file is authoritative — per the D6 citation-drift lesson, the assertion pins, not the line numbers, are the contract): group open `:409`, FM-2 `:410-454`, FM-3 `:455-507`, FM-7 `:508-542`, group close `:543`; the FM-9 group shifts `:409 → :544`, B6-1b `:480 → :615`, EOF `638 → 773`. Each mirrors a landed pattern 1:1 (held-completer: FM-9 `:409`; error-state asserts: AC-3b `:313`; empty-state asserts: AC-3c `:352`). See §3.1 for the scope adjudication.

```dart
    testWidgets(
      'FM-2: transport timeout after retries → same error state, '
      'no ring fallback',
      (tester) async {
        _seedForgedRing();
        final held = Completer<http.Response>();
        final api = SnaplinkAdminApi(
          baseUrl: 'https://sso.example.test',
          accessToken: 'admin-token',
          httpClient: MockClient((request) => held.future),
        );
        tester.view.physicalSize = const Size(1200, 2200);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuditLogTab(
                api: api,
                capabilities: _caps(['/api/v1/audit/events']),
              ),
            ),
          ),
        );
        // Explicit pump only — never pumpAndSettle while a request is
        // held (FM-9 idiom, :409).
        await tester.pump();
        held.completeError(TimeoutException('Timed out'));
        // Load-bearing: the transport retries the GET 3× (1000ms, then
        // 2000ms backoff — pow(2, attempt) * 500, snaplink_admin_api.dart
        // :298/:339) before the raw TimeoutException reaches the tab's
        // `on TimeoutException` branch. pumpAndSettle alone cannot advance
        // a Future.delayed timer that has not scheduled a frame — advance
        // the fake clock explicitly past both delays.
        await tester.pump(const Duration(milliseconds: 1100));
        await tester.pump(const Duration(milliseconds: 2100));
        await tester.pumpAndSettle();
        // Same error state as AC-3b — and never a ring fallback.
        expect(find.text('Retry'), findsOneWidget);
        expect(find.textContaining('Timed out'), findsOneWidget);
        expect(find.textContaining('admin_client_created'), findsNothing);
        expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
        expect(find.textContaining('forged entry'), findsNothing);
      },
    );

    testWidgets(
      'FM-3: server 401 → description in the same error state; the '
      'session hook still fires',
      (tester) async {
        _seedForgedRing();
        var unauthorizedFired = false;
        final requests = <Uri>[];
        final api = SnaplinkAdminApi(
          baseUrl: 'https://sso.example.test',
          accessToken: 'admin-token',
          onUnauthorized: () => unauthorizedFired = true,
          httpClient: MockClient((request) async {
            requests.add(request.url);
            return http.Response(
              jsonEncode({
                'error': 'unauthorized',
                'message': 'Session expired. Please sign in again.',
              }),
              401,
            );
          }),
        );
        await _pump(
          tester,
          AuditLogTab(
            api: api,
            capabilities: _caps(['/api/v1/audit/events']),
          ),
        );

        // The transport hook fires through the tab's read path — never
        // swallowed or reimplemented by the tab.
        expect(unauthorizedFired, isTrue);
        // The 401 description renders via the shared error state;
        // error.code ('unauthorized') is never the rendered text
        // (SnaplinkAdminApiError.toString() = description ?? code ?? …).
        expect(
          find.text('Session expired. Please sign in again.'),
          findsOneWidget,
        );
        expect(find.textContaining('unauthorized'), findsNothing);
        expect(find.text('Retry'), findsOneWidget);
        expect(find.textContaining('admin_client_created'), findsNothing);
        expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
        expect(find.textContaining('forged entry'), findsNothing);
        // Retry re-enters the gate and issues a fresh request after a 401.
        final before = requests.length;
        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();
        expect(requests.length, greaterThan(before));
      },
    );

    testWidgets(
      'FM-7: malformed envelope → server-truth empty state, no crash, '
      'no fabricated rows',
      (tester) async {
        _seedForgedRing();
        final api = _api({
          '/api/v1/audit/events': (_) => http.Response(
            '{"events": {"id": "not-a-list"}, "count": 999}',
            200,
          ),
        });
        await _pump(
          tester,
          AuditLogTab(
            api: api,
            capabilities: _caps(['/api/v1/audit/events']),
          ),
        );

        // Wrong-typed `events` maps to zero rows (mapper never throws,
        // audit_event_row.dart:50-62) — the widget shows the server-truth
        // empty state, NOT the error state: no Retry, no crash, and the
        // decoy count 999 / forged ring never render.
        expect(find.text('0 entries'), findsOneWidget);
        expect(
          find.text('No audit events returned by the server yet.'),
          findsOneWidget,
        );
        expect(find.text('Retry'), findsNothing);
        expect(find.textContaining('999'), findsNothing);
        expect(find.textContaining('/api/v1/admin/forged'), findsNothing);
        expect(find.textContaining('forged entry'), findsNothing);
      },
    );
```

### 1.7 `engineering.yaml` — line budget (D4: already exempt — verification-only)

`max_lines: 400` (`engineering.yaml:11`). **D4 correction:** `- "lib/screens/admin/audit_log_tab.dart"` is **already in `filesize.exemptions`** (`engineering.yaml:41`, working-tree diff; committed HEAD lacks it). The rewrite therefore needs **no `engineering.yaml` diff and no exemption decision** — the budget check cannot fail for this file, and migration step 5 collapses to a no-op verification. Contingency of record (only if a future change removes the exemption): ≤400 lines or a same-change re-exemption (prior-art §1.8; precedent `governance_tab.dart`, `clients_tab.dart`). No other file is touched by this change.

## 2. Compatibility constraints

| Constraint | Detail |
|---|---|
| Constructor shape | `AuditLogTab(api:, capabilities:, {tenantId:, traceId:})` — all 36 current call-site errors (dashboard ×2, admin_support_tabs ×4, audit_log_tab_test ×30) compile unedited; no other producers exist. `const AuditLogTab()` (old form) has zero remaining usages. |
| Zero-touch files this change | `lib/api/audit_read_client.dart`, `audit_event_row.dart`, `audit_query.dart`, `snaplink_admin_api.dart`, `snaplink_admin_types.dart`, `portal_api.dart` (no audit method — BFF stays `[PROPOSED]`), `admin_navigation.dart`, `dashboard_screen.dart`, `audit_log_service.dart` (B6-1b landed), all i18n catalogs. |
| `lib/screens/device/` | Zero-touch, guard-pinned (`test/device_audit_visibility_guard_test.dart`). |
| Guard scans | No audit path literal may enter the tab (trio-literal ownership); no hand-built `query:` map (scan 5: `.toQueryParameters()` + `AuditReadClient` reference mandatory); no `bff` substring (bff-literals); no fourth audit path, no non-GET audit method (catalog-trio). Read via `_client.list(limit: 100)` satisfies all by construction. |
| Ring | Single debug writer `_recordAudit` (`snaplink_admin_api.dart:81-85`, call `:324`) unchanged; no new writer; tab reads `.count`/`.clear()` only (debug surface), never `.entries`; `ringCopyEnabled` const-folded off in release. |
| B6-1b harness (D8) | `tab_kdebug_count: 1` — exactly **one** `kDebugMode` occurrence in the rewritten tab: the §1.4 gate, with a plain `foundation.dart` import (`show kDebugMode` = second occurrence). Landed gate config (`checks/config.py`, `checks/b6_1b_gates.py`) **unchanged**. Net harness effect: b6_1b failures 6 → 4 (old-en needles + tab count fixed; service seam pins + stale artifact remain B6-1b-scope, documented-red). |
| i18n | Consume landed keys verbatim; zero catalog edits; anchored `subtitle:` scan active (FM-13 — D7); zh-parity red at HEAD on 6 tab literals → green after rewrite. |
| Transport | `SnaplinkAdminApi.get` with query bypasses `DataCache` (`:133-134`); GET retry (3×, backoff) and 401 `onUnauthorized` are transport behavior — the tab must not reimplement or suppress either. |
| Line budget | Already exempt (`engineering.yaml:41`, D4) — no diff, no gate risk; §1.7 is verification-only. |
| Tests | Landed 638-line suite + `admin_support_tabs_test.dart` are the executable contract — the rewrite must make them green, not modify their assertions. Only net-new tests: present-branch (widget, §1.6A), FM-2/FM-3/FM-7 error-state variants (widget, §1.6C), drill read leg (§1.6B). |

## 3. Failure modes

| # | Mode | Behavior / mitigation | Pin |
|---|---|---|---|
| FM-1 | Sink 500 after retries | `SnaplinkAdminApiError` → error state: `error.toString()` (= description `'Query failed'`), `'Retry'` re-enters gate; ring stays inert; `error.data` never rendered (op-1/secret bait absent). | AC-3b `:313` |
| FM-2 | Timeout / network | GET retried by transport (3×, 1000/2000ms backoff, `snaplink_admin_api.dart:298/:339`); final raw `TimeoutException` → same error state with `e.toString()`; never a ring fallback. | new FM-2 test (§1.6C, target `:410`) |
| FM-3 | 401 | Transport fires `onUnauthorized` (session handling, `snaplink_admin_api.dart:335-336`) — unchanged; tab renders the 401 description via the same error state; Retry re-enters the gate; error code never rendered. | new FM-3 test (§1.6C, target `:455`) |
| FM-4 | Stale response race | `_generation` monotonic guard: only the newest fetch commits (search-triggered second request completes first; older response discarded). | test group "FM-9 stale-response race" `:409` (the landed group's own numbering — pins this FM-4) |
| FM-5 | Devtools-forged ring entries | Render path has no ring read — forgery cannot render regardless of server outcome. | AC-3a/b/c |
| FM-6 | Capability absent | Gate-first: not-enabled state, **zero** requests. | AC-4.1 `:374` (D6) |
| FM-7 | Malformed/wrong-typed envelope | Mapper never throws → 0 rows → **server-truth empty state** (adjudicated: empty, not error — `'Retry'` absent); no crash, no fabricated rows, decoy count never rendered. | `audit_event_row_test.dart` + new FM-7 widget test (§1.6C, target `:508`) |
| FM-8 | Decoy response `count` (999) | Header = `_rows.length`; `count` never read. | AC-1 `:110`, AC-3a `:294` (D6) |
| FM-9 | Release-build debug surface | Tab gate `kDebugMode && ringCopyEnabled` (§1.4, D8) const-folds `false` in release → no marker, no `delete_sweep` icon; server truth unaffected. The release guarantee is **source-enforceable**: `checks/b6_1b_gates.py` pins `_ringCopyEnabled = kDebugMode`, `if (!kDebugMode) return;` ×4, `service_kdebug_count: 6`, `tab_kdebug_count: 1` — widget tests pin the conditional path, the harness pins the const-fold. | B6-1b 2a/2c + b6_1b_gates source pins (tab count, initializer, guards) |
| FM-10 | Clear during loaded state | Ring-scoped dialog (n = ring count); `clear()` + re-fetch; server rows untouched. | B6-1b 2b |
| FM-11 | tenant/trace seam | Present → wire contains `tenant_id`/`trace_id` with injected values (trimmed, never derived); absent → exactly `{'limit':'100'}`. | new present-branch test |
| FM-12 | Guard regression (hand-built query map / raw trio literal / `bff` / 4th path) | Scans `second-consumer`/`trio-literal-owner`/`bff-literals`/`catalog-trio` are CI gates; design avoids by construction (read via client). | `audit_contract_guard_test.dart` |
| FM-13 | i18n drift (zh fallback) | All literals consume landed keys; anchored `subtitle:` scan (`i18n_coverage_test.dart:78-81` — D7: renumbered here from the old FM-16) + zh-parity scan (red at HEAD on 6 tab literals, green after rewrite) + placeholder-preservation pins. | `i18n_coverage_test.dart`, `app_strings_test.dart` |
| FM-14 | Line budget breach | **Vacuous (D4):** already exempt (`engineering.yaml:41`); no diff, no gate risk. Contingency only if a future change removes the exemption: ≤400 or same-change re-exemption. | `checks/filesize.py` (exemption present) |
| FM-15 | Drill false PASS pre-B1-5 | Read leg `[proposed]` deviation branch (B6-2 precedent `:159-190`); exit 0 with explicit deviation, never PASS without the observed row. | AC-4 |
| FM-16 | Search keystroke re-query storm (D7: sole owner of FM-16 — the subtitle scan moved to FM-13) | AC-1.6 pins exactly one request per `enterText` (2 requests total, both `{'limit':'100'}`); debounce/dedup is the separate F12 proposal (`b6-1a-lib-screens-admin-auditlogtab-f12-debounce-dedup-design.md`) — out of scope here. | AC-1.6 `:148` |

### 3.1 Scope adjudication (recorded — FM-2 / FM-3 / FM-7)

**Decision: Option A — the widget tests are specified (§1.6C), not documented out-of-scope.**

Rationale, recorded as binding for this direction:

1. **The unpinned surface is net-new, not pre-existing.** The branches in question are specified new behavior of this rewrite (§1.2 step 5: `on TimeoutException catch` + `on SnaplinkAdminApiError catch` → shared error state). The *transport* halves — GET retry, `onUnauthorized` firing — are pre-existing zero-touch code (`snaplink_admin_api.dart`) and are already pinned elsewhere (`snaplink_admin_transport_test.dart:105` timeout; 401/onUnauthorized in `snaplink_admin_api_test.dart`). "Out-of-scope pre-existing" would therefore cover only what is already tested, leaving exactly the new tab-level rendering unpinned — the opposite of the FM table's purpose.
2. **No repo precedent for an unpinned tab-level timeout branch:** prior art `governance_tab.dart` has no `on TimeoutException` branch at all (grep: zero hits); this design adds one explicitly, so its behavior must be enforceable.
3. **Non-vacuous marginal value:** no existing test feeds a timeout — a ring-fallback-on-timeout implementation would pass the entire current suite; no test pins 401 description-rendering or hook pass-through at tab level; no test distinguishes empty-state from error-state on a malformed body.
4. **Cost is minimal:** three tests, each a 1:1 idiom copy of landed patterns (held-completer FM-9 `:409`; error-state asserts AC-3b `:313`; empty-state asserts AC-3c `:352`), added in the same change as the rewrite (§4 step 3) with zero new imports (`dart:async`, `dart:convert`, `http/testing` already imported at `test/audit_log_tab_test.dart:1-9`).

**FM-7 adjudication: empty state, not error state.** Grounded in the mapper contract: `auditEventRowsFromResponse` (`audit_event_row.dart:50-62`) returns rows only from `List`-typed envelope keys (`events`/`items`/`results`/`data`/`entries`); every other shape — including wrong-typed `events` — yields `[]` without throwing, and `list()` (`audit_read_client.dart:39-43`) passes that through. The widget pin asserts `'0 entries'` + server-truth empty copy + **`'Retry'` absent** (the empty-vs-error discriminator), decoy `999` absent, forged ring absent. Error state remains reserved for `SnaplinkAdminApiError` (incl. 401/500) and timeout — the FM-2/FM-3 pins.

## 4. Migration steps (ordered; each step leaves the tree green or documented-red)

1. **Baseline (current state, recorded — A1 amendment):**
   - `make analyze` (`flutter analyze`): **36 errors → all `undefined_named_parameter`** (`api`/`capabilities`): `audit_log_tab_test` ×30 (15 sites × 2 — D5), `admin_support_tabs` ×4, dashboard ×2 — plus 4 pre-existing `info` lints (`test/entry_ux_test.dart:252/:269/:287/:292`, unrelated file, out of scope). The errors are the gap, fully attributed to `audit_log_tab.dart` + its landed callers.
   - **Joint suite:** `audit_log_tab_test` / `admin_support_tabs_test` / dashboard red (constructor shape); **`i18n_coverage_test.dart` red at HEAD too (A1)** — zh-parity fails on exactly 6 raw tab literals (`'All methods'`, `'Modify'`, `'No audit entries yet. Operations will appear here.'`, `'Clear log'`, `'Search by path, label...'`, `'Clear audit log?'`), same root cause, made green by the rewrite. The remaining joint-suite files: green (verified: 101 passed / 1 failed outside the widget files).
   - **Engineering harness — pre-existing reds, documented (A1):** filesize **×11** (`app_strings_source_admin_core` 509, `admin_overview_tab` 518, `change_approvals_tab` 410, `local_users_tab` 475, `tenants_tab` 565, `usage_analytics_tab` 503, `users_tab` 484, `webhooks_tab` 490, `login_view_widget` 420, `portal/overview_tab` 416, `audit_contract_guard_scans` 560 — no `_test.dart` suffix, so not ignored); directory-fanout **×1** (`docs/auto/runs` 59/12); b6_1b_gates **×6** (old-en needles found 4 — in B6-1a scope; tab kDebugMode found 0 — in scope, D8; service guard 1≠4 / storage initializer 0≠1 / service kDebugMode 2≠6 / stale artifact `sso_audit_log` ×2 — B6-1b storage-seam/artifact scope); invariants 12/12 green. (Reviewer snapshot "quality ×14" not reproducible: no `checks/quality.py` exists; nearest equivalent `checks/invariants.py` is green.) No action — the reds are the gap plus documented pre-existing debt.
2. **Rewrite `lib/screens/admin/audit_log_tab.dart`** (§1.1-§1.5) — single change; the only production file touched. Constructor + state model + UI + B6-1b surface (D8 gate form: exactly one `kDebugMode` occurrence + plain `foundation.dart` import) + CSV/filter rework, consuming landed keys verbatim.
3. **Add the net-new widget tests** (§1.6A present-branch + §1.6C FM-2/FM-3/FM-7 error-state variants) in the same change.
4. **Add the AC-4 drill read leg** (§1.6B) in the same change (drill invocation already wired at `run_all.py:169` / `full_stack_verify.py:113`).
5. **Line-budget verification (D4 — no-op):** `audit_log_tab.dart` is already in `filesize.exemptions` (`engineering.yaml:41`); confirm `checks/filesize.py` passes the file via the exemption and **make no `engineering.yaml` diff** (§1.7).
6. **Gate:** `flutter analyze` **36 errors → 0** (the 4 pre-existing `info` lints remain — documented-red, unrelated file); joint suite green — `flutter test test/audit_log_tab_test.dart test/audit_read_client_test.dart test/audit_event_row_test.dart test/audit_query_test.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/admin_navigation_test.dart test/admin_support_tabs_test.dart test/device_audit_visibility_guard_test.dart test/i18n_coverage_test.dart test/app_strings_test.dart` (11 files, including the previously-red `i18n_coverage_test.dart`).
7. **Engineering harness — re-scoped (A2):** `python3 cli.py harness` must show **zero NEW violations from this change**, with the step-1 reds (A1) documented. Net harness effect of this change: b6_1b_gates failures **6 → 4** (the rewrite fixes old-en needles 4→0 and tab kDebugMode 0→1); the remaining 4 (service guard 1≠4, storage initializer 0≠1, service kDebugMode 2≠6, stale artifact `sso_audit_log` ×2) are B6-1b storage-seam/artifact scope — a sibling deliverable, out of B6-1a scope, documented-red (their counts change only when the storage seam lands or `build/web` is rebuilt). filesize ×11 / directory-fanout ×1 / invariants: unchanged by this change (no new files; the drill leg reuses existing helpers — no duplicate-fingerprint/complexity trips on `tests/integration/*.py`). Absolute harness green is **not** attainable at this step — that is why the scope is "zero new violations".
8. **Drill (stack permitting):** `python3 tests/integration/audit_login_drill.py` — read leg passes when B1-5 is deployed; otherwise records `[proposed]` deviation (no false PASS).
9. **Docs:** mark spec REQ-1..REQ-6 implemented; record the full amendment set in the spec's evidence table and the `[RESOLVED]` note in `audit-contract-batch-snaplink-console.md`: D1 (36 vs 32), D2 (shim lives in `lib/screens/device/`), D3 (spec artifact), D4 (exemption already present — no diff), D5 (15 call sites), D6 (citation corrections AC-3a `:294` / AC-3b `:313` / AC-3c `:352` / AC-4.1 `:374` / AC-4.2 `:391`), D7 (FM-16 split), D8 (single `kDebugMode` tab gate; `tab_kdebug_count: 1` satisfied with zero gate-config changes), A1 (baseline reds), A2 (step-7 re-scope).

## 5. Testable acceptance mapping

| Acceptance (supplied) | Concrete test | State | Assertions (pins) |
|---|---|---|---|
| **AC-1** absent branch: exactly one `GET /api/v1/audit/events`, query `{'limit':'100'}`, rows from mock body, no local `AuditEntry` source | `test/audit_log_tab_test.dart` "issues exactly one events request with {limit: 100}…" (`:110`) | landed, red until rewrite | 1 request; `uri.queryParameters == {'limit':'100'}`; no `tenant_id`/`trace_id` keys; rows `admin_client_created`/`admin_user_deleted`; decoy `999` absent; forged `/api/v1/admin/forged` absent; `'on this device'` absent; search re-query keeps identical query (`:148`, 2 requests total) |
| **AC-1** present branch: injected `tenantId`/`traceId` ride the wire | new test (§1.6A) | **new — mandatory addition** | exactly 1 request; query contains `tenant_id='acme'`, `trace_id='tr-1'`, `limit='100'`; rows from mock body; forged absent; no `/facets`, no `/events/{id}` requests; trim corner |
| **AC-1** zh locale | "zh locale: count and subtitle render translated copy" (`:164`) | landed | `共 2 条`; `服务器记录的全部认证与管理事件。`; `全部`/`成功`/`失败`; CSV snackbar `已将 2 条记录以 CSV 导出到剪贴板` exact-key args path |
| **AC-1** capability gate | AC-4.1 (`:374`) / AC-4.2 (`:391`) (D6) | landed | trio-less → not-enabled copy + zero requests; positive → exactly 1 request + rows |
| **AC-2** ring isolation + single writer | greps + `audit_contract_guard_test.dart` + `device_audit_visibility_guard_test.dart` | landed (green at HEAD) | no `LocalStorage`/`sso_audit_log`/`.entries` in tab; `AuditLogService` confined to debug surface; `grep -rn "_recordAudit" lib/` → `snaplink_admin_api.dart:81` + `:324` only; device module untouched |
| **AC-3** forgery sub-cases | AC-3a (`:294`), AC-3b (`:313`), AC-3c (`:352`) (D6) | landed, red until rewrite | success: `2 entries`, `50% errors`, forged absent; 500: `Query failed`, `Retry`, `op-1`/`secret` absent, retry re-issues request; empty: `0 entries`, server-truth empty, forged absent |
| **AC-4** T-12 drill read leg | `audit_login_drill.py` Step 6 (§1.6B) | **new — mandatory addition** | console-shaped `?tenant_id=<t>&limit=100` query → re-query shows caller-attributed `audit.event.read` row; unobserved → `[proposed]` deviation, exit 0, never false PASS (B1-5 at `implementation-gate.md:47`) |
| **B6-1b** debug ring surface | group "B6-1b debug ring copy surface" (`:480`, 7 tests) + harness `tab_kdebug_count: 1` (D8) | landed, red until rewrite | 5 keys zh-atomic; marker ring-count-only (1≠2≠999); flag-off hides marker + `delete_sweep`; Clear ring-scoped copy + ring-only effect; zh dialog keys; tab carries exactly one `kDebugMode` (the §1.4 gate) |
| stale-response race (landed group name "FM-9", `:409` — pins §3's FM-4) | "older in-flight response never replaces newer rows" (`:409`) | landed, red until rewrite | newer response commits, older discarded (`newer-event` present, `older-event` absent) |
| **Gate** | `make analyze` + joint suite (§4 step 6) + engineering harness (§4 step 7) | 36 errors → 0 (4 pre-existing infos remain, documented); joint suite green; harness: zero new violations, b6_1b failures 6 → 4 (remaining 4 = B6-1b-scope, documented) | — |

## 6. Out of scope (spec §6, enforced)

B6-1b writer demotion / release-bundle surgery beyond the landed `ringCopyEnabled` gate; B6-2 client_id alignment; B4-1 tenant-claim parsing; BFF `trace_id` injection; nginx split-routing; B1-5 sink-side `audit.event.read` emission; F12 search debounce/dedup; any `PortalApi` audit method; any change to `lib/screens/device/`.

## 7. Risks

| Risk | Mitigation |
|---|---|
| Present-branch seam drifts into B4-1 claim parsing | REQ-2 pins forwarding-only (trim via `AuditQuery`, never derive/hardcode/default); absent-branch test pins default wire untouched. |
| Rewrite regresses landed B6-1b surface or i18n atomicity | B6-1b group + `admin_support_tabs_test.dart` + `i18n_coverage_test.dart` + `app_strings_test.dart` are gate members; rewrite consumes landed keys verbatim. |
| ~~Line budget surprises the gate~~ (D4) | Vacuous — already exempt (`engineering.yaml:41`); no diff needed. |
| Second `kDebugMode` occurrence in the tab (D8) | `tab_kdebug_count: 1` is an occurrence count (`rg -o`): a `show kDebugMode` import, a second debug gate, or any other `kDebugMode` token fails the landed harness pin. Mitigation: §1.4's single gate + plain `foundation.dart` import; verified by the b6_1b_gates step of `cli.py harness`. |
| Harness step 7 misread as absolute green | Re-scoped (A2): the gate is "zero new violations + step-1 reds documented"; 4 b6_1b failures (storage-seam/artifact scope) remain by design — landing must not be blocked on them, and the docs record them. |
| Drill false PASS without B1-5 | Hard `[proposed]` deviation branch; exit 0 with explicit deviation only. |
| Guard scans trip on refactor artifacts | Read exclusively via `_client.list(limit: 100)`; no literals, no `query:` maps in the tab — green by construction, pinned by mutation tests. |

## 8. Repository gates (unchanged baselines)

`engineering.yaml` (filesize 400, complexity, invariants), `checks/` harness via `python3 cli.py harness` (filesize, complexity/analyze, architecture, directory-fanout, root-policy, invariants, **b6_1b_gates**), `make analyze` (`flutter analyze`), `make release-artifact-check` (b6_1b artifact needles), full `flutter test` green. Drill wired at `run_all.py:169` / `full_stack_verify.py:113` (already invoking `audit_login_drill.py` — no wiring diff; rc-0 = PASS or `[proposed]` or SKIP).
