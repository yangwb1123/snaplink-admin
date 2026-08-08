# B6-1 Verified Design — Developer negative boundary (scan 6 parity): final contract, reconciliation, and closure

> Status: **design of record for the landed implementation**, re-verified against current HEAD `3b22ed4` + working tree on 2026-08-08. Supersedes the stale portions of `b6-1-lib-screens-developer-negative-boundary-design.md` (whose 56→64 arithmetic predates the B6-1a/1b additions to the same files). Sibling spec: `b6-1-lib-screens-developer-negative-boundary-spec.md` (6+/6- citation corrections, committed together with this document in M2).
> Method: every claim in the supplied evidence was re-checked against the repository, and the guard suite was **re-executed** (79/79) rather than trusted.

## 0. Evidence verification verdict

| Evidence claim | Repository reality (re-verified) | Verdict |
|---|---|---|
| `scans.dart` scan 6 (`scanPortalAuditBoundary` :465-475), `_auditAnyPattern` :431, `_scanNegativeBoundary` :433-456 | Exact. Helper parameterized over `(modulePrefix, scanId, moduleLabel, boundaryReason)`; portal scan is a one-line delegate; `_auditAnyPattern = RegExp(r'audit', caseSensitive: false)` | ✅ exact |
| `scanDeveloperAuditBoundary` (id `developer-audit-boundary`) wired into `scanLibDirectory` :124 | Exact. Per-file loop :119-125 (audit-path :119, bff :120, raw :121, second-consumer :122, portal :123, **developer :124**, ring :125); trio-owner post-loop :127 | ✅ exact |
| F2 pin uppercase `'AUDIT'` probe :359-362; probes 1-3 :447-487; V1 byte-identity pin :489-505; scan-6b group :439-506 | Exact. Group `'scan 6b — developer-audit-boundary'` :439-506; green live-module :440-445; probe 1 (AuditLogService import) :447-458; probe 2 (`'/api/v1/audit/events'`) :460-471; probe 3 (`// bff` via `scanBffLiterals`) :473-487; V1 portal detail-string pin :489-505 (em-dash U+2014 asserted) | ✅ exact |
| `_scanWith` dispatch :38-45 + :70-72; mutation skins A/B/C :417-462 (group :411-463) | Default set :38-45 includes `developer-audit-boundary` (:43); dispatch block :70-72 inside the per-file loop; skins group :411-463; **skin tests at :417-434 (A), :436-448 (B), :450-462 (C)** — re-pinned exact in this batch (the prior draft's :417-436/:438-450/:452-463 and the spec's :418-435/:437-449/:450-462 were off by ±2) | ⚠ re-pinned exact (was ±1-2 in the prior draft; group span exact) |
| `oidc_login_audit_visibility_guard_test.dart` AC-2 :25-47 | Exact: `moduleDir` :25, split-literal `banned` :26, recursive `dart:io` scan :28-38, `expect(offenders, isEmpty)` :39-47; file is 48 lines | ✅ exact |
| `lib/app_router.dart:31` "exact at HEAD; working tree :32 (B6-2 delta)" | **Stale at current HEAD.** Was exact at verification-basis `e1073ce`; the B6-2 delta has since been **committed** (`db6e435`, `a2b04fc`) → `ProductEntry.developer => const DeveloperScreen(),` is at **:32 at both HEAD and working tree**; `git diff HEAD -- lib/app_router.dart` is empty. Attribution (B6-2, not this direction) remains correct | ⚠ stale: :31→:32 at HEAD |
| `developer_api.dart` class :39, 188 lines; register/loadApp/saveApp/deleteApp; `[CORRECTION]` loadDiscovery/registerMetadata | Exact: `class DeveloperApi` :39 (188 lines); `loadDiscovery` :52, `registerMetadata` :62, `register` :75, `_registerBody` :94, `loadApp` :117, `saveApp` :136, `deleteApp` :155, `_handle` :168 | ✅ exact |
| Zero `audit`/`bff` across 13 module files (grep exit 1) | Re-run: `grep -rniE "audit\|bff" lib/screens/developer/` → 0 hits; exactly 13 `.dart` files; `git diff HEAD -- lib/screens/developer/` → empty | ✅ exact |
| Guard suite **79/79 green** (guard 37 + mutation 40 + developer guard 1 + oidc guard 1); matches G7 re-pin `implementation-gate.md:79` | **Re-executed**: `flutter test` on the four guard files → **+79: All tests passed!** G7 row at gate doc :79 pins the 79 baseline with the same breakdown | ✅ executed |
| Spec "rewritten, **untracked**" | **False**: the spec is **tracked** (`git ls-files` confirms) and the working-tree delta is 6+/6- (citation corrections :38-47→:38-45, :69-71→:70-72, :486-505→:489-505), not a rewrite | ❌ incorrect |
| "Direction already implemented in the **uncommitted working tree**" | **Stale**: implemented and **committed** at `4333f59` ("verify(b6-1): developer module ring-isolation floor + negative boundary"); `git status test/` is clean | ❌ stale |
| "Working-tree `lib/` diffs (4 sibling files)" (spec E7) | **Stale**: those diffs are committed; the working tree has **zero** `lib/` diffs (only the spec doc M and this design doc ?? differ from HEAD) | ❌ stale |
| "Remaining work: commit the working-tree change set (test-only, 3 guard files)" | **Already done** (4333f59). The only genuine remaining work is committing the spec's citation corrections **together with this design doc** (M2) and reconciling the stale claims in §0 above | ❌ stale |
| `[CORRECTION]` "scan 2 is already lib-wide; the unpinned surface was the wide case-insensitive `audit` net" | Consistent with the "What did not fail" table: `// bff` trips `bff-literals` (lib-wide) today; `AuditLogService` import, bare `/api/v1/audit` literal, `audit` in comments, and doc strings all passed the pre-landing surface and now trip `developer-audit-boundary` | ✅ exact |
| CI/Makefile: `.github/workflows/ci.yml:49-50` `make test`; `Makefile:51-53` | Exact: "Unit tests" step :49-50 → `make test`; `test:` target runs `flutter test` + `python3 -m unittest` | ✅ exact |

