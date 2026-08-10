# Requirements — Demote the localStorage ring to debug-only recording (kDebugMode gate + write-path isolation)

Direction: "Demote the localStorage ring to debug-only recording at the service boundary (kDebugMode gate + write-path isolation), completing T-12's forgery floor" — module `lib/screens` (B6-1b storage-seam wedge of b6-1a §1.2a). Scope: `lib/services/audit_log_service.dart` seam, scan/drill extensions, new behavior tests, gate re-pins, T-12 joint extension. No scope expansion.

## 1. Evidence verification (every direction citation checked against the current tree)

| # | Direction citation | Verdict | Current tree (verified) |
|---|---|---|---|
| E1 | `lib/services/audit_log_service.dart` — `_storageKey = 'sso_audit_log'`; `_save()`/`_load()` unconditional `LocalStorage.setItem/getItem` | ✅ | `_storageKey` at `:66` (the **only** `sso_audit_log` hit in `lib/`, count 1). `record()` `:83-90` → `_save()` at `:89`; `clear()` `:119-122` → `_save()` at `:121`; ctor `:60-62` → `_load()`. `_save()` `:126-134` calls `LocalStorage.setItem(_storageKey, jsonStr)` at `:130` **unconditionally**; `_load()` `:136-146` calls `LocalStorage.getItem` at `:138` **unconditionally** — no kDebugMode guard on the storage path today. Note: the B6-1b copy-surface gate (`_ringCopyEnabled`/`debugRingEnabled`, `:69-86`) already landed in the working tree; it gates *display*, not storage I/O. |
| E2 | `lib/api/snaplink_admin_api.dart:81-83` — `_recordAudit`, sole ring writer | ✅ | `_recordAudit` at `:81-88`, `AuditLogService().record(` at `:82`; call site at `:323-325` (`if (method != 'GET')` inside the 2xx branch). Grep of `lib/` confirms no other `record(` call on `AuditLogService` — sole writer claim holds. |
| E3 | `test/oidc_login_audit_visibility_guard_test.dart` — AC-2 module-level zero-reference guard | ✅ | Literal-split needles (`'AuditLog' 'Service'`, `'audit_log_' 'service'`, `'sso_audit_' 'log'`) over `lib/screens/oidc_login`; zero ring references there. Untouched by this direction; regression pin only. |
| E4 | `test/audit_contract_guard_mutation_test.dart` + `test/audit_contract_guard_scans.dart` — trip matrix + scan helpers to extend | ✅ | Scans 1/2/4/5 (`audit-path-literals`, `bff-literals`, `raw-stringification`, `second-consumer`) + runtime `catalog-trio`; `_scanWith` in-memory override harness; planted-regression groups + documented-residual group. Extension point for scan 6 confirmed. |
| E5 | `docs/campaigns/implementation-gate.md:56` — console row 1 "localStorage ring 降级为调试记录" | ✅ | Row 1 (B1-5): "localStorage ring 降级为调试记录；展示服务端记录" with T-12 joint: "devtools 伪造不再构成证据". |
| E6 | `docs/proposals/b6-1a-lib-api-auditlogtab-server-read-design.md:184` — F7 ring forgery → timeline never reads the ring | ✅ | F7 at `:184`. Also controlling: **§1.2a `:95-124`** (mandated seam shape: `_storageEnabled = kDebugMode` `:102`, const-gated setter `:106-107`, direct `if (!kDebugMode) return;` first-statement guards in `_save`/`_load` `:111-117`, rules (a)-(e)), **C3 `:165`** (`AuditLogService` public API untouched; `_recordAudit` `:81/324` unchanged; release: `_load`/`_save` no-op, ring memory-only), **F13 `:190`** (seam shape + release-artifact grep gate + source gates: `fromCharCodes` zero, key literal exactly 1 hit), **F16 `:191`** (constant-message debug prints, never `$e`), **AC-7 `:222`** (`test/audit_log_service_test.dart` new + artifact gate), **§4 `:238`** (demotion is B6-1b scope). |

Additional current-tree facts the spec is built on (drift vs. the analysis snapshot):

