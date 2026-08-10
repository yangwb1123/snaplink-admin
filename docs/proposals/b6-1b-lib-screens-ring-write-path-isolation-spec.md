# B6-1b — Requirements Specification: ring write-path isolation — recording itself debug-only; release builds no longer persist `sso_audit_log` (module: lib/screens)

> Direction: *"Land B6-1b ring write-path isolation — recording itself must be debug-only; release builds still persist 'sso_audit_log'"* (`docs/auto/analyses/lib-screens-19d4d0ab.json`, direction 1).
> Value 9 · Risk reduction 8 · Effort 4 · Confidence 9.
>
> **Revision 1.** Every direction citation below was re-verified against the live working tree (branch `verify/b6-advance`, HEAD `e1073ce` + uncommitted B6-1/B6-2 change set) on 2026-08-08. State at writing: the **read-path display half is landed** (timeline renders server truth via `AuditReadClient`; ring copy surface is `kDebugMode`-gated at `audit_log_tab.dart:293`), but the **write path is still ungated**: `_save()`/`_load()` persist `'sso_audit_log'` unconditionally. `python3 checks/b6_1b_gates.py` re-run live: **21 pass / 4 fail** — exactly the four cited failures (guard 1/4, storage pin 0/1, `kDebugMode` 2/6, artifact `sso_audit_log` 2× in `build/web/`). The gate files already carry the post-seam pins in final form (verify-green, never edit). The seam/scan design exists (`b6-1b-lib-services-audit-ring-storage-seam-spec.md` REQ-1…REQ-7, `b6-1b-lib-services-audit-ring-storage-seam-design.md`, and the **untracked** `b6-1b-lib-api-ring-write-path-isolation-design.md`); the screens-side flag is pinned as already landed (`b6-1b-lib-screens-admin-ring-debug-flag-spec.md`). This spec is the **lib/screens lens** of that direction: it adopts the seam authority verbatim by reference and pins the screens-side obligations (zero-diff display surface, T-12 joint, release-bundle proof) plus the supplied acceptance checks in runnable form.

## 0. Module boundary and scope

| File | Change | Reason |
|---|---|---|
| `lib/screens/admin/audit_log_tab.dart` | **Zero diff** | Display gate already landed at `:293` (`if (kDebugMode && AuditLogService.ringCopyEnabled)`); `kDebugMode` count in the file stays 1 (harness pin `tab_kdebug_count`). The write-path isolation deliberately lands **below** the screens layer. |
| `lib/services/audit_log_service.dart` | Seam (adopted by reference — REQ-0) | `_storageEnabled = kDebugMode` initializer, const-gated `debugStorageEnabled` setter, first-statement guard pairs in `_save()`/`_load()`, F16 constant-message debugPrints. |
| `lib/api/snaplink_admin_api.dart` | **Zero diff, pinned** | `_recordAudit` `:81-89` and invocation `:324` unchanged; `grep -rn 'kDebugMode' lib/api/` must stay 0 (gate at the service seam, call site untouched). |
| `test/audit_contract_guard_scans.dart` | New scan id `ring-storage-seam` (appended; never renumber) | REQ-2. |
| `test/audit_contract_guard_test.dart`, `test/audit_contract_guard_mutation_test.dart` | Scan group + drill rows | REQ-2. |
| `test/audit_log_tab_test.dart` | T-12 joint extension (devtools-seeding variant) | REQ-3. |
| `test/audit_log_service_test.dart` | **New file** (service behavior; screens-facing consequences pinned here) | REQ-0 (seam spec REQ-4). |
| `checks/config.py`, `engineering.yaml`, `Makefile`, `checks/b6_1b_gates.py` | **Verify green, never edit** | Pins pre-landed in final form (REQ-5). |

## 1. Evidence verification (every direction citation re-checked against the live tree)

