# B6-1c — Review: API change 1 (`AuditQuery`, `AuditQueryParseException`, `toQueryParameters`) against `lib/api/` conventions + C4 edge semantics

> Reviewed against: `docs/proposals/b6-1c-lib-screens-admin-audit-read-contract-design.md` (§1.1, §2 C1/C4/C5, §3 F1-F6, §4 steps 1-2, §5 AC-1/AC-2).
> Method: every convention claim re-verified against `lib/api/` source; every C4 edge **executed** on the repo's SDK (Dart 3.12.0-168.0.dev) — simulation of the pinned `fromJson`/`toQueryParameters` rules and of today's `'$value'` pass-through wire (see §2 for raw output). The class does not exist yet (zero `AuditQuery` hits in `lib/` `test/` — confirmed), so edge behavior was executed against a faithful transcription of the design's pinned rules, not the future implementation.

## 0. Verdict summary

| # | Claim being made | Verdict |
|---|---|---|
| V1 | `AuditQueryParseException` matches `lib/api/` exception naming | **Deviates.** Every `lib/api/` error type uses the `*Error` suffix (`PortalApiError`, `SnaplinkAdminApiError`, `SSOError`, `SetupNetworkError`, `DeveloperApiError`). The only non-`*Error` parse exception in the tree (`ConnectionConfigurationNotObject`) lives in `screens/`, not `lib/api/`. Rename to `AuditQueryParseError` (or co-locate the type and accept a documented deviation). |
| V2 | New-file placement + import in `governance_tab` matches transport-type conventions | **Partial deviation, low severity.** Public screen-facing contract types live in `snaplink_admin_types.dart` and are re-exported by `snaplink_admin_api.dart` (`export 'snaplink_admin_types.dart';` / `export 'snaplink_admin_error.dart';`). Separate files (`data_cache.dart`, `snaplink_admin_download_transport.dart`) exist but are internal helpers, not exported contract types. Co-locating in `snaplink_admin_types.dart` (already VM-pure: imports only `dart:typed_data`) would give `governance_tab` the type for free via the existing export and delete the design's new import (step 2). |
| V3 | Cache-bypass path citation (`:126`, `:133-134`, `:288`) | **Exact.** `get(String path, {Map<String, String>? query, bool forceRefresh = false})` at `:126`; `if (query != null) return _request('GET', path, query: query);` at `:133-134`; `Uri.parse('$baseUrl$path').replace(queryParameters: query)` at `:288`. "No transport change needed" is correct. Two edges need pinning: empty-map `query: {}` **also** bypasses cache (non-null check, not `isNotEmpty`), and `replace(queryParameters: {})` yields a trailing `?` while `null` yields none (empirically `http://x/e?` vs `http://x/e`) — 3 codebase sites normalize empty→null before `replace` (`sso_client.dart:525`, `admin_gate.dart:50`, `hosted_login_location.dart:23`). |
| V4 | `toQueryParameters()` returning `Map<String, String>` is the right wire type | **Mandatory, and the design gets it right.** `Uri.replace(queryParameters:)` **throws** on non-string values — empirically `type 'int' is not a subtype of Iterable` for `{'cursor': 0}`. Today's `'$value'` stringification is precisely what makes the current pass-through safe; the typed map preserves that. State this as rationale in the design. |
| V5 | C4 "every int/string scalar accepted" holds | **Overbroad as worded.** `limit: ''` is a string scalar today's pass-through sends (bare `?limit` on the wire) but is rejected post-change. The rejection is the blessed F4 direction, but C4's blanket sentence and C5's "all four" enumeration need correction — C5 misses two real behavior changes (see V6, V7). |
| V6 | C5 enumerates all tightening behavior changes | **Missing two entries:** (e) limit-as-non-integer-string (incl. `''`) rejected client-side where today the sink silently ignored `limit` on the events path (200, default page); (f) padded string filters are **trimmed before sending** (`'  acme  '` → `'acme'`), which changes the wire for a real input — and note the cited precedent `snaplink_admin_event_stream.dart:33-36` sends the *untrimmed* value after a trimmed presence-check, so the design's trim-to-value is *not* the precedent's behavior. |
| V7 | Edge semantics are pinned by AC-1 | **Gaps:** `limit: 0` (works, unpinned), `limit: ''` (rejected, unpinned), `limit: ' 100 '` (accepted — Dart 3.12 `int.tryParse` tolerates surrounding whitespace; relies on an SDK behavior, unpinned), `'  acme  '` → `'acme'` (trim-to-value, unpinned), `cursor: ''` omission (unpinned), `AuditQuery().toQueryParameters() == {}` (legal empty map, unpinned). |
| V8 | Typed errors fire before any request on every call path | **True for the tree today.** The sole query-construction path is `_queryAudit` (`governance_tab.dart:166-181`); `admin_live_events_tab.dart:167` is a path-parameter read with no query map. Post-migration, `fromJson` throws synchronously above the `setState(_loading = true)` block and the catch returns early — no `widget.api.get` is reachable. **Residual:** B6-1a's `audit_log_tab.dart` (absent today) will be a second construction site the guard cannot see; and no widget-level test pins "parse error ⇒ zero requests" (AC-2 exercises only valid inputs; the throw itself is pinned only in `audit_query_test.dart`). |
| V9 | Design-internal citations | **One self-drift:** §0 table says `connection_contract.dart:70`; §1.3 scan 4 says `:74`. Verified: the `MapEntry(key.toString(), value.toString())` site is **`:70`**. Also rule 1's "the factory still guards" is vacuous — `factory AuditQuery.fromJson(Map<String, dynamic> json)` makes non-map input a compile error; the runtime guard lives in `_json` + static typing. |

