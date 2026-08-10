# B6-1 Requirements Specification — device-module isolation floor: automated zero-ring guard + no-write widget pin

Module: `lib/screens/device` (analysis bucket `docs/auto/analyses/lib-screens-device-fb030ae1.json`) · Direction: B6-1 (re-selection) · Value: 8 · Risk reduction: 7 · Effort: 3 · Confidence: 8
Status: requirements (re-run after `docs/auto/runs/pin-the-b6-1-isolation-floor-for-the-device-modu-215ff671/pipeline.yaml` FAILED at this stage — `DECISIONS.md`: requirements FAIL, agent exited 1, no artifacts produced; the direction is re-selected in `docs/auto/runs/b6-1-isolation-floor-for-the-device-module-autom-6bf31d3c/pipeline.yaml`)
Sibling guard: `test/oidc_login_audit_visibility_guard_test.dart` (AC-2 pattern for `lib/screens/oidc_login`, REQ-1 of the oidc_login spec) — this spec extends the same isolation floor to `lib/screens/device` and adds the widget-level no-write pin the oidc_login lens does not have.

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD. All hold, with one span-precision note and three module-scope facts:

| Direction citation | Verification result |
|---|---|
| `lib/screens/device/device_verify_screen.dart:106-150` — `_checkCode` with zero audit side effects | **Exact.** Method declaration at `:106`; GET `check` at `:135-142` (via `_api.check`), status switch at `:144-155`, catch/finally at `:157-169`; no `AuditLogService` / storage interaction anywhere in the method. |
| `:198-296` — `_verify` approve/deny decision region | **Span-precision note.** The region is `_confirm` `:194-215` (dialog) + `_verify` `:217-270` (declaration at `:217`, not `:198`); the 200 / 401 / 404+501 / else branches are `:243-266`. `:296` is inside `build` (column children) — the cited span is the loose "decision region" and its endpoints are correct for intent. No audit side effects in any branch. |
| `:248-249` — 401 → `Session.clear()` | **Exact.** `:248` `} else if (response.statusCode == 401) {`, `:249` `Session.clear();`. |
| `:172-181` — `_redirectToLogin` | **Exact.** Declaration `:172`, body `:173-180` (`/login/?redirect=/device/verify…` via `BrowserNavigation.replaceLocation`), close `:181`. |
| `lib/services/audit_log_service.dart:66` — `_storageKey = 'sso_audit_log'` ring | **Exact.** `:66`; ring persistence writes `LocalStorage.setItem(_storageKey, …)` at `:130` (`_save`), read at `:138` (`_load`); `record()` `:89-95` inserts + saves; `count` getter `:119`. Demotion state already landed: `ringCopyEnabled` debug-only surface flag `:69-80` (B6-1b). |
| `lib/api/snaplink_admin_api.dart:81-85` — sole ring writer | **Exact.** `:81` `void _recordAudit(String method, String path, int statusCode) {`, `:82` `AuditLogService().record(`, close `:85`. Invoked `:322-324`: `:322` `if (response.statusCode >= 200 && response.statusCode < 300) {`, `:323` `if (method != 'GET') {`, `:324` `_recordAudit(method, path, response.statusCode);`. Repo-wide: no other `LocalStorage.setItem`/`AuditLogService().record` caller writes the ring (other `LocalStorage.setItem` sites — `app_settings.dart:175`, `cross_tab_sync.dart:54`, `list_state_manager.dart:21`, `trusted_device_token.dart:17` — are unrelated keys). |
| `test/oidc_login_audit_visibility_guard_test.dart` — the AC-2 guard pattern to mirror | **Exact.** `@TestOn('vm')`, `dart:io`; `Directory('lib/screens/oidc_login').listSync(recursive: true)` over `*.dart`; literal-split needles `['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log']`; zero-hit `expect` with the ring-is-debug-only reason; doc comment carries the CI grep form. The file is self-scan-safe by construction (literal split survives a scan-root widening to `test/`). |
| `test/entry_ux_test.dart:114-132` — reusable `DeviceVerifyScreen` pump pattern | **Exact.** `:114-124` `pumpWidget(MaterialApp(home: DeviceVerifyScreen(api: MockClient-backed, accessTokenProvider: () => 'user-token')))` after `_useNarrowViewport`; `:126-127` `enterText` + `tap('Check code')`; `:128` `pumpAndSettle`; helpers `_useNarrowViewport` / `_filledButton` at `:240-245`. |
| `test/entry_ux_test.dart:169-226` — B6-2 redirect-leg pins already landed | **Exact.** Comment `:169-176` (REQ-1, `SessionStorage` memory-backed on VM), `group('B6-2 device-entry redirect leg (REQ-1)')` `:177-227`, two no-session redirect tests (routeUri with/without `user_code`). |
| `test/device_verify_api_test.dart:31-50` — device wire pinned to `{user_code, approve}` | **Exact.** Test `'approves a device code with the current bearer'` `:31-50`: `expect(jsonDecode(request.body), {'user_code': 'WXYZ-1234', 'approve': true})` — no `client_id`, no tenant key. Wire producer `lib/api/device_verify_api.dart:56-63` (`verify` POST body). |
| `docs/auto/runs/pin-the-b6-1-isolation-floor-for-the-device-modu-215ff671/pipeline.yaml` — prior requirements-stage failure | **Confirmed.** Stages list shows `requirements` output `…/artifacts/requirements-10762e10/requirements.md`; `DECISIONS.md` records `2026-08-07 13:12:43 — stage 'requirements' — FAIL` (agent exited 1); no artifacts were produced. The direction must be re-run (this spec). |
| `docs/campaigns/implementation-gate.md:56` — ring demotion, server-read-only display, forgery ban | **Exact.** Row 1 (console, B6-1): "读路径接入（F-06）：审计页调 sink 读 API（tenant_id + trace_id 经 BFF）；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5". G7(B6) row `:79`: "B6-1..2 \| T-12 联合、console 服务端记录". |
| `[proposed]` — server-side `device.*` event types (e.g. `device.approve`/`device.deny`) | **Confirmed unassertable from this repo — with the D2 scope correction.** `grep -rn "device\.approve\|device\.deny\|device\.check" lib/ test/ tests/` → **0 hits** (exit 1, re-executed at HEAD). The unscoped form (incl. `docs/proposals/`) is **self-defeating**: it hits this spec's own `device.approve`/`device.deny` literals (2 hits, :27/:94). They belong to the IdP/sink edge contract (B1-5/B4-5) and are assertable only through the B6-1a read client once it lands. |

