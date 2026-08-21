# B6-1 — Design: oidc_login audit-visibility boundary (module: lib/screens/oidc_login)

> Upstream: `docs/proposals/b6-1-lib-screens-oidc-login-audit-visibility-spec.md` (requirements).
> **Status (2026-08-20): implemented and verified.** The historical pre-B6-1 evidence below is retained for traceability; the current implementation record in §0 and the landed joint test are authoritative.
> Every citation below was re-verified against the pre-B6-1 snapshot (2026-08-07) before writing this design; precedent tests `test/oidc_login_screen_client_id_test.dart` + `test/oidc_login_handle_success_census_test.dart` were executed and were green (+9).
> **Three defects in the upstream acceptance contract were found during verification and are corrected in this design** — §0 D1 (AC-1 Phase A self-contradiction), D2 (AC-1 Phase B path-set unsatifiable at HEAD), D3 (AC-3 "no `LocalStorage` in module" false at HEAD). A fourth (D4: harness is file-private) and a fifth discovered by executing Step 1 (D5: client_id literal census pins `test/` site map) are recorded likewise. The spec's `[CORRECTION]` line-number table (E2/E4/E5) is otherwise exact.
> Accepted review fixes landed 2026-08-07: **N1** (joint-file teardown is login-client-only — `SnaplinkAdminApi` has no `close`; §1.3, §3 F6), **N2** (F2 named in the §6 scope list), **security recs 2–4** (explicit recording predicate + F13/F14 failure-mode rows, §3; interim tamper window + two silent-swallow layers, §3.1; query-in-path and TrustedDeviceToken credential-at-rest one-liners, §3/§2.5), and the **postDownload scope call** (§6).

## 0. Evidence verification (claims re-checked, not trusted)
> Current implementation record (2026-08-20): B6-1 is landed and the Phase-B joint contract is now covered by `test/oidc_login_audit_timeline_joint_test.dart`; its MockClient accounts for the real branding/probe requests while asserting one credential login, one server audit read, server-row rendering, and no local ring evidence.

### 0.1 Direction source

| Claim (spec §header) | Verified reality | Verdict |
|---|---|---|
| Direction "Close the auth-event visibility gap…" value 8 / risk 8 / effort 4 / confidence 9 | `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`: `value: 8`, `effort: 4`, `confidence: 9` exact; **no `risk` field exists** — the JSON key is `risk_reduction` (string). | ✅ value/effort/confidence; ⚠️ risk=8 unverifiable from cited source (nit) |

### 0.2 Core citations

