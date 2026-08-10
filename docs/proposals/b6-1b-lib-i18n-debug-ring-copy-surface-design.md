# B6-1b — Debug-only ring copy surface (Clear/CSV/counter + marker) in lib/i18n

Direction: "Debug-only ring copy surface for Clear/CSV/counter + marker
(B6-1b 'ring 降级为调试记录' in lib/i18n)".

## 0. Evidence verification (claims re-checked, not trusted)

All citations below were re-checked at HEAD `26567d5` + the uncommitted B6-1a
landing in the working tree.

| Claim | Verification | Verdict |
|---|---|---|
| `audit_log_service.dart:65-66` = `_maxEntries` (1000), `_storageKey = 'sso_audit_log'`; `clear()` at `:101-104` | `grep -n` exact. Ring intact; **no `kDebugMode`/`debugStorageEnabled` seam exists in the file** (b6-1a design §1.2a is proposal-only, `[proposed]`) | ✅ |
| `{count} entries` at `audit_log_tab.dart:260` is server-derived (`_rows.length`) | Read at `:260` — `LocalizedText('{count} entries', args: {'count': _rows.length})` | ✅ (drift vs direction citation confirmed) |
| CSV snackbar at `:189-190` server-derived (`_displayed.length`) | Read at `:186-190` — `'Exported {n} entries as CSV to clipboard'`, args `{'n': _displayed.length}` | ✅ (drift confirmed) |
| Clear action `:278-291` ring-scoped in behavior **and** copy | Read — tooltip `'Clear log'.localized` (`:278`), disabled when `_logService.count == 0` (`:279`), title `'Clear audit log?'` (`:284`), message with `${_logService.count}` (`:285-286`), `confirmLabel: 'Clear log'` (`:287`), `_logService.clear()` + `_refresh()` (`:291-292`) | ✅ |
| Catalog keys at `admin_core.dart:4,89,90,92,144` | `:4` `'{count} entries'`, `:89` `'Clear audit log?'`, `:90` `'This will permanently delete all {n} local audit entries.'`, `:92` CSV exported, `:144` `'Clear log'` | ✅ (line drift from `86-87/89/142` confirmed) |
| Zero consumers outside `audit_log_tab.dart` | `grep -rn` over `lib/` — the five keys appear only in `audit_log_tab.dart:189,278,284,285,287` | ✅ in-place replacement safe |
| No debug-marker key in lib/i18n | `grep -rni 'debug.*marker|调试标记|调试记录' lib/i18n/` → zero hits | ✅ |
| No `kDebugMode` gate in lib/ | `grep -rn kDebugMode lib/` → zero hits. Mechanism is `[proposed]`; precedent shape = b6-1a design §1.2a const-gated `debugStorageEnabled` (`docs/proposals/b6-1a-lib-api-auditlogtab-server-read-design.md:95-127`) | ✅ |
| `i18n_coverage_test.dart` 3/3 green | Ran — passes. Scan regexes: `localizedCall`, `localizedProperty`, `messageAssignment` (`*message* = 'lit'`), `localizedNamedCopy` (`title/subtitle/detail/body/emptyText:`), helper/field patterns. **`message:`/`confirmLabel:` named args NOT scanned; the Clear message is a line-concat + interpolation that no single-literal regex can match** → zh only resolves via `_matchSourcePattern` fallback (verified in `app_strings_context.dart`; `translate()` falls back to the English source silently) | ✅ gap confirmed |
| b6-1a §6 + `implementation-gate.md:56` confirm B6-1b scope | b6-1a spec §6 "Out of scope" lists B6-1b verbatim ("debug badges, CSV/Clear relabeling, palette description copy"); `implementation-gate.md:56` console row 1 "localStorage ring 降级为调试记录" | ✅ |
| Harness at `admin_governance_security_test.dart:12-38` mirrored in `audit_log_tab_test.dart` | `_api`/`_caps`/`_pump` present in both files (audit_log_tab_test `:33,:44,:51`-ish) | ✅ |
| Baseline green (16/16) | Ran: `audit_log_tab_test` 8/8, `i18n_coverage_test` 3/3, `admin_support_tabs_test` 8/8, `admin_governance_security_test` 6/6 — all green. Evidence's "16/16" is a stale subset count; substance (green) holds | ⚠️ count drift only |
| `admin_support_tabs_test.dart:135` regression consequence | `:135` = `await tester.tap(find.text('Clear log').last);` — taps the Clear **confirm label**. Any label change breaks this test | ✅ consequence confirmed |

