# B6-1 Design — Pin lib/screens/portal as the B6-1 negative boundary (guard codification)

> Sibling: `docs/proposals/b6-1-lib-screens-portal-negative-boundary-spec.md` (requirements), mirroring `b6-1-lib-screens-oidc-login-read-carrier-resolution-{design,spec}.md`.
> Companion record: `docs/proposals/audit-contract-batch-snaplink-console.md:10` `[RESOLVED]`（B6-1, 2026-08-08）.
> Status: **design for the implement stage**. The boundary already holds at HEAD — this design turns it into repo guards.

## 0. Verification ledger (evidence re-checked against the working tree at HEAD `26782c5`, 2026-08-08)

All 14 evidence items and all executable claims were re-run independently. Results:

| # | Claim | Verified | Verdict |
|---|---|---|---|
| E1 | 3-line re-export shim `lib/screens/portal/portal_api.dart` | 2 comment lines + `export 'package:sso_admin/api/portal_api.dart';` — exact | ✅ |
| E2 | `lib/api/portal_api.dart` 292 lines, 0 `audit`, login = `GET /me` probe :233-253 | 292 lines, `grep -c audit` = 0; `login()` at :233 (doc :230-232) token-paste + `get('/me')` 200-else-throw | ✅ |
| E3 | `security_activity_tab.dart` `_loadActivity`/`_loadHistory` via `/me` paths | `_loadActivity` :39-65 → `get(PortalSecurityPaths.securityActivity)` :45; `_loadHistory` :67-93 → `get(...loginHistory)` :70; decodes `events`/`login_history`; 404/501 → "not enabled" | ✅ |
| E4 | `portal_security_contract.dart:13-14` | **Actually :10/:11** (`securityActivity`, `loginHistory`) — correction confirmed | ✅ corr. |
| E5 | `portal_screen_shell.dart:73` tab 4 | `4 => SecurityActivityTab(api: _api),` at :73; `_api` is the sole `PortalApi()` instantiation (`portal_screen.dart:90`) | ✅ |
| E6 | `audit_log_tab.dart:22` "reads ring today" | **Stale at HEAD**: :21-22 doc comment states `AuditReadClient` reading; `_client` :50; ring debug-only (`kDebugMode && AuditLogService.ringCopyEnabled` :298) | ✅ corr. |
| E7 | `dashboard_screen.dart:566` "const AuditLogTab() ungated" | **Now :567** `page: AuditLogTab(api: _api, capabilities: capabilities)` inside `if (navigation.supportsAuditLog)` (:559); no `const AuditLogTab()` remains | ✅ corr. |
| E8 | `audit-contract-batch-snaplink-console.md:6` F-11 + `[RESOLVED]` at :10 | :6 exact (`[PROPOSED]` scope doubt, `governance_tab.dart:166` measure cite); :10 `[RESOLVED]`（B6-1, 2026-08-08）names `SnaplinkAdminApi.get` + `AuditQuery`, both portal files 保持不动 | ✅ |
| E9 | design doc §6 hard boundary + AC-7 | §6 at :233 ("any change to `lib/screens/portal/`, `lib/api/portal_api.dart`…"); AC-7 at :229 ("portal files byte-identical to HEAD") | ✅ |
| E10 | `governance_tab.dart:166-183` GET proof | **`_queryAudit` :171-195; `widget.api.get(_auditPath, query: parameters)` at :187**; `_auditPath`/`_facetPath` = `AuditReadClient` constants :35-36 | ✅ corr. |
| E11 | `audit_query_test.dart` AC-1.1 :6-13 | `AuditQuery(limit: 100).toQueryParameters()` == `{'limit': '100'}` at :6-13 | ✅ |
| E12 | `audit_read_client_test.dart` default wire | test :21 "default list() wire is exactly {limit: 100}"; asserts :32 | ✅ |
| E13 | `portal_security_widgets_test.dart` = error independence only | single testWidgets, MockClient keyed by path (500 activity / 200 login_history / 404 fallback); no request-bound assertion | ✅ gap |
| E14 | guard scans 1-5, none scan portal | `test/audit_contract_guard_scans.dart` (560 lines): scans `audit-path-literals`/`bff-literals`/`catalog-trio`/`raw-stringification`/`second-consumer`; `scanLibDirectory` :85-107 per-file loop; **no portal scan** | ✅ gap |

**Executable claims re-run:** `find lib/screens/portal -name '*.dart' | wc -l` → 33; `grep -rn "audit" lib/screens/portal/` → exit 1; `git diff --exit-code -- lib/screens/portal/portal_api.dart lib/api/portal_api.dart` → exit 0; `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart test/audit_read_client_test.dart test/portal_security_widgets_test.dart` → **46/46 passed**.