| # | Claim | Verified reality | Verdict |
|---|---|---|---|
| E1 | `lib/screens/oidc_login/` has zero `AuditLogService`/`audit_log_service`/`sso_audit_log` references; storage is `SessionStorage` only | `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → exit 1 (all 28 module files clean) ✅. **"SessionStorage only" is FALSE** — `trusted_device_token.dart:12-22` uses `LocalStorage` (see D3). | ⚠️ zero-reference half exact; "SessionStorage only" half false |
| E2 | `audit_log_service.dart:33` → `_maxEntries = 1000` at `:65`, `_storageKey = 'sso_audit_log'` at `:66` | `static const int _maxEntries = 1000;` at `:65`, `_storageKey` at `:66`, `record()` `:70-76`, `clear()` `:101-104`, `LocalStorage.setItem(_storageKey,…)` at `:111` | ✅ (correction holds) |
| E3 | `snaplink_admin_api.dart:81-84` sole ring writer, `:322-324` non-GET guard | `void _recordAudit` `:81`, `AuditLogService().record(` `:82`, `AuditEntry(` `:83`; `// Record mutation in audit log` `:322`, `if (method != 'GET')` `:323`, `_recordAudit(...)` `:324`; `AuditLogService` referenced in exactly 3 `lib/` files (api, service, tab) | ✅ exact |
| E4 | `audit_log_tab.dart:16` still `const AuditLogTab({super.key})`, ring-fed; reads at `:43/:132`, subtitle `:158` | `class` `:15`, `const AuditLogTab({super.key})` `:16`, `_logService = AuditLogService()` `:22`, `_logService.entries` at `:43` (`_refresh`) and `:132` (`_errorRate`), subtitle at `:158`; **no `SnaplinkAdminApi` import** → B6-1 not landed | ✅ exact (corrections hold) |
| E5 | `governance_tab.dart:31` `_auditPath`; `_queryAudit` at `:167-183`, `api.get` at `:183` | `_auditPath = '/api/v1/audit/events'` `:31`, `_facetPath` `:32`, `_queryAudit()` `:167-183`, `AuditQuery.fromJson` `:172`, `toQueryParameters()` `:177`, `widget.api.get(_auditPath, query: parameters)` `:183` | ✅ exact (correction holds) |
| E6 | `implementation-gate.md:56` B6-1 console row: ring → debug-only, T-12 devtools 伪造不再构成证据 | Line 56 verbatim: "读路径接入（F-06）：审计页调 sink 读 API（tenant_id + trace_id 经 BFF）；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据" | ✅ exact |

### 0.3 Supplemental evidence

| # | Claim | Verified reality | Verdict |
|---|---|---|---|
| S1 | `OidcLoginApi({http.Client? httpClient, Uri? baseUri})` | Constructor `:31-35` with `timeout` default 30s; `login()` → `_postOutcome('../auth/login', payload)` `:57-58`; `loadBranding()` → `_http.get(_resolve('../branding'))` `:84` | ✅ exact |
| S2 | `OidcLoginScreen(api:, defaultClientId:, routeUri:)` | `:58-62` const ctor with all three optional params | ✅ exact |
| S3 | `_LoginHarness` precedent (class `:26-74`, pump `:67`, submit `:88`) | Class at `:26`; MockClient keyed on `POST /auth/login` with D9 filter `body['credential'] is Map`; mount-time probe counted separately (`probePosts`); `submit` = Username/Password `enterText` + `FilledButton 'Sign in'` tap; **file green at HEAD** | ✅ exact |
| S4 | `_api(routes)`/`_caps(paths)` harness (`admin_governance_security_test.dart:12-32`) | `_api` `:12-22` path-keyed MockClient; `_caps` `:24-30` → `SnaplinkAdminCapabilities` of `SnaplinkAdminEndpoint(method: 'GET', path:, feature: 'core')`; `SnaplinkAdminCapabilities.has` at `snaplink_admin_types.dart:94` | ✅ exact |
| S5 | Census-test pattern (`@TestOn('vm')`, `dart:io` scan, literal-split trick) | `oidc_login_handle_success_census_test.dart:1-9` `@TestOn('vm')` + `dart:io`; module scan at `:97-104`; split-literal census group present; **file green at HEAD** | ✅ exact |
| S6 | `LocalStorage.keys()` deterministic on VM; singleton `AuditLogService` with `record()`/`clear()` | `local_storage.dart:11-22` (`keys()` at `:21`); `local_storage_memory.dart:1-13` top-level map; `AuditLogService` singleton `:58-60`; `AuditEntry` named ctor `{timestamp, method, path, statusCode, label}` `:13-18`, `toJson` `:36-42` (ISO-8601 timestamp) | ✅ exact |
| S7 | B6-1 not landed; pipeline runs stopped pre-implementation | `audit_log_tab.dart` has no api/capabilities params (E4); run dirs `rewire-…`, `wire-…`, `b6-1a-…` present with no landed change; `state.jsonl` shows B6-1a/B6-1b directions in the campaign | ✅ |
| S8 | B6-1 surface: `AuditLogTab({required SnaplinkAdminApi api, required SnaplinkAdminCapabilities capabilities})` | `b6-1a-lib-api-auditlogtab-server-read-spec.md` REQ-2 verbatim; mapper per REQ-4/REQ-5; `SnaplinkAdminApi({required baseUrl, required accessToken, httpClient})` `:35-42`; `DataCache` is in-memory (no `LocalStorage`) | ✅ exact |

### 0.4 Defects found in the upstream acceptance contract (this design's corrections)

**D1 — AC-1 Phase A step 3 is self-contradictory (unsatisfiable as written).**
Step 1 pre-seeds the ring via `AuditLogService().record(...)`, which synchronously calls `_save()` → `LocalStorage.setItem('sso_audit_log', jsonStr)` (`audit_log_service.dart:110-111`). Step 3 then asserts `LocalStorage.keys()` does **not** contain `'sso_audit_log'`. After a successful seed the key is *necessarily present*, so a literal implementation fails at HEAD with zero `lib/` edits — contradicting the spec's own "green at HEAD" premise. **Correction (§1.2):** snapshot `LocalStorage.keys()` **and** `LocalStorage.getItem('sso_audit_log')` immediately after seeding; after the login flow assert (a) keys-set equality with the post-seed snapshot, (b) stored-value string equality with the post-seed snapshot, (c) `AuditLogService().count` and entry identity unchanged. (a)+(b) detect a net-zero rewrite (write-then-restore); (c) detects an in-memory-only write.

**D2 — AC-1 Phase B step 7's exact path set `{/auth/login, /api/v1/audit/events}` is not achievable.**
The login leg's mount fires, unconditionally, `_loadBranding()` → `GET /branding` (`oidc_login_screen.dart:210` → `oidc_provider_flow.dart:211-214` → `oidc_login_api.dart:84`), plus the credential-less probe `POST /auth/login` (`_probeProviders`, fired when `defaultClientId` is set and the route has no `prompt=none` — the exact harness configuration). The observed path set is therefore `{/auth/login, /branding, /api/v1/audit/events}` (with `/auth/login` appearing twice). The spec's own parenthetical "(no other audit endpoints)" reveals the real intent: a **negative space over the audit surface**. **Correction (§1.3):** assert (a) the audit-surface intersection — the set of observed request paths containing `audit` — is exactly `{/api/v1/audit/events}` (no `/api/v1/audit/facets`, no other audit endpoint), (b) the full observed path set is `{/auth/login, /branding, /api/v1/audit/events}`, (c) exactly **one credential-bearing** login POST (D9 filter — the probe is not a login request), (d) no ring write (key-absence, Phase B does not seed).

**D3 — AC-3's verification leg "grep `LocalStorage` in `lib/screens/oidc_login/` → exit 1 (today only `SessionStorage` appears)" is false at HEAD.**
`lib/screens/oidc_login/trusted_device_token.dart:12-22` contains `LocalStorage.getItem` (`:12`), `LocalStorage.setItem` (`:17`), `LocalStorage.removeItem` (`:22`) — grep exits 0, and the module's login flow calls `TrustedDeviceToken.store/read/clear` (`oidc_authorization_flow.dart:143,296,371`; `oidc_challenge_flow.dart:9`). This is **legitimate, ring-unrelated storage**: key namespace `snaplink_trusted_device:<clientId>` (never `sso_audit_log`), and every operation is `kIsWeb`-gated (`:11,16,21`), so on VM widget tests it is a deterministic no-op. **Correction (§1.2/§2):** the AC-3 verification leg is re-scoped from "no `LocalStorage` anywhere" to the actual REQ-1 floor — `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → exit 1 (this is AC-2's grep, verified exit 1) — and `TrustedDeviceToken` is documented as an in-scope-but-permitted exception with its namespace pinned. REQ-1/REQ-2 (ring-scoped) are unaffected; the AC-2 guard must **not** ban bare `LocalStorage`.

**D4 — harness is private; cannot be imported.** `_LoginHarness` is file-private to `test/oidc_login_screen_client_id_test.dart`. The new tests must replicate the pattern (see §1.2/§1.3, deliberate duplication), not import it. Drift risk with the sibling B6-2 constantization of that file is mitigated by contract-level assertions (D9 filter, probe counting) in the new files.

**D5 — client_id literal census pins `test/` (discovered by executing Step 1).** `test/oidc_login_handle_success_census_test.dart:136-161` scans every top-level `test/*.dart` file for the quoted contract client_id literal and pins the *exact* site map (`test/sso_client_test.dart:18`, `test/oidc_account_flow_test.dart:35,75,115,160`, `test/oidc_login_screen_client_id_test.dart:76,136,158`) while the sibling constant `SSOAdminClient.firstPartyClientId` is absent. A new test file carrying the literal (even in a comment) breaks the census — verified live: the first draft of `test/oidc_login_ring_isolation_test.dart` failed the census at HEAD. **Correction (§1.2/§2.9):** new files use a distinct non-contract harness clientId (`'ring-isolation-test-client'` — any non-empty value fires the mount probe identically; the wire value is B6-2's scope and neither AC-1 phase asserts it). The literal must also be absent from comments; the split-literal trick applies to test/ scans as well.

## 1. API changes

**No production-code change.** `lib/screens/oidc_login/**` stays untouched (REQ-1 floor already met at HEAD — zero references to the three banned literals). `lib/api/snaplink_admin_api.dart`, `lib/services/audit_log_service.dart`, `lib/screens/admin/*` are out of scope (B6-1/B6-1b). The change set is three test files plus two grep forms.

### 1.1 New file `test/oidc_login_audit_visibility_guard_test.dart` — static import guard (REQ-1 / AC-2, lands at HEAD)

Census pattern per S5: `@TestOn('vm')`, `dart:io`, single `group('oidc_login audit-visibility boundary')`.

```dart
@TestOn('vm')
library;
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const moduleDir = 'lib/screens/oidc_login';
  // Split literals so this guard file can never trip its own scan
  // (and survives a future widening of the scan root to test/).
  const banned = ['AuditLog' 'Service', 'audit_log_' 'service', 'sso_audit_' 'log'];
  test('zero ring references in the module (REQ-1 floor)', () {
    final offenders = <String, List<String>>{};
    for (final entity in Directory(moduleDir).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final hits = [
        for (final needle in banned)
          if (File(entity.path).readAsStringSync().contains(needle)) needle,
      ];
      if (hits.isNotEmpty) offenders[entity.path] = hits;
    }
    expect(offenders, isEmpty,
        reason: 'module must keep zero AuditLogService/audit_log_service/'
            'sso_audit_log references (debug-only ring boundary)');
  });
}
```

Design rules:
- Scan root is the module directory only — **not** `test/` (the sibling files legitimately name the ring) and **not** other `lib/` subtrees (owned by the existing audit-contract guard).
- Substring semantics, no allowlist: any identifier, comment, or string containing a banned needle trips the scan. This is the contract — the module must not even *mention* the boundary (spec REQ-1: "no string literals").
- Literal-split applied to all three needles (`'AuditLog' 'Service'` is a compile-time concatenation; the source text contains neither half-needle, and the guard file is outside the scan root anyway).
- Failure message lists offender files + matched needles (no silent red).
- Grep form for CI / joint gate: `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → **exit 1**. Verified at HEAD; a forgotten import fails this immediately.

### 1.2 New file `test/oidc_login_ring_isolation_test.dart` — AC-1 Phase A, behavioral isolation (REQ-2, lands at HEAD)

Widget test replicating the `_LoginHarness` pattern (S3; D4 duplication decision). Structure:

1. **Seed (deterministic):** in `setUp`, `AuditLogService().clear()`; in the test body, `AuditLogService().record(AuditEntry(timestamp: DateTime.now(), method: 'POST', path: '/api/v1/admin/forged', statusCode: 200, label: 'forged'))` (ctor per S6). Immediately snapshot:
   - `final keysBefore = LocalStorage.keys();` (contains `'sso_audit_log'` — the seed writes it, D1)
   - `final valueBefore = LocalStorage.getItem('sso_audit_log');` (JSON array with the forged entry, `audit_log_service.dart:110-111`)
   - `final countBefore = AuditLogService().count;` (1)
   - `final entriesBefore = AuditLogService().entries;`
   - `addTearDown(AuditLogService().clear);`
2. **Login leg:** pump `OidcLoginScreen(api: OidcLoginApi(baseUri: Uri.parse('https://sso.example/'), httpClient: mockClient), defaultClientId: 'ring-isolation-test-client', routeUri: Uri.parse('https://sso.example/login/'))` — **distinct non-contract clientId** (D5: the census pins the contract literal's site map across `test/`; the wire value is B6-2's scope and is not asserted here); mock = replicated harness (path-keyed; `POST /auth/login` with `body['credential'] is Map` → 200 `{"access_token":"t","session_id":"s"}`; probe/branding/else → 404 `{}`; per-request path recorder). `addTearDown(api.close)`. Submit via replicated `submit` (Username `ada@example.com` / Password → `FilledButton 'Sign in'`), `pumpAndSettle`.
3. **Assert (corrected D1):**
   - exactly **one credential-bearing** login POST (`loginPosts == 1`; probe counted separately and **not** a login);
   - `LocalStorage.keys()` set-equals `keysBefore` (no new key appeared);
   - `LocalStorage.getItem('sso_audit_log')` string-equals `valueBefore` (no rewrite — catches write-then-restore);
   - `AuditLogService().count == countBefore` and entries list identical (same length, same fields);
   - observed request paths contain no `/api/v1/audit` prefix (module's HTTP surface is `OidcLoginApi` only, REQ-2).
4. **Teardown ordering rule:** the seed test file never asserts *absence* of the key after any seed (`clear()` rewrites `'[]'`, key persists) — absence assertions live in the Phase B file (§1.3), which never seeds.

Determinism note: `TrustedDeviceToken` ops are `kIsWeb`-gated no-ops on VM (D3), so the login flow provably cannot touch `LocalStorage` in this test other than through the ring path under test.

### 1.3 New file `test/oidc_login_audit_timeline_joint_test.dart` — AC-1 Phase B, joint contract (REQ-3/REQ-4, lands with B6-1's change set)

Compiles only against the B6-1 surface (S8): `AuditLogTab(api:, capabilities:)`. Single **path-keyed** MockClient (S4 pattern) serving all four requests:

| Request (observed at mount+submit+mount) | Mock response |
|---|---|
| `POST /auth/login` (probe, no `credential`) | 404 `{}` (absence) |
| `GET /branding` (unconditional `_loadBranding`) | 404 `{}` (absence) |
| `POST /auth/login` (credential-bearing, D9 filter) | 200 `{"access_token":"t","session_id":"s"}` |
| `GET /api/v1/audit/events` (B6-1 tab) | 200 body whose rows include `{"method": "POST", "path": "/auth/login", "status": 200, "label": "auth.login.success"}` (REQ-4 fixture; legacy fallback vocabulary — the B6-1a mapper's defensive chain `label→type`, `path`, `status` renders it; if the mapper's legacy fallback is later removed, this fixture moves to the real schema `type/outcome/…`, see §2) |

Sequence: (a) login leg exactly as §1.2 (same harness replication, same mock object); (b) `SnaplinkAdminApi(baseUrl: 'https://sso.example.test', accessToken: 'admin-token', httpClient: sameMock)` + `_caps`-style `SnaplinkAdminCapabilities([SnaplinkAdminEndpoint(method: 'GET', path: '/api/v1/audit/events', feature: 'core')])`; pump `AuditLogTab(api:…, capabilities:…)`; `pumpAndSettle`. `addTearDown(api.close)` on the **login client only** — `SnaplinkAdminApi` has **no `close` member** (`snaplink_admin_api.dart:25`, verified; the S4 `_api` precedent performs no teardown), so the joint file's teardown is login-client-only (N1); the admin leg needs none.

Asserts (corrected D2):
- server-returned row renders: `find.textContaining('auth.login.success')` (EVENT column) and `find.textContaining('/auth/login')` (PATH column); entries counter shows the server count (1);
- **audit-surface intersection**: observed paths containing `'audit'` == exactly `{'/api/v1/audit/events'}` (no facets, no other audit endpoint);
- **full path set**: `{/auth/login, /branding, /api/v1/audit/events}`;
- exactly one credential-bearing login POST (D9 filter);
- `LocalStorage.keys()` does **not** contain `'sso_audit_log'` after the whole flow (this file never seeds — absence is assertable here, D1; the `DataCache` default in `SnaplinkAdminApi` is in-memory and the B6-1 tab's `get(path, query:)` bypasses it, so no cache→storage write).

### 1.4 Grep forms (CI / joint gate, no new files)

```sh
# AC-2 (REQ-1 floor) — must exit 1
grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/
# AC-3 module obligation (re-scoped per D3) — must exit 1
grep -rn "AuditLogService\|sso_audit_log\|audit_log_service" lib/screens/oidc_login/
```

The AC-3 "no bare `LocalStorage`" grep is **withdrawn** (D3): it fails at HEAD and would criminalize `TrustedDeviceToken`. Its replacement is the REQ-1 grep above plus the namespace pin (§2).

### 1.5 Ring-liveness pin — `test/snaplink_admin_api_test.dart` (security-review gap-d closure, lands at HEAD)

Every guard above asserts the ring is *unchanged* (Phase A snapshot equality) or *absent* (Phase B key absence) — all vacuously green for a dead writer. The security review rated this **HIGH (d)**. The closure is a liveness pin inside the existing admin-API test file (group `ring liveness — successful mutations land in the audit ring`):

- **Positive:** for each of POST/PUT/DELETE through a `MockClient` answering 200, `AuditLogService().count` must be exactly `before + 1` **and** `LocalStorage.getItem('sso_audit_log')` must decode to a list whose newest entry carries the exact `method` / `path` / `statusCode`, with the path query-free (exact equality + `isNot(contains('?'))`, and the mock asserts `request.url.query` is empty on the wire). Both halves are load-bearing: the stored-value half is what catches a write that is skipped in-memory-after-insert (count-only guards are blind to it).
- **Negative:** a 200 GET must leave count and the stored value byte-identical (pins the `method != 'GET'` predicate so the pin cannot degrade into "record everything").

## 2. Compatibility constraints

1. **B6-1 not landed ⇒ Phase B file must not exist before B6-1.** `test/oidc_login_audit_timeline_joint_test.dart` references `AuditLogTab(api:, capabilities:)`; at HEAD the ctor is `const AuditLogTab({super.key})` (`audit_log_tab.dart:16`) and the file would not compile. The file ships **inside B6-1's change set**, in the same commit as the tab rewrite and the `test/admin_support_tabs_test.dart:88,149` updates (b6-1a AC-5). It is a compile-time latch: the merge cannot silently land a mismatched surface.
2. **Zero edits to existing files.** No `lib/` edits; no edits to `test/oidc_login_screen_client_id_test.dart` (the sibling B6-2 constantization co-change touches it — avoid cross-direction coupling), no edits to `test/admin_support_tabs_test.dart` (B6-1's), no edits to the audit-contract guard suite (disjoint scope: it scans `lib/` audit-path/BFF literals; the new guard scans only the module dir for ring identifiers).
3. **Harness duplication is deliberate (D4).** `_LoginHarness` is private to its file; the new files replicate it with the D9 filter and probe counting preserved verbatim in behavior. Drift is bounded by contract-level assertions in both new files (exactly-one credential-bearing POST; probe ≠ login).
4. **Isolate isolation.** `LocalStorage` memory store and the `AuditLogService` singleton are per-test-isolate (`local_storage_memory.dart:1-13`); `flutter test` files run in separate isolates ⇒ no cross-file pollution. Within-file ordering rules: seeding files never assert key absence (§1.2); absence assertions live in the never-seeding Phase B file (§1.3).
5. **`TrustedDeviceToken` is a permitted, pinned exception (D3).** The module legitimately uses `LocalStorage` under the `snaplink_trusted_device:` namespace, `kIsWeb`-gated. The AC-2 guard bans only `AuditLogService`/`audit_log_service`/`sso_audit_log` — it must never be widened to bare `LocalStorage` without exempting this file. A future key under the ring name inside this module trips AC-2 immediately. One-line security note (rec 4): the exception stores a **bearer-equivalent MFA-skip grant at rest** (`trusted_device_token.dart:10-22`, localStorage, XSS-readable, no httpOnly equivalent) — pre-existing, out of audit scope, consciously accepted here so the exception is a known risk, not an oversight.
6. **Fixture vocabulary vs B6-1 mapper.** The REQ-4 fixture (`method`/`path`/`status`/`label`) renders because the approved B6-1a mapper keeps legacy ring vocabulary as a defensive fallback (`b6-1a design §1.1 rule 3`). If that fallback is ever removed, the joint fixture must be rewritten to the real schema (`type`/`outcome`/…) — the same commit, same review.
7. **REQ-3 census stays green.** The joint/ring tests never introduce `'auth.login.success'` into `lib/` (only into a `test/` fixture) — the existing census pin (`oidc_login_handle_success_census_test.dart:97-104`) scans the module only and stays green.
8. **engineering.yaml** `max_lines: 400` ignores `_test.dart`; `complexity` ignores tests — no check friction. `flutter analyze` must stay clean (no unused imports in new files).
9. **client_id literal census (D5, live-verified).** `test/oidc_login_handle_success_census_test.dart:136-161` pins the exact map of `test/*.dart` files carrying the quoted contract client_id literal while `SSOAdminClient.firstPartyClientId` is absent. New test files must not carry the literal in code **or comments**; harnesses use a distinct non-contract value (probe semantics are value-independent). When the sibling M2 commit introduces the constant, the census flips to zero-hits and all sites (including the B6-2 harness, not these files) must use the constant.

## 3. Failure modes

**Recording predicate at HEAD — stated explicitly (security rec 2).** `lib/api/snaplink_admin_api.dart:322-324` records **successful (`2xx`) `_request`-routed non-GET mutations only**: the `_recordAudit` call sits inside the `2xx` branch behind `if (method != 'GET')`. Three consequences, accepted and pinned here: (1) **failed mutations are unrecorded** — every 403/422/5xx (the highest-value audit events) is invisible; e.g. `dashboard_screen.dart:204-207` ignores the logout POST result, so a failed logout is unrecorded (F13); (2) **`postDownload` bypasses `_request` entirely** — `SnaplinkAdminDownloadTransport` has zero audit references, so the export POST is unrecorded (F14; scope call in §6); (3) the guard is **method-based, not semantics-based** — the `switch (method)` at `:319-326` throws `ArgumentError` outside GET/POST/PUT/PATCH/DELETE, so HEAD/OPTIONS are unissuable today, but if HEAD is ever added `method != 'GET'` would audit a safe read as a mutation. One-line note (rec 4): `_recordAudit` passes the raw `path` (`:324`) — a caller embedding a query (`post('/x?reason=…')`) would land it in both `path` and `label`; no current call site does (audited paths are query-free, carrying only `Uri.encodeComponent`'d resource IDs — identifiers, not credentials), and callers must keep them so.

| # | Failure | Detection | Mitigation |
|---|---|---|---|
| F1 | Implementer adds a doc comment mentioning the boundary ("the `sso_audit_log` ring is out of scope") | AC-2 guard trips (substring scan, no allowlist) | Spec REQ-1 already bans the literals in comments; guard failure lists offender files. Red, not silent — intended. |
| F2 | Guard defeated by literal obfuscation in `lib/` (`'sso_audit_' 'log'` concatenation) | Undetectable by substring scan | Accepted limitation; the behavioral test (§1.2 ring-snapshot equality) still catches any actual write; review gate. The guard's own split-literal trick is *not* a loophole in `lib/` — it is a documented scan boundary. |
| F3 | Phase A implemented literally from the spec (D1): pre-seed then assert key absence | Test fails at HEAD (unsatisfiable) | Corrected snapshot assertions (§1.2 step 3) — keys-set equality, stored-value equality, count/entries equality. |
| F4 | Phase B path-set asserted as the spec's literal `{/auth/login, /api/v1/audit/events}` (D2) | Fails on the unconditional `GET /branding` (and probe is a second `/auth/login` hit) | Corrected assertions (§1.3): audit-surface intersection exact; full set `{/auth/login, /branding, /api/v1/audit/events}`; D9-filtered login count. |
| F5 | Ring pollution across tests in the Phase A file (`clear()` rewrites `'[]'`, so the key persists after teardown) | Later absence assertions fail spuriously | Absence assertions live only in the never-seeding Phase B file; Phase A uses setUp-clear + seeded snapshots; ordering rule §2.4. |
| F6 | `pumpAndSettle` hangs on pending timers (`OidcLoginApi` 30s timeout, `SnaplinkAdminApi.requestTimeout`) | Timeout failure | Replicated harness calls `addTearDown(api.close)` on the **login client only** — `SnaplinkAdminApi` has no `close` member (`snaplink_admin_api.dart:25`, N1); the admin leg follows the S4 `_api` precedent (synchronous mock, no teardown); precedent file green at HEAD proves the pattern. |
| F7 | MockClient routing collision (`/auth/login` probe vs login POST; audit GET vs `/branding`) | Wrong counts/paths | Path-keyed exact match (S4) + D9 filter distinguishes probe from login; audit routes matched only by exact path. |
| F8 | B6-1 surface drift (param rename/requiredness) after Phase B lands | Compile error at B6-1 merge | Phase B ships inside B6-1's commit (§2.1); drift is a merge-time compile failure, never silent. |
| F9 | A future module feature reads the ring (e.g., a "show local events" toggle) — the AC-3 forgery barrier weakens | AC-2 grep goes red (ring key + service identifiers banned) | REQ-1 floor is the barrier; b6-1a AC-2 (forged ring never renders) is B6-1's test, out of this change set. |
| F10 | `find.textContaining('auth.login.success')` matches unintended text (fixture echo, error state) | Ambiguous pass | Fixture contains exactly one such row; B6-1 tab's defensive mapper renders it once; if ambiguity arises, scope the finder to the data-table EVENT column. |
| F11 | Timestamp nondeterminism in stored-value equality (ISO-8601 with sub-second precision) | Flaky equality | Snapshot and compare the *stored JSON string* captured post-seed — both sides come from the same `toJson` render; no wall-clock comparison. |
| F12 | B6-1b later wraps ring `_save` in `kDebugMode` | Test-env-visible direction caught by the liveness pin (F13); release-only direction residual | `kDebugMode` is true under `flutter test`; the pin (F13) fails on the debug-skip direction; a release-only skip (`if (!kDebugMode) return`) is unobservable in the test environment and stays a review gate at B6-1 landing. |
| F13 | Ring write silently skipped — `kDebugMode`-gated `_save`, gutted `record()`, deleted `_recordAudit`. The isolation guards are vacuously green for a dead writer (security review gap (d), HIGH) | Ring-liveness pin (§1.5): count delta +1 AND stored `sso_audit_log` entry | Landed at HEAD 2026-08-07; mutation-proven against all three forms (each fails the pin live, then reverted). |
| F13 | Failed mutation (403/422/5xx) not recorded — the predicate fires only inside the `2xx` branch (`:322-324`) | Undetectable by this change set; no failure label exists in-repo (b6-1a E13: no response schema) | Accepted, predicate documented above; console-side failed-login rendering is undefined/untested pending a schema; server-side login outcomes are covered by the gate's own contract (`implementation-gate.md` aero-id row) |
| F14 | `postDownload` export POST unrecorded — `SnaplinkAdminDownloadTransport` has zero audit references (`snaplink_admin_download_transport.dart:28-47`; sole caller `tenant_organizations_tab.dart:213`) | Undetectable by this change set | Explicit scope call in §6: zero `lib/` edits preserved here; recommended routing through `_recordAudit` (path-only) rides with B6-1's change set |

### 3.1 Interim audit-integrity window (accepted risk, HEAD → B6-1 landing) — security rec 3

Until B6-1 lands, the ring remains the **only** audit record *and* the display path (`audit_log_tab.dart` is still ring-fed, E4). In that window it is **forgeable and clearable**: a public singleton with `record()`/`clear()` (`audit_log_service.dart:58-60,70-76,101-104`), a UI "Clear log" action (`audit_log_tab.dart:180-192`), plaintext JSON, client-generated timestamps, no hash chain/MAC/sequence — devtools can rewrite it at will. It is also **silently lossy**, with two swallow layers: `_save`/`_load` try/catch (`audit_log_service.dart:108-124`, `debugPrint` only) and `local_storage_web.dart:17-21` swallowing every `setItem` error — privacy-mode/quota drops and corrupt stored JSON each silently yield an empty ring. Gate line 56's demotion (ring → debug-only; "devtools 伪造不再构成证据") ships *with* B6-1 — until then the forgeability is live, not theoretical. **Accepted; no integrity machinery is added here** (tamper-evidence properties are B6-1's concern, not this change set's). **Dated review point: B6-1 landing** — re-confirm the demotion landed, the §6 F14 routing decision, and re-read F13/F14 in B6-1's review.

## 4. Migration steps (ordered; each step leaves the tree green)

1. **Step 1 — now, at HEAD (zero `lib/` edits).** Land `test/oidc_login_audit_visibility_guard_test.dart` (§1.1), `test/oidc_login_ring_isolation_test.dart` (§1.2), and the ring-liveness pin in `test/snaplink_admin_api_test.dart` (§1.5). **Implemented and green** — the original 2026-08-07 validation was +26 (step-1 11/11 + pin file 15/15); the current pin file is **19/19** after the 2026-08-20 F12 transport additions. `flutter analyze` remains clean; both grep forms exit 1. The live run additionally surfaced D5 (census pin) and confirmed the D1 snapshot corrections and the D3 `kIsWeb` determinism. Green checks: the same guard/ring suites plus the F12 query-dedup group; `grep -rn "AuditLogService\|audit_log_service\|sso_audit_log" lib/screens/oidc_login/` → exit 1; `flutter analyze` clean.
2. **Step 2 — with B6-1's change set (same commit).** Land `test/oidc_login_audit_timeline_joint_test.dart` (§1.3) together with the `AuditLogTab` rewrite and the `test/admin_support_tabs_test.dart` updates (b6-1a AC-5). Green checks: full `flutter test`; the joint file's audit-surface intersection assertion (§1.3) pins the negative space once the tab issues `GET /api/v1/audit/events`. The §3.1 review point fires with this commit: ring demotion per gate line 56, the §6 F14 routing decision, and the F13/§3.1 re-read.
3. **Step 3 — joint gate (T-12 evidence, B6-1b).** Run the §1.4 grep pair (both exit 1); run b6-1a AC-2 (forged `sso_audit_log` never renders — B6-1's own test); run the joint file. Record gate output in the run artifact per campaign convention; `docs/auto/state.jsonl` entry for this direction moves to `design`/`implement` with the evidence pointers.

Rollback: any step is revertible independently; Step 1 files are standalone and cannot affect Step 2's compile surface.

## 5. Testable acceptance mapping

| Acceptance (spec) | Enforced by | Concrete assertion | Lands |
|---|---|---|---|
| AC-1 Phase A — joint login, ring untouched (module half) | `test/oidc_login_ring_isolation_test.dart` (§1.2) | one credential-bearing POST (D9); keys-set equality vs post-seed snapshot; stored `sso_audit_log` value byte-identical; count+entries identical; no `/api/v1/audit` request path (D1-corrected); harness clientId is a distinct non-contract value (D5) | **HEAD — implemented, green** |
| AC-1 Phase B — joint login → timeline rendering, ring untouched (timeline half) | `test/oidc_login_audit_timeline_joint_test.dart` (§1.3) | `textContaining('auth.login.success')` + `textContaining('/auth/login')` render from the single mock's `GET /api/v1/audit/events` response; counter = server count; audit-path set == `{/api/v1/audit/events}`; full path set `{/auth/login, /branding, /api/v1/audit/events}`; no `sso_audit_log` key (D2-corrected) | with B6-1 |
| AC-2 — static import guard | `test/oidc_login_audit_visibility_guard_test.dart` (§1.1) + grep | recursive scan of 28 module files → zero hits for the three split-literal needles; grep form exit 1 | **HEAD — implemented, green** |
| AC-3 — devtools-forged ring never renders | B6-1a AC-2 test (B6-1's change set) + module obligation §1.4 | forged path/method/status never renders (B6-1's test); module keeps zero ring references (REQ-1 grep, D3-corrected — bare-`LocalStorage` grep withdrawn, `snaplink_trusted_device:` namespace pinned as the permitted exception) | HEAD (obligation) / B6-1 (rendering) |
| REQ-1 floor | AC-2 guard | as above | HEAD |
| REQ-2 isolation | AC-1 Phase A | as above | HEAD |
| Ring liveness (gap-d closure) | §1.5 pin `test/snaplink_admin_api_test.dart` | POST/PUT/DELETE via MockClient → count exactly +1 and stored `sso_audit_log` newest entry {method, query-free path, statusCode}; GET → no record, stored value byte-identical | **HEAD — implemented, green** |
| REQ-3 no fabrication | census pin `oidc_login_handle_success_census_test.dart:97-104` (existing, stays green) + Phase B origin assertion | `auth.login.success` absent from `lib/screens/oidc_login/`; the rendered row originates solely from the mock-served server response | HEAD (census) / B6-1 (origin) |
| REQ-4 joint contract | AC-1 Phase B | single path-keyed MockClient serves all four requests; login leg via `OidcLoginApi(baseUri:, httpClient:)`; timeline leg via `SnaplinkAdminApi(..., httpClient: sameMock)` + `AuditLogTab(api:, capabilities:)` per b6-1a REQ-2 | with B6-1 |

## 6. Out of scope (hard boundary, per spec §5)

`lib/screens/admin/audit_log_tab.dart` rewiring and `test/admin_support_tabs_test.dart` updates (B6-1), ring demotion/debug labeling (B6-1b), `lib/api/snaplink_admin_api.dart` ring writer (unchanged — including its recording predicate as stated in §3: 2xx `_request`-routed non-GET only; failures and `postDownload` unrecorded, F13/F14), `client_id` wire values (B6-2 — the joint test asserts rendering of a server-returned `auth.login.success` row, **not** the wire value or sink emission), `AuditQuery`/facets surface (B6-1), `tests/integration/audit_login_drill.py` (device-leg sibling). `TrustedDeviceToken` (`snaplink_trusted_device:` namespace) is in-scope only as a documented, pinned exception to the AC-3 verification leg — its behavior is unchanged (credential-at-rest note: §2.5).

**`postDownload` audit routing — explicit scope call (F14).** The export POST (`SnaplinkAdminApi.postDownload`, `snaplink_admin_api.dart:245-251` → `SnaplinkAdminDownloadTransport.post`, `snaplink_admin_download_transport.dart:28-47`; sole caller `tenant_organizations_tab.dart:213`) is unrecorded at HEAD. **Decision: preserve zero `lib/` edits in this change set** — routing it through `_recordAudit` requires a `lib/api/` change (the transport would have to surface the response status: `SnaplinkAdminDownload` carries only `bytes`/`contentType`/`filename`, `snaplink_admin_types.dart:76-86`), which is B6-1's territory and would break this change set's zero-edit premise. **Recommendation: route `postDownload` through `_recordAudit` (path-only, no PII risk) in B6-1's change set** — same commit as the ring demotion, with a write-assertion in `test/snaplink_admin_api_test.dart` (currently 0 audit references); until then the exclusion is pinned here as F14 and re-read at the §3.1 review point.

**F2 is an accepted, §3-documented limitation — named here per review (N2).** The static residual — an obfuscated-literal mention of a banned needle in `lib/` *without* a write — is undetectable by substring scan and is therefore out of this change set's guarantee: detection is behavioral (§1.2 ring-snapshot equality catches any actual write) with a review gate at B6-1 landing (same review point as §3.1).
