# B6-1 AC-1 Phase B — Requirements spec: `test/oidc_login_audit_timeline_joint_test.dart` (module: `lib/screens/oidc_login`)

> Upstream: `docs/proposals/b6-1-lib-screens-oidc-login-audit-visibility-design.md` §1.3/§1.4/§5 (AC-1 Phase B row) and the parent spec `docs/proposals/b6-1-lib-screens-oidc-login-audit-visibility-spec.md` REQ-4 / AC-1 Phase B. Every citation below was re-verified at HEAD `40acef7` (2026-08-08) before writing; the two existing precedent files were executed and are green (+27). One supplied acceptance half was found unsatisfiable at HEAD and is corrected in §2 (C1), mirroring the design's own D-correction discipline (D1/D2/D3).

## 0. Direction (verbatim) and scope

**Direction title:** "Land B6-1 AC-1 Phase B joint test: `test/oidc_login_audit_timeline_joint_test.dart` (login leg → server-read timeline)".

**Problem (verified):** the approved design specifies this file as the module's B6-1 deliverable — one mock serves `OidcLoginScreen`'s `/auth/login` POST and `AuditLogTab`'s `GET /api/v1/audit/events` so the login edge is evidenced only through the server-fed timeline. It does not exist at HEAD (`ls test/oidc_login_audit_timeline_joint_test.dart` → exit 2; 136 files in `test/`, no joint file), so the console-side T-12 joint acceptance rests solely on the Python drill (`tests/integration/audit_login_drill.py`, deployed-stack-gated) — an in-repo regression (timeline silently falling back to the localStorage ring, or a duplicated login POST) would not fail CI.

**Scope:** one new file, zero edits. No `lib/` edits (design §2 rule 2: "Zero edits to existing files" — no edits to `test/oidc_login_screen_client_id_test.dart`, no edits to `test/audit_log_tab_test.dart`, no edits to the audit-contract guard suite). B6-1/B6-1b/B6-2 are **landed** at HEAD, so the file is green-able at HEAD — the design's §2.1 "ships inside B6-1's commit" latch has already closed.

**Module boundary:** the deliverable guards `lib/screens/oidc_login`'s login edge (REQ-3/REQ-4 of the parent spec); production code in the module stays byte-identical.

## 1. Evidence verification (every direction citation re-checked at HEAD, not trusted)

