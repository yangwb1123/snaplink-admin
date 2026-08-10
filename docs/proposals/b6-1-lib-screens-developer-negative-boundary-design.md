# B6-1 Design — Pin lib/screens/developer as the B6-1 negative boundary (scan 6 parity, wide `audit` net)

> Sibling: `docs/proposals/b6-1-lib-screens-developer-negative-boundary-spec.md` (requirements), mirroring the portal pair `b6-1-lib-screens-portal-negative-boundary-{design,spec}.md`.
> Status: **design for the implement stage**. The boundary already holds at HEAD `e1073ce` (grep exit 1 over all 13 module files) — this design turns it into repo guards: a scan-6-parity negative-boundary scan, loop wiring, F2 pin extension, and mutation skins, all under `test/`.

## 0. Verification ledger (every evidence claim re-checked, not trusted)

All spec citations re-checked against the working tree at HEAD `e1073ce` (2026-08-08). The guard suite was **executed**: `flutter test test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/developer_audit_visibility_guard_test.dart test/oidc_login_audit_visibility_guard_test.dart` → **56/56 green** (28 + 26 + 1 + 1, per-file counts re-measured).

| # | Spec claim | Verified at HEAD | Verdict |
|---|---|---|---|
| E1 | `app_router.dart:31` ungated `DeveloperScreen` entry | `git show HEAD:lib/app_router.dart` :31 = `ProductEntry.developer => const DeveloperScreen(),` — **exact at HEAD**; no `AdminGateScreen` wrapper (contrast admin :33). The **working tree** carries the B6-2 delta (one added `import 'api/sso_client.dart';` + `defaultClientId: SSOAdminClient.firstPartyClientId`) shifting the entry to :32 — the spec's HEAD citation is correct; the design's acceptance gates must attribute the B6-2 delta explicitly (see F9) | ✅ exact (at HEAD) |
| E2 | `scanLibDirectory` per-file loop `:94-113`, portal call at `:110` | `scans.dart:94-113` exact; per-file calls `scanAuditPathLiterals` :106, `scanBffLiterals` :107, `scanRawStringification` :108, `scanSecondConsumer` :109, `scanPortalAuditBoundary` :110; trio-owner post-loop :112 | ✅ exact |
| E3 | `scanPortalAuditBoundary` `:421-441`; portal-only early return `:425`; `_auditAnyPattern` `:419`; scan id `:432`; detail `:434-436` | Function :421-441; early return :425; `RegExp(r'audit', caseSensitive: false)` :419; `scan: 'portal-audit-boundary'` :432; detail text :434-436 — all exact | ✅ exact |
| E4 | Green-against-tree tests `:35,:140,:171,:426` (+ `[CORRECTION]` :109, :178, :313) | `:35` AC-3.1 green; `:109` scan-2 green; `:140` catalog-trio green; `:171` scan-5 green; `:178` trio-owner green; `:313` scan-6 portal green; `:426` AC-3.4 raw-string green — all confirmed | ✅ exact |
| E5 | Synthetic-probe trees `:67` bare-anchor, `:320-417` F2 pin (`[CORRECTION]` :54-66 encodeComponent) | `:54-65` encodeComponent probes; `:67-85` bare-anchor probe; **F2 test :320-422** (not :320-417): dirty probes `screens/portal/_probe.dart` `'audit'` :349-352, scan-1 :353-356, `'// bff'` :357, scan-4 :358-361, scan-5 :362-366, trio owner `api/audit_read_client.dart` :369-374, `allPerFileScans` :375-382, per-id dirty asserts :384-392, clean control writes :395-412, per-id green asserts :413-421 | ⚠ F2 tail stale in the spec *and* in the design's earlier draft — **corrected here with re-measured spans** (see note 3) |
| E6 | `developer_api.dart` register/loadApp/saveApp/deleteApp; zero audit/bff | `class DeveloperApi` :39; `loadDiscovery` :52; `registerMetadata` :62; `register` :75; `_registerBody` :94; `loadApp` :117; `saveApp` :136; `deleteApp` :155; `_handle` :168 — all exact. `find lib/screens/developer -name '*.dart'` → **13 files**; `grep -rniE "audit|bff" lib/screens/developer/` → **exit 1** (re-run) | ✅ exact |
| E7 | Zero `lib/` edits required; module already compliant | The three target test files are tracked; `lib/screens/developer/**` byte-clean of `audit`/`bff` (E6). Worktree `git status` shows only the B6-2 set (`lib/api/sso_client.dart`, `lib/app_router.dart`, 3 test files) + untracked docs/guard files — nothing touches the guard suite or the developer module | ✅ |
| E8 | T-12 joint gate: `make test` → `flutter test`; G7 same-gate pin+liveness | `Makefile:51-53` `test:` → `flutter test` + python unittest; `.github/workflows/ci.yml:49-50` "Unit tests" → `make test`; `docs/campaigns/implementation-gate.md:79` G7: "pin 与 liveness 套件**同门运行**，`@TestOn('vm')` 静默跳过即计数不匹配 → CI 失败"; console row 1 at :56 ("T-12 联合…devtools 伪造不再构成证据") | ✅ exact (Makefile target spans :51-53, tightened from :51-55) |
| E9 | `_scanWith` dispatch default set `{'audit-path-literals','bff-literals','raw-stringification','portal-audit-boundary'}` `:38-43`; dispatch blocks `:56-70` | Default set :38-43 exact. **Dispatch blocks are :53-67** (audit-path-literals :53-55, bff-literals :56-58, raw-stringification :59-61, second-consumer :62-64, portal-audit-boundary :65-67); the **trio-literal-owner block sits post-loop at :69-71** where `source`/`relative` are out of scope — it is *not* part of the default-set dispatch. Doc comment at **:33-35** ("Runs scans 1/2/4/5/6 + the ownership pin") — needs a 6b mention (migration step M2) | ⚠ dispatch/doc spans stale in the design's earlier draft — **corrected here** (see note 4) |
| E10 | Portal skins group `:336-392`; each asserts `mutated != source` then trips `portal-audit-boundary` via `_scanWith` | Group at **:336-391** (:392 closes the enclosing 'planted regressions' group at :84); skins A/B/C at :342-359 / :361-376 / :378-390; 26 tests in the mutation file (re-measured) | ⚠ group tail off by one (:336-391, not :336-392) — **corrected here** (see note 6) |