Baseline executed at HEAD (this run):

- `flutter test test/device_verify_api_test.dart` → **4/4 green** (wire pin `:31-50` included; **D1/M9**: the direction's "5/5" was a count error — the file has four tests: normalizes the code, checks the pending state, approves, times out).
- `flutter test test/oidc_login_audit_visibility_guard_test.dart test/entry_ux_test.dart` → **8/8 green** (guard + 7 entry_ux tests, including the B6-2 redirect-leg group).
- `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/device/` → **exit 1** (zero hits today — the floor is real, unguarded).

Module-scope facts that shape the requirements:

1. **The module is in the exact required shape today.** `lib/screens/device/` (3 files: `device_verify_screen.dart`, `device_verify_api.dart` re-export, `device_verify_widgets.dart`) has zero `AuditLogService` / `audit_log_service` / `sso_audit_log` references, and all four decision paths (`_checkCode`, `_verify` approve/deny, 401 → `Session.clear()`, `_redirectToLogin`) have zero audit side effects — but unlike `lib/screens/oidc_login`, **no automated guard pins it**.
2. **The ring has exactly one writer and the demotion is partially landed.** Sole writer is `lib/api/snaplink_admin_api.dart:82` (`:81-85`, invoked at `:324` for non-GET 2xx); persistence under `'sso_audit_log'` at `audit_log_service.dart:130`; B6-1b `ringCopyEnabled` (`:69-80`) already const-folds the debug ring-copy surface out of release builds.
3. **The device wire is already pinned.** `device_verify_api_test.dart:33-50` pins `POST /device/verify` body `{user_code, approve}` with `Bearer` auth and no `client_id`/tenant; `lib/api/device_verify_api.dart:56-63` is the producer. The no-write widget pin (REQ-2) re-asserts this at the screen level with a ring-untouched check.
4. **Test harness facts (reused, not invented):** `LocalStorage` is memory-backed on VM (`lib/services/local_storage.dart` conditional import — `local_storage_memory.dart` on VM, `window.localStorage` on web); `SessionStorage` likewise memory-backed (noted in `entry_ux_test.dart:169-176`); ring liveness + no-write assertion patterns (`ring.count`, `LocalStorage.getItem('sso_audit_log')` before/after) already exist in `test/snaplink_admin_api_test.dart:331-413`.

---

## 2. Scope

**In scope**

- One new test file: `test/device_audit_visibility_guard_test.dart` — verbatim mirror of `test/oidc_login_audit_visibility_guard_test.dart` (same three literal-split needles, `@TestOn('vm')` recursive `dart:io` scan) against `lib/screens/device/` (REQ-1).
- The widget no-write pin: a new `B6-1` group in `test/entry_ux_test.dart`, reusing the landed pump pattern (`:114-132`), helpers (`:240-245`) and the B6-2 group's conventions (`:169-176` comment: `SessionStorage` memory-backed on VM, `Session.clear()` in `setUp`) — approve 200, deny 200, 401-expiry flows with zero ring write (REQ-2).
- The CI/gate grep form documented in the guard file's doc comment (REQ-1).
- The T-12 joint framing: forged entries cannot be evidence; the server-fed timeline (B6-1a) is the only legitimate channel (REQ-3).

**Out of scope (explicitly not changed)**

- **Zero `lib/` diff from this change set.** No production file changes anywhere in B6-1; `lib/screens/device/**` untouched. The guard and pin are test-only. The zero-delta check is **change-set-scoped** (REQ-4): sibling in-flight change sets (B6-1a server-read timeline, B6-1b demotion flag, i18n sources) legitimately own unrelated `lib/` diffs at HEAD, so whole-tree `git diff lib/` emptiness is not this spec's gate.
- **No server-side `device.*` event types.** They are `[proposed]` at the IdP/sink edge (B1-5/B4-5); zero in-repo hits; never fabricated, emitted, or asserted into existence by this change set — assertable only through the B6-1a read client once it lands (REQ-3).
- **B6-1a's rendering half** (server-read audit timeline in `lib/screens/admin`, `test/audit_log_tab_test.dart` joint): a dependency for the T-12 joint, not implemented here.
- **The ring itself** (`lib/services/audit_log_service.dart`, `lib/api/snaplink_admin_api.dart`): no behavior change; demotion already landed (B6-1b).

---

## 3. Requirements

### REQ-1 — Zero-ring static guard: `test/device_audit_visibility_guard_test.dart` (isolation floor, AC-2 pattern)

New file mirroring `test/oidc_login_audit_visibility_guard_test.dart` **verbatim in pattern**:

1. `@TestOn('vm')` library annotation; `dart:io` import.
2. `const moduleDir = 'lib/screens/device';` — the only difference from the oidc_login guard is the scan root.
3. Banned needles, **literal-split** so the guard can never trip its own scan and survives a future widening of the scan root to `test/`: `'AuditLog' 'Service'`, `'audit_log_' 'service'`, `'sso_audit_' 'log'`.
4. Recursive scan: `Directory(moduleDir).listSync(recursive: true)`, `*.dart` files only; any needle hit collected per file; `expect(offenders, isEmpty, reason: …)` with the same ring-is-debug-only reason text adapted to the device module ("localStorage ring is debug-only; device decisions are evidenced exclusively through the server-fed timeline").
5. Doc comment carries the CI/gate grep form (must exit 1) with the needles **adjacent-quoted** so the documented command stays copy-pasteable while the file text holds no contiguous needle: `grep -rn "AuditLog""Service\|audit_log_""service\|sso_audit_""log" lib/screens/device/`. The `reason:` string applies the same discipline (adjacent literals). **No contiguous banned needle may appear anywhere in the guard file** — the oidc_login mirror's original reason/grep-form lines carried raw needles and would self-trip under a scan-root widening to `test/` (self-scan leak fix, mirrored here).

**Testable:** `flutter test test/device_audit_visibility_guard_test.dart` green; `grep -rn 'AuditLogService\|audit_log_service\|sso_audit_log' lib/screens/device/` → exit 1; `grep -n "'AuditLog' 'Service'" test/device_audit_visibility_guard_test.dart` hits (needle list present and literal-split); `grep -nE 'AuditLogService|audit_log_service|sso_audit_log' test/device_audit_visibility_guard_test.dart` → **exit 1** (no contiguous needle anywhere in the guard file — full self-scan-safety).

### REQ-2 — Widget no-write pin: approve / deny / 401-expiry complete with zero ring write

New `group('B6-1 device decisions stay out of the debug ring (REQ-1)')` in `test/entry_ux_test.dart`, reusing the landed `DeviceVerifyScreen` pump pattern (`:114-132`), `_useNarrowViewport` / `_filledButton` helpers (`:240-245`), and the B6-2 group's hermeticity conventions (`Session.clear()` + ring reset in `setUp`; `SessionStorage`/`LocalStorage` are memory-backed on VM):

1. **Fixture:** `MockClient` where `GET /device/verify?check=…` returns the pending preview shape from `:100-108` (`{'status': 'pending', 'client_name': …, 'scopes': […]}`), and `POST /device/verify` returns 200 (`'{}'`) for the approve/deny tests and 401 (`'{}'`) for the expiry test; `accessTokenProvider: () => 'user-token'`. In `setUp`: `BrowserNavigation.resetForTest()`, `Session.clear()`, then the ring reset in **`clear()` → `LocalStorage.removeItem('sso_audit_' 'log')` order** (hermetic singleton; **D8/M7**: `clear()` alone persists `'[]'` — `audit_log_service.dart:120-134` `clear()` → `_save()` — which breaks the `getItem == null` before-assertion, and a tearDown-only `removeItem` would leak `'[]'` into the next test under randomized ordering; `removeItem` (`local_storage_memory.dart:9`) drops the key entirely). `addTearDown` runs the same two steps with `removeItem()` executing **last** — package:test runs tear-downs in reverse declaration order (LIFO), so register `removeItem` before `clear` — leaving storage key-absent at the start and end of every test.
2. **Approve flow:** enter code → `Check code` → `pumpAndSettle` → tap the approval button (scoped `FilledButton` finder, per `_filledButton`) → confirm dialog → confirm → assert `'Device approved'` (i18n `deviceApproved`); assert the captured `POST /device/verify` request body is exactly `{'user_code': …, 'approve': true}` with **no `client_id` and no tenant key** (screen-level mirror of `device_verify_api_test.dart:31-50`).
3. **Deny flow:** same, deny path → `'Device denied'`; same body assertions with `'approve': false`.
4. **401-expiry flow:** verify returns 401 → `Session.clear()` (`device_verify_screen.dart:249`) → assert `'Your sign-in expired'` (i18n `signInExpired`) and the sign-in-again button render, `Session.read()` is null; `_redirectToLogin` (`:172-181`) is NOT invoked by the 401 branch (the redirect is only offered as the `signInAgain` button — pinned by the B6-2 group for the no-session entry leg).
5. **Ring-untouched assertion for every flow:** `LocalStorage.getItem('sso_audit_' 'log')` is null before and after, and `AuditLogService().count == 0` throughout. The key literal in the test is itself **literal-split** (`'sso_audit_' 'log'`) so a future widening of the guard's scan root to `test/` cannot flag the pin (mirrors REQ-1's self-safety rule).
6. **Liveness contrast (anti-vacuous):** the no-write pin is only meaningful while the ring is provably live — ring liveness for 2xx non-GET mutations is already pinned by `test/snaplink_admin_api_test.dart:331-413` (unchanged; `AuditLogService` is a singleton, so the same `count` the liveness test exercises is the one REQ-2 asserts stays 0).