| # | Direction citation | Verified repository reality | Status |
|---|---|---|---|
| E1 | `lib/services/audit_log_service.dart:76,83` — landed display gate | `static bool _ringCopyEnabled = kDebugMode;` at `:76`; getter `:79`; `@visibleForTesting set debugRingEnabled` `:81-85` with `if (!kDebugMode) return;` at `:83` (const-folds in release). `kDebugMode` count in file = 2. | ✅ |
| E2 | `_save()`/`_load()` at `:127-146` call `LocalStorage.setItem/getItem` with no build gate | Exact: `_save()` `:127-134` → `LocalStorage.setItem(_storageKey, jsonStr)` at `:130`; `_load()` `:136-146` → `LocalStorage.getItem(_storageKey)` at `:138`; **unconditional**. `debugPrint('audit_log persist/load error: $e')` at `:132`/`:146` (F16 violation — seam fixes to `'audit_log storage error: ${e.runtimeType}'`). `_storageKey = 'sso_audit_log'` at `:66` is the **only** hit in `lib/` (count 1). `record()` `:89-95` → `_save()` `:94`; `clear()` `:120-124` → `_save()` `:122`; ctor `:60-62` → `_load()` `:61`. | ✅ |
| E3 | `lib/api/snaplink_admin_api.dart:82` `_recordAudit` — the sole `.record(` caller, fired on every non-GET admin call | `_recordAudit` `:81-89`, `AuditLogService().record(` at `:82`; `grep -rn '\.record(' lib/` == exactly 1. Invocation at `:324` inside `if (method != 'GET')` `:323` within the 2xx branch `:321-326` (`_fireDataChanged` `:325`). Zero `kDebugMode` in `lib/api/` (grep → 0 hits). | ✅ |
| E4 | `lib/screens/admin/audit_log_tab.dart:298` — debug-only ring surface already landed | Gate at `:293` (`if (kDebugMode && AuditLogService.ringCopyEnabled)`); StatusChip `'Debug records'` + count + Clear action follow. `kDebugMode` in tab = 1 (harness `tab_kdebug_count`). | ✅ |
| E5 | `checks/b6_1b_gates.py` = 21 pass / 4 fail (artifact 2×, storage pin 0/1, kDebugMode 2/6, guard 1/4) | **Re-ran live: 21 passed, 4 failures, exit 1** — failures exactly: `guard_line_count` 1≠4, `storage_initializer_pin` 0≠1, `service_kdebug_count` 2≠6, artifact `'sso_audit_log'` found 2 in `build/web/` (in `main.dart.js`). | ✅ |
| E6 | Gate files already carry the post-seam pins | `checks/config.py:89-94`: `service_kdebug_count = 6` ("post-seam (interim was 2)"), `tab_kdebug_count = 1`, `initializer_pin = "_ringCopyEnabled = kDebugMode"`, `storage_initializer_pin = "_storageEnabled = kDebugMode"`, `guard_line = "if (!kDebugMode) return;"`, `guard_line_count = 4`; banned service tokens (`String.fromCharCodes`, `base64Decode`, `base64Url`). `engineering.yaml:189-194` mirrors. `Makefile:36-44` `release-artifact-check`: fail-closed `grep` for `sso_audit_log` == 0 in `build/web/` + both base64 masks; `:29` documents the pre-seam baseline "exactly 2 occurrences". | ✅ |
| E7 | Seam spec/design + api design exist; api design **untracked** | Tracked: `b6-1b-lib-services-audit-ring-storage-seam-{spec,design}.md`, `b6-1b-lib-screens-admin-ring-debug-flag-{spec,design}.md`. **Untracked** (`git status` `??`): `docs/proposals/b6-1b-lib-api-ring-write-path-isolation-design.md` — the direction's `[proposed]` claim verified. | ✅ |
| E8 | Scan id `ring-storage-seam` absent today; scans are 1…6b + trio pin | `test/audit_contract_guard_scans.dart`: header docstring `:7-36` lists items 1, 2, 3, 4, 5, 6 (portal), 6b (developer); `AuditGuardViolation.scan` doc `:42-44` lists ids; `scanLibDirectory` docstring `:94-97` "Runs scans 1, 2, 4, 5, 6 (portal boundary), and 6b (developer boundary) plus the trio-literal ownership pin"; body `:98-112`. `grep -rn 'ring-storage-seam' test/ checks/` → **0 hits**. Per the api design's drift corrections D2/D7 the new scan is appended by **id** as scan 7 — never renumbered. | ✅ |
| E9 | Mutation drill `_scanWith` harness + baseline | `test/audit_contract_guard_mutation_test.dart`: `_scanWith` `:36-75` (in-memory overrides, default scan set `:38-43` = {audit-path-literals, bff-literals, raw-stringification, portal-audit-boundary, developer-audit-boundary}, dispatch `:52-72`, trio `:73-75`); baseline group `:80`; planted groups `:94`/`:345`/`:407`; residual group `:517`. 29 tests. | ✅ |
| E10 | `test/audit_contract_guard_test.dart` — live-tree green groups + temp-dir probe precedent | 28 tests; groups AC-3.1 `:34`, AC-3.2 `:108`, AC-3.3 `:139`, scan 5 `:170`, scan 6 portal `:314` (synthetic temp-dir probes `:322-413`), scan 6b developer `:433`. Header docstring `:1-2` "the corrected four scans plus the B6-1 portal boundary scan (scan 6)" — normalization target for seven-scan phrasing. | ✅ |
| E11 | T-12 forged-row negatives: `audit_log_tab_test.dart` AC-1.5 `:143-145`; `admin_support_tabs_test.dart:67` | **`[CORRECTION — anchor drift]`** `audit_log_tab_test.dart:143-145` holds AC-1.4 (decoy-count `'999'` findsNothing `:149`, server-row assertions); the AC-1.5 forged-row negatives are at **`:159-160`** (`expect(find.textContaining('/api/v1/admin/forged'), findsNothing)` + `'forged entry'`), with further negatives at `:322-323`, `:354-358`, `:385-386`, `:455-456`; shared seeder `_seedForgedRing()` `:104-117` (records `/api/v1/admin/forged` + `'forged entry'` via `AuditLogService.record`). `admin_support_tabs_test.dart:67` is the T-12 comment ("must never render these rows (T-12: ring is not evidence)"); the assertions are at **`:126-127`**. Substance of the citation (forged rows never render; ring clear inert) verified present and green. | ✅ + ⚠️ |
| E12 | `implementation-gate.md:56` — contract row 1 (B1-5) "localStorage ring 降级为调试记录" + T-12 joint "devtools 伪造不再构成证据" | Line 56 = console row 1: "读路径接入（F-06）：审计页调 sink 读 API…；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5". Row is **half-met** today: display demoted, recording not. | ✅ |
| E13 | (new) Live baseline of the three acceptance files | `flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart` → **84/84 pass** (includes the B6-1b copy-surface group in `audit_log_tab_test.dart`, all AC-1.5 negatives, drill baseline + planted rows). | ✅ |
| E14 | (new) `test/audit_log_service_test.dart` does not exist; `cli.py` wiring | File absent (seam deliverable). `cli.py:136-144` `cmd_harness` runs `b6_1b_gates` among the checks — the CI wiring that must report 25/25 post-landing. | ✅ |

