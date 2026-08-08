# B6-1 — Design: read-carrier resolution + tenant_id/trace_id provenance gate (module: lib/screens/oidc_login)

> Upstream: `docs/proposals/b6-1-lib-screens-oidc-login-read-carrier-resolution-spec.md` (requirements).
> Every citation below was re-verified at HEAD (2026-08-08) before writing this design; the acceptance suite `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart` was executed and is green **38/38** at HEAD.
> **Five defects in the upstream evidence/acceptance were found during verification and are corrected in this design** — §0.4 D1 (E6's line corrections are incomplete: `_auditPath` is `:35` not `:31`, the admin get call is `:187` not `:183`; "`:183` get call exact" is false at HEAD), D2 (S1 off-by-one: `audit_read_client.dart` get call is `:51` not `:52`), D3 (S6's "no claim parser exists in `lib/`" is false at HEAD — `PortalApi._claimFromToken` `portal_api.dart:76-94` is a generic JWT claim reader; the *tenant*-claim gap holds, the absolute claim does not), D4 (AC-1 is **not** green at HEAD: the `[RESOLVED]`（B6-1）note does not exist in `audit-contract-batch-snaplink-console.md` — only the B6-2 note at `:12` — and the spec's §4 "both items green with zero code edits" contradicts its own §5 pending change set; the AC-1 item-2 grep as written would vacuously pass on the B6-2 note), D5 (REQ-5's testable grep is over-constrained and **fails at HEAD**: `tenantId`/`traceId` legitimately appear at `audit_log_tab.dart:34-35,41-42,69-70,143,195,474` (camel pattern; the snake-case doc `:31` and CSV header `:185` are outside it) and `audit_read_client.dart` forwards them in *two* methods — `list()` `:45-46` and `facets()` `:76-77` — not "only `:34-35` + `:29-33`").

## 0. Evidence verification (claims re-checked, not trusted)

> **Working-tree-relative pins:** all `audit_log_tab.dart` line pins in this design (§0.3 S2/S5, §0.4 D5, §1.2) are relative to the **working tree** at `26782c5` + the uncommitted doc-comment reword (net **+1 line**: 3 lines → 4). At the *committed* HEAD they are all −1 (`:33-34`/`:40-41`/`:68-69`/`:142`/`:184`/`:194`/`:473`). "At HEAD" throughout = the verified working tree (S7); every acceptance grep is content-based, so no acceptance depends on the +1. The `audit_read_client.dart`, `snaplink_admin_api.dart`, `portal_api.dart`, and `test/` pins are identical in both.

### 0.1 The evidence message itself (design-stage input)

| Claim | Verified reality | Verdict |
|---|---|---|
| Spec delivered at `docs/proposals/b6-1-lib-screens-oidc-login-read-carrier-resolution-spec.md` | File exists (untracked; matches the run artifact `requirements-10762e10/requirements.md` modulo the delivery-summary header) | ✅ |
| "All 10 direction citations hold; three got line corrections marked `[CORRECTION]`" | E5/E6/E7 carry `[CORRECTION]`; **E6's correction is incomplete** — the same +4 shift that moved the gate `:400→:404` also moved `_auditPath` `:31→:35` and the get call `:183→:187`, both left uncorrected; the evidence table's "`:183` get call exact" is FALSE at HEAD | ⚠️ E6 row inaccurate |
| "38/38 green at HEAD with zero code edits" | **Executed**: 38/38 passed (`audit_contract_guard_test.dart` + `audit_query_test.dart`) | ✅ |
| Working-tree `audit_log_tab.dart` change is doc-comment-only and records the `[PROPOSED]`-gated tenant/trace boundary | `git diff` = 5-line doc-comment rewording only ("BFF trace_id injection" → "proxy-side trace_id injection"); params `:34-35` unchanged; boundary doc `:29-33` | ✅ |
| "Spec §4: both items green at HEAD" | **False for AC-1** — the `[RESOLVED]`（B6-1）note is absent from the batch proposal (D4) | ❌ |

### 0.2 Direction citations E1–E10 (re-verified at HEAD)