**Testable:** `flutter test test/entry_ux_test.dart` green (new group + all existing groups, B6-2 included); `grep -n "device decisions stay out of the debug ring" test/entry_ux_test.dart` hits; `grep -n "sso_audit_" test/entry_ux_test.dart` shows only a split literal.

### REQ-3 — T-12 joint: forged entries can never be device evidence; the server-fed timeline is the only channel

1. **Forgery ban:** with the ring demoted to debug-only recording (`implementation-gate.md:56` row 1; B6-1b `ringCopyEnabled` flag, `audit_log_service.dart:69-80`), a devtools-forged `sso_audit_log` entry must never render as evidence in the audit timeline — display truth is the server response only. The rendering half of this joint is B6-1a's change set (`lib/screens/admin` audit timeline; debug-ring surface tests at `test/audit_log_tab_test.dart:481-577`); this module's enforceable half is REQ-1 (zero references — no import path into the ring exists) + REQ-2 (zero writes on all decision paths).
2. **The device module renders no audit UI of its own** and has no emission path: `lib/screens/device/` contains no audit widgets, no `AuditLogService` construction, and no `device.*` event emission (REQ-1 pins this).
3. **`[proposed]` device decision rows:** server-side `device.approve` / `device.deny` event types are the IdP/sink edge contract (B1-5/B4-5); zero in-repo hits (verified); they are assertable only through the B6-1a read client once it lands — this change set neither fabricates them nor asserts on them.

