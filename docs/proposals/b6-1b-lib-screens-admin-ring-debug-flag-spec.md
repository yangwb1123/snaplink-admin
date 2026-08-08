# B6-1b — Requirements Specification: localStorage ring demoted to debug-only recording behind a single test-overridable flag; admin module zero-ring-display floor (module: lib/screens/admin)

> Direction: "Demote the localStorage ring to debug-only recording behind a single test-overridable flag and pin the admin module's zero-ring-display floor (B6-1b)" (`docs/auto/analyses/lib-screens-admin-4276368d.json`, direction 2).
> Value 8 · Risk reduction 8 · Effort 4 · Confidence 8.
>
> **Revision 1 (2026-08-08).** Every citation below was re-verified against the repository working tree (HEAD `26567d5` + the uncommitted B6-1a/B6-1b change set that `git status` shows in `lib/screens/admin/audit_log_tab.dart`, `lib/services/audit_log_service.dart`, `test/snaplink_admin_api_test.dart`, `test/audit_log_tab_test.dart`, `checks/b6_1b_gates.py`, `checks/config.py`, `Makefile`). State of the change set at writing: (a) the rewire (direction 1) and the **flag mechanism** are landed; (b) the **writer gate is NOT landed** — `SnaplinkAdminApi._recordAudit` still persists unconditionally at `snaplink_admin_api.dart:324`; (c) the **census floor for `lib/screens/admin` is NOT landed** — `audit_log_tab.dart:11,33,293` still reference `AuditLogService`; (d) the chip on/off tests and T-12 forgery joints are landed. This revision therefore (a) verifies the direction's citations against the landed state, (b) preserves the supplied acceptance checks (AC-1…AC-5) and makes each testable, (c) marks every divergence from the source citation or acceptance text with `[CORRECTION]`, and (d) surfaces one cross-spec conflict with the sibling storage-seam spec (§4).

## 0. Module boundary

Production changes are confined to:

| File | Change | Reason |
|---|---|---|
| `lib/api/snaplink_admin_api.dart` | Gate the `_recordAudit` call site at `:324` behind the single flag; expose the debug-ring facade (REQ-4) | AC-1, AC-5 |
| `lib/screens/admin/audit_log_tab.dart` | Re-point the debug chip surface (import `:11`, field `:33`, gate `:293`, count `:241/:300/:312`, clear `:318`) to the lib/api facade; **zero `AuditLogService`/`audit_log_service`/`sso_audit_log` tokens remain** | AC-2, AC-3 |

**Zero changes** to `lib/services/audit_log_service.dart` — the flag mechanism (`_ringCopyEnabled = kDebugMode` at `:76`, `ringCopyEnabled` `:79`, const-gated `debugRingEnabled` setter `:82-84`) is already landed and harness-pinned (`checks/config.py:91` initializer pin is green). The storage-seam wedge (service-boundary `_storageEnabled` seam) is a sibling deliverable (`docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-spec.md`) and stays out of scope here, including its three currently-red harness pins (§5). Zero changes to `lib/i18n/` — the five B6-1b keys are landed and uniquely pinned (harness green).

Tests: `test/snaplink_admin_api_test.dart` (AC-1 flag on/off variants), `test/audit_log_tab_test.dart` (AC-3 flip-site re-point only — assertions stay), one new census guard test (AC-2), one new writer-gate guard test (AC-5).

## 1. Problem statement (verified against the working tree)

As cited by the direction, `SnaplinkAdminApi._recordAudit` (`lib/api/snaplink_admin_api.dart:81-90`) persists **unconditionally**: the sole call site at `:324` (`if (method != 'GET') { _recordAudit(method, path, response.statusCode); _fireDataChanged(method, path); }` inside the 2xx branch at `:322-326`) writes to the localStorage ring key `'sso_audit_log'` (`lib/services/audit_log_service.dart:66`, cap 1000 at `:65`) on every non-GET 2xx response — a production client-side audit store, exactly where `docs/campaigns/implementation-gate.md:56` says "localStorage ring 降级为调试记录". **Verified unchanged: the writer is still ungated in the working tree** (grep: zero `kDebugMode`/flag occurrences in `lib/api/snaplink_admin_api.dart`).

