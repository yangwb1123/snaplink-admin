# B6-1 Requirements Specification — Resolve the read-carrier ambiguity and tenant_id/trace_id provenance (module: lib/screens/oidc_login)

> Source direction: "Resolve the B6-1 read-carrier ambiguity and tenant_id/trace_id provenance before wiring the timeline (record, don't guess)" (value 7 / risk 8 / effort 2 / confidence 9), direction 3 of `docs/auto/analyses/lib-screens-oidc-login-ec0d732a.json`.
> All file/line citations below were re-verified against the repository on 2026-08-08. Corrections to the source citation are marked `[CORRECTION]`.
> Status: requirements — a **record-and-verify** deliverable. No production-code change is required or permitted: the carrier decision is recorded in the batch proposal (REQ-0), the guard suite is executed at HEAD (AC-2, verified green 38/38), and the provenance gate is documented (REQ-5). The direction's own acceptance is the deliverable.
> Sibling instances: `docs/proposals/b6-1-lib-screens-oidc-login-audit-visibility-spec.md` (same analysis bucket, direction 2 — ring isolation + joint timeline rendering) and the b6-1a family (`b6-1a-lib-api-audit-read-client-spec.md`, `b6-1a-lib-api-auditlogtab-server-read-spec.md`, `b6-1a-lib-screens-admin-auditlogtab-server-read-spec.md`) which own the timeline rewire. This spec owns **only** the carrier decision record, the guard-suite verification, and the tenant_id/trace_id provenance gate.

## 1. Problem statement (verified)

Gate row 1 (`docs/campaigns/implementation-gate.md:56`, console row 1) names `lib/api/portal_api.dart`（实际路径，QA F-11 实测；**非** `lib/services/`）as the audit read carrier. That citation is **contract-verified [PROPOSED]**: `grep -ci 'audit' lib/api/portal_api.dart` → **0** (verified). `PortalApi` (`lib/api/portal_api.dart:37`) is a portal-only self-service client — `/me-family` fetch (`fetchMe` `:270`, `fetchListOrEmpty` `:282`), notifications, `/logout` (`:268`), with a bare transport surface (`get` `:110` — **no `query:` parameter**, `post` `:159`, `patch` `:171`, `put` `:183`, `delete` `:191`) and sole instantiation at `lib/screens/portal/portal_screen.dart:90` (`_api = widget.api ?? PortalApi();`). The audit read cannot land there without inventing a new surface — a query-parameterized `get` plus an audit client — which would contradict the existing guard suite and the portal's scope.

The **validated carrier** in this repo is `SnaplinkAdminApi.get('/api/v1/audit/events', query: AuditQuery(...))`, proven at `lib/screens/admin/governance_tab.dart:183` (`widget.api.get(_auditPath, query: parameters)` in `_queryAudit`, `:167-183`), backed by the documented endpoint trio (`lib/api/snaplink_admin_types.dart:310-312`) and the typed builder `lib/api/audit_query.dart` whose default wire is exactly `{'limit':'100'}`. Since the timeline rewire landed, the trio literals are owned by `AuditReadClient` (`lib/api/audit_read_client.dart:14-16`; `governance_tab.dart:31` references `AuditReadClient.eventsPath` — scan-5 ownership pin), and the timeline (`lib/screens/admin/audit_log_tab.dart`) reads through `AuditReadClient.list(...)` → `SnaplinkAdminApi.get(eventsPath, query:)` (`audit_read_client.dart:52`).

Separately, **tenant_id + trace_id via BFF is unproven**: tenant_id needs token-claim parsing (no claim parser exists in `lib/` — dependency B4-1) and trace_id BFF injection has no repository surface — both `[PROPOSED]`. `test/audit_contract_guard_test.dart` AC-3.2 (`:101-123`) forbids `'bff'` literals in `lib/` (unified case-insensitive semantics == `grep -rni "bff" lib/`), so "via BFF" must be **parameter wiring**, not literals. Fabricating tenant_id/trace_id query params would leak event content into proxy logs — the exact boundary b6-1a AC-1's limit-only default is designed to bound ("no-leak query boundary": search terms/event content must never ride the URL; `b6-1a-lib-api-auditlogtab-server-read-spec.md` REQ-1).

