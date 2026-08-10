# B6-1 Design — Pin lib/screens/portal as the B6-1 negative boundary (guard codification)

> Sibling: `docs/proposals/b6-1-lib-screens-portal-negative-boundary-spec.md` (requirements), mirroring `b6-1-lib-screens-oidc-login-read-carrier-resolution-{design,spec}.md`.
> Companion record: `docs/proposals/audit-contract-batch-snaplink-console.md:10` `[RESOLVED]`（B6-1, 2026-08-08）.
> Status: **design for the implement stage**. The boundary already holds at HEAD — this design turns it into repo guards.

## 0. Verification ledger (evidence re-checked against the working tree at HEAD `26782c5`, 2026-08-08)

All 14 evidence items and all executable claims were re-run independently. Results:

| # | Claim | Verified | Verdict |
|---|---|---|---|
| E1 | 3-line re-export shim `lib/screens/portal/portal_api.dart` | 2 comment lines + `export 'package:sso_admin/api/portal_api.dart';` — exact | ✅ |
| E2 | `lib/api/portal_api.dart` 292 lines, 0 `audit`, login = `GET /me` probe :233-257 | 292 lines, `grep -c audit` = 0; `login()` at :233-257 (doc :230-232) token-paste + `get('/me')` probe at :245, 200-else-throw | ✅ |
| E3 | `security_activity_tab.dart` `_loadActivity`/`_loadHistory` via `/me` paths | `_loadActivity` :39-65 → `get(PortalSecurityPaths.securityActivity)` :45; `_loadHistory` :67-93 → `get(...loginHistory)` :73; decodes `events`/`login_history`; 404/501 → "not enabled" | ✅ |
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
| E14 | guard scans 1-5, none scan portal | `test/audit_contract_guard_scans.dart` (606 lines at the F2-amendment commit): scans `audit-path-literals`/`bff-literals`/`catalog-trio`/`raw-stringification`/`second-consumer`; `scanLibDirectory` :94-114 per-file loop (:109 scan 5, :110 scan 6); **no portal scan at review time — the exact gap the F2 amendment closes** | ✅ gap → closed |

**Executable claims re-run:** `find lib/screens/portal -name '*.dart' | wc -l` → 33; `grep -rn "audit" lib/screens/portal/` → exit 1; `git diff --exit-code -- lib/screens/portal/portal_api.dart lib/api/portal_api.dart` → exit 0; `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart test/audit_read_client_test.dart test/portal_security_widgets_test.dart` → **46/46 passed**.

**Two minor discrepancies found (neither affects the design):**
1. The spec header cites HEAD as `7d8cd00`; actual HEAD is `26782c5` (2026-08-07). `7d8cd00` is an **ancestor** of HEAD — the citation is a stale hash, and the spec's "+ working tree" caveat is what was actually verified.
2. The verified state includes uncommitted working-tree edits: `docs/proposals/audit-contract-batch-snaplink-console.md` (+1: the `[RESOLVED]` line at :10) and `lib/screens/admin/audit_log_tab.dart` (5 lines). The 46/46 result and the `[RESOLVED]` record therefore live on the **working tree**, not in any commit. Consequence: the guards in this design must be **structural** (source + test tree), never dependent on the doc record being committed.

> **Resolution (verify stage, 2026-08-08):** the spec header now cites `26782c5` with the delta recorded; the spec, this design, the `[RESOLVED]` line (now `audit-contract-batch-snaplink-console.md:10` in the committed tree — the acceptance-mapping T-12 linkage depends on it), and the `audit_log_tab.dart` comment-only rewording (whose +1 line shift the E6 citations :50/:51/:67/:85/:298 are based on) are **all committed** in one change set. The 46/46 suite and the two executable acceptance checks were re-run on a **fresh checkout of the committed revision** (not the working tree) — all green. The guard suite remains structural: every file its gates touch (portal sources, the four test files, `AuditReadClient`, `AuditQuery`) is committed; no gate reads `docs/` content; the doc record is advisory provenance only.