**Bottom line:** the direction is fully landed, committed, and green; the evidence's *structural* claims are accurate; its *state* claims (untracked/uncommitted/:31-at-HEAD/working-tree-lib-diffs) are stale snapshots from verification basis `e1073ce`.

## 1. API changes (final contract, as landed)

### 1.1 Production API — none (negative constraint, enforced)

Zero `lib/` changes were required or made. `DeveloperApi` (`lib/screens/developer/developer_api.dart`, 188 lines) acquires no audit surface: no methods, no path literals, no `AuditReadClient` wiring. `lib/screens/developer/**` remains byte-clean of `audit`/`bff` (grep exit 1; zero diff vs HEAD).

### 1.2 Test-suite API — the landed contract (3 files)

**A. `test/audit_contract_guard_scans.dart` — exported function + shared helper + loop wiring.**

```dart
List<AuditGuardViolation> scanDeveloperAuditBoundary(
  String source,
  String fileLabel,
) => _scanNegativeBoundary(
  source,
  fileLabel,
  modulePrefix: 'screens/developer/',
  scanId: 'developer-audit-boundary',
  moduleLabel: 'developer module',
  boundaryReason: "DCR reads/writes belong to DeveloperApi's /register "
      'surface; audit reads belong to SnaplinkAdminApi via AuditReadClient',
);
```