## 2. Normative requirements

### REQ-0 — Seam authority adopted verbatim by reference

The write-path isolation mechanics are **already specified**: `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-spec.md` (REQ-1…REQ-7) and `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-design.md` (§1.1 seam code verbatim, §1.2 scan draft, §1.3 registration, §1.4 drill rows (a)–(i), §1.5 service behavior tests, §1.6 tab joint, §1.7 gate diffs, §4 migration), with the lib/api lens and drift corrections D1–D7 in `docs/proposals/b6-1b-lib-api-ring-write-path-isolation-design.md`. This spec does **not** restate them; it pins the **screens-side contract** they must satisfy and the supplied acceptance checks. Landing order per the api design §4 (steps 1–5) is adopted unchanged; nothing in those steps touches `lib/screens/`.

### REQ-1 — `lib/screens/admin/audit_log_tab.dart` zero-diff pin

- **R1.1** No edits to `lib/screens/admin/audit_log_tab.dart` attributable to this direction (verify `git diff lib/screens/admin/audit_log_tab.dart` shows only the pre-existing B6-2 i18n change set — TIME-column localization in `_formatTime`; the B6-1b ring surface at `:293` is committed at HEAD and must stay byte-identical).
- **R1.2** The debug ring copy surface stays exactly as landed: gate `:293` `if (kDebugMode && AuditLogService.ringCopyEnabled)`, `kDebugMode` count in the file == 1 (`tab_kdebug_count` pin), i18n keys unchanged. The surface remains debug-only; the seam changes nothing the tab reads (`ringCopyEnabled`/`count`/`clear` untouched by the seam — C3).
- **R1.3** No screens file may reference `_storageEnabled` or `debugStorageEnabled` (the seam flag is `@visibleForTesting`, exercised by `test/audit_log_service_test.dart` and the T-12 polarity tests only).