> **F2 amendment (implement + final release, 2026-08-08):** per the adversarial review, the F2 canary gap is closed and the F2 row's mechanism description is corrected (it overclaimed: the probes pin the `_scanWith` dispatch, not the `scanLibDirectory` wiring). The amendment lands scan 6 exactly as §1.2 A–E specify **plus** §1.2.F — a temp-dir positive pin (`audit_contract_guard_test.dart:320`) writing a synthetic `screens/portal/_probe.dart` into `Directory.systemTemp` and asserting `scanLibDirectory` trips through the per-file wiring (`scans.dart:110`), with a clean-probe control so the pin cannot be satisfied by path alone. The three mutation skins fail closed through the `_scanWith` dispatch (:65-67). All six test-suite changes are committed in **one change set** together with this design and the spec; every citation in this document and the spec holds at the committed revision (re-verified on a fresh detached worktree — see the run's final-verify record).
>
> **Re-review (2026-08-08, at the F2-amendment commit `4a8723f`):** the pin is **extended** to the shared vacuous-pass residual — scans 1/2/4/5 and the trio-owner call share the `_scanWith`-re-implements-the-loop gap with scan 6, so the extension pins every per-file call in one test (one probe per scan id + a per-id clean control; probe bodies drill-verified: each trips its own id and nothing else in the control). Scan-5 group citations corrected to :170-:310; `mutated != source` framed as uniform new-code discipline (the older partial practice is accepted: a no-op mutation still fails the `isNotEmpty` violation assertion). Red-condition drills re-run at the committed revision: loop wiring removed → pin red while the green group passes vacuously; dispatch removed → all three skins red. Suite green: **75/75** (49 four-file + 26 mutation) with the extended pin.

## 1. API changes

### 1.1 Production API — none (negative constraint, enforced)

Zero `lib/` changes are required **or permitted** by this direction. The production surface is frozen at HEAD:

- `PortalApi` (`lib/api/portal_api.dart`, 292 lines) acquires **no** audit surface: no methods, no path literals, no query builders, no `AuditReadClient` wiring, no `AuditQuery` usage.
- `lib/screens/portal/portal_api.dart` stays a pure 3-line re-export shim.
- `SnaplinkAdminApi` + `AuditReadClient` (trio literal owner, `audit_read_client.dart:15-17`) + `AuditQuery` remain the sole audit-read carrier — unchanged.
- `SecurityActivityTab` keeps exactly two BFF requests: `PortalSecurityPaths.securityActivity` (`/me/security/activity`, contract :10) and `PortalSecurityPaths.loginHistory` (`/me/login-history`, contract :11).

### 1.2 Test-suite API — six additive changes

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

Wiring: inside the `scanLibDirectory` per-file loop (`test/audit_contract_guard_scans.dart:101-111`), directly after `scanSecondConsumer(source, relative)` (:109) — the landed call sits at :110.
`violations.addAll(scanPortalAuditBoundary(source, relative));`

**B. Mutation harness dispatch** in `test/audit_contract_guard_mutation_test.dart`:
- Add `'portal-audit-boundary'` to the default `scans` set (:38-43).
- Add dispatch beside the existing per-scan `if (scans.contains(...))` blocks (:53-67):
  `if (scans.contains('portal-audit-boundary')) { violations.addAll(scanPortalAuditBoundary(source, relative)); }`

**C. Green-against-tree group** in `test/audit_contract_guard_test.dart`, following the scan-5 group pattern (:170-:310):

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

Each probe asserts `mutated != source` and `violations.where((v) => v.scan == 'portal-audit-boundary')` is non-empty. The `mutated != source` assertion is **uniform new-code discipline on all three skins** — deliberately stricter than the mutation file's pre-existing partial practice (it asserts it on ~10 of ~15 older skins). The older omissions are accepted: a no-op `replaceFirst` still fails the `isNotEmpty` violation assertion (the `isNot` assert only upgrades the failure message), and the residual-route group's `isEmpty` postconditions are documentation-grade, with behavioral backstops named in their comments.

**E. Request-bound widget test** in `test/portal_security_widgets_test.dart` (new `testWidgets` at :34, existing imports suffice — `MockClient` from `package:http/testing.dart` already imported):

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