Key drift recorded in the spec (kept): counter/CSV are server truth
(`_rows.length`/`_displayed.length`); only Clear remains ring-scoped. This
design therefore **does not touch** the counter/CSV copy — it keeps server
truth and adds the conditional ring-scoped keys (marker chip + Clear dialog).

Ring producer note: `lib/api/snaplink_admin_api.dart:82` still calls
`AuditLogService().record(...)` in all builds; the storage-I/O seam
(b6-1a §1.2a) is a separate pending step, not this direction.

## 1. API changes

### 1.1 `lib/services/audit_log_service.dart` — const-gated ring-copy flag

Adds one static flag with the repo's established const-gated shape (b6-1a
design §1.2a). Public instance API (`record`/`entries`/`search`/
`filterByMethod`/`recent`/`clear`/`count`) is **unchanged** — the
`service_contracts_test.dart:18-37` and `snaplink_admin_api.dart` ring
callers stay green.

```dart
// foundation.dart already imported (kDebugMode, debugPrint, @visibleForTesting)
static bool _ringCopyEnabled = kDebugMode; // const-folded false in release/profile

/// True when the debug-only ring copy surface may render (marker + Clear).
static bool get ringCopyEnabled => _ringCopyEnabled;

@visibleForTesting
static set debugRingEnabled(bool value) {
  if (!kDebugMode) return; // const-folds to `return;` in release — assignment unreachable
  _ringCopyEnabled = value;
}
```

Rules (from b6-1a §1.2a, applied): (a) `kDebugMode` is the only axis — no
`bool.fromEnvironment`/env-var second axis; (b) the setter is itself
const-gated so no release-reachable code can flip the flag; (c) `flutter
test` runs debug-mode, so both polarities are testable with
`AuditLogService.debugRingEnabled = false` simulating release; (d) tests
must restore the flag in teardown (singleton static state — precedent:
wire-auditlogtab F2 order-dependence finding).

Relationship to the pending `debugStorageEnabled` seam: separate concern
(storage I/O vs copy surface). When the storage seam lands, fold both under
one flag to avoid two axes on the same service; B6-1b does not block on it.

### 1.2 `lib/i18n/app_strings_source_admin_core.dart` — exact key table

In-place replacement of the three Clear keys (zero consumers outside
`audit_log_tab.dart`, verified §0) + two new marker keys. en is the source
language; every key gets an atomic zh value.

| Action | en key | zh value | Consumer (audit_log_tab.dart) |
|---|---|---|---|
| REPLACE `:89` | `'Clear local debug records?'` | `'清除本地调试记录？'` | `:284` dialog title |
| REPLACE `:90` | `'This will permanently delete all {n} local debug records.'` | `'这将永久删除全部 {n} 条本地调试记录。'` | `:285-286` dialog message (switched to args-form) |
| REPLACE `:144` | `'Clear local debug records'` | `'清除本地调试记录'` | `:278` tooltip, `:287` confirmLabel |
| ADD | `'Debug records: {n} entries'` | `'调试记录：共 {n} 条'` | marker chip (ring counter, flag-gated) |
| ADD | `'Debug records'` | `'本地调试记录'` | marker chip label (flag-gated) |

**Terminology adjudication (i18n review, adopted — 环 rejected)**: the draft
mixed three zh nouns (日志/审计记录/环) and kept 环/调试环 in brand-new copy,
contradicting the sanctioned wording `localStorage ring 降级为调试记录`
(implementation-gate.md:56). Final set uses the **single noun 调试记录 across
all five keys**, en mirror `debug records`. 环 is rejected because the marker
is exactly the surface where the demotion must become visible — re-using the
ring's old name there would re-sanction it; the internal "ring" term stays in
code comments and design docs only. 本地 appears on the label pair only
(en `Debug records` ↔ zh `本地调试记录`, matching the draft's own label
convention), and the count line drops it (`调试记录：共 {n} 条`), preserving
the catalog's established `'{count} entries' → '共 {count} 条'` tail — the
label-vs-count-line noun asymmetry (环 vs 日志 vs 审计记录) is what is fixed.
Verified at HEAD: zero existing hits for `调试记录`/`Debug records`/`Debug
ring` in `lib/` — no collision; uniqueness grep needs anchored matching only
because `Debug records` ⊂ `Debug records: {n} entries` (same file).

Removed (zero hits after landing): `'Clear audit log?'`,
`'This will permanently delete all {n} local audit entries.'`, `'Clear log'`.

Untouched (server truth): `'{count} entries'` (`:4`), `'Exported {n} entries
as CSV to clipboard'` (`:92`) — behavior and copy stay server-derived. No
ring-scoped CSV variant is added: CSV exports `_displayed` (server rows);
labeling them "local debug" would be false. Deviation from the direction's
original CSV wording recorded at spec level.

