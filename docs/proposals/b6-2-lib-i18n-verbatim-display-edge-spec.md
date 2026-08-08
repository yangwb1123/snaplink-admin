# B6-2 — Pin the verbatim machine-data display edge (EVENT/OUTCOME/ACTOR/TENANT) in lib/i18n (spec)

Source direction: `docs/auto/analyses/lib-i18n-5fc3a900.json` entry 2 ("Pin the B6-2 display edge: auth.login.success and client_id=sso-admin-console render verbatim (machine data) in both locales").

## Status

**Spec — proposed, not yet implemented.** All cited symbols verified against the working tree on 2026-08-08; four line-number drifts vs the direction's citations are documented in §3 (B6-1b landing shifted lines; symbols unchanged). One acceptance item is not literally satisfiable (see §5 correction C1).

## Problem (verified)

T-12 joint row 2 (`docs/campaigns/implementation-gate.md:57`: console row 2 — `login → auth.login.success（client_id=sso-admin-console）`; sink 出现 `sso-admin-console` login 事件) requires the audit timeline to surface the console's own login event as *machine data*. The emission edge exists and is pinned elsewhere:

- `lib/api/sso_client.dart:82` — `static const String firstPartyClientId = 'sso-admin-console'` (direction cited :86-87); carried in the `/auth/login` body at :98 (`'client_id': clientId`, default :92).
- `lib/app_router.dart:36` — `defaultClientId: SSOAdminClient.firstPartyClientId` (direction cited :35).
- `lib/api/oidc_login_api.dart:52` — `'client_id': clientId` probe pass-through (exact match).
- Wire-level pins: `test/oidc_login_screen_client_id_test.dart`, `test/oidc_login_handle_success_census_test.dart:97-101` (module census) and :140-147 (test/ literal census, single-source rule).

The row builders deliberately render EVENT/OUTCOME/ACTOR/TENANT verbatim — `lib/screens/admin/audit_log_tab.dart:428-433` (EVENT: `TableCellText(_displayed[i].type, bold: true)`), :436-460 (OUTCOME: `StatusChip(label: row.outcome, …)` with the comment "Server vocabulary rendered verbatim (machine data, like EVENT) — the OUTCOME column never fabricates localized copy" at :447-448), :462-467 (ACTOR), :471-476 (TENANT) — correct per the data-vs-copy rule at `lib/i18n/README.md:10` ("界面文案用 LocalizedText/context.tr；**纯数据（版本号/计数/动态字段）用 Text**（值==key 的占位翻译会污染 pattern 匹配）"). `TableCellText` paints `Text(text)` with no tr (`lib/widgets/admin_data_table.dart:251-260`).

**The unpinned boundary:** `'success': '成功'` / `'failure': '失败'` now exist in the zh catalog (`lib/i18n/app_strings_source_admin_core.dart:63-64`, added by the B6-1a landing, commit `7a055be`; consumed by the outcome dropdown filter copy at `audit_log_tab.dart:375-385`). A future "localization" of the OUTCOME chip (`StatusChip(label: row.outcome)` → `context.tr(row.outcome)`) would silently translate cell values (`success` → `成功`) and fabricate localized evidence, breaking the T-12 verbatim-evidence property. Today the only guard is incidental: the dropdown-open zh assertions (`audit_log_tab_test.dart:229-230`, `find.text('成功') findsOneWidget`) would go red if the OUTCOME cell translated (the value would appear twice) — but that is undocumented, covers OUTCOME only, and pins nothing about EVENT/ACTOR/TENANT or client_id. `test/audit_log_tab_test.dart` seeds server rows (`_eventsBody`, :17-27) but never asserts zh-verbatim cell rendering (en-only `find.textContaining` at :150-151, :169-170 — substring matches, not exact, not zh).

## Evidence verification table