---

## 1. `lib/api/` conventions

### 1.1 Typed-get error handling — consistent, one naming deviation

The transport's contract: `get` throws `SnaplinkAdminApiError` (built by `snaplinkAdminError()` in `_request`); screens catch `on SnaplinkAdminApiError` (4 sites in `governance_tab.dart` alone). The design's parse exception is a *new, pre-request* error type caught in a narrow `on` clause inside `_queryAudit` — consistent with the codebase's narrow-catch pattern (`break_glass_tab.dart` catches `on SnaplinkAdminApiError` then a bare `catch`). The exception's shape (`final String message`, `toString() => message`) matches `PortalApiError` (`portal_api.dart:12-19`) — the only other message-carrying API exception.

**Findings:**
1. **Name.** `lib/api/` is 100% `*Error` suffix: `PortalApiError`, `SnaplinkAdminApiError`, `SSOError`, `SetupNetworkError`, `DeveloperApiError`. `AuditQueryParseException` breaks the file's own convention. The one in-tree `*Exception` parse error (`ConnectionConfigurationNotObject`, `connection_contract.dart:60`) is in `screens/` and carries no message. Recommendation: `AuditQueryParseError`. (If kept, it must be a *documented* deviation; the F-table and AC-1.5 all rename together.)
2. **Catch-site idiom.** Every existing catch in `governance_tab.dart` uses `error.toString()`; the design's migration snippet uses `error.message`. Equivalent here (`toString() => message`), but `.toString()` is the uniform idiom — prefer it so a future change to the exception's `toString` can't strand a `.message` site.
3. **Doc nit.** Rule 1 ("the factory still guards") overclaims — with a typed positional parameter there is no runtime non-map guard possible. The guard is `_json` (`:233-241`) plus the type system. Say that instead.

### 1.2 Cache-bypass path — exact, with two edges to pin

Verified against source: `:126` signature, `:133-134` `query != null` bypass, `:288` `Uri.replace(queryParameters:)`. The design's "no transport change needed" is correct — live audit reads must not serve from `DataCache`.