Key uniqueness: new keys must appear in exactly one `app*SourceZh` map
(spread-override precedence, `app_strings_source.dart:14-25` — a duplicate
later wins silently). Grep gate in §5.

### 1.3 `lib/screens/admin/audit_log_tab.dart` — marker + gated Clear

- **Marker chip** in the actions row (next to the server count, after
  `:260`): rendered only when `kDebugMode && AuditLogService.ringCopyEnabled`
  — `LocalizedText('Debug records', ...)` + `LocalizedText('Debug records:
  {n} entries', args: {'n': _logService.count})`. The direct `kDebugMode`
  guard makes bundle elimination structural (b6-1a §1.2a AMEND W2/S14
  precedent: DCE must rest on const-branch folding, not getter-inlining
  heuristics). Exact-text finders in existing tests (`'2 entries'`,
  `'1 entries'`, `'共 2 条'`) do not collide (full-string match).
- **Clear IconButton** (`:276-292`): wrapped in
  `if (kDebugMode && AuditLogService.ringCopyEnabled) ...` — hidden entirely
  when the flag is off (release: the ring is invisible to users; it is never
  rendered, so a ring-scoped Clear is meaningless). Inside the branch the
  existing enable/disable (`_logService.count == 0`), destructive
  ConfirmDialog, `_logService.clear()` + `_refresh()` behavior is
  unchanged.
- **Message becomes args-form** (exact-key path): replace the
  concatenation at `:285-286` with
  `message: context.tr('This will permanently delete all {n} local debug records.', {'n': _logService.count})`
  — the exact-key zh hit, not the fragile pattern fallback (the current
  copy only resolves zh because `_matchSourcePattern` regex-matches the
  interpolated string; any en drift silently falls back to English). As a
  `context.tr(...)` literal the message key becomes `localizedCall`-scanned,
  so its zh parity is gate-enforced at landing — and a concat relapse would
  drop that coverage and fail the zh-parity gate (F2 is now scan-enforced,
  not just review-enforced).
- No constructor/state-model change — B6-1a's `AuditLogTab({required this.api, required this.capabilities})` stays.

### 1.4 Test files

- `test/admin_support_tabs_test.dart:135` — tap target becomes
  `find.text('Clear local debug records').last` (regression consequence,
  same change).
- `test/audit_log_tab_test.dart` — new AC-2 group (see §5); teardown
  restores `AuditLogService.debugRingEnabled = true`.

## 2. Compatibility constraints

1. **Public service API frozen** — only additive statics; `record`/`clear`/
   `count`/`entries` semantics untouched (`service_contracts_test.dart`,
   `snaplink_admin_api_test.dart:335,399`, `oidc_login_ring_isolation_test`
   ring assertions keep passing).
2. **`AuditLogTab` constructor frozen** — no further change beyond B6-1a.
3. **Catalog line budget**: `admin_core.dart` is 493 lines (pre-existing
   over `filesize.max_lines: 400`; the check is red repo-wide on unrelated
   files — documented baseline, `checks/filesize.py`). Convention: minimal
   delta vs HEAD. This design is net **+2 lines** (3 in-place replacements
   + 2 new keys). Do not add the filesize exemption unless quality.py is
   invoked on touched files and blocks.
4. **`i18n_coverage_test.dart` must stay 3/3 green**: post-landing scan
   coverage of the five new keys — the `title:` key
   (`localizedNamedCopy`), the marker keys and the args-form message
   (`localizedCall`: `context.tr('...')` literal), and the tooltip
   occurrence (`'Clear local debug records'.localized`) — is all
   scan-covered, so zh parity for those occurrences is enforced at landing.
   The **only** scan-invisible occurrence left is the `confirmLabel:` named
   arg (documented gap, observation — scoped out per direction); its zh
   parity is pinned by the AC-2e widget test instead. (The old code's
   concat+interpolated message was unscannable; the args-form refactor is
   what makes the message key scan-covered — see F2.)
5. **`flutter test` runs debug-mode** → flag defaults `true` → all existing
   flag-sensitive tests (support tabs Clear flow, audit tab marker) exercise
   the visible surface by default; release semantics are only simulated via
   `debugRingEnabled = false` and guaranteed by const-folding.