| Citation (direction) | Verified at (working tree) | Verdict |
|---|---|---|
| `docs/campaigns/implementation-gate.md` console row 2 | :57 — `login → auth.login.success（client_id=sso-admin-console）`; sink 出现 sso-admin-console login 事件；无重复 | ✓ exact |
| `lib/screens/admin/audit_log_tab.dart:404-436` verbatim builders | :428-433 EVENT, :436-460 OUTCOME (`label: row.outcome`, comment :447-448), :462-467 ACTOR, :471-476 TENANT | ✓ drift +24-40 (B6-1b lines) |
| `audit_log_tab.dart:322-325` dropdown filter copy | :375-385 — `DropdownMenuItem` with `LocalizedText('All'/'success'/'failure')` | ✓ drift +53; UI copy, separate from cells |
| `lib/i18n/app_strings_source_admin_core.dart` `'success': '成功'`, `'failure': '失败'` | :63-64; commit `7a055be` (B6-1a); also docs/proposals/b6-1a-…-design.md:43 | ✓ exact |
| `lib/i18n/README.md` data-vs-copy rule | :10 — pure data uses Text; value==key placeholder translations pollute pattern matching | ✓ exact |
| `lib/api/sso_client.dart:86-87` | :82 `firstPartyClientId = 'sso-admin-console'`, :92 default param, :98 `'client_id': clientId` body key | ✓ drift -4 |
| `lib/app_router.dart:35` | :36 `defaultClientId: SSOAdminClient.firstPartyClientId` | ✓ drift +1 |
| `lib/api/oidc_login_api.dart:52` | :52 `'client_id': clientId` | ✓ exact |
| `test/audit_log_tab_test.dart` "seeds rows but never asserts zh-verbatim cell rendering" | `_eventsBody` :17-27 (server JSON with type/outcome/actor_id/client_id/tenant_id); en substring asserts :150-151, :169-170; zh test :194-241 asserts count/subtitle/dropdown/CSV snackbar only | ✓ confirmed |
| `test/audit_log_tab_test.dart:198-200` zh dropdown | :229-230 `find.text('成功') findsOneWidget` / `find.text('失败') findsOneWidget` | ✓ drift +31 |
| Wire-level tests | `test/oidc_login_screen_client_id_test.dart` exists; `test/oidc_login_handle_success_census_test.dart:97-101` module census (`lib/screens/oidc_login` only, :16), :140-147 test/ literal census for `sso-admin-console` | ✓ exact (see C2) |
| `translate` API for the acceptance's unit pin | `AppStringsSourceLookup.translate(String source, [Map<String, Object?> values])` at `lib/i18n/app_strings_context.dart:5-15`; missing zh key → returns `source` (identity) — no `auth.login.success` key exists in any catalog (grep across `lib/i18n/` = zero) | ✓ exact |

## Requirements (normative invariants)

- **REQ-1 — zh-verbatim cell rendering pin.** New `testWidgets` in `test/audit_log_tab_test.dart` (zh locale, harness identical to the existing zh test at :194-235: `MaterialApp(locale: Locale('zh'), supportedLocales, global delegates)`, 1200×2200 view). Seed a body with exactly **one** event row: `type: 'auth.login.success'`, `outcome: 'success'`, `actor_id: 'admin-1'`, `client_id: SSOAdminClient.firstPartyClientId`, `tenant_id: 'acme'`, fixed timestamp; serve it through the existing `_api` mock. With the dropdown **closed**, assert:
  - `find.text('auth.login.success')` findsOneWidget — EVENT cell exact in zh (server vocabulary, not copy);
  - `find.text('success')` findsOneWidget — OUTCOME chip label exact in zh (the live `'成功'`-collision cell);
  - `find.text('成功')` findsNothing — the catalog zh value must not leak into cell data while the dropdown is closed (explicit divergence: filter copy vs cell data);
  - `find.text('admin-1')` findsOneWidget and `find.text('acme')` findsOneWidget — ACTOR/TENANT exact;
  - client_id surfaces only via CSV (no CLIENT column, C1): with the clipboard mock (:199-238 pattern), tap `Icons.file_download_outlined`; assert `_clipboardText` contains `'"${SSOAdminClient.firstPartyClientId}"'` (quoted CSV cell, verbatim) and does **not** contain `'成功'` (the outcome cell exports `success`, never the translated value);
  - unit pin (data, not copy): `AppStrings.forLocale(const Locale('zh')).translate('auth.login.success') == 'auth.login.success'` and `AppStrings.forLocale(const Locale('zh')).translate(SSOAdminClient.firstPartyClientId) == SSOAdminClient.firstPartyClientId`.
  - The test file gains `import 'package:sso_admin/api/sso_client.dart';` (the only new import required; `app_strings.dart` is already imported at :11).
- **REQ-2 — grep guard (scan-5 style).** New plain `test()` in `test/audit_log_tab_test.dart` reading `lib/screens/admin/audit_log_tab.dart` source; region = substring from the first `id: 'type'` (column header, :427-428) through the columns-list terminator `itemCount:` (:477-478) — i.e., exactly the EVENT/OUTCOME/ACTOR/TENANT builders. Assert the region:
  - **contains** `TableCellText(_displayed[i].type` and `label: row.outcome` (positive pins — the region extraction cannot go vacuous);
  - **contains none** of `context.tr(`, `LocalizedText(`, `.localized`, `translate(`.
  - (Column-header labels `'EVENT'`/`'OUTCOME'`/… are rendered via raw `Text(column.label)` in `admin_data_table.dart:180/201` and sit outside the region; the dropdown filter copy at :375-385 is outside too — it is the sanctioned localized sibling.)