**Testable:** `grep -rn "device\.approve\|device\.deny\|device\.check" lib/ test/ tests/` → exit 1 (**D2 scope**: `docs/proposals/` excluded — the durable spec itself carries the `device.*` literals, 2 hits verified, so the unscoped form self-defeats); REQ-1 + REQ-2 green; the server-read rendering joint remains tracked in the B6-1a spec/change set (dependency recorded in §5).

### REQ-4 — No-regression / zero-delta floor

1. The B6-1 change set is test-only by construction: `test/device_audit_visibility_guard_test.dart` (new) + `test/entry_ux_test.dart` (one new group) — **no `lib/` path in the change set**. The zero-delta check is **change-set-scoped** (D-B): whole-tree `git diff lib/` is legitimately non-empty at HEAD because sibling in-flight change sets (B6-1a server-read timeline, B6-1b demotion flag, i18n sources) own unrelated `lib/` diffs — an "empty `git diff --stat lib/`" assertion would be false today and cannot gate this change set.
2. Existing suites stay green unchanged: `test/device_verify_api_test.dart` (wire pin), `test/oidc_login_audit_visibility_guard_test.dart` (mirror source), `test/entry_ux_test.dart` (all existing groups, B6-2 included).
3. The direction's acceptance command runs clean: `flutter test test/device_audit_visibility_guard_test.dart test/device_verify_api_test.dart`.