6. **Release behavior by construction (shape-verified only)**:
   `_ringCopyEnabled = kDebugMode` folds to `false`; the getter returns
   `false`; marker + Clear branches fold out (the direct `kDebugMode &&`
   widget guard makes elimination structural, not getter-inlining-
   dependent); the const-gated setter makes any release flip unreachable.
   The fold itself is never executed by the debug suite (tests always
   compile debug-mode; `flutter test --release` does not exist on this
   toolchain) — it is verified by the AC-1 code-shape pins + the debug
   polarity tests (2a/2c) + the artifact gate (old-key absence in
   `build/web/main.dart.js`; the marker keys themselves stay
   release-reachable from `translate()`, so their *elimination* is not
   artifact-verifiable) — see §4 step 6. No
   `removeItem`/cleanup of `sso_audit_log` storage in this direction
   (b6-1a §1.2a: cleanup is a later step; a literal in release-reachable
   code would defeat the storage grep gate).
7. **Pattern-fallback fragility**: the OLD message key
   (`'This will permanently delete all {n} local audit entries.'`) is a
   `_sourcePattern`; after replacement, no runtime string can hit it. The
   NEW key is args-form (exact lookup). No stale pattern can resurrect
   since `_sourcePatterns` are rebuilt from the catalog at startup.
8. **Flag state is singleton-global** — any test flipping polarity must
   restore it in `addTearDown` (runs even after failures); `flutter test`
   isolates test files per-process, so the real risk is **intra-file
   ordering** (a dirty flag from AC-2c would break later flag-on tests in
   the same file) — hence the group-level `setUp` reset in AC-2.

## 3. Failure modes

| # | Failure | Trigger | Mitigation |
|---|---|---|---|
| F1 | zh silent English fallback on new keys | A zh value missing at landing | AC-1 exact key table + `translate(key) != key` unit assertions; `title:`/marker/tooltip/`context.tr` message occurrences additionally caught by `i18n_coverage_test` scan; only the `confirmLabel:` occurrence is scan-invisible (AC-2e pin) |
| F2 | Message relapses to concatenation form → only pattern fallback resolves zh; en drift then silently English | Refactor of `:285-286` back to string concat | AC-2e widget test pins the exact rendered zh string in a zh-locale pump; **scan-enforced**: the args-form `context.tr` literal is `localizedCall`-captured, so a concat relapse drops that scan coverage and fails the zh-parity gate at landing — keep `message:` args-form |
| F3 | `'Modify'` hazard (registered observation F2) — `AuditEntry.methodLabel` returns `'Modify'` (service `:30`), no zh key; if the marker surface ever renders it, zh → English | Future debug UI renders `methodLabel` | Marker renders static copy + count only; grep gate: `methodLabel` has zero consumers in `lib/screens`+`lib/widgets` (kept at zero) |
| F4 | Marker/Clear visible in release | Flag not const-gated, or second enable axis added | Const-gated setter + `kDebugMode`-only axis (b6-1a §1.2a rules); widget branch guarded by a direct `kDebugMode &&` (structural fold, per AMEND W2/S14); widget tests both polarities; code-shape gates: `kDebugMode` = 2 in `audit_log_service.dart` + 1 in `audit_log_tab.dart`, initializer line pinned to `_ringCopyEnabled = kDebugMode` (exactly 1) |
| F5 | Clear disappears when flag off → actions row layout shift | Release parity hiding | Intentional; no test asserts the delete icon in flag-off mode; flag-on is the test default |
| F6 | `admin_support_tabs_test:135` red | Label change | Same-change update (§1.4); tap by new confirm label |
| F7 | Catalog duplicate key silently overrides (spread order) | New key collides with another `app*SourceZh` | Grep uniqueness gate (§5 AC-1) |
| F8 | Flag leaks across tests (singleton static) | A polarity test without teardown | `addTearDown(() => AuditLogService.debugRingEnabled = true)` in every polarity test (AC-2a **and** AC-2c) + group-level `setUp` reset (intra-file ordering; precedent: wire-auditlogtab F2) |
| F9 | Old keys linger → `'Clear audit log?'` etc. become orphaned or double-render in some other surface | Partial replacement | Grep gate: old three keys zero hits in `lib/` after landing |
| F10 | `i18n_coverage_test` red on the new `title:` key if zh missing at landing | Catalog and tab landing in separate steps | Migration step 2 lands catalog before step 3 wires the tab (tree green at every step) |

## 4. Migration steps (ordered; each leaves the tree green)

1. **Service flag** — add `_ringCopyEnabled` + `debugRingEnabled` +
   `ringCopyEnabled` to `audit_log_service.dart`. No behavior change.
   Run `flutter test test/service_contracts_test.dart
   test/snaplink_admin_api_test.dart test/oidc_login_ring_isolation_test.dart`.