- `_scanNegativeBoundary` (:433-456): private, module-level, parameterized; early-returns `const []` for any label not starting with `modulePrefix`; reports one `AuditGuardViolation(scan: scanId, file: fileLabel, detail: 'case-insensitive "audit" at line $line; the $moduleLabel is the B6-1 negative boundary — $boundaryReason')` per case-insensitive `audit` match.
- `scanPortalAuditBoundary` (:465-475) is a one-line delegate with `moduleLabel: 'portal module'` — behavior and detail string byte-identical to the pre-refactor text (V1, enforced by the detail-string pin).
- Loop wiring: `scanLibDirectory` calls the developer scan at :124, between the portal call (:123) and the ring-storage-seam call (:125).

**B. `test/audit_contract_guard_test.dart` — scan-6b group :439-506 + F2 extension :359-362.**

- Green-against-tree (:440-445): `scanLibDirectory(packageLibDir())` filtered by `developer-audit-boundary` → empty.
- Per-function probes — probe 1 (AuditLogService import) :447-458 → non-empty; probe 2 (`'/api/v1/audit/events'` literal) :460-471 → non-empty; probe 3 (`// bff`) :473-487 → `bff-literals` non-empty.
- V1 portal detail-string pin (:489-505): fixed probe, asserts the exact byte string incl. em-dash and line math.
- F2 pin extension (:359-362): dirty temp-tree probe `screens/developer/_probe.dart` = `final _probe = 'AUDIT';` (uppercase needle — pins `caseSensitive: false` because every lowercase needle in the suite fires under both modes); `allPerFileScans` includes the developer id; clean control neutralizes to `'activity'`.

**C. `test/audit_contract_guard_mutation_test.dart` — dispatch extension :38-45/:70-72 + skins :411-463.**

- `_scanWith` default set gains `'developer-audit-boundary'` (:43); dispatch block :70-72 (inside the per-file loop, where `source`/`relative` are in scope — NOT the post-loop trio-owner block).
- Skins on `_libSource('screens/developer/developer_api.dart')`, each asserting `mutated != source` (anchor live) then `developer-audit-boundary` non-empty:
  - A (:417-434): `AuditReadClient` import + usage after the unique `http` import at :3.
  - B (:436-448): `replaceFirst("'/register'", "'/api/v1/audit'")` — bare-prefix repoint, chosen because the trio-member form `'/api/v1/audit/events'` is already caught by `trio-literal-owner` through the real loop, breaking the "missed by the landed suite, caught by the new scan" property.
  - C (:450-462): appended `/// audit probe comment`.

## 2. Compatibility constraints

1. **Purely additive guard suite.** The new scan early-returns `const []` for every label outside `screens/developer/`; scans 1/2/4/5/6/7 and the trio-owner pin produce identical violation sets. All pre-existing tests stay green (79/79 executed).
2. **Portal scan-6 behavior + messages byte-identical** (V1): preserved by the shared helper and continuously enforced by the detail-string pin — a message-drifting refactor reds the suite, not just the diff gate.
3. **No new dependencies or SDK features**: `RegExp(caseSensitive: false)` already in use; `AuditGuardViolation` shape unchanged; the new id is a plain string among the existing six.
4. **`_scanWith` default-set addition is inert for existing skins**: no existing skin mutates a `screens/developer/`-labeled file; the live module is clean.
5. **F2 discipline preserved**: one probe per scan id, per-id dirty/clean asserts, temp-dir with `addTearDown` cleanup; the `'AUDIT'` probe satisfies no other scan's trigger vocabulary.
6. **Landed ring-isolation set untouched**: `developer_audit_visibility_guard_test.dart`, `developer_ring_isolation_test.dart`, `developer_forge_invisibility_test.dart` pass unchanged (the wide net subsumes, never replaces, the AC-2 needles).
7. **No self-hit**: scans read `lib/` only; probe literals live under `test/` per existing convention.
8. **G7 gate compatibility**: the count pin at `implementation-gate.md:79` (guard 37 + mutation 40 + developer guard 1 + oidc guard 1 = 79) matches the executed suite; future batches touching the four pin files must re-measure with `-r expanded` and re-pin.

## 3. Failure modes

