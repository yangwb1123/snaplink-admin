# B6-2 Hardening amendment — census gate G1–G7 closure, F7/F8 claim corrections, and pass criteria

> Converts the security reviewer's proven evasion forms (G1–G7, adversarial-review stage of run `land-the-m2-single-source-constantization-ssoadm-6d86d228`) into decision-ready amendments to `test/oidc_login_handle_success_census_test.dart` (the census gate). Every amendment below was **validated by live mutation against the amended gate on this tree** — all mutations reverted, working tree restored byte-identical (md5-verified), joint green after restore. Status: **specification** — apply per §8 (the appendix code is the validated, verbatim application unit).

Target: WT census gate (`test/oidc_login_handle_success_census_test.dart`, uncommitted in-flight state with the `lib/` single-source clause + 43-gate joint). Design under amendment: `docs/proposals/b6-2-lib-screens-oidc-login-client-id-alignment-design.md` (F1–F9). Precedent for the runner-level check: `Makefile guard-count-pin` (G7 B6-1 executable count pin).

---

## 1. Measured baseline and hole inventory

Baseline measured on this tree before any change: the five-file joint (`census + client_id + sso + sso_login_exactly_once + entry_ux`) → **43/43 green**; in-file count sub-assertions 10/3/17/3/10 → sum 43.

| # | Hole (security review) | Pre-amendment status | Amendment | Post-amendment (measured) |
|---|---|---|---|---|
| G1 | Double-quoted literal `"sso-admin-console"` in test/ | GREEN (evades) | A3 | **RED** — `Expected: empty / Actual: {'test/…probe_G1…': [3]}` |
| G2 | Split-half `'sso-admin-' 'console'` in test/ | GREEN | A3 (bare prefix) | **RED** |
| G3 | Escape suffix `'sso-admin-\u0063onsole'` in test/ | GREEN | A3 (bare prefix) | **RED** |
| G4 | Interior split `'sso-' + 'admin-console'` in lib/ | GREEN | **Accepted residual** (§5 R1) | stays GREEN by design — rationale written |
| G5 | Flip-detector comment spoof (constant deleted, `// static const …` left) | GREEN (state misreport) | A2 | **RED** — absent branch, `Expected: {pinned sites} / Actual: {}` |
| G6 | Guard self-silencing (`@TestOn('vm')` → `@TestOn('browser')`) | exit 0, joint reports **+33** with the census silently dropped | A1 | **RED** — in-file ban for partial silencing; `census-count-pin` FAILs on the full-file flip (extracted count 33 ≠ 43) |
| G7 | Scope holes — `test/` walk non-recursive; non-Dart fixtures; `integration_test/`/`test_driver/` | invisible today (1 dir / 136 dart / 0 non-dart — measured) | A4 (recursive walk) + accepted residual (§6 R2) | recursive closure measured green; residuals ruled |
| E7 | Duplicate declaration → `List.single` crash instead of informative expect | crash (red, unreadable) | A2 | **RED informatively** — `Expected: <1> / Actual: <2>` with the site map |
| F8 | Rename `firstPartyClientId` → `firstPartyClientId2` | WT substring checks pass (rename-relaxation) | A2 (`\b` boundary) | **RED** — flip detector lands in the absent branch |