2. **Catalog** — replace the three Clear keys in place (`admin_core.dart`
   `:89,:90,:144`), add the two marker keys, all with zh. Run
   `flutter test test/i18n_coverage_test.dart` (3/3) and the AC-1 grep
   gates (old keys zero hits; new keys exactly one file; uniqueness).
3. **Tab wiring** — marker chip + gated Clear (direct `kDebugMode &&`
   guard) + args-form message in `audit_log_tab.dart`. Run
   `flutter test test/audit_log_tab_test.dart`.
4. **Regression consequence** — update `admin_support_tabs_test.dart:135`
   tap target. Run `flutter test test/admin_support_tabs_test.dart`.
5. **New AC-2 widget tests** (below) + teardown restoration. Run the full
   audit test file.
6. **Gate sweep — exact CI wiring** (test review A1 resolution; re-checked
   against the actual gate wiring at HEAD `26567d5` + B6-1a working tree).
   Run `flutter test` on the affected set: `audit_log_tab_test` (8 + new),
   `i18n_coverage_test` (3), `admin_support_tabs_test` (8),
   `admin_governance_security_test` (6), `snaplink_admin_api_test`,
   `oidc_login_ring_isolation_test`, `service_contracts_test`. Then wire
   the §5 AC-1 gates so they run on every landing:
   - **Source grep gates** land as a new check module
     `checks/b6_1b_gates.py` (repo pattern: `checks/` module exposing
     `run() -> int`; thresholds in `engineering.yaml`), added to
     `cmd_harness` in `cli.py`. CI already runs this as the
     **"Engineering gates" step of `.github/workflows/ci.yml`**
     (`python3 cli.py harness`, every push to main/master and every PR)
     — the gates execute on every landing with zero new CI wiring: old
     en + zh keys zero hits in `lib/`, five-key uniqueness, `kDebugMode`
     count = 2, initializer line-pin = 1, tab guard count = 1.
   - **Release-web artifact gate** (new): `make release-artifact-check`
     greps `build/web/main.dart.js` for the old-key needles and is
     invoked in `.github/workflows/ci.yml` as a step right after
     **"Build"** (`make build-prod`), which already produces the release
     web bundle on every push/PR. Verified at this working tree the gate
     is **non-vacuous — red today**: `Clear audit log?` ×2, `local audit
     entries` ×2, `Clear log` ×3 (raw ASCII survives dart2js
     minification), and the zh values in escaped form
     `\u6e05\u7a7a\u5ba1\u8ba1` (清空审计) / `\u672c\u5730\u5ba1\u8ba1`
     (本地审计) / `\u6e05\u9664\u65e5\u5fd7` (清除日志) ×1 each (dart2js
     emits non-ASCII as `\uXXXX` at this toolchain, Flutter
     3.47.0-0.4.pre) — all present in `build/web/main.dart.js`; after
     landing all vanish, proving the migration in the artifact itself.
     Mirror (optional): `.gitea/workflows/build.yml` may carry the same
     grep after its release build; `make verify` may compose it too.
   - **`flutter test --release` does NOT exist on this toolchain**
     (verified: no mode flag in `flutter test -h` nor in the
     `flutter_tools` `test.dart` option list). A `skip: kDebugMode`
     release-parity test can never execute — tests always compile
     debug-mode (`--run-skipped` runs it in debug, where
     `kDebugMode == true` and the fold is not exercised) — so the
     A1-proposed release-parity test is **not added**; the artifact gate
     above is the only executable release-mode verification available,
     and CI already builds the artifact it greps.
   - **Release parity statement (exact)**: runtime-false in release is by
     const semantics (const-init + const-gated setter + direct
     `kDebugMode &&` widget guard), verified by shape gates (AC-1 code
     shape) + the debug polarity tests (2a/2c) + the artifact gate above
     (old surface copy absent from the release bundle). Bundle
     *elimination* of the marker branch stays **shape-gated and
     optimizer-dependent**: the marker keys remain release-reachable
     through the catalog maps (`translate()`), so no artifact literal
     distinguishes folded-out vs present — only the *old* keys are
     artifact-discriminating (they are removed entirely). No release
     build is *required* for B6-1b's tests; the artifact gate reuses the
     release build CI already makes. The storage grep gate
     (`sso_audit_log`) remains owned by the storage seam step.
   - **Ordering contract for release cuts (b6-1a)**: CI enforces the
     gates above and nothing more. It cannot enforce §7.4 — a release
     cut containing B6-1b must not ship before the storage seam (§1.2a)
     lands, or must carry the §7.6 sentence; that is a release-process
     gate, not a CI gate (nothing greppable distinguishes the seam's
     absence until it lands). AC-1's `kDebugMode` counts hold only in
     the interim; the seam re-pins them (§7.5) — do not extend the count
     gates to the seam shape inside B6-1b.