**Edges the design doesn't state:**
- `get(path, query: {})` — which is exactly what `AuditQuery().toQueryParameters() == {}` (all-null construction, declared legal) produces — **bypasses the cache** (`query != null`, not `query != null && query.isNotEmpty`) and renders a **trailing `?`** (`replace(queryParameters: {})` → `http://x/e?`, empirically; `null` → `http://x/e`). Three codebase sites normalize empty→null before `replace` (`sso_client.dart:525`, `admin_gate.dart:50`, `hosted_login_location.dart:23`). Server-equivalent and pre-existing behavior (today `'{}'` in the field produces the same map), so not a bug — but the design should (a) pin `AuditQuery().toQueryParameters() == {}` in AC-1.6, and (b) add one sentence noting the all-null map still bypasses cache and carries a bare `?` — it is the *semantic* "live read, no filters" case, which is the correct cache treatment.
- The tab never emits `{}` in practice (default field text is `{"limit": 100}`; only `{"limit": null}` or all-null keys reach `{}`), so this is documentation, not behavior.

### 1.3 `Uri.replace(queryParameters:)` usage — consistent, and the typed map is load-bearing

`:288` is the transport idiom; `getText` and `snaplink_admin_download_transport.dart:48` use the same pattern; `get`'s parameter type is `Map<String, String>?`. `toQueryParameters()` plugs straight in.

**Empirical hard requirement:** `Uri.replace(queryParameters: {'cursor': 0})` **throws** (`type 'int' is not a subtype of type 'Iterable<dynamic>'`, `dart:core/uri.dart:2768`). So a `Map<String, dynamic>` wire map — or any future relaxation of `toQueryParameters`' return type — crashes the transport. Today's `'$value'` stringification is the only thing keeping the current pass-through safe. The design's `Map<String, String>` return type is therefore mandatory, not stylistic; the design should say so (one sentence, rationale for rule 3's int-coercion and for the AC-2.1 "no param outside the six-key set" assertion).

### 1.4 Placement/export — low-severity deviation

Public contract types consumed by screens are exported through `snaplink_admin_api.dart` (`export 'snaplink_admin_error.dart'`; `export 'snaplink_admin_types.dart'`). `AuditQuery` is a public contract type consumed by `governance_tab` (which imports `snaplink_admin_api.dart` for `widget.api`). The design's separate `lib/api/audit_query.dart` + new import in the tab deviates from that pattern; the separate-file precedent (`data_cache.dart`, `snaplink_admin_download_transport.dart`, `snaplink_admin_event_stream.dart`) is internal-transport machinery, never screen-facing.

Options (both preserve VM-testability — `snaplink_admin_types.dart` imports only `dart:typed_data`):
- **Preferred:** put `AuditQuery` + `AuditQueryParseError` in `snaplink_admin_types.dart`, next to the trio doc it cites (`:310-312`). Zero new imports, zero export-surface change, migration step 2 shrinks to the `:167-169` block.
- Acceptable: keep `audit_query.dart` but re-export it from `snaplink_admin_api.dart` so consumers keep one import.

## 2. C4 edge semantics — adversarial, empirically executed

Executed on the repo SDK (Dart 3.12.0-168.0.dev) against a faithful transcription of the design's pinned rules and today's `'$value'` pass-through.

### 2.1 Empty-after-trim omission

| Input | Today's wire (`'$value'`) | Post-change | Verdict |
|---|---|---|---|
| `tenant_id: '  '` | `tenant_id=++` (encoded spaces) | **omitted** | ✅ AC-1.3 pinned; F5 documented |
| `tenant_id: '  acme  '` | `tenant_id=+acme+` | **`'acme'`** (trimmed value sent) | ⚠️ wire change for a real input, **not enumerated in C5** (C5(d) covers only whitespace-only strings), **not pinned by any AC**. Add AC-1.3 variant; add C5 entry. |
| `cursor: ''` | bare `?cursor` | omitted | ⚠️ tightening, unpinned (AC-1.6 pins only presence/absence/null) |

**Precedent mismatch worth recording:** the design cites `snaplink_admin_event_stream.dart:33-36` as the conditional-omit precedent, but that precedent checks `trim().isNotEmpty` and then sends the **untrimmed** value (`'event_types': eventTypes!`). The design's trim-to-value is a *different*, stricter choice — defensible (C4's "(String → trimmed)" documents it), but it should be stated as a deliberate divergence from the cited precedent, not presented as the precedent's behavior.

