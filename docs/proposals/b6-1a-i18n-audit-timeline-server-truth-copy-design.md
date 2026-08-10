# B6-1a — Design: i18n server-truth copy migration for the audit timeline (module: lib/i18n)

> Upstream: `docs/proposals/b6-1a-i18n-audit-timeline-server-truth-copy-spec.md` (requirements).
> Direction: analysis entry 1 of `docs/auto/analyses/lib-i18n-5fc3a900.json` — "Server-truth copy migration for the audit timeline (B6-1 display-truth in lib/i18n)".
> Pipeline output: `docs/auto/runs/server-truth-copy-migration-for-the-audit-timeli-91f45e06/artifacts/design-a77de8a6/task-1-design.md`.
> **Status: the direction is already landed in the working tree (uncommitted B6-1a landing).** This design treats the landed state as normative invariants with re-runnable gates; the implement stage re-verifies and commits, it does not re-implement.

## 0. Evidence verification (claims re-checked, not trusted)

Every claim in the requirements evidence was re-verified against the working tree on 2026-08-07. Verdicts:

| Cited claim | Verified reality | Verdict |
|---|---|---|
| Subtitle key replaced at `admin_core.dart:56` | `lib/i18n/app_strings_source_admin_core.dart:56` = `'All authentication and administrative events recorded by the server.': '服务器记录的全部认证与管理事件。'`; diff vs HEAD (`index fb89d79..9d1a13b`) shows the old key line removed in place | ✅ exact |
| Empty-state key replaced at `admin_features.dart:142` | `lib/i18n/app_strings_source_admin_features.dart:142` = `'No audit events returned by the server yet.': '服务器尚未返回审计事件。'`; old key line removed in place | ✅ exact |
| Consumers at `audit_log_tab.dart:256-257,260,373` | `:254` `AdminListHeader(` … `:257` subtitle key; `:260` `LocalizedText('{count} entries', args: {'count': _rows.length})`; `:373` `LocalizedText('No audit events returned by the server yet.')` | ✅ exact |
| `admin_list_header.dart:48` `context.tr` | File lives at **`lib/widgets/admin_list_header.dart`** (not `lib/screens/admin/`); `context.tr(subtitle!)` at **`:46`** (claimed `:48`); `context.tr(title)` at `:39` | ⚠️ path + line drift, substance exact |
| Data path `AuditReadClient` over `eventsPath` (`audit_read_client.dart:15,51`) | `:15` `static const eventsPath = '/api/v1/audit/events'`; `:35` `list({int limit = 100, …})`; `:51` `auditEventRowsFromResponse(await _api.get(eventsPath, query: query))`; gated by `capabilities.has('GET', AuditReadClient.eventsPath)` (`audit_log_tab.dart:68`) | ✅ exact |
| Gate `implementation-gate.md:56` (T-12) | `docs/campaigns/implementation-gate.md:56` row 1: "审计页调 sink 读 API … localStorage ring 降级为调试记录；展示服务端记录 … T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据" | ✅ verbatim |
| `grep -rn "recorded on this device" lib/` zero hits | Exit 1, zero hits; `'No audit entries yet'`, `此设备上记录`, `尚无审计记录` (lib/ **and** test/) also zero | ✅ exact |
| `test/i18n_coverage_test.dart` 3/3 | 3 tests (raw-Text scan, zh-parity scan, command-palette zh); `flutter test` on both suites → **11/11 passed** | ✅ exact |
| `test/audit_log_tab_test.dart` 8/8, AC-1.3 at `:118` | 8 `testWidgets`; `find.textContaining('on this device')` findsNothing at `:118`; server rows under exact `{'limit':'100'}` (no `tenant_id`/`trace_id`); forged ring `/api/v1/admin/forged` absent at 4 assertion sites (`:124-125, :221-222, :253-254, :284-285`); AC-4.1 not-enabled zero requests (`:288`) | ✅ exact |
| "No scope expansion … no new keys proposed (in-place replacements, zero orphans, no line-count regressions)" | **Discrepancy — see C1/C2/C3 below.** Net-zero line counts hold (5+/5− across both catalog files), but the worktree diff adds 3 keys and removes 3 keys | ⚠️ overstated |

### Corrections found during verification (folded into this design)