`[CORRECTION — analysis snapshot vs working tree]` The direction's "no debug gate exists anywhere" is stale: the **display-side flag is landed**. `audit_log_service.dart:76-86` now carries `static bool _ringCopyEnabled = kDebugMode;` / `ringCopyEnabled` getter / `@visibleForTesting static set debugRingEnabled(bool)` with `if (!kDebugMode) return;` — const-folded to `false` in release, test-overridable in debug. The direction's `[proposed]` claim ("static bool on AuditLogService vs injected switch") is therefore **resolved in favor of the landed static bool**: no precedent exists in lib/api, test-overridability is satisfied (the setter is exercised by `test/audit_log_tab_test.dart:481,525-526,577-578`), and the off-branch is assertable in a debug run. This spec pins that mechanism; nothing may replace it with a compile-time-only `kDebugMode` gate (AC-3).

The direction's "nothing pins lib/screens/admin away from the ring" is still true: the only isolation guards cover `oidc_login` (`test/oidc_login_ring_isolation_test.dart`, `test/oidc_login_audit_visibility_guard_test.dart`). The remaining ring references in `lib/screens/admin` are `audit_log_tab.dart:11` (import), `:33` (`final _logService = AuditLogService();`), `:293` (`if (kDebugMode && AuditLogService.ringCopyEnabled)`), `:241/:300/:312` (`_logService.count`), `:318` (`_logService.clear()`).

## 2. Evidence verification table (direction citations re-checked against the working tree)