### 2.2 `limit` 0 / `''` / whitespace int-string coercion

| Input | Today's wire | Post-change | Verdict |
|---|---|---|---|
| `limit: 0` | `limit=0` | `'0'` (`'$limit'`) | ✅ identical; **unpinned** (AC-1.1 pins only 100) — add |
| `limit: '0'` | `limit=0` | `'0'` (`int.tryParse('0')` = 0) | ✅ identical; add |
| `limit: ''` | bare `?limit` | **`AuditQueryParseException`** (`int.tryParse('')` = null) | ✅ strict, F4 family — but today on the events path the sink **ignored** `limit` (parseQuery never reads it; `server.go:872-876` is `listAdminActions`-only) → a 200 with default page becomes a banner. C4's blanket "every … string scalar is still accepted" is **false for `''`**; C5 doesn't enumerate it. Add C5 entry + AC-1.5 variant. |
| `limit: ' 100 '` | `limit=+100+` | **accepted → `'100'`** | ✅ works, but **relies on SDK behavior**: Dart 3.12 `int.tryParse` tolerates surrounding whitespace (empirically `int.tryParse(' 100 ') == 100`, `int.tryParse(' 0 ') == 0`; `''` and whitespace-only → null). Design rule 3 ("String that parses via int.tryParse") is accurate as written on this SDK — no trim needed — but this is exactly the kind of edge a future SDK change could break; pin `limit: ' 100 '` → `{'limit': '100'}` in AC-1.5. |
| `limit: '  '` | `limit=++` | rejected (`int.tryParse` → null) | ⚠️ tightening, unpinned |
| `limit: 'abc'` | `limit=abc` (sink 400 on listAdminActions / ignored on events path) | rejected | ✅ F4 pinned (AC-1.5) |
| `limit: 1.5` / `true` | `limit=1.5` / `limit=true` | rejected | ✅ F3 pinned (AC-1.5) |
| `limit: null` | `limit=null` | **absent** | ✅ C5(c); today sink ignored it on the events path, so this is cosmetic there and a 400→200 fix on listAdminActions |

### 2.3 Unknown-key rejection

`{'tenat_id': 'x'}` → throws with the offending key quoted and the six-key enumeration (simulation output verified). ✅ AC-1.5 pinned. Post-`jsonDecode` keys are always `String`; the `Map<String, dynamic>` signature makes non-string keys a compile error, and casing variants (`'Tenant_id'`, `'event_type '`) are all rejected with the key echoed — correct. The only unreachable claim is rule 1's "factory still guards" (§1.1.3).

### 2.4 cursor / outcome

- `cursor: 0` (int) → `'0'` — coercion identical to today's `'$value'` ✅ (unpinned; add to AC-1.6).
- `cursor: ''` → omitted (today: bare `?cursor`) ⚠️ unpinned.
- `outcome: 'failure'` → `'failure'` ✅ (AC-1.4 exercises it via the `:404` helper-text example).
- `eventTypes` field → wire `event_type` (singular) ✅ matches sink `parseQuery` (`server.go:910` binds `event_type`). **Note for the doc:** the SSE stream uses plural `event_types` (`snaplink_admin_event_stream.dart:34`) — singular query key vs plural stream key coexist; one sentence in the class doc prevents a future "why don't these match" edit.
- `event_type: 123` → `'123'` ✅ same as today.
- `outcome: true` → rejected ✅ C5(b).

### 2.5 Typed errors fire before any request — every call path

**Inventory (exhaustive, verified):** the only query-construction path in `lib/` is `_queryAudit` (`governance_tab.dart:166-181`). `admin_live_events_tab.dart:167` is a `get` with a path parameter and **no** query map; `admin_operations_tab.dart:56` is a grouping prefix, not a call; the trio lines at `snaplink_admin_types.dart:310-312` are documentation.