- **Direction-1 precondition already met in-tree**: the timeline is server-fed via `AuditReadClient` (`audit_log_tab.dart:35-36,53`, capability-gated `:68`), and `test/audit_log_tab_test.dart` already asserts forged ring rows never render (AC-1.5 `:90-145`, `:241-242`, `:273-274`, `:304-305`). Acceptance #3's "once server-fed per direction 1" is therefore testable now.
- **`LocalStorage` is legitimately used elsewhere in `lib/`** with non-ring keys (`app_settings.dart:170-183`, `cross_tab_sync.dart:54-61`, `list_state_manager.dart:21-46`, `oidc_login/trusted_device_token.dart:12-22`) — the static guard must be **key-scoped** (`sso_audit_log`), never call-scoped.
- **Gate re-pin is mandated, not expansion**: `checks/b6_1b_gates.py` pins `service_kdebug_count = 2` (`checks/config.py:84`) and initializer `_ringCopyEnabled = kDebugMode` (`:86`); its own docstring states the counts are interim and "the storage seam (b6-1a §1.2a) re-pins them when it lands". `Makefile release-artifact-check` (`:23-29`) + `checks/b6_1b_gates.py` artifact needles already implement the release-bundle grep pattern the seam's F13 gate extends.
- **Zero pre-existing hits** in `lib/` for `bool.fromEnvironment`, `assert(kDebugMode`, `String.fromCharCodes` — absence pins start green.
- `kDebugMode` appears in `lib/` only in `audit_log_service.dart` (2×) and `audit_log_tab.dart:293` (1×, display gate — unchanged).

## 2. Normative requirements

### REQ-1 — Storage seam in `AuditLogService` (`lib/services/audit_log_service.dart`)

Implement the b6-1a §1.2a seam shape verbatim (W2/F13/S14):

- **R1.1** `static bool _storageEnabled = kDebugMode;` — const-folded initializer line, pinned.
- **R1.2** `@visibleForTesting static set debugStorageEnabled(bool value) { if (!kDebugMode) return; _storageEnabled = value; }` — const-gated setter (assignment unreachable in release), same shape as the existing `debugRingEnabled` setter.
- **R1.3** `_save()`: first statements `if (!kDebugMode) return;` then `if (!_storageEnabled) return;` — **before** the `try`/I/O (structural DCE by const folding; never `assert`, which is stripped in release).
- **R1.4** `_load()`: identical two first-statement guards.
- **R1.5** `kDebugMode` is the **only** enable axis — no `bool.fromEnvironment`, no env var, no second flag (rule c).
- **R1.6** `record()`/`clear()`/`entries`/`search`/`filterByMethod`/`recent`/`count` and the `AuditEntry` surface are **unchanged** (C3): in-memory ring (bounded 1000) keeps working with the flag off; release ring is memory-only.
- **R1.7** No `removeItem` migration of a legacy `sso_audit_log` payload (rule e — deleting the key would require the literal in release-reachable code and defeat the artifact gate; leftover storage is provably inert instead).
- **R1.8** Both `_save`/`_load` catches print a constant message + `e.runtimeType` only — never `$e` (F16; the same two functions being rewritten).
- **R1.9** `_recordAudit` at `snaplink_admin_api.dart:81-88` is **unchanged** (C3). Write-path isolation is achieved at the service boundary: in release the call site can never persist because `_save()` no-ops. Gating `_recordAudit` itself is out of scope (see §4) — acceptance #1 is asserted at the service API, and acceptance #4 requires the mutation-recording tests to pass unchanged.

### REQ-2 — Static guard: scan 6 `ring-storage-seam` (`test/audit_contract_guard_scans.dart`)

New scan added to `scanLibDirectory` and the drill's `_scanWith` default scan set. Key-scoped (E-fact 2), grep-level, absence + positive pins:

- **R2.1** Lib-wide: `sso_audit_log` literal count == **1** across `lib/` (must be `audit_log_service.dart` only) — any second hit (duplicate literal, moved literal, debug badge string) trips (F13 S16).
- **R2.2** In `audit_log_service.dart`: `if (!kDebugMode) return;` count == **4** (ringCopy setter + storage setter + `_save` + `_load`); `kDebugMode` count == **6** (adds the two initializers).
- **R2.3** In `audit_log_service.dart`: initializer line `static bool _storageEnabled = kDebugMode;` exactly 1; `_storageEnabled = value` exactly 1.
- **R2.4** Ordering pin in `audit_log_service.dart`: index of the **last** `if (!kDebugMode) return;` < index of the **first** `LocalStorage.` token (guards textually precede the I/O — S14 structural requirement; also trips if `setItem` is hoisted into `record()`).
- **R2.5** In `audit_log_service.dart`: `LocalStorage.` tokens == **2** (one `setItem` in `_save`, one `getItem` in `_load` — write path isolated to `_save` only).
- **R2.6** In `audit_log_service.dart`: zero hits for `assert(kDebugMode`, `bool.fromEnvironment`, `String.fromCharCodes`, and `debugPrint` regex `debugPrint\([^)]*\$e` (F13/F16/S15; all zero in-tree today, E-fact 4).
- **R2.7** Baseline group in the mutation test ("all scans pass on the live lib/ tree") stays green; docstring scan count updated five → six.

### REQ-3 — Mutation drill rows (`test/audit_contract_guard_mutation_test.dart`)