| # | Claim | Verified reality | Verdict |
|---|---|---|---|
| E1 | `portal_api.dart` grep 'audit' = 0 (both files) | `grep -ci 'audit' lib/api/portal_api.dart` → 0; shim `lib/screens/portal/portal_api.dart` (3-line re-export) → 0 | ✅ exact |
| E2 | `:56-60,180-265` client surface, no audit read, no query builder | `class PortalApi` `:37`; `onSessionExpired` `:57`; `hasToken` `:59`; transport `get` `:110` (**no `query:` param**), `post` `:159`, `patch` `:171`, `put` `:183`, `delete` `:191`, `deleteWithQuery` `:194`; `login` `:233`, `logout` `:268`, `fetchMe` `:270`, `fetchListOrEmpty` `:282` | ✅ substance exact (ranges approximate) |
| E3 | `portal_screen.dart:90` sole instantiation | `_api = widget.api ?? PortalApi();` at `:90` | ✅ exact |
| E4 | `snaplink_admin_types.dart:310-312` trio | `:310` events, `:311` facets, `:312` events/{id} | ✅ exact |
| E5 | `audit_query.dart` builder; default `{'limit':'100'}` | `class AuditQuery` `:17`; default-wire doc `:13-16`; `supportedKeys` `:51-58`; `toQueryParameters()` `:148`; `AuditQueryParseException` `:167` | ✅ (corrected lines hold) |
| E6 | `governance_tab.dart:31/:166-191/:400` server read + capability gate | `_auditPath = AuditReadClient.eventsPath` **`:35`** (not `:31`); trio-literal comment `:32-34`; `_queryAudit()` `:171`; `widget.api.get(_auditPath, query: parameters)` **`:187`** (not `:183`); facets gate `:188`; `_auditArea` `:400`, capability gate `:404`; `_has` `:85` | ⚠️ gate corrected; `:31`/`:183` uncorrected (+4 shift) |
| E7 | `snaplink_admin_api.dart:126` `get(path, query:)` | signature `:124-127`, `Map<String, String>? query` `:126`; `_recordAudit` `:81-84`; mutation-only guard `:322-325` | ✅ (corrected) |
| E8 | `audit_contract_guard_test.dart:27-50` allowlist; `:101-123` AC-3.2 | AC-3.1 group **`:29-101`** (green `:30-35`, blob tokens `:37-47`, encodeComponent `:49-60`); AC-3.2 group **`:103-132`** (green `:104-109`, case/comment probes `:111-120`, lowercase `:122-131`); allowlist trio `audit_contract_guard_scans.dart:51-57` + bare-prefix allowlist `:59-64` | ⚠️ **pins stale at HEAD** (pre-HEAD numbering — b82d2cf-era for AC-3.1 — was marked "exact"); trip substance holds |
| E9 | `implementation-gate.md:56` gate row 1 | Row 1 verbatim: "读路径接入（F-06）：审计页调 sink 读 API（tenant_id + trace_id 经 BFF）；localStorage ring 降级为调试记录；展示服务端记录 \| T-12 联合：查询触发 self-audit 行；devtools 伪造不再构成证据 \| B1-5" | ✅ exact |
| E10 | `audit-contract-batch-snaplink-console.md:6` `[PROPOSED]`; `:9` tenant/trace; `:12` `[RESOLVED]`（B6-2） | `:6` portal_api scope `[PROPOSED]`; `:9` tenant_id/trace_id `[PROPOSED]`; `:12` `[RESOLVED]`（B6-2, 2026-08-07）note — the pattern REQ-0 follows | ✅ exact |

### 0.3 Supplemental S1–S7 (re-verified at HEAD)

