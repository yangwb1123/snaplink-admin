# B6-1b — Design: gated ring writer + lib/api debug-ring facade + admin census floor (module: lib/screens/admin)

> Companion design to `docs/proposals/b6-1b-lib-screens-admin-ring-debug-flag-spec.md` (requirements). This document is the concrete, implementable design: exact API changes, compatibility pins, failure modes, landing sequence, and a testable acceptance mapping. Every citation below was re-verified against the working tree on 2026-08-08 (HEAD `26567d5` + uncommitted B6-1a/B6-1b change set) by reading the files, running the suites, running the harness, and — new — running a **fresh** `make build-prod` + `make release-artifact-check`.
>
> Status: **design complete**. Two spec defects corrected (D2, D6) and one spec claim refuted empirically (D1/FM-4: the release-artifact greps are green only against a stale bundle; a fresh build from the current tree **fails** `make release-artifact-check`, and CI runs that gate on every push — `ci.yml:38-44`).

---

## 0. Verification ledger (evidence claims → verdicts)

| # | Claim (spec §2) | Verdict | Evidence |
|---|---|---|---|
| E1 | `_recordAudit` at `snaplink_admin_api.dart:81-90`; sole call site `:324` (`method != 'GET'` ∧ 2xx); `_fireDataChanged` `:325`; **ungated** | ✅ exact | `grep -n` → `:81`, `:323`, `:324`, `:325`; zero `kDebugMode`/`debugRingEnabled`/`ringCopyEnabled` tokens in `lib/api/` |
| E2 | Service `_entries`/`_maxEntries`/`'sso_audit_log'`; flag mechanism landed | ✅ exact | `:64/:65/:66`; `_ringCopyEnabled = kDebugMode` `:76`, getter `ringCopyEnabled` `:79`, setter `debugRingEnabled` `:82-84` (`if (!kDebugMode) return;` `:83`); `record` `:89-95`, `clear` `:120-124`, `count` `:125`, `_save` `:127-134`, `_load` `:136-145` |
| E3 | Liveness group `snaplink_admin_api_test.dart:327-413` (getItem `:351`, GET `:398-413`) | ✅ exact | group at `:327`, `:351`, `:398-413` confirmed |
| E4 | `oidc_login_ring_isolation_test.dart:16-28,104-136` | ✅ exact | docstring + seed/snapshot idiom confirmed |
| E5 | `oidc_login_audit_visibility_guard_test.dart:18-39` | ✅ exact | `@TestOn('vm')`, recursive `Directory` scan, literal-split needles confirmed |
| E6 | `implementation-gate.md:56` | ✅ exact | line 56 = console row, "localStorage ring 降级为调试记录" |
| E7 | Tab-test B6-1b group `:480-641`, flips `:481/:525-526/:577-578`, `_seedForgedRing` `:89-102`, T-12 joints `:294-371`, joint `:617-641` | ✅ exact | all confirmed by grep |
| E8 | Harness 22/25; 3 red = seam pins (`service_kdebug_count` 2≠6, `storage_initializer_pin` 0≠1, `guard_line_count` 1≠4) | ✅ exact | ran `python3 cli.py harness` → 22 passed / 3 failures, identical pins |
| E9 | Sole `record()` writer `:82`; constructions `:82` + tab `:33`; key in exactly one lib file | ✅ exact | grep census reproduced |
| E10 | Seam spec §4 walls call-site gating | ✅ exact | `b6-1b-lib-services-audit-ring-storage-seam-spec.md:114` |
| E7b | "31 tests green" | ✅ exact | ran both files → `All tests passed!` (+31) |
| — | Spec §6: "release-artifact greps … green and load-bearing" | ⚠️ **refuted for fresh builds** | see D1/FM-4: stale `build/web` (Aug 7, built from a more-advanced tree) was green; fresh build from current tree embeds `sso_audit_log` ×2 and `make release-artifact-check` **fails**; `ci.yml:38-44` runs build-prod → release-artifact-check → harness |
| — | Spec REQ-6.2 pin: "`debugRingEnabled` occurs exactly once in `lib/api` (the gate)" | ⚠️ **unsatisfiable** | `debugRingEnabled` is a **setter-only** member (`static set debugRingEnabled(bool)`, no getter). Reading it is a compile error. The readable getter is `ringCopyEnabled` → D2 |
| — | Spec AC-1.2: "getItem null" after `ring.clear()` clean-state | ⚠️ **wrong mechanism** | `clear()` → `_save()` → `setItem(key, '[]')`; key is `'[]'`, never null. Null requires `LocalStorage.removeItem` (exists in wrapper `:31` and memory impl) → D6 |