**Code order (post-migration):** `_json` → `AuditQuery.fromJson` (throws synchronously) → catch sets `_error`, `return` → … → `setState(_loading = true)` → `widget.api.get`. The design's replacement block sits **above** the `:170` setState, so a parse error also never flips `_loading` — same lifecycle as today's F1 (`_json` failure returns before setState). No `AuditQueryParseException` can reach the transport: `toQueryParameters` is pure, and the only `get` calls receive the already-validated map. **Confirmed for the tree today.**

**Gaps to close:**
1. **No integration-level no-request pin.** AC-2.1–2.4 exercise only valid inputs; the "no request is issued" claims in F2-F6 are pinned only at the unit level (the throw) and by code inspection. Add one widget assertion to migration step 3's new group: enter `{"limit": "abc"}`, tap Query → assert the recording handler saw **zero** requests and the banner shows the parse message. This is the deliverable that actually "confirms typed errors fire before any request" on the real call path.
2. **Recording handlers are new work, not reuse.** `_api` (`test/admin_governance_security_test.dart:17-24`) only routes; it does not record. Step 3's "MockClient records `request.url.path` + `request.url.queryParameters`" must be implemented as new handlers in the new group (already flagged by the guard review — confirmed here).
3. **Second consumer (B6-1a land-check).** `audit_log_tab.dart` is absent (`audit_log_tab_test.dart` absent, `dashboard_screen.dart:566` still `const AuditLogTab()`). When it lands, its AC-1.5 `tenant_id`/`trace_id` branch becomes a second construction site the guard cannot see (scan 4 is governance_tab-only; scan 1 sees path literals, not query keys). The design's §1.1 "The only sanctioned way" claim is unenforceable for that consumer — the land-check must be "reuse `AuditQuery` or extend scan 4", recorded in migration step 5.

## 3. Recommendations (ordered)

1. **Rename `AuditQueryParseException` → `AuditQueryParseError`** (lib/api/ convention; §1.1.1); use `error.toString()` at the catch site (§1.1.2).
2. **Co-locate `AuditQuery` in `snaplink_admin_types.dart`** (or re-export from `snaplink_admin_api.dart`) — deletes the new import, matches the exported-contract-type pattern (§1.4).
3. **Correct C4/C5:** C4's blanket acceptance claim → "accepted, or rejected with a typed banner strictly earlier than today's server behavior"; C5 gains (e) limit-as-non-integer-string rejection and (f) trim-to-value for padded string filters, each with the today-wire → post-change mapping (§2.1, §2.2).
4. **Extend AC-1 pins:** `limit: 0` → `'0'`; `limit: ''` → throw; `limit: ' 100 '` → `{'limit': '100'}` (locks in `int.tryParse` whitespace tolerance); `'  acme  '` → `{'acme'}`; `cursor: ''` omitted; `AuditQuery().toQueryParameters() == {}`; `cursor: 0` → `'0'` (§2.2–2.4).
5. **Add the no-request widget assertion** (parse error ⇒ zero recorded requests + banner) with step 3's own recording handlers (§2.5.1–2).
6. **Doc fixes:** §0 `connection_contract.dart:70` (not `:74`); rule 1 "factory still guards" rewording; note the all-null `{}` map bypasses cache with a bare `?`; note singular `event_type` vs stream's plural `event_types`; state that `Map<String, String>` is load-bearing for `Uri.replace` (§1.2, §1.3, §2.4).
7. **Record the B6-1a land-check** ("reuse `AuditQuery` or extend scan 4") in migration step 5 (§2.5.3).

## 4. Bottom line

No blocking findings: the design's pinned semantics are coherent, wire-equivalent for the default (C1), and typed errors provably precede any request on the only call path that exists today. The fixes are convention alignment (exception name, placement/export), C4/C5 completeness (two unenumerated tightenings, three unpinned coercion edges), and one integration assertion (parse-error ⇒ zero requests) that the AC-2 harness currently lacks. All empirical claims above were executed on the repo's SDK; the `Uri.replace` non-string crash is a hard constraint the typed map satisfies.
