# B6-2 — Pin the verbatim machine-data display edge in lib/i18n (design)

Direction: `docs/auto/analyses/lib-i18n-5fc3a900.json` entry 2. Spec:
`docs/proposals/b6-2-lib-i18n-verbatim-display-edge-spec.md` (proposed).
This design is the implementation plan for that spec. Every citation in the
spec was re-verified against the working tree (HEAD `e1073ce`, uncommitted
B6-1b delta) on 2026-08-08 before writing this document; §1 records the
verdicts and the three spec-internal line offsets found.

## 0. TL;DR

A **test-only** change set. No production code, no catalog, no rendering
change. Two additions to `test/audit_log_tab_test.dart`:

1. **REQ-1** — a zh-locale `testWidgets` that seeds exactly one server row
   (`type: 'auth.login.success'`, `outcome: 'success'`, `client_id` =
   `SSOAdminClient.firstPartyClientId`) and pins, with the outcome filter
   dropdown **closed**: exact `find.text` for the four verbatim cells
   (EVENT/OUTCOME/ACTOR/TENANT), `find.text('成功') findsNothing` (catalog
   zh value must not leak into cell data), the always-quoted CSV client_id
   cell, and the `translate()` identity unit pin. Plus a plain `test()` for
   the two identity pins.
2. **REQ-2** — a plain `test()` grep guard over
   `lib/screens/admin/audit_log_tab.dart`, marker-anchored
   (`id: 'type'` → `itemCount:`), with positive pins so it cannot go
   vacuous, banning `context.tr(`, `LocalizedText(`, `.localized`,
   `translate(` inside the EVENT/OUTCOME/ACTOR/TENANT builder region.

## 1. Evidence verification (untrusted claims → working-tree facts)

| Spec citation | Working-tree result | Verdict |
|---|---|---|
| `implementation-gate.md:57` console row 2 (`login → auth.login.success（client_id=sso-admin-console）`) | :57 is exactly that row, T-12 joint | ✓ exact |
| `'success': '成功'` / `'failure': '失败'` at `app_strings_source_admin_core.dart:63-64`, added by commit `7a055be` | :63-64 exact; `7a055be` exists = "feat(audit): server-read audit timeline (B6-1a) + debug-only ring demotion (B6-1b)" | ✓ exact |
| `lib/i18n/README.md:10` data-vs-copy rule | :10 = "界面文案用 LocalizedText/context.tr；**纯数据（版本号/计数/动态字段）用 Text**…" | ✓ exact |
| `oidc_login_api.dart:52` client_id pass-through | :52 `'client_id': clientId,` | ✓ exact |
| `sso_client.dart:86-87` | :82 `firstPartyClientId = 'sso-admin-console'`; :92 default param; :98 body key | ✓ drift −4 |
| `app_router.dart:35` | :36 `defaultClientId: SSOAdminClient.firstPartyClientId` | ✓ drift +1 |
| Verbatim builders 404-436 → 428-476 | EVENT `id: 'type'` :427 + `TableCellText(_displayed[i].type, bold: true)` :432; OUTCOME `StatusChip(label: row.outcome)` :450 with "never fabricates localized copy" comment :447-448; ACTOR :462-467; TENANT :471-476; columns = TIME/EVENT/OUTCOME/ACTOR/TENANT only | ✓ symbols exact; spec-internal offsets: `id: 'type'` :427 (spec 428), `itemCount:` :479 (spec 477-478) — harmless, REQ-2 is marker-anchored |
| `TableCellText` paints raw `Text` | `admin_data_table.dart`: constructor :242-249, `Text(text, …)` :254-260 | ✓ |
| Dropdown filter copy 322-325 → 375-385 | `LocalizedText('All')` :376, `('success')` :380, `('failure')` :384 — UI copy, outside the cell builders | ✓ drift +53 |
| zh dropdown asserts 198-200 → 229-230 | :229-230 `find.text('成功'/'失败') findsOneWidget`, only while dropdown open | ✓ drift +31 |
| `audit_log_tab_test.dart` seeds rows but never asserts zh-verbatim cells | `_eventsBody` :17-27 (type/outcome/actor_id/client_id/tenant_id); en substring asserts :150-151/:169-170; zh test asserts count/subtitle/dropdown/CSV snackbar only (:223-241); `_pumpZh` helper :85-102 exists | ✓ confirmed |
| C1 — no CLIENT column; clientId only in search filter + CSV | search :142 `row.clientId.toLowerCase().contains(query)`; CSV header :185, cell :194; `_csvCell` **always quotes** (`'"$cell"'` :228) → `"sso-admin-console"` is exactly satisfiable | ✓ confirmed (and the quoted-cell assert is implementable) |
| C2 — literal `'sso-admin-console'` banned from `test/` | census `oidc_login_handle_success_census_test.dart:140-147`: `firstPartyClientId` exists ⇒ `expect(actual, isEmpty, reason: …literal must not appear in test/…)` | ✓ exact |
| Census scope | module census :16 `moduleDir = 'lib/screens/oidc_login'` only; `auth.login.success` module census :97-101 | ✓ exact |
| `translate()` identity pin | `extension AppStringsSourceLookup on AppStrings` (`app_strings_context.dart`: decl :4, `translate` :5-15): missing key ⇒ `?? source` identity; `AppStrings.forLocale` at `app_strings.dart:21`; `app_strings.dart` already imported at test :11 | ✓ exact; no `auth.login.success` key anywhere in `lib/` (0 grep hits) |
| REQ-2 markers unique | `id: 'type'` → 1 hit; `itemCount:` → 1 hit in `audit_log_tab.dart` | ✓ |
| Baseline gates | `flutter test test/audit_log_tab_test.dart test/i18n_coverage_test.dart test/oidc_login_handle_success_census_test.dart` → **35/35 passed** | ✓ green today |

