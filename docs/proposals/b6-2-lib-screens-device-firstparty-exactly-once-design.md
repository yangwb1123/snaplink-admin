# B6-2 Design — Direct-leg exactly-once harness (`SSOAdminClient.login` POST counter) + `lib/` single-source census clause

Module: `lib/screens/device` · Complements: `docs/proposals/b6-2-lib-screens-device-firstparty-exactly-once-spec.md` (REQ-1…REQ-4) · Status: implemented · Effort: 3 · Risk reduction: 9 · Rev-2 (2026-08-08): integrates the mutation-audit + guard-evasion findings — fail-closed harness (`probePosts` throw), split-halves `lib/` scan, self-presence pins, `entry_ux` count pin, 43-test total, static silencing ban; drill §6 step 2 extended with the relaxation+deletion chains.

## 0. TL;DR

The direction's central premise ("`firstPartyClientId` has NOT landed") is **stale** — the constant landed at `db6e435` and the two-state census is green in constant mode. What is genuinely open is exactly what the spec says: (a) the direct-leg `SSOAdminClient.login` dispatch has **zero request counting** anywhere in `test/`, and (b) the literal census scans `Directory('test')` only — a planted literal in `lib/` is undetected.

This design is **test-only, zero production diff**:

1. **REQ-1** — new file `test/sso_client_login_exactly_once_test.dart`: a `_DirectLoginHarness` counting credential-bearing `POST /auth/login` dispatches (D9 filter), with 3 tests pinning exactly-once per `login()`, cumulative 2 across retries, and zero extra POSTs across probe/read/401-expiry paths. **Rev-2 fail-closed invariant**: any unscripted POST (credential-less `/auth/login` echo, refresh-grant on any path, extra endpoint) increments `probePosts` **and throws** `StateError` — it reddens deterministically instead of hiding in an unasserted bucket; tests 1 and 3 additionally assert `probePosts == 0`.
2. **REQ-2** — extend the existing literal-census test in `test/oidc_login_handle_success_census_test.dart` (no new test; its 10-test self-count stays pinned): a recursive `Directory('lib')` scan (constant mode → exactly the declaration site; absent mode → the two historical pins) whose matcher covers the contiguous literal **and the bare value prefix** `'sso-admin-'` (split halves, adjacent concatenation, interpolation), a count-gate extension `10+3+17+3+10 == 43` including a new `entryUxCount == 10` pin, **self-presence pins** for the walk + collector statements, and a **static silencing ban** (`skip:`/`skipTag`/`@Skip`/`@Tags`/`tags:`/`@TestOn`≠`vm`) across the four non-census joint-gate files.
3. **REQ-3/REQ-4** — verification-only gates: constant at `sso_client.dart:82`, `app_router.dart:36` references it, `grep` → exactly one hit, `entry_ux_test.dart` redirect-leg group stays green (now also count-pinned at 10), `lib/screens/device/` diff stays empty.

Joint gate: `flutter test` on the five acceptance files → **43/43** (10+3+17+3+10). Rollback is a one-commit revert with zero production impact.

## 1. Evidence verification (untrusted claims → working-tree facts)