Extend the planted-regression trip matrix (in-memory overrides via `_scanWith`, scan set gains `ring-storage-seam`); each mutation must trip scan 6 and the unmutated baseline must stay green:

- (a) both guards removed from `_save` (unconditional write restored) → R2.2
- (b) `if (!kDebugMode) return;` replaced with `assert(kDebugMode);` in `_save` → R2.6
- (c) `LocalStorage.setItem` hoisted into `record()` → R2.5/R2.4
- (d) `bool.fromEnvironment('ringStorage')` axis added → R2.6
- (e) const guard deleted from the `debugStorageEnabled` setter → R2.2
- (f) initializer changed to `_storageEnabled = true` → R2.3
- (g) `sso_audit_log` literal duplicated in another `lib/` file (e.g. `snaplink_admin_api.dart`) → R2.1
- (h) `String.fromCharCodes` key reconstruction in `audit_log_service.dart` → R2.6
- (i) `$e` reintroduced in the persist/load debugPrint → R2.6
- **Documented residual (accepted, same class as the existing split-literal residuals)**: adjacent-literal key split (`'sso_' 'audit_log'`) evades R2.1 at source level — but the concatenated constant still lands the full string in the release bundle, so the **release artifact gate (R6.3) is the backstop**; record this in the residual group with the note that the artifact gate closes what the source grep cannot.

### REQ-4 — Behavior tests: new `test/audit_log_service_test.dart` (design AC-7)