### REQ-2 — Scan `ring-storage-seam` registration (id-based, appended as scan 7)

Adopt the api design §1.3/§1.4 and D2/D7 exactly; the screens-side obligation is that the scan exists, is registered, and is green:

- **R2.1** `test/audit_contract_guard_scans.dart`: new `scanRingStorageSeam` (key-scoped: `sso_audit_log` literal count == 1 across `lib/`, service file only — any hit in `lib/api/` or `lib/screens/` trips; service-file pins: `kDebugMode` == 6, `if (!kDebugMode) return;` == 4, `_storageEnabled = kDebugMode` initializer == 1, `_storageEnabled = value` == 1, `LocalStorage.` == 2, guard-before-I/O ordering, bans on `assert(kDebugMode`/`bool.fromEnvironment`/`String.fromCharCodes`/`base64Decode`/`base64Url`/`debugPrint\([^)]*\$e`). Called from `scanLibDirectory` (body `:98-112` gains the call) and registered in the mutation drill's `_scanWith` default set `:38-43` + dispatch `:52-72`.
- **R2.2** Docstring normalization (append-only, never renumber): scans.dart header `:7-36` gains item 7; `AuditGuardViolation.scan` doc `:42-44` gains the id; `scanLibDirectory` docstring `:94-97` gains the id in its run list; guard_test header `:1-2` → seven-scan phrasing.
- **R2.3** `test/audit_contract_guard_test.dart`: new `ring-storage-seam` group — live-tree green + unit probes + **anti-vacuity temp-dir probe** (a guard removed from a temp `services/audit_log_service.dart` must trip the scan — catches a dropped registration; precedent `:322-413`).
- **R2.4** `test/audit_contract_guard_mutation_test.dart`: drill rows (a)–(i) per the seam design §1.4, each reporting `scan == 'ring-storage-seam'`; unmutated baseline group `:80` stays green; residual group `:517` gains the adjacent-literal split note (artifact gate is the backstop).

### REQ-3 — T-12 joint: forged rows never render, and release cannot persist them (REQ-3 + REQ-4 of the direction acceptance)

- **R3.1** Existing forged-row negatives stay green **unchanged**: `test/audit_log_tab_test.dart` AC-1.5 `:159-160` (+ `:322-323`, `:354-358`, `:385-386`, `:455-456`) and `test/admin_support_tabs_test.dart` `:126-127` (`ring clear is inert`, T-12 comment `:66-67`).
- **R3.2** Devtools-seeding variant added to `test/audit_log_tab_test.dart`: seed the ring via **raw** `LocalStorage.setItem('sso_audit_log', <forged JSON>)` before the page pump (a devtools-forged payload, not `AuditLogService().record`), assert zero forged rows render, in **both** polarities (`debugStorageEnabled` on and off); teardown removes the seeded key and restores the flag (`addTearDown`). Display truth comes exclusively from `AuditReadClient` (`/api/v1/audit/events`).
- **R3.3** Dependency recorded (R5.3 of the seam spec): the joint is conditioned on the landed server-fed timeline (direction 1, in-tree today); if that read path is reverted the check is blocked, not silently green.
- **R3.4** The persistence half of the joint is the release-bundle proof (REQ-4): because the key literal and all storage I/O const-fold out of release, a devtools-forged row **cannot be persisted in release** — the ring storage simply does not exist in the bundle, and any pre-seam leftover is provably inert (never read, never written, no `removeItem` — seam rule (e)).

### REQ-4 — Release-bundle proof (gate artifact checks)

- **R4.1** `make build-prod && make release-artifact-check` green post-landing: `sso_audit_log` and its base64/base64Url masks == 0 occurrences in `build/web/` (Makefile `:36-44`, fail-closed). Non-vacuous: today the needle is live (2 hits in `build/web/main.dart.js`).
- **R4.2** `python3 checks/b6_1b_gates.py` → **25/25** (guard 4/4, storage pin 1/1, `kDebugMode` 6/6, artifact 0/0, key residence 1/1, masks 0/0). Today 21/4 — the four failures are precisely the unlanded seam; they are the landing's definition of done.

### REQ-5 — Gate files: verify green, never edit