| # | Citation from direction | Verified repository reality | Status |
|---|---|---|---|
| E1 | `lib/api/snaplink_admin_api.dart:81-90` (`_recordAudit`), `:324` (sole call site, `method != 'GET'` && 2xx) | Exact. `_recordAudit` at `:81-90` (`AuditLogService().record(AuditEntry(timestamp/method/path/statusCode/label))`); call site `:324` inside `if (method != 'GET')` at `:323` within the 2xx branch `:322-326`; `_fireDataChanged` at `:325`. **Ungated** — zero `kDebugMode`/flag tokens in the file (verified by grep). Sole ring writer in `lib/` (`AuditLogService().record(` occurs exactly once in `lib/`, at `:82`). | ✅ + ⚠️ |
| E2 | `lib/services/audit_log_service.dart:57-124` (singleton, key `'sso_audit_log'` `:66`, `_maxEntries` `:65`, `record`/`_save`/`_load`/`clear`) | Exact: `_entries` `:64`, `_maxEntries` `:65`, `_storageKey = 'sso_audit_log'` `:66`, `record` `:89-95`, `_save` `:127-134`, `_load` `:136-145`, `clear` `:119-124`, `count` `:126`. **`[CORRECTION]`** the file now also carries the landed B6-1b flag at `:76-86` (see §1) and `@visibleForTesting` setter with `if (!kDebugMode) return;` at `:83`. | ✅ + ⚠️ |
| E3 | `test/snaplink_admin_api_test.dart:331-413` (ring persistence pins; `:351` getItem non-null; GET no-op `:399-413`) | Group `'ring liveness — successful mutations land in the audit ring'` at `:327-413` `[CORRECTION: 331→327]`; POST/PUT/DELETE append test `:332-397` (per-method `ring.count + 1` and `LocalStorage.getItem('sso_audit_log')` length `+1` with exact query-free wire path, `:351-374`); GET test `:398-413` (`ring.count` unchanged, stored value byte-identical). Ran green in this revision (see §6). These are the semantics AC-1 must preserve under flag ON and flip under flag OFF. | ✅ + ⚠️ |
| E4 | `test/oidc_login_ring_isolation_test.dart:16-28,104-136` (isolation guard pattern) | Exact: docstring `:16-28` (AC-1 Phase A REQ-2), main test `:104-136` (pre-seed ring, snapshot keys/value/count/entries, login, assert net-zero rewrite). Pattern reference for ring-untouched assertions — AC-1's off-branch borrows the "count + stored value unchanged" idiom. | ✅ |
| E5 | `test/oidc_login_audit_visibility_guard_test.dart:18-39` (reference-census pattern) | Exact: `@TestOn('vm')` `:3`, `dart:io` `Directory(moduleDir).listSync(recursive: true)` scan `:29-38`, literal-split needles `['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log']` `:23` (self-trip-proof), `expect(offenders, isEmpty)` `:33-38`. **This is the template for AC-2's new census guard.** | ✅ |
| E6 | `docs/campaigns/implementation-gate.md:56` (ring demotion named contract item; T-12 devtools forgery no longer evidence) | Line 56 = snaplink-console row 1: "读路径接入（F-06）：审计页调 sink 读 API…；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5". | ✅ |
| E7 | (new) `test/audit_log_tab_test.dart` — landed B6-1b chip surface + T-12 joints | B6-1b group `:480-641`: `setUp(() => AuditLogService.debugRingEnabled = true)` `:481`; 2a on `:483-505` (marker renders with ring count 1, never server count 2/decoy 999); 2a off `:506-523`; 2b clear dialog `:524-562`; 2c off `:563-578`; 2e zh `:579-615`; AC-3 joint (empty server rows=0 vs ring=1 badge-only) `:617-641`. T-12 forgery joints AC-3a/b/c `:294-371` + AC-1 server-read `:108-145`, all seeding via shared `_seedForgedRing` `:89-102` (one entry: path `/api/v1/admin/forged`, label `'forged entry'`). All 31 tests in this file + `test/snaplink_admin_api_test.dart` ran green in this revision. | ✅ |
| E8 | (new) harness state (`python3 cli.py harness`, this revision) | **22 passed, 3 failed.** The 3 failures are exclusively the storage-seam sibling's post-seam pins (`checks/config.py:89,92,94`: `service_kdebug_count` 2≠6, `storage_initializer_pin` `_storageEnabled = kDebugMode` 0≠1, `guard_line_count` 1≠4) — out of scope for this spec, must stay untouched. Green and load-bearing for this spec: `_ringCopyEnabled = kDebugMode` initializer pin (`:91`), `tab_kdebug_count = 1` (`:90`, the chip's single `kDebugMode`), key-literal residence (`sso_audit_log` in exactly one lib/ file = the service), five i18n keys unique, mask bans, release-artifact greps (`sso_audit_log` + base64 masks absent from `build/web/`, `Makefile:42-44` fail-closed). | ✅ + ⚠️ |
| E9 | (new) grep census of `lib/` | `AuditLogService()` constructions: `snaplink_admin_api.dart:82` (writer) + `audit_log_tab.dart:33` (badge) only. `AuditLogService().record(`: exactly 1 (the writer). `sso_audit_log`: exactly 1 lib/ file (the service). No `lib/screens/admin` file other than `audit_log_tab.dart` references the ring. | ✅ |
| E10 | (new) cross-spec conflict — sibling storage-seam spec | `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-spec.md` §4 walls: "**Gating `_recordAudit` itself** with `kDebugMode` at `snaplink_admin_api.dart` — contradicts C3 ('`_recordAudit`' `:81/324` unchanged) and is not needed by any acceptance check … Any implementer deviation toward call-site gating must be rejected." **This directly conflicts with this direction's AC-1 (flag OFF → no append) and AC-5 (sole writer gated).** Resolution in §4. | ⚠️ |

## 3. Requirements

### REQ-1 — One flag gates the writer (single test-overridable switch)