Measured runner behavior (toolchain: Flutter 3.47.0-0.4.pre, master): a `@TestOn('browser')` census run alone prints `No tests ran.` / `No tests were found.` with exit **79**; the five-file joint with the census silenced exits **0** and reports `+33: All tests passed!` (the four other files run). Exit codes are therefore toolchain/command-shape dependent (the reviewer measured exit 0 on the single-file run) — the **numeric summary-line pin is the version-independent needle**; never rely on exit code alone for "tests ran" (same conclusion as the gate doc's M5 for `guard-count-pin`).

---

## 2. Amendment A1 — close G6 (self-silencing)

Two independent layers; both required (one is in the file, one is at the runner — the file layer cannot fire when the file is fully silenced).

### A1.1 In-file self-ban (catches partial silencing of the census file)

Extend the existing silencing ban to the census file **itself**, with two self-hit controls:

1. **Split-token pattern definition** — the ban pattern is written with split string literals (`"skipT" 'ag|@' "Skip|@T" 'ags|' … "@Test" "On\\s*…"`) so the census file's own definition text never contains the contiguous tokens it bans (same convention as the `literal` split). Semantics of the pattern are unchanged: `skip\s*: | skipTag | @Skip | @Tags | tags\s*: | @TestOn` with a non-`'vm'` argument.
2. **Comment stripping** — the census file's own explanatory comments legitimately name `@TestOn`/`skip` forms; scan the census file with a quote-aware `//`-comment stripper first (code tokens still match; comment tokens are inert and would self-hit otherwise).

The census file joins the ban list (`test/oidc_login_handle_success_census_test.dart` first). Line 1's `@TestOn('vm')` remains allowed by the pattern's negative lookahead (it matches the default VM runner).

Validated: adding `skip: 'probe',` to any census test → **RED** (`Expected: false / Actual: <true>` + `silencing tokens banned in test/oidc_login_handle_success_census_test.dart (joint-gate file, including the gate itself — G6)`). The four sibling joint files keep their existing ban.

### A1.2 Runner-level `census-count-pin` (catches full-file silencing)

A full-file `@TestOn('browser')` flip silences everything in the census file, so no in-file check can fire. Close with the repo's established mechanism (`guard-count-pin`, gate doc M5): numeric equality on the expanded reporter's summary line.

New Makefile target (tab-indented, mirrors `guard-count-pin` exactly):

```make
# ── G6 (B6-2) census joint count pin — closes the guard self-silencing hole ──
# The five-file census joint must report EXACTLY +$(CENSUS_PIN_COUNT) on the
# VM platform (census 10 + client_id 3 + sso 17 + sso_login 3 + entry_ux 10
# = 43, 2026-08-08 re-measured — matches the census file's in-file 43
# assertion). Fail-closed: numeric equality on the expanded reporter's
# summary line reds on (a) a deleted guard test, (b) a @TestOn
# platform-mismatch silently dropping the census file (silenced joint exits
# 0 and reports +33 — the exit code alone cannot catch it, security review
# G6), and (c) any added test that forgets to re-pin the 43 assertion
# together with this target. The command MUST run on the default VM
# platform (the census file is @TestOn('vm')).
CENSUS_PIN_FILES = test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart test/sso_client_login_exactly_once_test.dart test/entry_ux_test.dart
CENSUS_PIN_COUNT ?= 43
census-count-pin:
	@set -eu; \
	out="$$(flutter test $(CENSUS_PIN_FILES) -r expanded 2>&1)"; \
	count="$$(printf '%s\n' "$$out" | sed -nE 's/^.*\+([0-9]+): All tests passed!$$/\1/p' | tail -1)"; \
	if [ -z "$$count" ]; then printf '%s\n' "$$out" >&2; echo 'FAIL: census joint did not report "All tests passed!" (compile error, test failure, or a silenced file — a @TestOn mismatch prints "No tests ran" with exit 0)' >&2; exit 1; fi; \
	if [ "$$count" -ne "$(CENSUS_PIN_COUNT)" ]; then printf '%s\n' "$$out" >&2; echo "FAIL: census joint count +$$count != +$(CENSUS_PIN_COUNT) (G6 pin — re-measure with -r expanded and re-pin this target and the census file's in-file 43 assertion together)" >&2; exit 1; fi; \
	echo "census count pin: OK (+$$count: All tests passed!)"
```

CI wiring (`.github/workflows/ci.yml`, `check` job — add after the `guard-count-pin` step):

```yaml
      - name: Census count pin (G6 B6-2 — census joint must report exactly +43)
        run: make census-count-pin
```

Validated end-to-end: with the census file silenced, the joint exits **0** and the pin extraction yields `33` → the target's `-ne 43` branch FAILs. With the joint intact, extraction yields `43` → OK.

---

## 3. Amendment A2 — anchor the G5 flip detector (and restore F8's rename detection, make E7 informative)

Replace the unanchored `File(ssoClientPath).readAsStringSync().contains(constantDecl)` with a line-anchored, non-comment, word-bounded declaration match:

```dart
final constantDeclRe = RegExp('^\\s*$constantDecl\\b');
bool isDeclLine(String line) {
  final trimmed = line.trimLeft();
  return !trimmed.startsWith('//') && constantDeclRe.hasMatch(line);
}
final constantExists = File(ssoClientPath)
    .readAsStringSync()
    .split('\n')
    .any(isDeclLine);
```

Properties, all measured:

- **G5 comment spoof**: `// static const String firstPartyClientId = 'sso-admin-console';` fails `isDeclLine` (first token is `//`) → `constantExists` is false → the gate runs the **absent** branch, whose pinned allowlist reds against a constantized tree (`Expected: {8 pinned sites} / Actual: {}`). The gate can no longer advertise zero-tolerance while no constant exists.
- **F8 rename**: `firstPartyClientId2` fails the `\b` boundary (no word boundary between `d` and `2`) → same absent-branch red. This restores the design's F8 "flips red" property, which the WT lib clause's substring checks had inadvertently relaxed (both `contains(constantDecl)` and the decl-line-content substring check match `firstPartyClientId2`).
- The decl-line-content invariant in the constant branch uses `isDeclLine(...)` on the single hit line (was `.contains(constantDecl)`) — same anchored semantics.
- **E7 informative failure**: before `libOffenders[ssoClientPath]!.single`, assert `expect(libOffenders[ssoClientPath]!.length, 1, reason: …)`. A duplicate declaration (two hits in the same file — `libOffenders.length` stays 1) now fails with `Expected: <1> / Actual: <2>` + the site map instead of a `List.single` crash. Validated.
- **Self-presence pins**: new anchored statement pins keep the machinery in the census file (deleting the detector, hardcoding `constantExists`, or relocating the matcher reddens): `^\s*final constantDeclRe =`, `^\s*final constantExists = File\(`, `^\s*bool testCarriesValue\(String path, String line\)` (the last belongs to A3).

---

## 4. Amendment A3 — broaden the test/ matcher (G1–G3)

Replace the single-quoted-only scan with a three-form matcher over `test/*.dart`:

```dart
const literalDq = '"sso-admin-' 'console"';           // double-quoted form (G1)
const censusPath = 'test/oidc_login_handle_success_census_test.dart';
bool testCarriesValue(String path, String line) =>
    line.contains(literal) ||
    line.contains(literalDq) ||
    (path != censusPath && line.contains('sso-admin-'));
```

- **G1** — the contiguous double-quoted form is caught by `literalDq` (split in the census file's own source so it cannot self-hit; measured: zero double-quoted hits in `test/` today).
- **G2 / G3** — both keep `sso-admin-` contiguous in raw source (`'sso-admin-' 'console'`, `'sso-admin-\u0063onsole'`), so the **bare-prefix** scan catches them. Measured: zero raw `sso-admin-` hits in non-census `test/` files today → zero false positives; the census file is excluded from the bare-prefix scan only (its split-literal convention and reason strings carry the prefix by construction — the same self-exclusion the count gate applies). The contiguous quoted forms still scan the census file (its source never contains them).
- The lib/ clause keeps its existing `literal || 'sso-admin-'` matcher unchanged (its over-breadth and G4 limitation are now documented in-file per §5).

---

## 5. Amendment A4 — close the test/ walk scope hole (G7, part 1); residual ruling R1 (G4) and R2 (G7, part 2)

### A4 — recursive test/ walk

`Directory('test').listSync()` → `Directory('test').listSync(recursive: true)` (the lib/ clause already walks recursively). Closes a future `test/subdir/` literal. Measured cost: zero (no subdirectories today; the `.dart` filter and the census-file path exclusion are unaffected). This is a 1-line change with a dedicated self-presence pin (`^\s*for \(final entity in Directory\('test'\)`).

### R1 — G4 (interior split in lib/) accepted residual, written rationale

**Ruling: accepted.** The lib clause scans contiguous `sso-admin-`; `'sso-' + 'admin-console'` keeps no contiguous prefix (E6 proven green pre-amendment; still green post-amendment by design).

1. **Closure cost is a permanent false-positive tax (measured).** A `sso-`-prefix scan hits `lib/app_router.dart:13` (`sso-server` doc comment) in addition to the declaration site — requiring a permanent allowlist that any future legitimate `sso-` token (identifier, comment, i18n string, session key) would trip. The `'console'` half-token was already probed to redden on legit lib/ debug strings (in-file gate comment). The asymmetry is deliberate: the matcher is over-broad on the lib/ side already; going further converts the gate into a lint with a growing allowlist.
2. **The value is not a credential** (security review §A — public OAuth2 client identifier; no secret, no logging, no telemetry).
3. **G4 is a deliberate, review-visible act.** Exploiting it requires deleting the constant, rebuilding the value at a consumer site via a split expression, AND repairing every compile-time reference (8 test co-sites + `app_router.dart` wiring + `login` default) — a multi-file edit that the gate's absent-branch red would flag on the first commit anyway (constant deleted → pinned-allowlist mismatch).
4. **Wire-level layers still pin the value end-to-end**: harness `lastClientId == SSOAdminClient.firstPartyClientId` on submit and retry (compile-linked); drill step-1/step-3 hard equality (`AGREED_CLIENT_ID`, exit 1 on divergence); `Session.store` key contract. These are behavioral, not textual — they catch runtime drift that raw-text scans cannot.
5. **Re-open criterion**: if Branch A (value change) ever proceeds, F6's flip path re-measures the value census by grep and the drill's `AGREED_CLIENT_ID` diverges → drill step 1 reddens. At that moment the `sso-`-prefix cost can be re-bid against the actual token inventory.

### R2 — G7 remainder (non-Dart fixtures; integration_test/ / test_driver/; escape-obfuscated prefixes) accepted residual, written rationale

**Ruling: accepted.** Measured today: `test/` = 1 dir, 136 dart files, 0 non-dart; no `integration_test/` or `test_driver/` trees exist.

1. **Non-Dart fixtures under `test/`** are data, not code consumers — the single-source rule targets code references. Landing-time grep AC-3 (`grep -rn "'sso-admin-console'" test/` → exit 1) covers all file types, and the permanent Dart-tree enforcement is the census + `census-count-pin`.
2. **`integration_test/` / `test_driver/`** (absent today) are separate test trees with their own contract records; the census governs the unit/widget tree that the count pins (10/3/17/3/10 → 43) enumerate. A value there is pinned by the drill's `AGREED_CLIENT_ID` and the harness wire asserts — the same layers as R1.4. Expanding the census into those trees would duplicate the drill's purpose and widen the gate's blast radius.
3. **Escape-obfuscated prefixes** (`\u0073so-admin-…` or hex/octal variants where even the prefix is escaped): a raw-text census cannot see through arbitrary escape sequences without a full Dart tokenizer (the b6-1c scan-1 tokenizer is the precedent if this class ever becomes worth closing). This mirrors the accepted R9 class in `docs/proposals/b6-1c-guard-mutation-drill.md`; the wire-level layers remain the backstop.

---

## 6. F7/F8 claims — corrected to measured reality (also applied to the design doc)

The design doc (`docs/proposals/b6-2-lib-screens-oidc-login-client-id-alignment-design.md`, §5 rows F7/F8) is amended in place; the corrected text:

- **F7** — the claim "a fresh literal is caught **regardless of how it's produced**" is **retracted**. Measured: G1 (double-quoted), G2 (split-half), G3 (escape suffix), G4 (interior split) all evaded the pre-amendment gate in mutation (E3–E6). Corrected claim: compile-time half sound (absent/renamed symbol breaks the 8 constantized co-sites); textual half catches the contiguous single/double-quoted literal and any raw `sso-admin-` prefix in non-census test files (A3) — everything else is residual with written rationale (R1/R2) or wire-level backstop.
- **F8** — the claim "a renamed constant flips the gate red … forcing a conscious update" was **measured false at the WT gate**: `constantExists`'s unanchored `contains()` and the decl-line substring check both match `firstPartyClientId2` (rename-relaxation), and a comment replica of the declaration satisfies both (G5 spoof) — the gate reported zero-tolerance with no constant present. Corrected claim: with A2's anchored non-comment `\b`-bounded match, rename → absent-branch red and comment spoof → absent-branch red (both re-proven by mutation); self-hit protection (split literal) unchanged.

---

## 7. Pass criteria (each hole closes; counts unmoved; 43-joint intact)

Apply order: A1.1+A2+A3+A4 code (appendix, verbatim) → A1.2 Makefile target + CI step. Then:

| # | Criterion | Pass |
|---|---|---|
| P1 | Joint green, counts unmoved: `flutter test` on the five joint files → **43/43**; in-file sub-assertions 10/3/17/3/10 → sum 43 (the amendments add zero test declarations — the appendix adds none) | 43/43 (measured twice post-amendment) |
| P2 | Analyzer: amended census file introduces **zero new findings** (baseline carries 4 pre-existing infos: 2× `unnecessary_string_interpolations` at `${lines[j]}`, 2× `curly_braces_in_flow_control_structures` — same statements as the pre-amendment file) | 4 pre-existing infos only (measured) |
| P3 | `make census-count-pin` → `census count pin: OK (+43: All tests passed!)` | OK (measured) |
| P4 | **G1**: plant `const v = "sso-admin-console";` in a temp `test/` file → census red with the file:line in the message; remove probe | RED (measured) |
| P5 | **G2**: plant `const v = 'sso-admin-' 'console';` → red; remove | RED (measured) |
| P6 | **G3**: plant `const v = 'sso-admin-\u0063onsole';` (heredoc-verified bytes) → red; remove | RED (measured) |
| P7 | **G5**: delete the constant, leave `// static const String firstPartyClientId = 'sso-admin-console';` → census-only run red (absent branch); restore | RED (measured) |
| P8 | **G6a**: census line 1 → `@TestOn('browser')` → `make census-count-pin` FAILs (extracted count ≠ 43; silenced joint exits 0 and reports +33); restore | FAIL as required (measured) |
| P9 | **G6b**: add `skip: 'probe',` to one census test → red via the self-ban; restore | RED (measured) |
| P10 | **E7**: duplicate the declaration line → informative red (`Expected: <1> / Actual: <2>` + site map), no `List.single` crash; restore | RED informative (measured) |
| P11 | **F8 rename**: `firstPartyClientId` → `firstPartyClientId2` → census-only run red (absent branch); restore | RED (measured) |
| P12 | **Residuals**: R1/R2 rulings present in this document; gate stays green against the current tree (P1 covers it) | documented |
| P13 | Working tree restored: census file and `lib/api/sso_client.dart` md5-identical to the pre-drill state; no probe files remain | verified |

Standing procedure: **any future edit to the literal-census group re-runs P4–P11** (the drill is transient by nature — the in-file self-presence pins and the silencing ban are the permanent regression encoding; they redden on deletion, and P4–P11 redden on weakening). The count pins and the 43 assertion move **only** together with `CENSUS_PIN_COUNT` and a re-measure (same rule as the G7 row/`GUARD_PIN_COUNT` pairing).

---

## 8. Files touched (implementation scope)

1. `test/oidc_login_handle_success_census_test.dart` — apply the appendix code (A1.1, A2, A3, A4). Counts unchanged (10 tests in the census file).
2. `Makefile` — add the `census-count-pin` target (A1.2).
3. `.github/workflows/ci.yml` — add the `make census-count-pin` step after `guard-count-pin` (A1.2).
4. `docs/proposals/b6-2-lib-screens-oidc-login-client-id-alignment-design.md` — F7/F8 rows corrected per §6.
5. `docs/proposals/b6-2-lib-screens-oidc-login-m2-census-hardening-amendment.md` — this document (residual rulings R1/R2 are the permanent record).

No changes to `lib/`, `tests/integration/`, the drill, or any count-pinned test file.

---

## Appendix — validated application unit (amended literal-census group)

Validated verbatim on this tree (43/43 green + P4–P11 red matrix); apply as-is. Self-presence pins make the group self-checking against deletion/relocation. Line numbers shift on application; the pins are statement-anchored, not line-anchored.

```dart
  group('client_id literal census (single-source rule, §6.4 gate c)', () {
    // Split so the exact quoted literal never appears in this file's source
    // (the census scans test/*.dart and must not self-hit). Same convention
    // for the double-quoted form (G1) and the silencing-ban pattern tokens
    // (G6): this file's raw source must never contain what it bans.
    const literal = "'sso-admin-" "console'";
    const literalDq = '"sso-admin-' 'console"';
    const ssoClientPath = 'lib/api/sso_client.dart';
    const constantDecl = 'static const String firstPartyClientId';
    // G5 (security review): the flip detector's anchored, non-comment
    // declaration form — line-anchored, first token not a comment,
    // word-bounded. A comment replica
    // (`// static const String firstPartyClientId = …`) or a renamed
    // constant (`firstPartyClientId2`) does NOT satisfy it; both flip the
    // gate to the ABSENT branch (pinned allowlist) instead of advertising
    // zero-tolerance on a lie. The `\b` boundary restores F8's rename
    // detection, which the WT lib clause's substring check had relaxed.
    final constantDeclRe = RegExp('^\\s*$constantDecl\\b');
    bool isDeclLine(String line) {
      final trimmed = line.trimLeft();
      return !trimmed.startsWith('//') && constantDeclRe.hasMatch(line);
    }

    // The census file itself is excluded from the bare-prefix scan below:
    // its split-literal convention and reason strings carry the prefix by
    // construction (self-hit — the same self-exclusion the count gate
    // applies). The contiguous quoted forms still scan the census file,
    // whose source never contains them (split convention).
    const censusPath = 'test/oidc_login_handle_success_census_test.dart';
    // Pinned literal sites while the sibling constant is absent (HEAD state).
    const pinnedSites = <String, List<int>>{
      'test/sso_client_test.dart': [18],
      'test/oidc_account_flow_test.dart': [35, 75, 115, 160],
      'test/oidc_login_screen_client_id_test.dart': [76, 136, 158],
    };

    test(
      'literal census derives from constant existence + standing 43-test '
      'count gate (design §4.2/§4.4/§5/§6.4; REQ-2/REQ-4 item 6)',
      () {
        // G5: the flip is derived from an anchored, non-comment
        // declaration line — a comment spoof lands in the ABSENT branch,
        // which reds against a constantized tree (mutation E8, security
        // review) instead of reporting zero-tolerance with no constant.
        final constantExists = File(ssoClientPath)
            .readAsStringSync()
            .split('\n')
            .any(isDeclLine);
        final actual = <String, List<int>>{};
        // G1–G3 (security review): matcher widened to the double-quoted
        // form and the bare value prefix. The bare prefix catches split
        // halves ('sso-admin-' 'console'), suffix escapes
        // ('sso-admin-\u0063onsole'), and interpolation fragments — all
        // keep `sso-admin-` contiguous in raw source. The census file is
        // excluded from the bare-prefix scan only (self-hit). G4 (interior
        // split 'sso-' + 'admin-console' in lib/) is an accepted residual
        // — see hardening amendment §R1.
        bool testCarriesValue(String path, String line) =>
            line.contains(literal) ||
            line.contains(literalDq) ||
            (path != censusPath && line.contains('sso-admin-'));
        // G7 (security review): recursive walk — a future test/subdir/
        // literal is visible, not just top-level test/*.dart.
        for (final entity in Directory('test').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = File(entity.path).readAsStringSync().split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (testCarriesValue(entity.path, lines[i])) {
              actual.putIfAbsent(entity.path, () => []).add(i + 1);
            }
          }
        }
        // ---- lib/ single-source clause (REQ-2, design §2.2a) ----
        // Recursive lib/ scan with the same split-literal convention: in
        // constant mode exactly the declaration site may carry the value;
        // in absent mode the two historical production sites are pinned.
        // The matcher is deliberately broader than the test/ side: the
        // contiguous quoted literal OR the bare value prefix. The bare
        // form covers split halves, adjacent concatenation, and
        // interpolation — but only while `sso-admin-` stays contiguous:
        // an interior split ('sso-' + 'admin-console') evades it (G4,
        // proven by mutation E6) and is an ACCEPTED RESIDUAL (hardening
        // amendment §R1): closing it needs a `sso-`-prefix scan that
        // false-positives on legit lib/ text (measured: the `sso-server`
        // doc comment at lib/app_router.dart:13), and the wire-level
        // layers (harness lastClientId, drill AGREED_CLIENT_ID) pin the
        // value end-to-end. The 'console' half-token is deliberately NOT
        // scanned: it is a legitimate token in lib/ debug strings
        // (probed: reddens on legit code).
        bool libCarriesValue(String line) =>
            line.contains(literal) || line.contains('sso-admin-');
        final libOffenders = <String, List<int>>{};
        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = File(entity.path).readAsStringSync().split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (libCarriesValue(lines[i])) {
              libOffenders.putIfAbsent(entity.path, () => []).add(i + 1);
            }
          }
        }
        // Self-presence pin: the walk and its collector must physically
        // live in THIS file (deleting the walk reddens; relocating it to a
        // helper or hiding it in a comment does too — anchored statement
        // forms, not bare contains). The G5/G1–G3 machinery is pinned the
        // same way (hardening amendment A2/A3).
        final censusLines = File(
                'test/oidc_login_handle_success_census_test.dart')
            .readAsStringSync()
            .split('\n');
        expect(
            censusLines.indexWhere((l) =>
                RegExp(r"^\s*for \(final entity in Directory\('lib'\)")
                    .hasMatch(l)),
            isNot(-1),
            reason: 'lib clause walk must be a statement of this file');
        expect(
            censusLines.indexWhere((l) => RegExp(
                    r'^\s*final libOffenders = <String, List<int>>\{\};')
                .hasMatch(l)),
            isNot(-1),
            reason: 'libOffenders collector must be declared in this file');
        expect(
            censusLines.indexWhere(
                (l) => RegExp(r'^\s*final constantDeclRe =').hasMatch(l)),
            isNot(-1),
            reason: 'G5 anchored flip detector must be declared in this file');
        expect(
            censusLines.indexWhere(
              (l) => RegExp(r'^\s*final constantExists = File\(').hasMatch(l),
            ),
            isNot(-1),
            reason: 'flip detector must derive from the sso_client.dart '
                'file read, not a hardcoded state');
        expect(
            censusLines.indexWhere((l) => RegExp(
                    r'^\s*bool testCarriesValue\(String path, String line\)')
                .hasMatch(l)),
            isNot(-1),
            reason: 'G1–G3 test/ matcher must be declared in this file');
        if (constantExists) {
          // Single-source rule active: once SSOAdminClient.firstPartyClientId
          // exists, no test may carry the value as a fresh literal — every
          // reference goes through the constant. The sibling co-change list
          // constantizes the anchor's REQ-2 file in the same commit (M2); a
          // forgotten co-site fails here immediately (red, not silent).
          expect(actual, isEmpty,
              reason: 'firstPartyClientId exists in $ssoClientPath — the '
                  'sso-admin-console literal must not appear in test/; '
                  'every reference goes through the constant');
          // Constant mode lib/ clause: exactly the declaration site, and
          // that site's line carries the declaration itself (site +
          // declaration-line-content invariant, not an absolute line pin).
          expect(libOffenders.length, 1,
              reason: 'exactly one lib/ site may carry the literal in '
                  'constant mode — found $libOffenders');
          expect(libOffenders.keys.single, ssoClientPath,
              reason: 'the single lib/ site must be the declaration file '
                  '$ssoClientPath — found $libOffenders');
          // E7 (security review): a duplicate declaration keeps length 1
          // (both hits inside the same file) — fail informatively here
          // instead of crashing on List.single.
          expect(libOffenders[ssoClientPath]!.length, 1,
              reason: 'the declaration file must carry exactly one value '
                  'site — a duplicate declaration or second literal fails '
                  'here ($libOffenders)');
          final declLine = libOffenders[ssoClientPath]!.single;
          expect(
            isDeclLine(File(ssoClientPath)
                .readAsStringSync()
                .split('\n')[declLine - 1]),
            isTrue,
            reason: 'the single lib/ hit must be the declaration line '
                '($ssoClientPath:$declLine) — found $libOffenders',
          );
        } else {
          // Pre-sibling: the literal census equals exactly the pinned sites.
          expect(actual, pinnedSites,
              reason: 'constant absent — literal census is pinned; the '
                  'sibling M2 commit constantizes these sites in the same '
                  'commit (anchor design §4.2)');
          // Absent mode lib/ clause: the two pre-constantization
          // production sites (anchor spec §1.4 census coordinates),
          // preserved for two-state traceability. Compile-broken at HEAD.
          expect(libOffenders, {
            'lib/api/sso_client.dart': [86],
            'lib/app_router.dart': [35],
          },
              reason: 'constant absent — lib/ literal census is pinned');
        }

        // ---- 43-test self-count regression gate (design §4.4) ----
        // (unchanged — see the current file; the amendments add zero test
        // declarations, so the 10/3/17/3/10 sub-assertions and the 43 sum
        // are untouched by construction)

        // ---- silencing ban (mutation-audit §2 A/B; G6 extension) ----
        // The gate's counts are text-based, so an exclusion token on any
        // joint-gate file would silently shrink the 43-run (@TestOn
        // platform-mismatch → "No tests ran" with exit 0 or a non-green
        // code, skip: → skipped without red). G6: the ban now covers the
        // census file ITSELF, scanned with its own comments stripped (the
        // ban's explanatory comments legitimately name the tokens) and a
        // pattern written with split tokens so its definition cannot
        // self-hit. The line-1 @TestOn('vm') annotation is allowed
        // (negative lookahead — it matches the default VM runner); any
        // other silencing token fails here while the file still runs, and
        // a full-file @TestOn flip (which silences everything, so nothing
        // in this file can fire) is caught by the runner-level
        // census-count-pin (Makefile, G6).
        final silenceRe = RegExp(
          "skip\\s*:|skipT"
          'ag|@'
          "Skip|@T"
          'ags|'
          "tags\\s*:|@Test"
          "On\\s*\\((?!\\s*['\"]vm['\"])",
        );
        // Quote-aware //-comment stripper for the census file's own ban:
        // real code tokens (skip:, @Skip, @Tags, tags:, @TestOn with a
        // non-vm argument) still match after stripping.
        String stripLineComments(String src) {
          final buf = StringBuffer();
          var inStr = false;
          var quote = '';
          for (var i = 0; i < src.length; i++) {
            final c = src[i];
            if (!inStr) {
              if (c == "'" || c == '"') {
                inStr = true;
                quote = c;
                buf.write(c);
              } else if (c == '/' &&
                  i + 1 < src.length &&
                  src[i + 1] == '/') {
                while (i < src.length && src[i] != '\n') {
                  i++;
                }
                if (i < src.length) buf.write('\n');
              } else {
                buf.write(c);
              }
            } else {
              if (c == '\\') {
                buf.write(c);
                if (i + 1 < src.length) {
                  i++;
                  buf.write(src[i]);
                }
              } else {
                if (c == quote) inStr = false;
                buf.write(c);
              }
            }
          }
          return buf.toString();
        }

        for (final f in [
          'test/oidc_login_handle_success_census_test.dart', // G6: the gate itself
          'test/sso_client_login_exactly_once_test.dart',
          'test/oidc_login_screen_client_id_test.dart',
          'test/sso_client_test.dart',
          'test/entry_ux_test.dart',
        ]) {
          expect(
              silenceRe.hasMatch(
                  stripLineComments(File(f).readAsStringSync())),
              isFalse,
              reason: 'silencing tokens banned in $f (joint-gate file, '
                  'including the gate itself — G6)');
        }
      },
    );
  });
```

Application notes: (1) the 43-test count gate block between the two markers is left untouched in place (the appendix elides it only to avoid duplication); (2) the `// G6: the gate itself` inline comment and the split-token pattern are load-bearing for the self-scan — do not "clean them up"; (3) after applying, run `dart format` on the file, then the P1–P13 matrix; the amended file must report the same 4 pre-existing analyzer infos and nothing new.