All citations re-checked at HEAD `40acef7` (working tree carries only B6-1/B6-1c edits plus untracked siblings; none touch this direction's files). **Every claim in the evidence verified true**; no corrections required.

| Evidence claim | Verification at HEAD |
|---|---|
| `db6e435` "feat(b6-2): firstPartyClientId single-source constant (Branch B)" is an ancestor of HEAD | `git merge-base --is-ancestor db6e435 HEAD` → ancestor ✓ |
| `lib/api/sso_client.dart:82` — `static const String firstPartyClientId = 'sso-admin-console';` | Exact (`:78-81` doc comment; sole-owner pattern per `lib/api/audit_read_client.dart:11-13`) ✓ |
| `lib/app_router.dart:36` — `defaultClientId: SSOAdminClient.firstPartyClientId` | Exact; `:35` is `ProductEntry.login => OidcLoginScreen(` — the stale-line correction is correct ✓ |
| `grep -rn "'sso-admin-console'" lib/ test/` → exactly one hit | Ran it: exactly `lib/api/sso_client.dart:82` ✓ |
| Test co-sites constantized: `sso_client_test.dart:18`, `oidc_account_flow_test.dart:36/76/116/161`, `oidc_login_screen_client_id_test.dart:77/137/159` | All present (client_id file additionally carries the constant in comments at `:22/:78/:134/:157`) ✓ |
| Two-state census in constant mode; 40/40 green | Ran `flutter test` on the four acceptance files → **40/40 passed** ✓ |
| **Gap 1** — `sso_client_test.dart:10-30` whole-body assertion, zero dispatch counting; no renewal path | Exact. First test asserts the full POST body (`:18` `client_id`), no counter (`requestNumber` appears only at `:33/:79/:381/:411/:437`, all non-login). Only `/auth/login` POST in `lib/api/sso_client.dart` is `login()`'s at `:96`; `_handle` 401 branch (`:598-601`) clears token/session + fires `onUnauthorized`, never re-POSTs ✓ |
| **Gap 2** — census scans `Directory('test')` only; no `lib/` clause | Exact: `test/oidc_login_handle_success_census_test.dart:122-238` walks `Directory('test')`; no `Directory('lib')` literal walk exists in `test/` ✓ |
| Count gate 10/3/17 = 30 at `:161-185` | Exact (and green at HEAD; the gate's own runtime asserts 10/3/17) ✓ |
| Hosted-leg precedent: `_LoginHarness` at `oidc_login_screen_client_id_test.dart:27-66`, `loginPosts`/`probePosts`/`lastClientId`, D9 `credential is Map` filter, 3 testWidgets | Exact ✓ |
| `client_id_contract_test.dart` 2 testWidgets; `oidc_login_ring_isolation_test.dart:129` `loginPosts == 1` | Exact ✓ |
| `entry_ux_test.dart` 10 tests; redirect-leg group `:174-220` (both shapes, path+query only) | Exact (`grep -c` → 10) ✓ |
| Spec deliverable `docs/proposals/b6-2-lib-screens-device-firstparty-exactly-once-spec.md` exists; REQ-1 harness file absent | Spec present (134 lines, §1-6). `test/sso_client_login_exactly_once_test.dart` **did not exist** at design time ✓ |

**Behavioral facts discovered during verification (needed by the design, §2.2):**

- `login()` dispatches via `_post('/auth/login', body, auth: false)` → `_handle(resp, authenticated: false)`. A 401 on login therefore **skips** the session-clearing branch (`authenticated &&` guard at `:598`) but **still throws `SSOError(401, …)`** — the retry test must expect the throw (precedent: `sso_client_test.dart:436-457` asserts `throwsA(isA<SSOError>().having((e) => e.status, 'status', 401))`).
- An authenticated read's 401 clears `_token` + `Session.clear()` + `onUnauthorized?.call()`, then throws `SSOError(401)` — the expiry-leg test can assert `unauthorizedCalls == 1` alongside `loginPosts == 1`.
- `_listPage` tolerates a missing `itemKey` (`values is List ? … : const []` at `:506-510`), so the harness can serve `{}` 200 for successful reads.

## 2. Design

### 2.1 REQ-1 — `test/sso_client_login_exactly_once_test.dart` (new file, 3 tests)

Mirror of the hosted-leg harness (`oidc_login_screen_client_id_test.dart:27-66`) adapted to the direct client. File-private; nothing exported. **Rev-2**: the harness is fail-closed — the exercised flows must issue exactly one POST total (the scripted credential-bearing `/auth/login`); anything else reddens deterministically.

```dart
// test/sso_client_login_exactly_once_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/sso_client.dart';

/// Direct-leg counting harness: counts credential-bearing POST /auth/login
/// dispatches of SSOAdminClient.login (D9 filter, mirroring the hosted-leg
/// _LoginHarness). Reads/probe return 200 {} unless [authExpired] flips.
/// Invariant: the exercised flows (login/probe/read/401-expiry) issue exactly
/// one POST total — the scripted credential-bearing /auth/login. ANY other
/// POST (credential-less /auth/login, refresh-grant on any path, extra
/// endpoint) increments [probePosts] and throws, so it reddens the test
/// deterministically instead of hiding in an unasserted bucket.
class _DirectLoginHarness {
  _DirectLoginHarness(List<String> script) : script = List.of(script) {
    client = SSOAdminClient(
      'https://sso.example.test',
      onUnauthorized: () => unauthorizedCalls++,
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final isLogin = body['credential'] is Map; // D9 filter
          if (isLogin) {
            loginPosts++;
            lastClientId = body['client_id'] as String?;
            lastUsername = (body['credential'] as Map)['username'] as String?;
            if (script.removeAt(0) == 'fail') {
              return http.Response(jsonEncode({'error': 'invalid_credentials'}), 401);
            }
            return http.Response(jsonEncode({'access_token': 't'}), 200);
          }
          probePosts++; // credential-less POST — mount-probe analog (parity)
          throw StateError(
              'unscripted POST ${request.url.path} (probePosts=$probePosts)');
        } else if (request.method == 'POST') {
          // POST to any other path (e.g. a refresh-grant endpoint): also an
          // unscripted dispatch — same deterministic red.
          probePosts++;
          throw StateError(
              'unscripted POST ${request.url.path} (probePosts=$probePosts)');
        } else if (request.method == 'GET' && authExpired) {
          return http.Response(jsonEncode({'error': 'invalid_token'}), 401);
        }
        // Probe, reads, and anything else: absence shape (200 {}).
        return http.Response('{}', 200);
      }),
    );
  }

  final List<String> script;
  late final SSOAdminClient client;
  int loginPosts = 0;
  int probePosts = 0;
  int unauthorizedCalls = 0;
  bool authExpired = false; // when true, authenticated GETs return 401
  String? lastClientId;
  String? lastUsername;
}

void main() {
  // Test 1 — exactly one credential-bearing POST per login().
  test('direct login dispatches exactly one credential-bearing POST', () async {
    final h = _DirectLoginHarness(['ok']);
    await h.client.login('admin', 'password');
    expect(h.loginPosts, 1);
    expect(h.probePosts, 0); // no credential-less /auth/login echo
    expect(h.lastClientId, SSOAdminClient.firstPartyClientId);
    expect(h.lastUsername, 'admin');
  });

  // Test 2 — two sequential logins → cumulative 2 (retry-after-401 mirror).
  test('failed login then retry dispatches cumulative 2', () async {
    final h = _DirectLoginHarness(['fail', 'ok']);
    await expectLater(
      h.client.login('admin', 'password'),
      throwsA(isA<SSOError>().having((e) => e.status, 'status', 401)),
    );
    await h.client.login('admin', 'password');
    expect(h.loginPosts, 2);
    expect(h.lastClientId, SSOAdminClient.firstPartyClientId);
  });

  // Test 3 — probe/read/401-expiry paths add zero login POSTs.
  test('probe, read, and 401 expiry add zero login POSTs', () async {
    final h = _DirectLoginHarness(['ok']);
    await h.client.login('admin', 'password');
    expect(h.loginPosts, 1);

    await h.client.probeAdminAccess(); // GET /api/v1/admin/endpoints
    await h.client.listClients();      // GET /api/v1/admin/clients

    h.authExpired = true;              // next authenticated read → 401
    await expectLater(
      h.client.listClients(),
      throwsA(isA<SSOError>().having((e) => e.status, 'status', 401)),
    );

    expect(h.loginPosts, 1);           // no renewal, no re-login
    expect(h.probePosts, 0);           // no credential-less POST anywhere
    expect(h.unauthorizedCalls, 1);    // session cleared exactly once
  });
}
```

Design decisions:

- **D9 filter on `loginPosts`** — mirrors the hosted harness and survives future credential-less POSTs to `/auth/login` (e.g. a mount probe) without mis-counting.
- **Fail-closed `probePosts`** (Rev-2, closes mutation-audit §1 #2 and guard-evasion M2b/M3b): a credential-less `/auth/login` POST or any other-path POST increments `probePosts` **and throws** `StateError` — the guard-evasion finding was that the original design's unasserted `probePosts` bucket left a credential-less refresh-grant renewal (same path or `/auth/refresh`) green. Empirically verified: a `_post('/auth/refresh', …)` or credential-less `_post('/auth/login', …)` added to `login()` now reddens tests 1 and 3 with `Bad state: unscripted POST … (probePosts=1)`.
- **`script.removeAt(0)` on empty list throws `RangeError`** — an unexpected extra *credential-bearing* dispatch fails the test red; empirically the RangeError surfaces at the `await` inside `login()` (`_post` has no catch), i.e. *before* the count asserts — the same red, different ordering than the original comment claimed (corrected in Rev-2).
- **Test 2 expects `SSOError(401)`** — pins the verified behavior of `_post(auth: false)` → `_handle(authenticated: false)`: no session clear on login failure (guarded at `:598`), but a throw. This is *stronger* than the hosted retry test (which never observes the throw) and matches `sso_client_test.dart:436-457`'s `SSOError` assert style.
- **Test 3's `authExpired` flag is flipped *after* probe + first read** — the probe is `GET /api/v1/admin/endpoints` and would also 401 under the flag; the order is load-bearing and documented in the test. (Rev-2 correction: the 401 probe/read **throws** `SSOError(401)` through the bare `await` — the mutation is caught by the throw and/or `unauthorizedCalls == 2`, never "silent" as the original FM11 claimed.)
- **Request-side facts only** (D6 convention): no navigation/session assertions; `unauthorizedCalls` is a callback-count fact, allowed by the convention (it counts dispatches' effects, not UI state).
- **Literal hygiene**: the file contains no `'sso-admin-console'` token in code, comments, or reason strings (strict-mode census scans `test/*.dart`; a fresh contiguous literal reddens the census). All value assertions reference `SSOAdminClient.firstPartyClientId`.

### 2.2 REQ-2 — census extension in `test/oidc_login_handle_success_census_test.dart` (no new test)

Extend the existing two-state literal-census test (`:122-238`); the census file's own 10-test count stays pinned.

**2.2a — `lib/` scan clause.** After the existing `Directory('test')` scan block, add a recursive `lib/` scan. **Rev-2**: the line matcher covers the contiguous quoted literal **or the bare value prefix** (closes guard-evasion M4 — double-quoted, split `'sso-admin-' 'console'`, adjacent-concat and interpolation forms all carry the `sso-admin-` substring; empirically all three plant forms now redden), and the walk + collector carry **self-presence pins** (closes M5's scan-neutering / relocation / comment-hiding):

```dart
        // ---- lib/ single-source clause (REQ-2, design §2.2a) ----
        // Recursive lib/ scan with the same split-literal convention: in
        // constant mode exactly the declaration site may carry the value;
        // in absent mode the two historical production sites are pinned.
        // The matcher is deliberately broader than the test/ side: the
        // contiguous quoted literal OR the bare value prefix — the bare
        // form covers split halves, adjacent concatenation, and
        // interpolation, all zero-hit in lib/ today besides the
        // declaration site, so it has no false positives. The 'console'
        // half-token is deliberately NOT scanned: it is a legitimate
        // token in lib/ debug strings (probed: reddens on legit code).
        // lib/-only: even the bare prefix appears in test/ only inside
        // this file's own source (self-hit — see §8).
        bool libCarriesValue(String line) =>
            line.contains(literal) || line.contains('sso-admin-');
        final libOffenders = <String, List<int>>{};
        for (final entity in Directory('lib').listSync(recursive: true)) {
          if (entity is! File || !entity.path.endsWith('.dart')) continue;
          final lines = File(entity.path).readAsStringSync().split('\n');
          for (var i = 0; i < lines.length; i++) {
            if (libCarriesValue(lines[i])) {
              libOffenders.putIfAbsent(entity.path, () => []).add(i + 1);
            }
          }
        }
        // Self-presence pin: the walk and its collector must physically
        // live in THIS file (deleting the walk reddens; relocating it to a
        // helper or hiding it in a comment does too — anchored statement
        // forms, not bare contains).
        final censusLines = File(
                'test/oidc_login_handle_success_census_test.dart')
            .readAsStringSync()
            .split('\n');
        expect(
            censusLines.indexWhere((l) =>
                RegExp(r"^\s*for \(final entity in Directory\('lib'\)")
                    .hasMatch(l)),
            isNot(-1),
            reason: 'lib clause walk must be a statement of this file');
        expect(
            censusLines.indexWhere((l) => RegExp(
                    r'^\s*final libOffenders = <String, List<int>>\{\};')
                .hasMatch(l)),
            isNot(-1),
            reason: 'libOffenders collector must be declared in this file');
```

- **Constant mode** (current, operative): `expect(libOffenders.length, 1)` **and** the single hit lives in `lib/api/sso_client.dart` **and** that hit's line contains `constantDecl` (`'static const String firstPartyClientId'`). This pins single-source ownership: a second site, a fresh literal in any spelling anywhere in `lib/`, or a declaration moved to another file all fail. The declaration's absolute line number is *not* pinned (site + declaration-line-content is the invariant; `:82` is the HEAD coordinate — see §5, failure mode 4 vs. 8).
- **Absent mode** (historical): `expect(libOffenders, {'lib/api/sso_client.dart': [86], 'lib/app_router.dart': [35]})` — the two pre-`db6e435` production literal sites from the anchor spec's §1.4 census, preserved for two-state traceability. Compile-broken at HEAD, therefore inert; kept only so the branch structure survives.

**2.2b — count-gate extension** (`:161-185`): add the new harness file's test count, pin `entry_ux_test.dart` (closes mutation-audit §1 #7 — its 10 tests were previously unpinned), and lift the total to 43:

```dart
        final ssoLoginCount = declRe
            .allMatches(File('test/sso_client_login_exactly_once_test.dart')
                .readAsStringSync())
            .length;
        expect(ssoLoginCount, 3,
            reason: 'exactly-once harness file must hold 3 tests — found '
                '$ssoLoginCount');
        final entryUxCount = declRe
            .allMatches(File('test/entry_ux_test.dart').readAsStringSync())
            .length;
        expect(entryUxCount, 10,
            reason: 'entry_ux_test must hold 10 tests (redirect-leg group '
                'included) — found $entryUxCount');
        expect(
            censusCount + clientIdCount + ssoCount + ssoLoginCount +
                entryUxCount,
            43,
            reason: 'joint 43-test acceptance count (10+3+17+3+10)');
```

**2.2c — static silencing ban** (Rev-2, closes mutation-audit §2 A/B — `skip: true`/`skipTag`/`@TestOn('browser')` were empirically green against the v1 gate: the count pins read file text, not run results). Tokens written split so the ban cannot self-hit its own guard file; `@TestOn('vm')` is allowed (the census file's own line-1 annotation is the precedent):

```dart
        // ---- silencing ban (mutation-audit §2 A/B) ----
        // The gate's counts are text-based, so an exclusion token on any
        // non-guard joint-gate file would silently shrink the 43-run
        // (@TestOn('browser') → "No tests ran", exit 0; skip: → skipped
        // without red). Tokens are written split so the ban cannot
        // self-hit its own guard file; @TestOn('vm') is allowed (matches
        // the default VM runner — the census file's own line-1 annotation
        // is the precedent).
        final silenceRe = RegExp(
            "skip\\s*:|skipTag|@Skip|@Tags|tags\\s*:|@TestOn\\s*\\((?!\\s*['\"]vm['\"])");
        for (final f in [
          'test/sso_client_login_exactly_once_test.dart',
          'test/oidc_login_screen_client_id_test.dart',
          'test/sso_client_test.dart',
          'test/entry_ux_test.dart',
        ]) {
          expect(silenceRe.hasMatch(File(f).readAsStringSync()), isFalse,
              reason: 'silencing tokens banned in $f (joint-gate file)');
        }
```

The existing pins (`censusCount == 10`, `clientIdCount == 3`, `ssoCount == 17`) stay unchanged; the gate's explanatory comment names all five files.

### 2.3 REQ-3 — landed-state verification (no code)

Gates only: constant at `sso_client.dart:82` (doc `:78-81`); `app_router.dart:36` references it; co-sites at `sso_client_test.dart:18`, `oidc_account_flow_test.dart:36/76/116/161`, `oidc_login_screen_client_id_test.dart:77/137/159`; census green in constant mode. No re-landing.

### 2.4 REQ-4 — device-leg boundary (no code)

`entry_ux_test.dart` redirect-leg group (`:174-220`) stays green (both redirect shapes, `path == '/login/'` + `redirect` query, no `client_id` at this layer) **and count-pinned at 10** (§2.2b); `git diff --stat lib/screens/device/` stays empty.

## 3. API changes

| Surface | Change | Kind |
|---|---|---|
| `lib/` production | **None.** `SSOAdminClient`, `app_router.dart`, `lib/screens/device/*` untouched | — |
| `test/sso_client_login_exactly_once_test.dart` | **New file.** File-private `_DirectLoginHarness` (constructor takes `List<String> script`; fields `loginPosts`, `probePosts`, `unauthorizedCalls`, `authExpired`, `lastClientId`, `lastUsername`; `late final SSOAdminClient client`). Fail-closed semantics: any unscripted POST increments `probePosts` and throws `StateError`. Consumes only existing public `SSOAdminClient` API: `SSOAdminClient(String baseUrl, {httpClient, onUnauthorized})`, `login(username, password)`, `probeAdminAccess()`, `listClients()` | Test-only, additive |
| `test/oidc_login_handle_success_census_test.dart` | Extend the existing two-state census test: `lib/` scan clause with bare-prefix matcher + self-presence pins (§2.2a) + `ssoLoginCount == 3`, `entryUxCount == 10` and `== 43` gate terms (§2.2b) + silencing ban (§2.2c). No new `test()` — file stays at 10 tests | Test-only, in-place |
| Doc records | `docs/proposals/b6-2-lib-screens-device-firstparty-exactly-once-spec.md` status → implemented; `[RESOLVED]` record at `audit-contract-batch-snaplink-console.md:13` needs **no edit** (already anticipates the sibling-constant state) | Docs |

No public API, no exported symbol, no production behavior change.

## 4. Compatibility constraints

- **Census strict mode** (existing): `Directory('test')` scan covers *all* `test/*.dart` — tracked and untracked. The new harness file must be literal-free of `'sso-admin-console'` in code/comments/reason strings; the untracked sibling `test/developer_login_attribution_census_test.dart` (already in the tree, literal-free — census green at HEAD) must stay literal-free.
- **Pinned counts**: `sso_client_test.dart` stays 17, `oidc_login_screen_client_id_test.dart` stays 3, census file stays 10, `entry_ux_test.dart` stays 10. New harness tests land only in the new file; any future direct-leg harness test extends the gate in the same commit.
- **Same-change-set rule**: the new file and the REQ-2 census extension (all `ssoLoginCount`/`entryUxCount` terms *and* the gate comment) land in **one commit** — otherwise the gate's self-description diverges from its computation.
- **Two-state branch**: the census's `constantExists` derivation (`File('lib/api/sso_client.dart').readAsStringSync().contains(constantDecl)`) is unchanged; the absent branch remains historical and compile-broken at HEAD (constant exists and three test sites reference it — removing it is a compile failure, so absent-mode drift cannot mask a live regression).
- **Path shape**: `Directory('lib').listSync(recursive: true)` yields relative paths (`lib/api/sso_client.dart`), matching the existing `test/…` key convention.
- **No dependency on the drill**: the deployed-IdP evidence channel (`api_login_e2e.py`, `audit_login_drill.py`) stays `[PROPOSED]` and is unchanged; nothing in this change set depends on it.

## 5. Failure modes

| # | Failure mode | Guard | Red signal |
|---|---|---|---|
| 1 | `login()` double-dispatches (parallel login/renewal added to `login()`) | REQ-1 test 1 | `loginPosts == 2` (RangeError at the second scripted dispatch surfaces first — same red) |
| 2 | Silent renewal added to `_handle` 401 path (`:598-601`) re-POSTs `/auth/login` | REQ-1 test 3 | `loginPosts == 2` after expiring read |
| 3 | Probe/read paths switched to login POSTs | REQ-1 test 3 | `loginPosts > 1` |
| 4 | Fresh literal planted in `lib/` (second site, relocated declaration, or new file) | REQ-2 lib clause | `libOffenders.length != 1` or wrong site/line-content |
| 4a | **Fresh literal in lib/ in non-contiguous spelling** — double-quoted, split `'sso-admin-' 'console'`, adjacent concat, interpolation, escapes | REQ-2 lib clause bare-prefix matcher (Rev-2) | `libCarriesValue` flags `sso-admin-` substring → `libOffenders.length != 1` (empirically red for double-quoted + split plants) |
| 4b | **Scan neutering** — walk deleted / relocated to a helper / hidden in a comment; scan-target swap (`lib` → `test`) | Self-presence pins (Rev-2) | `lib clause walk must be a statement of this file` / `libOffenders collector …` (empirically red on swap) |
| 5 | Fresh literal planted in any `test/*.dart` (new co-site without constantizing) | Strict-mode test scan | `actual` non-empty (contiguous literal only — double-quoted test-side plant remains green, pre-existing convention, see §8) |
| 6 | Deletion of any of the 3 new harness tests | REQ-2 count gate | `ssoLoginCount != 3` / total `!= 43` |
| 7 | Deletion of tests from the three pinned files | Existing count gate | `10/3/17` mismatch |
| 7a | **Deletion of the entry_ux redirect-leg group** | `entryUxCount == 10` (Rev-2) | `entry_ux_test must hold 10 tests … found 8` (was silent in v1 — mutation-audit §1 #7) |
| 8 | Line-number drift of the constant declaration (comment inserted above `:82`) | None (by design) | **No red** — the operative invariant is site + declaration-line-content, not line 82; a line shift inside `sso_client.dart` is not a single-source violation |
| 9 | Extra unexpected login dispatch exhausts the script | `script.removeAt(0)` on empty list | `RangeError` → test red (surfaces at the `await` inside `login()`, before the count asserts — mechanism corrected in Rev-2) |
| 10 | Gate self-description drift (comment says 43, code computes differently) | Same-change-set rule (§4) | Not machine-checkable; mitigated by one-commit landing + the 43 expectation itself |
| 11 | Test 3 order-dependency broken (probe called after `authExpired = true`) | Load-bearing order documented in test | Probe 401s → `SSOError(401)` thrown through the bare `await` → test red; even if swallowed, `unauthorizedCalls == 2` reds `expect(…, 1)` (mechanism corrected in Rev-2 — never "silent") |
| 12 | **Credential-less POST to `/auth/login` inside `login()`** (parity/audit/preflight echo) | Fail-closed harness + `probePosts == 0` asserts (Rev-2) | `Bad state: unscripted POST /auth/login (probePosts=1)` (was green in v1 — guard-evasion M2b; empirically red now) |
| 13 | **Credential-less refresh-grant renewal** — same path or `/auth/refresh`, second client | Fail-closed harness (Rev-2) | `Bad state: unscripted POST /auth/refresh …` (was green in v1 — M3b; empirically red now) |
| 14 | **`skip: true` / `skipTag` / `@TestOn('browser')` / `@Tags` silencing** of a joint-gate file | Static silencing ban (Rev-2) | `silencing tokens banned in <file> (joint-gate file)` (was green in v1 — mutation-audit §2 A/B; empirically red now) |
| 15 | **Count-gate relaxation + deletion chain** — `ssoLoginCount >= 2` + total `> 30` + delete a harness test | None (accepted, documented) | **No red** — the `==` per-file pins are the only defense; relaxation requires a deliberate gate edit (documented hole, drill §6 step 2 row D11) |
| 16 | **Master-key deletion** — `censusCount >= 9` + total `> 30` + delete the literal-census test (holder of lib clause, test scan, all count pins, self-presence pins, silencing ban) | None (accepted, documented) | **No red** — every pin lives inside that one test (documented hole, drill row D12) |

Failure modes 1-3, 12, 13 close the `implementation-gate.md:57` "无重复" contract's last unpinned leg; 4-4b, 14, 7a close the `lib/` census hole and its silencing/scan-neutering evasions; 1-14 all red *inside* the joint command (no external tooling). 15-16 are deliberate, documented residual holes (any text-based count gate shares them).

## 6. Migration steps (each leaves the tree green)

- **Step 0 — baseline (verified at HEAD).** Four acceptance files 40/40; `grep -rn "'sso-admin-console'" lib/ test/` → exactly `lib/api/sso_client.dart:82`; `git diff --stat lib/screens/device/` → empty.
- **Step 1 — single commit (REQ-1 + REQ-2 together, per §4).**
  1. Add `test/sso_client_login_exactly_once_test.dart` (§2.1, Rev-2 fail-closed).
  2. Extend the census test: `lib/` scan clause + self-presence pins + `ssoLoginCount == 3` + `entryUxCount == 10` + total `43` + silencing ban + comment update (§2.2).
  3. Run joint gate (§7) → **43/43 green**; `grep` still exactly one hit; `lib/screens/device/` diff still empty.
- **Step 2 — negative-control drill (documented, not committed).** Each row: apply → record → revert → re-verify green.
  - **D1-D3** Plant `'sso-admin-console'` in `lib/` — single-quoted, double-quoted, split (`'sso-admin-' 'console'`) → census red (all three, Rev-2); revert → green.
  - **D4-D5** Plant it in `test/` — single-quoted → red; double-quoted → green (documented pre-existing test-side convention); revert → green.
  - **D6** Delete one of the 3 harness tests → gate red (`must hold 3 tests — found 2`); restore → green.
  - **D7-D8** `skip: true` / `@TestOn('browser')` on the harness file → silencing-ban red; revert → green.
  - **D9** Delete the entry_ux redirect-leg group → `entry_ux_test must hold 10 tests` red; restore → green.
  - **D10** Swap `Directory('lib')` → `Directory('test')` in the lib walk → self-presence red; revert → green.
  - **D11 (relaxation+deletion chain)** `ssoLoginCount` → `>= 2` + total → `> 30` + delete a harness test → **green** (the documented hole — the `==` pins are the only defense; drill row proves why the relaxation must never land).
  - **D12 (master key)** `censusCount` → `>= 9` + total → `> 30` + delete the literal-census test → **green** (documented hole — every pin lives in that one test).
  - **D13 (pin-block deletion)** delete the lib-clause expects + count-gate block + a harness test → green (documented).
  - **D14-D15 (fail-closed probes)** add a credential-less `_post('/auth/refresh', …)` / `_post('/auth/login', {'provider':'echo'})` to `login()` in `lib/api/sso_client.dart` → harness red (`Bad state: unscripted POST …`); revert lib → green.
  This is the executable form of acceptance checks (3) and of the spec's mutation clauses.
- **Step 3 — doc records.** Flip the spec's status to implemented (repo convention), design file status alongside; no `[RESOLVED]` record edit (§3).
- **Rollback.** `git revert` of the step-1 commit restores the exact pre-direction guard state; zero production impact (`lib/` diff empty in both directions).

## 7. Testable acceptance mapping

| # | Spec requirement / supplied check | Exact command / probe | Pass condition |
|---|---|---|---|
| R1a | REQ-1 test 1 — exactly one credential-bearing POST per `login()`, `client_id` via constant | `flutter test test/sso_client_login_exactly_once_test.dart` | 3/3 green: `loginPosts == 1`, `probePosts == 0`, `lastClientId == SSOAdminClient.firstPartyClientId` |
| R1b | REQ-1 test 2 — cumulative 2 across fail+retry | same run | `SSOError(401)` on first, `loginPosts == 2` |
| R1c | REQ-1 test 3 — probe/read/401 → zero extra POSTs | same run | `loginPosts == 1`, `probePosts == 0`, `unauthorizedCalls == 1` |
| R2a | REQ-2 lib clause — planted literal (any spelling) anywhere in `lib/` fails census | mutation drill D1-D3 | census red on plant; green on revert |
| R2b | REQ-2 count gate — `10+3+17+3+10 == 43` incl. `entryUxCount == 10` | `flutter test test/oidc_login_handle_success_census_test.dart` | 10/10 green; drill D6/D9 → red |
| R2c | REQ-2 silencing ban + self-presence pins | drill D7/D8/D10 | red on `skip:`/`@TestOn('browser')`/scan swap |
| R3 | REQ-3 — landed-state verification | `grep -rn "'sso-admin-console'" lib/ test/`; `grep -n "firstPartyClientId" lib/app_router.dart`; `grep -n "firstPartyClientId" test/sso_client_test.dart test/oidc_account_flow_test.dart test/oidc_login_screen_client_id_test.dart` | exactly `lib/api/sso_client.dart:82`; `:36`; co-sites `:18`, `:36/76/116/161`, `:77/137/159` |
| R4 | REQ-4 — device-leg boundary | `flutter test test/entry_ux_test.dart`; `git diff --stat lib/screens/device/` | 10/10 green incl. redirect-leg group `:174-220`; empty diff |
| (1)-(4) | Supplied T-12 checks 1:1 | Joint gate: `flutter test test/oidc_login_handle_success_census_test.dart test/oidc_login_screen_client_id_test.dart test/sso_client_test.dart test/sso_client_login_exactly_once_test.dart test/entry_ux_test.dart` | **43/43 green** (10+3+17+3+10), zero prod diff in `lib/screens/device/`, exactly one literal hit |

## 8. Risks and scope exclusions

- **Scope exclusions (unchanged):** hosted-leg harnesses (`oidc_login_screen_client_id_test.dart`, `client_id_contract_test.dart`, `oidc_login_ring_isolation_test.dart`); `test/sso_client_test.dart` (17-test pin); `test/oidc_account_flow_test.dart`; all `lib/` production; the proxy drill and its artifacts; the `entry_ux_test.dart` 401 tap-through/signInAgain leg (sibling item).
- **Risk — census count-gate staleness** (comment/term divergence): mitigated by the one-commit rule and by the fact that the gate computes from the files themselves.
- **Risk — residual holes (documented, drilled):** relaxation+deletion chains (FM15), master-key deletion (FM16), pin-block deletion (D13), and the test-side double-quote convention (FM5) are not machine-closed. All are text-based-gate properties shared with the repo's existing census discipline; each has a permanent drill row so the list cannot silently change. The gate's *strength* is that every other vector is red inside the joint command.
- **Risk — line-number drift in absent-mode pins** (`sso_client.dart:86`, `app_router.dart:35`): inert — absent mode is compile-broken at HEAD; constant mode pins by site + declaration-line-content, not absolute line numbers.
- **Risk — false coverage confidence from the hosted pins**: the hosted harnesses never count `SSOAdminClient.login` dispatches; REQ-1 is the only guard that does — no broader claim is made. The deployed-IdP "exactly one sink row per login" remains provable only by the `[PROPOSED]` drill.
- **Risk — untracked sibling files in `test/`**: the strict-mode scan includes them; a concurrent sibling landing a literal without constantizing reddens the census (correct behavior — it forces the single-source rule), and the joint 43/43 command's named-file set is stable regardless.
- **Risk — silencing-ban false positives**: the ban is a raw-text regex over the four joint-gate files; a future legit comment or string containing `skip:`/`@Skip`/`@TestOn(...)` (non-vm) in those files reddens and needs a token-spelling workaround — acceptable for guard files that should never carry such tokens anyway.