- **C1 (citation drift, cosmetic)** — `AdminListHeader` lives at `lib/widgets/admin_list_header.dart:46` for `context.tr(subtitle!)`; the cited `lib/screens/admin/…:48` path does not exist. Consumer claim substance unaffected.
- **C2 ("no new keys" is FALSE at worktree level)** — the catalog diff vs HEAD carries **3 new keys** in `app_strings_source_admin_core.dart`: `'success'`, `'failure'`, `'{n}% errors'`. All three are **consumed** by new worktree UI in `audit_log_tab.dart` (error-rate badge `:224` `context.tr('{n}% errors', {'n': …})`; outcome dropdown `:322-325` `LocalizedText('success')` / `LocalizedText('failure')`), so **zero orphan keys** — but the evidence's "no new keys" wording is wrong. The outcome filter itself is new in the worktree (HEAD `audit_log_tab.dart` has zero `outcome` occurrences), so these keys belong to the same uncommitted B6-1a landing, not a committed sibling. Design pins the exact key-set delta (2 replaced + 3 added + 3 removed) so implement-stage drift is detectable.
- **C3 (`Modify` removal leaves a residual producer)** — removed key `'Modify'` is still produced by `lib/services/audit_log_service.dart:30` (`AuditEntry.methodLabel`, `case 'PATCH': return 'Modify'`). The getter has **no render path** in the tree (zero consumers of `methodLabel`), and the i18n coverage scan only walks `lib/screens` + `lib/widgets` — `lib/services` is invisible to it, which is why the gate stays green. Latent risk: if the excluded B6-1b debug-ring UI ever renders `methodLabel` via `LocalizedText`/`context.tr`, zh silently falls back to English. Registered as F2; no action in this direction.
- **C4 (wording)** — "git diff `fb89d79`..worktree": `fb89d79` is the pre-image **blob** hash of `admin_core.dart` (per `index fb89d79..9d1a13b`), not a commit; HEAD is `26567d5`. The diff itself is real; the two replacement hunks are exactly as claimed.

## 1. API changes

The direction's API surface is the **i18n catalog key surface** — there are no code-level API changes.

### 1.1 Catalog keys (the only API delta of this direction)

| File | Key (en canonical) | zh value | Status |
|---|---|---|---|
| `lib/i18n/app_strings_source_admin_core.dart:56` | `'All authentication and administrative events recorded by the server.'` | `'服务器记录的全部认证与管理事件。'` | REPLACES `'…recorded on this device.'` in place |
| `lib/i18n/app_strings_source_admin_features.dart:142` | `'No audit events returned by the server yet.'` | `'服务器尚未返回审计事件。'` | REPLACES `'No audit entries yet. Operations will appear here.'` in place |

Attributed additions in the same landing (consumed, not orphans — C2): `'success': '成功'`, `'failure': '失败'`, `'{n}% errors': '错误率 {n}%'` (admin_core; error-rate badge + outcome dropdown).
Hygiene removals (zero consumers in `lib/`): `'All methods'`, `'Search by path, label...'` (admin_core). Registered-risk removal: `'Modify'` (C3/F2).

### 1.2 Unchanged code surfaces (explicit no-ops)

- `AppStrings._t` lookup chain (`app_strings.dart:26-28`): zh map → additional → en fallback. **No change** — en is the source language; a missing zh key silently falls back to the key itself.
- `context.tr` extension / `LocalizedText` (`lib/i18n/localized_text.dart`, `app_strings_context.dart`): **no change**.
- `AdminListHeader` (`lib/widgets/admin_list_header.dart`): `subtitle` stays `String?`, rendered via `context.tr(subtitle!)` at `:46` — **no signature change**.
- `AuditReadClient` (`lib/api/audit_read_client.dart`) and `SnaplinkAdminApi`: **no change**; the row data path (eventsPath `:15`, `list` `:35/:51`) is the sibling B6-1a server-read design's surface and is pinned, not modified, here.
- Not-enabled branch: `'This feature is not enabled on the connected replica.'` at `admin_features.dart:92`, consumer `audit_log_tab.dart:244` — pre-existing, untouched.

## 2. Compatibility constraints

1. **en is the source of truth.** Only non-English values are stored (`app_strings_source.dart:8-10`). Any key change must keep en rendering identical in meaning; zh regressions are the only detectable class — every gate below therefore asserts the **zh** side, never en.
2. **Silent fallback, no exception.** `_t` returns the en key when zh misses. A stale old-key reference is invisible in en and in `flutter analyze`; only the grep gates and the zh-parity scan catch it. Greps must use the **old** literals (they must be absent) and the coverage scan asserts **new** literals translate.
3. **Coverage-scan scope is `lib/screens` + `lib/widgets` only** (`i18n_coverage_test.dart:11-16`). Producers in `lib/services` (`Modify`), `lib/api`, `lib/i18n` itself are not scanned. This is the reason C3 stays green; do not rely on the scan for service-layer keys.
4. **Catalog merge order is override-by-spread** (`app_strings_source.dart:14-25`): `…appAdminCoreSourceZh, …appAdminFeatureSourceZh, …` — a duplicate key in a later file silently wins at runtime with no compile or test signal. The three added keys must remain unique across all `app*SourceZh` maps (verified today: grep finds them only in admin_core).
5. **Line-count invariant.** Both catalog files are net-zero lines vs HEAD (5+/5−). `engineering.yaml` `max_lines: 400` applies repo-wide via `quality.py`; the i18n files exceed it pre-existing (493/329) — the invariant is **no delta vs HEAD**, not ≤400.
6. **Capability-gated data path unchanged.** Rows render only from `AuditReadClient.list(limit: 100)` when `capabilities.has('GET', eventsPath)` (`audit_log_tab.dart:68`); `_rows` is server truth (`:41`), `_displayed` is the filtered/sorted view (`:42`). Copy changes must not touch this control flow.
7. **Ring demotion holds.** `AuditLogService` still records to localStorage but has zero render path in the tab; B6-1b (debug marker, ring-scoped Clear/CSV copy) is a separate direction and must not be pulled in here.
8. **`{count} entries` pre-exists** (`admin_core.dart:4`, zh `'共 {count} 条'`) — the count label needs no key change; the zh test pins `'共 2 条'`.