---

## 1. Design decisions

### D1 — Gate form at the writer call site: `kDebugMode && AuditLogService.ringCopyEnabled`

```dart
if (method != 'GET') {
  if (kDebugMode && AuditLogService.ringCopyEnabled) {
    _recordAudit(method, path, response.statusCode);
  }
  _fireDataChanged(method, path);
}
```

Why the `kDebugMode &&` operand in addition to the flag (spec REQ-2 allowed either, flag operand mandatory):

1. **Release bundle elimination is structural (const-branch folding).** `kDebugMode` is a per-build const; `false && _` folds and the whole `_recordAudit` → `record` → `_save` subtree becomes unreachable in release, so the `'sso_audit_log'` literal leaves the artifact. **Empirically validated by this design's fresh-build experiment**: a bundle built from a tree with this gate + facade re-point (the stale Aug 7 bundle) contains **zero** ring code (`sso_audit_log`: 0, service `debugPrint` string: 0), while the fresh build from the current ungated tree contains `sso_audit_log` ×2 and fails the artifact gate. The tab's existing comment at `:292` names this mechanism ("const-branch folding"); the design makes it true of the writer too.
2. The flag operand is preserved, so the off-branch stays behaviorally testable in a debug run (AC-3's "no untestable compile-time-only gate").
3. Runtime behavior is identical to flag-only gating in every mode: debug default `kDebugMode`=true → flag rules; release flag is const-false at the service.

Requires `import 'package:flutter/foundation.dart' show kDebugMode;` in `lib/api/snaplink_admin_api.dart` (file has no foundation import today). Harness-neutral: no pin counts `kDebugMode` in `lib/api`.

Rejected: flag-only gate (`if (AuditLogService.ringCopyEnabled)`) — leaves the write path reachable in the release bundle (runtime read, not folded), so a fresh `make build-prod` keeps embedding `sso_audit_log` and `make release-artifact-check` stays red (FM-4/FM-5).

### D2 — The gate reads `ringCopyEnabled`, not `debugRingEnabled` (spec correction)

`AuditLogService.debugRingEnabled` is a **setter-only** member in the landed service (`:82`, no getter). `if (AuditLogService.debugRingEnabled)` does not compile. The readable getter is `AuditLogService.ringCopyEnabled` (`:79`). Consequences:

- The writer gate, the facade getter, and the tab gate all read `ringCopyEnabled`.
- Spec REQ-6.2's token pin ("`debugRingEnabled` occurs exactly once in lib/api") is replaced by pins on `ringCopyEnabled` and `kDebugMode` (see AC-5). The `debugRingEnabled` setter remains the test flip site (tests only — `test/` is not under any census).

### D3 — Debug-ring facade: three statics on `SnaplinkAdminApi`

```dart
// lib/api/snaplink_admin_api.dart — place immediately above `_recordAudit` (~:80).
/// B6-1b debug-ring facade: read-only surface so `lib/screens/admin` keeps
/// zero `AuditLogService` tokens (AC-2 census floor). Delegates to the
/// service flag; the tab's `kDebugMode` gate makes the whole facade
/// unreachable in release (structural const-branch folding).
static bool get ringCopyEnabled => AuditLogService.ringCopyEnabled;
static int get debugRingCount => AuditLogService().count;
static void clearDebugRing() => AuditLogService().clear();
```

- Additive, static, mirrors the class's existing statics (`_resourceType` `:93`, `_decode` `:358`). No collision: verified no `count`/`clear`/`ringCopyEnabled` member exists on the class (only `clearCache`, distinct).
- Delegates **only** to stable public service members (`ringCopyEnabled`, `count`, `clear`) — never to `_storageEnabled` (the seam sibling's private wedge), so this direction composes with the seam in either landing order.
- The tab already imports `lib/api/snaplink_admin_api.dart` (`:7`) — zero new imports in the tab.

### D4 — `_fireDataChanged` stays ungated, and gets a behavioral pin

The UI-refresh event is not ring persistence; gating it would break the admin timeline's live refresh when the debug flag is off. Because no existing test distinguishes "flag off ⇒ no ring write" from "flag off ⇒ no event", add the pin to the AC-1 off-branch test: listen on `EventBus().on<DataChangedEvent>()` and expect exactly one event after the flag-off POST (see AC-1).

### D5 — Tab re-point: five sites, one deleted field, one deleted import

| Site (today) | Change |
|---|---|
| `:11` `import 'package:sso_admin/services/audit_log_service.dart';` | delete |
| `:33` `final _logService = AuditLogService();` | delete |
| `:241` `args: {'n': _logService.count}` | `args: {'n': SnaplinkAdminApi.debugRingCount}` |
| `:293` `if (kDebugMode && AuditLogService.ringCopyEnabled) ...[` | `if (kDebugMode && SnaplinkAdminApi.ringCopyEnabled) ...[` |
| `:300` `onPressed: _logService.count == 0` | `onPressed: SnaplinkAdminApi.debugRingCount == 0` |
| `:312` `{'n': _logService.count}` | `{'n': SnaplinkAdminApi.debugRingCount}` |
| `:318` `_logService.clear();` | `SnaplinkAdminApi.clearDebugRing();` |

`kDebugMode` line-count in the tab stays **1** (`:293`) → `checks/config.py:90` (`tab_kdebug_count = 1`) stays green. Strings, i18n keys, `_debugRingBadge` widget: untouched.

### D6 — AC-1 off-branch clean-state precondition: `removeItem`, not `clear()` (spec correction)

`ring.clear()` ends in `_save()` → `setItem(key, '[]')` — the key is `'[]'`, never null, so the "getItem null" assertion is unsatisfiable after `clear()`. The precondition is:

```dart
LocalStorage.removeItem('sso_audit_log');   // verified: wrapper :31 + memory impl
```

followed by a precondition sanity assertion (`isNull`). The seeded variant uses the byte-identical snapshot idiom from `oidc_login_ring_isolation_test.dart:104-136` (no null assertion needed there).

### D7 — Sequencing with the seam sibling (cross-spec conflict resolution)

Code-wise the two directions are disjoint (seam edits `lib/services/audit_log_service.dart` + its pins; this direction edits `lib/api`, `lib/screens/admin/audit_log_tab.dart`, tests). The conflict is textual: seam §4 (`:114`) mandates rejection of call-site gating. Resolution, per spec §4: amend the seam spec's §4 wall (design-gate record) **before** landing this direction's gate, then land. Either order composes; recommended seam-first as the spec states, but this direction is independently shippable — and is the one that makes CI's fresh-build artifact gate green (FM-4).

---

## 2. API changes (complete inventory)

**`lib/api/snaplink_admin_api.dart`**
1. New import: `import 'package:flutter/foundation.dart' show kDebugMode;`
2. New statics (D3): `ringCopyEnabled` getter, `debugRingCount` getter, `clearDebugRing()`.
3. Gate the `:324` invocation (D1). `_recordAudit` definition (`:81-90`), `AuditLogService.record`, `_fireDataChanged` (`:325`): unchanged.

**`lib/screens/admin/audit_log_tab.dart`** — D5 table. Net: `-1` import, `-1` field, `5` re-points, zero string/behavior change.

**`lib/services/audit_log_service.dart`** — **zero edits** (seam sibling's file; its 3 harness pins stay red until the seam lands, untouched by this direction).

**`test/snaplink_admin_api_test.dart`** — add (a) flag-off POST test (clean + seeded variants + DataChangedEvent pin), (b) flag-off GET test; optionally a defensive `setUp(() => AuditLogService.debugRingEnabled = true)` on the existing liveness group (mirrors `audit_log_tab_test.dart:481`). Existing ON tests (`:327-413`) preserved **verbatim** — they are the non-vacuousness half of AC-1.

**`test/audit_log_tab_test.dart`** — **zero changes**. The B6-1b group flips `AuditLogService.debugRingEnabled` (`:481/:525-526/:577-578`), which is exactly the flag the facade delegates to; assertions already pin the chip's behavior and the T-12 joints. (Spec §0's "may be re-pointed if the facade exposes a setter" is moot: the facade is getter-only by design, so the flip sites stay as-is.)

**New `test/admin_ring_census_guard_test.dart`** (AC-2) and **new `test/ring_writer_gate_guard_test.dart`** (AC-5) — see §6.

No wire-shape, i18n, or capability-gate changes.

---

## 3. Compatibility constraints (pins that must not move)

| # | Pin | Why / verification |
|---|---|---|
| C1 | `tab_kdebug_count == 1` (`checks/config.py:90`) | the tab's only `kDebugMode` remains `:293`; harness green |
| C2 | `_ringCopyEnabled = kDebugMode` initializer (`:91`) | service untouched; harness green |
| C3 | `AuditLogService().record(` in `lib/` == 1, at `snaplink_admin_api.dart:82` | sole writer definition; tab's test-side `_seedForgedRing` is in `test/`, not `lib/` |
| C4 | `sso_audit_log` literal in exactly one `lib/` file (the service) | harness key-residence pin green |
| C5 | Seam pins `service_kdebug_count`/`storage_initializer_pin`/`guard_line_count` remain red at **3** failures until the seam lands | this direction must not touch the service; harness result after landing: 22/25, identical 3 |
| C6 | Five B6-1b i18n keys unique; zh parity | harness green; no i18n edits |
| C7 | ON liveness tests `:327-413` semantics verbatim (query-free wire path, per-method +1, GET no-op) | AC-1 flag-ON half; `flutter test test/snaplink_admin_api_test.dart` |
| C8 | T-12 joints (`_seedForgedRing`, server-derived counts, zero forged-row rendering) | `test/audit_log_tab_test.dart` unchanged, green |
| C9 | `kDebugMode` line-count in `lib/api` == 1 (the gate); `ringCopyEnabled` line-count in `lib/api` == 2 (facade decl line + gate line) | AC-5 guard; drift fails the guard |
| C10 | Fresh-build artifact contract: `make build-prod && make release-artifact-check` green | **red today** (FM-4); must be green after landing; CI `ci.yml:38-44` runs it |
| C11 | Public API additions are additive only; no removal/rename of existing members; `_fireDataChanged` semantics unchanged | behavioral: flag-off POST still emits exactly one `DataChangedEvent` (AC-1) |
| C12 | Facade delegates only to stable public service members, never `_storageEnabled` | composes with seam in either order (D7) |

---

## 4. Failure modes (with mitigations)

| # | Failure mode | Trigger | Mitigation |
|---|---|---|---|
| FM-1 | Gate written against `AuditLogService.debugRingEnabled` (spec REQ-6.2's token) → **does not compile** (setter-only member) | implementer follows the spec's pin text literally | D2: gate reads `ringCopyEnabled`; AC-5 pins the corrected tokens |
| FM-2 | AC-1 off-branch assertions flaky from singleton state: `AuditLogService` is a process-wide singleton; earlier tests populate `_entries`/key | test isolation lapse | byte-identical snapshot idiom + explicit `removeItem` precondition + `addTearDown` restore of the flag (`:525-526` pattern); assertions are order-independent |
| FM-3 | "getItem null" assertion impossible after `clear()` (key = `'[]'`) | spec's clean-state mechanism | D6: `LocalStorage.removeItem('sso_audit_log')` + precondition sanity `isNull` |
| FM-4 | **Release-artifact greps vacuously green** (spec §6 claim): `build/web` was stale (Aug 7 build from a more-advanced tree); fresh build from the current tree embeds `sso_audit_log` ×2 and `make release-artifact-check` **fails**; CI runs it on every push (`ci.yml:38-44`) | anyone relying on the current local green | This design's gate+facade restores structural bundle elimination; acceptance includes a **fresh** build + artifact check (AC-6); never trust artifact greps without a fresh `make build-prod` |
| FM-5 | Flag-only gate (`if (AuditLogService.ringCopyEnabled)`) — runtime read, not const-folded → write path + key literal stay in the release bundle → fresh artifact check red | "simplification" during implementation | D1 mandates the `kDebugMode &&` operand; AC-5 pins `kDebugMode` line-count == 1 in `lib/api` |
| FM-6 | Flag operand dropped → `if (kDebugMode)`-only gate → off-branch untestable in debug (AC-3 violation); test flips have no effect | misreading REQ-2 | AC-5 adjacency pin requires `ringCopyEnabled` in the gate line; AC-1 off-branch test fails against a dead gate (non-vacuousness) |
| FM-7 | Gate moved into `_recordAudit`'s definition → invocation stays unconditional → AC-1 off-branch fails; violates seam C3 re-scope ("`_recordAudit` definition unchanged") | refactor | AC-5 pins: exactly one `_recordAudit(` **invocation** line in `lib/api`, immediately after the gate line |
| FM-8 | `_fireDataChanged` accidentally gated → admin timeline stops refreshing when the flag is off | sloppy merge of the two `if`s | AC-1 off-branch asserts exactly one `DataChangedEvent`; AC-5 adjacency pin: the line before `_fireDataChanged(method, path);` is `}` |
| FM-9 | Facade drift: rename `debugRingCount`/`clearDebugRing`/`ringCopyEnabled` → census pins go stale or AC-2 passes vacuously if the badge is deleted entirely | refactor/removal | AC-2 guard also asserts each facade member is referenced from the tab (≥1); AC-3 behavioral tests pin the chip rendering; renaming forces a guard edit (intentional-change path) |
| FM-10 | Flag left false after tests → later suites in the same run see ring off (ON liveness silently passing without writes) | missing tearDown | `addTearDown(() => AuditLogService.debugRingEnabled = true)` on every flip test; defensive `setUp` on the liveness group (D3 note) |
| FM-11 | In-tree contradiction with seam §4 (call-site gating "must be rejected") | landing this direction without the docs step | D7: amend seam §4 wall first (design-gate record) |
| FM-12 | Seam lands first and changes service internals (`_storageEnabled`); facade accidentally couples to it | later composition | C12: facade delegates only to `ringCopyEnabled`/`count`/`clear` — all public, seam-stable |

---

## 5. Migration steps (landing sequence)

1. **Docs (prerequisite commit).** Amend `docs/proposals/b6-1b-lib-services-audit-ring-storage-seam-spec.md` §4 to record the design-gate override: call-site gating is required by AC-1/AC-5 of the sibling `lib/screens/admin` spec; C3 re-scoped to the service public API + `_recordAudit` definition. Removes the in-tree contradiction (FM-11).
2. **Code (one atomic commit — REQ-2 + REQ-4 together).** `lib/api/snaplink_admin_api.dart` (D1 gate + D3 facade + `show kDebugMode` import) and `lib/screens/admin/audit_log_tab.dart` (D5 re-points). Any subset leaves either the census (AC-2) red or the tab broken, so do not split.
3. **Tests (same commit or immediate follow-up).** AC-1 off-branch tests + AC-2 census guard + AC-5 writer guard (sketches in §6).
4. **Verification battery (in order):**
   - `flutter test test/snaplink_admin_api_test.dart test/audit_log_tab_test.dart test/admin_ring_census_guard_test.dart test/ring_writer_gate_guard_test.dart` — all green (≥34 tests: existing 31 + new).
   - `python3 cli.py harness` — 22 passed / 3 failed, the 3 failures byte-identical to today's (seam pins, C5).
   - `make build-prod && make release-artifact-check` — **must pass on the fresh bundle** (currently red; AC-6). This is the empirical regression the design fixes.
   - `make analyze` — clean (new import + statics analyzed).
5. **CI.** `ci.yml:38-44` already runs exactly steps build-prod → release-artifact-check → harness; no workflow change needed. Post-landing CI is the standing guard for FM-4.
6. **Follow-up (seam sibling).** Land the storage seam; its three harness pins turn green; the two directions then compose (D7). Rebuild `build/web` on landing so the local artifact is not stale again.

---

## 6. Testable acceptance mapping

### AC-1 — Writer flag on/off (REQ-1, REQ-2) — `test/snaplink_admin_api_test.dart`

**ON (existing, preserved verbatim):** group `:327-413` — POST/PUT/DELETE each append exactly one entry (`count + 1`) and persist one more element under `getItem('sso_audit_log')` with the exact query-free wire path (`:332-397`); GET no-op (`:398-413`). Non-vacuousness half.

**OFF (new):**
```dart
test('flag OFF: 2xx non-GET persists nothing; refresh event still fires', () async {
  AuditLogService.debugRingEnabled = false;
  addTearDown(() => AuditLogService.debugRingEnabled = true);
  LocalStorage.removeItem('sso_audit_log');                    // D6 precondition
  final ring = AuditLogService();
  addTearDown(ring.clear);
  final events = <DataChangedEvent>[];
  final sub = EventBus().on<DataChangedEvent>().listen(events.add);
  addTearDown(sub.cancel);

  expect(LocalStorage.getItem('sso_audit_log'), isNull, reason: 'precondition');
  final api = SnaplinkAdminApi(
    baseUrl: 'https://sso.example.test',
    accessToken: 'admin-token',
    httpClient: MockClient((_) async => http.Response('{"status":"ok"}', 200)),
  );
  await api.post('/api/v1/admin/clients', {'operator': 'ada@example.test'});

  expect(ring.count, 0, reason: 'flag off ⇒ no in-memory append');
  expect(LocalStorage.getItem('sso_audit_log'), isNull,
      reason: 'flag off ⇒ no persist (FM-3)');
  expect(events, hasLength(1), reason: '_fireDataChanged stays ungated (FM-8)');

  // Seeded variant — isolation snapshot idiom (E4):
  ring.record(AuditEntry(timestamp: DateTime.now(), method: 'POST',
      path: '/api/v1/admin/seeded', statusCode: 200, label: 'seed'));
  final storedBefore = LocalStorage.getItem('sso_audit_log');
  final countBefore = ring.count;
  await api.post('/api/v1/admin/clients', {'operator': 'ada@example.test'});
  expect(ring.count, countBefore, reason: 'byte-identical count');
  expect(LocalStorage.getItem('sso_audit_log'), storedBefore,
      reason: 'byte-identical stored value');
});

test('flag OFF: GET still never records', () async { /* same harness, api.get,
    count + stored byte-identical (runs under flag=false; the ON half :398-413
    covers flag=true) */ });
```
New imports in the test file: `package:sso_admin/services/event_bus.dart` (for `EventBus`/`DataChangedEvent`). `AuditEntry`, `LocalStorage`, `AuditLogService` already imported.

### AC-2 — Census floor for `lib/screens/admin` (REQ-3, REQ-4) — new `test/admin_ring_census_guard_test.dart`

`@TestOn('vm')`; recursive `Directory('lib/screens/admin')` scan; literal-split needles `'AuditLog' 'Service'` / `'audit_log_' 'service'` / `'sso_audit_' 'log'`; `expect(offenders, isEmpty)` (verbatim shape of `oidc_login_audit_visibility_guard_test.dart:18-39`). **Anti-vacuity clause** (FM-9): the tab must reference each facade member — `SnaplinkAdminApi.ringCopyEnabled` ≥ 1, `SnaplinkAdminApi.debugRingCount` ≥ 3 (`:241/:300/:312`), `SnaplinkAdminApi.clearDebugRing()` ≥ 1 — so deleting the debug surface trips the guard. Harness `tab_kdebug_count == 1` stays green (C1).

### AC-3 — Chip renders iff flag on (REQ-1, REQ-4) — `test/audit_log_tab_test.dart` (zero changes)

B6-1b group `:480-641` pins both states, zh parity, and the ring=1 vs rows=0 vs decoy=999 joint. Flip sites `:481/:525-526/:577-578` already target `AuditLogService.debugRingEnabled` — the exact flag the facade delegates to (D3), so no re-pointing is needed. Gate is never `kDebugMode`-only (FM-6): the widget reads `kDebugMode && SnaplinkAdminApi.ringCopyEnabled`.

### AC-4 — T-12 joint preserved (REQ-5) — `test/audit_log_tab_test.dart`

Unchanged: `_seedForgedRing` `:89-102`; AC-3a/b/c `:294-371`; AC-1 server-read `:108-145`; joint `:617-641`. Flag restored in tearDown, so the forgery fixture is undisturbed (FM-10).

### AC-5 — Writer census + adjacency (REQ-6) — new `test/ring_writer_gate_guard_test.dart`

`@TestOn('vm')`, `dart:io` scans (same style as AC-2 guard):
1. `AuditLogService().record(` in `lib/` == 1, hit file == `lib/api/snaplink_admin_api.dart` (C3).
2. `_recordAudit(method, path, response.statusCode);` in `lib/api` == 1, and its immediately preceding line contains `kDebugMode && AuditLogService.ringCopyEnabled` — invocation gated at the call site, not inside the definition (FM-7).
3. `kDebugMode` line-count in `lib/api` == 1; `ringCopyEnabled` line-count in `lib/api` == 2 (facade decl + gate) (C9, FM-5).
4. The line immediately preceding `_fireDataChanged(method, path);` is `}` — the refresh event is outside the gate (FM-8).
5. Non-vacuousness is carried by AC-1's off-branch behavioral test (a dead/relocated gate fails it).

### AC-6 (new, this design) — Fresh-build release artifact contract

`make build-prod && make release-artifact-check` pass on a **fresh** bundle: `sso_audit_log`, its base64 masks, and the old ring copy absent from `build/web/` (Makefile `:38-48`; `checks/b6_1b_gates.py` artifact section). **Red on the current tree** (FM-4, empirically reproduced: fresh build → `sso_audit_log` ×2, FAIL); green after D1/D3 land; standing guard = `ci.yml:38-44`.

### Summary table

| AC | Requirement | Pin | Files | Verify |
|---|---|---|---|---|
| AC-1 | REQ-1/REQ-2 | ON: `:332-397` verbatim; OFF: count 0 + key null (clean), byte-identical (seeded), 1 event; GET both modes | `test/snaplink_admin_api_test.dart` | `flutter test test/snaplink_admin_api_test.dart` |
| AC-2 | REQ-3/REQ-4 | Census guard + facade-reference anti-vacuity; `tab_kdebug_count == 1` | `test/admin_ring_census_guard_test.dart`; tab; api | `flutter test test/admin_ring_census_guard_test.dart`; `python3 cli.py harness` |
| AC-3 | REQ-1/REQ-4 | Chip on/off both asserted, zh, joint — unchanged | `test/audit_log_tab_test.dart` | `flutter test test/audit_log_tab_test.dart` |
| AC-4 | REQ-5 | T-12 joints unchanged | `test/audit_log_tab_test.dart` | `flutter test test/audit_log_tab_test.dart` |
| AC-5 | REQ-6 | record==1; gated invocation adjacency; kDebugMode==1, ringCopyEnabled==2 in lib/api; `}` before `_fireDataChanged` | `test/ring_writer_gate_guard_test.dart` | `flutter test test/ring_writer_gate_guard_test.dart` |
| AC-6 | D1/D3 | Fresh bundle: ring literal + masks absent | Makefile `:38-48`; CI `ci.yml:38-44` | `make build-prod && make release-artifact-check` |

**Expected final state:** all four test files green (existing 31 + ~5 new); `python3 cli.py harness` 22/25 with the 3 failures byte-identical to today's (seam's, untouched); fresh `make release-artifact-check` green (currently red); `make analyze` clean.
