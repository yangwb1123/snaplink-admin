# B6-1 — Design: developer-module zero-ring isolation floor — guard trio (module: lib/api)

> Upstream: `docs/proposals/b6-1-lib-api-developer-ring-isolation-floor-spec.md` (requirements).
> Every citation below was re-verified at HEAD on 2026-08-08. **Working-tree snapshot at refresh (tree live with the concurrent B6-2 landing):** 8 untracked files — this spec, this design, and the B6-1b design; the three landed guard tests `test/developer_ring_isolation_test.dart`, `test/developer_audit_visibility_guard_test.dart`, `test/developer_forge_invisibility_test.dart`; and B6-2's `test/app_router_client_id_wiring_test.dart`, `test/client_id_contract_test.dart`. The 5 tracked-modified files (`lib/api/sso_client.dart`, `lib/app_router.dart`, `test/sso_client_test.dart`, `test/oidc_account_flow_test.dart`, `test/oidc_login_screen_client_id_test.dart`) are the B6-2 landing (pre-existing, adversarial-review F6) — **zero tracked `lib/` changes attributable to B6-1** (its diff is exactly the 3 docs + 3 test files). The acceptance-critical suites were **executed**, not just cited: `test/developer_api_test.dart`, `test/oidc_login_ring_isolation_test.dart`, `test/oidc_login_audit_visibility_guard_test.dart`, `test/audit_log_tab_test.dart` (landed AC-3a/3b/3c), `test/device_audit_visibility_guard_test.dart` — all green. The spec's claims hold; this design records the verification table (with three line-drift corrections), eight design-level findings (V1–V8), and the concrete test-side contract the spec leaves open.

## 0. Evidence verification (claims re-checked, not trusted)

### 0.1 Citation table (spec §2 E1–E9, S1–S6 re-checked at HEAD)

