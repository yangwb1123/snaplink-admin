# B6-1b — Ring write-path isolation from release builds (module `lib/api` lens: `_recordAudit` sole-writer pin + service-boundary seam)

Direction: *"Isolate the ring write path from release builds — pin `lib/api/snaplink_admin_api.dart _recordAudit` as sole writer and land the storage seam so recording itself is debug-only (not just display)"* (value 7 / risk 8 / effort 3 / confidence 8; `docs/auto/analyses/lib-api-03f8cdf9.json`). T-12 floor: `docs/campaigns/implementation-gate.md:56` — "localStorage ring 降级为调试记录；展示服务端记录", joint "devtools 伪造不再构成证据".

Normative sources (both already in repo, verified line-exact at HEAD `f8fdca7`):

1. **Spec:** `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-spec.md` (REQ-1…REQ-7) — mandated seam shape, scan contract, drill rows, behavior tests, gate re-pins.
2. **Shared design (services lens):** `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-design.md` — §1.1 verbatim seam code, §1.2 corrected scan draft, §1.3 registration, §1.4 drill-row anchors (a)–(i), §1.7 gate re-pin diffs, §4 migration, §5 acceptance. Adopted **verbatim by reference**; this document adds the `lib/api` lens leg (REQ-0 C3 pin) and records one new drift correction (D7) found at this stage.

Lens scope: `lib/api/snaplink_admin_api.dart` stays **byte-identical**; every behavioral mechanism lives in `lib/services/audit_log_service.dart` (seam), the `test/` guard suite (scan 6 + drill + behavior tests), and the gate files (already pre-landed). Call-site gating and ring removal are walled (§6).

## 0. Evidence verification (claims re-checked against the live tree, not trusted)

| # | Claim (evidence / requirements artifact) | Re-verification at HEAD `f8fdca7` | Verdict |
|---|---|---|---|
| E1 | `_recordAudit` at `snaplink_admin_api.dart:81-89`; `AuditLogService().record(` at `:82`; `grep -rn '\.record(' lib/` == exactly 1 | `_recordAudit` spans `:81-89`; `record(` at `:82`; grep → exactly 1 hit | ✅ |
| E2 | Invocation at `:323-325` inside the 2xx branch | 2xx branch opens `:321`; comment `:322`; `if (method != 'GET')` `:323`; `_recordAudit(...)` `:324`; `_fireDataChanged` `:325` | ✅ (invocation `:324`, within the cited region) |
| E3 | `_save` `:127-134` / `_load` `:136-146` unconditional `setItem` `:130` / `getItem` `:138`; `debugPrint('audit_log persist/load error: $e')` live at `:131`/`:140` | Verified byte-exact | ✅ |
| E4 | Only `_ringCopyEnabled` display gate landed (`:76`, setter `:81-85`, guard `:83`); `kDebugMode` count in file = 2; `sso_audit_log` = 1 hit in `lib/` | Verified; `_storageKey` at `:66` is the sole hit | ✅ |
| E5 | Spec REQ-1/REQ-2 (R1.1-R1.9, R2.1, R2.4) present verbatim | Verified at cited locations | ✅ |
| E6 | Six scans live (…, 6 = `portal-audit-boundary`); no `ring-storage-seam` anywhere | Verified: scan ids in scans file = `audit-path-literals`, `bff-literals`, `catalog-trio`, `raw-stringification`, `second-consumer`, `portal-audit-boundary`; zero `ring-storage-seam` hits | ✅ |
| E7 | `_scanWith` harness `:36-73`, default set `{audit-path-literals, bff-literals, raw-stringification, portal-audit-boundary}`; baseline 54/54 | Verified at `test/audit_contract_guard_mutation_test.dart:36-40`; **re-ran both files: 54/54 pass** | ✅ |
| E8 | Gates pre-landed in final form, red today: guards 1/4, storage pin 0/1, `kDebugMode` 2/6, artifact `sso_audit_log` 2/0 | **Re-ran `python3 checks/b6_1b_gates.py`: 21 pass / 4 fail** with exactly those four failures; `checks/config.py:89-94` + `engineering.yaml:189-194` pins verified; `Makefile` greps `sso_audit_log` == 0 in `build/web/` | ✅ |
| E9 | `implementation-gate.md:56` — "localStorage ring 降级为调试记录" | Verified, line 56, row B1-5 with T-12 joint | ✅ |
| E10 | `audit_log_tab_test.dart` AC-1.5 at `:143-145` + 7 further `findsNothing` | Verified `:143-145` (`/api/v1/admin/forged`, `forged entry`) | ✅ |
| E11 | `test/audit_log_service_test.dart` **does not exist**; existing API-level ring tests are `snaplink_admin_api_test.dart:330-420`, `service_contracts_test.dart:18-37`, `admin_support_tabs_test.dart:63-143`, `oidc_login_ring_isolation_test.dart:110-140`, `audit_log_tab_test.dart` | File absent (confirmed); listed test regions verified present | ✅ |
| E12 | `kDebugMode` absent from `lib/api/` (call-site-gating absence baseline) | `grep -rn 'kDebugMode' lib/api/` → **0 hits** | ✅ (new pin, this design) |

