# B6-2 Requirements Specification — Exactly-once pin on the last unpinned login leg (direct `SSOAdminClient.login`) + single-source `firstPartyClientId` verification

Module: `lib/screens/device` (analysis bucket `docs/auto/analyses/lib-screens-device-fb030ae1.json`) · Direction: B6-2 ("Branch B 收尾") · Value: 9 · Risk reduction: 9 · Effort: 3 · Confidence: 9
Status: implemented
Completes: `b6-2-lib-screens-device-client-id-alignment-spec.md` REQ-0/AC-2 (the "唯一未满足项" at the time that spec was written — see §1 correction 1)
Sibling instances (shared artifacts, single change set): `b6-2-lib-api-client-id-alignment-spec.md` + `-design.md`, `b6-2-lib-screens-*-client-id-alignment-spec.md`

---

## 1. Verification outcome

Every citation in the direction was re-checked against the repository at HEAD (`40acef7`, working tree includes only B6-1/B6-1c edits outside this direction's files). **One central claim is stale: the `firstPartyClientId` constant HAS landed** (commit `db6e435 feat(b6-2): firstPartyClientId single-source constant (Branch B)`, an ancestor of HEAD). The two genuinely open acceptance items are the **direct-leg request counter** (item 1) and the **`lib/` single-source census clause** (item 3).

| Direction citation | Verification result at HEAD |
|---|---|
| `lib/screens/device/device_verify_screen.dart:172-181` — `_redirectToLogin` → `/login/?redirect=/device/verify…`; call sites `:76`, `:226`, `:369` | **Exact.** `:172` `void _redirectToLogin()`; `:174-177` target `Uri(path: '/device/verify', queryParameters: code.isEmpty ? null : {'user_code': code})`; `:178-180` `ProductApiOrigin.baseUri.resolve('/login/').replace(queryParameters: {'redirect': target})`; `:181` `BrowserNavigation.replaceLocation(login.toString())`. Call sites verified: `:76` (initState, no session — the primary device-entry leg), `:226` (`_verify`, token null/empty — re-entry after expiry), `:369` (`signInAgain` `onPressed: _redirectToLogin`). The device module never POSTs `/auth/login` itself; its login wire is decided downstream at `app_router.dart:35-39`. |
| `lib/app_router.dart:35` — `OidcLoginScreen defaultClientId: 'sso-admin-console'`, "second literal site" | **Stale.** `:35` is `ProductEntry.login => OidcLoginScreen(`; `:36` now reads `defaultClientId: SSOAdminClient.firstPartyClientId,` — constantized at `db6e435`. No literal remains at this site. |
| `lib/api/sso_client.dart:86,92` — `login()` default `'sso-admin-console'` and `'client_id'` wire, "first literal site" | **Stale.** Constant at `:82` `static const String firstPartyClientId = 'sso-admin-console';` (doc comment `:78-81`); `login()` at `:89-108` with default `String clientId = firstPartyClientId` at `:92`; POST `/auth/login` at `:96`; `'client_id': clientId` wire at `:98`. Sole `lib/` literal site — verified by `grep -rn "'sso-admin-console'" lib/ test/` → exactly one hit (`lib/api/sso_client.dart:82`). |
| `test/sso_client_test.dart:10-27` — whole-body assertion, zero request counting | **Exact — the open gap.** `:10-30` first test asserts the full POST `/auth/login` body (`:18` `'client_id': SSOAdminClient.firstPartyClientId`), with **no request counter** (file has 17 tests; `requestNumber` counters at `:33/:79/:381/:411/:437` cover paging, timeout bounds and the 401-expiry test `:436-457` — none counts `/auth/login` dispatches). A silent double-dispatch (parallel login/renewal) would still emit duplicate sink rows undetected by any direct-leg guard. |
| `test/oidc_login_screen_client_id_test.dart:76,136,158` — hosted-leg precedent (`loginPosts == 1`, cumulative 2, probe ≠ login) | **Exact (precedent).** Harness `_LoginHarness` (`:27-66`) with `loginPosts`/`probePosts`/`lastClientId` and the D9 credential-key filter; three `testWidgets` (mount probe → `loginPosts == 0`; single submit → 1 with `client_id == SSOAdminClient.firstPartyClientId`; retry after 401 → cumulative 2). References constantized at `:77,:137,:159` (+1 from the added import). The hosted leg is now additionally pinned by `test/client_id_contract_test.dart` (2 testWidgets: probe fires with the constant; `?client_id=<rp>` URL precedence) and `test/oidc_login_ring_isolation_test.dart:129` (`loginPosts == 1`). |
| `test/oidc_login_handle_success_census_test.dart:110-160` — two-state census: constant exists → zero `test/` literals; absent → pinned sites; 30-test count gate | **Exact, and currently GREEN in constant mode.** Group at `:96-238`; the literal-census test at `:122-238` scans `Directory('test')` and derives from `constantExists` (checks `lib/api/sso_client.dart` for `static const String firstPartyClientId`). Count gate `:161-185`: census 10 + client_id 3 + sso 17 = 30 (all three counts verified at HEAD: 10/3/17). **Gap: the census has no `lib/` scan** — a planted literal anywhere in `lib/` (outside the constant declaration) is not detected by any current test (verified: no `Directory('lib')` walk in `test/` except `i18n_coverage_test.dart:12`, which scans for keys, not this literal). The absent-branch `pinnedSites` (`sso_client_test.dart:18`, `oidc_account_flow_test.dart:35,75,115,160`, `oidc_login_screen_client_id_test.dart:76,136,158`) are historical pre-constantization coordinates; the constantized sites now sit at `sso_client_test.dart:18`, `oidc_account_flow_test.dart:36,76,116,161`, `oidc_login_screen_client_id_test.dart:77,137,159`. |
| `test/entry_ux_test.dart:171-220` — device-entry redirect shape pinned; `client_id` not asserted at this layer | **Exact.** Group `B6-2 device-entry redirect leg (REQ-1)` at `:174-220`; two `testWidgets` at `:180` (user_code → `redirect == '/device/verify?user_code=WXYZ-1234'`) and `:200` (no code → `redirect == '/device/verify'`, no `user_code` key), each asserting `BrowserNavigation.currentUri.path == '/login/'` — path + query only, never host. No `client_id` assertion at this layer (the device wire carries none; `test/device_verify_api_test.dart:31-50` pins POST `/device/verify` to `{user_code, approve}` only). |
| `docs/campaigns/implementation-gate.md:57` — contract row: `login → auth.login.success`, `client_id=sso-admin-console`, "sink 出现 sso-admin-console login 事件；无重复" | **Exact.** Row 2 (console): "边缘生成验证：login → `auth.login.success`（client_id=sso-admin-console） | sink 出现 sso-admin-console login 事件；无重复 | B4-5". The contract value matches the landed constant. |
| `docs/proposals/b6-2-lib-api-client-id-alignment-spec.md:15-25,42` — "the only two defaults in the repo are `sso_client.dart:86` and `app_router.dart:35`"; §1.1 sink-side | **Partly stale.** §1.5 "No central constant exists … the only two defaults in the repo" was true pre-`db6e435`; at HEAD both defaults reference `SSOAdminClient.firstPartyClientId`. §1.1 **remains true**: no client-side `auth.login.success` emission path exists (`lib/services/audit_log_service.dart:66` is a localStorage ring; `lib/services/event_bus.dart:40-45` `DataChangedEvent` is UI-local); the sink row is produced server-side, so exactly-once at the client is a per-login single-dispatch property. |
| `tests/integration/api_login_e2e.py:59-77` + `audit_login_drill.py:79-82` — proxy drill | **Exact.** `api_login_e2e.py:59-77`: password login `POST {PROXY}/auth/login` with `CONFIG.login_payload()`, JWT decode, sub/iss checks. `audit_login_drill.py:78-83` `sink_rows()`: `GET {API}/api/v1/audit/events?event_types=auth.login.success&tenant_id=<t>` (server route only). Drill is the only evidence channel for the deployed IdP registering `sso-admin-console` — `[PROPOSED]`, outside this repo (unchanged by this direction). |
| `lib/api/audit_read_client.dart:11-13` — `AuditReadClient.eventsPath` sole-owner pattern | **Exact (pattern precedent).** `:11-13` `static const eventsPath/facetsPath/eventDetailPath` with a doc comment asserting single ownership. The landed constant (`sso_client.dart:78-82`) follows the same pattern. |
| `lib/services/product_api_origin.dart:9` — `ProductApiOrigin.baseUri` | **Exact.** `abstract final class ProductApiOrigin` at `:9`; `baseUri` at `:10` resolves `AppSettings.instance.ssoBaseUrlOverride ?? 'https://sso.ywbsd.site'` (VM: `test/entry_ux_test.dart` asserts path+query only, never host). |

Corrections to the direction's premises (all verified):

1. **"The designed `firstPartyClientId` constant has NOT landed" — false at HEAD.** Landed in `db6e435` (ancestor of HEAD); `grep -rn "'sso-admin-console'" lib/ test/` → exactly one hit (the declaration). The two-state census is already in constant mode and green (`flutter test` on the four acceptance files: 40/40 pass). Acceptance item (2) therefore **verifies landed state** — it must not re-land anything.
2. **The direct-leg exactly-once gap is real and remains open** (item 1): `test/sso_client_test.dart:10-30` is a single whole-body assertion with zero dispatch counting; no test anywhere counts `/auth/login` POSTs of `SSOAdminClient.login`. This is the last unpinned leg of the `implementation-gate.md:57` contract ("无重复").
3. **The census `lib/` clause is missing** (item 3): the literal census scans `Directory('test')` only; "planted literal anywhere in `lib/` fails the census" is not yet executable.
4. **No renewal path exists in `SSOAdminClient`** (verified `lib/api/sso_client.dart`): the only `/auth/login` POST in the file is `login()`'s at `:96`; `probeAdminAccess()` (`:116-118`) is `GET /api/v1/admin/endpoints`; the 401 branch in `_handle` (`:598-601`) clears the token/session and calls `onUnauthorized` — it never re-POSTs. The "probe/refresh paths → zero extra `/auth/login` POSTs" clause is therefore pinning an absence (no silent renewal), which is exactly the double-dispatch class the direction names.

---

## 2. Scope

**In scope (this direction's T-12 joint, no more, no less)**

- REQ-1 — New counting-MockClient harness for the direct leg (`SSOAdminClient.login`), mirroring `test/oidc_login_screen_client_id_test.dart`: a dedicated file `test/sso_client_login_exactly_once_test.dart` with 3 tests (exactly-one per `login()`, cumulative 2, probe/read/401 → zero extra).
- REQ-2 — Census co-change (required by items (2)+(3)): add the `lib/` single-source clause to the two-state literal census in `test/oidc_login_handle_success_census_test.dart`, and extend the standing count gate to cover the new harness file.
- REQ-3 — Landed-state verification of the constant + pinned co-change (item (2)): the constant exists at `lib/api/sso_client.dart:82`; `app_router.dart:36` and the three test co-sites reference it; `test/` carries zero literals; the census stays green in constant mode.
- REQ-4 — Device-leg regression boundary (item (4)): `test/entry_ux_test.dart:174-220` redirect-leg group stays green; `lib/screens/device/` production files stay untouched (zero diff).

**Out of scope (explicitly not changed by this direction)**

- The hosted-leg harnesses (`oidc_login_screen_client_id_test.dart`, `client_id_contract_test.dart`, `oidc_login_ring_isolation_test.dart`) — already pinned; untouched.
- The value decision / `[RESOLVED]` record / drill artifact (`audit_login_drill.py`, `api_login_e2e.py`, `test_config.py`) — shared sibling artifacts; the drill remains the only IdP-registry evidence channel and is `[PROPOSED]` until run.
- Any new test in `test/sso_client_test.dart` (its 17-test count is pinned; the harness gets its own file), and any change to `test/oidc_account_flow_test.dart` / `test/oidc_login_screen_client_id_test.dart`.
- Any production change in `lib/` (the constant has landed; REQ-3 verifies).
- The `entry_ux_test.dart` 401 tap-through leg and the `signInAgain` continuation — the sibling device-lens item (out of this direction's acceptance).

---

## 3. Requirements

### REQ-1 — Direct-leg exactly-once counting harness (new file, 3 tests)

Create `test/sso_client_login_exactly_once_test.dart` mirroring the hosted-leg harness mechanics (`test/oidc_login_screen_client_id_test.dart:27-66`): a `_DirectLoginHarness`-style setup with a `MockClient` that counts **credential-bearing** `POST /auth/login` requests (D9 filter: `jsonDecode(request.body)['credential'] is Map`) into `loginPosts`, captures `lastClientId = body['client_id']`, and serves a per-test script (`'ok'` → `{"access_token":"admin-token"}` 200; `'fail'` → `{"error":"invalid_credentials"}` 401). Request-side facts only (D6 convention: no session/navigation assertions).

The three tests (mirror of the hosted file's three):

1. **Exactly one credential-bearing POST per `login()`** — `await client.login('admin', 'password')` (script `['ok']`) → `loginPosts == 1` and `lastClientId == SSOAdminClient.firstPartyClientId`. The whole-body shape itself stays pinned by the untouched `test/sso_client_test.dart:10-30`.
2. **Two sequential logins → cumulative 2** — script `['fail', 'ok']` (first dispatch fails, second succeeds): `loginPosts == 2`, `lastClientId == SSOAdminClient.firstPartyClientId` on the final dispatch — mirrors the hosted retry test; a silent extra dispatch would push the count to 3 and fail.
3. **Probe/read/401 paths → zero extra `/auth/login` POSTs** — after one successful `login()` (`loginPosts == 1`): call `probeAdminAccess()` (GET `/api/v1/admin/endpoints`, `sso_client.dart:116-118`), one representative read (`listClients()`), and one 401-expiring read (MockClient returns 401 for the read → `_handle` `:598-601` clears token/session and fires `onUnauthorized`) → `loginPosts` stays **1**. This pins the absence of any silent renewal/re-login path (verified: none exists in `SSOAdminClient`; the only `/auth/login` POST in the file is `login()`'s at `:96`).

Hard constraints:

- Every assertion references `SSOAdminClient.firstPartyClientId` — **never** the value `'sso-admin-console'` as a literal (strict-mode census scans `test/*.dart` for the exact quoted literal; a fresh literal in this file, contiguous or split, reddens the census).
- The file carries no contiguous `'sso-admin-console'` token in **any** comment or reason string (existing convention, e.g. `client_id_contract_test.dart` "the constant's value").
- The script/fixture pattern must stay within this file; `test/sso_client_test.dart` keeps its 17 tests untouched.

**Testable:** `flutter test test/sso_client_login_exactly_once_test.dart` → 3/3 green at HEAD state (no production changes); deleting any of the three tests breaks the REQ-2 count gate (see below).

### REQ-2 — Census co-change: `lib/` single-source clause + count-gate extension

Extend the existing literal-census test in `test/oidc_login_handle_success_census_test.dart` (the two-state test at `:122-238`) — do **not** add a new test (the census file's own 10-test count is pinned):

1. **`lib/` scan clause** — walk `Directory('lib')` recursively over `*.dart`, counting lines containing the same split literal `"'sso-admin-" "console'"`:
   - **Constant mode** (current): exactly **one** hit, and that hit is in `lib/api/sso_client.dart` on a line containing `static const String firstPartyClientId` (the declaration site — pins single-source ownership in `lib/`; a second site, a relocated declaration, or a fresh literal anywhere in `lib/` fails).
   - **Absent mode** (historical, compile-broken at HEAD): exactly the two pinned production sites `{lib/api/sso_client.dart: [86], lib/app_router.dart: [35]}` (coordinates from the anchor spec's §1.4 census), preserving the two-state design for traceability.
2. **Count-gate extension** — add the new harness file to the standing gate (`:161-185`): `ssoLoginCount == 3` (from `test/sso_client_login_exactly_once_test.dart`), total `10 + 3 + 17 + 3 == 33`, and update the gate's explanatory comment. The existing pins (`censusCount == 10`, `clientIdCount == 3`, `ssoCount == 17`) stay unchanged.

**Testable:** `flutter test test/oidc_login_handle_success_census_test.dart` → 10/10 green; with the lib clause, the mutation form is executable: plant `'sso-admin-console'` in any `lib/*.dart` (e.g. `lib/foo.dart` or a second line in `sso_client.dart`) → census red; revert → green. Planting a literal in any `test/*.dart` → census red (already enforced by strict mode).

### REQ-3 — Verify landed constant state (item (2); no re-landing)

The `firstPartyClientId` constant and its pinned co-change landed at `db6e435`; this direction verifies and keeps the state:

- `lib/api/sso_client.dart:82` — `static const String firstPartyClientId = 'sso-admin-console';` (doc comment `:78-81`, `AuditReadClient.eventsPath` sole-owner pattern per `lib/api/audit_read_client.dart:11-13`).
- `lib/app_router.dart:36` — `defaultClientId: SSOAdminClient.firstPartyClientId` (route entry `ProductEntry.login` at `:35`).
- Three test co-sites reference the constant: `test/sso_client_test.dart:18`, `test/oidc_account_flow_test.dart:36,76,116,161`, `test/oidc_login_screen_client_id_test.dart:77,137,159`.
- The two-state census is in constant mode (zero `test/` literals) and green.

**Testable:** `grep -rn "'sso-admin-console'" lib/ test/` → exactly one line (`lib/api/sso_client.dart:82`); `grep -n "firstPartyClientId" lib/app_router.dart` → hit at `:36`; `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart test/sso_client_login_exactly_once_test.dart` → 33/33 green.

### REQ-4 — Device-leg regression boundary (item (4))

- `test/entry_ux_test.dart` redirect-leg group (`:174-220`) stays green — both shapes (`/device/verify?user_code=WXYZ-1234` and bare `/device/verify`), `path == '/login/'` + `redirect` query, no `client_id` at this layer (unchanged).
- `lib/screens/device/` production files untouched: `git diff --stat lib/screens/device/` → empty.

**Testable:** `flutter test test/entry_ux_test.dart` → all green (including the redirect-leg group and the B6-1 ring-untouched group); `git diff --stat lib/screens/device/` → empty.

---

## 4. Acceptance checks (supplied T-12 checks preserved 1:1, made testable)

| # | Supplied check | Testable form (this spec) |
|---|---|---|
| (1) | New counting-MockClient harness for `SSOAdminClient.login` mirroring `test/oidc_login_screen_client_id_test.dart` — exactly one credential-bearing POST `/auth/login` per `login()` with body `client_id == 'sso-admin-console'` (referencing `SSOAdminClient.firstPartyClientId` once landed), two sequential logins → cumulative 2, probe/refresh paths → zero extra `/auth/login` POSTs | REQ-1: `test/sso_client_login_exactly_once_test.dart`, 3 tests — single `login()` → `loginPosts == 1` + `lastClientId == SSOAdminClient.firstPartyClientId`; script `['fail','ok']` → `loginPosts == 2`; `probeAdminAccess()` + `listClients()` + 401-expiring read → `loginPosts` unchanged at 1. `flutter test test/sso_client_login_exactly_once_test.dart` green; deleting any test reddens the REQ-2 gate |
| (2) | `firstPartyClientId` static const lands in `lib/api/sso_client.dart` (`AuditReadClient.eventsPath` sole-owner pattern, `lib/api/audit_read_client.dart:11-13`) with pinned co-change of `app_router.dart:35` and the three test literal sites — the two-state census flips to constant mode and stays green | **Landed at `db6e435` (verified §1).** REQ-3 verification gates: constant at `sso_client.dart:82`; `app_router.dart:36` references it; the three co-sites reference it (sso_client_test:18, oidc_account_flow_test:36/76/116/161, oidc_login_screen_client_id_test:77/137/159); `grep -rn "'sso-admin-console'" lib/ test/` → exactly one hit; census green in constant mode (REQ-2 keeps it green) |
| (3) | Planted literal anywhere in `lib/` fails the census | REQ-2 lib clause: census walks `Directory('lib')` recursively; constant mode expects exactly the declaration site (`sso_client.dart:82`, line contains `static const String firstPartyClientId`). Mutation form: plant the literal in any `lib/*.dart` → census red; revert → green |
| (4) | Existing device-leg tests (`entry_ux_test.dart:171-220`) stay green | REQ-4: `flutter test test/entry_ux_test.dart` green (redirect-leg group `:174-220`); `git diff --stat lib/screens/device/` → empty |

Joint gate: `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart test/sso_client_login_exactly_once_test.dart test/entry_ux_test.dart` → 43/43 green (10 + 3 + 17 + 3 + 10), with no production diff in `lib/screens/device/` and exactly one `'sso-admin-console'` hit in `lib/ test/` (the declaration line).

---

## 5. Dependencies and constraints

- **Anchor specs:** this direction completes `b6-2-lib-screens-device-client-id-alignment-spec.md` REQ-0/AC-2; the landed constant is the anchor's REQ-1 Branch B artifact. The `[RESOLVED]` record at `docs/proposals/audit-contract-batch-snaplink-console.md:13` (Branch B, citation fixed to `:35`) already anticipates this state ("sibling 机制落地后统一对齐 `SSOAdminClient.firstPartyClientId`") — no record edit required.
- **Census ownership:** `test/oidc_login_handle_success_census_test.dart` is the oidc-login lens's anchor guard; its two-state design, the split-literal convention, and the 10-test self-count must be preserved (REQ-2 extends inside the existing test).
- **Count-gate invariants:** `sso_client_test.dart` stays at 17 tests, `oidc_login_screen_client_id_test.dart` at 3, the census file at 10; the new file adds 3; total 33. Any future harness test must land in `test/sso_client_login_exactly_once_test.dart` (or extend the gate in the same commit).
- **Literal hygiene:** the new file must be literal-free of `'sso-admin-console'` in code, comments, and reason strings (strict-mode census); probe payloads and override values in other files use distinct literal-free strings (`client_id_contract_test.dart` precedent).
- **Drill remains `[PROPOSED]`:** the deployed IdP registering `sso-admin-console` and emitting exactly one row per login is verifiable only via the proxy drill (`api_login_e2e.py:59-77`, `audit_login_drill.py:78-83`); no code in this repo can prove it.

## 6. Risks and rollback

- **Line-number drift** in the absent-mode pins (`sso_client.dart:86`, `app_router.dart:35`, and the three test co-sites): the absent branch is historical (the constant exists and three sites reference it — removing it is a compile failure), so drift there cannot mask a live regression; constant mode is the operative branch and pins by site + declaration line, not by line number.
- **Census count-gate staleness**: if the REQ-2 comment and the `ssoLoginCount` term are not updated in the same commit as the new file, the gate's self-description diverges; the spec requires them in one change set, and the gate itself fails red if the new file's tests are deleted.
- **False sense of direct-leg coverage from the hosted-leg pins**: the hosted harnesses (`oidc_login_screen_client_id_test.dart`, `client_id_contract_test.dart`) cover the OidcLoginScreen wire only; they do not count `SSOAdminClient.login` dispatches — REQ-1 closes exactly that gap; no other guard is claimed.
- **Rollback**: the entire change set is test-only (one new test file + one census test extension); reverting it restores the pre-direction guard state with zero production impact (`lib/screens/device/` diff remains empty either way).