## 3. Failure modes

| # | Failure | Trigger | Detection | Mitigation |
|---|---|---|---|---|
| F1 | Stale old-key reference resurrects | Consumer reverts to `'…recorded on this device.'` / `'No audit entries yet…'` | Silent en fallback in zh; grep gates fail | Gate 1 (grep) run at implement + acceptance; AC-1.3 pin in `audit_log_tab_test.dart:118` |
| F2 | `'Modify'` zh missing while producer remains | B6-1b debug UI renders `AuditEntry.methodLabel` (`audit_log_service.dart:30`) via tr | Silent en fallback (`'Modify'`); invisible to coverage scan (lib/services) | Registered risk; B6-1b must re-add the key or DCE the getter — explicitly out of this direction's scope |
| F3 | Duplicate key across catalogs | Someone adds `'success'`/`'failure'` to a later-spread file (features/portal/…) | Runtime override, no test signal (coverage scan checks `translate()` presence only) | Gate 6 (uniqueness grep) at implement; merge-order note in §2.4 |
| F4 | Count arg binding breaks | `args: {'count': _rows.length}` (int) mismatches `LocalizedText` arg contract | zh test `'共 2 条'` fails (`audit_log_tab_test.dart:189`) | AC-3b keeps the zh-count assertion |
| F5 | Grep-gate literal drift | Old copy reworded slightly (e.g. "records" for "recorded") | Greps exit 0 = gate failure; variants escape | Gates pin the full canonical literals (en + zh + partial `recorded on this device`) |
| F6 | Outcome keys absent | Dropdown renders `success`/`failure` untranslated in zh | `'成功'`/`'失败'` assertions fail (`audit_log_tab_test.dart:198-200`) | AC-5 keeps the dropdown-open zh assertions |
| F7 | CSV snackbar key regression | Snackbar falls back to en form | `'已将 2 条记录以 CSV 导出到剪贴板'` fails, `'Exported 2 entries as CSV'` present (`audit_log_tab_test.dart:202-204`) | AC-5 keeps the exact-key zh pin |
| F8 | Capability gate removed | Tab issues requests or renders without `GET /api/v1/audit/events` | AC-4.1 expects **zero** requests, AC-4.2 exactly **one** (`audit_log_tab_test.dart:288,305`) | Gates as written |
| F9 | Stale-response race | Older in-flight response replaces newer rows | FM-9 test (`audit_log_tab_test.dart:324`) | Test already lands with the suite |
| F10 | Rollback coupling | Reverting only the two catalog lines without the consumers | zh parity breaks (en-only fallback), `AdminListHeader` subtitle renders raw key | Rollback unit is the whole B6-1a landing commit (M6); key-only partial revert is not a valid state |
| F11 | Forged ring resurfaces as evidence | Ring rows re-render in the timeline (B6-1b regression or rewire reversal) | Forged-row assertions at 4 sites (`audit_log_tab_test.dart:124-125,221-222,253-254,284-285`) | AC-2 pins absence across success/error/empty |
| F12 | en copy drift vs server behavior | Subtitle/empty text no longer matches what the sink serves | Manual/contract review | Out of scope: en copy is pinned by the sibling server-read design's AC surface, not here |

## 4. Migration steps

The landing already executed M1–M5 in the working tree; the steps are re-run as verification gates at implement/acceptance, in order, each tree-green:

1. **M1 — Catalog replacement.** Swap the two keys in `app_strings_source_admin_core.dart:56` and `app_strings_source_admin_features.dart:142` (done). Invariant: in-place, net-zero line delta, no orphaned old keys.
2. **M2 — Consumer update.** `audit_log_tab.dart:257` (subtitle via `AdminListHeader`) and `:373` (empty state via `LocalizedText`) point at the new keys (done). Invariant: no other consumer of either old key anywhere in `lib/`.
3. **M3 — Atomic zh parity.** New keys carry zh values in the same line; coverage scan extended to cover `subtitle:`/`title:`-style named copy if not already (it is — `localizedNamedCopy` regex, `i18n_coverage_test.dart:78-80`). Invariant: `flutter test test/i18n_coverage_test.dart` 3/3.
4. **M4 — Old-copy sweep.** `grep -rn "recorded on this device\|No audit entries yet\|此设备上记录\|尚无审计记录" lib/ test/` → exit 1 (done, verified). Invariant: zero hits at implement and acceptance.
5. **M5 — Regression pins.** `test/audit_log_tab_test.dart` (8 tests: AC-1/AC-2/AC-3/AC-4 + zh + FM-9) and the worktree outcome-filter/error-badge assertions (done). Invariant: `flutter test test/audit_log_tab_test.dart` 8/8.
6. **M6 — Commit the landing.** The B6-1a landing (server-read + outcome filter + error-rate badge + this copy) is one uncommitted worktree; commit as the atomic unit. Rollback = revert the commit (F10: key-only revert is not a valid state). Post-commit, re-run Gate 0 (full suite) plus Gate 1–7 below; `git status` must show a clean tree for `lib/i18n/`.

## 5. Testable acceptance mapping

REQ → AC → executable gate → expected result. All gates re-runnable after commit.

| REQ | AC | Gate (command) | Expected |
|---|---|---|---|
| REQ-1 | AC-1 subtitle server-sourced | `grep -rn "recorded on this device" lib/` | exit 1 (zero hits) |
| REQ-1 | AC-1.3 subtitle pin | `flutter test test/audit_log_tab_test.dart` | 8/8; `:118` `find.textContaining('on this device')` findsNothing |
| REQ-2 | AC-1.3 empty state | `grep -rn "No audit entries yet" lib/` | exit 1 (zero hits) |
| REQ-2 | AC-1.3 empty state renders | audit suite AC-3c (`:266`) | server-truth empty text shown; 0 entries |
| REQ-3 | AC-1.2 exact wire | audit suite (`:100-106`) | exactly one request; `queryParameters == {'limit':'100'}`; no `tenant_id`/`trace_id` |
| REQ-3 | AC-1.4 count truth | audit suite (`:109-113`) | `'2 entries'` from `_rows.length`; planted decoy `999` never rendered |
| REQ-3 | AC-2 forged ring inert | audit suite (`:124-125,221-222,253-254,284-285`) | `/api/v1/admin/forged` + `'forged entry'` absent across success/error/empty |
| REQ-3 | AC-4 capability gating | audit suite AC-4.1/AC-4.2 (`:288,:305`) | trio-less → zero requests + not-enabled; positive → exactly one request |
| REQ-4 | AC-5 atomic zh parity | `flutter test test/i18n_coverage_test.dart` | 3/3; zh keys for both new literals + dropdown/CSV exact-key forms |
| REQ-4 | AC-5 zh copy | audit suite zh test (`:139`) | `'共 2 条'`, `'服务器记录的全部认证与管理事件。'`, `'成功'`, `'失败'`, `'已将 2 条记录以 CSV 导出到剪贴板'` |
| REQ-5 | AC-5 old zh absent | `grep -rn "此设备上记录\|尚无审计记录" lib/ test/` | exit 1 (zero hits) |
| — | Key-set pin (C2/C3) | `grep -rn "'success'\|'failure'\|{n}% errors\|'All methods'\|'Modify'\|'Search by path" lib/i18n/` | exactly: 3 present (admin_core), 3 absent; consumers in `audit_log_tab.dart:224,322-325` only |
| — | Catalog delta pin | `git diff HEAD --stat -- lib/i18n/` | 2 files, 5+/5−, net-zero lines |
| — | Format | `dart format --output=none --set-exit-if-changed lib` (pyquality validator) | exit 0 |
| — | Full suite | `flutter test` | all suites green (baseline + 11 new/affected tests) |

## 6. Scope discipline (exclusions)

- **B6-1b** (debug-marker / ring-scoped Clear / CSV relabeling) — separate direction (analysis entry 2); F2 registers its `'Modify'` hazard, does not fix it.
- **Column headers / not-enabled / load-error copy** — separate direction (analysis entry 3); not-enabled key already localized (`admin_features.dart:92`), untouched.
- **Row rendering, CSV content, error-state leak rules, stale-response guard** — owned by the sibling B6-1a server-read design (`docs/proposals/b6-1a-lib-api-auditlogtab-server-read-design.md`, hardening passes 1–4); referenced, not re-designed.
- **No new public Dart API, no new files** in this direction; the only delta is the key surface of §1.1 plus the attributed additions/removals of C2/C3.