- **REQ-3 — existing divergence assertions stay green.** `test/audit_log_tab_test.dart:229-230` (`'成功'`/`'失败'` dropdown-open, direction cited :198-200) unchanged and green; `test/i18n_coverage_test.dart` unchanged (3/3). No edits to `lib/i18n/app_strings_source_admin_core.dart`, `lib/screens/admin/audit_log_tab.dart`, or `test/i18n_coverage_test.dart` are required or permitted by this direction.
- **REQ-4 — gates.** `flutter test test/audit_log_tab_test.dart` and `flutter test test/i18n_coverage_test.dart` all green; `flutter test test/oidc_login_handle_success_census_test.dart` stays green (the new `'auth.login.success'` string appears **only** in the `test/` fixture — the module census at :16 scans `lib/screens/oidc_login` only — and the `sso-admin-console` **literal** never appears in `test/` per the single-source census at :140-147, C2).

## Verification commands (runnable gates)

```bash
# REQ-1/REQ-3/REQ-4: the new zh-verbatim test + the full tab suite
flutter test test/audit_log_tab_test.dart          # all green (incl. new REQ-1 test + REQ-2 guard test)
# REQ-3/REQ-4: zh-parity coverage gate untouched and green
flutter test test/i18n_coverage_test.dart          # expect: 3/3
# REQ-4: single-source + module census untouched
flutter test test/oidc_login_handle_success_census_test.dart   # expect: all green
# REQ-2 manual cross-check (the guard test asserts this programmatically)
sed -n '/id: .type./,/itemCount:/p' lib/screens/admin/audit_log_tab.dart \
  | grep -n 'context\.tr(\|LocalizedText(\|\.localized\|translate('   # expect: no hits (exit 1)
# REQ-1 negative: no zh value may leak into cell vocabulary
grep -rn "context.tr(row.outcome)\|tr(row.outcome)" lib/             # expect: zero hits (exit 1)
```

## Testability corrections vs the supplied acceptance (intent preserved)

- **C1 — `find.text('sso-admin-console')` exact is not satisfiable in the table.** The rendered columns are TIME/EVENT/OUTCOME/ACTOR/TENANT only (`audit_log_tab.dart:416-476`); `clientId` participates in search filtering (:137-142) and CSV export (:198) but has **no table cell**. The acceptance's intent — client_id machine data renders verbatim — is pinned at the two surfaces that actually exist: the CSV export cell (exact quoted-cell assert) and the `translate()` identity unit pin. Adding a CLIENT column is out of scope (§6).
- **C2 — the raw literal `'sso-admin-console'` must not appear in `test/`.** The literal census (`oidc_login_handle_success_census_test.dart:140-147`) enforces the single-source rule once `SSOAdminClient.firstPartyClientId` exists: every test reference goes through the constant. The REQ-1 fixture must interpolate the constant into the JSON body (pattern: `_eventsBodyRelative` at :29-44), and the `translate()` pin must pass the constant, not a literal — this requires importing `package:sso_admin/api/sso_client.dart` into `test/audit_log_tab_test.dart`.
- **C3 — line drift.** Direction cites `audit_log_tab.dart:404-436` (actual 428-476), dropdown `:322-325` (actual 375-385), `audit_log_tab_test.dart:198-200` (actual 229-230), `sso_client.dart:86-87` (actual 82), `app_router.dart:35` (actual 36). All cited symbols verified present; the B6-1b landing (commit `7a055be`) shifted lines only. The REQ-2 guard uses marker-anchored region extraction (`id: 'type'` → `itemCount:`), not line numbers, so it survives future drift.
- **C4 — `translate` API.** The acceptance's `translate('auth.login.success')` maps to `AppStringsSourceLookup.translate` (`app_strings_context.dart:5-15`); `test/audit_log_tab_test.dart` already imports `package:sso_admin/i18n/app_strings.dart` (:11). No catalog key `'auth.login.success'` exists — the identity result is the pin, and adding such a key would itself fail REQ-1 (a desired trip).

## Scope exclusions

- **No catalog changes.** `'success'`/`'failure'` zh keys stay (dropdown filter copy at :375-385 consumes them); no `'auth.login.success'` key is added (adding one would break REQ-1's identity pin by design).
- **No rendering changes.** The row builders keep painting `TableCellText`/`StatusChip` verbatim; no tr wiring, no new CLIENT column.
- TIME column copy path (`context.tr('just now')`/`'{count}m ago'`/`'{count}h ago'` at `audit_log_tab.dart:489-498`) — analysis entry 1, separate direction.
- Coverage-scan blind spots (scan scope `lib/screens`+`lib/widgets`, interpolated literals, `lib/services` producers, F2 `methodLabel` 'Modify') — analysis entry 3, separate direction.
- `docs/proposals/b6-1a-i18n-audit-timeline-server-truth-copy-design.md` F3 (duplicate-key risk) and F6 (outcome keys absent) — existing registrations, unchanged by this direction.