| # | Claim | Verified reality | Verdict |
|---|---|---|---|
| S1 | Timeline reads via `AuditReadClient` → `SnaplinkAdminApi.get(eventsPath, query:)` at `:52`; trio `:15-17`; ctor `:23-25`; forwarding `:45-46` | trio `:15-17` ✅; ctor `:23-25` ✅; `list()` `:35-52`; forwarding `:45-46` ✅; **get call at `:51`** (return line `:51`); **second forwarding site `facets()` `:76-77`** (D5); detail reader `event()` `:86-87` (no query params) | ⚠️ off-by-one `:52`→`:51`; forwarding claim incomplete (`facets()` missed) |
| S2 | `audit_log_tab.dart:29-35` boundary doc + optional params | doc `:29-33` ("B4-1 claim parsing / proxy-side trace_id injection are [PROPOSED]…"); `tenantId` `:34`, `traceId` `:35` | ✅ exact |
| S3 | Guard + query suites green at HEAD (38/38) | **Executed** 2026-08-08: 38/38 passed | ✅ exact |
| S4 | `equals({'limit':'100'})` — order-insensitive | `audit_query_test.dart:10-11` (AC-1.1 `:6-13`); AC-1.2 `:16-25`; AC-1.3 `:27-36` | ✅ exact |
| S5 | `AuditLogTab` carries `api`/`capabilities`/optional `tenantId`/`traceId`; server-read doc header | `:25-27` params; header `:19-24` ("the localStorage ring is demoted to a debug-only recording surface (B6-1b) and is never a data source") | ✅ exact |
| S6 | "No claim parser exists in `lib/`" | **False as stated**: `PortalApi._claimFromToken(token, claim)` `portal_api.dart:76-94` is a generic JWT claim reader (payload decode `:84`, `claims[claim]` `:86`); used for `aud` `:70` (`currentClientId`) and `sid` `:73`; no **tenant**-claim parsing exists anywhere; no claim parsing on the admin/audit read path; dep B4-1 unresolved | ⚠️ absolute claim false; gate substance holds |
| S7 | Working tree = `audit_log_tab.dart` (doc-comment), two b6-2 spec docs, census test | `git diff --stat` matches exactly (4 files; + the untracked b6-1 spec); none touches this direction's carriers | ✅ exact |

### 0.4 Defects found in the upstream evidence (this design's corrections)

**D1 — E6's line corrections are incomplete (same +4 shift, only one of three sites corrected).**
`governance_tab.dart` gained 4 lines (the "Trio literals live only in AuditReadClient" comment block at `:32-34`) since the direction was authored. The gate was corrected (`:400→:404`) but `_auditPath` (`:31→:35`) and the admin get call (`:183→:187`) were left at pre-shift values, and the evidence table explicitly claims "`:183` get call exact". The spec's §1 problem statement repeats `:183`/`:167-183`. **Correction:** the note (this design §1.2) cites `:35`, `:171`, `:187`, `:404`; §5 acceptance greps are content-based, never line-based.

**D2 — S1 off-by-one: the admin get call is at `audit_read_client.dart:51`, not `:52`.**
`list()` spans `:35-52`; the `return auditEventRowsFromResponse(await _api.get(eventsPath, query: query));` line is `:51`, the closing brace `:52`. The spec's §1 problem statement and S1 both cite `:52`. **Correction:** `:51` everywhere; note cites `:51`.

**D3 — S6's "no claim parser exists in `lib/`" is false at HEAD.**
`PortalApi._claimFromToken` (`portal_api.dart:76-94`) is a generic JWT-claim reader (base64-payload decode + `claims[claim]` lookup) exercised for `aud` (`:70`) and `sid` (`:73`). The direction's own problem statement repeats the overclaim. The **gate substance is unaffected**: no *tenant*-claim parsing exists, no claim parsing exists on the admin/audit path, and `PortalApi` is REQ-1-forbidden territory anyway (B4-1 remains the dependency). **Correction:** REQ-5's rationale is restated as "no tenant-claim parsing on the audit read path (B4-1); the only JWT claim-reading primitive is the portal-only `PortalApi._claimFromToken`, which is off-limits (REQ-1)".

