# B6-1b — Demote the localStorage ring to debug-only recording (kDebugMode seam + write-path isolation)

Direction: "Demote the localStorage ring to debug-only recording at the service boundary (kDebugMode gate + write-path isolation), completing T-12's forgery floor" — module `lib/screens` (B6-1b storage-seam wedge of b6-1a §1.2a). Scope: `lib/services/audit_log_service.dart` seam, scan 6 `ring-storage-seam`, nine drill regressions, new `test/audit_log_service_test.dart`, T-12 joint extension, gate re-pins. Spec: `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-spec.md` (REQ-1…REQ-7).

## 0. Evidence verification (claims re-checked, not trusted)

Every citation in the requirements spec was re-verified at HEAD `26567d5` + the uncommitted B6-1a/B6-1b working tree. Verdict per direction citation:

| # | Spec claim | Verified against the tree | Verdict |
|---|---|---|---|
| E1 | `audit_log_service.dart` — `_storageKey = 'sso_audit_log'` :66; `_save()` :126-134 / `_load()` :136-146 unconditional (`setItem` :130, `getItem` :138); B6-1b copy-surface gate `ringCopyEnabled` :69-86 gates display, not I/O | `grep -n` exact: `_storageKey` :66, `_ringCopyEnabled = kDebugMode` :76, setter guard :83, `setItem` :130, `getItem` :138. `kDebugMode` in the file = 2. `ringCopyEnabled` is consumed only at `audit_log_tab.dart:293` (display gate). `sso_audit_log` is the **only** hit in `lib/` (count 1) | ✅ |
| E2 | `snaplink_admin_api.dart` — `_recordAudit` :81-88, `record(` :82, call site :323-325, sole writer | `_recordAudit` :81-88, `AuditLogService().record(` :82, call site **:324** (drift from `:323-325`, cosmetic). Grep: `record(` over `lib/` hits only `lib/api/snaplink_admin_api.dart` + the service itself; `lib/screens/admin/snaplink_admin_api.dart` has zero hits | ✅ (line drift :324) |
| E3 | `oidc_login_audit_visibility_guard_test.dart` — literal-split needles over `lib/screens/oidc_login`, zero ring references | Confirmed: `@TestOn('vm')`, `dart:io` census, needles `['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log']` | ✅ |
| E4 | `audit_contract_guard_mutation_test.dart` + `audit_contract_guard_scans.dart` — scans 1/2/4/5 + runtime catalog-trio; `_scanWith` in-memory override; planted + documented-residual groups | Confirmed. `scanLibDirectory` runs 1/2/4/5 (`scanAuditPathLiterals`, `scanBffLiterals`, `scanRawStringification`, `scanSecondConsumer`); scan 3 runtime via `scanCatalogTrio`; `_scanWith` default scan set `{'audit-path-literals','bff-literals','raw-stringification'}`; residual group pattern exists. **Docstrings say "four scans" / "scans 1, 2, 4, and 5" — the spec's "five → six" is a count-normalization, not a literal edit** (see §1.3) | ✅ (docstring wording noted) |
| E5 | `implementation-gate.md:56` — console row 1 | Row 1 (B1-5): "localStorage ring 降级为调试记录；展示服务端记录" with T-12 joint | ✅ |
| E6 | b6-1a design — F7 :184, §1.2a :95-124, C3 :165, F13 :190, F16 :191, AC-7 :222, §4 :238 | All confirmed at the cited lines. §1.2a supplies the exact mandated seam shape (mutable static + const-folded init, const-gated setter, direct first-statement guards, rules (a)-(e)), the `String.fromCharCodes` last-resort policy, and the empirically verified DCE claim | ✅ |

Additional facts the spec builds on — all verified:

- **Direction-1 precondition already landed**: `audit_log_tab.dart` is server-fed via `AuditReadClient` (`:35-36` field, `:53` init, `:68` capability gate); `audit_log_tab_test.dart` asserts forged rows never render at `:144-145`, `:241-242`, `:273-274`, `:304-305` (AC-1.5, seeded via `AuditLogService().record(...)` in `_seedForgedRing`).
- **Key-scoped guard**: `LocalStorage` legitimately used in `lib/app_settings.dart`, `lib/services/cross_tab_sync.dart`, `lib/services/list_state_manager.dart`, `lib/screens/oidc_login/trusted_device_token.dart` (+ the wrapper itself) — none with the `sso_audit_log` key.
- **Gate re-pin is mandated**: `checks/config.py:84` `service_kdebug_count = 2`, `:86` `initializer_pin = "_ringCopyEnabled = kDebugMode"` (values overridden by `engineering.yaml:185,187`); `checks/b6_1b_gates.py` docstring: "the storage seam (b6-1a §1.2a) re-pins them when it lands". `cli.py:144` runs it in the harness; `ci.yml:38,41,44` = build-prod → release-artifact-check → harness.
- **Artifact needle non-vacuous**: `grep -cF 'sso_audit_log' build/web/main.dart.js` → **2 hits today** (the key is in the release bundle; after landing it must be DCE'd to 0).
- **Zero pre-existing hits** in `lib/` for `bool.fromEnvironment`, `assert(kDebugMode`, `String.fromCharCodes`; `debugPrint` with `$e` exists 2× (both catches at `:132`, `:146` — R2.6's pins start red **only inside the atomic landing**; see §4).
- **`kDebugMode` in `lib/`**: `audit_log_service.dart` 2× + `audit_log_tab.dart:293` 1× (display gate, unchanged; `tab_kdebug_count` stays 1).
- `LocalStorage.keys()` exists (`local_storage.dart:21`); VM tests use `local_storage_memory.dart` (isolate-local static map — deterministic, per-file-isolate state).

### Spec defect found at design stage (R2.4 as literally stated is unsatisfiable)

REQ-2 R2.4 pins: *"index of the **last** `if (!kDebugMode) return;` < index of the **first** `LocalStorage.` token"*. In the intended final layout this is **false**: `_save()`'s `LocalStorage.setItem` (stays at ~`:130`) textually precedes `_load()`'s guard pair (lands ~`:140`), so the last guard is *after* the first IO token. Landed code would trip its own pin. The design replaces R2.4 with a **per-function ordering pin** (§1.2) that is satisfiable by the landed layout, trips on every regression R2.4 was meant to catch (guards deleted; guards moved below the I/O; `setItem` hoisted into `record()`), and additionally trips on a new class (guards hoisted out of the functions). The acceptance mapping (§5, AC-2) tracks this correction.

### Scan-6 pin audit (empirical — `dart format` 3.12.0-168.0.dev + 28-case mutation matrix)

The pins as first drafted were transcribed verbatim into a throwaway harness, run against the `dart format` output of the §1.1 landed layout, and probed with a 28-case mutation matrix covering every guard drop/hoist/reorder plus legitimate-edit probes. Verdict: **two genuine defects fixed below (F1, F2), one drill-anchor rot fixed (F3), two vacuity/robustness gaps closed (F4, F5), one boundary documented (F6) — zero false positives on formatter/linter output**.

- **F1 (false positive — the drafted layout tripped its own pin, fixed §1.1)**: the seam doc comment as drafted contained the literal `sso_audit_log` ("the `sso_audit_log` constant is dead-code-eliminated…"), so `keyHits == 2` and R2.1 went red on the very layout it describes. The scan pins are whole-source regexes; comments count. Reworded to "the storage-key constant" — verified `keyHits == 1` on the landed file. The existing class doc comment ("…in memory and localStorage.") is safe: `localStorage` matches no pin.
- **F2 (false negative — the hoist class escaped, fixed §1.2)**: the ordering pins count guard occurrences *before* the IO tokens **globally**, so a guard pair hoisted into the constructor, `record()`, `clear()`, either setter, or above the class keeps `before(setItem) == 4`, `before(getItem) == 6`, `pairs == 2` and every count pin green — an unguarded `_save()` (release would write the key; `clear()` → `_save()` is unconditional) was **scan-green** in the harness. The new **function-head pair pin** anchors each pair to its function signature and closes FD-7: all 8 hoist placements (per-pair, both-pairs, five targets) now trip.
- **F3 (drill-anchor rot — rows (a)/(b) could not match their target, fixed §1.4)**: the anchors as drafted (`'if (!kDebugMode) return;\n    if (!_storageEnabled) return;'`) match **0 times** on the landed layout, because both kDebug guard lines carry trailing comments (`// first statements, before the try` / `// same shape`). `replaceFirst` would no-op and the anchor-rot guard would fail the rows on the very layout they exist for. Anchors now use the §1.1-verbatim commented spellings — which are **unique per pair**, since the two pairs' comments differ. Rows (c), (d), (e), (f), (g), (h), (i) verified present with correct first-occurrence semantics (row (c): 2 hits, first = `record()`'s tail; row (g): 1 hit at `snaplink_admin_api.dart:82`; row (i): 2 hits, first = `_save`'s catch).
- **F4 (registration vacuity, fixed §1.3)**: the AC-3.6 group as drafted (live-tree green + direct unit probes) cannot detect a dropped `scanLibDirectory` registration of scan 6 — the drill rows exercise `_scanWith`, a *separate* registration. Added a temp-tree probe that runs `scanLibDirectory` over a directory containing `services/audit_log_service.dart` with one guard removed and asserts the scan-6 violation is reported. (The ordering pin itself is non-vacuous against missing IO: `indexOf == -1` → `before(-1) == 0 ≠ 4` trips.)
- **F5 (python-mirror regex trap, fixed §1.7)**: `if (!kDebugMode) return;` is an `rg` regex-metacharacter soup — the naive pattern matches **0 lines** (verified), which would make the new `b6_1b_gates.py` check red on the landed layout. The check must use fixed-string matching (`_grep(..., fixed=True)`), as the design already does for the artifact needles.
- **F6 (documented boundary)**: swapping the IO calls between the two gated functions (`_save` reads / `_load` writes, both still gated) is scan-6-green — and release-safe. The behavior tests R4.1-R4.4 own this class (flag-on write-path assertions go red). Recorded in §1.4's residual group.

Verified green on `dart format` output (byte-stable, idempotent — `dart format` re-run produced no diff): `kDebugMode` 6 occurrences on 6 lines (2 initializers + 4 guards), direct guards 4, IO tokens 2, key literal 1, `_storageEnabled = value` 1, ordering 4 before `setItem` / 6 before `getItem`, adjacency pairs 2, function-head pairs 2. `dart analyze` on the seam shape is clean (only sandbox URI-resolution noise outside a package context). Legitimate edits verified green: a comment line between a signature and its guard; extra doc comments without pinned tokens; doc-comment rewordings that avoid the pinned tokens.

## 1. API changes

### 1.1 `lib/services/audit_log_service.dart` — storage seam (REQ-1, b6-1a §1.2a verbatim)

Two additive members (same shape as the landed `_ringCopyEnabled`/`debugRingEnabled` pair) + two guard insertions + one message change. Public instance API (`record`/`entries`/`search`/`filterByMethod`/`recent`/`clear`/`count`) is **untouched** (C3 — `service_contracts_test.dart:18-37` and `snaplink_admin_api.dart:81-88,324` stay green).

```dart
// After the existing debugRingEnabled setter (~:85):
  /// Debug-only storage seam (b6-1a §1.2a): storage I/O is demoted to
  /// debug-only recording. Const-folded to `false` in release/profile —
  /// no release-reachable code can enable it (the setter is const-gated),
  /// so `_save`/`_load` are structural no-ops and the storage-key
  /// constant is dead-code-eliminated from release bundles. (No pinned
  /// token in any service-file comment — the scan pins are whole-source
  /// regexes; F1/C12.)
  static bool _storageEnabled = kDebugMode;

  /// Debug-only test axis: false simulates release (no storage I/O),
  /// true exercises the ring path. Assignment unreachable in release.
  @visibleForTesting
  static set debugStorageEnabled(bool value) {
    if (!kDebugMode) return; // const-folds to `return;` in release.
    _storageEnabled = value;
  }
```

```dart
  void _save() {
    if (!kDebugMode) return;      // first statements, before the try
    if (!_storageEnabled) return;
    try {
      final jsonStr = jsonEncode(_entries.map((e) => e.toJson()).toList());
      LocalStorage.setItem(_storageKey, jsonStr);
    } catch (e) {
      debugPrint('audit_log storage error: ${e.runtimeType}');
    }
  }

  void _load() {
    if (!kDebugMode) return;      // same shape
    if (!_storageEnabled) return;
    try {
      final jsonStr = LocalStorage.getItem(_storageKey);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final list = jsonDecode(jsonStr) as List;
        _entries.addAll(
          list.map((e) => AuditEntry.fromJson(Map<String, dynamic>.from(e))),
        );
      }
    } catch (e) {
      debugPrint('audit_log storage error: ${e.runtimeType}');
    }
  }
```

Rules carried from §1.2a (a)-(e): both functions gated (release neither reads nor writes; ring stays memory-only, bounded 1000); setter const-gated (assignment unreachable in release); `kDebugMode` the **only** axis (no `bool.fromEnvironment`); no `removeItem` (leftover storage provably inert — deleting the key would require the literal in release-reachable code and defeat the artifact gate; the **sole legal deletion** is the pre-seam bootstrap purge of §4 step 2, removed by the landing); both catches print constant message + `e.runtimeType` only, never `$e` (F16 — note `${e.runtimeType}` does **not** contain the `$e` substring; `$` is followed by `{`). `_recordAudit` at `snaplink_admin_api.dart:81-88,324` is **unchanged** — write-path isolation is achieved at the service boundary; call-site gating is walled (§6).

### 1.2 Scan 6 `ring-storage-seam` (REQ-2, with the corrected R2.4)

New per-file scan in `test/audit_contract_guard_scans.dart`, registered in `scanLibDirectory` and in the mutation drill's `_scanWith` default scan set. Key-scoped, occurrence semantics identical to `checks/b6_1b_gates.py`'s `_grep` (`allMatches` vs `rg -o`; each pinned line contains exactly one occurrence, so line counts agree as well — W-3/W-4).

```dart
/// Scan 6 — ring-storage-seam source guard (b6-1a §1.2a / F13 / S14-S16).
///
/// Key-scoped: `LocalStorage` is legitimately used by other lib/ services
/// (app_settings, cross_tab_sync, list_state_manager,
/// trusted_device_token) — the pin is the `sso_audit_log` key literal,
/// never call-scope. Absence is lib-wide; positive pins are per-file on
/// `services/audit_log_service.dart`.
List<AuditGuardViolation> scanRingStorageSeam(
  String source,
  String fileLabel,
) {
  final violations = <AuditGuardViolation>[];
  final isService = fileLabel == 'services/audit_log_service.dart';
  final keyHits = 'sso_audit_log'.allMatches(source).length;
  if (!isService && keyHits > 0) {
    violations.add(AuditGuardViolation(
      scan: 'ring-storage-seam',
      file: fileLabel,
      detail: 'sso_audit_log literal outside the service file '
          '(must live only in audit_log_service.dart) — F13 S16',
    ));
  }
  if (!isService) return violations;
  if (keyHits != 1) violations.add(AuditGuardViolation(
    scan: 'ring-storage-seam', file: fileLabel,
    detail: 'sso_audit_log literal count == ${keyHits}, pinned 1'));
  final kDebugLines = RegExp(r'kDebugMode').allMatches(source).length;
  if (kDebugLines != 6) violations.add(AuditGuardViolation(
    scan: 'ring-storage-seam', file: fileLabel,
    detail: 'kDebugMode lines == $kDebugLines, pinned 6 '
        '(2 initializers + 4 direct guards)'));
  final guardLines =
      RegExp(r'if \(!kDebugMode\) return;').allMatches(source).length;
  if (guardLines != 4) violations.add(AuditGuardViolation(
    scan: 'ring-storage-seam', file: fileLabel,
    detail: 'direct guards == $guardLines, pinned 4 '
        '(copy setter + storage setter + _save + _load)'));
  if (!source.contains('static bool _storageEnabled = kDebugMode;')) {
    violations.add(AuditGuardViolation(
      scan: 'ring-storage-seam', file: fileLabel,
      detail: 'foldable storage initializer missing'));
  }
  if (RegExp(r'_storageEnabled = value').allMatches(source).length != 1) {
    violations.add(AuditGuardViolation(
      scan: 'ring-storage-seam', file: fileLabel,
      detail: '_storageEnabled = value must appear exactly once '
          '(const-gated setter)'));
  }
  final ioTokens = RegExp(r'LocalStorage\.').allMatches(source).length;
  if (ioTokens != 2) violations.add(AuditGuardViolation(
    scan: 'ring-storage-seam', file: fileLabel,
    detail: 'LocalStorage. tokens == $ioTokens, pinned 2 '
        '(one setItem in _save, one getItem in _load)'));
  // Corrected R2.4 (spec R2.4 as literally stated fails on the landed
  // layout): per-function ordering — _save's setItem must sit after
  // exactly 4 guard lines, _load's getItem after exactly 6 (the two
  // setter guards + _save's pair + _load's pair). These counts own the
  // drops, below-IO moves, and cross-function reorders; the hoist class
  // is owned by the function-head pair pin below (F2).
  final guards = <Match>[
    ...RegExp(r'if \(!kDebugMode\) return;').allMatches(source),
    ...RegExp(r'if \(!_storageEnabled\) return;').allMatches(source),
  ]..sort((a, b) => a.start.compareTo(b.start));
  final setItem = source.indexOf('LocalStorage.setItem');
  final getItem = source.indexOf('LocalStorage.getItem');
  int before(int idx) => guards.where((m) => m.start < idx).length;
  if (before(setItem) != 4 || before(getItem) != 6) {
    violations.add(AuditGuardViolation(
      scan: 'ring-storage-seam', file: fileLabel,
      detail: 'guard-before-IO ordering broken: ${before(setItem)} guards '
          'before setItem (pinned 4), ${before(getItem)} before getItem '
          '(pinned 6) — S14 direct-first-statement guards'));
  }
  // Pair adjacency: each function's direct guard is immediately followed
  // by the _storageEnabled guard (2 pairs; the setter guards are followed
  // by assignments, so they cannot be counted here).
  final lines = source.split('\n');
  var pairs = 0;
  for (var i = 0; i + 1 < lines.length; i++) {
    if (lines[i].contains('if (!kDebugMode) return;') &&
        lines[i + 1].contains('if (!_storageEnabled) return;')) {
      pairs++;
    }
  }
  if (pairs != 2) violations.add(AuditGuardViolation(
    scan: 'ring-storage-seam', file: fileLabel,
    detail: 'direct-guard pairs == $pairs, pinned 2 (one per function)'));
  // Function-head pair pin (closes FD-7 — F2): each of _save/_load must
  // open with the direct guard followed by the storage guard, anchored to
  // the function signature. The ordering pins above count guards before
  // the IO tokens globally, so a pair hoisted into the constructor,
  // record(), clear(), a setter, or above the class keeps every count
  // green; this pin is what makes the FD-7 claim true. Comments/blanks
  // between the signature and the guard are allowed (the guards remain
  // the first *statements*); a statement line there breaks the pattern.
  final fnPairPattern = RegExp(
    r'void (_save|_load)\(\) \{\n'
    r'(?:    (?://|///)[^\n]*\n|[ \t]*\n)*'
    r'    if \(!kDebugMode\) return;[^\n]*\n'
    r'    if \(!_storageEnabled\) return;');
  final fnPairs = fnPairPattern.allMatches(source).length;
  if (fnPairs != 2) violations.add(AuditGuardViolation(
    scan: 'ring-storage-seam', file: fileLabel,
    detail: 'function-head guard pairs == $fnPairs, pinned 2 — each of '
        '_save/_load must open with the direct guard + storage guard '
        '(FD-7 hoist class)'));
  // Bans (F13/F16/S15): zero in-tree today, must stay zero.
  for (final needle in const [
    'assert(kDebugMode',
    'bool.fromEnvironment',
    'String.fromCharCodes',
    'base64Decode', // open finding 1 — mirror of the python-gate ban
    'base64Url', // same; also covers base64UrlDecode
  ]) {
    if (source.contains(needle)) violations.add(AuditGuardViolation(
      scan: 'ring-storage-seam', file: fileLabel,
      detail: 'banned $needle present (F13 last-resort/second-axis)'));
  }
  if (RegExp(r'debugPrint\([^)]*\$e').hasMatch(source)) {
    violations.add(AuditGuardViolation(
      scan: 'ring-storage-seam', file: fileLabel,
      detail: 'debugPrint interpolates \$e — F16 payload echo'));
  }
  return violations;
}
```

Pin arithmetic on the landed layout (verified by construction): `kDebugMode` lines = `_ringCopyEnabled` init, copy-setter guard, `_storageEnabled` init, storage-setter guard, `_save` guard, `_load` guard = **6**; direct guards = 4; guard lines before `setItem` = copy-setter + storage-setter + `_save` pair = **4**; before `getItem` = **6**; adjacency pairs = `_save` pair + `_load` pair = **2**; function-head pairs = **2**; `LocalStorage.` tokens = **2**. All empirically verified on the `dart format` output of the §1.1 layout (see §0 audit), including the 28-case mutation matrix.

### 1.3 Registration and docstring normalization (REQ-2.7)

- `scanLibDirectory`: add `violations.addAll(scanRingStorageSeam(source, relative));` — the baseline tests in `audit_contract_guard_test.dart` (`AC-3.1…`) and the mutation baseline then exercise it automatically.
- `AuditGuardViolation.scan` doc comment gains `ring-storage-seam`.
- `_scanWith` default scan set gains `'ring-storage-seam'` and its loop calls the new scan per file.
- Docstring count normalization: `audit_contract_guard_scans.dart` ("The four scans", "Runs scans 1, 2, 4, and 5") and `audit_contract_guard_test.dart` ("the corrected four scans") → **six scans** (1 audit-path-literals, 2 bff-literals, 3 catalog-trio, 4 raw-stringification, 5 second-consumer, 6 ring-storage-seam). The spec's "five → six" is satisfied by this normalization; the currently-true text is "four" in `scanLibDirectory`'s context.
- New `AC-3.6 ring-storage-seam scan` group in `audit_contract_guard_test.dart`: live-tree green test + unit probes (a mutated probe string missing one guard trips; a probe with `LocalStorage.` outside the service trips) — mirroring the AC-3.1 group shape — **plus an anti-vacuity probe (F4)**: write `services/audit_log_service.dart` with one guard removed into a temp tree, run `scanLibDirectory` over it, and assert the scan-6 violation is reported. This catches a dropped `scanLibDirectory` registration, which the live-tree green test and the drill rows (they exercise `_scanWith`, a separate registration) cannot.

### 1.4 Mutation drill rows (REQ-3) — anchors against the landed file

Each row: `_libSource('services/audit_log_service.dart')` (or `api/snaplink_admin_api.dart` for g), mutate with `replaceFirst` on the anchor below, assert `expect(mutated, isNot(source))` (anchor-rot guard, FD-10), run `_scanWith` with the `ring-storage-seam` scan, assert `violations.where((v) => v.scan == 'ring-storage-seam')` non-empty. Baseline (unmutated tree) must stay green. Anchors are the **§1.1-verbatim spellings, trailing guard comments included** (F3) — if an implementation drops a trailing comment, the anchor-rot guard fails the row loudly and both are updated together.

| Row | Mutation (anchor → replacement) | Trips |
|---|---|---|
| (a) | `'if (!kDebugMode) return; // first statements, before the try\n    if (!_storageEnabled) return;'` → `''` (`_save`'s pair; the comment makes the anchor unique — `_load`'s guard carries `// same shape`) | R2.2 (4→3), R2.4 (4→3 before setItem), fn-pair pin (F2) |
| (b) | same anchor → `'assert(kDebugMode);\n    if (!_storageEnabled) return;'` | R2.2, R2.6 (`assert(kDebugMode`), R2.4, fn-pair pin |
| (c) | `'    _save();\n  }'` → `"    LocalStorage.setItem(_storageKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));\n  }"` (first occurrence = `record()`'s tail; `clear()` shares the shape but comes later) | R2.5 (3 tokens), R2.4 (2 before first setItem) |
| (d) | `'static bool _storageEnabled = kDebugMode;'` → `"static bool _storageEnabled = kDebugMode || bool.fromEnvironment('ringStorage');"` | R2.6 |
| (e) | `'  static set debugStorageEnabled(bool value) {\n    if (!kDebugMode) return;'` → `'  static set debugStorageEnabled(bool value) {'` | R2.2 (4→3), R2.4 |
| (f) | `'static bool _storageEnabled = kDebugMode;'` → `'static bool _storageEnabled = true;'` | R2.3 |
| (g) | in `api/snaplink_admin_api.dart`: `"AuditLogService().record("` → `"AuditLogService().record( /* sso_audit_log */ "` (comment injection; in-memory only) | R2.1 |
| (h) | `"static const String _storageKey = 'sso_audit_log';"` → `'static const String _storageKey = String.fromCharCodes([115,115,111,95,97,117,100,105,116,95,108,111,103]);'` | R2.6 |
| (i) | `"debugPrint('audit_log storage error: \${e.runtimeType}');"` → `"debugPrint('audit_log storage error: \$e');"` (raw-string spelling in the drill source) | R2.6 |

**Documented residuals** (same class as the existing split-literal residuals):
- adjacent-literal key split (`'sso_' 'audit_log'`) evades R2.1 at source level; the concatenated constant still lands the full string in the release bundle, so the artifact gate (R6.3) is the backstop — record in the mutation file's residual group with the artifact-gate note;
- **decoy-literal evasion** (open finding 1 residual): the pinned literal kept in the service file (unused, DCE'd) while real I/O uses a reconstructed key passes every source pin; the artifact needles — the key literal plus its base64/base64Url encodings — are the backstop (the reconstructed bytes ship unless hidden further); deliberate reintroduction is a manual-review matter, not a gate one;
- **F6 boundary**: swapping the IO calls between the two gated functions (`_save` reads / `_load` writes, both still gated) is scan-6-green and release-safe; the R4.1-R4.4 write-path behavior tests own it (flag-on assertions go red) — record as a documented boundary, not a residual escape.

### 1.5 Behavior tests — new `test/audit_log_service_test.dart` (REQ-4)

Per-file-isolate singleton semantics: `_load()` runs exactly once per file, at first `AuditLogService()` construction. Hence the **construction-order contract**: the load-off test MUST be the first test in the file, and its teardown must remove the seeded key so later tests observe clean storage. Test order within the file is declaration order (default). Layout:

1. **Load path, flag off (first test, contract)**: `AuditLogService.debugStorageEnabled = false;` → `LocalStorage.setItem('sso_audit_log', <forged JSON>)` → `addTearDown(() => LocalStorage.removeItem('sso_audit_log'))` (test-code `removeItem` is allowed — only `lib/` is scanned and bundled) → construct `AuditLogService()` (first construction in this isolate) → `entries` empty (gated read), stored payload **byte-identical**, key still present (no read, no `removeItem` in lib/ — R1.7).
2. **Flag-off persistence**: re-seed, `record()` 3× then `clear()` → payload byte-identical (write isolation; `_save` no-ops).
3. **Write path, flag off**: `debugStorageEnabled = false`; `record()` 3 distinct entries → `LocalStorage.keys()` contains no `sso_audit_log`, `getItem` null; `entries`/`count`/`search`/`filterByMethod`/`recent`/`clear` still work **in memory** (C3).
4. **Write path, flag on**: `debugStorageEnabled = true` (addTearDown restores `true` — the default — plus `service.clear`); `record()` 3 → key present, JSON decodes to exactly 3, first entry most recent, wire fields `{timestamp, method, path, statusCode, label}` intact; `clear()` → key present with `[]`.

Load-on polarity needs no new test: every existing ring test constructs with the default axis on (acceptance #4 pins them); F16's echo concern is enforced statically by R2.6.

### 1.6 T-12 joint extension — `test/audit_log_tab_test.dart` (REQ-5)

- Keep AC-1.5 assertions (`:144-145`, `:241-242`, `:273-274`, `:304-305` — service-record-seeded forged rows never render).
- New raw-devtools variant: seed `LocalStorage.setItem('sso_audit_log', jsonEncode([<forged row with path '/api/v1/admin/forged'>]))` **before** the page pump (bypassing `AuditLogService().record`), teardown `LocalStorage.removeItem('sso_audit_log')`. Assert `find.textContaining('/api/v1/admin/forged')` and `'forged entry'` findsNothing in **both polarities**:
  - on (default; kDebugMode in tests): nothing to set;
  - off: `AuditLogService.debugStorageEnabled = false;` + `addTearDown(() => AuditLogService.debugStorageEnabled = true)` (restores the default for later tests in the file), and additionally assert the raw payload is **byte-identical** afterwards (the tab never writes the ring).
- R5.3: the assertion is conditioned on the server-fed timeline (already landed); if that read path is reverted, this check is blocked (B1-5), not silently green — note in the test comment.

### 1.7 Gate re-pins (REQ-6) — exact diffs

`engineering.yaml` `b6_1b_gates:` block:
```yaml
  service_kdebug_count: 6          # was 2 (interim pre-seam value)
  tab_kdebug_count: 1              # unchanged
  initializer_pin: "_ringCopyEnabled = kDebugMode"      # unchanged
  storage_initializer_pin: "_storageEnabled = kDebugMode"  # NEW
  artifact_en_needles:
    - "Clear audit log?"
    - "local audit entries"
    - "Clear log"
    - "sso_audit_log"              # NEW (F13 artifact gate)
```
`checks/config.py` `B61bGatesConfig`: `service_kdebug_count: int = 6`, add `storage_initializer_pin: str = "_storageEnabled = kDebugMode"`; update the docstring's interim note (the seam has landed — the counts are now final).

`checks/b6_1b_gates.py` — add three checks (same result-list pattern):
- `storage_initializer_pin` in the service file == exactly 1;
- `if (!kDebugMode) return;` in the service file == exactly 4 (mirror of R2.2 — the python gate and the Dart scan cannot disagree). **Must call `_grep(pattern, service, fixed=True)`**: as an `rg` regex the `(`,`)`,`!` are metacharacters and the naive pattern matches 0 lines (verified — F5), which would make the gate red on the landed layout;
- `sso_audit_log` matches exactly one file under `lib/` and that file resolves to `lib/services/audit_log_service.dart` (`_files_with` + resolve, mirror of R2.1).
Update the module docstring (remove the "interim" deferral).

`Makefile` `release-artifact-check` — add after the `Clear log` line:
```makefile
	@test "$$(grep -cF 'sso_audit_log' build/web/main.dart.js)" = "0" || { echo 'FAIL: "sso_audit_log" still in release bundle'; exit 1; }
```
Non-vacuous: 2 hits in today's bundle; post-seam the const is DCE'd (empirically verified for this exact shape in b6-1a §1.2a) → 0.

**Gate hardening deltas (post-review, landed in the working tree)** — same values as the diffs above, with the open-finding extensions:

- **Mask ban mirrored (open finding 1)**: `engineering.yaml`/`checks/config.py` gain `banned_service_tokens: [String.fromCharCodes, base64Decode, base64Url]` — each must be **absent** from the service file (fixed-string, `_grep(fixed=True)`), and scan-6's ban loop (§1.2) gains the same two base64 tokens so both mechanisms agree (FD-5 class). The ban is service-file-scoped on purpose: `base64Decode`/`base64Url` are legitimate idioms in `portal_api.dart`/`token_refresh_service.dart`/`federated_login.dart`. The artifact side of the mask: `artifact_key_masks` needles `c3NvX2F1ZGl0X2xvZw==` (base64) and `c3NvX2F1ZGl0X2xvZw` (base64Url) — a masked write ships the encoded text even though the source pins see no literal. **Documented residual — decoy-literal evasion**: keeping the pinned literal in the service file (unused, DCE'd) while doing real I/O with a reconstructed key passes every source pin; the artifact needles then carry the burden (reconstructed bytes land in the bundle unless hidden further), and deliberate reintroduction is a manual-review matter, not a gate one.
- **Recursive artifact needle (open finding 2)**: `artifact_dir: build/web` replaces the single-file path; `make release-artifact-check` uses `grep -rI -oF ... build/web/` and the python gate scans the directory — a chunked build cannot silently widen the surface.
- **Occurrence semantics (W-3/W-4)**: the Makefile baseline is `grep -oF | wc -l`, not `grep -cF` (line count); `checks/b6_1b_gates.py`'s `_grep` uses `rg -o` (one line per match = occurrence count). Both now match scan-6's `allMatches` — FD-5's "identical semantics" is occurrence semantics, not line semantics. The `== 2` pre-seam baseline holds only as an occurrence count (two const inlined literals: setItem/getItem); a future dart2js that emits both on one line keeps `== 2` by occurrence but reads `== 1` by line.
- **Fail-closed (open finding 5)**: a missing `build/web` is a **failure** in the python gate (no silent skip — the old `artifact.exists()` skip is gone) and the Makefile target opens with `test -d build/web` (a grep failure inside `$()` would otherwise read as 0; `set -euo pipefail` is belt-and-suspenders).
- **W-1/W-2**: the `sso_audit_log` needle is live in both gates — a fresh pre-seam bundle (2 occurrences) is red, so the gate is no longer green independent of the seam.

## 2. Compatibility constraints

| # | Constraint | Enforcement |
|---|---|---|
| C1 | `AuditLogService` public API unchanged (`record`/`entries`/`search`/`filterByMethod`/`recent`/`clear`/`count`, `AuditEntry`) | `test/service_contracts_test.dart` `AuditLogService` group (:18) green |
| C2 | `_recordAudit` at `snaplink_admin_api.dart:81-88,324` unchanged; zero edits to `lib/api/` | REQ-7 `snaplink_admin_api_test.dart` ring-liveness (:330+) green; no diff in the change |
| C3 | Debug-mode behavior identical (flag defaults on via `kDebugMode` in `flutter test`/debug builds) | Full REQ-7 list green unchanged (see §5, AC-4) |
| C4 | Release: ring memory-only, key DCE'd from the bundle, leftover storage provably inert (never read/written, no `removeItem`) | `make release-artifact-check` (needle == 0), scan 6 bans |
| C5 | Key-scoped: the four other `LocalStorage` consumers (`app_settings`, `cross_tab_sync`, `list_state_manager`, `trusted_device_token`) untouched — the gate pins the `sso_audit_log` literal, never call-scope | Scan 6 R2.1 (count == 1) |
| C6 | `audit_log_tab.dart` untouched (display gate `ringCopyEnabled` :293 unchanged; `tab_kdebug_count` stays 1) | REQ-7 audit-log-tab tests green |
| C7 | `kDebugMode` the only enable axis; `assert` never used as the gate | Scan 6 bans + const-gated setter shape |
| C8 | Test files may use `removeItem` and contain the key literal (teardown hygiene, raw-seeding); scans scope to `lib/` only | Scan roots unchanged; artifact gate scans the bundle, not `test/` |
| C9 | Gate re-pins (config + harness + Makefile needle) land **atomically with the seam** — every gate green at every commit | §4 step 3 is a single change (the step-2 purge removal, 3h, is inside it); `python cli.py harness` + artifact check green post-landing |
| C10 | T-12 joint is conditioned on the landed server-fed timeline (direction 1); blocked, not faked, if that read path is reverted | R5.3 note in `audit_log_tab_test.dart` |
| C11 | `_recordAudit` call-site gating is a **deviation**, rejected on sight | §6 wall; review gate |
| C12 | No pinned token in any service-file comment (`sso_audit_log`, `LocalStorage.`, extra `kDebugMode`, `_storageEnabled = value`, banned needles) — the pins are whole-source regexes, comments count | Scan 6 (any mention trips loudly, FD-13); §1.1 wording verified clean (F1) |

## 3. Failure modes

| ID | Failure | Detection | Mitigation / response |
|---|---|---|---|
| FD-1 | Spec R2.4 as literally stated trips the landed layout (last guard after first `LocalStorage.`) | Design-stage analysis (§0) | Corrected per-function pin: exactly 4 guard lines before `setItem`, 6 before `getItem`, adjacency pairs == 2 (§1.2) |
| FD-2 | dart2js keeps the key (DCE regression) | Artifact gate red | Gate is the verdict; fix is structural (direct guards first). `String.fromCharCodes` fallback **banned** (masks the failure, key recoverable from the int array — §1.2a) |
| FD-3 | Test-order coupling in the new file (static flag leaks between tests; singleton already constructed) | Order-dependent passes/flakes | First-test construction-order contract + `addTearDown` protocol (restore flag `true`, remove seeded key) (§1.5) |
| FD-4 | R4.3 goes silently vacuous (singleton constructed before seeding in the isolate) | `entries` non-empty would fail loudly; no silent path | First-test contract documented in the file doc comment; scan 6 keeps the static shape honest |
| FD-5 | Python gate and Dart scan counts drift apart | Two mechanisms disagree on the same tree | Identical **occurrence** semantics (`rg -o` in `b6_1b_gates.py` vs `allMatches` in scan 6 — W-3/W-4); `if (!kDebugMode) return;` == 4 and `sso_audit_log` == 1 mirrored in both (§1.7) |
| FD-6 | Adjacent-literal key split evades R2.1 at source level | Source-level residual (documented) | Concatenated const still lands the full string in the bundle → artifact gate closes it (§1.4 residual) |
| FD-7 | Guard pair hoisted out of `_save`/`_load` (into the constructor, `record()`, `clear()`, a setter, or above the class) | Function-head pair pin (`fnPairs != 2`) — the ordering counts stay 4/6 for these placements and are not the trip (F2) | FD-7; the hoisted layout is release-writing (`clear()` → `_save()` unconditional) and also trips R6.3; both layers verified |
| FD-8 | Setter assignment deleted/moved | `_storageEnabled = value` count != 1 | Scan pin + behavior tests (flag toggling stops working → R4.2/R4.4 red) |
| FD-9 | Artifact gate vacuous (key absent because the bundle wasn't rebuilt, not because it was DCE'd) | `b6_1b_gates.py` skips a missing artifact; Makefile runs after `build-prod` in CI | CI ordering (build-prod → artifact-check) pins the sequence; needle proven non-vacuous today (2 hits) |
| FD-10 | Drill anchors rot as the file evolves | `expect(mutated, isNot(source))` fails → row is red, never silently green | Anchor-rot guard on every row (§1.4) |
| FD-11 | F16 echo reintroduced via a differently-spelled print | R2.6 regex `debugPrint\([^)]*\$e` | Scan ban; catch messages are pinned constants |
| FD-12 | Second enable axis sneaks in (env var, `fromEnvironment`) | R2.6 ban + artifact gate (any axis that works in release re-lands the key in the bundle) | Banned; C7 |
| FD-13 | Service-file comment mentions a pinned token (`sso_audit_log`, `LocalStorage.`, extra `kDebugMode`, `_storageEnabled = value`, banned needles) | Scan pins are whole-source regexes — any mention trips loudly, never silently | F1: §1.1 wording verified clean; landed-layout constraint C12 |
| FD-14 | Scan 6 dropped from `scanLibDirectory` (registration rot) | AC-3.6 temp-tree anti-vacuity probe red | F4; the drill rows exercise `_scanWith`, a separate registration |
| FD-15 | Pre-seam browser profiles keep legacy `sso_audit_log` rows at rest indefinitely — the cleanup window closes permanently at the atomic landing (post-seam the literal is scan-6-red + artifact-red, and the removal phase must not relax the needle) | §4 review: step 2 (purge) absent and/or no guidance bullet | §4 step 2 pre-seam bootstrap purge (legal while the needle is not yet in force) + step 2c clear-site-data guidance; the residual class (profiles that never load the purge build) is accepted as R1.7 inert |

Requirement-level failure modes (F13 release-ring leak, F16 payload echo, F7 forgery) are the *object* of this design; their trip matrices are the scan pins and drill rows above.

## 4. Migration steps (ordered; each leaves the tree green)

1. **Baseline**: `flutter analyze && flutter test` — record green state (acceptance #4 snapshot). Confirm `grep -cF 'sso_audit_log' build/web/main.dart.js` == 2 (the needle is red today — this is the pre-landing proof of non-vacuity).
2. **Pre-seam legacy-data cleanup release** (one commit; resolves the at-rest finding — pre-seam browser profiles keep `sso_audit_log` rows at rest indefinitely, and post-seam no `removeItem` is legal, so this step is the **only** deletion window):
   a. `lib/main.dart` — one-shot release-only purge in the bootstrap, immediately after `WidgetsFlutterBinding.ensureInitialized();`, with `import 'services/local_storage.dart';` (the wrapper's conditional import makes non-web targets a no-op). Placement here, not in the service file, is mandatory: `lib/main.dart` is unpinned by every interim gate (`service_kdebug_count`/`tab_kdebug_count` are service/tab-scoped; no artifact needle exists yet), whereas a `kDebugMode` mention in the service file would trip `service_kdebug_count == 2` today and an unconditional purge would break the debug ring tests:
      ```dart
      if (!kDebugMode) {
        // B6-1b §4 step 2: purge legacy on-disk audit rows while the key
        // literal is still legal in release code; step 3 (the seam
        // landing) removes this block.
        LocalStorage.removeItem('sso_audit_log');
      }
      ```
      Guard shape is deliberate and distinct from the seam's: `if (!kDebugMode) { purge }` const-folds to **live** release code (the literal ships in the bundle — that is what makes the purge verifiable, 2b), whereas the seam's guard-first `return;` shape would DCE the purge away. Debug and test builds skip the branch — every ring-dependent test behaves byte-identically (C3 pre-seam); profile builds run it (harmless, desired).
   b. Verification (tree-green + artifact + deploy):
      - `flutter test` full suite green — the line is debug-inert;
      - `python cli.py harness` green **unchanged** (16/16) — this step touches no `config.py`/`b6_1b_gates.py`/`engineering.yaml`/`Makefile`/scan file; that is what keeps it outside the atomic core (C9);
      - `make release-artifact-check` green unchanged — the purge line contains none of the six old-key needles; the `sso_audit_log` needle does not exist yet (it lands with step 3g);
      - `make build-prod` then `grep -cF 'sso_audit_log' build/web/main.dart.js` == **3** — step-1 snapshot 2 → 3: the +1 literal is the `removeItem` site (dart2js emits one literal per call site; empirically stable across toolchain generations), proving the purge ships in release code. Record the 2 → 3 → 0 transition in the run — the standing gate is `== 0`, immune to the interim count;
      - **deploy gate** (operational, not a tree gate): ship the release so profiles load it **before** step 3 lands; record tag/URL/date in the run. If deployment cannot precede the landing, skip 2a's code (leave the tree clean) and ship only 2c — the exposure is then the documented R1.7 inert residual, not a blocker.
   c. **Clear-site-data guidance** (shipped with the seam landing's release notes regardless of the deploy outcome): "This build no longer stores audit records in the browser. Records stored by earlier builds are never read by the app; to remove them, clear site data for this origin (browser settings) or reset the profile." This covers the class 2b cannot reach — profiles that never load the purge build (offline/abandoned) — which no approach can clean, since a profile that never runs new code keeps its rows.
   
   Why this is the only legal window: post-seam, `LocalStorage.removeItem('sso_audit_log')` in any `lib/` file is (i) **scan-6-red** — the key literal outside `audit_log_service.dart` trips the non-service branch, and a third `LocalStorage.` token trips the `== 2` pin — and (ii) **artifact-red** — a live release-reachable literal fails `make release-artifact-check`. The B6-1b removal phase (§6) cannot clean up either: the artifact needle is the standing F13 control and must not be relaxed for a one-release exception. Step 2 is therefore the one and only deletion opportunity; afterward, leftover rows are the accepted inert-at-rest posture (R1.7). C9 is unaffected: step 2 touches no re-pin; all re-pins land atomically with the seam in step 3.

3. **ATOMIC core change** (seam + scan + tests + re-pins + purge removal in one commit; no interleaving keeps every gate green):
   a. `lib/services/audit_log_service.dart` — §1.1 seam (R1.1-R1.8).
   b. `test/audit_contract_guard_scans.dart` — scan 6 + registration + docstring normalization (R2.x with corrected R2.4).
   c. `test/audit_contract_guard_test.dart` — `AC-3.6` group + docstring count (six scans).
   d. `test/audit_contract_guard_mutation_test.dart` — rows (a)-(i), residual group note, scan-set registration.
   e. `test/audit_log_service_test.dart` — §1.5 behavior tests with the construction-order contract.
   f. `engineering.yaml` + `checks/config.py` + `checks/b6_1b_gates.py` — §1.7 re-pins (R6.1/R6.2).
   g. `Makefile` — `sso_audit_log` artifact needle (R6.3).
   h. `lib/main.dart` — **remove the step-2 purge** (and its import if now unused). Post-seam the literal is scan-6-red (non-service `keyHits > 0`) and the live `removeItem` would re-land the literal in the bundle (needle red); the deletion sits inside this same commit so no intermediate state carries the orphaned literal.
   
   Why atomic: scan 6's positive pins describe the post-seam shape (red before 3a); `b6_1b_gates.py` `service_kdebug_count == 2` breaks the harness the moment 3a lands without 3f; the Makefile needle is red on the pre-seam bundle until 3a DCEs the key; the step-2 purge is red under scan 6 + the needle until 3h removes it. Any split ordering leaves a gate red at some commit. R1.7 / §1.2a rule (e) hold on the post-seam tree: zero `removeItem` of the key in `lib/` (scan 6 pins `LocalStorage.` == 2, keyHits == 1); test-code `removeItem` remains C8-allowed.
   
   Verify: `flutter test test/audit_log_service_test.dart test/audit_contract_guard_mutation_test.dart test/audit_contract_guard_test.dart test/service_contracts_test.dart` + `python cli.py harness`.
4. **T-12 joint extension** — `test/audit_log_tab_test.dart` raw-seeded forged payload, both polarities + teardown protocol (R5). Verify: `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart` (the B6-1b copy-surface group at :414+ must stay green).
5. **Release proof**: `make build-prod && make release-artifact-check` — needle must be 0 (`sso_audit_log` absent from `build/web/main.dart.js`). Full suite: the REQ-7 list + `python cli.py harness` (re-pinned). Record the artifact-grep evidence in the run — this doubles as the purge-removal proof: needle == 0 ⇒ the step-2 line is gone from the bundle, and scan 6's non-service branch proves it is gone from `lib/` source.

## 5. Testable acceptance mapping

| Direction acceptance | Requirements | Runnable assertion (file → pinned check) |
|---|---|---|
| AC-1 Mutation tests: flag off → `record()` never calls `setItem`, key absent after N records; flag on → recording works | R1.1-R1.4, R4.1-R4.2, R3 | `test/audit_log_service_test.dart`: `debugStorageEnabled = false` → after 3 `record()`s `LocalStorage.keys()` has no `sso_audit_log`, `getItem` null, in-memory ring intact; `= true` → key present, JSON == 3 entries, first most recent, wire fields intact, `clear()` → `[]`. Drill rows (a)-(i): each `_scanWith` run yields a `ring-storage-seam` violation; unmutated baseline green |
| AC-2 Static guard: grep-level proof of no unconditional `LocalStorage.setItem('sso_audit_log'...)` outside the debug-gated branch | R2.1-R2.6 (corrected R2.4), R6.1-R6.3 | `test/audit_contract_guard_test.dart` `AC-3.6` group green on the live tree + `scanLibDirectory` baseline in the mutation file; `python cli.py harness` green (service `kDebugMode` == 6, storage initializer pin == 1, direct guards == 4, `sso_audit_log` in exactly one lib/ file); `make release-artifact-check` green (needle == 0 in `build/web/main.dart.js`) |
| AC-3 T-12 joint: devtools/localStorage-seeded forged rows → timeline renders zero forged rows | R5.1-R5.3 | `test/audit_log_tab_test.dart`: raw `LocalStorage.setItem('sso_audit_log', <forged JSON>)` pre-pump → `find.textContaining('/api/v1/admin/forged')` and `'forged entry'` findsNothing, polarities on **and** off; payload byte-identical in the off polarity; AC-1.5 service-seeded assertions retained |
| AC-4 Existing ring-dependent tests pass unchanged in debug mode | R6, R7 | REQ-7 list green: `snaplink_admin_api_test.dart` ring-liveness (:330+), `audit_log_tab_test.dart` (all groups incl. :414+), `admin_support_tabs_test.dart` ring-clear (:63-143), `oidc_login_ring_isolation_test.dart` (:117-135), `oidc_login_audit_visibility_guard_test.dart`, `service_contracts_test.dart`, `audit_contract_guard_mutation_test.dart` baseline, `python cli.py harness` |

Verification commands (post-implementation):

```bash
flutter test test/audit_log_service_test.dart test/audit_contract_guard_mutation_test.dart \
  test/audit_contract_guard_test.dart test/audit_log_tab_test.dart \
  test/snaplink_admin_api_test.dart test/oidc_login_ring_isolation_test.dart \
  test/service_contracts_test.dart test/admin_support_tabs_test.dart
python cli.py harness          # b6_1b_gates re-pinned (R6.1/R6.2)
make build-prod && make release-artifact-check   # R6.3: sso_audit_log absent from build/web
```

## 6. Out of scope (hard boundary)

- **B6-1b removal phase** (`_recordAudit` deletion, debug badge/Clear/CSV relabeling, palette wording) — the demotion is the wedge; removal is a later step (b6-1a §4).
- **Gating `_recordAudit` itself** with `kDebugMode` at `snaplink_admin_api.dart` — contradicts C3/C11; the service-boundary seam makes release persistence impossible while keeping dev observability identical. Any implementer deviation toward call-site gating must be rejected.
- **Direction 1** (nav capability-gating, `supportsAudit` registration, row-model re-pinning) — separate; only its forged-row assertions are reused (R5.1).
- **`removeItem` cleanup** of legacy `sso_audit_log` storage in `lib/` — forbidden post-seam (§1.2a rule e); the pre-seam bootstrap purge of §4 step 2 is the single exception and is deleted by the landing; leftover storage is provably inert.
- **F17 CSV hardening / `_csvCell`** and **B6-2 login-edge drill** — separate directions.
- **Runtime F16 payload-echo test** (a second first-construction polarity) — enforced statically via R2.6 instead; load-off polarity covered by the construction-order-contract test (§1.5).