## 5. Testable acceptance mapping

**AC-1 — key table + grep gates (exact; enforcement wiring per §4 step 6:
all source gates live in new `checks/b6_1b_gates.py` → `cli.py harness` →
ci.yml "Engineering gates" step; the artifact gate lives in
`make release-artifact-check` → ci.yml step after `make build-prod`)**
- New key set exactly: `'Clear local debug records?'`, `'This will
  permanently delete all {n} local debug records.'`, `'Clear local debug
  records'`, `'Debug records: {n} entries'`, `'Debug records'` — each
  present in `app_strings_source_admin_core.dart` with a zh value
  (`AppStrings.forLocale(Locale('zh')).translate(key) != key` unit
  assertion for all five). Final en+zh table: §1.2 (single noun 调试记录,
  adjudicated).
- Old en keys zero hits: `grep -rn "Clear audit log?\|local audit entries\|'Clear log'" lib/` → empty.
- Old zh values zero hits: `grep -rn '清空审计日志\|本地审计记录\|清除日志' lib/` →
  empty (collision-safe vs the new strings: `清除日志` ⊄ `清除本地调试记录`;
  `本地审计记录` ⊄ `这将永久删除全部 {n} 条本地调试记录。`).
- Uniqueness: each new key appears in exactly one `lib/i18n/*.dart` file —
  anchored `grep -Fx` per key (`'Debug records'` ⊂ `'Debug records: {n}
  entries'`; same file, verdict unchanged).
- Code shape: `grep -c "kDebugMode" lib/services/audit_log_service.dart` → 2
  (field init + setter guard) **and** `grep -n "_ringCopyEnabled = kDebugMode"
  lib/services/audit_log_service.dart` → exactly 1 (pins the foldable
  initializer — `= _compute()` or `= kReleaseMode` keeps the count at 2 but
  loses the fold) **and** `grep -c "kDebugMode" lib/screens/admin/audit_log_tab.dart` → 1
  (the direct `kDebugMode &&` widget guard).
- **Release-web artifact gate** (after `make build-prod` in CI; old keys
  must be absent from the release bundle):
  `grep -cF "Clear audit log?" build/web/main.dart.js` → 0;
  `grep -cF "local audit entries" build/web/main.dart.js` → 0;
  `grep -cF "Clear log" build/web/main.dart.js` → 0; plus the escaped-zh
  form (dart2js emits non-ASCII as `\uXXXX` — verified at this toolchain,
  Flutter 3.47.0-0.4.pre): `grep -cF '\u6e05\u7a7a\u5ba1\u8ba1'
  build/web/main.dart.js` → 0, likewise `'\u672c\u5730\u5ba1\u8ba1'`
  and `'\u6e05\u9664\u65e5\u5fd7'`. The zh escaped form is
  optimizer-dependent (a toolchain upgrade may change escaping) — the en
  needles are the stable pins, the zh variants are advisory. Verified
  non-vacuous: today all six needles are present in
  `build/web/main.dart.js` (en ×2/×2/×3, zh ×1 each); after landing they
  vanish, proving the surface copy migrated in the artifact itself.
- **Explicitly NOT gated on the artifact**: presence of the new marker
  keys in the release bundle. The catalog maps stay release-reachable
  through `translate()`, and dart2js dedups identical string literals —
  no bundle literal distinguishes "marker branch folded out" from
  "present". Bundle elimination remains shape-gated (the code-shape pins
  above + the const-gated setter) and optimizer-dependent; the debug-mode
  polarity tests (2a/2c) are the behavioral verification of the fold's
  semantics. Per §4 step 6, the b6-1a ordering contract (§7.4 — no
  release cut containing B6-1b before the §1.2a seam, or with §7.6
  language) is a release-process gate CI cannot enforce; these `kDebugMode`
  counts hold only in the interim and the seam re-pins them (§7.5).

**AC-2 — widget tests (`test/audit_log_tab_test.dart`, new group)** — pins
use the existing harness facts: `_seedForgedRing` records **exactly one**
ring entry, `_eventsBody` serves **two** rows with a `count: 999` decoy —
ring=1, rows=2, decoy=999 — so every marker/dialog pin below uses **1**, not
2 (reseeding the ring to 2 would make the marker-vs-header pin vacuous).
- 2a marker polarity: flag default → `'Debug records'` +
  `'Debug records: 1 entries'` (count from `_logService.count`) rendered;
  `debugRingEnabled = false` → both `findsNothing` and the actions row has
  no delete-sweep icon. Both polarity tests (2a and 2c) require
  `addTearDown(() => AuditLogService.debugRingEnabled = true)`; the group
  adds `setUp(() => AuditLogService.debugRingEnabled = true)` (intra-file
  order-independent reset, F8).