**Spec-internal offsets found (no design impact):** `itemCount:` :479 not
:477-478; `AppStringsSourceLookup` declared :4 not :5; EVENT builder block
starts :427 not :428. All three are within the same constructs the spec
anchors by symbol/marker, never by line number.

**Conclusion:** the evidence is trustworthy. The spec's two corrections
(C1, C2) are not just reasonable — C1 is *required* (no CLIENT column
exists) and C2 is *enforced by an existing red test* (the literal census).
The design below implements the spec as written.

## 2. Design

### 2.1 REQ-1 — zh-verbatim cell rendering pin (new `testWidgets` + unit `test`)

Reuse the file's existing harness — `_pumpZh` (:85, zh locale + global
delegates + 1200×2200) and the `_api` MockClient router (:48) — plus the
established clipboard mock pattern (:174-189). New pieces only:

1. **One-row fixture** (function, not `const` — it interpolates the
   constant, same pattern as `_eventsBodyRelative` :29-44):

```dart
String _eventsBodySsoLogin() =>
    '{"events":['
    '{"id":"e-1","type":"auth.login.success","outcome":"success",'
    '"timestamp":"2026-08-05T12:00:00Z","actor_id":"admin-1",'
    '"client_id":"${SSOAdminClient.firstPartyClientId}","tenant_id":"acme"}],'
    '"count":1}';
```

2. **New imports** — two, both mechanical: `package:sso_admin/api/sso_client.dart`
   for REQ-1 (fixture + CSV assert + identity pin all reference
   `SSOAdminClient.firstPartyClientId`; a raw literal would be red under
   the census, C2) and `dart:io` for the REQ-2 guard's `File` read (not
   currently imported in this file; the spec's "only one new import"
   claim covers REQ-1's needs, the guard adds `dart:io`).