`checks/config.py:89-94`, `engineering.yaml:189-194`, `Makefile:36-44`, `checks/b6_1b_gates.py` already carry the final-form post-seam pins (E6). The landing commit must **not** modify them; the implementer verifies green post-seam. `python3 cli.py harness` (`cli.py:144` runs `b6_1b_gates`) is the CI wiring that must report green.

### REQ-6 — No-regression (screens-side surface)

All of the following stay green post-landing, unchanged in debug mode (flag defaults on):

- `flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart` (84/84 today, ≥84 after — acceptance #4);
- `test/admin_support_tabs_test.dart` (ring-clear inert `:63-143`), `test/snaplink_admin_api_test.dart` ring-liveness (group `:327-420` — POST/PUT/DELETE persist exactly one entry in debug; GET never records), `test/service_contracts_test.dart` `AuditLogService` group (`:18-33` — public API list unchanged), `test/oidc_login_ring_isolation_test.dart` (`:104-136`);
- `grep -rn '\.record(' lib/` == 1 (`snaplink_admin_api.dart:82`).

## 3. Acceptance mapping (the supplied checks, preserved 1:1, runnable form)

| Direction acceptance | REQs | Runnable assertion |
|---|---|---|
| AC-1 — `python3 checks/b6_1b_gates.py` → **25/25** (storage pin 1/1, kDebugMode 6/6, artifact 0/0, guard 4/4) | REQ-4, REQ-5 | `python3 checks/b6_1b_gates.py` exits 0 with all 25 checks `[+]` (today: 21 pass / 4 fail, exit 1 — recorded baseline). Gate files untouched by the landing (`git diff --stat checks/ engineering.yaml Makefile` empty). |
| AC-2 — `grep -rn 'sso_audit_log' lib/` == **1** hit (service only) **and** `grep -rn kDebugMode lib/api/` == **0** (write path gated at the service seam, call site untouched) | REQ-1, REQ-2 (R2.1), REQ-6 | Two greps above + `grep -rn '\.record(' lib/` == 1 (`:82`) + no diff in `lib/api/` and no diff in `lib/screens/` beyond the pre-existing B6-2 i18n change set (R1.1). Scan `ring-storage-seam` non-service branch trips on any second literal (drill row (g)). |
| AC-3 — scan id `ring-storage-seam` present in `test/audit_contract_guard_scans.dart` **and green** | REQ-2 | `grep -n "scanId: 'ring-storage-seam'" test/audit_contract_guard_scans.dart` == 1; registered in `scanLibDirectory` + `_scanWith` default set; new guard-test group green incl. anti-vacuity probe; drill rows (a)–(i) trip, baseline green. |
| AC-4 — `flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart` green | REQ-3, REQ-6 | Single invocation above, all green (84/84 baseline today; grows with the R3.2 variant and R2.3/R2.4 additions). |
| AC-5 — T-12 joint: existing forged-row negatives (`audit_log_tab_test.dart` AC-1.5 `:143-145`, `admin_support_tabs_test.dart:67`) stay green **and** the release web build carries no `sso_audit_log` literal/keys — a devtools-forged row cannot even be persisted in release | REQ-3, REQ-4 | `flutter test test/audit_log_tab_test.dart test/admin_support_tabs_test.dart` green (AC-1.5 `:159-160`, T-12 `:126-127` — `[CORRECTION]` anchors, E11) + R3.2 devtools-seeding variant both polarities green; `make build-prod && make release-artifact-check` → `sso_audit_log` + masks == 0 in `build/web/`. Joint mapped to `implementation-gate.md:56` row 1 (B1-5): "devtools 伪造不再构成证据". |

## 4. Cross-spec coordination (must read before landing)

- **Consistent with the seam spec.** `b6-1b-lib-services-audit-ring-storage-seam-spec.md` §4 walls call-site gating ("`_recordAudit` `:81/324` unchanged … Any implementer deviation toward call-site gating must be rejected") — **this direction agrees**: the supplied acceptance mandates `grep -rn 'kDebugMode' lib/api/` == 0. The service-boundary seam is the single mechanism; `snaplink_admin_api.dart` stays byte-identical.
- **Supersedes the admin-flag spec's writer gate.** `b6-1b-lib-screens-admin-ring-debug-flag-spec.md` (REQ-2, AC-1, AC-5) proposed gating the `_recordAudit` invocation at `:324` behind `AuditLogService.debugRingEnabled`. The direction selected here (module `lib/screens` authority, analysis `lib-screens-19d4d0ab.json`) **resolves that conflict in favor of the seam**: the flag spec's call-site gate is withdrawn; its display-floor pieces (REQ-3 census, REQ-4 facade re-point) belong to the separate `lib-screens-admin-4276368d.json` direction and are out of scope here. Both layers compose only seam-first: the seam kills release persistence; the display flag (already landed) gates the debug surface.
- **Contract row completion.** `implementation-gate.md:56` row 1 (B1-5) "localStorage ring 降级为调试记录" is half-met today (display demoted, recording not); this landing completes it, satisfying the T-12 joint "devtools 伪造不再构成证据" on both halves (never rendered, never persisted in release).

## 5. Out of scope (hard boundary — no expansion beyond the direction)

- **Ring-removal phase** (`_recordAudit` deletion, badge/Clear/CSV relabeling, palette wording) — the demotion is the wedge; removal is a later step (seam spec §4).
- **Call-site gating** of `_recordAudit` — rejected on sight (AC-2 pin `kDebugMode` in `lib/api/` == 0; FD-A1 of the api design).
- **`lib/screens/admin` census floor** (zero-ring reference scan, lib/api facade re-point) — the admin-flag spec's separate direction (`lib-screens-admin-4276368d.json`); its REQ-2/AC-1/AC-5 are superseded per §4, its REQ-3/REQ-4 are not this direction's.
- **`removeItem` cleanup of legacy `sso_audit_log` storage in `lib/`** — forbidden post-seam (rule (e)); the api design §4 step 2 pre-seam purge window (if shipped) is that design's migration decision, does not touch `lib/screens/`, and is deleted by the seam landing.
- **B6-2 items** (client-id wire, T-12 positive joint), **F17 CSV hardening**, **direction-1 nav capability-gating** — separate directions (only direction 1's forged-row assertions are reused via R3.1).
- **Editing the pre-landed gate files** (`checks/config.py`, `checks/b6_1b_gates.py`, `engineering.yaml`, `Makefile`) — verify green, never edit (REQ-5).

## 6. Verification commands (post-implementation)

```bash
python3 checks/b6_1b_gates.py                                # 25/25 after landing (21/4 today)
grep -rn 'sso_audit_log' lib/                                # == 1 (audit_log_service.dart:66)
grep -rn 'kDebugMode' lib/api/                               # == 0
grep -rn '\.record(' lib/                                    # == 1 (snaplink_admin_api.dart:82)
grep -n "scanId: 'ring-storage-seam'" test/audit_contract_guard_scans.dart   # == 1
git diff --stat lib/api/ lib/screens/ checks/ engineering.yaml Makefile     # lib/api zero-diff; lib/screens only the pre-existing B6-2 change set; gates untouched
flutter test test/audit_log_tab_test.dart test/audit_contract_guard_test.dart \
  test/audit_contract_guard_mutation_test.dart               # 84/84 baseline today, >=84 after
flutter test test/audit_log_service_test.dart test/admin_support_tabs_test.dart \
  test/snaplink_admin_api_test.dart test/service_contracts_test.dart \
  test/oidc_login_ring_isolation_test.dart                   # seam + no-regression surface
make build-prod && make release-artifact-check               # sso_audit_log + masks == 0 in build/web/
python3 cli.py harness                                       # ci.yml wiring incl. b6_1b_gates
```

## 7. `[PROPOSED]` claims (verified, uncommitted)

- `docs/proposals/b6-1b-lib-api-ring-write-path-isolation-design.md` is **untracked** (`git status` `??`) — the seam/scan design it carries (incl. D7: `ring-storage-seam` appended as scan 7, id-based pins) is `[proposed]` until committed.
- The **25/25 gate state is `[proposed]`**: the pins are pre-landed in final form (E6) but red today (21/4); 25/25 is the definition of done for this landing, not a current-tree fact.
- The **`[CORRECTION]` anchors** (E11): AC-1.5 negatives live at `audit_log_tab_test.dart:159-160` (not `:143-145`) and `admin_support_tabs_test.dart:126-127` (not `:67`); the cited lines hold adjacent AC-1.4/T-12-comment content. Acceptance AC-5 is keyed to the assertions, not the stale line numbers.