| # | Failure mode | Detection | Mitigation |
|---|---|---|---|
| F1 | Future developer-module content acquires any case-insensitive `audit` (import, identifier, comment, doc string, non-path string) | `developer-audit-boundary` non-empty → CI red; skins A/B/C and probes 1-2 prove fail-closed | Intended friction: forces a documented boundary amendment (record + spec + scan change) instead of silent drift |
| F2 | Loop wiring regression (developer call dropped from `scanLibDirectory`, wrong prefix, typo'd id) | F2 pin extension reds while the green-against-tree test passes vacuously (its filter uses the correct id and sees an empty result) — the two canaries are anti-correlated by construction | Extended F2 pin + skins |
| F3 | Mutation-dispatch regression (default set or dispatch block missing) | All three developer skins red through `_scanWith` | Skins self-pin the dispatch |
| F4 | Shared-helper parameter drift (wrong `moduleLabel`/`boundaryReason`/`scanId`) | Portal detail-string pin asserts exact bytes (em-dash included) → red; portal skins/F2 still pin the id | Detail pin + `git diff -U0` review of the delegate |
| F5 | Legit developer content containing "audit" (DCR client named `audit-client`, RFC 7591 doc quote) | CI red despite sound content | By design: audit reads belong to SnaplinkAdminApi/admin screens; approval requires an explicit boundary amendment |
| F6 | Skin anchor brittleness (`developer_api.dart:3` http import, `:104` standalone `'/register'`) | `mutated == source` fails loudly (or `_libSource` throws on rename) | Loud by convention; a rename also breaks the spec's greppable claim |
| F7 | Clean-control drift (neutralized probe accidentally contains `audit`) | F2 green asserts red | `'activity'` verified clean against every default-scan id |
| F8 | G7 count assertion stale after future additions to the four pin files | Gate CI red on count mismatch | Re-measure `-r expanded` and re-pin `implementation-gate.md:79` in the same change set |
| F9 | Spec/design citation drift vs the committed code (the current stale class: `app_router.dart:31`, "uncommitted working tree", skin sub-spans) | Citations no longer greppable/verifiable at HEAD | Reconciliation below (M1-M3): re-pin against current HEAD `3b22ed4`, not the historical basis `e1073ce` |

## 4. Migration steps

The implementation migration (M1-M6 of the original design) is **historical — completed and committed** at `4333f59`; the guard suite was re-executed green (79/79). The remaining migration is **documentation reconciliation and closure**:

1. **M1 — re-pin the spec's state claims to current HEAD `3b22ed4`** (`docs/proposals/b6-1-lib-screens-developer-negative-boundary-spec.md`, working tree):
   - Header: "implemented in the working tree (uncommitted)" → "implemented and committed at `4333f59`"; verification basis footnote updated.
   - E3: `app_router.dart:31` → `:32` at HEAD (the B6-2 delta is committed; keep the attribution note, drop the "working tree carries the delta" framing).
   - E7: replace "working-tree `lib/` diffs (4 sibling files)" with "zero working-tree `lib/` diffs; the B6-2/B6-1b sets are committed".
   - S4: skin sub-spans → :417-434 / :436-448 / :450-462 (group :411-463 unchanged).
   - Keep the already-corrected spans (:38-45, :70-72, :489-505).
2. **M2 — commit the spec corrections together with this design doc** (`...design.verified.md` is currently **untracked**; the 3 test files and gate doc are already committed at HEAD). Verify first: `git status --short` shows exactly the spec (M) plus `?? docs/proposals/b6-1-lib-screens-developer-negative-boundary-design.verified.md` — scope the commit to these two docs.
3. **M3 — confirm the joint gate**: `make test` green at CI (`.github/workflows/ci.yml:49-50` → `Makefile:51-53` = `flutter test` + python unittest). Guard four-file suite already re-executed 79/79 in this verification; G7 count pin (`implementation-gate.md:79`) matches.
4. **M4 — rollback (contingency)**: the landed set is **7 files** — the 3 guard files (`test/audit_contract_guard_scans.dart`, `test/audit_contract_guard_test.dart`, `test/audit_contract_guard_mutation_test.dart`) plus the 3 ring-isolation floor tests (`test/developer_audit_visibility_guard_test.dart`, `test/developer_forge_invisibility_test.dart`, `test/developer_ring_isolation_test.dart`) plus `docs/campaigns/implementation-gate.md` — so `git revert 4333f59` reverts **all 7, including the ring-isolation floor files** (validated in a scratch worktree: zero conflicts; reverted tree byte-identical to parent `db6e435`; the exported `scanDeveloperAuditBoundary` surface and the shared `_scanNegativeBoundary` helper are fully removed). The commit adds **+23 tests** (guard +9, mutation +14, developer +1), of which the 8 negative-boundary pins are a subset (the rest are the B6-1b ring-storage-seam rows a–i and the F4 anti-vacuity probe). The design/spec docs are doc-only and carry no gate weight. Zero production surface involved.

## 5. Testable acceptance mapping

| Acceptance (from the supplied evidence) | Concrete gate (testable) | Red when |
|---|---|---|
| Probe 1 — `AuditLogService` import in a `screens/developer/`-labeled source → `developer-audit-boundary` non-empty | `test/audit_contract_guard_test.dart:447-458` (`scanDeveloperAuditBoundary` direct call) — executed green | Scan semantics loosened (wrong prefix/id); helper reverted to portal-only |
| Probe 2 — `'/api/v1/audit/events'` literal → `developer-audit-boundary` non-empty (regardless of the scan-1 trio allowlist) | `test/audit_contract_guard_test.dart:460-471` — executed green | Same as probe 1; allowlist accidentally widened to the wide net |
| Probe 3 — `// bff` token → `bff-literals` non-empty (developer module inside the guarded tree) | `test/audit_contract_guard_test.dart:473-487` (`scanBffLiterals` direct call) — executed green | Scan-2 tree coverage narrowed; developer module excluded from `scanLibDirectory` |
| V1 — portal detail string byte-identical through the shared helper | `test/audit_contract_guard_test.dart:489-505` (exact string incl. em-dash) — executed green | Shared-helper parameter drift; portal message changed |
| F2 — case-insensitive wide net, per-scan-id trip through the real loop | `test/audit_contract_guard_test.dart:359-362` (uppercase `'AUDIT'` dirty probe + `'activity'` clean control, `allPerFileScans` incl. developer id) — executed green | `caseSensitive: false` dropped; loop call dropped; id/prefix typo |
| Mutation skins A/B/C — planted regressions fail closed | `test/audit_contract_guard_mutation_test.dart:411-463` (each asserts `mutated != source` then trips `developer-audit-boundary` via `_scanWith` dispatch :70-72) — executed green | Dispatch/default-set regression; dead anchors; scan semantics loosened |
| Green-against-tree — live module clean | `test/audit_contract_guard_test.dart:440-445`; plus `grep -rniE "audit\|bff" lib/screens/developer/` → exit 1; `git diff HEAD -- lib/screens/developer/` → empty — all executed | Any audit/bff content lands in the developer module |
| G7 joint gate — guard suite green in the gate, count pinned | Four-file suite 79/79 (re-executed: guard 37 + mutation 40 + developer guard 1 + oidc guard 1) = `docs/campaigns/implementation-gate.md:79`; CI runs `make test` (`.github/workflows/ci.yml:49-50`) | Any of the four pin files regresses; count assertion stale; `@TestOn('vm')` silent-skip mismatch |

**Change set summary (as landed):** 3 test files, additive (`scans.dart`, `guard_test.dart`, `mutation_test.dart`) + G7 gate-doc count row; committed at `4333f59`. Zero `lib/`. Guard suite: **79/79 green** (re-executed 2026-08-08). Remaining work: documentation reconciliation (M1), doc commit (M2), joint-gate confirmation (M3).