| # | Spec claim | Verified at HEAD | Verdict |
|---|---|---|---|
| E1 | Sibling spec `b6-1-lib-screens-developer-ring-isolation-spec.md:65,72,76` = AC-1/2/3 headings; header value 8 / risk 8 / effort 2 / confidence 9 | `:65` = AC-1 heading, `:72` = AC-2 heading, `:76` = AC-3 heading (exact); header line 3 carries "value 8 / risk 8 / effort 2 / confidence 9" (exact) | ✅ exact |
| E2 | `lib/screens/developer/` zero `AuditLogService`/`audit_log_service`/`sso_audit_log` refs, 13 files | `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/developer/` → exit 1, zero hits, 13 files (`developer_screen`, `developer_api`, `register_panel`, `manage_panel`, `dcr_models`, `dcr_credentials`, `dcr_delete_dialog`, `dcr_form_controller`, `dcr_metadata_form`, `dcr_round_trip_notice`, `dcr_update_projection`, `dcr_validation`, `discovery_region_notice`) | ✅ exact |
| E3 | `test/oidc_login_ring_isolation_test.dart:104-137` — pre-seed → snapshot → drive → net-zero + `addTearDown(clear)` | testWidgets at :100; pre-seed `record(AuditEntry(…'/api/v1/admin/forged'…'forged'))` :104-112; `addTearDown(AuditLogService().clear)` :113; snapshots + seed sanity :116-121; drive :123-125; net-zero (keys set, stored string, count, entries, no `/api/v1/audit` request) :134-141 | ✅ exact |
| E4 | `test/oidc_login_audit_visibility_guard_test.dart:21-47` — main :21, split needles :26, `expect` :39 | `void main() {` is at **:24** (`:21-23` = grep-form doc comment); `moduleDir = 'lib/screens/oidc_login'` :25; `const banned = ['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log']` :26; `expect(offenders, isEmpty, reason: …)` :39-46; `@TestOn('vm')` + `dart:io` recursive scan | ⚠️ main :21→**:24**; needles/expect exact |
| E5 | `test/audit_log_tab_test.dart:276-306` forge joint AC-3a; `_seedForgedRing` :89-105 | `_seedForgedRing()` :89-101 (non-matching vocab: `path: '/api/v1/admin/forged'` :96, `label: 'forged entry'` :98); AC-3a testWidgets :294-310 (`_seedForgedRing()` :297; asserts `find.text('2 entries')` :306, forged path/label `findsNothing` :307-308); :276-290 is the tail of the preceding redaction test | ⚠️ lines shifted: AC-3a :294-310 (spec's `[CORRECTION]` confirmed); substance exact |
| E6 | `lib/screens/admin/audit_log_tab.dart:26,53,68` — `api`, `capabilities`, `AuditReadClient(widget.api)`, capability gate | `final SnaplinkAdminApi api;` :26; `final SnaplinkAdminCapabilities capabilities;` :27; `required this.api` :39 / `required this.capabilities` :40; `_client = AuditReadClient(widget.api, tenantId: …, traceId: …)` :67-68; gate `if (!widget.capabilities.has('GET', AuditReadClient.eventsPath))` :85 | ⚠️ lines corrected (spec's `[CORRECTION]` confirmed): :53→:67-68, :68→:85 |
| E7 | `test/developer_api_test.dart` MockClient harness at :16/:54/:76/:125; `register`/`saveApp`/`deleteApp` signatures | `DeveloperApi(baseUri:, httpClient: MockClient(…))` at :14-16, :52-54, :74-76, :123-125 (+ :155-157, :201-204); method/path/Bearer/body asserts per request; `developer_api.dart`: `register` :75, `saveApp` :136, `deleteApp` :155 — signatures exact (`register({required clientName, required redirectUris, required scope, required tokenEndpointAuthMethod, required tokenStrategy, additionalMetadata = const {}, String? initialAccessToken})`; `saveApp({required clientId, required token, required body})`; `deleteApp({required clientId, required token})`) | ✅ exact |
| E8 | `docs/campaigns/implementation-gate.md:56` — "localStorage ring 降级为调试记录；展示服务端记录 … devtools 伪造不再构成证据" | Line 56, console row 1: exact, incl. "T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据" and "B1-5" | ✅ exact |
| E9 | Three target files absent; `device_audit_visibility_guard_test.dart` landed | `ls test/developer_ring_isolation_test.dart test/developer_audit_visibility_guard_test.dart test/developer_forge_invisibility_test.dart` → no such file, all three; device guard exists, `moduleDir = 'lib/screens/device'` :23, `expect(offenders, isEmpty)` scan | ✅ exact |
| S1 | `DeveloperApi` injectable ctor :44-49 | `DeveloperApi({http.Client? httpClient, Uri? baseUri, Duration timeout = …})` :44-49; pure Dart (no widgets) — plain `test()` suffices | ✅ exact |
| S2 | `LocalStorage` VM in-memory (`keys()` :21); `AuditLogService` singleton, `record` inserts before `_save`, `clear`, `count`, `entries` | `LocalStorage` :9, `getItem` :11, `keys()` :21 (module-level map impl); `AuditLogService` singleton via `factory AuditLogService() => _instance` :58-59; key `'sso_audit_log'` :66; `entries` → `List.unmodifiable(_entries)` :87; `record` :89-94 — `_entries.insert(0, entry)` **before** `_save()`; `clear` :120-123; `count` :125; `_save` :127-134; `_load` :136-148 (the **only** `AuditEntry.fromJson` path) | ✅ exact |
| S3 | Landed forge joints pin non-matching vocabulary; AC-3 adds the matching variant | `_seedForgedRing` path `/api/v1/admin/forged` vs server row types `admin_client_created`/`admin_user_deleted` — label never equals a row type; the dedup/misattribution variant is unpinned | ✅ exact |
| S4 | Timeline harness reusable verbatim | `_eventsBody` :17-25 (rows `admin_client_created`/`admin_user_deleted`, wire `"count":999`); `_api(routes)` :29-39 keyed by `request.url.path`, 404 fallback; `_caps(paths)` :41-45; `_recordingApi` :48-60; `_pump` :62-68 (1200×2200 view, `MaterialApp(home: Scaffold(child: child))`) | ✅ exact |
| S5 | `SnaplinkAdminApi({required baseUrl, required accessToken, http.Client? httpClient})` :35-40; `AuditReadClient.eventsPath` | ctor :35-38 (named params confirmed by every test call site); `eventsPath` is at `audit_read_client.dart:15` (spec cited :24 — drift; value `/api/v1/audit/events` exact) | ⚠️ eventsPath :15 not :24; substance exact |
| S6 | Admin ring-write positive pin `snaplink_admin_api_test.dart:331-413` | Group "ring liveness — successful mutations land in the audit ring" at :327; test `POST/PUT/DELETE each append exactly one query-free ring entry` :333 (spec's `:331-413` off by a row); pins one ring entry + `sso_audit_log` key per 2xx non-GET | ⚠️ :331→**:327** group / :333 test; substance exact |

**Working-tree note:** the spec's §head states "one untracked docs/ file"; at verification time there are **two** untracked `docs/` files (the spec itself and the B6-1b design) — a staleness in the spec's working-tree note only; the deliverable claim (zero tracked `lib/` changes) holds.

### 0.2 Design-level findings (no spec defect — tighten the acceptance contract)

**V1 — `AuditEntry` has no `operator ==`; AC-1's `entries` equality is identity-based and that is the point.** `entries` returns `List.unmodifiable(_entries)` — a fresh wrapper per call — so `expect(AuditLogService().entries, entriesBefore)` passes only via package:matcher deep collection equality, which falls back to **element identity** for `AuditEntry`. Consequences: (a) this is the strongest possible write-then-restore detector — any transient `record()` inserts a fresh instance that can never be identity-equal to the seed instance; (b) it is a matcher-semantics dependency, not an `AuditEntry.==` dependency. Robustness invariant (verified `audit_log_service.dart:89-94,127-148`): `record()` stores the **caller's instance directly** — no JSON round-trip — so identity survives `_save()`; `_load()` is the only `fromJson` path. A write-then-restore that launders localStorage still leaves a `fromJson`-fresh instance in `_entries`. Should a future `AuditEntry.==` weaken this pin to value equality, the storage-level asserts (keys-set equality, stored-string equality) remain a second layer. The AC-1 reason strings must say "same in-memory entry instances".

**V2 — the header count is `_rows.length`, not the wire `count` field** (`audit_log_tab.dart:280`: `LocalizedText('{count} entries', args: {'count': _rows.length})`). AC-3's `'2 entries'` assertion therefore requires the canned body to contain **exactly two rows**; the wire `count` value is irrelevant (landed AC-3a already proves it: body `count: 999` → header `'2 entries'`). The coupling is intentional and the point of the assertion: it pins that the header derives from the decoded events array, not from the wire `count` and not from the ring — a future commit that merges ring rows into `_rows` flips it to 3 and fails `findsOneWidget`. The assertion must carry `reason: 'header count derives from _rows.length (2 rows), never the wire count or the ring'`.

**V3 — a server row's `type` renders in exactly one widget: the bold EVENT cell** (`TableCellText(_displayed[i].type, bold: true)`, `audit_log_tab.dart:432`, column header `'EVENT'` :428). There is **no path column** on the timeline (the CSV export header at `audit_log_tab.dart:185` is `timestamp,type,outcome,id,actor_id,client_id,tenant_id`). So AC-3's `find.textContaining('/api/v1/admin/clients') → findsNothing` is trivially green today and exists purely to pin the future hazard: a buggy commit that merges ring rows into `_rows` renders the forged **label** as a duplicate `admin_client_created` (caught by `findsOneWidget`) and, if it also renders paths, the path (caught by `findsNothing`). **This assertion is a FUTURE-PIN (non-current behavior)** — it must carry a `// FUTURE-PIN (non-current-behavior): no path column renders today; trips when a future commit renders ring paths` comment and matching reason string, so maintainers cannot "simplify" it away as trivially green.

**V4 — AC-1's drive produces three requests but only two distinct paths.** POST → `/register`; PUT → `/register/client-1`; DELETE → `/register/client-1` (PUT/DELETE share the path; only the method differs). The audit-surface assertion must be: request count == 3 **and** every recorded path starts with `/register` **and** no path contains `/api/v1/audit` — never a set-equality over three distinct paths (unsatisfiable by construction).

**V5 — the B6-1b debug chip is ON by default in `flutter test`** (`_ringCopyEnabled = kDebugMode`, `audit_log_service.dart:76`; `flutter test` runs in debug mode). The chip (`audit_log_tab.dart:296-318`) renders exactly: `StatusChip('Debug records')` :300-304, `'Debug records: {n} entries'` :307-310 (n = `_logService.count` — 1 after the AC-3 seed), delete icon with tooltip `'Clear local debug records'` :313-317 — **count text only, never paths or labels**. AC-3 needles (`admin_client_created`, `/api/v1/admin/clients`, `forged`) cannot collide with chip text; `find.text('2 entries')` (exact) cannot collide with `'Debug records: 1 entries'`. The design does **not** toggle `ringCopyEnabled` — keeping the default exercises the real debug surface (landed AC-3a suite passes with the default on).

**V6 — per-isolate shared state: teardown is mandatory.** `AuditLogService()` is a process singleton (:58-59) and VM `LocalStorage` is a module-level map. Every test that seeds the ring must `addTearDown(AuditLogService().clear)` (sibling pattern), and AC-3 must additionally assert `LocalStorage.keys()` unchanged **post-pump** (the timeline must not write). `DateTime.now()` seeds are inert — timestamps are never compared.

**V7 — `DeveloperApi._handle` tolerates 204/empty bodies** (`developer_api.dart:168-187`: empty body falls through, 2xx returns `{}`, no throw) — the AC-1 DELETE leg (mock 204, empty body) cannot throw; `register` returns the parsed map (extra keys like `registration_access_token` are inert). MockClient responses must resolve immediately (the ctor's `timeout` is `const Duration(seconds: 30)` at `:46` — no artificial delay in handlers, so the timeout is never approached).

**V8 — no path-literal duplication hazard in the new files.** The three new test files live under `test/`, outside the AC-2 scan root (`lib/screens/developer`), so their own `AuditLogService` imports cannot trip the scan — but the guard files must still keep their needles literal-split **including inside reason strings** (the sibling splits the reason too: `'AuditLog' 'Service / audit_log_' 'service / sso_audit_' 'log references'`), because a naive grep over `test/` would otherwise self-hit.

## 1. API changes

**No production-code change.** `lib/screens/developer/**`, `lib/screens/admin/audit_log_tab.dart`, `lib/api/snaplink_admin_api.dart`, `lib/api/audit_read_client.dart`, `lib/services/audit_log_service.dart`, `lib/services/local_storage.dart` are all untouched. The module already satisfies REQ-1 (E2); the deliverable is regression guards only.

The change set is **three new files under `test/`** (+3 tests), auto-discovered by `flutter test` (`Makefile:52`; CI `make test` at `.github/workflows/ci.yml` "Unit tests") — no CI, Makefile, manifest, or pubspec change.

### 1.1 Test-side surface freeze (the only "API" this design adds)

Each new file compiles strictly against **landed** surfaces — a compile-error in any new file is a regression signal that a landed API changed. Nothing `[PROPOSED]` (no BFF wire, no `trace_id`/`tenant_id` requirement — both are optional `AuditLogTab` ctor params, omitted).

| Symbol | Contract (verified) | Used by |
|---|---|---|
| `DeveloperApi({Uri? baseUri, http.Client? httpClient, Duration timeout})` | `developer_api.dart:44-49`; pure Dart | AC-1 |
| `DeveloperApi.register({clientName, redirectUris, scope, tokenEndpointAuthMethod, tokenStrategy, additionalMetadata, initialAccessToken})` → `Future<Map<String,dynamic>>` | `:75-92`; POST `/register`; Bearer when token supplied | AC-1 |
| `DeveloperApi.saveApp({clientId, token, body})` → `Future<Map<String,dynamic>>` | `:136-152`; PUT `/register/{id}` | AC-1 |
| `DeveloperApi.deleteApp({clientId, token})` → `Future<void>` | `:155-166`; DELETE `/register/{id}`; 204 tolerated | AC-1 |
| `AuditLogService()` singleton; `record(AuditEntry)` / `clear()` / `count` / `entries` | `audit_log_service.dart:58-59,89-94,120-125` | AC-1, AC-3 |
| `AuditEntry({timestamp, method, path, statusCode, label})` | `:6-34`; no `==` (V1) | AC-1, AC-3 |
| `LocalStorage.keys()` / `getItem(key)` | `local_storage.dart:11,21`; VM in-memory | AC-1, AC-3 |
| `AuditLogTab({required api, required capabilities, tenantId?, traceId?})` | `audit_log_tab.dart:26-43` | AC-3 |
| `SnaplinkAdminApi({required baseUrl, required accessToken, http.Client? httpClient})` | `snaplink_admin_api.dart:35-38` | AC-3 |
| `SnaplinkAdminCapabilities([SnaplinkAdminEndpoint(method:, path:, feature:)])` | test harness pattern `audit_log_tab_test.dart:41-45` | AC-3 |
| `AuditReadClient.eventsPath` == `'/api/v1/audit/events'` | `audit_read_client.dart:15` | AC-3 (capability gate input) |
| `auditEventRowsFromResponse` envelope: `events` array of `{id,type,outcome,timestamp,actor_id,client_id,tenant_id}` | `audit_event_row.dart:50-58` (tolerant of degraded envelopes) | AC-3 fixture shape |

### 1.2 New file skeletons

**`test/developer_ring_isolation_test.dart`** (AC-1, plain `test()`, ~80 lines) — imports: `dart:convert`, `flutter_test`, `http`, `http/testing`, `screens/developer/developer_api.dart`, `services/audit_log_service.dart`, `services/local_storage.dart`. One `test()`:
1. Seed: `AuditLogService().record(AuditEntry(timestamp: DateTime.now(), method: 'POST', path: '/api/v1/admin/forged', statusCode: 200, label: 'forged'))`; `addTearDown(AuditLogService().clear)`.
2. Snapshots + seed sanity: `keysBefore`, `valueBefore`, `countBefore`, `entriesBefore`; `expect(keysBefore, contains('sso_audit_log'), reason: 'seed sanity')`, `expect(countBefore, 1, reason: 'seed sanity')`.
3. Drive: one `DeveloperApi(baseUri: Uri.parse('https://sso.example'), httpClient: MockClient(…))` recording every `request.url` into `paths`, with per-leg asserts:
   - `register(clientName: 'Acme app', redirectUris: ['https://app.example.test/callback'], scope: 'openid', tokenEndpointAuthMethod: 'none', tokenStrategy: 'jwt', initialAccessToken: 'bootstrap-token')` → assert `POST` `/register`, `Authorization: Bearer bootstrap-token`; return `201` `{"client_id":"client-1","registration_access_token":"rat-1"}`;
   - `saveApp(clientId: 'client-1', token: 'rat-1', body: {'client_name': 'Acme app'})` → assert `PUT` `/register/client-1` + Bearer; return `200 {}`;
   - `deleteApp(clientId: 'client-1', token: 'rat-1')` → assert `DELETE` `/register/client-1` + Bearer; return `204` empty.
4. Net-zero (REQ-2), each with a reason string:
   - `expect(LocalStorage.keys().toSet(), keysBefore, reason: 'the DCR flow must not introduce the ring key')`;
   - `expect(LocalStorage.getItem('sso_audit_log'), valueBefore, reason: 'stored ring value byte-identical')`;
   - `expect(AuditLogService().count, countBefore, reason: 'same in-memory entry count')`;
   - `expect(AuditLogService().entries, entriesBefore, reason: 'same in-memory entry instances (catches write-then-restore)')` (V1);
   - `expect(paths.length, 3)`; `expect(paths.every((p) => p.path.startsWith('/register')), isTrue, reason: 'exactly the three DCR requests')`; `expect(paths.where((p) => p.path.contains('/api/v1/audit')), isEmpty, reason: 'the DCR flow must not issue any audit request')` (V4).

**`test/developer_audit_visibility_guard_test.dart`** (AC-2, `@TestOn('vm')`, ~45 lines) — exact mirror of `oidc_login_audit_visibility_guard_test.dart:19-48` with `moduleDir = 'lib/screens/developer'` and the split needles `['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log']`; recursive `dart:io` scan over `*.dart`; `expect(offenders, isEmpty, reason: 'lib/screens/developer must keep zero ' 'AuditLog' 'Service / audit_log_' 'service / sso_audit_' 'log references (localStorage ring is debug-only; DCR mutations are evidenced exclusively through the server-fed timeline)')`. File header documents the CI grep form (literal-split, must exit 1): `grep -rn "AuditLog""Service\|audit_log_""service\|sso_audit_""log" lib/screens/developer/`.

**`test/developer_forge_invisibility_test.dart`** (AC-3, `testWidgets`, ~110 lines) — harness copied verbatim from `audit_log_tab_test.dart:17-68` (own copies of `_eventsBody`-equivalent, `_api`, `_caps`, `_pump`; no shared helper import — keeps the deliverable self-contained at three files). One testWidgets:
1. Seed (matching vocabulary): `AuditLogService().record(AuditEntry(timestamp: DateTime.now(), method: 'POST', path: '/api/v1/admin/clients', statusCode: 200, label: 'admin_client_created'))`; `addTearDown(AuditLogService().clear)`; snapshot `keysBefore`.
2. Canned body — **exactly two rows** (V2): `{"events":[{"id":"e-1","type":"admin_client_created","outcome":"success","timestamp":"2026-08-05T12:00:00Z","actor_id":"admin-1","client_id":"console","tenant_id":"acme"},{"id":"e-2","type":"admin_user_deleted","outcome":"failure","timestamp":"2026-08-05T13:00:00Z","actor_id":"admin-2","client_id":"console","tenant_id":"acme"}],"count":2}`; route `GET /api/v1/audit/events` → 200; `AuditLogTab(api: _api({...}), capabilities: _caps(['/api/v1/audit/events']))`; `_pump(tester, tab)`.
3. Assert (T-12 joint), with reasons:
   - `expect(find.textContaining('admin_client_created'), findsOneWidget, reason: 'server row renders exactly once; the forged duplicate never merges')` — never `findsNWidgets(2)`;
   - `expect(find.textContaining('/api/v1/admin/clients'), findsNothing, reason: 'FUTURE-PIN (non-current-behavior): no path column renders today — trips when a future commit renders ring paths')` (V3);
   - `expect(find.textContaining('forged'), findsNothing, reason: 'forged entries never render as evidence')`;
   - `expect(find.text('2 entries'), findsOneWidget, reason: 'header count derives from _rows.length (2 rows), never the wire count or the ring')` (V2);
   - post-pump `expect(LocalStorage.keys().toSet(), keysBefore, reason: 'the timeline must not write to the ring')` (V6).

## 2. Compatibility constraints

- **C1 — Zero production API change.** The three files compile only against the frozen surface (§1.1). Any landed-API signature change that breaks a new file fails `make analyze` / `flutter test` loudly at the changed symbol — the intended tripwire, not a maintenance burden.
- **C2 — Test-only, auto-discovered.** Files live under `test/`; `flutter test` (Makefile:52, CI) discovers them without manifest edits. No `dart:html`/browser-only APIs in any file: AC-1 is a plain `test()` (VM), AC-2 is `@TestOn('vm')`, AC-3 is `testWidgets` (VM flutter_test). Deterministic on VM (in-memory `LocalStorage`).
- **C3 — Guard self-exemption.** Banned literals must stay split (`'AuditLog' 'Service'` etc.) in **both** guard files — including inside reason strings (V8) — so neither guard can ever trip itself, and the documented CI grep form stays copy-pasteable (adjacent-quote concatenation).
- **C4 — Ring-state hygiene.** Every seeding test: `addTearDown(AuditLogService().clear)`; seed-sanity asserts (`contains('sso_audit_log')`, `count == 1`); AC-3 post-pump keys assert. Prevents order-dependent flakiness from the process singleton (V6).
- **C5 — Debug chip default stays ON.** Do not toggle `AuditLogService.ringCopyEnabled`/`debugRingEnabled` in tests. Needles are collision-free against chip text (`'Debug records'`, `'Debug records: {n} entries'`, tooltip `'Clear local debug records'`) (V5).
- **C6 — Fixture shape.** AC-3's canned body must parse under `auditEventRowsFromResponse` (envelope key `events`; row keys `id/type/outcome/timestamp/actor_id/client_id/tenant_id`) and contain **exactly two rows** — the header count is `_rows.length`, not the wire `count` (V2).
- **C7 — Mock semantics.** Route handlers keyed by `request.url.path` with 404 fallback (landed harness); handlers resolve immediately (no artificial delay — `DeveloperApi` applies a timeout); `_handle` accepts 204/empty (V7).
- **C8 — Scan-root boundary.** AC-2 covers `lib/screens/developer` only. Ring refs in other modules are enforced by their own buckets (oidc_login/device guards landed; admin is the sanctioned ring writer, pinned by `snaplink_admin_api_test.dart:327-413`). The new files' own `AuditLogService` imports are outside the scan root by construction.
- **C9 — No shared-helper extraction.** The S4 harness is copied verbatim into `test/developer_forge_invisibility_test.dart` (not promoted to a shared `test/helpers/` file): keeps the deliverable at exactly three files per the spec, avoids cross-file churn, and matches the sibling oidc_login pattern (each guard self-contained).

## 3. Failure modes

| # | Future regression | Tripped by | Trip signature |
|---|---|---|---|
| FM-1 | A developer-module refactor wires DCR mutations into the debug ring (`AuditLogService().record(...)` anywhere in `lib/screens/developer/`) | AC-1 **and** AC-2 | AC-1: `count`/`entries` mismatch, `sso_audit_log` key/value change. AC-2: `offenders` non-empty (catches even code no test exercises) |
| FM-2 | Write-then-restore: transient ring write that restores the localStorage string afterwards | AC-1 (in-memory identity, V1) | `entries` differs — a `record()`-inserted `fromJson`-fresh instance is never identity-equal to the seed; storage-level asserts are the second layer |
| FM-3 | Timeline merges ring rows into `_rows` (server-fed invariant violated) | AC-3 | `findsOneWidget` fails → `findsNWidgets(2)`; `'2 entries'` → `'3 entries'`; forged path/label render if rows/paths render |
| FM-4 | Timeline writes to the ring (e.g., `record()` in `_refresh`) | AC-3 post-pump | `LocalStorage.keys()` changed |
| FM-5 | Server contract drift (row field renamed, envelope key changed) | AC-3 fixture | `auditEventRowsFromResponse` yields zero/partial rows → `'2 entries'`/`findsOneWidget` fail loudly — a signal to update the fixture **with** the contract change, never silently |
| FM-6 | Guard self-hit (needles de-split, e.g., by a formatter/refactor) | AC-2 | Guard permanently red — the split-literal discipline (C3) exists to prevent this |
| FM-7 | Singleton-state leakage (a seeding test loses `addTearDown(clear)`) | AC-1/AC-3 neighbors | Order-dependent failures across tests in the same isolate; seed-sanity asserts localize the break |
| FM-8 | `AuditEntry` gains value-based `==` | AC-1 (weakened, not broken) | Pin drops from identity to value equality — still catches writes; documented dependency (V1). Storage asserts remain |
| FM-9 | False confidence from the wrong scan root (someone retargets AC-2 to `lib/screens/oidc_login`) | AC-2 | moduleDir change silently stops guarding `lib/screens/developer` — the reason string names the module explicitly |
| FM-10 | Deliverable scope creep (production edit bundled in) | AC-4 | `git diff --stat` shows tracked `lib/` changes — the review gate, not a test |

**Guard-weakness analysis (explicit):** AC-1 is black-box — it cannot catch a ring write that is (a) exercised by no code path in the drive, or (b) paired with an exact in-memory remove *and* exact localStorage restore leaving zero trace (undetectable by any black-box test). AC-2 closes (a) for the developer module statically. AC-3 is a behavior pin on the landed timeline, not on `DeveloperApi` — its scope is the T-12 joint, deliberately exercised from the developer suite per the spec's AC-4 joint list.

## 4. Migration steps (ordered; each step leaves the tree green)

1. **Precondition (already at HEAD):** `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/developer/` → exit 1; confirm the three target files absent; `git status` shows no tracked changes.
2. **Land AC-1** — write `test/developer_ring_isolation_test.dart` per §1.2; run `flutter test test/developer_ring_isolation_test.dart test/developer_api_test.dart` (both green; the latter proves the harness pattern compiles unchanged).
3. **Land AC-2** — write `test/developer_audit_visibility_guard_test.dart`; run `flutter test test/developer_audit_visibility_guard_test.dart` (green ⇒ module clean AND guard self-exempt), plus `flutter test test/oidc_login_audit_visibility_guard_test.dart test/device_audit_visibility_guard_test.dart` (sibling guards unaffected).
4. **Land AC-3** — write `test/developer_forge_invisibility_test.dart` (harness copied verbatim from `audit_log_tab_test.dart:17-68`); run `flutter test test/developer_forge_invisibility_test.dart test/audit_log_tab_test.dart` (the landed AC-3a/3b/3c still green ⇒ no interference from the developer-suite pump).
5. **Full-suite gate** — `flutter test` (all green) and `make analyze` (zero **new** diagnostics vs the pre-existing baseline — the tool is already red at HEAD with exactly 9 pre-existing infos (`test/audit_contract_guard_test.dart:340`, `test/entry_ux_test.dart:252/269/287/292`, `test/oidc_login_handle_success_census_test.dart:212/216/315/347`), none in the landed files; the honest gate is `flutter analyze` output minus that 9-info baseline = empty, i.e. the three new files add nothing to the set); verify `git diff --stat` shows **zero** tracked `lib/` files.
6. **CI posture** — no workflow change required (`make test` discovers the files; `make analyze` covers them). Optionally, per spec AC-4, paste the literal-split grep form from the AC-2 file header into the review checklist/CI job doc — the guard test itself is the enforcement. The landed `make release-artifact-check` (`Makefile:36-48`) scans the release **bundle**, not `lib/` — untouched and out of scope.

## 5. Testable acceptance mapping

| AC (spec §4) | New file | Test | Key assertions (with reasons per §1.2) | Fails on |
|---|---|---|---|---|
| AC-1 | `test/developer_ring_isolation_test.dart` | plain `test()` | seed sanity; keys-set equal; stored string byte-equal; `count` equal; `entries` equal (identity); `paths.length == 3`; all paths start `/register`; no `/api/v1/audit` path | FM-1, FM-2, FM-7, FM-8 |
| AC-2 | `test/developer_audit_visibility_guard_test.dart` | `@TestOn('vm')` scan | `expect(offenders, isEmpty)` over `lib/screens/developer` with split needles; CI grep form in header | FM-1 (static), FM-6, FM-9 |
| AC-3 | `test/developer_forge_invisibility_test.dart` | `testWidgets` | `findsOneWidget` on `admin_client_created`; `findsNothing` on forged path (FUTURE-PIN) and `'forged'`; `find.text('2 entries')`; post-pump keys unchanged | FM-3, FM-4, FM-5, FM-7 |
| AC-4 | — (aggregate) | `flutter test` + `make analyze` + `git diff --stat` | full suite green incl. `developer_api_test`, `dcr_widgets_test`, `entry_ux_test`, `developer_serving_region_test`, `dcr_models_test`, `audit_log_tab_test`, both oidc_login guards, `device_audit_visibility_guard_test`; zero **new** `make analyze` diagnostics vs the 9-info pre-existing baseline; zero tracked `lib/` diff | FM-10, any regression |

**Green-at-HEAD basis (verified):** the module is compliant (E2), the timeline is server-fed (E6, V2), the debug chip is collision-free (V5), and the landed sibling/forge suites pass — so all three files are green on landing with zero production edits, exactly as the spec's §5 scopes.

## 6. Out of scope (hard boundary, per spec §5)

- **No production-code change** anywhere in `lib/`; deliverable is exactly the three guard test files (C9 keeps it at three).
- B6-1a timeline rewire, B6-1b ring-demotion mechanism and i18n keys — landed sibling change sets, referenced only as test surface.
- B6-2 sibling directions (login-edge generation drill, `client_id` alignment, `auth.login.success` census) — separate buckets.
- `[PROPOSED]` BFF audit read (`trace_id`/`tenant_id` wire, `lib/api/portal_api.dart`) — AC-3 uses the landed `SnaplinkAdminApi` carrier only.
- Sink-side `audit.event.read` self-audit emission (B1-5) — cross-repo, server-side.
- Release-grep machinery (`Makefile:36-48`) and CI workflow edits — landed/unchanged; the guard test is the enforcement.