3. **zh testWidgets** — pump `AuditLogTab(api: _api({…_eventsBodySsoLogin…}),
   capabilities: _caps(['/api/v1/audit/events']))` via `_pumpZh`. With the
   dropdown **closed**, assert in this order:
   - `find.text('auth.login.success')` findsOneWidget — EVENT cell exact;
   - `find.text('success')` findsOneWidget — OUTCOME chip exact (this is
     the live `'成功'`-collision cell);
   - `find.text('成功')` findsNothing — catalog zh value must not leak into
     cell data while the dropdown is closed (explicit divergence pin:
     filter copy vs cell data; today only the *open* state is incidentally
     pinned by :229-230);
   - `find.text('admin-1')` findsOneWidget, `find.text('acme')`
     findsOneWidget — ACTOR/TENANT exact;
   - tap `Icons.file_download_outlined`, `pumpAndSettle`, then:
     `expect(_clipboardText, contains('"${SSOAdminClient.firstPartyClientId}"'))`
     (always-quoted CSV cell, verbatim) and
     `expect(_clipboardText, isNot(contains('成功')))` (the OUTCOME cell
     exports `success`, never the zh value).

4. **Unit pins** (plain `test()`, no harness — the extension resolves via
   the existing `app_strings.dart` import at :11):
   `AppStrings.forLocale(const Locale('zh')).translate('auth.login.success')
   == 'auth.login.success'` and `…translate(SSOAdminClient.firstPartyClientId)
   == SSOAdminClient.firstPartyClientId`. No `auth.login.success` key
   exists in any catalog (verified: 0 hits in `lib/`), so identity is the
   pin — and adding such a key is a *desired* trip, not a false positive.

### 2.2 REQ-2 — marker-anchored grep guard (new plain `test()`)

Scan-5 style, matching the repo's guard-test convention
(`test/audit_contract_guard_test.dart` reads `lib/` sources with
`dart:io`). `flutter test` runs with cwd = package root, so the relative
path is stable.

```dart
test('B6-2: the EVENT/OUTCOME/ACTOR/TENANT builders never localize '
    'machine data (verbatim cell region)', () {
  final src = File('lib/screens/admin/audit_log_tab.dart').readAsStringSync();
  final start = src.indexOf("id: 'type'");
  final end = src.indexOf('itemCount:');
  // Fail fast (never vacuous): markers verified unique (1 hit each).
  expect(start, isNot(-1), reason: "anchor id: 'type' drifted/removed");
  expect(end, greaterThan(start),
      reason: "anchor itemCount: drifted/removed");
  final region = src.substring(start, end);
  // Positive pins: the region really is the verbatim builders.
  expect(region, contains('TableCellText(_displayed[i].type'));
  expect(region, contains('label: row.outcome'));
  // Negative pins: no localization wiring may enter the cell builders.
  for (final needle in ['context.tr(', 'LocalizedText(', '.localized', 'translate(']) {
    expect(region, isNot(contains(needle)), reason: needle);
  }
});
```

Why the region works: `id: 'type'` (:427) opens the EVENT column; the
ACTOR/TENANT builders follow; `itemCount:` (:479) terminates the columns
list. The sanctioned localized siblings live **outside** the region: the
dropdown filter copy (:375-385) and the TIME column `context.tr('just
now')`/`'{count}m ago'`/`'{count}h ago'` (:489-498), which is a separate
direction's surface. Column headers render via raw `Text(column.label)`
(`admin_data_table.dart:180/201`) and are outside too.

### 2.3 Deliberate non-designs (rejected alternatives)

- **New test file** (`test/audit_verbatim_display_test.dart`): rejected —
  `_pumpZh`, `_api`, `_caps`, `_clipboardText`, and the clipboard mock are
  file-scoped; a new file duplicates ~70 lines of harness. The spec's
  choice (extend `audit_log_tab_test.dart`) is lower risk.
- **Extract the clipboard mock / zh pump into a shared helper**: rejected —
  touches existing green tests; violates REQ-3's "unchanged" constraint.
- **Localize-proof the OUTCOME chip in code** (e.g., a `VerbatimText`
  widget): out of scope — the spec forbids rendering changes; the guard
  test is the cheaper trip surface and stays green for future refactors
  that keep the verbatim property.
- **Add a CLIENT column**: out of scope (C1); client_id is pinned at its
  two real surfaces (CSV cell, `translate()` identity).

## 3. API changes

**Production API: none.** Zero delta in `lib/`. No catalog keys added or
removed, no widget API, no service signature change, no pubspec change.

**Test-facing API touchpoints (all existing, none new):**