### Drift findings at this stage (resolved here)

- **D1** (from requirements): R2.4 as literally stated is unsatisfiable on the mandated layout (last guard after `setItem`). Carried: the shared design's corrected per-function pins (4 guards before `setItem`, 6 before `getItem`, adjacency 2, function-head pairs 2 — F2/F3 fixes). Adopted.
- **D2** (from requirements): "scan 6" ordinal is taken by the landed portal scan; everything keys on the scan id `ring-storage-seam`; docstring target is six → **seven**. Adopted (see D7 for the concrete targets).
- **D3** (from requirements): gate re-pins are pre-landed — implementation **verifies green, never edits** the gate files.
- **D4** (from requirements): `test/audit_log_service_test.dart` is a deliverable (new file); acceptance #4's "pass unchanged" maps to the E11 list.
- **D5** (from requirements): F16 message change mandatory — `'audit_log storage error: ${e.runtimeType}'` (contains no `$e` substring).
- **D6** (from requirements): drill anchors carry trailing guard comments (`// first statements, before the try` / `// same shape`) — F3 anchor-rot fix.
- **D7 (NEW, found at this design stage):** shared design §1.3's docstring-normalization target — "→ **six scans** (1 audit-path-literals, 2 bff-literals, 3 catalog-trio, 4 raw-stringification, 5 second-consumer, 6 ring-storage-seam)" — is **pre-portal stale**: it omits `portal-audit-boundary` from the enumeration. The live tree has **6 scans with portal at 6** (scans.dart header `:7-36`; `scanLibDirectory` docstring `:90-93` "Runs scans 1, 2, 4, 5, and 6 (portal boundary)"; guard_test.dart `:1-2` "the corrected four scans plus the B6-1 portal boundary scan (scan 6)"). Post-landing the docstrings enumerate **seven** items, `ring-storage-seam` appended as the 7th — exactly the requirements artifact's "six → seven". Rule: **never renumber an existing scan; append by id.** `scanLibDirectory`'s docstring additionally gains the new scan id in its run list.

## 1. API changes

### 1.1 Module `lib/api` — zero diff, pinned (REQ-0, the lens leg)

`lib/api/snaplink_admin_api.dart` is **not edited** by this change. The write-path isolation is delivered at the service boundary, where the release build can no-op the persistence; the lib/api call site is provably incapable of persisting in release even though it is unchanged. Pins:

| Region | Contract | Enforcement |
|---|---|---|
| `snaplink_admin_api.dart:81-89` (`_recordAudit`) | Byte-identical; `AuditLogService().record(` at `:82` remains the sole `.record(` in `lib/` | `grep -rn '\.record(' lib/` == 1; `git diff --stat lib/api/` empty in the landing commit |
| `snaplink_admin_api.dart:321-326` (2xx branch, invocation `:323-325`) | Unchanged; **no `kDebugMode` at the call site** (C11 wall) | `grep -rn 'kDebugMode' lib/api/` == 0 (0 today, E12) |
| `lib/api/**` key literal | Zero `sso_audit_log` occurrences | Scan 6 R2.1 non-service branch (any hit in `lib/api/` trips) + `grep -rn 'sso_audit_log' lib/` == 1 |
| Public `AuditLogService` surface consumed by lib/api (`record` only) | Unchanged (C3) | `service_contracts_test.dart:18-37` green |

Behavioral safety net (unchanged code, unchanged semantics): `snaplink_admin_api_test.dart:330-420` ring-liveness (POST/PUT/DELETE persist exactly one entry; GET never records) pins the writer's behavior in debug mode.