**Two minor discrepancies found (neither affects the design):**
1. The spec header cites HEAD as `7d8cd00`; actual HEAD is `26782c5` (2026-08-07). `7d8cd00` is an **ancestor** of HEAD — the citation is a stale hash, and the spec's "+ working tree" caveat is what was actually verified.
2. The verified state includes uncommitted working-tree edits: `docs/proposals/audit-contract-batch-snaplink-console.md` (+1: the `[RESOLVED]` line at :10) and `lib/screens/admin/audit_log_tab.dart` (5 lines). The 46/46 result and the `[RESOLVED]` record therefore live on the **working tree**, not in any commit. Consequence: the guards in this design must be **structural** (source + test tree), never dependent on the doc record being committed.

> **Resolution (verify stage, 2026-08-08):** the spec header now cites `26782c5` with the delta recorded; the spec, this design, the `[RESOLVED]` line (now `audit-contract-batch-snaplink-console.md:10` in the committed tree — the acceptance-mapping T-12 linkage depends on it), and the `audit_log_tab.dart` comment-only rewording (whose +1 line shift the E6 citations :50/:51/:67/:85/:298 are based on) are **all committed** in one change set. The 46/46 suite and the two executable acceptance checks were re-run on a **fresh checkout of the committed revision** (not the working tree) — all green. The guard suite remains structural: every file its gates touch (portal sources, the four test files, `AuditReadClient`, `AuditQuery`) is committed; no gate reads `docs/` content; the doc record is advisory provenance only.

## 1. API changes

### 1.1 Production API — none (negative constraint, enforced)

Zero `lib/` changes are required **or permitted** by this direction. The production surface is frozen at HEAD:

- `PortalApi` (`lib/api/portal_api.dart`, 292 lines) acquires **no** audit surface: no methods, no path literals, no query builders, no `AuditReadClient` wiring, no `AuditQuery` usage.
- `lib/screens/portal/portal_api.dart` stays a pure 3-line re-export shim.
- `SnaplinkAdminApi` + `AuditReadClient` (trio literal owner, `audit_read_client.dart:15-17`) + `AuditQuery` remain the sole audit-read carrier — unchanged.
- `SecurityActivityTab` keeps exactly two BFF requests: `PortalSecurityPaths.securityActivity` (`/me/security/activity`, contract :10) and `PortalSecurityPaths.loginHistory` (`/me/login-history`, contract :11).

### 1.2 Test-suite API — five additive changes

**A. New scan function** in `test/audit_contract_guard_scans.dart` (placed after the scan-5 section, scan id literal `'portal-audit-boundary'` per existing convention of string-literal scan ids):

```dart
/// Scan 6 — B6-1 portal negative boundary.
///
/// The portal module (`lib/screens/portal/`) keeps zero case-insensitive
/// `audit` occurrences (identifiers, comments, literals, doc comments).
/// The audit timeline read belongs to SnaplinkAdminApi via
/// AuditReadClient; the portal self-service client never acquires an
/// audit surface (record: audit-contract-batch-snaplink-console.md:10).
final _auditAnyPattern = RegExp(r'audit', caseSensitive: false);

List<AuditGuardViolation> scanPortalAuditBoundary(
  String source,
  String fileLabel,
) {
  if (!fileLabel.startsWith('screens/portal/')) return const [];
  final violations = <AuditGuardViolation>[];
  for (final match in _auditAnyPattern.allMatches(source)) {
    final line =
        1 + '\n'.allMatches(source.substring(0, match.start)).length;
    violations.add(AuditGuardViolation(
      scan: 'portal-audit-boundary',
      file: fileLabel,
      detail: 'case-insensitive "audit" at line $line; the portal module '
          'is the B6-1 negative boundary — audit reads belong to '
          'SnaplinkAdminApi via AuditReadClient',
    ));
  }
  return violations;
}
```

Wiring: inside the `scanLibDirectory` per-file loop (`test/audit_contract_guard_scans.dart:96-101`), directly after `scanSecondConsumer(source, relative)`:
`violations.addAll(scanPortalAuditBoundary(source, relative));`

**B. Mutation harness dispatch** in `test/audit_contract_guard_mutation_test.dart`:
- Add `'portal-audit-boundary'` to the default `scans` set (:38-42).
- Add dispatch beside the existing per-scan `if (scans.contains(...))` blocks (:52-62):
  `if (scans.contains('portal-audit-boundary')) { violations.addAll(scanPortalAuditBoundary(source, relative)); }`

**C. Green-against-tree group** in `test/audit_contract_guard_test.dart`, following the scan-5 group pattern (:165-:203):

```dart
group('scan 6 — portal-audit-boundary (B6-1 negative boundary)', () {
  test('zero "audit" occurrences across the live portal module', () {
    final violations = scanLibDirectory(packageLibDir())
        .where((v) => v.scan == 'portal-audit-boundary')
        .toList();
    expect(violations, isEmpty, reason: violations.join('\n'));
  });
});
```