**D4 — AC-1 is not green at HEAD: the `[RESOLVED]`（B6-1）note does not exist.**
`grep -n 'RESOLVED' docs/proposals/audit-contract-batch-snaplink-console.md` → only `:12` (the B6-2 note). The spec's §4 header claims "**Executed at HEAD: both items are green with zero code edits**" — false for AC-1 items 1–2 — while §5 correctly lists the note as the one pending edit. Worse, AC-1 item 2's testable form as written (`grep -n '\[RESOLVED\]' … hits the B6-1 note`) would **vacuum-pass**: the grep hits `:12` (B6-2) even with no B6-1 note present. **Correction:** AC-1 is a *post-implementation* acceptance (runs after the note lands); the grep pins the B6-1 note by pattern `` `[RESOLVED]`（B6-1 `` (backtick-aware — Defect B; the `:12` note is `` `[RESOLVED]`（B6-2 … ``) plus body tokens (`SnaplinkAdminApi.get` AND `AuditQuery`); AC-2 is green at HEAD independently. §4's "both green" claim is corrected to "AC-2 green at HEAD; AC-1 pending the note".

**D5 — REQ-5's testable grep is over-constrained and fails at HEAD.**
The spec's REQ-5 testable form requires `grep -n 'tenantId\|traceId\|tenant_id\|trace_id' lib/screens/admin/audit_log_tab.dart` to hit "only the optional constructor params (`:34-35`) + the boundary doc comment `:29-33`". Executed at HEAD it hits **eight** sites: doc `:31`, declaration `:34-35`, super-forward `:41-42`, `AuditReadClient` construction `:69-70`, row filter `:143`, CSV header `:185`, CSV write `:195`, row render `:474` — all legitimate consumers of the caller-supplied values (the rewire forwards `widget.tenantId`/`widget.traceId` into the read client at `:69-70`; the rest are display/filter/CSV uses of the returned rows). Similarly `audit_read_client.dart` forwards at `:45-46` (`list()`) **and** `:76-77` (`facets()`), and the spec's S1 only names the first. **Correction (§5, incl. the post-review Defect A re-derivation):** the REQ-5 grep is re-scoped to the actual invariant — *declaration-and-forwarding sites only, no derivation* — and the expected sets now byte-match the corrected camel-only pattern's real output at HEAD: `audit_log_tab.dart` → **`{34,35,41,42,69,70,143,195,474}`** (optional-param declaration `:34-35`, super-forward `:41-42`, read-client construction `:69-70`, row consumption `:143` filter / `:195` CSV write / `:474` render — all consume the caller-supplied values, none derive; the boundary doc `:29-33` and CSV header `:185` are snake-case and never match the camel pattern, so `:31`/`:185` are **not** in the set); `audit_read_client.dart` → **`{10,20,21,23,24,25,40,41,45,46,70,71,76,77}`** (doc `:10`, ctor `:20-25`, `list()` `:40-46`, `facets()` `:70-77` — forwarding only). The wire-level guarantee (no tenant/trace keys in the default wire, AC-1.1) is the authoritative pin and remains unchanged.

### 0.5 Post-review corrections to this design (second pass — adversarial re-verification, 2026-08-08)

