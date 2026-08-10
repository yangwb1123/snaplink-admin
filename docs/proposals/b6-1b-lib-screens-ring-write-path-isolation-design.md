# B6-1b — Design: ring write-path isolation — recording debug-only; release no longer persists `sso_audit_log` (module `lib/screens` lens)

> Direction: *"Land B6-1b ring write-path isolation — recording itself must be debug-only; release builds still persist 'sso_audit_log'"* (`docs/auto/analyses/lib-screens-19d4d0ab.json`, direction 1; value 9 / risk 8 / effort 4 / confidence 9).
> Requirements: `docs/proposals/b6-1b-lib-screens-ring-write-path-isolation-spec.md` (REQ-0…REQ-6).
> Mechanics adopted **verbatim by reference** (never restated here): `b6-1b-lib-services-audit-ring-storage-seam-spec.md` (REQ-1…REQ-7), `b6-1b-lib-services-audit-ring-storage-seam-design.md` (§1.1 seam code, §1.2 scan 6, §1.3 registration, §1.4 drill rows (a)–(i), §1.5 behavior tests, §1.6 tab joint, §1.7 gate diffs, §4 migration), `b6-1b-lib-api-ring-write-path-isolation-design.md` (lib/api lens, drift corrections D1–D7, §4 steps 1–5).
>
> **Revision 1, 2026-08-08.** Every citation in the screens spec was re-verified live at this design stage against the working tree (HEAD `e1073ce` + uncommitted B6-1/B6-2 change set). The design is the **lib/screens lens** of the direction: the screens layer contributes zero production diff; its obligations are the T-12 joint extension (REQ-3), the release-bundle proof (REQ-4), and the no-regression surface (REQ-6), all test-side.

## 0. Evidence verification (re-checked live at this design stage, not trusted)

