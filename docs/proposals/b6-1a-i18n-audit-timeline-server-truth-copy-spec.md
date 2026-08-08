# B6-1a — i18n server-truth copy migration for the audit timeline (spec)

Source direction: `docs/auto/analyses/lib-i18n-5fc3a900.json` entry 1 ("Server-truth copy migration for the audit timeline (B6-1 display-truth in lib/i18n)").
Pipeline output: `docs/auto/runs/server-truth-copy-migration-for-the-audit-timeli-91f45e06/artifacts/requirements-10762e10/requirements.md`.

## Status

**Implemented and verified in the working tree** (uncommitted B6-1a landing; catalog diff vs HEAD `fb89d79`). Both gates green: `flutter test test/i18n_coverage_test.dart` → 3/3; `flutter test test/audit_log_tab_test.dart` → 8/8 (2026-08-07).

## Problem (verified)

Before the rewire, the i18n catalog encoded ring-truth copy: the timeline subtitle `'All authentication and administrative events recorded on this device.'` (`app_strings_source_admin_core.dart:56`, zh `'此设备上记录的全部认证与管理事件。'`) and the empty state `'No audit entries yet. Operations will appear here.'` (`app_strings_source_admin_features.dart:142`, zh `'尚无审计记录，操作会显示在此处。'`) were rendered by the ring-only `audit_log_tab.dart` (pre-rewire `:158` / `:244`). After B6-1a (audit page displays server-side records; localStorage ring demoted to debug-only — `docs/campaigns/implementation-gate.md:56`, console row 1, T-12 joint "devtools 伪造不再构成证据"), those strings would claim device-local truth while the tab shows server records. b6-1a spec REQ-1 (server-sourced subtitle) and AC-5 (atomic zh-locale keys) pin the flip.

## Requirements (all SATISFIED — normative invariants)

- **REQ-1** — Subtitle key at `lib/i18n/app_strings_source_admin_core.dart:56` is `'All authentication and administrative events recorded by the server.'` with zh `'服务器记录的全部认证与管理事件。'`; `'…recorded on this device.'` absent from `lib/` (in-place replacement, no orphan).
- **REQ-2** — Empty-state key at `lib/i18n/app_strings_source_admin_features.dart:142` is `'No audit events returned by the server yet.'` with zh `'服务器尚未返回审计事件。'`; `'No audit entries yet. Operations will appear here.'` absent from `lib/`.
- **REQ-3** — Consumers: `audit_log_tab.dart:256-257` passes the REQ-1 key as `AdminListHeader.subtitle` (rendered via `context.tr(subtitle!)`, `admin_list_header.dart:48`); `:260` `{count} entries` ← `_rows.length` (server page); `:373` renders the REQ-2 key via `LocalizedText`. Rows come from `AuditReadClient.list(limit: 100)` (`audit_read_client.dart:51`, `eventsPath` `:15`), gated by `capabilities.has('GET', eventsPath)`.
- **REQ-4** — Atomic zh parity: `test/i18n_coverage_test.dart` zh-parity gate (`:55-116`) green.
- **REQ-5** — Display-truth regression pins in new `test/audit_log_tab_test.dart` (8 tests): AC-1.3 subtitle without "on this device" (`:118`), server rows `admin_client_created`/`admin_user_deleted` under exact `{'limit':'100'}` accounting, decoy `999` count never rendered, zh subtitle + count rendered, AC-2 forged ring row (`/api/v1/admin/forged`, `forged entry`) absent across success/error/empty, AC-4.1 not-enabled zero requests.

## Verification commands (runnable gates)

```bash
grep -rn "recorded on this device" lib/            # expect: zero hits (exit 1)
grep -rn "No audit entries yet" lib/               # expect: zero hits (exit 1)
grep -rn "此设备上记录\|尚无审计记录" lib/ test/      # expect: zero hits (exit 1)
flutter test test/i18n_coverage_test.dart          # expect: 3/3
flutter test test/audit_log_tab_test.dart          # expect: 8/8
```

## Scope exclusions

B6-1b (debug-only ring relabeling: debug marker, ring-scoped Clear/CSV copy) per b6-1a spec §6 — separate direction, analysis entry 2. Column headers / not-enabled / load-error copy — separate direction, analysis entry 3 (the audit not-enabled string already localized at `admin_features.dart:92`, consumer `audit_log_tab.dart:244`). No new keys proposed; in-place replacements keep catalog line counts at HEAD.