| # | Direction citation | Verified reality at HEAD `40acef7` | Verdict |
|---|---|---|---|
| E1 | Design §1.3 joint-file spec | `test/oidc_login_audit_timeline_joint_test.dart` fully specified: single path-keyed MockClient serving four requests (probe POST `/auth/login` 404; GET `/branding` 404; credential-bearing POST `/auth/login` 200; GET `/api/v1/audit/events` 200 with the REQ-4 fixture row), D2-corrected asserts (audit-surface intersection, full path set `{/auth/login, /branding, /api/v1/audit/events}`, D9-filtered login count, no `sso_audit_log` key), N1 teardown (login-client-only) | ✅ exact |
| E2 | Design §1.4 grep forms | Both forms present; `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → **exit 1** at HEAD (28 module files clean) | ✅ exact |
| E3 | Design §5 AC-1 Phase B table row | Row "AC-1 Phase B — joint login → timeline rendering, ring untouched (timeline half)" → enforced by this file, lands "with B6-1" — B6-1 landed, latch closed | ✅ exact (landing state advanced) |
| E4 | `lib/screens/admin/audit_log_tab.dart:108` (_refresh via AuditReadClient, ring never a data source) | `AuditLogTab({required api, required capabilities})` landed (ctor `:29-37`); `_refresh()` `:78`; `final rows = await _client.list(limit: 100);` at **`:102`**; file doc comment `:24-26`: "the localStorage ring is demoted to a debug-only recording surface (B6-1b) and is never a data source" | ⚠️ line drift (`:102`, not `:108`); claim exact |
| E5 | `lib/api/audit_read_client.dart:17` (eventsPath) | `static const eventsPath = '/api/v1/audit/events';` exactly at `:17`; `AuditReadClient.list` is the tab's sole read path (`:59-66`) | ✅ exact |
| E6 | `test/oidc_login_screen_client_id_test.dart:24` (MockClient harness precedent filtering POST `/auth/login`) | `_LoginHarness` class `:27-55`; `httpClient: MockClient((request) async {` `:31`; D9 filter `body['credential'] is Map` `:34`; probe counted separately (`probePosts`) `:51`; file green at HEAD (baseline run, §5) | ⚠️ line drift (`:27/:31/:34`, not `:24`); claim exact |
| E7 | `test/audit_log_tab_test.dart:108-127` (AC-1.2/1.4/1.5/1.6 server-read pins) | Seed helpers `_seedForgedRing`/`_seedForgedRingRaw` at `:105-145`; the pins themselves: AC-1.2 exact query `expect(uri.queryParameters, {'limit': '100'})` `:170`; AC-1.4 header `find.text('2 entries')` (decoy `"count":999` never read) `:180-184`; AC-1.5 forged ring never renders `:186-188`; AC-1.6 re-query identical `:190-197` | ⚠️ range drift (pins at `:153-197`); claim exact |
| E8 | Joint file absent at HEAD | `ls test/oidc_login_audit_timeline_joint_test.dart` → exit 2 | ✅ exact |
| E9 | `tests/integration/audit_login_drill.py:219-223` (step 6, T-12 joint) | Step 6 header + comment exactly at `:219-223`: "console-shaped read triggers the caller's own audit.event.read self-audit row (sink-side emission is B1-5 … until it lands, this leg records [proposed], never a false PASS)" | ✅ exact |
| E10 | Census constraint (design D5, updated) | **Constant mode is active at HEAD**: `lib/api/sso_client.dart:82` `static const String firstPartyClientId = 'sso-admin-console';` exists ⇒ `test/oidc_login_handle_success_census_test.dart:184-191` asserts **zero** occurrences of the quoted literal across all of `test/` (code and comments). The 43-test count gate (`:234-260`) counts only five pinned files — a new file does not trip it | ✅ verified (rule now: use the constant, carry no literal) |
| E11 | Mount behavior behind the path-set (design D2) | `_loadBranding()` unconditional at `oidc_login_screen.dart:210`; `_probeProviders()` fires when `_effectiveClientId.isNotEmpty && _route.requiresAuthentication && _federatedContinuationId == null && !FederatedLogin.hasPendingReturn && !_route.shouldAutoSubmitMagicLink && !_params.hasPromptNone` (`:221-228`) — all true for the harness config (defaultClientId set, plain routeUri) ⇒ mount issues probe POST `/auth/login` (credential-less) + GET `/branding` | ✅ exact (path set `{/auth/login, /branding, /api/v1/audit/events}`) |
| E12 | `SnaplinkAdminApi` ctor / no-close (design N1) | `SnaplinkAdminApi({required baseUrl, required accessToken, httpClient, onUnauthorized, cache, requestTimeout})` `:35-42`; **no `close` member** (only hit is a doc comment at `:267`); `get` at `:126`; `DataCache` in-memory (`lib/api/data_cache.dart:10-30`, no `LocalStorage`) | ✅ exact |
| E13 | `LocalStorage` / ring state in tests | `local_storage_memory.dart:1-11`: top-level `_memoryStore` map, `keys()` deterministic; `local_storage.dart:21` `keys()`. `AuditLogService.ringCopyEnabled` defaults to `kDebugMode` (`audit_log_service.dart:76`) = true under `flutter test`; the tab's debug chip renders ring text only `if (ringCount > 0)` (`audit_log_tab.dart:304-317`) — the joint file never seeds ⇒ ringCount 0 ⇒ no ring text competes with the header counter | ✅ exact |
| E14 | Header counter renders server count | `LocalizedText('{count} entries', args: {'count': _rows.length})` (`audit_log_tab.dart:290-292`) — `_rows` is server-fed only; precedent `find.text('2 entries')` (`audit_log_tab_test.dart:180`) proves template passthrough ⇒ count 1 renders `'1 entries'` | ✅ exact |

## 2. Verified corrections (supplied acceptance preserved; unsatisfiable halves corrected with evidence)

**C1 — "`find.textContaining('/auth/login')` (PATH column)" is unsatisfiable at HEAD.** The design's §1.3 assert list (and the parent spec's AC-1 Phase B step 6) were written against a pre-B6-1 surface that assumed a PATH column. The landed B6-1 surface has none:
- `AuditLogTab` renders columns **TIME / EVENT / OUTCOME / ACTOR / TENANT only** (`audit_log_tab.dart:401-481`); no PATH column.
- `AuditEventRow` has **no path field** — fields are `{timestamp, type, outcome, id, actorId, clientId, tenantId}` (`audit_event_row.dart:17-35`).
- The defensive mapper's type fallback chain is `['type', 'event_type', 'eventType', 'event', 'action', 'label', 'path', 'uri', 'resource', 'endpoint', 'id']` (`audit_event_row.dart:119-135`) — `label` precedes `path`, so the REQ-4 fixture `{method:'POST', path:'/auth/login', status:200, label:'auth.login.success'}` maps to `type = 'auth.login.success'` and `/auth/login` is **dropped** (no field consumes it). `method`/`status` are likewise not in the allowlist.
- The landed tab test asserts type-derived text only (`'admin_client_created'`, `'admin_user_deleted'`) — never path text — confirming the surface.

**Correction (same evidence relocation the design already made in D2):** the rendered-row half asserts `find.textContaining('auth.login.success')` (EVENT column, via the label→type fallback — the only server-row text the landed surface renders for this fixture); the `/auth/login` evidence is asserted **on the wire** in AC-2's full-path-set assertion `{'/auth/login', '/branding', '/api/v1/audit/events'}` (the direction's own check 2, unchanged). The login edge is thereby evidenced exactly as intended — server-fed timeline, `/auth/login` provenance pinned at the HTTP boundary. **Review point:** if a future B6-1 surface change adds a path-bearing field/column, the fixture must render `/auth/login` in the table and the render half is re-enabled in the same commit.

**Line-nits (no substance):** E4 `:108`→`:102`; E6 `:24`→`:27/:31/:34`; E7 `:108-127`→`:153-197` (pins) with seed helpers at `:105-145`.

## 3. Requirements (supplied acceptance checks preserved 1:1, made testable)

**AC-1 — New file `test/oidc_login_audit_timeline_joint_test.dart` per design §1.3; one mock serves both legs; the login edge renders through the server-fed timeline.**
1. File exists at `test/oidc_login_audit_timeline_joint_test.dart`. It replicates the `_LoginHarness` pattern (E6; deliberate duplication per design D4 — `_LoginHarness` is file-private) and uses `SSOAdminClient.firstPartyClientId` (E10 — no fresh `'sso-admin-console'` literal anywhere in the file, including comments).
2. One path-keyed `MockClient` instance serves all four requests (design §1.3 table):

   | Request | Mock response |
   |---|---|
   | `POST /auth/login` with `body['credential'] is Map` (D9 filter) | 200 `{"access_token":"t","session_id":"s"}`; increment `loginPosts` |
   | `POST /auth/login` credential-less (mount probe) | 404 `{}`; increment `probePosts` |
   | `GET /branding` (unconditional `_loadBranding`, E11) | 404 `{}` |
   | `GET /api/v1/audit/events` (timeline leg) | 200 `{"events":[{"method":"POST","path":"/auth/login","status":200,"label":"auth.login.success"}]}` (REQ-4 fixture row; `{'events':[…]}` envelope per E7 precedent `_eventsBody`) |
   | any other path | recorded; zero unexpected requests permitted (AC-2's path-set is the gate) |
3. **Login leg:** `OidcLoginApi(baseUri: Uri.parse('https://sso.example/'), httpClient: mock)` → pump `OidcLoginScreen(api: …, defaultClientId: SSOAdminClient.firstPartyClientId, routeUri: Uri.parse('https://sso.example/login/'))` (design D11: no `prompt=none`, no fragment, no magic-link token); `addTearDown(api.close)` on the **login client only** (E12 — `SnaplinkAdminApi` has no `close`). Submit via the replicated harness (`Username` `'ada@example.com'` / `Password` → tap `FilledButton 'Sign in'`), `pumpAndSettle`. Viewport per precedent: `tester.view.physicalSize` ≥ `Size(900, 1600)` (client_id precedent `900x1600`; tab-test precedent `1200x2200`), `devicePixelRatio = 1.0`, `addTearDown(tester.view.reset)`.
4. **Timeline leg:** `SnaplinkAdminApi(baseUrl: Uri.parse('https://sso.example.test'), accessToken: 'admin-token', httpClient: sameMock)` + `SnaplinkAdminCapabilities([SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/audit/events', feature: 'core')])` (S4 pattern); pump `AuditLogTab(api: …, capabilities: …)` inside `MaterialApp`; `pumpAndSettle`.
5. **Assert (C1-corrected):**
   - `expect(find.textContaining('auth.login.success'), findsOneWidget)` — EVENT column, row originates solely from the mock-served `GET /api/v1/audit/events` response (label→type fallback, E-C1);
   - `expect(find.text('1 entries'), findsOneWidget)` — entries counter shows the **server count (1)**, not the ring count (E14; the ring is never a data source, E4, and ringCount is 0 because this file never seeds, E13).

**AC-2 — Path-set assertions (design D2 correction, direction check 2).**
1. Audit-surface intersection: observed request paths containing `'audit'` == exactly `{'/api/v1/audit/events'}` — no `/api/v1/audit/facets`, no other audit endpoint.
2. Full observed path set == `{'/auth/login', '/branding', '/api/v1/audit/events'}` (E11 — the unconditional branding GET and the mount probe are expected).
3. Exactly one credential-bearing login POST: `expect(loginPosts, 1)` and `expect(probePosts, 1)` — the probe is not a login (D9 filter, E6); a duplicated login POST fails here (sink `'无重复'` clause, implementation-gate.md:57).
4. Consistency pin (from the cited AC-1.2 evidence, E7 `:170`): the events GET arrives with `queryParameters == {'limit': '100'}` (single expect inside the events route handler or against the recorded request; same contract the direction's evidence already pins).

**AC-3 — No ring write; module keeps the zero-reference floor (direction check 3).**
1. After the whole login+timeline flow: `expect(LocalStorage.keys(), isNot(contains('sso_audit_log')))` — never seeded (E13); `TrustedDeviceToken` ops are `kIsWeb`-gated no-ops on VM (`trusted_device_token.dart:11,16,21`); `DataCache` is in-memory (E12); a ring write from either leg fails this immediately.
2. Grep guard (design §1.4, re-run at the joint gate): `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → **exit 1** (verified at HEAD, E2).

**AC-4 — T-12 joint drill unchanged; no false PASS (direction check 4).**
`tests/integration/audit_login_drill.py` step 6 (`:219-223`, E9) keeps its semantics: a console-shaped read triggers the caller's own `audit.event.read` self-audit row against a deployed B1-5 stack; until B1-5 lands the drill records the `[proposed]` deviation and never reports PASS. The in-repo joint file complements the drill (CI-visible, deployed-stack-free); it does not replace it and requires no drill edit.

**AC-5 — Green run, zero edits (direction check 5).**
1. `flutter test test/oidc_login_audit_timeline_joint_test.dart test/audit_log_tab_test.dart test/oidc_login_screen_client_id_test.dart` → all green. Baseline at HEAD (pre-landing, verified 2026-08-08): `audit_log_tab_test.dart` + `oidc_login_screen_client_id_test.dart` → **+27 all passed**; `flutter analyze` clean.
2. `git diff --stat lib/` empty (zero production-code edits, design §1.4/§2 rule 2); no edits to existing test files (D4/coupling rule).

## 4. Constraints (verified at HEAD)

1. **Census (constant mode, E10):** `SSOAdminClient.firstPartyClientId` exists ⇒ zero `'sso-admin-console'` literals permitted anywhere in the new file (code **or comments**); the harness passes the constant. The 43-test count gate counts five pinned files only — adding this file does not trip it (verified `:234-260`).
2. **Teardown (N1, E12):** `addTearDown(api.close)` on the `OidcLoginApi` client only; the admin leg needs none.
3. **Harness duplication (D4):** replicate the `_LoginHarness` pattern with the D9 filter and probe counting preserved; do not import the file-private class.
4. **Wire client_id / sink emission are not asserted** (design §6: B6-2 scope — the joint test asserts rendering of a server-returned `auth.login.success` row only).
5. **Fixture vocabulary dependency (design §2.6):** the REQ-4 fixture renders via the mapper's legacy-fallback chain (label→type). If that fallback is ever removed, the fixture moves to the real schema in the same commit, same review.
6. **`flutter analyze` clean** (no unused imports in the new file); `engineering.yaml` ignores `_test.dart` (max_lines/complexity — no check friction).

## 5. Verification procedure (ordered; each step green at HEAD)

1. `ls test/oidc_login_audit_timeline_joint_test.dart` → exists; `git diff --stat lib/` → empty; `grep -rn "sso-admin-console" test/oidc_login_audit_timeline_joint_test.dart` → exit 1 (census literal).
2. `flutter test test/oidc_login_audit_timeline_joint_test.dart` → green (AC-1/AC-2/AC-3 in-file asserts).
3. `flutter test test/oidc_login_audit_timeline_joint_test.dart test/audit_log_tab_test.dart test/oidc_login_screen_client_id_test.dart` → green (AC-5; no regression to the sibling pins).
4. `flutter test test/oidc_login_handle_success_census_test.dart` → green (census constant-mode + 43-test gate unaffected).
5. `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → exit 1 (AC-3.2).
6. `flutter analyze` → no issues.

## 6. Out of scope (hard boundary)

`lib/screens/oidc_login/**` and all other `lib/` code (zero edits — the design's REQ-1 floor is already met and pinned); `lib/screens/admin/audit_log_tab.dart` and its test (`test/audit_log_tab_test.dart`) — B6-1's, landed, cited only as evidence; `tests/integration/audit_login_drill.py` — device-leg sibling (AC-4 references it, does not change it); client_id wire values and sink emission — B6-2; the `AuditQuery`/facets surface — B6-1; ring liveness/`AuditLogService` behavior — B6-1b (landed).