- **R4.1** Write path, flag off (release simulation): `AuditLogService.debugStorageEnabled = false`; `record()` N≥3 distinct entries → `LocalStorage.keys()` contains no `sso_audit_log`, `LocalStorage.getItem('sso_audit_log')` is null, and `entries`/`count`/`search`/`filterByMethod`/`recent`/`clear` still work **in memory** (C3 — public API unaffected). `clear()` likewise leaves storage untouched.
- **R4.2** Write path, flag on (debug/dev behavior preserved): `debugStorageEnabled = true`; `record()` N entries → key present, JSON decodes to exactly N entries, first entry is the most recent, wire fields `{timestamp, method, path, statusCode, label}` intact; `clear()` → key present with `[]`.
- **R4.3** Load path, flag off: **first test in the file** (documented construction-order contract — the singleton's `_load()` runs once per test-file isolate): seed a forged payload via `LocalStorage.setItem('sso_audit_log', <forged JSON>)` before the first `AuditLogService()`; flag off; construct → `entries` empty (gated read) and the stored payload **byte-identical** afterwards (no read, no `removeItem` — R1.7).
- **R4.4** Flag-off persistence of the existing singleton state: with flag off, `record()`/`clear()` never modify the pre-seeded payload from R4.3 (write isolation).
- Load-on polarity needs no new test: every existing ring test constructs the service with the default axis on (acceptance #4 pins them), and the F16 payload-echo concern is enforced statically by R2.6 (grep), avoiding a second first-construction polarity conflict.

### REQ-5 — T-12 joint: forged rows never constitute evidence (`test/audit_log_tab_test.dart`)

Extend the existing forged-row group (AC-1.5) so the joint cannot go vacuous post-demotion:

- **R5.1** Keep the existing assertions (record-seeded forged ring row `/api/v1/admin/forged` never renders — `:144-145`, `:241-242`, `:273-274`, `:304-305`).
- **R5.2** Add the devtools-seeding variant: `LocalStorage.setItem('sso_audit_log', <forged JSON>)` **before** the page pump (raw devtools-forged payload, not service-`record`-seeded), assert the timeline renders zero forged rows in both polarities (`debugStorageEnabled` on and off). Display truth comes exclusively from `AuditReadClient` (`/api/v1/audit/events`) — F7.
- **R5.3** Dependency recorded: this acceptance is conditioned on the server-fed timeline (direction 1), which is already landed in the working tree; if that read path is reverted, this check is blocked (B1-5), not silently green.

### REQ-6 — Gate re-pins (atomic companions; keeps acceptance #4's "existing gates pass" true)

- **R6.1** `checks/config.py:84`: `service_kdebug_count` 2 → **6**. `:86` initializer pin: keep `_ringCopyEnabled = kDebugMode`, add `_storageEnabled = kDebugMode` (config gains a second pin field or a list; `checks/b6_1b_gates.py` iterates). `tab_kdebug_count` (1) unchanged.
- **R6.2** `checks/b6_1b_gates.py`: add source pins mirroring R2.1/R2.2 (`sso_audit_log` exactly 1 in `lib/`; `if (!kDebugMode) return;` == 4 in the service file).
- **R6.3** Release artifact gate (F13, §1.2a rule e): add the needle `sso_audit_log` to `checks/b6_1b_gates.py` `artifact_en_needles` and to `Makefile release-artifact-check` (`grep -cF 'sso_audit_log' build/web/main.dart.js` == 0). Non-vacuous: the key is in the release bundle **today** (the seam is not landed); after landing it must vanish (DCE by const folding, empirically verified in §1.2a). Runs after `make build-prod` in CI — same wiring as the existing copy needles.

### REQ-7 — No-regression pins (acceptance #4)

All of the following must pass unchanged in debug mode (default axis on, ring behavior preserved). List them as a regression group in the new test file or in the drill baseline:

- `test/snaplink_admin_api_test.dart` ring-liveness group (`:330-420` — POST/PUT/DELETE append exactly one persisted entry under `sso_audit_log`; GET never records)
- `test/audit_log_tab_test.dart` (all groups, incl. B6-1b copy surface `:414+`)
- `test/admin_support_tabs_test.dart` ring-clear test (`:63-143`)
- `test/oidc_login_ring_isolation_test.dart` (`:117-135` — login leaves the pre-seeded ring untouched)
- `test/oidc_login_audit_visibility_guard_test.dart` (E3)
- `test/service_contracts_test.dart` `AuditLogService` group (`:18` — public API list unchanged, C3)
- `test/audit_contract_guard_mutation_test.dart` baseline + all existing planted rows
- `python cli.py harness` (runs `checks/b6_1b_gates.py` per `ci.yml`)

## 3. Acceptance mapping (direction acceptance → requirements, runnable form)

| Direction acceptance | Requirements | Runnable assertion |
|---|---|---|
| AC-1 Mutation tests: flag off → `record()` never calls `setItem`, key absent after N records; flag on → recording works | REQ-1 (R1.1-R1.4), REQ-4 (R4.1, R4.2), REQ-3 (matrix rows) | `test/audit_log_service_test.dart`: `debugStorageEnabled = false` → after 3 records `LocalStorage.keys()` contains no `sso_audit_log`; `= true` → key present with 3 entries. Drill rows (a)-(i) trip scan 6, baseline green. |
| AC-2 Static guard: release/flag-off config, grep-level proof of no unconditional `LocalStorage.setItem('sso_audit_log'...)` outside the debug-gated branch | REQ-2 (R2.1-R2.6), REQ-6 (R6.1-R6.3) | `test/audit_contract_guard_scans.dart` scan 6 green on live tree; `checks/b6_1b_gates.py` + `make release-artifact-check` green post-landing (needle absent from `build/web/main.dart.js`). |
| AC-3 T-12 joint: devtools/localStorage-seeded forged rows → timeline renders zero forged rows | REQ-5 (R5.1-R5.3) | `test/audit_log_tab_test.dart`: raw `sso_audit_log` forged payload seeded pre-pump → `find.textContaining('/api/v1/admin/forged')` findsNothing, both polarities. |
| AC-4 Existing ring-dependent tests pass unchanged in debug mode | REQ-6, REQ-7 | The full REQ-7 list green via `flutter test`; `python cli.py harness` green after the R6.1 re-pin. |

## 4. Out of scope (explicit walls)

- **B6-1b removal phase** (`_recordAudit` deletion, debug badge/Clear/CSV relabeling, palette wording) — the demotion is the wedge; removal is a later step (§4 of the design).
- **Gating `_recordAudit` itself** with `kDebugMode` at `snaplink_admin_api.dart` — contradicts C3 ("`_recordAudit` :81/324 unchanged") and is not needed by any acceptance check: the service-boundary seam makes release persistence impossible while keeping dev observability identical. Any implementer deviation toward call-site gating must be rejected.
- **Direction 1** (nav capability-gating of `AuditLogTab`, `supportsAudit` registration, row-model re-pinning) — separate direction; only its forged-row assertions are reused (R5.1).
- **`removeItem` cleanup** of legacy `sso_audit_log` storage — forbidden by §1.2a rule (e) (defeats the artifact gate).
- **F17 CSV hardening / `_csvCell`** and **B6-2 login-edge drill** — separate directions.
- **Runtime F16 payload-echo test** (second first-construction polarity) — enforced statically via R2.6 instead; documented in R4.4.

## 5. Verification commands (post-implementation)

```bash
flutter test test/audit_log_service_test.dart test/audit_contract_guard_mutation_test.dart \
  test/audit_log_tab_test.dart test/snaplink_admin_api_test.dart \
  test/oidc_login_ring_isolation_test.dart test/service_contracts_test.dart
python cli.py harness          # b6_1b_gates re-pinned (R6.1/R6.2)
make build-prod && make release-artifact-check   # R6.3: sso_audit_log absent from build/web
```