| Symbol | Where | Role |
|---|---|---|
| `SSOAdminClient.firstPartyClientId` | `lib/api/sso_client.dart:82` | fixture + CSV assert + identity pin; new import `package:sso_admin/api/sso_client.dart` in the test file |
| `File` (`dart:io`) | stdlib | REQ-2 guard source read; new import `dart:io` in the test file |
| `AppStrings.forLocale(Locale)` | `lib/i18n/app_strings.dart:21` | unit-pin entry point (already imported at test :11) |
| `AppStringsSourceLookup.translate(source)` (extension) | `lib/i18n/app_strings_context.dart:5-15` | identity semantics under test |
| `_pumpZh`, `_api`, `_caps`, `_clipboardText` | `test/audit_log_tab_test.dart` :85, :48, :56, :45 | reused harness, unchanged |

## 4. Compatibility constraints

1. **No production delta.** The change set touches exactly one file:
   `test/audit_log_tab_test.dart` (+ this design + the spec already on
   disk). `git status` must show no `lib/` modifications attributable to
   this direction.
2. **Census constraints (both enforced by existing red tests):**
   - the raw literal `sso-admin-console` must never appear in `test/`
     (`oidc_login_handle_success_census_test.dart:140-147`);
   - `auth.login.success` must not appear in `lib/screens/oidc_login/`
     (module census :97-101; it lives only in the test fixture).
3. **No catalog edits.** `'success'`/`'failure'` zh keys stay (dropdown
   filter copy consumes them); no `'auth.login.success'` key may be added
   (identity pin would trip by design).
4. **Existing zh assertions untouched and green:** :229-230 dropdown-open
   divergence, :223-225 count/subtitle, :239-240 CSV snackbar.
5. **Marker uniqueness in `audit_log_tab.dart`:** `id: 'type'` and
   `itemCount:` must remain unique (1 hit each today); the guard's fail-
   fast `expect`s turn any future collision into a loud red, not a silent
   wrong-region scan.
6. **Fixture is a function, not `const`** (interpolates the constant).
7. **Dropdown closed-state precondition:** the new `findsNothing` assert
   depends on the current dropdown behavior (items render only when open,
   closed shows `全部`). This is exactly the divergence the pin exists to
   protect — but it must be asserted *before* any `tap` on the dropdown in
   the same test (open-state coverage stays in the existing test).

## 5. Failure modes

| # | Future regression | Trip surface (this direction) | Additional trip |
|---|---|---|---|
| F1 | OUTCOME chip "localized": `StatusChip(label: row.outcome)` → `context.tr(row.outcome)` | REQ-1: `find.text('成功') findsOneWidget` (was findsNothing) + `find.text('success')` findsNothing; REQ-2 guard: `context.tr(` in region → red | existing :229-230 open-state assert |
| F2 | EVENT/ACTOR/TENANT wrapped in any localization | REQ-1 exact `find.text` pins red; REQ-2 negative pins red | — |
| F3 | zh catalog key `auth.login.success` added | REQ-1 identity unit pin red (`成功` would be returned) | — (no existing trip) |
| F4 | CSV quoting relaxed (`_csvCell` quotes only when needed) | REQ-1 `'"${…}"'` contains-assert red | — |
| F5 | Dropdown items render inline (always open) | REQ-1 `find.text('成功') findsNothing` red (value appears twice: chip + item) | existing :229-230 (findsOneWidget red) |
| F6 | Builder region refactor renames/relocates `id: 'type'` or `itemCount:` | REQ-2 fail-fast `expect(isNot(-1))` red — loud, requires pin refresh | — |
| F7 | Fixture literal regression (someone writes `"client_id":"sso-admin-console"` instead of the constant) | census `:140-147` red | — |
| F8 | `translate()` identity semantics change (e.g., a pattern key starts matching `auth.login.success`) | REQ-1 unit pin red | — |

Every mode is a red test at the committing CI step; none is silent. F1-F3
are the ones the direction exists to catch.

## 6. Migration steps