| # | Claim (screens spec / evidence) | Verified repository reality | Verdict |
|---|---|---|---|
| E1 | `audit_log_service.dart:76,83,127-146` — display gate landed; `_save`/`_load` unconditional | `_ringCopyEnabled = kDebugMode` `:76`; getter `:79`; `@visibleForTesting set debugRingEnabled` `:81-85`, guard `if (!kDebugMode) return;` `:83`; `_save()` `:127-134` → `LocalStorage.setItem(_storageKey, jsonStr)` `:130` **unguarded**; `_load()` `:136-146` → `LocalStorage.getItem` `:138` **unguarded**; `_storageKey = 'sso_audit_log'` `:66` sole hit in `lib/`; `record()` `:89-95` → `_save()` `:94`; `clear()` `:120-124` → `_save()` `:122`; ctor `:60-62` → `_load()` `:61`. `kDebugMode` in file == 2 | ✅ |
| E2 | `snaplink_admin_api.dart:82,324` — sole `.record(` caller | `_recordAudit` `:81-89`, `AuditLogService().record(` `:82`; 2xx branch `:321-326`, `if (method != 'GET')` `:323`, invocation `:324`, `_fireDataChanged` `:325`. `grep -rn '\.record(' lib/` == exactly 1; `grep -rn 'kDebugMode' lib/api/` == 0 | ✅ |
| E3 | `audit_log_tab.dart:298` — debug-only ring surface landed | Gate `if (kDebugMode && AuditLogService.ringCopyEnabled)` at **`:298`** (see D-S2 — the spec's `:293` is stale by 5); StatusChip `'Debug records'` + `'Debug records: {n} entries'` + Clear button `:298-321`. `kDebugMode` in the tab == 1 (harness `tab_kdebug_count`; `grep -rn 'kDebugMode' lib/screens/` == 1, tab only). Working-tree diff of the tab is **only** the B6-2 i18n change set: `_formatTime` `:487-499` localizes `'just now'`/`'{count}m ago'`/`'{count}h ago'` (9 insertions / 3 deletions) — no B6-1b content | ✅ |
| E4 | Gate state 21/4 | `python3 checks/b6_1b_gates.py` re-run: **21 passed / 4 failed, exit 1** — exactly the four cited: guard `if (!kDebugMode) return;` 1≠4, storage pin `_storageEnabled = kDebugMode` 0≠1, `kDebugMode` in service 2≠6, artifact `sso_audit_log` 2 in `build/web/`. All other needles (old en/zh keys, masks, escaped-zh) 0 | ✅ |
| E5 | Gate pins pre-landed in final form | `checks/config.py:89-94` (`service_kdebug_count = 6` "post-seam (interim was 2)", `tab_kdebug_count = 1`, `initializer_pin`, `storage_initializer_pin`, `guard_line`, `guard_line_count = 4`, `banned_service_tokens` incl. base64 family); `engineering.yaml:189-194` mirror; `Makefile:36-44` `release-artifact-check` fail-closed (`test -d build/web` + `grep -rI -oF` == 0 for `sso_audit_log` + both base64 masks + escaped-zh) | ✅ |
| E6 | Api design doc untracked | `git status` → `?? docs/proposals/b6-1b-lib-api-ring-write-path-isolation-design.md` | ✅ |
| E7 | `ring-storage-seam` absent; scans 1…6b + trio pin | `grep -rn 'ring-storage-seam' test/ checks/` == 0. Scans live: `audit-path-literals`, `bff-literals`, `catalog-trio`, `raw-stringification`, `second-consumer`, `portal-audit-boundary` (portal at 6), `developer-audit-boundary` (6b) + runtime trio pin | ✅ |
| E8 | Acceptance-file baseline | Spec's trio `flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart` → **84/84 green**. Secondary trio (`audit_log_tab` + `snaplink_admin_api` + `admin_support_tabs`) → 45/45 green. No conflict — the two trios overlap in `audit_log_tab_test.dart` | ✅ |
| E9 | `[CORRECTION]` anchors | AC-1.5 forged-row negatives at `audit_log_tab_test.dart:159-160` (comment `:158`; `:143-149` holds AC-1.4 decoy-count `'999'` findsNothing); further negatives `:322-323, :354-358, :385-386, :455-456`; `_seedForgedRing()` `:104-117`. T-12 comment at `admin_support_tabs_test.dart:67`, assertions `:126-127` (`'forged entry'` findsNothing; also `:145`). Ring-liveness group opens `snaplink_admin_api_test.dart:327`. `config.py` pins at `:89-94` | ✅ |
| E10 | `cli.py` harness wiring | `cmd_harness` `:136-144` runs `b6_1b_gates` last among six engineering gates; CI sequence build-prod → release-artifact-check → harness (`ci.yml:38,41,44`) | ✅ |

**New drift findings at this design stage:**

- **D-S1 (anchor drift — seam design §1.6 says "B6-1b copy-surface group `:414+`")**: the live B6-1b group in `test/audit_log_tab_test.dart` opens at **`:690`** (`group('B6-1b debug ring copy surface (AC-1 / AC-2 / AC-3)')`); the file grew with the B6-2 i18n change set since the seam design's HEAD. Same anchor-drift class as E9 — the acceptance mapping below pins by **group name and assertion text**, never line numbers, and the R3.2 variant appends inside the group at its end (see §1.3), not at a line.
- **D-S2 (anchor correction — display gate is `:298`, not `:293`)**: `grep -n 'kDebugMode' lib/screens/admin/audit_log_tab.dart` at HEAD `e1073ce` (and in the working tree) resolves the gate to **`:298`**; `:293` is the `'Export CSV'.localized` tooltip line. The `:293` citation appears in the screens spec (header, REQ-1, R1.2, E4), the seam spec, and the api design — all stale by 5 lines. The claim's own line reference (`audit_log_tab.dart:298` for the surface) is correct; its parenthetical gate line is not. No gate or scan pins line numbers (`tab_kdebug_count` pins the count only), so no automation is affected; this design cites `:298` and records the correction.

## 1. API changes

### 1.1 `lib/screens/` — zero production diff, pinned (REQ-1)

No `lib/screens/` file is edited by this direction.

| Region | Contract | Enforcement |
|---|---|---|
| `lib/screens/admin/audit_log_tab.dart:298-321` (ring copy surface) | Byte-identical to HEAD; the seam changes nothing the tab reads (`ringCopyEnabled` getter, `count`/`ringCount`, `clear` — all untouched, seam C3) | `git diff lib/screens/` in the landing commit shows **only** the pre-existing B6-2 `_formatTime` i18n change set (E3); REQ-7 tab tests green |
| `kDebugMode` count in the tab | Stays exactly 1 (`tab_kdebug_count` pin — the `:298` display gate, D-S2) | `python3 checks/b6_1b_gates.py` (pinned 1) |
| `_storageEnabled` / `debugStorageEnabled` | **No screens file may reference them** (seam flag is `@visibleForTesting`, exercised by `test/audit_log_service_test.dart` and the T-12 polarity tests only — R1.3) | Review gate + `grep -rn 'debugStorageEnabled\|_storageEnabled' lib/screens/` == 0 in the landing commit |
| i18n keys consumed by the tab (`'Debug records'`, `'Debug records: {n} entries'`, `'Clear local debug records'`, `'Clear local debug records?'`, `'This will permanently delete all {n} local debug records.'`) | Unchanged; residence in `lib/i18n/app_strings_source_admin_core.dart` pinned; old en/zh needles zero hits | `b6_1b_gates.py` key-residence checks (already 21/21-green subset) |
| `lib/api/snaplink_admin_api.dart` | Byte-identical (`_recordAudit` `:81-89`, invocation `:324`); `kDebugMode` in `lib/api/` == 0 | Adopted by reference (api design §1.1, C2/C11); `grep -rn '\.record(' lib/` == 1 |

### 1.2 Mechanics adopted verbatim by reference (no restatement)

- **Storage seam** (`lib/services/audit_log_service.dart`): `_storageEnabled = kDebugMode` initializer, const-gated `debugStorageEnabled` setter, first-statement guard pairs in `_save()`/`_load()` (before the `try`), F16 constant-message `debugPrint` — seam design §1.1 verbatim, b6-1a §1.2a shape, rules (a)–(e).
- **Scan 7 `ring-storage-seam`** (`test/audit_contract_guard_scans.dart`): key-scoped pins + corrected per-function ordering (D1) + function-head pair pin (F2) + bans — seam design §1.2 verbatim; registered in `scanLibDirectory` and `_scanWith`, docstrings normalized to **seven** items by id, never renumbered (D2/D7/C13).
- **Drill rows (a)–(i)**, **behavior tests** (`test/audit_log_service_test.dart`, construction-order contract), **gate verification** (verify green, never edit — D3) — seam design §1.4/§1.5/§1.7 + api design D4–D6.

The screens lens adds only §1.3 (test-side joint) and the verification obligations of §2–§5.

### 1.3 Test-side additions (the screens lens's API surface)

1. **T-12 joint extension — raw-devtools seeding variant (REQ-3 R3.2)**, appended at the **end** of the existing `B6-1b debug ring copy surface (AC-1 / AC-2 / AC-3)` group (`audit_log_tab_test.dart:690`), never at a pinned line:
   - Seed **before** the page pump: `LocalStorage.setItem('sso_audit_log', jsonEncode([<forged row: path '/api/v1/admin/forged', label 'forged entry'>]))` — a devtools-forged payload, **not** `AuditLogService().record` (the existing `_seedForgedRing` `:104-117` stays for AC-1.5; the new variant is a separate helper `_seedForgedRingRaw()`).
   - Assert in **both polarities**: on (default — nothing to set); off (`AuditLogService.debugStorageEnabled = false;`).
   - Assertions: `find.textContaining('/api/v1/admin/forged')` findsNothing and `find.textContaining('forged entry')` findsNothing (display truth comes exclusively from `AuditReadClient` `/api/v1/audit/events` — F7); off-polarity additionally asserts the raw payload is **byte-identical** after the test (the tab never writes the ring).
   - Teardown protocol (unconditional `addTearDown`): `LocalStorage.removeItem('sso_audit_log')` + `AuditLogService.debugStorageEnabled = true` (restores the file default for the remaining tests in the same isolate — FD-S3).
   - Positive control: the server-row assertions from the group's parent test (`admin_client_created` etc. render) prove the test is live, not vacuously green (FD-S2).
   - Dependency note (R5.3): the joint is conditioned on the landed server-fed timeline (direction 1); if that read path is reverted the check is **blocked**, never silently green.
2. **Scan registration + docstring normalization** (REQ-2) — api design §1.3 targets verbatim: `scans.dart` header `:7-36` gains item 7; `AuditGuardViolation.scan` doc `:42-44`; `scanLibDirectory` docstring `:94-97`; `guard_test.dart` header `:1-2` → seven-scan phrasing.
3. **`AC-3.6` group** with the anti-vacuity temp-dir probe (dropped-registration detection, F4) and **drill rows (a)–(i)** (row (g) plants the `sso_audit_log` comment-injection into `lib/api/snaplink_admin_api.dart` — the lib/api non-writer pin from the screens lens's AC-2).
4. **`test/audit_log_service_test.dart`** — new behavior file (seam design §1.5), first-test construction-order contract; the off-polarity load/write pins are the persistence half of the T-12 joint (REQ-3 R3.4).

## 2. Compatibility constraints

| # | Constraint | Enforcement |
|---|---|---|
| C-S1 | **Zero production diff in `lib/screens/`** attributable to this direction; the tab's working-tree diff stays exactly the pre-existing B6-2 i18n change set (E3) | `git diff --stat lib/screens/` reviewed at landing; REQ-7 tab tests green |
| C-S2 | `kDebugMode` in the tab == 1 (the `:298` display gate, D-S2); no new `kDebugMode` anywhere in `lib/screens/` (the joint tests toggle `debugStorageEnabled`, never production code) | `b6_1b_gates.py` `tab_kdebug_count` pin; `grep -rn 'kDebugMode' lib/screens/` == 1; review gate |
| C-S3 | Screens never reference `_storageEnabled`/`debugStorageEnabled` (R1.3) | `grep -rn 'debugStorageEnabled\|_storageEnabled' lib/screens/` == 0 |
| C-S4 | Debug-mode behavior byte-identical (flag defaults on via `kDebugMode` in test/debug builds): ring badge, count, Clear action, CSV — all unchanged | Full REQ-6 no-regression list green |
| C-S5 | Release: ring memory-only; key DCE'd from the bundle; legacy leftover storage provably inert (never read, never written, no `removeItem` in `lib/` post-seam) | `make release-artifact-check` (needle + masks == 0 in `build/web/`); scan 7 `LocalStorage.` == 2 / keyHits == 1 |
| C-S6 | T-12 joint conditioned on the landed server-fed timeline (direction 1); blocked, not faked, if reverted | R5.3 note in the variant's test comment |
| C-S7 | Test files may use `removeItem`/the key literal (teardown hygiene, raw seeding); scans scope to `lib/` only; the artifact gate scans the bundle, never `test/` | Scan roots unchanged (C8 of the api design) |
| C-S8 | Gate files (`checks/config.py`, `checks/b6_1b_gates.py`, `engineering.yaml`, `Makefile`) verify green, **never edit** (REQ-5/D3) | `git diff --stat checks/ engineering.yaml Makefile` empty in the landing commit |
| C-S9 | Scan 7 appended **by id**, existing scans never renumbered (D2/D7/C13) | Docstring normalization targets (§1.3); id-based pins everywhere |
| C-S10 | Acceptance keyed to **assertions, not stale line anchors** (E9 corrections; D-S1) | Each mapped test pinned by group name + assertion text; corrections recorded in §0 |
| C-S11 | Polarity isolation within `audit_log_tab_test.dart`: the off-polarity test restores `debugStorageEnabled = true` and removes the seeded key via unconditional `addTearDown` — later tests in the same isolate must not observe the flipped flag or the forged payload | Teardown protocol (§1.3); the variant sits last in the group |
| C-S12 | No pinned token (`sso_audit_log`, `LocalStorage.`, extra `kDebugMode`) in any new comment text under `test/` that is scanned — scan roots are `lib/` only, but the service-file comment ban (C12) still applies to the seam's doc comments | Seam §1.1 wording verbatim (F1-verified) |

## 3. Failure modes

Adopted unchanged from the shared designs (verified against the same tree): FD-1…FD-15 (seam design §3) and FD-A1…FD-A5 (api design §3) — including FD-A1 (call-site gating rejected on sight; `kDebugMode` in `lib/api/` == 0) and FD-A4 (literal injected into `lib/api/` — the screens lens's AC-2 trips). Screens-lens-specific:

| ID | Failure | Detection | Mitigation / response |
|---|---|---|---|
| FD-S1 | An implementer "helps" the tab (adds a belt-and-suspenders `kDebugMode` guard to `_clearRing`, relabels the badge, gates `ringCount`) | `tab_kdebug_count` gate red; `git diff lib/screens/` ≠ B6-2 change set; i18n key-residence checks red on relabel | Zero-diff pin (C-S1/C-S2); rejected at review — the seam is the single mechanism |
| FD-S2 | R3.2 variant goes vacuously green (forged payload seeded but the assertion passes because the whole test is inert — e.g., the timeline fetch failed and *nothing* renders) | No positive control in the test | Server-row render assertions (positive control) in the same test; the negative assertions alone are insufficient |
| FD-S3 | Polarity leak: `debugStorageEnabled = false` not restored → subsequent tests in `audit_log_tab_test.dart` run with storage off → the copy-surface group fails or, worse, passes vacuously | Order-dependent failures; B6-1b group tests at `:716+` depend on the default-on flag | Unconditional `addTearDown` restore (C-S11); variant appended at group end |
| FD-S4 | Raw-seeded payload silently consumed/echoed: in the off polarity `_load` must not read it and nothing may write it | Byte-identical assertion after the test: `LocalStorage.getItem('sso_audit_log')` equals the seeded JSON exactly; the key is still present (never `removeItem`'d by the app) | R3.4/R4.3 pins in `test/audit_log_service_test.dart` own the load/write gates; the joint variant asserts the display half |
| FD-S5 | Anchor drift makes the acceptance mapping stale (the E9 corrections + D-S1 class recurring as tests grow) | Review: mapped anchors re-checked at landing | Acceptance keyed to group names/assertion text (C-S10); `[CORRECTION]`/`[DRIFT]` recorded in §0 |
| FD-S6 | T-12 joint silently unblocks if the server-fed timeline is reverted (direction 1) | R5.3 dependency note; the variant's `AuditReadClient`-fed assertions fail loudly on a ring-fed timeline | Blocked-not-faked posture (C-S6) |
| FD-S7 | Release-bundle proof goes vacuous (bundle not rebuilt; artifact gate skips) | `b6_1b_gates.py` fails closed on a missing `build/web`; Makefile opens with `test -d build/web`; CI ordering build-prod → artifact-check → harness | FD-9 adopted; non-vacuity proven today (2 hits in `build/web/main.dart.js`) |
| FD-S8 | Drill row (g) anchor rot (`snaplink_admin_api.dart` evolves) | `expect(mutated, isNot(source))` anchor-rot guard (FD-10) | Anchor-rot guard on every row; row (g) is the lib/api non-writer pin from the screens lens's AC-2 |
| FD-S9 | A second `kDebugMode` sneaks into the tab or any screens file (someone mirrors the display gate "for consistency") | `tab_kdebug_count` == 1 pin; `grep -rn 'kDebugMode' lib/screens/` == 1 review | C-S2; the display gate at `:298` (D-S2) is the *only* screens-side flag |

## 4. Migration steps (ordered; each leaves the tree green)

Adopted from api design §4 (steps 1–5) — the screens lens's obligations are the verification added to each step. **No step touches `lib/screens/`.**

1. **Baseline** (screens lens): `flutter analyze && flutter test` green; `python3 checks/b6_1b_gates.py` → 21/4 (recorded); `grep -rn '\.record(' lib/` == 1; `grep -rn 'kDebugMode' lib/api/` == 0; `grep -cF 'sso_audit_log' build/web/main.dart.js` == 2 (artifact non-vacuity); `git diff lib/screens/` == B6-2 i18n change set only.
2. **Pre-seam legacy-data cleanup release** (api design §4 step 2; optional, deploy-gated): one-shot release-only `LocalStorage.removeItem('sso_audit_log')` in `lib/main.dart` (the sole legal deletion window; post-seam it is scan-7-red + artifact-red), artifact count 2 → 3 (purge ships), then removal inside step 3; if deployment cannot precede the landing, ship only the clear-site-data guidance (2c). Screens unaffected — verify the tab diff is still the B6-2 change set.
3. **ATOMIC core change** (one commit; C-S8/C9 — no interleaving keeps every gate green): (a) seam in `audit_log_service.dart`; (b) scan 7 + registration + docstring normalization (incl. D-S1: reference the group by name, not `:414+`); (c) `AC-3.6` group (anti-vacuity temp-dir probe); (d) drill rows (a)–(i); (e) `test/audit_log_service_test.dart`; (f)–(g) gate pins + Makefile needle — **pre-landed, verify green, do not edit**; (h) remove the step-2 purge. **Screens verification inside the commit**: `git diff --stat lib/screens/` == 0 additions beyond the B6-2 change set; `grep -rn 'kDebugMode' lib/screens/` == 1; `grep -rn 'debugStorageEnabled\|_storageEnabled' lib/screens/` == 0; `python3 checks/b6_1b_gates.py` → 25/25.
4. **T-12 joint extension** (REQ-3): raw-devtools seeding variant appended to the end of the B6-1b group in `test/audit_log_tab_test.dart` (both polarities + teardown + positive control). Verify: `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart` — the whole B6-1b group (`:690` onward) and the T-12 ring-clear-inert test (`:63-143`, assertions `:126-127`) stay green.
5. **Release proof** (REQ-4): `make build-prod && make release-artifact-check` — `sso_audit_log` + base64 masks == 0 in `build/web/`; full no-regression suite (REQ-6 list: tab tests, `admin_support_tabs_test.dart`, `snaplink_admin_api_test.dart` ring-liveness `:327-420`, `service_contracts_test.dart` `AuditLogService` group `:18-33`, `oidc_login_ring_isolation_test.dart` `:104-136`); `python3 cli.py harness` green (b6_1b_gates 25/25). Record the artifact-grep evidence.

Rollback: revert step 3 (atomic); steps 2 and 4 revert independently. Post-rollback the gates return to the documented 21/4 state.

## 5. Testable acceptance mapping

The five supplied acceptance checks (screens spec §3), preserved 1:1, each mapped to runnable assertions keyed to the **corrected** anchors (E9):

| Acceptance | REQs | Runnable assertion |
|---|---|---|
| AC-1 — `python3 checks/b6_1b_gates.py` → **25/25** (storage pin 1/1, kDebugMode 6/6, artifact 0/0, guard 4/4, key residence 1/1, masks 0/0) | REQ-4, REQ-5 | `python3 checks/b6_1b_gates.py` exits 0, all 25 `[+]` (today: 21 pass / 4 fail — the four are precisely the unlanded seam). `git diff --stat checks/ engineering.yaml Makefile` empty (pins pre-landed, verify-only). Non-vacuity: the `sso_audit_log` artifact needle is live today (2 hits) |
| AC-2 — `grep -rn 'sso_audit_log' lib/` == **1** (service only) **and** `grep -rn 'kDebugMode' lib/api/` == **0** (write path gated at the service seam, call site untouched) | REQ-1, REQ-2 (R2.1), REQ-6 | `grep -rn 'sso_audit_log' lib/` → 1 line (`audit_log_service.dart:66`); `grep -rn 'kDebugMode' lib/api/` → 0; `grep -rn '\.record(' lib/` → 1 (`snaplink_admin_api.dart:82`); `git diff --stat lib/api/ lib/screens/` → lib/api empty, lib/screens only the B6-2 i18n change set; scan 7 non-service branch trips on any second literal (drill row (g)) |
| AC-3 — scan id `ring-storage-seam` present in `test/audit_contract_guard_scans.dart` **and green** | REQ-2 | `grep -n "scanId: 'ring-storage-seam'" test/audit_contract_guard_scans.dart` == 1; registered in `scanLibDirectory` + `_scanWith` default set; `AC-3.6` group green incl. the anti-vacuity temp-dir probe (dropped registration trips); drill rows (a)–(i) each yield a `ring-storage-seam` violation; unmutated baseline green |
| AC-4 — `flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart` green | REQ-3, REQ-6 | Single invocation, all green — **84/84 baseline today** (E8), grows with the R3.2 variant (step 4) and AC-3.6/drill rows (step 3) |
| AC-5 — T-12 joint: existing forged-row negatives stay green **and** the release web build carries no `sso_audit_log` literal/keys — a devtools-forged row cannot even be persisted in release | REQ-3, REQ-4 | `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart` green — AC-1.5 negatives at `audit_log_tab_test.dart:159-160` (plus `:322-323, :354-358, :385-386, :455-456`), T-12 assertions at `admin_support_tabs_test.dart:126-127` (comment `:67`) — `[CORRECTION]` anchors; R3.2 raw-devtools variant green in both polarities with byte-identical off-polarity payload; `make build-prod && make release-artifact-check` → `sso_audit_log` + masks == 0 in `build/web/`. Joint row: `docs/campaigns/implementation-gate.md:56` (B1-5) |

Verification commands (post-implementation, screens lens):

```bash
python3 checks/b6_1b_gates.py                                # 25/25 (today 21/4)
grep -rn 'sso_audit_log' lib/                                # == 1 (audit_log_service.dart:66)
grep -rn 'kDebugMode' lib/api/                               # == 0
grep -rn 'kDebugMode' lib/screens/                           # == 1 (audit_log_tab.dart:298 — D-S2)
grep -rn 'debugStorageEnabled\|_storageEnabled' lib/screens/ # == 0
grep -rn '\.record(' lib/                                    # == 1 (snaplink_admin_api.dart:82)
grep -n "scanId: 'ring-storage-seam'" test/audit_contract_guard_scans.dart   # == 1
git diff --stat lib/api/ lib/screens/ checks/ engineering.yaml Makefile     # api/screens: only the B6-2 change set; gates untouched
flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart \
  test/audit_contract_guard_mutation_test.dart               # 84/84 baseline, >=84 after
flutter test test/audit_log_service_test.dart test/admin_support_tabs_test.dart \
  test/snaplink_admin_api_test.dart test/service_contracts_test.dart \
  test/oidc_login_ring_isolation_test.dart                   # seam + no-regression surface (ring-isolation group :99)
make build-prod && make release-artifact-check               # sso_audit_log + masks == 0 in build/web/
python3 cli.py harness                                       # ci.yml wiring incl. b6_1b_gates
```

## 6. Out of scope (hard boundary — no expansion beyond the direction)

- **Ring-removal phase** (`_recordAudit` deletion, badge/Clear/CSV relabeling, palette wording) — the demotion is the wedge; removal is a later step (seam spec §4).
- **Call-site gating** of `_recordAudit` at `snaplink_admin_api.dart:324` — rejected on sight (AC-2 pin; FD-A1).
- **`lib/screens/admin` census floor** (zero-ring reference scan, facade re-point) — the admin-flag spec's separate direction (`lib-screens-admin-4276368d.json`); its REQ-2/AC-1/AC-5 are superseded in favor of the seam (screens spec §4), its REQ-3/REQ-4 are not this direction's.
- **`removeItem` cleanup of legacy `sso_audit_log` storage in `lib/`** — forbidden post-seam (rule (e)); the api design §4 step-2 pre-seam purge window (if shipped) is that design's migration decision and is deleted by the seam landing.
- **B6-2 items** (client-id wire, T-12 positive joint), **F17 CSV hardening**, **direction-1 nav capability-gating** — separate directions (only direction 1's forged-row assertions are reused via R3.1).
- **Editing the pre-landed gate files** (`checks/config.py`, `checks/b6_1b_gates.py`, `engineering.yaml`, `Makefile`) — verify green, never edit (REQ-5/D3).
- **Any edit to `lib/screens/`** — this direction's screens-side contribution is entirely test-side (§1.3); production code in the screens layer stays byte-identical (C-S1).

## 7. `[PROPOSED]` claims (verified, uncommitted)

- `docs/proposals/b6-1b-lib-api-ring-write-path-isolation-design.md` is **untracked** (`git status` `??`) — the seam/scan design it carries (incl. D7: scan 7 by id) is `[proposed]` until committed.
- The **25/25 gate state is `[proposed]`**: pins pre-landed in final form (E5) but red today (21/4, E4); 25/25 is the landing's definition of done.
- The **`[CORRECTION]` anchors** (E9) and the new **D-S1/D-S2 drifts** are recorded here (D-S2 is new at this design stage: the display gate is at `audit_log_tab.dart:298`, not `:293` as cited in the spec/seam spec/api design); acceptance AC-5 is keyed to the assertions, not the stale line numbers.
- The **84/84 baseline** (E8) was re-verified live at this stage; the secondary trio (45/45) is also green — both recorded as the no-regression floor.