- **Defect B (the design's own F1 pin was broken).** §3 F1 / §4 step 3 / §5 AC-1.1 used `grep -n '\[RESOLVED\]（B6-1'`; the verbatim note (and the `:12` precedent it mirrors) has a **backtick between `]` and `（`** — `` `[RESOLVED]`（B6-1, 2026-08-08） ``. The un-backticked pattern returns exit-1 both pre- and post-edit (simulated; control `` `grep -nF '[RESOLVED]`（B6-1' `` hits), so AC-1.1 could never go green, while its natural relaxation (`\[RESOLVED\]`) is exactly the D4 vacuous-pass hole F1 was built to close. **Fixed** with `grep -nF '[RESOLVED]`（B6-1' in all three places; re-simulated post-edit: hit, and the B6-2 note at `:12` does not match it.
- **Defect A (REQ-5 sets did not byte-match the corrected command).** D5's first correction expected `audit_log_tab.dart:31,34-35,41-42,69-70` — but `:31` is snake-case doc (`trace_id`) and never matches the camel pattern, while `:143/:195/:474` (`row.tenantId` consumers) do match; `audit_read_client.dart:10` (doc) matches but was excluded. **Fixed:** expected sets re-derived to the byte-exact HEAD output — `{34,35,41,42,69,70,143,195,474}` / `{10,20,21,23,24,25,40,41,45,46,70,71,76,77}` (declaration/forwarding/consumption only, no derivation; wire pin AC-1.1 remains the sole hard gate).
- **E8 pins were stale (pre-HEAD numbering marked "exact").** At HEAD the guard-test groups are AC-3.1 `:29-101` (green `:30-35`, blob `:37-47`, encode `:49-60`) and AC-3.2 `:103-132` (green `:104-109`, probes `:111-120`, lowercase `:122-131`); the `'// bff path is proposed only'` probe is `:116`; the scans-file allowlist is trio `:51-57` + bare-prefix `:59-64` (not `:51-62`).
- **Attribution fix.** The note's "proxy-log 泄漏评审点" sentence is **b6-1a REQ-3** (`b6-1a-lib-api-auditlogtab-server-read-spec.md:51`), not b6-1a AC-1 — AC-1 *asserts* the no-leak exact-`{limit:100}` boundary, the "review point" wording is REQ-3's.
- **Minor span fixes.** S1 `event()` `:86-87`; S4 AC-1.2 `:16-25`; E7 mutation-only guard `:322-325`; `_claimFromToken` `:76-94` (was `:76-91` — omitted the catch-block close, `return null`, and the closing brace at `:92-94`).

## 1. API changes

### 1.1 Production API: none — a verified constraint, not a choice

Zero `lib/` edits and zero test edits. This is enforced by the guard suite itself: any audit literal outside the trio trips AC-3.1 (green `:30-35`), any `bff` literal trips AC-3.2 (including in comments — the `'// bff path is proposed only'` probe at `:116` trips identically, which is exactly why the working-tree `audit_log_tab.dart` doc-comment change from "BFF" to "proxy-side" was required), and any trio literal outside `AuditReadClient` trips the scan-5 ownership pin. `PortalApi` keeps its bare transport (`get` `:110` has no `query:`); `SnaplinkAdminApi.get(path, {query, forceRefresh})` (`:124-127`) + `AuditQuery.toQueryParameters()` remain the sole read surface.

### 1.2 The documentation contract: the `[RESOLVED]`（B6-1）note

The "API" of this change is one inserted bullet in `docs/proposals/audit-contract-batch-snaplink-console.md`. Placement is **content-anchored**: immediately after the `- `[PROPOSED]`：tenant_id（token claim 解析，依赖 B4-1）…` bullet (`:9`, end of the B6-1 section), before the blank line and `**B6-2 边缘生成验证**` header (`:11`). Never line-anchored — the doc drifts.

Verbatim note (mirrors the `[RESOLVED]`（B6-2, 2026-08-07）pattern at `:12`):

> - `[RESOLVED]`（B6-1, 2026-08-08）：**读路径 carrier 定案**——console 审计读走 `SnaplinkAdminApi.get('/api/v1/audit/events', query: AuditQuery(...).toQueryParameters())`：实测于 `lib/screens/admin/governance_tab.dart:187`（`_queryAudit`，能力门禁 `_has('GET', _auditPath)` `:404`）；rewire 后 timeline 经 `AuditReadClient.list()` → `lib/api/audit_read_client.dart:51` 同一载体；端点 trio `lib/api/snaplink_admin_types.dart:310-312`；默认 wire 恰为 `{'limit':'100'}`（`test/audit_query_test.dart` AC-1.1，order-insensitive map compare）。`lib/api/portal_api.dart`（及 re-export shim `lib/screens/portal/portal_api.dart`）是门户自服务客户端（唯一实例化 `lib/screens/portal/portal_screen.dart:90`；零 'audit' 标识符），**保持不动**——不新增审计读表面；`implementation-gate.md:56` 行 1 括号注记在 carrier 点上以此为准（T-12 验收由被证明的载体承担，不经门户客户端）。tenant_id/trace_id 保持 off-wire（REQ-5 门禁）：二者 caller-supplied-only，经 `AuditReadClient` 构造参数原样转发（`audit_read_client.dart:23-25` → `list()` `:45-46`、`facets()` `:76-77`），绝不派生、绝不硬编码、绝不默认化；**任何未来的 tenant_id/trace_id 参数都是 b6-1a REQ-3 界定的 proxy-log 泄漏评审点**（`b6-1a-lib-api-auditlogtab-server-read-spec.md:51`）——事件内容、检索词、关联上下文不得进入 URL，limit-only 默认即为设计边界。守卫套件 AC-3.1/AC-3.2/AC-3.4 在 HEAD 38/38 绿（`test/audit_contract_guard_test.dart` + `test/audit_query_test.dart`）。

Mandatory machine-checkable tokens (the note's "signature"):
1. `[RESOLVED]`（B6-1, 2026-08-08 — full-width parens, exact pattern.
2. `SnaplinkAdminApi.get` — the carrier call.
3. `AuditQuery` — the typed builder.
4. `保持不动` (or "untouched") applied to `portal_api.dart` — the non-carrier statement.
5. `proxy-log 泄漏评审点` — the REQ-5 leakage-review-point record (wording "proxy-side", never a `bff` literal — docs are outside AC-3.2's scan, but the lib/-compatible precedent set by the working-tree `audit_log_tab.dart` change is kept).

### 1.3 Corrected citation pins (D1/D2 — what the note and this design must use)

| Symbol | Pre-shift (direction/spec) | Corrected (HEAD) |
|---|---|---|
| `governance_tab.dart` `_auditPath` | `:31` | `:35` |
| `governance_tab.dart` `_queryAudit` | `:167-183` | `:171` |
| `governance_tab.dart` admin get call | `:183` | `:187` |
| `governance_tab.dart` capability gate | `:400` | `:404` |
| `audit_read_client.dart` admin get call | `:52` | `:51` |

## 2. Compatibility constraints

1. **Guard-suite compatibility (the hard contract).** AC-3.1 (trio literal allowlist + `{id}` normalizer + scan-5 ownership), AC-3.2 (zero `bff` literals in `lib/`, comments included), AC-3.4 (raw-stringification scan), and `audit_query_test.dart` AC-1.1–1.6 must stay green before and after — the change is docs-only, so they are *expected* to stay byte-identical; any trip is a mis-scoped edit.
2. **REQ-1/REQ-2 floors.** `lib/api/portal_api.dart` + shim keep zero 'audit' identifiers; `lib/` keeps zero `bff` literals. The note itself lives in `docs/` (not scanned) and uses "proxy-side" wording to stay consistent with the lib/ precedent.
3. **Batch-proposal format.** Chinese language; `[RESOLVED]`（B6-1, 2026-08-08）pattern mirrors `:12`; the note is a bullet inside the B6-1 section (before the B6-2 header) — it must not be appended after the B6-2 section or merged into the `:6`/`:9` bullets.
4. **Citation correctness.** The note cites the corrected lines (§1.3). File paths + symbols are primary; line numbers are snapshots — the note's own future greps must be content-based.
5. **Sibling-spec boundaries.** Trio ownership (`AuditReadClient`), timeline rewire + no-leak boundary (b6-1a family), ring demotion (b6-1b), joint test (visibility spec AC-1 Phase B) are referenced, never re-specified.
6. **Gate row untouched.** `implementation-gate.md:56` is superseded by reference from the note; no gate amendment.
7. **No concurrent-edit hazard.** `audit-contract-batch-snaplink-console.md` is shared with the b6-2 campaign's records; the change is a single inserted bullet, committed alone.

## 3. Failure modes

| F# | Failure | Detection | Mitigation |
|---|---|---|---|
| F1 | **Vacuous PASS on AC-1**: `grep -n '\[RESOLVED\]'` hits only the B6-2 note at `:12` and is counted as "the B6-1 note" | Spec's AC-1 item 2 as written would pass pre-edit | Pin: `` `grep -nF '[RESOLVED]`（B6-1' `` (backtick-aware — the verbatim note and the `:12` precedent both carry a backtick between `]` and `（`; the un-backticked form is exit-1 even post-edit, and relaxing to `\[RESOLVED\]` reopens the vacuous pass — Defect B) must hit, AND the note region must contain `SnaplinkAdminApi.get` + `AuditQuery` (D4) |
| F2 | Note inserted in the wrong section (after B6-2, or merged into `:6`) | Section order check fails | Content anchor: after `:9` bullet, before `**B6-2 边缘生成验证**`; post-edit verify `grep -n 'B6-2 边缘生成验证' docs/proposals/audit-contract-batch-snaplink-console.md` line > note line |
| F3 | Line drift invalidates the note's citations (`:187` shifts again) | Future census | Path+symbol primary, line numbers snapshot; acceptance greps content-based (§5) |
| F4 | Note accidentally lands in `lib/`/`test/` (e.g., as a comment) | AC-3.1/AC-3.2/scan-5 trip (comment probes prove comment scans) | Scope guard: the only file edited is the batch proposal; suite re-run after edit |
| F5 | Grep encoding mismatch: full-width `（B6-1` vs half-width `(B6-1`; case variants | `grep` misses / false hits | Exact byte pattern `（B6-1`; REQ-1 uses `-in`, REQ-2 uses `-rni` — semantics documented in the spec are preserved |
| F6 | Future tenant_id/trace_id param added without the review point | AC-1.1 wire pin fails (`{'limit':'100'}` drifts) | REQ-5 gate + the note's standing leakage-review-point sentence |
| F7 | "Both items green at HEAD" misread as implementable-now (D4) | AC-1 item 1 not executable pre-edit | Corrected acceptance: AC-2 green at HEAD; AC-1 runs post-edit |
| F8 | Stale citations (`:183`/`:52`/`:31`) propagate into the note | Review grep census | §1.3 pins corrected values; this design's D1/D2 record the shifts |
| F9 | Rollback leaves residue | `git diff` shows more than one inserted bullet | One-line-diff rollback: remove the single bullet; docs-only ⇒ no behavioral residue |
| F10 | Concurrent b6-2 edit of the same file merged into this change | Diff scope grows | Single-purpose commit (one bullet); pipeline `git_commit: true` |
| F11 | REQ-5 grep over-constrained (spec form fails at HEAD: `:41-42`/`:69-70`/`facets()` forwarding missed) | Spec's REQ-5 testable form would fail pre-edit | D5 + Defect A correction: expected site sets re-derived to byte-match HEAD (`{34,35,41,42,69,70,143,195,474}` / `{10,20,21,23,24,25,40,41,45,46,70,71,76,77}`), wire pin AC-1.1 as authority |

## 4. Migration steps

1. **Baseline (pre-edit, at HEAD):** execute `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart` → record **38/38**; record `grep -in 'audit' lib/api/portal_api.dart lib/screens/portal/portal_api.dart` → exit 1; `grep -rni 'bff' lib/` → exit 1; `grep -n 'RESOLVED' docs/proposals/audit-contract-batch-snaplink-console.md` → `:12` only (proves AC-1 pending, D4).
2. **Edit (the only edit):** insert the §1.2 note bullet into `docs/proposals/audit-contract-batch-snaplink-console.md` after the `:9` `[PROPOSED]` bullet, before the blank line + `**B6-2 边缘生成验证**` header.
3. **Verify presence (AC-1):** `` `grep -nF '[RESOLVED]`（B6-1' docs/proposals/audit-contract-batch-snaplink-console.md `` → ≥1 hit (backtick-aware — Defect B); the note line/region contains `SnaplinkAdminApi.get` and `AuditQuery`; `grep -n '保持不动' docs/proposals/audit-contract-batch-snaplink-console.md` → the note region; section order: note line < `**B6-2 边缘生成验证**` line.
4. **Verify invariants (AC-2, unchanged):** re-run the two suites → still 38/38; portal greps exit 1; bff grep exit 1. Any change in these results means a mis-scoped edit (F4).
5. **Record:** append the design/decision record to the run's `DECISIONS.md`; commit (pipeline `git_commit: true`). No `lib/`, no `test/`, no gate-row edits.

## 5. Testable acceptance mapping

| Spec acceptance | Corrected testable form | Command | Expected |
|---|---|---|---|
| AC-1.1 note recorded (REQ-0) | B6-1 note exists, B6-2 pattern mirrored | `` `grep -nF '[RESOLVED]`（B6-1' docs/proposals/audit-contract-batch-snaplink-console.md `` (backtick-aware — matches the `` `[RESOLVED]`（B6-1, 2026-08-08） `` note verbatim; the un-backticked pattern is exit-1 pre- and post-edit, and `\[RESOLVED\]` would vacuously hit the B6-2 note — Defect B) | ≥1 hit |
| AC-1.1 carrier named (REQ-0.1) | Note body carries both tokens | `grep -c 'SnaplinkAdminApi.get' docs/proposals/audit-contract-batch-snaplink-console.md`; `grep -c 'AuditQuery' …` | ≥1 each |
| AC-1.1 portal untouched (REQ-0.2/REQ-1) | Non-carrier statement present | `grep -n '保持不动' docs/proposals/audit-contract-batch-snaplink-console.md` (note region) | ≥1 |
| AC-1.2/REQ-1 zero identifiers | — | `grep -in 'audit' lib/api/portal_api.dart lib/screens/portal/portal_api.dart` | exit 1 |
| AC-2.1/REQ-3 literal allowlist | — | `flutter test test/audit_contract_guard_test.dart` | green (AC-3.1/3.2/3.4 + scans 1/2/4/5) |
| AC-2.2/REQ-4 default wire | — | `flutter test test/audit_query_test.dart` | green (AC-1.1 `:6-13` `equals({'limit':'100'})`; AC-1.2/1.3 presence/omission; AC-1.5 unknown-key throw) |
| AC-2.3/REQ-2 zero bff | — | `grep -rni 'bff' lib/` | exit 1 |
| AC-2.5/REQ-5 provenance gate | tenant/trace off the wire; params optional, verbatim-forwarded, never derived | AC-1.1 (no tenant/trace keys); `grep -n 'tenantId\|traceId' lib/screens/admin/audit_log_tab.dart` → exact site set **`{34,35,41,42,69,70,143,195,474}`** (declaration `:34-35`, super-forward `:41-42`, read-client construction `:69-70`, row consumption `:143` filter / `:195` CSV write / `:474` render — all consume the caller-supplied values, none derive; the snake-case doc `:29-33` and CSV header `:185` never match the camel pattern — Defect A); `grep -n 'tenantId\|traceId' lib/api/audit_read_client.dart` → exact site set **`{10,20,21,23,24,25,40,41,45,46,70,71,76,77}`** (doc `:10`, ctor `:20-25`, `list()` `:40-46`, `facets()` `:70-77` forwarding — no derivation); both sets byte-identical post-edit (docs-only change); leakage-review-point sentence present in the note | all hold (sets byte-match HEAD) |
| Gate linkage (T-12, B1-5) | Carrier decision recorded before timeline joint | AC-1 greps above + §5's D4 note (AC-1 pending pre-edit, green post-edit) | hold post-edit |

**Execution status at HEAD (2026-08-08):** AC-2 fully green (38/38); AC-1 pending the §1.2 note — the only remaining edit of this direction. The spec's §4 "both items green" claim is corrected accordingly (D4).

## 6. Scope, rollback, residual risk

**In scope:** one inserted bullet in `docs/proposals/audit-contract-batch-snaplink-console.md` (the `[RESOLVED]`（B6-1）carrier note) + this design. **Explicitly out:** `lib/api/portal_api.dart` + shim (REQ-1 forbids edits), all `lib/` and `test/`, B4-1 tenant-claim parsing, proxy trace_id injection, `implementation-gate.md:56` text, sibling b6-1a/b6-1b/visibility deliverables, the joint test file.

**Rollback:** remove the single note bullet — a one-line diff restoring HEAD exactly; docs-only, so no behavioral or test-state residue (F9).

**Residual risk:** the direction's named risk — tenant_id/trace_id fabrication leaking event content into proxy logs — is bounded by REQ-5's gate and the b6-1a no-leak boundary (AC-1 asserts the exact-`{limit:100}` boundary; the future-param review point is REQ-3 at `b6-1a-lib-api-auditlogtab-server-read-spec.md:51`), asserted by the green guard suite on every run (F6). The residual *documentation* risk (stale line citations) is bounded by content-based acceptance (F3). D3's correction (claim-parser existence) does not weaken the gate: `PortalApi._claimFromToken` is on REQ-1-forbidden territory and reads `aud`/`sid` only — never `tenant_id`.