**Deliverable:** record the carrier decision (don't guess), verify the guard suite, and pin the provenance gate. The module (`lib/screens/oidc_login`) is the consumer of this decision: its login edge renders on the timeline only via the server feed (joint T-12, gate row 1, dep B1-5), and the feed's carrier must be the proven one.

## 2. Evidence verification table

Every direction citation re-checked against the repository at HEAD (fresh grep census; no code modified).

| # | Citation from direction | Verified repository reality | Status |
|---|---|---|---|
| E1 | `lib/api/portal_api.dart` — grep 'audit' count = 0 | `grep -ci 'audit' lib/api/portal_api.dart` → **0**. Same for the shim `lib/screens/portal/portal_api.dart` (3-line re-export, `:1-3`) → **0**. | ✅ exact |
| E2 | `lib/api/portal_api.dart:56-60,180-265` — client surface, no audit read, no query builder | `class PortalApi` at `:37`; `onSessionExpired` `:56-58`; `hasToken` `:59-60`; transport `get` `:110` (no `query:` param), `post` `:159`, `patch` `:171`, `put` `:183`, `delete` `:191`, `deleteWithQuery` `:194`; session surface `login` `:233`, `logout` `:268`, `fetchMe` `:270`, `fetchListOrEmpty` `:282`. No audit read, no `AuditQuery`-style builder anywhere. | ✅ (ranges approximate; substance exact) |
| E3 | `lib/screens/portal/portal_screen.dart:90` — sole instantiation | `_api = widget.api ?? PortalApi();` at `:90`. | ✅ exact |
| E4 | `lib/api/snaplink_admin_types.dart:310-312` — documented audit trio | `:310` `GET /api/v1/audit/events`, `:311` `GET /api/v1/audit/facets`, `:312` `GET /api/v1/audit/events/{id}` — exact. | ✅ exact |
| E5 | `lib/api/audit_query.dart:13-135` — typed builder; tenant_id/trace_id serialize iff non-empty; default `{'limit':'100'}` at `:54-63` | File is 174 lines. `class AuditQuery` at `:17`; fields `:20-38`; `supportedKeys` at **`:51-58`** `[CORRECTION: :54-63]`; `fromJson` `:66-146` (unknown keys throw `AuditQueryParseException` `:167`); `toQueryParameters()` at **`:148`** `[CORRECTION: :146-165 → :148-165]` — `limit` iff non-null (`'$limit'` coercion), string keys iff non-empty after trim. Default wire exactly `{'limit':'100'}` stated in the class doc `:13-16`; the builder spans `:17-165` `[CORRECTION: :13-135 → :17-165]`. | ✅ (lines corrected, substance exact) |
| E6 | `lib/screens/admin/governance_tab.dart:31/:166-191/:400` — proven server read + `_has('GET','/api/v1/audit/events')` capability gate | `:31` `static const _auditPath = AuditReadClient.eventsPath;` (trio literal now owned by `AuditReadClient` `:14-16` — scan-5 pin; the literal itself no longer lives in governance); `_queryAudit()` `:167-183` with `widget.api.get(_auditPath, query: parameters)` at `:183` and `final facets = _has('GET', _facetPath) ? ...` at `:188`; `_auditArea` at `:400` with capability gate `if (!_has('GET', _auditPath))` at **`:404`** `[CORRECTION: :400 → gate at :404; :400 is the method start]`. `_has` defined `:85`. | ✅ (gate line corrected) |
| E7 | `lib/api/snaplink_admin_api.dart:126` — `get(path, query:)` admin transport | Signature `Future<Map<String, dynamic>> get(String path, {Map<String, String>? query, bool forceRefresh})` spans **`:124-127`**; `Map<String, String>? query` at `:126` `[CORRECTION: :126 → :124-127]`. Ring writer `_recordAudit` at `:81-84`, mutation-only (`method != 'GET'`) at `:322-324`. | ✅ (line spans corrected, substance exact) |
| E8 | `test/audit_contract_guard_test.dart:27-50` — audit-path literal allowlist; `:101-123` — AC-3.2 forbids 'bff' literals in lib/ | AC-3.1 group `:26-95`: green-against-tree `:27-32`, routes-blob per-line normalization `:34-42`, `Uri.encodeComponent` normalization `:44-50`. AC-3.2 group `:101-123`: green-against-tree `:102-107`, case/identifier/comment variants trip `:109-117`, lowercase trips / plain trio passes `:119-123`. Allowlist trio defined in `test/audit_contract_guard_scans.dart:51-62`. | ✅ exact |
| E9 | `docs/campaigns/implementation-gate.md:56` — gate row 1 citation | Line 56 console row 1: "读路径接入（F-06）：审计页调 sink 读 API（tenant_id + trace_id 经 BFF）；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5" — names `lib/api/portal_api.dart`（实际路径，QA F-11 实测；**非** `lib/services/`）. | ✅ exact |
| E10 | `docs/proposals/audit-contract-batch-snaplink-console.md:6` — portal_api.dart scope flagged [PROPOSED] | `:6` "`lib/api/portal_api.dart`（路径存在，但作用域存疑 `[PROPOSED]`——它是门户客户端，管理端审计页实际走 `SnaplinkAdminApi`，已在 `governance_tab.dart:166` 用 `GET /api/v1/audit/events` 实测）"; `:9` records tenant_id/trace_id `[PROPOSED]`; `:12` is the existing `[RESOLVED]`（B6-2）note — the pattern REQ-0 follows. | ✅ exact |

Supplemental evidence (verified at HEAD):

| # | Fact | Location |
|---|---|---|
| S1 | Timeline reads through `AuditReadClient` → `SnaplinkAdminApi.get(eventsPath, query:)` (the get call is at `:52`); trio constants `eventsPath`/`facetsPath`/`eventDetailPath` (`:15-17`); `tenantId`/`traceId` are **caller-supplied constructor params (`:23-25`), forwarded verbatim, never derived** (`list()` `:35-52`, forwarding at `:45-46`; wire note `:26-34`) | `lib/api/audit_read_client.dart:15-17,23-25,35-52` |
| S2 | Timeline's tenant/trace boundary already recorded in the source: "B4-1 claim parsing / proxy-side trace_id injection are [PROPOSED] and out of scope; when absent the wire stays exactly `{'limit':'100'}` (AC-1)" | `lib/screens/admin/audit_log_tab.dart:29-35` (doc comment `:29-33` on the optional `tenantId`/`traceId` params `:34-35`; working-tree change already aligned) |
| S3 | Guard suite + query suite execute green at HEAD: `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart` → **38/38 passed** (AC-3.1/AC-3.2/AC-3.4 scans 1/2/4/5 incl. the E1–E6 evasion matrix; `audit_query_test.dart` AC-1.1 default-wire pin, AC-1.2/AC-1.3 presence/omission pins, AC-1.4 helper-text round-trip, AC-1.5 unknown-key throw) | executed 2026-08-08; `test/audit_query_test.dart:6-13` (AC-1.1) |
| S4 | `AuditQuery` wire compare in tests is `equals({'limit':'100'})` — Dart map equality is order-insensitive, satisfying the direction's "order-insensitive map compare" | `test/audit_query_test.dart:10-11` (AC-1.1 `:6-13`) |
| S5 | `AuditLogTab` already carries the rewire: `api`/`capabilities`/optional `tenantId`/`traceId` params, server-read doc header "Renders the sink's audit events through [AuditReadClient] … the localStorage ring is demoted to a debug-only recording surface (B6-1b) and is never a data source" | `lib/screens/admin/audit_log_tab.dart:12-36` |
| S6 | No claim parser exists in `lib/`: `grep -rni 'claim' lib/` → only JWT `sid`-claim handling in `portal_api.dart` (portal session expiry, `:59-60`) — no tenant-claim parsing; dep B4-1 unresolved | verified grep |
| S7 | Working tree at verification time: only `lib/screens/admin/audit_log_tab.dart` (doc-comment change, S2), the two b6-2 spec docs, and `test/oidc_login_handle_success_census_test.dart` differ from HEAD — none touches this direction's carriers | `git status` / `git diff --stat` |

## 3. Requirements

### REQ-0 — Decision record: `SnaplinkAdminApi.get` + `AuditQuery` is the console audit read carrier; `portal_api.dart` is not

Record the decision where the ambiguity was flagged — `docs/proposals/audit-contract-batch-snaplink-console.md:6` — as a `[RESOLVED]` note, matching the existing `[RESOLVED]`（B6-2）note pattern at `:12`. The note must name, with citations:

1. **Carrier:** the console audit read is `SnaplinkAdminApi.get('/api/v1/audit/events', query: AuditQuery(...).toQueryParameters())` — proven at `governance_tab.dart:183` and, since the rewire, `audit_read_client.dart:52`; endpoints documented at `snaplink_admin_types.dart:310-312`; typed builder `audit_query.dart` with default wire exactly `{'limit':'100'}` (`audit_query_test.dart` AC-1.1).
2. **Non-carrier:** `lib/api/portal_api.dart`（和 `lib/screens/portal/portal_api.dart` re-export shim）is a portal-only self-service client（sole instantiation `portal_screen.dart:90`; zero 'audit' identifiers）and is **left untouched** — no audit read surface is added there.
3. **Gate alignment:** `implementation-gate.md:56` row 1's parenthetical is thereby superseded on the carrier point; the row's acceptance（T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据）is served by the proven carrier, not by the portal client.

**Testable:** the `[RESOLVED]`（B6-1）note exists in `docs/proposals/audit-contract-batch-snaplink-console.md` and contains both the strings `SnaplinkAdminApi.get` and `AuditQuery`; `grep -in 'audit' lib/api/portal_api.dart lib/screens/portal/portal_api.dart` → exit 1 (REQ-1); AC-2 suite green.

### REQ-1 — `portal_api.dart` untouched: zero 'audit' identifiers in both files

`lib/api/portal_api.dart` and the re-export shim `lib/screens/portal/portal_api.dart` keep **zero** 'audit' identifiers — no imports, no methods, no path literals, no query builder, no client classes. The audit read lives exclusively on the admin transport (`SnaplinkAdminApi`), never on the portal client. Verified compliant at HEAD (E1/E2).

**Testable:** `grep -in 'audit' lib/api/portal_api.dart lib/screens/portal/portal_api.dart` → exit 1; `grep -n 'class Audit' lib/api/portal_api.dart` → exit 1; AC-3.1 green (a trio literal added there would trip the lib-wide literal scan, `audit_contract_guard_test.dart:27-32`).

### REQ-2 — Zero 'bff' literals in `lib/` (AC-3.2)

The unified AC-3.2 scan (`test/audit_contract_guard_test.dart:101-123`; semantics == `grep -rni "bff" lib/`, case-insensitive, identifiers and comments included) stays green. "Via BFF" — the gate row's tenant_id/trace_id transport wording — is realized exclusively as **parameter wiring through the existing typed builder** (`AuditQuery.tenantId`/`traceId`), never as `bff` literals, path segments, or class names in `lib/`.

**Testable:** `flutter test test/audit_contract_guard_test.dart` green (AC-3.2 green-against-tree `:102-107`); `grep -rni 'bff' lib/` → exit 1.

### REQ-3 — Audit read literals confined to the documented trio (AC-3.1)

Every audit-path literal in `lib/` normalizes into the allowlist `{/api/v1/audit/events, /api/v1/audit/facets, /api/v1/audit/events/{id}}` (`audit_contract_guard_scans.dart:51-62`; shared `{id}` normalizer incl. `${Uri.encodeComponent(<ident>)}`). Trio literals are owned by `AuditReadClient` (`audit_read_client.dart:14-16`, scan-5 ownership pin); consumers (`governance_tab.dart:31`, `audit_log_tab.dart`) reference the constants. No audit read literal may appear in `portal_api.dart` (REQ-1) or anywhere outside the allowlist.

**Testable:** `flutter test test/audit_contract_guard_test.dart` green (AC-3.1 green-against-tree `:27-32`; blob/encodeComponent probes `:34-50`; scan-5 ownership pin tests).

### REQ-4 — Default timeline wire is exactly `{'limit':'100'}`, order-insensitive

`AuditQuery(limit: 100).toQueryParameters()` equals the map `{'limit': '100'}` — Dart map equality is order-insensitive (S4). `tenant_id`/`trace_id`/`cursor`/`event_type`/`outcome` serialize iff non-null and (for strings) non-empty after trim; an all-null construction yields an empty map; unknown keys throw `AuditQueryParseException` (never a silent pass-through).

**Testable:** `flutter test test/audit_query_test.dart` green — AC-1.1 default `:6-13`, AC-1.2 presence `:16-25`, AC-1.3 whitespace omission `:27-36`, AC-1.4 round-trip, AC-1.5 unknown-key throw; AC-1.6 cursor/event_type.

### REQ-5 — Provenance gate: tenant_id/trace_id stay off the wire until server-side capabilities exist

`tenant_id` and `trace_id` are **explicitly absent** from any audit read wire until both `[PROPOSED]` capabilities exist as server-side facts:

- **tenant_id** — requires token-claim parsing; **no claim parser exists in `lib/`** (S6; dependency B4-1). Until B4-1 lands, the only sanctioned tenant source is caller-supplied context forwarded verbatim (`audit_read_client.dart` constructor `:23-25` → `list()` `:45-46` → `AuditQuery`), never derived, never hardcoded, never defaulted (`audit_log_tab.dart:29-35`).
- **trace_id** — requires BFF/proxy-side injection; **no repository surface exists** and `bff` literals are forbidden (REQ-2). Until then, `trace_id` is caller-supplied-only, same forwarding rule.

Consequence for the module: the login edge's timeline read ships with the `limit`-only wire. **Any future** tenant_id/trace_id parameter addition is a documented **proxy-log leakage review point** per b6-1a AC-1's no-leak query boundary — event content, search terms, and correlation context must never ride the URL into proxy logs; the limit-only default is the designed bound.

**Testable:** AC-1.1 (default wire has no tenant/trace keys); `grep -n 'tenantId\|traceId\|tenant_id\|trace_id' lib/screens/admin/audit_log_tab.dart` → only the optional constructor params (`:34-35`) + the boundary doc comment `:29-33` (S2); `grep -rn 'tenantId\|traceId' lib/api/audit_read_client.dart` → only the constructor (`:23-25`) and forwarding (`:45-46`) sites; zero `bff` literals (REQ-2).

## 4. Acceptance checks (supplied checks preserved 1:1, made testable)

The direction's acceptance has two items; each is preserved verbatim in substance and given a testable form. **Executed at HEAD: both items are green with zero code edits** (S7) — the change set is documentation-only.

**AC-1 — Direction acceptance (1): record the carrier decision in `docs/proposals/audit-contract-batch-snaplink-console.md` — a `[RESOLVED]` note naming `SnaplinkAdminApi.get` + `AuditQuery` as the console read carrier, `portal_api.dart` left untouched.**

Testable form (REQ-0/REQ-1):
1. The note lands adjacent to the flagged line (`:6`) or the `[PROPOSED]` line (`:9`) in the batch proposal, using the `[RESOLVED]`（B6-1, 2026-08-08）pattern already established at `:12`（B6-2）.
2. `grep -n '\[RESOLVED\]' docs/proposals/audit-contract-batch-snaplink-console.md` hits the B6-1 note; the note body contains `SnaplinkAdminApi.get` **and** `AuditQuery` **and** states that `portal_api.dart` is untouched（or its Chinese equivalent）.
3. `grep -in 'audit' lib/api/portal_api.dart lib/screens/portal/portal_api.dart` → exit 1（zero identifiers — REQ-1）.

**AC-2 — Direction acceptance (2): `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart` green — zero 'audit' identifiers in `lib/api/portal_api.dart` and `lib/screens/portal/portal_api.dart`, zero 'bff' literals in `lib/`, every audit read literal within the allowed `/api/v1/audit/events[/{id}|/facets]` set, and the timeline's default `AuditQuery` wire exactly `{'limit':'100'}` (order-insensitive map compare) — tenant_id/trace_id explicitly absent until [proposed] B4-1 token-claim parsing and BFF trace_id injection exist as server-side capabilities; any future tenant_id/trace_id parameter is a documented proxy-log leakage review point per b6-1a AC-1.**

Testable form (executed at HEAD — **38/38 passed**, S3):
1. `flutter test test/audit_contract_guard_test.dart` green → AC-3.1 literal allowlist (REQ-3), AC-3.2 `bff` ban (REQ-2), scans 4/5 (builder wiring, trio-literal ownership).
2. `flutter test test/audit_query_test.dart` green → AC-1.1 (`:6-13`) default wire exactly `{'limit':'100'}` via order-insensitive map equality (REQ-4), AC-1.2 (`:16-25`) / AC-1.3 (`:27-36`) presence/omission semantics, AC-1.5 unknown-key rejection.
3. `grep -in 'audit' lib/api/portal_api.dart lib/screens/portal/portal_api.dart` → exit 1 (REQ-1).
4. `grep -rni 'bff' lib/` → exit 1 (REQ-2).
5. Provenance gate (REQ-5): AC-1.1's wire has no `tenant_id`/`trace_id` keys; `audit_log_tab.dart`'s tenant/trace params (`:34-35`) are optional, documented `[PROPOSED]`-gated (`:29-33`), forwarded verbatim never derived (`audit_read_client.dart:23-25,45-46`); the leakage-review-point statement stands in the batch proposal's `[RESOLVED]` note (AC-1).

**Gate linkage:** T-12 joint（gate row 1, dep B1-5）— the carrier decision recorded by AC-1/AC-2 is the prerequisite the oidc_login timeline joint (`b6-1-lib-screens-oidc-login-audit-visibility-spec.md` AC-1 Phase B) and the b6-1a tab tests compile against; the module's login edge renders via the proven server feed, never the ring (sibling direction 2, zero ring references in `lib/screens/oidc_login/` — 28 files, verified).

## 5. Dependency, scope guard, and expected change set

**Dependencies (explicit):**
- **B4-1**（[proposed] token-claim parsing）— the tenant_id provenance prerequisite; until it lands, tenant_id is caller-supplied-only (REQ-5). No code in this change set.
- **B1-5**（gate row 1 dependency）— the carrier decision precedes the timeline joint evidence; the b6-1a tab surface (`AuditLogTab(api:, capabilities:)`) is already landed in the working tree (S5).
- Sibling b6-1 specs — the timeline rewire, ring demotion (b6-1b), and the read client are owned there; this spec references, never re-specifies, them.

**Out of scope (explicitly not changed):**
- `lib/api/portal_api.dart` and `lib/screens/portal/portal_api.dart` — REQ-1 forbids edits; the record, not the code, is the deliverable.
- Any production code in `lib/` — the guard suite is green at HEAD (AC-2); the direction's "record, don't guess" is documentation + verification.
- B4-1 claim parser, BFF/proxy trace_id injection, `tests/integration/audit_login_drill.py`, the joint widget test `test/oidc_login_audit_timeline_joint_test.dart`（owned by the visibility spec AC-1 Phase B, ships with B6-1）.
- The b6-1a no-leak boundary tests (`test/audit_log_tab_test.dart` AC-1.6) — owned by `b6-1a-lib-api-auditlogtab-server-read-spec.md`; REQ-5 references their review-point semantics only.
- The gate row text at `implementation-gate.md:56` — the direction asks to **record the decision**, not amend the gate row; the note (AC-1) supersedes the row's parenthetical by reference.

**Expected change set:**
1. `docs/proposals/audit-contract-batch-snaplink-console.md` — add the `[RESOLVED]`（B6-1）carrier note (AC-1, REQ-0). **The only file edited.**
2. This spec (`docs/proposals/b6-1-lib-screens-oidc-login-read-carrier-resolution-spec.md`).
3. Zero `lib/` edits; zero test edits — `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart` must stay 38/38 green before and after (AC-2, verified).

**Risk and rollback:** pure documentation change — revert the note with a one-line diff; no data migration, no behavior change, no reverted test. The residual risk the direction names（tenant_id/trace_id fabrication leaking event content into proxy logs）is bounded by REQ-5's gate and the b6-1a AC-1 no-leak boundary, both of which are asserted by the green guard suite at every run.