**D. Fail-closed mutation probes** in `test/audit_contract_guard_mutation_test.dart` (in-memory overrides via `_libSource` + `_scanWith`, never touching files). Three skins against `screens/portal/security_activity_tab.dart`:
1. Import + usage skin: insert `import 'package:sso_admin/api/audit_read_client.dart';` and one `AuditReadClient(...).list()` expression.
2. Literal skin: replace the `PortalSecurityPaths.securityActivity` argument with a `'/api/v1/audit/events'` literal.
3. Comment skin: append a doc comment containing `audit`.

Each probe asserts `mutated != source` and `violations.where((v) => v.scan == 'portal-audit-boundary')` is non-empty.

**E. Request-bound widget test** in `test/portal_security_widgets_test.dart` (new `testWidgets`, existing imports suffice — `MockClient` from `package:http/testing.dart` already imported):

```dart
testWidgets('Activity tab issues only /me BFF paths — never the audit trio',
    (tester) async {
  final paths = <String>[];
  final api = PortalApi(
    httpClient: MockClient((request) async {
      paths.add(request.url.path);
      if (request.url.path.startsWith('/api/v1/audit')) {
        fail('portal Activity tab must never call the audit trio: '
            '${request.url.path}');
      }
      if (request.url.path == '/me/security/activity') {
        return http.Response('{"events":[]}', 200);
      }
      if (request.url.path == '/me/login-history') {
        return http.Response('{"login_history":[]}', 200);
      }
      return http.Response('{}', 404);
    }),
  );
  await tester.pumpWidget(MaterialApp(home: SecurityActivityTab(api: api)));
  await tester.pumpAndSettle();
  expect(paths,
      unorderedEquals(['/me/security/activity', '/me/login-history']));
});
```

The `fail()` inside the handler is a fast-fail extra; it throws inside the async handler, which the tab's catch-all converts into its error state — **the authoritative gate is the final `unorderedEquals`** (fails on any audit path, any third request, any missing `/me` path). Fixtures `{'events': []}` / `{'login_history': []}` match the verified decode (`portalObjectList(..., 'events')` / `'login_history'`).

## 2. Compatibility constraints

1. **Purely additive guard suite.** The new per-file call early-returns `const []` for any file outside `screens/portal/`, so the existing scans 1/2/4/5 and the trio ownership pin run exactly as before, with identical violation sets. All 46 existing tests stay green; only new tests are added.
2. **Byte-identity invariants are checkable, not codified in Dart.** REQ-2's `git diff --exit-code` on the two `portal_api.dart` files stays an executable acceptance check (CI command or review step), because a test cannot cheaply verify "identical to HEAD commit" — the scan covers the audit-content part structurally, git covers the byte part.
3. **No new dependencies, no SDK features beyond `RegExp(caseSensitive: false)`** (long-supported). No changes to `AuditGuardViolation`'s shape (`scan`/`file`/`detail`); the new scan id is a plain string, consistent with the other five.
4. **The guards must not depend on the doc record.** The `[RESOLVED]` line at `audit-contract-batch-snaplink-console.md:10` is currently **uncommitted** (working tree). The scan, probes, and widget test are pure source-tree checks and stay green regardless of commit state; the doc record is advisory provenance, and this design deliberately does not add a docs-dependent assertion.
5. **Widget-test environment.** `pumpAndSettle` is proven in the existing test on this widget; `SecurityActivityTab` schedules only the two plain futures in `initState` (verified `_loadActivity`/`_loadHistory`), no timers/animations, so no settle hang. Empty-array fixtures are valid per the decode path.
6. **Mutation probes follow the existing convention** of path-keyed `_libSource` overrides (same brittleness profile as the `governance_tab.dart` probes: a rename breaks both the probe and the REQ-1 greppable claim, so the failure is loud, not silent).

## 3. Failure modes