- 2b Clear dialog en: flag on → tap `Icons.delete_sweep` → dialog shows
  `'Clear local debug records?'` title, message
  `'This will permanently delete all 1 local debug records.'` (N = seeded
  ring count = 1), confirm `'Clear local debug records'`; confirm →
  `service.count == 0`; old strings (`'Clear audit log?'`,
  `'Clear log'`) `findsNothing`.
- 2c Clear hidden: flag off → `find.byIcon(Icons.delete_sweep)` findsNothing
  (+ teardown restore and group `setUp` reset as in 2a).
- 2d server-truth pins unchanged: `'2 entries'` from `_rows.length`
  (decoy `999` never rendered), CSV snackbar `'Exported 2 entries as CSV
  to clipboard'` from `_displayed.length` — existing assertions kept.
- 2e zh locale (flag on): marker `'调试记录：共 1 条'` + label
  `'本地调试记录'`; open Clear dialog → title `'清除本地调试记录？'`,
  message `'这将永久删除全部 1 条本地调试记录。'` (exact-key+args path —
  assert `find.textContaining('这将永久删除全部 1 条本地审计记录。')`
  findsNothing: the old zh key's rendered output is absent from the new
  string — needle sound, `调试` interrupts `本地|审计`), confirm
  `'清除本地调试记录'`. Note: this positive pin catches the harmful F2
  case (en drift → silent English); it cannot distinguish exact-key lookup
  from pattern-fallback *through the new key* — the args-form grep/scan
  gates carry that half.

**AC-3 — T-12 joint (forged rows stay non-evidence)**
- Existing `_seedForgedRing` assertions unchanged: forged
  `/api/v1/admin/forged`/`forged entry` never rendered across
  success/error/empty; header count is the served page size; the marker
  chip shows the *ring* count only in the debug badge — `'Debug records:
  1 entries'` vs header `'2 entries'`; strongest joint: reuse the AC-3c
  empty-server pump (rows=0, ring=1) asserting marker `'Debug records:
  1 entries'` + header `'0 entries'`, the only configuration where
  ring-vs-server-vs-decoy are pairwise distinguishable on the marker —
  never in the header count. `i18n_coverage_test` 3/3 green at landing.

**Regression consequence (registered)**
- `admin_support_tabs_test.dart:135` updated to the new confirm label
  (`find.text('Clear local debug records').last`) in the same change; the
  ring-only-clear + server-rows-stay behavior
  assertions (`service.count == 0`, `'2 entries'` findsOneWidget, forged
  absent) unchanged.

**Scoped out (registered observations, non-normative)**: `'Modify'`
methodLabel hazard (F2), the `message:`/`confirmLabel:` zh-parity scan gap,
palette description copy, storage-I/O seam (`debugStorageEnabled` +
`_save`/`_load` gating + debugPrint hardening), `sso_audit_log` release
grep gate, ring-removal cleanup.

## 6. Out of scope (hard boundary)

- `AuditLogService` storage I/O gating / ring removal (b6-1a §1.2a,
  pending direction).
- Any change to counter/CSV behavior or server-truth copy (drift recorded
  at spec level; no ring-scoped CSV key added).
- `i18n_coverage_test.dart` regex expansion for `message:`/`confirmLabel:`
  (gap registered, closed per-key by AC-2e instead).
- `'Modify'` / `methodLabel` i18n coverage; palette description copy.
- Any change outside `lib/i18n`, `lib/services/audit_log_service.dart`,
  `lib/screens/admin/audit_log_tab.dart`, and the two test files.

## 7. Residual release exposure — coordination note owed to b6-1a §1.2a (storage seam)

### 7.1 Verified residual (HEAD `26567d5` + uncommitted B6-1a)

- `snaplink_admin_api.dart:81-90` `_recordAudit` → `AuditLogService().record(...)`; sole
  call site `:324` inside `_request` (`if (method != 'GET')`) — every successful non-GET
  admin call records, in all builds. B6-1b changes zero bytes of this path.
- `audit_log_service.dart:108-112` `_save` / `:115-125` `_load` unconditionally
  read/write `sso_audit_log` (`:66`); the constructor `:60-62` calls `_load()`, so
  instantiating the service (`audit_log_tab.dart:36`) reads the key in release.
  `grep -rn kDebugMode lib/` → zero hits — the storage path has no gate today.