**F. F2 temp-dir positive pin** in `test/audit_contract_guard_test.dart` (scan-6 group at :312; pin test at :320) — the F2 amendment, **extended at re-review** to the shared vacuous-pass residual. The mutation probes (D) pin only the `_scanWith` dispatch (:65-67) — and that dispatch *re-implements* the `scanLibDirectory` loop, so without a pin, dropping any per-file call in the loop (scans.dart:106-110) would make that scan's green group's filtered list empty and `expect(violations, isEmpty)` pass **vacuously**. Scans 1/2/4/5 and the trio-owner post-loop call (:112) share exactly this residual with scan 6 (the b6-1c landing accepted it by convention; the F2 review's lesson is that the convention is a hazard). The pin closes it uniformly: a synthetic probe tree — one probe per scan id (`screens/portal/_probe.dart` containing `audit` for scan 6; a non-allowlisted audit path for scan 1; a `bff` comment for scan 2; a raw `MapEntry(key, '$value')` for scan 4; a hand-built `query:` map on `/api/v1/audit/events` for scan 5; the scan-5 probe doubling as the offender for the ownership pin, with a complete trio owner in the tree) — is written into a throwaway `Directory.systemTemp` tree; `scanLibDirectory` must trip **every** scan id on the dirty tree, and the same layout with all probes neutralized must stay green for every id (control, so the pin cannot trip on paths/layout alone). Temp-dir only, `addTearDown`-removed, zero repo files touched:

```dart
test('F2 wiring pin — synthetic probe tree trips every per-file scan '
    'via scanLibDirectory', () {
  final tempDir = Directory.systemTemp.createTempSync('b6_1_guard_pin_');
  addTearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });
  final writeProbe = (String relativePath, String body) {
    final file = File(
      '${tempDir.path}${Platform.pathSeparator}'
      '${relativePath.replaceAll('/', Platform.pathSeparator)}',
    );
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(body);
  };
  // Dirty state — one probe per scan id:
  writeProbe('screens/portal/_probe.dart',
      "final _probe = 'audit'; // synthetic negative-boundary probe\n");
  writeProbe('screens/portal/_probe_scan1.dart',
      "final p = '/api/v1/audit/events/export';\n");
  writeProbe('screens/portal/_probe_scan2.dart', '// bff\n');
  writeProbe('screens/portal/_probe_scan4.dart',
      "final m = MapEntry(key, '\$value');\n");
  writeProbe('screens/portal/_probe_scan5.dart',
      "await api.get('/api/v1/audit/events', "
          "query: {'limit': '100'});\n");
  // A complete trio owner in the throwaway tree, so the ownership pin
  // trips on the offender probe above, not on missing-owner noise.
  writeProbe('api/audit_read_client.dart',
      "const a = '/api/v1/audit/events';\n"
          "const b = '/api/v1/audit/facets';\n"
          "const c = '/api/v1/audit/events/{id}';\n");
  const allPerFileScans = [
    'portal-audit-boundary',
    'audit-path-literals',
    'bff-literals',
    'raw-stringification',
    'second-consumer',
    'trio-literal-owner',
  ];
  final dirty = scanLibDirectory(tempDir.path);
  for (final scan in allPerFileScans) {
    expect(dirty.where((v) => v.scan == scan), isNotEmpty,
        reason: 'dirty probe tree produced no $scan violations — the '
            'scanLibDirectory wiring for this scan is missing or broken: '
            '${dirty.join('\n')}');
  }
  // Control: neutralize every probe; all ids must stay green, so the pin
  // cannot be satisfied by paths/layout alone (over-flagging).
  writeProbe('screens/portal/_probe.dart', "final _probe = 'activity';\n");
  writeProbe('screens/portal/_probe_scan1.dart',
      "final p = '/me/security/activity';\n");
  writeProbe('screens/portal/_probe_scan2.dart', '// activity\n');
  writeProbe('screens/portal/_probe_scan4.dart',
      'final m = MapEntry(key, value);\n');
  writeProbe('screens/portal/_probe_scan5.dart',
      "await api.get('/me/security/activity', "
          "query: {'limit': '100'});\n");
  final clean = scanLibDirectory(tempDir.path);
  for (final scan in allPerFileScans) {
    expect(clean.where((v) => v.scan == scan), isEmpty,
        reason: 'clean probe tree still trips $scan — over-flagging: '
            '${clean.join('\n')}');
  }
});
```

## 2. Compatibility constraints

1. **Purely additive guard suite.** The new per-file call early-returns `const []` for any file outside `screens/portal/`, so the existing scans 1/2/4/5 and the trio ownership pin run exactly as before, with identical violation sets. All 46 existing tests stay green; only new tests are added.
2. **Byte-identity invariants are checkable, not codified in Dart.** REQ-2's `git diff --exit-code` on the two `portal_api.dart` files stays an executable acceptance check (CI command or review step), because a test cannot cheaply verify "identical to HEAD commit" — the scan covers the audit-content part structurally, git covers the byte part.
3. **No new dependencies, no SDK features beyond `RegExp(caseSensitive: false)`** (long-supported). No changes to `AuditGuardViolation`'s shape (`scan`/`file`/`detail`); the new scan id is a plain string, consistent with the other five.
4. **The guards must not depend on the doc record.** The `[RESOLVED]` line at `audit-contract-batch-snaplink-console.md:10` is currently **uncommitted** (working tree). The scan, probes, and widget test are pure source-tree checks and stay green regardless of commit state; the doc record is advisory provenance, and this design deliberately does not add a docs-dependent assertion.
5. **Widget-test environment.** `pumpAndSettle` is proven in the existing test on this widget; `SecurityActivityTab` schedules only the two plain futures in `initState` (verified `_loadActivity`/`_loadHistory`), no timers/animations, so no settle hang. Empty-array fixtures are valid per the decode path.
6. **Mutation probes follow the existing convention** of path-keyed `_libSource` overrides (same brittleness profile as the `governance_tab.dart` probes: a rename breaks both the probe and the REQ-1 greppable claim, so the failure is loud, not silent).
7. **The F2 pin is temp-dir-contained and per-scan.** It writes its synthetic probe tree under `Directory.systemTemp` only — never the repo tree — removes it via `addTearDown`, and carries a clean-probe control so no scan can trip on paths/layout alone. Every assertion is filtered per scan id; the throwaway tree carries a complete trio owner so the ownership pin trips on the offender probe rather than on missing-owner noise, and the tree's only `.dart` files are the probes and the owner, so no other scan state leaks into the assertions. The pin covers the per-file loop calls of scans 1/2/4/5/6 and the trio-owner post-loop call — the shared vacuous-pass residual (the `_scanWith` dispatch re-implements the loop, so the mutation skins cannot pin it; scan 3 needs no pin: it is runtime-derived and invoked directly in tests).

## 3. Failure modes

| # | Failure mode | Detection | Mitigation |
|---|---|---|---|
| F1 | Future implementer adds an audit surface to the portal module (import, literal, identifier, comment) | Scan 6 trips on any `audit` occurrence → CI red; mutation skins A/B/C prove fail-closed | The intended friction: forces a documented boundary amendment (record + spec + scan) instead of a silent drift; T-12 acceptance stays on the proven carrier |
| F2 | Scan wiring regresses (wrong prefix, misplaced call, typo'd scan id) | Two independent canaries cover both wiring points: the mutation skins fail closed through the `_scanWith` dispatch (`audit_contract_guard_mutation_test.dart:65-67`), and the temp-dir positive pin (`audit_contract_guard_test.dart:320`) makes `scanLibDirectory` trip on a synthetic probe tree — every per-file scan id (1/2/4/5/6 + trio owner) asserted non-empty on the dirty tree, all empty on the clean control — through the scans.dart per-file calls (:106-110, trio owner :112) | Probes pin the dispatch wiring; the pin pins the loop wiring of every per-file scan — no green-against-tree group can pass vacuously if any loop call or the dispatch is dropped |
| F3 | `fail()` inside MockClient handler silently swallowed by the tab's error catch-all | Final `unorderedEquals(paths, ...)` still fails on the recorded audit path | Design keeps both layers; the assertion is authoritative, the fast-fail is diagnostic |
| F4 | Widget gains a third request or drops one of the two `/me` requests | Set equality fails (over-request *and* under-request) | `unorderedEquals` on the recorded path set |
| F5 | Future legit portal content contains "audit" (e.g., self-service audit feature) | CI red on the guard, even if the feature is otherwise sound | By design: the B6-1 boundary routes audit reads through `SnaplinkAdminApi`/admin screens; approving such a feature requires an explicit boundary amendment touching record + spec + scan — never silent |
| F6 | Probe brittleness if `security_activity_tab.dart` is renamed | Probe's `_libSource` throws / `mutated == source` assertion fails | Same convention as existing probes; rename would also break REQ-1's greppable claim |
| F7 | Uncommitted working-tree edits to portal files at acceptance time | `git diff --exit-code` on the two `portal_api.dart` paths → exit 1; guard green-against-tree → red | Byte-identity is the invariant; AC-1.2 is the gate |
| F8 | `pumpAndSettle` timeout if the widget ever grows timers | Test times out loudly | Visible failure; switch to explicit `pump()`s, not a settle waiver |

## 4. Migration steps (implement stage, ordered)

1. **`test/audit_contract_guard_scans.dart`** — add `_auditAnyPattern` + `scanPortalAuditBoundary` (after the scan-5 section); wire one line into the `scanLibDirectory` loop after `scanSecondConsumer`.
2. **`test/audit_contract_guard_mutation_test.dart`** — add `'portal-audit-boundary'` to the default `scans` set; add the dispatch block; add the three-skin probes group.
3. **`test/audit_contract_guard_test.dart`** — add the scan-6 green-against-tree group **and the F2 temp-dir positive pin** (1.2.F) after the scan-5 group (:170-:310).
4. **`test/portal_security_widgets_test.dart`** — add the request-bound `testWidgets` (section 1.2.E, :34); the existing error-independence test stays untouched.
5. **Verify, in order:**
   - `grep -rn "audit" lib/screens/portal/` → **exit 1**
   - `git diff --exit-code -- lib/screens/portal/portal_api.dart lib/api/portal_api.dart` → **exit 0**
   - `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart test/audit_read_client_test.dart test/portal_security_widgets_test.dart` → green (**49** = 46 baseline + scan-6 green + F2 pin + request-bound widget test)
   - `flutter test test/audit_contract_guard_mutation_test.dart` → green (26 = baseline + existing drills + 3 B6-1 skins)
   - `flutter test` (full suite) → green, no cross-test interaction
6. **Rollback:** revert the four test files (`git checkout -- test/audit_contract_guard_scans.dart test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/portal_security_widgets_test.dart`) — zero production surface touched, nothing else to unwind.

## 5. Testable acceptance mapping

| Direction acceptance | Requirement | Concrete gate (testable) | Red when |
|---|---|---|---|
| **AC-1(a)** grep guard + byte-identical portal files | REQ-1, REQ-2 | (i) `grep -rn "audit" lib/screens/portal/` → exit 1; (ii) `git diff --exit-code -- lib/screens/portal/portal_api.dart lib/api/portal_api.dart` → exit 0; (iii) scan-6 green-against-tree group; (iv) mutation skins A/B/C non-empty; (v) F2 temp-dir positive pin trips on **every per-file scan id** (1/2/4/5/6 + trio owner) over the synthetic probe tree and stays green on the clean control | any `audit` occurrence in portal module; either portal_api file changed; scan wiring broken (any `scanLibDirectory` per-file call dropped → (v) red; `_scanWith` dispatch dropped → (iv) red) |
| **AC-2(b)** Activity tab request bound | REQ-3 | New `testWidgets` in `portal_security_widgets_test.dart` (1.2.E): recorded path set must equal `{/me/security/activity, /me/login-history}`; `fail()` on `/api/v1/audit*` | audit-trio request issued; third request; missing `/me` path; non-200 shape assumptions |
| **AC-3(c)** default-wire pin + portal client acquires no audit surface | REQ-4, REQ-5 | (i) `test/audit_query_test.dart` AC-1.1 (`AuditQuery(limit:100)` → `{'limit':'100'}`); (ii) `test/audit_read_client_test.dart` default `list()` wire = one request, `eventsPath`, `{'limit':'100'}`; (iii) `grep -in "audit" lib/api/portal_api.dart` → exit 1; (iv) scan-5 trio-literal ownership pin stays green | wire drifts from limit-only; `PortalApi` gains audit identifiers; trio literals escape `AuditReadClient` |
| Gate linkage (T-12 console leg, `implementation-gate.md:56`) | REQ-5 | `[RESOLVED]` record present at `audit-contract-batch-snaplink-console.md:10` naming `SnaplinkAdminApi.get` + `AuditQuery`; joint acceptance carried by the proven carrier + sink B1-5 self-audit, never the portal client | carrier reassigned to `PortalApi` (would trip AC-1/AC-2 before any record could matter) |

**Change set summary:** 4 test files, additive. Zero `lib/`. The spec and this design are amended in the same change set to record the F2 amendment (scan-6 implementation + temp-dir positive pin) and refresh line citations to the committed revision. Dependencies: B6-1a landed carrier (`AuditReadClient`, `audit_event_row.dart`), B6-1b ring demotion (`ringCopyEnabled`), guard baseline 46/46 green (re-executed at HEAD `26782c5` + working tree); post-amendment guard suite **75/75** (49 in the four-file command + 26 in the mutation drill).