| # | Failure mode | Detection | Mitigation |
|---|---|---|---|
| F1 | Future implementer adds an audit surface to the portal module (import, literal, identifier, comment) | Scan 6 trips on any `audit` occurrence → CI red; mutation skins A/B/C prove fail-closed | The intended friction: forces a documented boundary amendment (record + spec + scan) instead of a silent drift; T-12 acceptance stays on the proven carrier |
| F2 | Scan wiring regresses (wrong prefix, misplaced call, typo'd scan id) | Mutation probes fail closed (they call `scanPortalAuditBoundary` directly with the id filter) | Probes are the canary for the scan itself, not just the tree |
| F3 | `fail()` inside MockClient handler silently swallowed by the tab's error catch-all | Final `unorderedEquals(paths, ...)` still fails on the recorded audit path | Design keeps both layers; the assertion is authoritative, the fast-fail is diagnostic |
| F4 | Widget gains a third request or drops one of the two `/me` requests | Set equality fails (over-request *and* under-request) | `unorderedEquals` on the recorded path set |
| F5 | Future legit portal content contains "audit" (e.g., self-service audit feature) | CI red on the guard, even if the feature is otherwise sound | By design: the B6-1 boundary routes audit reads through `SnaplinkAdminApi`/admin screens; approving such a feature requires an explicit boundary amendment touching record + spec + scan — never silent |
| F6 | Probe brittleness if `security_activity_tab.dart` is renamed | Probe's `_libSource` throws / `mutated == source` assertion fails | Same convention as existing probes; rename would also break REQ-1's greppable claim |
| F7 | Uncommitted working-tree edits to portal files at acceptance time | `git diff --exit-code` on the two `portal_api.dart` paths → exit 1; guard green-against-tree → red | Byte-identity is the invariant; AC-1.2 is the gate |
| F8 | `pumpAndSettle` timeout if the widget ever grows timers | Test times out loudly | Visible failure; switch to explicit `pump()`s, not a settle waiver |

## 4. Migration steps (implement stage, ordered)

1. **`test/audit_contract_guard_scans.dart`** — add `_auditAnyPattern` + `scanPortalAuditBoundary` (after the scan-5 section); wire one line into the `scanLibDirectory` loop after `scanSecondConsumer`.
2. **`test/audit_contract_guard_mutation_test.dart`** — add `'portal-audit-boundary'` to the default `scans` set; add the dispatch block; add the three-skin probes group.
3. **`test/audit_contract_guard_test.dart`** — add the scan-6 green-against-tree group after the scan-5 group (:165-:203).
4. **`test/portal_security_widgets_test.dart`** — add the request-bound `testWidgets` (section 1.2.E); the existing error-independence test stays untouched.
5. **Verify, in order:**
   - `grep -rn "audit" lib/screens/portal/` → **exit 1**
   - `git diff --exit-code -- lib/screens/portal/portal_api.dart lib/api/portal_api.dart` → **exit 0**
   - `flutter test test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/portal_security_widgets_test.dart` → green (46 baseline + new tests)
   - `flutter test` (full suite) → green, no cross-test interaction
6. **Rollback:** revert the four test files (`git checkout -- test/audit_contract_guard_scans.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/portal_security_widgets_test.dart`) — zero production surface touched, nothing else to unwind.

## 5. Testable acceptance mapping

| Direction acceptance | Requirement | Concrete gate (testable) | Red when |
|---|---|---|---|
| **AC-1(a)** grep guard + byte-identical portal files | REQ-1, REQ-2 | (i) `grep -rn "audit" lib/screens/portal/` → exit 1; (ii) `git diff --exit-code -- lib/screens/portal/portal_api.dart lib/api/portal_api.dart` → exit 0; (iii) scan-6 green-against-tree group; (iv) mutation skins A/B/C non-empty | any `audit` occurrence in portal module; either portal_api file changed; scan wiring broken |
| **AC-2(b)** Activity tab request bound | REQ-3 | New `testWidgets` in `portal_security_widgets_test.dart` (1.2.E): recorded path set must equal `{/me/security/activity, /me/login-history}`; `fail()` on `/api/v1/audit*` | audit-trio request issued; third request; missing `/me` path; non-200 shape assumptions |
| **AC-3(c)** default-wire pin + portal client acquires no audit surface | REQ-4, REQ-5 | (i) `test/audit_query_test.dart` AC-1.1 (`AuditQuery(limit:100)` → `{'limit':'100'}`); (ii) `test/audit_read_client_test.dart` default `list()` wire = one request, `eventsPath`, `{'limit':'100'}`; (iii) `grep -in "audit" lib/api/portal_api.dart` → exit 1; (iv) scan-5 trio-literal ownership pin stays green | wire drifts from limit-only; `PortalApi` gains audit identifiers; trio literals escape `AuditReadClient` |
| Gate linkage (T-12 console leg, `implementation-gate.md:56`) | REQ-5 | `[RESOLVED]` record present at `audit-contract-batch-snaplink-console.md:10` naming `SnaplinkAdminApi.get` + `AuditQuery`; joint acceptance carried by the proven carrier + sink B1-5 self-audit, never the portal client | carrier reassigned to `PortalApi` (would trip AC-1/AC-2 before any record could matter) |

**Change set summary:** 4 test files, additive. Zero `lib/`. Zero `docs/`. Dependencies: B6-1a landed carrier (`AuditReadClient`, `audit_event_row.dart`), B6-1b ring demotion (`ringCopyEnabled`), guard baseline 46/46 green (re-executed at HEAD `26782c5` + working tree).