- B6-1b gates only the **copy surface**: marker + Clear (`audit_log_tab.dart:279,286,291`).

### 7.2 Payload sensitivity (SSO events)

Ring rows = `{timestamp ISO, method, path, statusCode, label}`. Observed mutation paths:
`/api/v1/admin/clients/{id}/rotate-secret`, `/api/v1/admin/devices/bulk-revoke`,
`/api/v1/admin/tokens/bulk-revoke`, `/api/v1/admin/credentials/{type}/compromise`,
`/api/v1/admin/break-glass/{id}/approve`, `/api/v1/admin/account-lockout/clear`,
`/api/v1/admin/compliance/retention-sweep`, `/api/v1/admin/crypto/keys/{id}/compromise`,
`/api/v1/admin/domains/{hostname}`, `/api/v1/admin/connections/{id}/...`. No bodies, no
query strings, no headers/tokens — nothing `SensitiveData` would redact, because there
is nothing to redact.

**Verdict: not credentials, but an SSO admin activity trail** — which client's secret was
rotated, which device/token set bulk-revoked, which break-glass approval granted, at
ISO-timestamp precision, with outcome — persisted per-origin with no integrity
(forgeable; T-12 pins rows as non-evidence), no eviction, and, once B6-1b lands, **no
user-visible surface and no purge affordance in release**. Exposure vectors:
same-origin script (localStorage is one read away from any XSS on the origin), browser
profile sync/backup, shared-device residue; the ring is intentionally untouched by
login/logout flows (`oidc_login_ring_isolation_test`).

### 7.3 Posture assessment

- **Coherent within scope**: hiding marker+Clear by const-folding is exactly
  "debug-only copy surface"; in release the surface is absent, not lying.
- **Incoherent as a claim about the ring**: "ring 降级为调试记录" holds only for the copy
  surface. In release the ring remains live (record + load + persist) with zero visible
  surface and zero purge path. As an end-state shipped without §1.2a this is a residual
  exposure, not a demotion.
- **Coherent only as a staged interim** if the ordering contract (§7.4) is honored and
  release notes say exactly what shipped (§7.6). Net delta of B6-1b alone: visibility ↓,
  data-at-rest unchanged, user purge agency ↓ (Clear was the ring's only purge
  affordance; hiding it in release removes agency without removing the data).

### 7.4 Ordering contract

B6-1b may land anytime, but **no release cut containing B6-1b may ship before the §1.2a
seam lands** unless the notes carry the §7.6 sentence. §1.2a is the step that makes the
ring release-inert; only after it lands may any note say the ring is debug-only.

### 7.5 Merge contract (single axis)

§1.2a lands `debugStorageEnabled`/`_storageEnabled`; B6-1b lands `debugRingEnabled`.
Whichever lands second folds both under one const-gated axis (b6-1a rules (a)–(d)
carry over: `kDebugMode` only, const-gated setter, tests flip both polarities).
Consequences:

- B6-1b AC-1 code-shape gate (`kDebugMode` hits in `audit_log_service.dart` = 2) holds
  **only in the interim**; the seam adds 3 more hits (field init + setter guard + two
  `if (!kDebugMode)` guards). The seam step re-pins the gate — do not extend the count
  gate to the seam shape inside B6-1b.
- After the merge, AC-2's flag-off becomes a true full-release simulation (surface
  hidden AND `LocalStorage.keys()` empty); until the merge, flag-off simulates
  **surface only** — B6-1b must not assert LocalStorage behavior (that belongs to the
  seam's tests).
- B6-1b AC-2 teardown (`debugRingEnabled = true`) follows the merged name.

### 7.6 Release-note language (exact)

- **B6-1b alone**: "Debug-ring marker and Clear action are hidden in release builds;
  ring recording and localStorage persistence are unchanged (pending the storage
  seam)."
- **After §1.2a**: "The local audit ring's storage I/O is debug-only; release never
  reads or writes `sso_audit_log`. Data left from before the seam is inert but not
  deleted — removal is the ring-removal cleanup step." Never "ring removed".
- Both directions do **no `removeItem`** (a literal in release-reachable code defeats
  the seam's artifact grep gate); notes must not imply deletion.

### 7.7 Test coupling

`snaplink_admin_api_test.dart:332-413` and `oidc_login_ring_isolation_test.dart:117-135`
assert `sso_audit_log` storage behavior — they run in debug (seam on) and stay green
through both steps; §1.2a rule (d) adds the flag-off storage assertions.
`snaplink_admin_api.dart:81/324` stays byte-identical through both steps.