**Testable:** `git diff HEAD --stat -- lib/screens/device/` → empty (the guarded module is untouched); the B6-1 change-set manifest is exactly the two test files above — no `lib/` path (verified per B6-1 commit by `git diff HEAD --name-only` while uncommitted / by manifest review at commit time); `flutter test test/device_audit_visibility_guard_test.dart test/device_verify_api_test.dart` green; `flutter test test/entry_ux_test.dart test/oidc_login_audit_visibility_guard_test.dart` green.

---

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

| # | Supplied check | Testable form |
|---|---|---|
| AC-1 | New `test/device_audit_visibility_guard_test.dart` mirrors the oidc_login guard (same three literal-split needles, `@TestOn('vm')` scan of `lib/screens/device/`) — green | REQ-1: `flutter test test/device_audit_visibility_guard_test.dart` green; file contains `@TestOn('vm')`, `Directory('lib/screens/device')`, and the split needles `'AuditLog' 'Service'` / `'audit_log_' 'service'` / `'sso_audit_' 'log'` (grep-verifiable) |
| AC-2 | `grep -rn 'AuditLogService\|audit_log_service\|sso_audit_log' lib/screens/device/` exits 1 (CI/gate form) | REQ-1 §5: run the command — exit 1 (verified at HEAD today; stays 1 via REQ-1's scan) |
| AC-3 | Widget pin: approve/deny/401-expiry flows complete with no ring write (MockClient-driven, no `'sso_audit_log'` storage interaction) | REQ-2: `flutter test test/entry_ux_test.dart` green; the B6-1 group asserts `LocalStorage.getItem('sso_audit_' 'log') == null` and `AuditLogService().count == 0` after each of the three flows, plus `POST /device/verify` body `{user_code, approve}` with no `client_id`/tenant |
| AC-4 | With the ring demoted, devtools-forged device decisions cannot appear as evidence — the only legitimate channel is the server-fed timeline (B6-1a dependency) | REQ-3: REQ-1+REQ-2 green (forgery-proof floor); `grep -rn "device\.approve\|device\.deny\|device\.check" lib/ test/ tests/` → exit 1 (D2-scoped); rendering joint tracked in B6-1a's change set (dependency recorded in §5) |
| AC-5 | `flutter test test/device_audit_visibility_guard_test.dart + test/device_verify_api_test.dart` green | REQ-1 + REQ-4: run the command — green (device_verify_api_test 4/4 verified at HEAD; count correction D1/M9) |

Gate relationship: AC-1/AC-2 are the static floor (mirror of the oidc_login guard), AC-3 is the behavioral floor (screen-level, anti-vacuous via the liveness contrast), AC-4 is the T-12 joint conclusion (enforced by AC-1..AC-3 here; rendering half lands with B6-1a), AC-5 is the unconditional no-regression gate. All five are executable as written. Joint gate (G7(B6), `implementation-gate.md`): count-asserted under `-r expanded` — guard+widget **+16** (device guard 1 + oidc guard 1 + entry_ux 10 incl. the B6-2 group + device_verify_api 4), liveness **+15** (`snaplink_admin_api_test.dart`), API **+4** (`device_verify_api_test.dart`); the pin and liveness suites run in the **same gate** so silent `@TestOn('vm')` skips fail CI (M5/M10).

---

## 5. Dependencies and constraints

- **B6-1a** (`lib/screens/admin` server-read timeline; `b6-1a-lib-screens-admin-auditlogtab-server-read-spec.md`): the rendering half of AC-4/T-12 — dependency, not implemented here; this change set only guarantees the device module cannot forge or emit.
- **B6-1b** (ring demotion, already landed): `ringCopyEnabled` flag `audit_log_service.dart:69-80`; the demotion context AC-4 rests on.
- **B1-5 / B4-5**: server-side `device.*` event types at the sink/IdP edge — `[proposed]`, out of repo, assertable only via the B6-1a read client.
- **T-12 joint gate** (`implementation-gate.md:56` row 1, `:79` G7(B6)): the acceptance this floor serves; self-audit row + forgery ban are joint with B6-1a.
- **Constraints:** zero `lib/` diff from this change set (change-set-scoped, REQ-4); test-only change set; guard file self-scan-safe (literal-split needles in the needle list, the reason string, and the doc-comment grep form — no contiguous needle anywhere in the file); widget-pin key literal also split; no new event names, no emission code, no i18n delta; no changes to `audit_log_service.dart` / `snaplink_admin_api.dart`.

## 6. Risks and rollback

- **Future "record device decisions" change silently writes the ring after the demotion** (the exact failure this floor prevents): REQ-1's grep/scan + REQ-2's count/key assertions fail loudly at CI; the change cannot land green.
- **Vacuous no-write pin** (ring dead ⇒ pin passes trivially): countered by the liveness contrast — `snaplink_admin_api_test.dart:331-413` proves 2xx non-GET mutations do write the ring, and both tests exercise the same singleton `count`.
- **Guard tripping its own scan** (needles unsplit) or **widget pin flagged by a widened scan root**: both literals are split by construction; the guard's own test is the proof.
- **Widget-test flakiness** (two `'Approve'` texts — dialog title vs. button): scoped `FilledButton` finder (`_filledButton` helper, `entry_ux_test.dart:244-245`); `pumpAndSettle` after the check call per the landed pattern `:128`.
- **Scope creep** (fabricating `device.*` events, pre-implementing B6-1a rendering): explicitly out of scope (§2); `[proposed]` markers retained; the rendering joint stays with B6-1a.
- **Rollback:** delete `test/device_audit_visibility_guard_test.dart` and revert the `entry_ux_test.dart` group — zero production impact (no B6-1-attributable `lib/` diff by REQ-4; whole-tree `git diff lib/` may stay non-empty from sibling in-flight change sets).