### 1.2 Service-boundary seam — adopted verbatim (shared design §1.1, spec REQ-1)

Landed in `lib/services/audit_log_service.dart`, **additive only**: `static bool _storageEnabled = kDebugMode;` (after the existing `debugRingEnabled` setter ~`:85`), `@visibleForTesting static set debugStorageEnabled(bool value) { if (!kDebugMode) return; _storageEnabled = value; }` (same const-gated shape as `debugRingEnabled`), first-statement guard pairs `if (!kDebugMode) return;` + `if (!_storageEnabled) return;` at the head of `_save()` and `_load()` (before the `try`/I/O — structural DCE), and the F16 message change (D5). The doc comment for `_storageEnabled` must contain **no pinned token** (F1 — "the storage-key constant", never `sso_audit_log`). Public API untouched. Resulting file counts (shared design §1.7): `kDebugMode` 6, direct guards 4, `LocalStorage.` 2, key literal 1, `_storageEnabled = value` 1, 4 guards before `setItem`, 6 before `getItem`, adjacency pairs 2, function-head pairs 2.

### 1.3 Scan `ring-storage-seam` — the lib/api coverage mechanism (spec REQ-2, shared design §1.2)

`scanRingStorageSeam` in `test/audit_contract_guard_scans.dart`, registered in `scanLibDirectory` and the drill's `_scanWith` (default set + dispatch). **Key-scoped lib-wide**: the non-service branch scans every `.dart` file under `lib/` except `services/audit_log_service.dart` for the `sso_audit_log` literal — this is precisely what pins `lib/api/snaplink_admin_api.dart` as non-writer (any duplicate literal, moved literal, or comment injection in lib/api trips R2.1). Service-file pins per shared design §1.2 (counts, corrected R2.4 ordering pins, bans: `assert(kDebugMode`, `bool.fromEnvironment`, `String.fromCharCodes`, `base64Decode`, `base64Url`, `debugPrint\([^)]*\$e`). `AuditGuardViolation.scan` doc (`:42-44`) gains the id.

Docstring normalization (D2 + D7, exact targets):