1. **Edit `test/audit_log_tab_test.dart`** (only production-adjacent file
   touched):
   a. add `import 'dart:io';` (with the other dart: imports at :1-2) and
      `import 'package:sso_admin/api/sso_client.dart';` (alphabetical,
      after `app_settings.dart` at :11);
   b. add `_eventsBodySsoLogin()` next to `_eventsBodyRelative` (:44);
   c. add the REQ-1 zh `testWidgets` (with clipboard mock, `_pumpZh`,
      closed-state asserts, CSV asserts) in the server-read group;
   d. add the REQ-1 unit-pin `test()` and the REQ-2 guard `test()` in the
      same file.
2. **Run the three gates:**
   `flutter test test/audit_log_tab_test.dart` (all green, incl. new
   tests); `flutter test test/i18n_coverage_test.dart` (3/3);
   `flutter test test/oidc_login_handle_success_census_test.dart` (green,
   unchanged).
3. **Manual cross-checks (the guard test asserts these programmatically):**
   `sed -n "/id: .type./,/itemCount:/p" lib/screens/admin/audit_log_tab.dart | grep -n 'context\.tr(\|LocalizedText(\|\.localized\|translate('`
   → no hits; `grep -rn "tr(row.outcome)" lib/` → no hits.
4. **Commit** (repo convention, matching `7a055be`/`e1073ce` style):
   `git add docs/proposals/b6-2-lib-i18n-verbatim-display-edge-spec.md`
   (untracked today), `docs/proposals/b6-2-lib-i18n-verbatim-display-edge-design.md`,
   `test/audit_log_tab_test.dart`; message e.g.
   `verify(b6-2): pin verbatim EVENT/OUTCOME/ACTOR/TENANT + client_id CSV edge in zh (REQ-1/REQ-2)`.
5. **Optional follow-up:** annotate `implementation-gate.md` T-12 console
   row 2 with the new test name as the console-side pin reference.

## 7. Testable acceptance mapping

| Spec REQ | Acceptance (observable) | Test / file | Gate command |
|---|---|---|---|
| REQ-1a | zh, dropdown closed: EVENT cell renders `auth.login.success` exactly once | `testWidgets` `find.text('auth.login.success')` findsOneWidget | `flutter test test/audit_log_tab_test.dart` |
| REQ-1b | zh, dropdown closed: OUTCOME chip renders `success` exactly once | `find.text('success')` findsOneWidget | same |
| REQ-1c | zh, dropdown closed: no `成功` anywhere (catalog value never leaks into cell data) | `find.text('成功')` findsNothing | same |
| REQ-1d | zh, dropdown closed: ACTOR `admin-1`, TENANT `acme` exact | both findsOneWidget | same |
| REQ-1e | CSV export carries quoted verbatim client_id and never `成功` | `_clipboardText` contains `'"${SSOAdminClient.firstPartyClientId}"'`; isNot(contains('成功')) | same |
| REQ-1f | `translate()` identity on both machine strings | plain `test()` equality pins | same |
| REQ-2 | builder region localizes nothing; markers anchored; not vacuous | guard `test()`: fail-fast indexOf + 2 positive + 4 negative pins | same |
| REQ-3 | existing zh assertions + i18n coverage untouched and green | :229-230, :223-225, :239-240 unchanged; `i18n_coverage_test.dart` 3/3 | both commands |
| REQ-4 | census green; `auth.login.success` only in test fixture; no literal in test/ | `oidc_login_handle_success_census_test.dart` unchanged | census command |
| Constraint | zero production delta | `git status` shows only test + docs | manual |

## 8. Risks and scope exclusions

- **Low risk by construction:** test-only, reuses two battle-tested
  harness helpers, all seven cited files re-verified, baseline 35/35 green
  before the change.
- **Residual risk:** REQ-1's `find.text('success')` findsOneWidget could
  become ambiguous if a future feature renders another bare `success` in
  zh (e.g., a new verbatim column). The test's failure would then be a
  pin-refresh, not a product bug — acceptable, and the guard test keeps
  the underlying property pinned.
- **Out of scope** (unchanged by this direction): catalog content; row
  rendering; CLIENT column; TIME-column copy path (`audit_log_tab.dart`
  :489-498, analysis entry 1); coverage-scan blind spots (analysis entry
  3); B6-1a design F3/F6 registrations.