**Post-review corrections applied to this design (the drift class is fully purged from every anchor this design depends on):**

1. **Scan-id inventory doc is at `scans.dart:40-42`, not `:36-38`** (spec REQ-1 cites `:36-38`). :36 is an import; the `/// Scan id: …` list lives on the `AuditGuardViolation.scan` field at :40-42. Migration step M1 targets :40-42. (Design was already correct here.)
2. **The `_scanWith` doc comment is at `mutation_test.dart:33-35`, not `:36-38`** — :36 is the function signature. The design's earlier draft repeated the spec's `:36-38` in E9, §1.2C and M2; all three are corrected to :33-35 (note 4).
3. **F2 spans were systematically stale** (design E5/§1.2B and spec E6 both carried the same drift class). Corrected spans: F2 test :320-422; dirty probes :349-352 / :353-356 / :357 / :358-361 / :362-366 / :369-374; `allPerFileScans` :375-382; per-id dirty asserts :384-392; clean control writes :395-412; per-id green asserts :413-421.
4. **E9 dispatch span corrected**: default-set dispatch blocks :53-67 (the :53-55 audit-path-literals block was omitted); the trio-literal-owner pin block at :69-71 is post-loop and is **not** a dispatch insertion site (M2's corrected anchor: **after :67**, inside the per-file loop — see note 5 in §4).
5. **V4 anchors corrected**: http import is at `developer_api.dart:3` (not :2); the standalone `'/register'` literal is at :104 (unique — the only non-interpolated occurrence); the interpolated register paths are at :123 (loadApp), :143 (saveApp), :161 (deleteApp), not :126-127/:147-148/:162-163.
6. **E10 group tail corrected**: portal skins group :336-391 (not :336-392).
7. **E8 Makefile span tightened** to :51-53 (the `test:` target body).
8. **Spec-side residual (separate doc, out of scope here)**: the spec's own E6 row (:349-353/:354-356/:358-360/:361-363/:364-371), S2 dispatch (:56-70) and E1 scan-id list (:36-38) retain the same drift class; the implementer should reconcile the spec's citations during M5's doc sweep. The design's group name (§1.2C) is aligned to the spec's REQ-3 name (`'B6-1 scan 6 — developer negative boundary fails closed'` — no "6b" in the display name; "6b" lives in the scan id and the library-doc bullet).

### Open-decisions execution (both decisions proven against the landed suite, HEAD `e1073ce`)

The two open decisions below were **executed, not re-argued**: a scratch harness (14 tests, deleted after the run) replayed the design's exact helper/skin/F2 code against the live suite (re-executed **56/56** green before the run). Full log: `/tmp/b6-1-evidence/scratch-harness-run.txt`.

**(a) Skin-B re-anchor (bare prefix + split form) — PROVEN.** With the mutation `replaceFirst("'/register'", "'/api/v1/audit'")` layered over the live tree:

- **Missed by the full landed surface**: the layered-tree run of scans 1/2/4/5/6 + `trio-literal-owner` (the exact surface the F2 pin and green tests exercise) yields **zero violations**, and the mutation-drill `_scanWith` default set is equally silent. The landed AC-2 needles (`AuditLogService`/`audit_log_service`/`sso_audit_log`) stay absent.
- **Tripped by the new scan only**: the extended loop yields exactly one `developer-audit-boundary` violation on `developer_api.dart` — scan-id isolated (no landed id fires alongside).
- **Split form equally proven**: `'/api/v1/audit' '/events'` → zero landed violations (scan-1 allowlists the bare fragment, `'/events'` carries no token, the ownership pin sees no single-line trio member, and scan-5's E4 adjacent-split detector engages at regex level but early-returns — `developer_api.dart` has **zero** `query:` occurrences, verified); the new scan trips the same way.
- **Anchor unique/live**: standalone `'/register'` occurs exactly once (:104; load/save/delete stay interpolated); `mutated != source` for both forms. Control (why the re-anchor is required): the OLD trio target `'/api/v1/audit/events'` **is** caught by the landed `trio-literal-owner` through the real loop — reproduced.

**(b) F-B fix (uppercase `'AUDIT'` F2 needle) — PROVEN.** With the extended F2 dirty tree (landed probes + `screens/developer/_probe.dart` = `final _probe = 'AUDIT';`):

- **Correct scan**: trips `developer-audit-boundary` — exactly one violation, from exactly the developer probe file (one-probe-per-id preserved; the probe trips no other id).
- **Dropped `caseSensitive: false`** (case-sensitive `RegExp(r'audit')`): the developer id goes **absent** from the dirty tree while every other id still trips → the F2 dirty assert **reds**, precisely, with zero collateral.
- **Why the needle**: every lowercase needle (skins A/B/C, probes 1–2, the portal F2 probe) provably fires under *both* modes — none can pin the flag; `'AUDIT'` matches only case-insensitively (proven).
- **Live 13-file tree stays green under both modes** (zero case-insensitive `audit`; grep exit 1 re-confirmed; extended loop over live `lib/` fully clean).

**Re-measured arithmetic: 56 → 64.** Landed counts re-measured dynamically: 28 = 23 static `test(` + 6 loop − 1 (the loop's own declaration), 26, 1, 1 → 56 (executed). Post-change: guard test **33** (28 + green-against-tree + 3 per-function probes + portal detail-string pin §1.2B item 3), mutation **29** (26 + skins A/B/C), developer guard 1, oidc guard 1 → **64/64**. The F-B needle and the skin-B re-anchor add **zero** tests (in-place changes inside the existing F2 test / existing skin).

### Design-level findings (no spec defect — tighten the implementation contract)

**V1 — Shared-helper refactor keeps portal messages byte-identical by construction.** The spec requires `scanPortalAuditBoundary` to stay "byte-identical in behavior and message". Parameterizing the existing function's body directly risks message drift; the design instead extracts a private `_scanNegativeBoundary(source, fileLabel, {modulePrefix, scanId, moduleLabel, boundaryReason})` and makes **both** public scans one-line delegates. With `moduleLabel: 'portal module'` and `boundaryReason: 'audit reads belong to SnaplinkAdminApi via AuditReadClient'`, the generated detail string is character-identical to the current :434-436 text (verified by concatenation). The portal early-return, scan id, and violation shape are untouched. The `[CORRECTION]`-free path: keep `_auditAnyPattern` module-level (shared), add the developer delegate next to the portal one. Honest residual **closed**: the landed portal skins/F2 pin assert only the id, never the detail text — byte-identity is now **test-enforced** by the portal detail-string pin (§1.2B item 3, +1 test), with the M1/M4 `git diff -U0` gate as the second line (F4).

**V2 — The developer probe trips exactly one scan id in the F2 pin.** `"final _probe = 'AUDIT';"` under `screens/developer/_probe.dart` (uppercase deliberately — see V2a): scan-1 needs an `api/v1/audit` token (absent), scan-2 needs `bff` (absent), scan-4 needs `MapEntry` (absent), scan-5 needs `query:` (absent), trio-owner needs a trio literal (absent), portal scan early-returns on the label. So the dirty-tree extension preserves the F2 "one probe per scan id" discipline; the `'activity'` clean control contains no case-insensitive `audit` and trips nothing. The throwaway trio-owner file at `api/audit_read_client.dart` stays non-developer-labeled, so the new scan's early-return keeps it inert.

**V2a — The uppercase `'AUDIT'` needle test-enforces the wide net's case-insensitivity.** Every other B6-1 gate needle (probes, skins, portal F2 probe) is lowercase `'audit'` — if `caseSensitive: false` were dropped from `_auditAnyPattern`, all of them would still fire, so the flag would be unpinned by the entire gate set (the portal set has the same blind spot). The F2 dirty probe's `'AUDIT'` trips only under the case-insensitive flag: the mutation reds the F2 dirty assert (iii) while the green-against-tree test (ii) passes vacuously. The `'AUDIT'` needle satisfies no other scan's trigger vocabulary (verified: no `api/v1/audit` token, no `bff`, no `MapEntry`, no `query:`, no trio member), so one-probe-per-id still holds.

**V3 — Adding `developer-audit-boundary` to the `_scanWith` default set is inert for every existing skin.** All existing mutation skins mutate files labeled `screens/admin/…`, `screens/portal/…`, or `api/…`; the new scan early-returns for all of them (E9 dispatch verified). The live tree has zero `audit` in `screens/developer/` (E6), so the mutation file's baseline green group stays green. The default-set addition is therefore safe *and* necessary: without it, the developer skins would exercise nothing.

**V4 — Skin anchors on `developer_api.dart` are unique and live.** Skin A anchors on `import 'package:http/http.dart' as http;` (:3, unique — re-measured); skin B anchors on the standalone literal `'/register'` at :104 — unique because the other three occurrences are interpolated `'/register/${Uri.encodeComponent(clientId)}'` (loadApp :123, saveApp :143, deleteApp :161); skin C appends a doc-comment line. Each skin's `expect(mutated, isNot(source))` proves the anchor is still live — a rename or re-interpolation fails loudly, never silently (same convention as the portal skins, S3/F6).

**V5 — Skin B (re-anchored on the audit bare prefix) trips no other scan, landed or new.** Skin B repoints the DCR register POST at the audit **bare prefix** `'/api/v1/audit'` (keeping the `'/register'` repoint framing). The bare prefix is allowlisted by scan-1 anywhere (the `auditBarePrefix` grouping anchor, E11), it is **not** a trio member, and it carries no `query:`/`bff`/`MapEntry` trigger — so no landed scan fires on it through the real `scanLibDirectory` loop, and `second-consumer`/`trio-literal-owner` are not in the `_scanWith` default set (E9). The new wide net is the only trip. **Why not the trio-member form `'/api/v1/audit/events'`:** that exact repoint *is* caught by the landed `trio-literal-owner` pin through the real loop (verified empirically — the trio member is a single-line literal outside the owner), so its "missed by the existing suite, caught by the new scan" property fails at the real-loop level even though the `_scanWith` default set (which the drill runs) lacks trio-owner. Re-anchoring on the bare prefix removes the ambiguity: the skin is genuinely missed by every landed scan and caught only by the new wide net — **executed**: full-landed-surface run over the layered tree → zero violations; extended loop → exactly one `developer-audit-boundary` violation, scan-id isolated; the split form `'/api/v1/audit' '/events'` is equally proven (scan-5's E4 adjacent-split detector early-returns — `developer_api.dart` has zero `query:` occurrences; verified). Skin A's `AuditReadClient` identifier likewise trips only the wide net.

**V6 — No self-hit hazard.** The new scan and probes live under `test/`; every scan reads only `lib/` (E2 loop root). The guard files already carry `audit` literals today (the F2 probe writes `'audit'`), so the new probe literals follow existing convention — no literal-splitting burden beyond what the landed AC-2 sibling already documents for its own needles.

**V7 — G7 count assertion is stale *before* this change set and must be refreshed in the same change set.** `implementation-gate.md:79` pins campaign-relative test-count deltas ("guard+widget +16 …" = device guard 1 + oidc guard 1 + entry_ux 10 + device_verify_api 4) — the breakdown **omits all three landed developer tests** (`developer_audit_visibility_guard_test.dart` +1, `developer_ring_isolation_test.dart` +1, `developer_forge_invisibility_test.dart` +1; each measured at 1 test), so the row is already short ≥3 before this change set. This change set adds **+8** guard-suite tests (guard test +5: green-against-tree + 3 per-function probes + portal detail-string pin §1.2B item 3; mutation drill +3: skins A/B/C), taking the four-file suite 56 → **64** — and that +8 lands on top of the missing +3. Recomputed row (M5): guard+widget **+27** = 16 (device guard 1 + oidc guard 1 + entry_ux 10 + device_verify_api 4) + 3 (landed developer tests) + 8 (this set). The implementer must record the measured deltas (M5) rather than edit the doc blind.

**V8 — Acceptance must attribute the pre-existing B6-2 `lib/` delta.** `git diff --stat HEAD -- lib/` is non-empty **today** (B6-2's `sso_client.dart` + `app_router.dart`). AC-2's zero-`lib/` check is therefore: *this change set* adds no `lib/` path — verify by comparing the pre-change and post-change `git diff --stat HEAD -- lib/` outputs (M1 step-0 captures the baseline) and confirming they are identical (or, on a clean landing, by reverting/rebasing B6-2 first). The scans never read `app_router.dart` (module-rooted only), so B6-2 cannot interact with the new scan.

## 1. API changes

### 1.1 Production API — none (negative constraint, enforced)

Zero `lib/` changes are required **or permitted**. `DeveloperApi` (`lib/screens/developer/developer_api.dart`, 188 lines) acquires no audit surface: no methods, no path literals, no `AuditReadClient` wiring, no query builders. `lib/screens/developer/**` stays byte-clean of `audit`/`bff` (E6). The only "API" added is test-side.

### 1.2 Test-suite API — additive changes to three files

**A. `test/audit_contract_guard_scans.dart` — shared negative-boundary helper + new scan + loop wiring.**

Extract the scan-6 body into a private parameterized helper (V1) and add the developer scan:

```dart
/// Shared B6-1 negative-boundary scan (portal + developer parity).
/// [modulePrefix] gates the scan (early return keeps every other label
/// byte-for-byte unaffected); [scanId] is the pin id; [moduleLabel] and
/// [boundaryReason] render the violation detail.
List<AuditGuardViolation> _scanNegativeBoundary(
  String source,
  String fileLabel, {
  required String modulePrefix,
  required String scanId,
  required String moduleLabel,
  required String boundaryReason,
}) {
  if (!fileLabel.startsWith(modulePrefix)) return const [];
  final violations = <AuditGuardViolation>[];
  for (final match in _auditAnyPattern.allMatches(source)) {
    final line = 1 + '\n'.allMatches(source.substring(0, match.start)).length;
    violations.add(AuditGuardViolation(
      scan: scanId,
      file: fileLabel,
      detail: 'case-insensitive "audit" at line $line; the $moduleLabel '
          'is the B6-1 negative boundary — $boundaryReason',
    ));
  }
  return violations;
}

List<AuditGuardViolation> scanPortalAuditBoundary(
  String source,
  String fileLabel,
) =>
    _scanNegativeBoundary(
      source,
      fileLabel,
      modulePrefix: 'screens/portal/',
      scanId: 'portal-audit-boundary',
      moduleLabel: 'portal module',
      boundaryReason:
          'audit reads belong to SnaplinkAdminApi via AuditReadClient',
    );

/// Scan 6b — B6-1 developer negative boundary (parity with scan 6).
///
/// The developer module (`lib/screens/developer/`) keeps zero
/// case-insensitive `audit` occurrences (identifiers, imports, comments,
/// literals, doc comments). DCR reads/writes belong to DeveloperApi's
/// /register surface; audit reads belong to SnaplinkAdminApi via
/// AuditReadClient — the developer self-service client never acquires an
/// audit surface.
List<AuditGuardViolation> scanDeveloperAuditBoundary(
  String source,
  String fileLabel,
) =>
    _scanNegativeBoundary(
      source,
      fileLabel,
      modulePrefix: 'screens/developer/',
      scanId: 'developer-audit-boundary',
      moduleLabel: 'developer module',
      boundaryReason: "DCR reads/writes belong to DeveloperApi's /register "
          'surface; audit reads belong to SnaplinkAdminApi via AuditReadClient',
    );
```

Loop wiring (after the portal call at `scans.dart:110`, landing at :111):

```dart
    violations.addAll(scanPortalAuditBoundary(source, relative));
    violations.addAll(scanDeveloperAuditBoundary(source, relative));
```

Doc updates in the same file: (i) library doc gains a bullet 6b after the scan-6 bullet (:28-31) — "developer negative-boundary scan (B6-1) — zero case-insensitive `audit` occurrences anywhere in `lib/screens/developer/`; DCR reads/writes belong to DeveloperApi's /register surface, audit reads belong to SnaplinkAdminApi via AuditReadClient"; (ii) the scan-id inventory doc on `AuditGuardViolation.scan` (**:40-42**, not `:36-38` — note 1) gains `developer-audit-boundary`.

**B. `test/audit_contract_guard_test.dart` — new scan-6b group (green + probes) + F2 pin extension.**

New sibling group after the portal scan-6 group (:312-423, which closes after the F2 test at :422):

1. **Green-against-tree** (mirror of :313-318): `scanLibDirectory(packageLibDir()).where((v) => v.scan == 'developer-audit-boundary')` → empty, reason = violations joined.
2. **Per-function probes** (the `:67` probe style, AC-3 probes 1-3):
   - `AuditLogService` import: `scanDeveloperAuditBoundary("import 'package:sso_admin/services/audit_log_service.dart';\n", 'screens/developer/developer_api.dart')` → non-empty (`developer-audit-boundary`).
   - Trio literal: source containing `'/api/v1/audit/events'` → `scanDeveloperAuditBoundary` non-empty (the wide net trips regardless of scan-1's allowlist).
   - `bff` token: `scanBffLiterals('// bff\n', 'screens/developer/developer_api.dart')` → non-empty (`bff-literals` — scan 2 is lib-wide; the probe pins that the developer module sits inside the guarded tree).

**F2 pin extension** (inside the existing test at :320-422, preserving one-probe-per-id):
- Dirty tree: `writeProbe('screens/developer/_probe.dart', "final _probe = 'AUDIT'; // synthetic negative-boundary probe\n");` (mirror of :349-352; uppercase needle per V2a pins the case-insensitive flag).
- `allPerFileScans` (:375-382) gains `'developer-audit-boundary'`.
- Clean control (:395-412): rewrite the developer probe to `"final _probe = 'activity';\n"` (V2).
- No new test is added for the pin — the extension lives inside the existing F2 test so the "every per-file scan trips through the real loop" invariant stays single-homed.

3. **Portal detail-string pin (+1 test, closes V1's byte-identity residual).** The landed portal skins/F2 pin assert only the *id*, never the detail text — a shared-helper refactor that keeps the id but drifts the message would stay suite-green. Inside the new scan-6b group (or the portal scan-6 group), add a fixed-probe assertion pinning the exact detail string byte-for-byte (em-dash U+2014 and line math included; executed: the design helper renders these bytes identically to the landed :434-436 text over all 33 real portal files + a 9-case adversarial corpus):

```dart
test('portal detail string stays byte-identical through the shared helper '
    '(V1 pin)', () {
  const probe = '// portal negative-boundary probe\n'
      "final _probe = 'audit';\n";
  final violations = scanPortalAuditBoundary(
    probe,
    'screens/portal/security_activity_tab.dart',
  );
  expect(violations, hasLength(1));
  expect(
    violations.single.detail,
    'case-insensitive "audit" at line 2; the portal module is the B6-1 '
        'negative boundary \u2014 audit reads belong to '
        'SnaplinkAdminApi via AuditReadClient',
  );
});
```

This makes the V1 byte-identity claim continuously enforced (F4), so the M1/M4 `git diff -U0` gate is the second line, not the only line.

**C. `test/audit_contract_guard_mutation_test.dart` — dispatch extension + developer skins group.**

1. `_scanWith` default scans set (:38-43) gains `'developer-audit-boundary'`; dispatch block added **after the portal block (:67)** — inside the per-file loop, where `source`/`relative` are in scope; doc comment (:33-35) updated: "Runs scans 1/2/4/5/6/6b + the ownership pin".
2. New group `'B6-1 scan 6 — developer negative boundary fails closed'` (spec REQ-3 name — no "6b" in the display name; mirror of :336-391), anchored on `_libSource('screens/developer/developer_api.dart')`, each skin asserting `mutated != source` then `developer-audit-boundary` non-empty through `_scanWith`:
   - **Skin A** — append after the unique http import at :3 (V4): `import 'package:sso_admin/api/audit_read_client.dart';\nfinal _probe = AuditReadClient(null).list();`.
   - **Skin B** — `replaceFirst("'/register'", "'/api/v1/audit'")` (V4/V5; the DCR register POST repointed at the audit bare prefix — the second-read-path hazard class; the trio-member repoint form is trio-owner-caught through the real loop, so the bare prefix is the uniquely-newly-caught member).
   - **Skin C** — append `/// audit probe comment` (doc-comment surface).

## 2. Compatibility constraints

1. **Purely additive guard suite.** The new per-file call early-returns `const []` for every label outside `screens/developer/`, so scans 1/2/4/5, the portal scan, and the trio-owner pin run exactly as before with identical violation sets. All 56 existing tests stay green; only new tests are added.
2. **Portal scan-6 behavior + messages byte-identical.** The refactor (V1) preserves the portal early-return, the `portal-audit-boundary` id, and the :434-436 detail text character-for-character; the existing portal green test (:313), F2 pin (portal id in `allPerFileScans`), and portal mutation skins (:336-391) re-verify it on every run.
3. **No new dependencies or SDK features** — `RegExp(caseSensitive: false)` is already in use (:419); `AuditGuardViolation` shape (`scan`/`file`/`detail`) unchanged; the new id is a plain string consistent with the other six.
4. **`_scanWith` default-set addition is inert for existing skins** (V3): no existing skin mutates a `screens/developer/`-labeled file, and the live module is clean — the mutation file's baseline green group cannot trip the new id.
5. **F2 discipline preserved** (V2/V2a): one probe per scan id, clean control per id, temp-dir-contained with `addTearDown` cleanup; the developer probe cannot satisfy any other scan's dirty assertion, and the control cannot trip anything.
6. **Landed ring-isolation set untouched.** `test/developer_audit_visibility_guard_test.dart` (AC-2 needles), `test/developer_ring_isolation_test.dart`, `test/developer_forge_invisibility_test.dart` pass unchanged — the wide net subsumes but never replaces them.
7. **No self-hit** (V6): scans read `lib/` only; the new probe literals follow the F2 test's existing convention.
8. **G7 gate compatibility** (V7): the count assertion at `implementation-gate.md:79` must be refreshed with the measured deltas in the same change set (the row is already short the landed developer +3); the joint-gate mechanism (pin + liveness same CI run) is unchanged.

## 3. Failure modes

| # | Failure mode | Detection | Mitigation |
|---|---|---|---|
| F1 | Future implementer adds an audit surface to the developer module (import, identifier, comment, doc string, non-path string) | Wide net trips on any case-insensitive `audit` → CI red; skins A/B/C prove fail-closed; per-function probes pin the semantics | The intended friction: forces a documented boundary amendment (record + spec + scan) instead of silent drift; T-12 acceptance stays on the proven carrier |
| F2 | Scan wiring regresses (developer call dropped from the `scanLibDirectory` loop, wrong prefix, typo'd scan id) | Two independent canaries: the F2 pin extension makes the dirty temp tree's developer id produce violations only through the real loop call (`scans.dart:111`) — if the call is dropped *or the id/prefix is typo'd*, `developer-audit-boundary` is absent from the dirty result while the green-against-tree test passes vacuously; the mutation dispatch extension pins the `_scanWith` dispatch | F2 pin (extended) + skins (extended) — no green group can pass vacuously if either wiring point is dropped |
| F3 | Dispatch regression in the mutation drill (default set or dispatch block missing) | All three developer skins red | F2 pin covers the real loop; the dispatch is pinned by the skins themselves |
| F4 | Shared-helper parameter drift (wrong `moduleLabel`/`boundaryReason`/`scanId`) | **Test-enforced**: the portal detail-string pin (§1.2B item 3) asserts the exact :434-436 detail bytes (em-dash included) — a message-drifting refactor reds it directly; portal skins/F2 still pin the id | Migration steps M1/M4 require the `git diff -U0` check on the portal delegate before/after the refactor as the second line; keep the portal delegation one line |
| F5 | Legit developer content containing "audit" (e.g., a DCR client named `audit-client`, an RFC 7591 doc quote) | CI red on the guard even if the content is otherwise sound | By design: the boundary routes audit reads through `SnaplinkAdminApi`/admin screens; approving such content requires an explicit boundary amendment — never silent |
| F6 | Probe brittleness: `developer_api.dart` import anchor (:3) or `'/register'` literal (:104) changes | Skin's `mutated == source` fails loudly, or `_libSource` throws on rename | Same convention as the portal skins (S3); a rename would also break the spec's greppable claim — loud, not silent |
| F7 | Clean-control drift (neutralized developer probe accidentally contains `audit`) | F2 green asserts red | Use `'activity'` (verified clean against every default-scan id, V2) |
| F8 | G7 count assertion stale after landing | Campaign gate CI red on count mismatch | M5: refresh `implementation-gate.md:79` with measured deltas in the same change set |
| F9 | Acceptance-time `lib/` diff polluted by the uncommitted B6-2 set | `git diff --stat HEAD -- lib/` shows `sso_client.dart`/`app_router.dart` | AC-2's gate is *delta attribution*: this change set adds no `lib/` path (V8) — M1 step-0 captures the baseline, M4 compares against it; scans never read `app_router.dart`, so no interaction |

## 4. Migration steps (implement stage, ordered)

1. **M1 — `test/audit_contract_guard_scans.dart`:**
   - **Step 0 (baseline capture, before any edit):** `git diff --stat HEAD -- lib/ > /tmp/b6-1-lib-baseline.txt` (current tree: `sso_client.dart` + `app_router.dart` only — re-verified). F9's delta attribution compares against this snapshot; without it the "identical to pre-change output" check has no reference.
   - Extract `_scanNegativeBoundary` (V1); rewire `scanPortalAuditBoundary` as a one-line delegate and **diff it against HEAD** to confirm byte-identical behavior/messages (F4: `git diff -U0 HEAD -- test/audit_contract_guard_scans.dart` — only the delegation lines, the new scan, the loop call, and the doc lines may change; the :434-436 detail text must be untouched); add `scanDeveloperAuditBoundary` (scan id `developer-audit-boundary`); add the loop call after :110 (lands at :111); update the library doc bullet (after :31) and the scan-id inventory doc at **:40-42** (note 1).
2. **M2 — `test/audit_contract_guard_mutation_test.dart`:** add `'developer-audit-boundary'` to the `_scanWith` default set (:38-43); add the dispatch block **after :67 — inside the per-file loop, where `source`/`relative` are in scope** (NOT after :69-70: that is the post-loop trio-literal-owner block, where the loop variables are out of scope and an inserted call would fail to compile); update the :33-35 doc comment ("Runs scans 1/2/4/5/6/6b + the ownership pin"); add the `'B6-1 scan 6 — developer negative boundary fails closed'` group (skins A/B/C, V4/V5) mirroring :336-391.
3. **M3 — `test/audit_contract_guard_test.dart`:** add the scan-6b group (green-against-tree + three per-function probes) **after the portal group (:423, which closes after the F2 test at :422 — NOT :417, which is inside the F2 test's assert loop)**; extend the F2 test (:320-422) with the developer dirty probe (`'AUDIT'`), the `'developer-audit-boundary'` entry in `allPerFileScans` (:375-382), and the `'activity'` clean control (:395-412).
4. **M4 — verify, in order:**
   - `grep -rniE "audit|bff" lib/screens/developer/` → **exit 1**
   - `git diff -U0 HEAD -- test/audit_contract_guard_scans.dart` → full-file review: only the delegation lines, new scan, loop call, and doc lines changed; the :434-436 detail text byte-identical (F4)
   - `flutter test test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/developer_audit_visibility_guard_test.dart test/oidc_login_audit_visibility_guard_test.dart` → green, **64/64** (28+5 guard, 26+3 mutation, 1, 1)
   - `make test` (full joint gate) → green
   - `git diff --stat HEAD -- lib/` → **identical to `/tmp/b6-1-lib-baseline.txt`** (M1 step 0; only the B6-2 paths; delta attribution V8/F9). Note: if the B6-2 set were red, it would block the full gate for out-of-scope reasons — attribute, don't unwind.
5. **M5 — refresh `docs/campaigns/implementation-gate.md:79`** G7 count row with the measured deltas: this set +8 (guard test +5, mutation +3) lands **on top of the already-missing +3** from the landed ring-isolation set (V7 — the row's breakdown omits `developer_audit_visibility_guard` +1, `developer_ring_isolation` +1, `developer_forge_invisibility` +1); reconcile both → recomputed row guard+widget **+27** (16 + 3 + 8), and sweep the spec's own stale citations (note 8) — same change set.
6. **M6 — rollback (contingency, not a sequential step — runs only if M4/M5 fail and a clean revert is needed after M5):** `git checkout -- test/audit_contract_guard_scans.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart docs/campaigns/implementation-gate.md` — **4 tracked files** (3 test files + the G7 gate doc). The design/spec docs are *untracked* — `git checkout --` on them errors ("pathspec did not match"); delete them manually if needed. This restores the HEAD line baseline every citation refers to; zero production surface touched, nothing else to unwind. The 3-test-file set is disjoint from the B6-2 modified set (5 B6-2 files), so no clobbering.

## 5. Testable acceptance mapping

| Spec acceptance | Requirement | Concrete gate (testable) | Red when |
|---|---|---|---|
| **AC-1** — roots extension + F2 pin | REQ-1, REQ-2 | (i) `scanDeveloperAuditBoundary` exported with scan id `developer-audit-boundary`, module prefix `screens/developer/`, wide-net semantics (M1); (ii) green-against-tree test: `scanLibDirectory(packageLibDir())` filtered by the new id → empty; (iii) F2 pin extension: dirty temp tree's `screens/developer/_probe.dart` `'AUDIT'` → `developer-audit-boundary` non-empty via the real loop; clean control `'activity'` → empty; (iv) portal id + messages still pinned (portal detail-string pin §1.2B item 3 + M1/M4 `git diff -U0`, portal skins) | any `audit` occurrence in the developer module; loop call dropped (:111) → (iii) red while (ii) passes vacuously; prefix/id typo → (iii) red while (ii) passes vacuously (the (ii) filter uses the correct id, so it sees an empty result); case-insensitive flag dropped → (iii) red (uppercase `'AUDIT'` needle, V2a); portal refactor drift → detail-string pin red + M1/M4 diff red |
| **AC-2** — green at HEAD, zero `lib/` edits | REQ-1, REQ-4 | (i) guard suite 64/64 (M4 counts); (ii) `git diff --stat HEAD -- lib/` delta attribution: identical to the M1-step-0 baseline → this change set adds no `lib/` path (V8/F9) | any new `lib/` path in the change set; any guard-suite regression |
| **AC-3** — three mutation probes fail closed | REQ-3 | (i) per-function probes: `AuditLogService` import → `developer-audit-boundary` non-empty; `'/api/v1/audit/events'` literal → non-empty; `// bff` → `bff-literals` non-empty (all labeled `screens/developer/…`); (ii) mutation skins A/B/C on `_libSource('screens/developer/developer_api.dart')` through the extended `_scanWith` dispatch, each asserting `mutated != source` | scan semantics loosened (wrong prefix, wrong id) → probes/skins red; dispatch block or default-set entry missing → skins red; anchors dead (:3 http import, :104 `'/register'`) → `mutated == source` fails loudly. (Case-insensitivity is *not* claimed here — every probe/skin needle is lowercase; the flag is pinned by the F2 uppercase needle, AC-1(iii)/V2a) |
| **AC-4** — T-12 joint gate | REQ-4 | `make test` green at CI (`.github/workflows/ci.yml:49-50`, `Makefile:51-53`) with the extended suite; landed developer AC-1/AC-2/AC-3 (`test/developer_ring_isolation_test.dart`, `test/developer_audit_visibility_guard_test.dart`, `test/developer_forge_invisibility_test.dart`) pass unchanged; G7 count row refreshed (M5, `implementation-gate.md:79`) | any guard-suite failure in the joint gate; count assertion stale → gate CI red; landed tests touched |

**Change set summary:** 3 test files, additive (`scans.dart`, `guard_test.dart`, `mutation_test.dart`) + the G7 gate-doc count row. Zero `lib/`. Dependencies: none beyond the landed ring-isolation set (already green) and the B6-2 working-tree delta (inert, V8). Guard suite before: **56/56** (executed at HEAD `e1073ce`); after: **64/64** (+5 guard test: green + 3 probes + portal detail-string pin; +3 mutation skins). Rollback is a 4-file revert (3 test files + `docs/campaigns/implementation-gate.md`).