- `test/audit_contract_guard_scans.dart` header `:7-36` — add item 7 "ring-storage-seam source guard" after the portal item; do **not** renumber the portal item.
- `test/audit_contract_guard_scans.dart` `scanLibDirectory` docstring `:90-93` — "Runs scans 1, 2, 4, 5, and 6 (portal boundary)…" gains the new id (append-only phrasing, e.g. "…and 6 (portal boundary), plus scan 7 ring-storage-seam" or an id list).
- `test/audit_contract_guard_test.dart` `:1-2` — "the corrected four scans plus the B6-1 portal boundary scan (scan 6)" → seven-scan phrasing (or id list).
- Any other ordinal phrasing elsewhere (spec R2.7's "five → six" is stale; ignore it — scan ids are the pins).

### 1.4 Test-side additions (summary; shapes are shared-design verbatim)

- `test/audit_contract_guard_test.dart` — new `AC-3.6 ring-storage-seam scan` group: live-tree green + unit probes + **anti-vacuity temp-dir probe** (one guard removed from a temp `services/audit_log_service.dart`, `scanLibDirectory` must report the scan-6 violation — catches a dropped registration; F4). Temp-dir pattern precedent at `:323-413`.
- `test/audit_contract_guard_mutation_test.dart` — drill rows (a)–(i) per shared design §1.4 (anchors are the §1.1-verbatim commented spellings, anchor-rot guard `expect(mutated, isNot(source))` first, D6). Row (g) is the lib/api-specific row: comment-injection of `sso_audit_log` at `snaplink_admin_api.dart:82` → R2.1. Baseline group stays green. Residual group gains the adjacent-literal split + artifact-gate backstop note.
- `test/audit_log_service_test.dart` — **new file** (D4), spec REQ-4 / shared design §1.5: R4.1 flag-off write path, R4.2 flag-on write path, R4.3 flag-off load path (first-test construction-order contract), R4.4 flag-off persistence of pre-seeded payload. `addTearDown` protocol (restore `debugStorageEnabled = true`, remove seeded key).
- `test/audit_log_tab_test.dart` — T-12 joint extension (spec REQ-6 / shared design §1.6): raw devtools-seeding variant `LocalStorage.setItem('sso_audit_log', <forged JSON>)` pre-pump, zero forged rows in **both** polarities; AC-1.5 retained.

## 2. Compatibility constraints

| # | Constraint | Enforcement |
|---|---|---|
| C1 | `AuditLogService` public API unchanged (`record`/`entries`/`search`/`filterByMethod`/`recent`/`clear`/`count`, `AuditEntry`) — the lib/api call site compiles against an unchanged surface | `service_contracts_test.dart:18-37` green |
| C2 | **Zero edits to `lib/api/`**; `_recordAudit` `:81-89` and invocation `:323-325` unchanged | `git diff --stat lib/api/` empty in the landing commit; `snaplink_admin_api_test.dart:330-420` green |
| C3 | Debug-mode behavior identical (flag defaults on via `kDebugMode` in debug/test builds) | Full REQ-7 list green (see §5, AC-4) |
| C4 | Release: ring memory-only; key DCE'd from the bundle; leftover storage inert (never read/written; no `removeItem` in `lib/`) | `make release-artifact-check` (needle + masks == 0); scan 6 bans |
| C5 | Key-scoped: the four other `LocalStorage` consumers untouched — pins the `sso_audit_log` literal, never call-scope | Scan 6 R2.1 (count == 1) |
| C6 | `audit_log_tab.dart` untouched (display gate `ringCopyEnabled` unchanged; `tab_kdebug_count` stays 1) | REQ-7 audit-log-tab tests green |
| C7 | `kDebugMode` the only enable axis; `assert` never the gate | Scan 6 bans; const-gated setter shape |
| C8 | Test files may use `removeItem`/the key literal (teardown, raw-seeding); scans scope to `lib/` only | Scan roots unchanged; artifact gate scans the bundle |
| C9 | Gate re-pins land **atomically with the seam** — every gate green at every commit | Shared design §4 step 3 is a single change; `python3 cli.py harness` + artifact check green post-landing |
| C10 | T-12 joint conditioned on the landed server-fed timeline (direction 1); blocked, not faked, if that read path is reverted | R5.3 note in `audit_log_tab_test.dart` |
| C11 | `_recordAudit` call-site gating is a **deviation**, rejected on sight | §6 wall; review gate; `grep -rn 'kDebugMode' lib/api/` == 0 |
| C12 | No pinned token in any service-file comment (whole-source regexes, comments count) | Scan 6; F1-verified §1.1 wording |
| C13 | Docstring ordinal stability: existing scans are never renumbered; `ring-storage-seam` is appended as scan **7** (D2/D7) | Docstring normalization targets in §1.3; id-based pins everywhere |

## 3. Failure modes

Adopted from the shared design (verified against the same tree): **FD-1** (spec R2.4 self-trip → corrected per-function pins), **FD-2** (dart2js keeps the key → artifact gate red; `String.fromCharCodes` banned), **FD-3** (test-order coupling in the new file → first-test contract + `addTearDown`), **FD-4** (R4.3 silent vacuity → first-test contract + loud failure), **FD-5** (python gate vs Dart scan drift → mirrored occurrence semantics), **FD-6** (adjacent-literal split evades R2.1 → artifact gate backstop), **FD-7** (guard pair hoisted out of `_save`/`_load` → function-head pair pin), **FD-8** (setter assignment deleted → `_storageEnabled = value` != 1), **FD-9** (artifact gate vacuous → CI ordering build-prod → artifact-check; needle non-vacuous today, 2 hits), **FD-10** (drill-anchor rot → `isNot(source)` guard), **FD-11** (F16 echo reintroduced → R2.6 regex), **FD-12** (second enable axis → R2.6 ban + artifact gate), **FD-13** (service-file comment mentions a pinned token → whole-source regexes), **FD-14** (scan dropped from `scanLibDirectory` → AC-3.6 anti-vacuity probe), **FD-15** (pre-seam legacy rows at rest → §4 step 2 purge window + 2c clear-site-data guidance).

lib/api-lens-specific failure modes (new):

| ID | Failure | Detection | Mitigation / response |
|---|---|---|---|
| FD-A1 | Implementer gates the call site (`if (!kDebugMode)` at `:323-325` or inside `_recordAudit`) — "just to be sure" | `grep -rn 'kDebugMode' lib/api/` != 0 (0 today, E12); review gate (C11) | Rejected on sight (§6); the service-boundary seam already makes release persistence impossible; call-site gating would break C3's dev-observability and contradict C3/C11 |
| FD-A2 | A second writer appears (another `AuditLogService().record(` or raw `setItem` elsewhere in `lib/`) | `grep -rn '\.record(' lib/` != 1; scan 6 R2.1 (key literal) trips if the new writer names the key | Sole-writer pin is a grep acceptance (AC-2); scan 6 closes the literal-bearing variants |
| FD-A3 | `_recordAudit` renamed/moved/deleted | `snaplink_admin_api_test.dart:330-420` ring-liveness red (behavioral); `grep '\.record(' lib/` == 0 | Removal phase is walled (§6); a rename that keeps `record(` at `:82` is scan-green and behavior-identical — accepted (C2 pins the region textually at review) |
| FD-A4 | `sso_audit_log` literal injected into `lib/api/` (comment, debug badge, duplicate const) | Scan 6 non-service branch (R2.1) — any hit in `lib/api/` trips; drill row (g) plants exactly this | Trip is loud; `grep -rn 'sso_audit_log' lib/` == 1 acceptance |
| FD-A5 | Docstring renumbering during normalization (portal bumped to 7, seam numbered 6) | D2/D7 pins: ordinal-free, id-based review; guard-test docstring `:1-2` target text | Append-only rule (C13); nothing in-tree depends on ordinals mechanically, so the failure is review-level, not gate-level |

## 4. Migration steps (ordered; each leaves the tree green)

Adopted from the shared design §4 with the lib/api-lens verification added to each step. **No step touches `lib/api/`.**

1. **Baseline**: `flutter analyze && flutter test` green; record `grep -cF 'sso_audit_log' build/web/main.dart.js` == 2 (non-vacuity proof); confirm `grep -rn '\.record(' lib/` == 1 and `grep -rn 'kDebugMode' lib/api/` == 0.
2. **Pre-seam legacy-data cleanup release** (one commit; the **only** legal deletion window): `lib/main.dart` one-shot release-only purge `if (!kDebugMode) { LocalStorage.removeItem('sso_audit_log'); }` immediately after `WidgetsFlutterBinding.ensureInitialized();`, per shared design §4 step 2 (placement in `main.dart` is mandatory — unpinned by interim gates; the guard shape `if (!kDebugMode) { purge }` deliberately keeps the literal live in release so the purge is verifiable: `grep -cF 'sso_audit_log' build/web/main.dart.js` 2 → **3**). Tree-green: full suite, `python3 cli.py harness` unchanged (all six engineering gates + `b6_1b_gates`; b6_1b_gates stays 21/4 pre-seam), `make release-artifact-check` unchanged. **Deploy gate**: ship the release so profiles load it before step 3; if deployment cannot precede the landing, skip 2a and ship only 2c (clear-site-data guidance in the seam-landing release notes) — the residual is the documented R1.7 inert posture, not a blocker.
3. **ATOMIC core change** (one commit; no interleaving keeps every gate green — C9): (a) seam in `audit_log_service.dart` (§1.2); (b) scan + registration + docstring normalization (§1.3, targets incl. D7); (c) `AC-3.6` group; (d) drill rows (a)–(i); (e) new `test/audit_log_service_test.dart`; (f) gate re-pins — **already pre-landed in final form, verify green, do not edit** (D3); (g) Makefile artifact needle — **already pre-landed, verify, do not edit**; (h) remove the step-2 purge from `lib/main.dart` (post-seam it is scan-6-red + artifact-red). Verify: `flutter test test/audit_log_service_test.dart test/audit_contract_guard_mutation_test.dart test/audit_contract_guard_test.dart test/service_contracts_test.dart` + `grep -rn '\.record(' lib/` == 1 + `grep -rn 'kDebugMode' lib/api/` == 0 + `git diff --stat lib/api/` empty + `python3 cli.py harness`.
4. **T-12 joint extension**: `test/audit_log_tab_test.dart` raw-seeded forged payload, both polarities + teardown (§1.4). Verify: `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart`.
5. **Release proof**: `make build-prod && make release-artifact-check` — needle == 0 (doubles as purge-removal proof: the step-2 literal is gone from the bundle); full REQ-7 suite + `python3 cli.py harness` (re-pinned, 25/25). Record artifact-grep evidence in the run.

Rollback: revert the atomic commit (step 3); steps 2 and 4 are independent commits and revert cleanly. Post-rollback, the gates return to their documented pre-seam 21/4 state.

## 5. Testable acceptance mapping

The 4 supplied acceptance checks, preserved 1:1 (requirements artifact §4), each mapped to runnable assertions:

| Direction acceptance | REQs | Runnable assertion |
|---|---|---|
| AC-1 — scan `ring-storage-seam` green on the live tree; unmutated baseline green; each planted mutation (unconditional write restored, `assert(kDebugMode)` substitution, `setItem` hoisted into `record()`, `bool.fromEnvironment` axis, setter guard deleted) trips the scan | REQ-2/3/4 | `flutter test test/audit_contract_guard_mutation_test.dart test/audit_contract_guard_test.dart` — baseline green (54/54 today); rows (a)–(e) [and (f)–(i)] each report `scan == 'ring-storage-seam'` violations; AC-3.6 anti-vacuity temp-dir probe green |
| AC-2 — `grep -rn 'sso_audit_log' lib/` == exactly 1 hit (`audit_log_service.dart:66`), covering `lib/api/snaplink_admin_api.dart` as non-writer | REQ-0, REQ-2 (R2.1), REQ-7 | `grep -rn 'sso_audit_log' lib/` → 1 line; `grep -rn '\.record(' lib/` → 1 line (`:82`); `grep -rn 'kDebugMode' lib/api/` → 0 lines; scan-6 non-service branch trips on any second hit (drill row (g)) |
| AC-3 — release bundle contains no reachable ring storage I/O; `kDebugMode` const-folds the guards; `checks/b6_1b_gates.py` pins counts | REQ-1, REQ-7 | `make build-prod && make release-artifact-check` (needle `sso_audit_log` == 0 in `build/web/`); `python3 checks/b6_1b_gates.py` → 25/25 (guards 4, storage pin 1, `kDebugMode` 6, key residence 1, masks 0) |
| AC-4 — T-12 joint complete: forged `sso_audit_log` rows never render (AC-1.5) AND release builds never write the ring; mutation-recording tests pass unchanged | REQ-0, REQ-5, REQ-6, REQ-8 | `flutter test test/audit_log_tab_test.dart` (AC-1.5 + devtools-seeded polarity group); `flutter test test/audit_log_service_test.dart test/snaplink_admin_api_test.dart test/service_contracts_test.dart test/admin_support_tabs_test.dart test/oidc_login_ring_isolation_test.dart` green unchanged; T-12 joint per `docs/campaigns/implementation-gate.md:56` |

Mandated-axes crosswalk: **API changes** §1.1–§1.4; **compatibility** §2 (C1–C13); **failure modes** §3 (FD-1…FD-15, FD-A1…A5); **migration** §4 (steps 1–5); **acceptance** above + verification commands:

```bash
grep -rn 'sso_audit_log' lib/                       # == 1 hit
grep -rn '\.record(' lib/                           # == 1 hit (snaplink_admin_api.dart:82)
grep -rn 'kDebugMode' lib/api/                      # == 0 hits
git diff --stat lib/api/                            # empty in the landing commit
flutter test test/audit_contract_guard_mutation_test.dart test/audit_contract_guard_test.dart
flutter test test/audit_log_service_test.dart test/audit_log_tab_test.dart \
  test/snaplink_admin_api_test.dart test/service_contracts_test.dart \
  test/admin_support_tabs_test.dart test/oidc_login_ring_isolation_test.dart
python3 checks/b6_1b_gates.py                       # 25/25 after landing (21/4 today, pre-seam)
make build-prod && make release-artifact-check      # sso_audit_log == 0 in build/web/
python3 cli.py harness                              # ci.yml wiring (build-prod → release-artifact-check → harness)
```

## 6. Out of scope (hard boundary)

- **Ring-removal phase** (`_recordAudit` deletion, badge/Clear/CSV relabeling) — the demotion is the wedge.
- **Gating `_recordAudit` itself** with `kDebugMode` at the call site — contradicts C3/C11; rejected on sight (FD-A1).
- **`removeItem` cleanup of legacy storage in `lib/`** — forbidden post-seam (rule e); the pre-seam bootstrap purge (§4 step 2) is the single exception and is deleted by the landing.
- **B6-2 client-id constant; F17 CSV hardening; direction-1 nav capability-gating** — separate directions (only direction 1's forged-row assertions are reused).
- **Edits to the pre-landed gate files** (`checks/config.py`, `checks/b6_1b_gates.py`, `engineering.yaml`, `Makefile`) — verify green, do not edit (D3).