The landed mechanism is the single switch: `AuditLogService.debugRingEnabled` (setter) / `AuditLogService.ringCopyEnabled` (getter), default `kDebugMode`, setter const-gated (`if (!kDebugMode) return;`) so release builds fold to `false` and no release-reachable code can flip it. Nothing may add a second switch, an injected variant, or a compile-time-only `kDebugMode` gate in its place (AC-3's "no untestable compile-time-only gate"). The display chip (REQ-4) and the writer gate (REQ-2) must read the **same** flag.

### REQ-2 — Writer call site gated (AC-1, AC-5)

In `lib/api/snaplink_admin_api.dart` `_request`, the 2xx non-GET branch (`:322-326`) must invoke `_recordAudit` **only while the flag is on**:

```dart
if (method != 'GET') {
  if (AuditLogService.debugRingEnabled) {   // or `kDebugMode && …` — flag operand mandatory
    _recordAudit(method, path, response.statusCode);
  }
  _fireDataChanged(method, path);           // unchanged: UI refresh is not ring persistence
}
```

The `_fireDataChanged` call stays outside the gate (it is a UI-refresh event, not a ring write). `_recordAudit`'s definition (`:81-90`) and `AuditLogService.record` stay unchanged — the gate is at the invocation site only.

### AC-1 (testable) — Writer flag on/off unit test

In `test/snaplink_admin_api_test.dart`, extend the ring-liveness group (`:327-413`; plain-Dart `test()` + `MockClient` — no widget pumping):

1. **Flag ON (the default in debug; no setter call needed)** — existing semantics preserved verbatim: `:332-397` (POST/PUT/DELETE each append exactly one entry to `AuditLogService().count` **and** persist one more element under `LocalStorage.getItem('sso_audit_log')`, exact query-free wire path, `statusCode 200`). The direction's example path `/api/v1/admin/clients` is covered by the same method-agnostic machinery; the existing exercised paths are kept. `[CORRECTION — testable form]` the direction's "`LocalStorage.getItem('sso_audit_log')` non-null at `:351`" is preserved as the stored-array `length + 1` assertion already present.
2. **Flag OFF** — new test, same MockClient harness: `AuditLogService.debugRingEnabled = false` (with `addTearDown` restore, mirroring `test/audit_log_tab_test.dart:525-526`); pre-clean state via `ring.clear()` (the "null" assertion requires a clean key — `[CORRECTION — precondition made explicit]`); then a successful `POST /api/v1/admin/clients` (body any map, 200 response) must leave `AuditLogService().count` unchanged (0) **and** `LocalStorage.getItem('sso_audit_log')` null. A pre-seeded variant (seed one entry, snapshot stored value, flag off, POST) must leave count and stored value byte-identical — the `oidc_login_ring_isolation_test.dart:104-136` snapshot idiom.
3. **GET never records in either mode** — `:398-413` semantics preserved and run under both flag states: `ring.count` unchanged and stored value identical.

### REQ-3 — Census floor for `lib/screens/admin` (AC-2)

New guard test mirroring `test/oidc_login_audit_visibility_guard_test.dart:18-39` verbatim in shape (`@TestOn('vm')`, `dart:io` recursive `Directory` scan, literal-split needles `'AuditLog' 'Service'` / `'audit_log_' 'service'` / `'sso_audit_' 'log'`, `expect(offenders, isEmpty)`), scanning **`lib/screens/admin`**: zero `AuditLogService` / `audit_log_service` / `sso_audit_log` references. Currently **red** at `audit_log_tab.dart:11,33,293` — REQ-4 is the remediation. Ring access is then confined to `lib/api/snaplink_admin_api.dart` (writer + facade) and `test/` (forging/flag-flipping).

### REQ-4 — Debug ring facade in lib/api; chip re-point (AC-2, AC-3)

The tab's debug surface must keep working with zero banned tokens. Add a read-only static facade on `SnaplinkAdminApi` (the file the direction names as the confined ring home; the tab already imports it), delegating to the service — exact member names are implementation freedom, the behavior is pinned:

| Facade member (suggested) | Delegates to | Replaces in `audit_log_tab.dart` |
|---|---|---|
| `static bool get ringCopyEnabled` | `AuditLogService.ringCopyEnabled` | gate operand at `:293` |
| `static int get debugRingCount` | `AuditLogService().count` | `_logService.count` at `:241` (badge), `:300` (disabled state), `:312` (dialog message) |
| `static void clearDebugRing()` | `AuditLogService().clear` | `_logService.clear()` at `:318` |

`audit_log_tab.dart` changes: delete import `:11`; delete `final _logService = AuditLogService();` `:33`; gate `:293` becomes `if (kDebugMode && SnaplinkAdminApi.ringCopyEnabled) ...` — **`kDebugMode` count in the tab stays 1**, keeping `checks/config.py:90` green, and the flag remains the testable operand (AC-3). The chip's strings, i18n keys, and `_debugRingBadge` widget (`:227-243`) are unchanged.

### AC-3 (testable) — Chip renders iff flag on; both states asserted

The landed B6-1b group in `test/audit_log_tab_test.dart:480-641` is the pin; only the flip sites (`:481,525-526,577-578`) may be re-pointed if the facade exposes a setter — they must flip **the same flag the widget reads** (`AuditLogService.debugRingEnabled`, which the facade delegates to). Assertions preserved:

- flag ON: marker `'Debug records'` + `'Debug records: 1 entries'` render (ring count 1 — never server count 2, never decoy 999); delete icon enabled; Clear dialog uses the ring-scoped copy and clears the ring only (server rows untouched).
- flag OFF: marker, badge, delete icon, and Clear dialog all absent; server truth (`'2 entries'`) unaffected.
- zh: the five keys resolve exact zh (`:579-615`).
- The gate is never `kDebugMode`-only — the flag operand is always present, so the off-branch is exercised in a debug run (this is the "no untestable compile-time-only gate" requirement).

### REQ-5 — T-12 joint preserved (AC-4)

The devtools-forgery joint stays pinned: `test/audit_log_tab_test.dart` AC-3a (`:294-312`, server success), AC-3b (`:313-350`, server 500 + retry, error.data bait never surfaces), AC-3c (`:352-371`, server empty `{'events': [], 'count': 0}` → `'0 entries'` + server-truth empty state), AC-1 server-read (`:108-145`), and the B6-1b AC-3 joint (`:617-641`, ring=1 vs rows=0 vs decoy=999 pairwise-distinguishable badge). All seed the ring via the shared `_seedForgedRing` fixture (`:89-102`) — the devtools-equivalent (`record()` = forged `setItem` content); all assert forged marker strings (`/api/v1/admin/forged`, `'forged entry'`) render **zero** rows, the count badge is server-derived, and the ring never acts as fallback. AC-1's flag-off tests must not disturb this fixture (flag restored in tearDown).

### REQ-6 — Writer-census guard (AC-5)

New guard test (same `@TestOn('vm')` scan style as REQ-3), or an extension of an existing source-scan guard, pinning "release-path ring writes impossible — no unconditional `AuditLogService().record` call remains in lib/api":

1. `AuditLogService().record(` in `lib/` == 1, and the hit is in `lib/api/snaplink_admin_api.dart` (the sole writer definition, `:82`).
2. In that file, the single `_recordAudit(` invocation (`:324`) is textually inside a statement containing `debugRingEnabled` — an adjacency pin in the style of the seam's per-function ordering pins; `debugRingEnabled` occurs exactly once in `lib/api` (the gate), so a decorative/unreachable gate cannot silently drift.
3. Non-vacuousness is carried by AC-1's off-branch behavioral test (flag off ⇒ nothing appended, key null) — a dead gate would fail it.
4. Backstops already green and untouched: key-literal residence (exactly one lib/ file), `Makefile:42-44` + `checks/b6_1b_gates.py` release-artifact greps (`sso_audit_log` and its base64/base64Url masks absent from `build/web/`, fail-closed).

## 4. Cross-spec coordination finding (must read before landing)

**Conflict.** `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-spec.md` §4 ("Out of scope (explicit walls)") and R1.9 state that gating `_recordAudit` at `snaplink_admin_api.dart` "contradicts C3 ('`_recordAudit`' `:81/324` unchanged) … and is not needed by any acceptance check", and mandate rejection of call-site gating.

**This direction's AC-1 and AC-5 require exactly that gate** — the seam alone cannot satisfy AC-1's off-branch: the seam release-gates storage I/O only, while `record()` in a debug test run persists regardless of the display flag, so "flag OFF ⇒ count unchanged and key null" is only achievable at the writer call site. The seam's "not needed by any acceptance check" is true only of the seam's own acceptance set; AC-1/AC-5 of this direction (the module `lib/screens/admin` authority) are binding.

**Resolution (sequential, not contradictory).** Land the seam first (service-boundary isolation: release `_load`/`_save` no-op, `_storageEnabled` seam, its three harness re-pins), then this direction's call-site gate. C3's "`_recordAudit` unchanged" is re-scoped to the service public API and the writer's definition/signature (`:81-90`) — the invocation at `:324` is gated by REQ-2. Both layers compose: seam kills release persistence at the I/O boundary; the flag gate kills the debug-mode write when the debug surface is off, and provides the testable off-branch. The seam spec's §4 wall should be amended (or explicitly rejected for this direction per the campaign design-gate process) before this direction's gate lands, so the two specs are not mutually contradictory in the tree.

## 5. Out of scope / `[PROPOSED]` (no expansion)

- **Storage-seam wedge** (`lib/services/audit_log_service.dart` `_storageEnabled`, per-function guard pins, `service_kdebug_count` 2→6 re-pin, scan-6 drill): sibling deliverable; this spec makes **zero** edits to the service file. The three red harness pins (E8) are that sibling's responsibility and must remain untouched here.
- **Removal of the debug surface** (badge/Clear/CSV relabeling): demotion is not removal — AC-3 explicitly requires the flag-gated chip to keep rendering. The seam spec §4's "removal phase" stays a later step.
- **`[PROPOSED]` claims from the direction**: (a) the flag mechanism choice is **resolved** — static bool on `AuditLogService` (landed, harness-pinned), no injection needed; (b) BFF `trace_id` / token-claim `tenant_id` remain off the wire (no change here); (c) nothing in this spec touches the wire shape (`{'limit':'100'}` pin, Bearer pin, catalog-trio, bff-literals, scan-5 — all in `test/audit_contract_guard_test.dart` stay green).
- **`_fireDataChanged` semantics**, i18n keys/zh parity, CSV export, capability gate: unchanged, still pinned by their existing tests.

## 6. Acceptance mapping and verification

| AC | Requirement(s) | Testable pin | File(s) | Verification |
|---|---|---|---|---|
| AC-1 | REQ-1, REQ-2 | Flag ON: append+persist (existing `:332-397`); Flag OFF: `count` unchanged, `getItem('sso_audit_log')` null (clean state), stored value byte-identical (seeded variant); GET never records in both modes (`:398-413`) | `test/snaplink_admin_api_test.dart` | `flutter test test/snaplink_admin_api_test.dart` |
| AC-2 | REQ-3, REQ-4 | New census guard: zero `AuditLogService`/`audit_log_service`/`sso_audit_log` in `lib/screens/admin`; facade on `SnaplinkAdminApi`; `tab_kdebug_count == 1` harness pin stays green | new guard test; `audit_log_tab.dart`; `snaplink_admin_api.dart` | `flutter test test/<census_guard>.dart`; `python3 cli.py harness` |
| AC-3 | REQ-1, REQ-4 | Chip on/off both asserted (`:483-523,563-578`), zh `:579-615`, joint `:617-641`; flip sites re-pointed to the single flag | `test/audit_log_tab_test.dart` | `flutter test test/audit_log_tab_test.dart` |
| AC-4 | REQ-5 | T-12 joint: seeded forged ring (`_seedForgedRing` `:89-102`) renders zero rows across success/500/empty; server-derived counts | `test/audit_log_tab_test.dart` | `flutter test test/audit_log_tab_test.dart` |
| AC-5 | REQ-6 | `AuditLogService().record(` == 1 in `lib/` (the gated writer); `debugRingEnabled` == 1 in `lib/api`, adjacent to the `:324` call site; artifact greps green | new guard test; `Makefile:42-44`; `checks/b6_1b_gates.py` | `flutter test test/<writer_guard>.dart`; `python3 cli.py harness` |

Landing order within this direction: REQ-4 (facade + chip re-point) and REQ-2 (writer gate) land atomically with the new guard tests and the AC-1 off-branch test — any subset leaves the census or AC-1 red at an interim commit. Expected final state: `test/snaplink_admin_api_test.dart` + `test/audit_log_tab_test.dart` + the two new guard files green; `python3 cli.py harness` at **22 passed / 3 failed**, with the 3 failures being exactly the seam sibling's pins (unchanged, out of scope).
