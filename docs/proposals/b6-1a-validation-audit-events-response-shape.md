# B6-1a — Validation: GET /api/v1/audit/events response shape vs. real server implementation

> Validated 2026-08-07 against the **server implementation** in the sibling repo
> `snaplink` (`platform/audit/handlers.go`, `platform/audit/auditspi/event.go`,
> `platform/audit/auditspi/query.go`, `platform/audit/memory_sink.go`,
> `platform/audit/sqlite/query.go`, `platform/audit/doc.go`, `docs/openapi.yaml`)
> and the **wire path** in this repo (`nginx.conf`, `lib/api/snaplink_admin_api.dart`,
> `lib/screens/admin/governance_tab.dart`, `lib/services/sensitive_data.dart`).
> Design under review: `docs/proposals/b6-1a-lib-api-auditlogtab-server-read-design.md`
> (spec: `b6-1a-lib-api-auditlogtab-server-read-spec.md`).

## 0. Verdict

| Claim | Verdict |
|---|---|
| `events` is the real list key; `items/results/data/entries` are harmless defensive aliases | ✅ `events` is the **only** real key (required `[events, count]`) and is checked first |
| Per-field aliases/fallbacks map the real payload | ❌ **The row model's field vocabulary is the local-ring vocabulary, not the server's.** Real events have NO `method`/`path`/`status`/`status_code`/`resource`/`endpoint`/`uri`/`verb`/`event_type`/`event`/`action` — 3 of the 5 table columns plus the METHOD filter, PATH search, status coloring, and the error-rate badge go dead against every real payload |
| `limit=100` semantics | ✅ `NormalizedLimit()`: 0/neg → default 100; >1000 → capped 1000. `limit=100` = exactly "up to 100 newest-first events", within bounds; `count` in the response = page length (== `_rows.length`) |
| `skipCache()` + query-param GET = fresh request (live timeline) | ✅ Confirmed, and the claim is **stronger** than stated: the `query != null` branch in `get()` never consults, populates, or dedups the cache (`snaplink_admin_api.dart:121-123`); `skipCache()` is redundant-but-harmless (flag still consumed) |
| F1–F11 cover real payload divergence | ❌ F4/F8 exercise invented (ring-shaped) fixtures only; the real payload shape (`{id, type, outcome, timestamp, ...}`) appears in **no** failure-mode fixture, and the real failure signal `outcome: failure` is dropped from the model |

**Bottom line:** the transport, capability, gating, limit, cache, and never-throw
claims all hold against the real implementation. The **response-to-rows mapping
and the acceptance fixtures do not**: they were derived from the localStorage
ring's `AuditEntry` shape (method/path/status), which the server never emits.
The design must be corrected before implementation, or AC-1/AC-5 will pass
against invented fixtures while the real integration renders `-`/`-`/`-` rows.

---

## 1. Real wire path (no payload-reshaping BFF)

- `nginx.conf:94-95`: `location ~ ^/(?:auth/|api/|...)` → `${SNAPLINK_UPSTREAM}`
  (sso-server). The only split upstream is `admin/commerce|commerce|metering`
  (`nginx.conf:56-57`) — **audit is not in it**. There is no BFF layer between
  the console and the server; the handler response IS the wire response.
- Server side (`snaplink`): `platform/audit/doc.go:30-33` mounts
  `GET /api/v1/audit/events` under `PathAPIPrefix` (`/api/v1`) **only when**
  `WithAuditAPI` is enabled AND an `Auditor` is wired; otherwise the route is
  **not mounted → 404**. `interfaces/sso/server_discovery.go:381` delegates to
  `audit.HandleEvents`. Admin-gated (`admin:read`); 401 for missing/invalid
  bearer (OpenAPI `401` documented).

## 2. Real response shape (validated)

`platform/audit/handlers.go:37-41`:

```go
ctx.JSON(http.StatusOK, map[string]any{
    KeyEvents: events,   // "events"
    KeyCount:  len(events), // "count" — page length, NOT total matching
})
```

OpenAPI `AuditEventList` (`docs/openapi.yaml:15433`): `required: [events, count]`.

- ✅ Design list-extraction order `['events', 'items', 'results', 'data', 'entries']`
  hits the real key first. `items/results/data/entries` are pure speculation but
  unreachable when `events` is present — acceptable defense.
- ⚠️ `count` = page size (≤ limit), never the total. The design's `{count} entries`
  ← `_rows.length` is equivalent. But the tab has **no pagination**: with >100
  matching events, only the newest 100 are visible and no F-mode documents this
  ceiling (the old ring displayed up to 1000).

### 2.1 Real event schema — the divergence

`platform/audit/auditspi/event.go` (JSON tags) + OpenAPI `AuditEvent` (`:15394`):

| Real field (all snake_case) | Required | Design mapper alias covers it? |
|---|---|---|
| `id` | yes | ❌ dropped by `AuditEventRow` |
| `type` (canonical: `login`, `admin_client_created`, ...) | yes | ✅ via label aliases (`type` is 6th alias) |
| `outcome` (`success`/`failure`) | yes | ❌ **not in any alias list** — the real failure signal |
| `timestamp` (RFC3339) | yes | ✅ (first alias) |
| `actor_id`, `actor_ip`, `user_agent`, `client_id`, `tenant_id`, `provider`, `request_id`, `trace_id`, `span_id`, `session_id`, `token_id`, `reason`, `metadata`, `prev_hash`, `hash`, `server_version` | no | ❌ all dropped |
| `method` / `verb` | — | ❌ **no such field anywhere** in the server schema |
| `path` / `resource` / `endpoint` / `uri` | — | ❌ **no such field** (metadata keys `resource`/`uri` exist only in test files) |
| `status` / `status_code` / `statusCode` | — | ❌ **no such field**; the analog is `outcome` |
| `event_type` / `eventType` / `event` / `action` | — | ❌ not emitted (only `type`) |
| `time` / `created_at` / `createdAt` / `occurred_at` | — | ❌ not emitted (`timestamp` is the only time field) |

Consequence for the design's `AuditEventRow {timestamp, method, path, statusCode, label}`:
**every real server row renders `-` in METHOD, `-` in STATUS, `-` in PATH** (F8 fallbacks
fire unconditionally, 3 of 5 columns). The METHOD dropdown filter (POST/PUT/DELETE/PATCH)
matches nothing → any non-ALL selection empties the list; PATH search matches nothing;
status color coding never applies; `_errorRate` (`statusCode >= 400 && statusCode > 0`)
is always 0 → the error-rate badge (an existing feature, `feat(audit): error-rate badge`)
is silently dead. The real failure signal `outcome == 'failure'` never reaches the UI.

In-repo corroboration: `governance_tab.dart:423-440` — the existing consumer of the
same endpoint reads `result['events']`, `result['count']`, and per-event
`type`/`timestamp`/`outcome`/`id` (with a `created_at` fallback). That is the field
vocabulary the real endpoint actually serves.

`SensitiveData.redact` safety check (design step 1): `token_id`, `token_strategy`
(allowlisted), `request_id`, `session_id`, `actor_*`, `client_id`, `tenant_id`,
`prev_hash`, `hash` all survive redaction (`lib/services/sensitive_data.dart:24-36`).
Redact-first does not mangle real rows. ✅

### 2.2 Real query semantics

`platform/audit/auditspi/query.go:5-9` + `query_test.go:119-135`:
`NormalizedLimit()` — zero/negative → `DefaultQueryLimit = 100`; > `MaxQueryLimit = 1000`
→ capped at 1000. Ordering newest-first (`memory_sink.go:79-85` sorts;
`sqlite/query.go:82` `ORDER BY ts_unix_ns DESC`). OpenAPI documents
`limit: {type: integer, default: 100}`, `offset: {default: 0}`.

- ✅ Design's `limit=100` is deterministic, in-bounds, and matches the server default.
- ✅ Server has **no required** query parameters — the design's limit-only query is a
  valid request (AC-1's exact-query assertion is satisfiable; governance precedent
  `governance_tab.dart:33` uses the same `{"limit": 100}`).
- ✅ Server-side filters exist (`type, actor_id, client_id, tenant_id, provider,
  outcome, request_id, trace_id, since, until, limit, offset`) but the design's
  client-side search/filter over fetched rows is a valid v1; no filter *must* be sent.
- ⚠️ `offset` exists server-side; the design has no pagination (see 2.1 ceiling note).

### 2.3 Error surface (validated status codes)

| Status | Real trigger | Design F-mode |
|---|---|---|
| 200 | `{events, count}` | — |
| 400 | malformed `limit`/`since`/`until` (`parseQuery`) | **not covered** — unreachable from this tab (always `limit=100`), non-issue |
| 401 | missing/invalid bearer (admin middleware) | F2 ✅ (`onUnauthorized` fires, `_request`) |
| 404 | route not mounted: `!WithAuditAPI` or no Auditor (`doc.go:30-33`) | F3 ✅ (fits "deployment lacks the route"; note this is the **default** when audit is disabled, not an exotic deny) |
| 500 | `audit_not_enabled` (recorder nil — defense-in-depth, nearly unreachable) or `server_error` (sink `Query` failure) | F1 ✅ (GET retried ≤3, backoff `2^attempt*500ms`, timeout retried; actual lines `snaplink_admin_api.dart:307-327`, design cited 205-215 — line drift only) |
| 501 | facets sink missing `FacetQuerier` | n/a — design never calls `/facets` ✅ |

## 3. skipCache() / query-param GET — live-timeline claim

`snaplink_admin_api.dart:117-124` (`get`):

```dart
final skipCache = _skipCacheNext || forceRefresh;
_skipCacheNext = false;
if (query != null) {
  return _request('GET', path, query: query);   // ← never touches _cache
}
```

- ✅ Query-param GETs never read `_cache.get`, never dedup via
  `_cache.registerOrGet`, never write `_cache.set` — the audit fetch is fresh on
  every call **even without** `skipCache()`.
- ✅ `skipCache()` before the fetch is redundant-but-harmless (flag consumed; the
  subsequent query GET is fresh regardless). Design F9's claim is consistent, and
  the design's literal statement ("query-param GET bypasses the cache entirely,
  favorable for a live timeline") is verified.
- ⚠️ **No dedup for query GETs + re-query on every search/filter change** = rapid
  refreshes can complete out of order. F10's `if (!mounted) return` guards disposal
  only, not response ordering; a stale in-flight response can overwrite newer rows.
  Needs a generation/sequence guard — small gap, not payload-related.
- Note: the design cites `skipCache()` precedent at `governance_tab.dart:166`; the
  actual `skipCache()` call is `governance_tab.dart:104` (in `_read`), while
  `_queryAudit` (`:167-186`) relies on the query-branch bypass. Line drift only.

## 4. F1–F11 vs. real payload divergence — assessment

| F | Covers real behavior? | Finding |
|---|---|---|
| F1 | ✅ | Retry ≤3 on 5xx/timeout verified (line drift 205-215 → 307-327). Real 5xx = `server_error`; `audit_not_enabled` 500 is nearly unreachable (route unmounted instead) |
| F2 | ✅ | 401 → `onUnauthorized` verified in `_request` |
| F3 | ✅ | 404-on-unmounted is the realistic "no audit API" case — exactly this F-mode's territory |
| F4 | ⚠️ | Never-throw mapper ✅, but the matrix's *event fixtures* are ring-shaped (method/path/status); the real shape `{id, type, outcome, timestamp}` is not exercised. A real-payload case must be added |
| F5 | ✅ | `{events: [], count: 0}` → 0 entries, server-truth empty state |
| F6 | ✅ | Gate + zero requests verified pattern |
| F7 | ✅ | Ring forgery never renders (server-only source) |
| F8 | ❌ | Fallbacks fire for *missing* fields; the real payload has *different fields*. Under F8's own rules, every real row renders `-`/`-`/`-` — F8 treats that as "row still rendered" and calls it done. The divergence is not in the matrix |
| F9 | ✅ | Verified (see §3); claim holds |
| F10 | ⚠️ | Covers `!mounted`; does NOT cover out-of-order response overwrite (no dedup on query GETs) |
| F11 | ✅ | Line-budget constraint unchanged |

**Missing F-modes (real divergence, unlisted):**
1. **Field-vocabulary divergence** — real rows have no method/path/status; METHOD/STATUS/PATH columns, METHOD filter, PATH search, status coloring are dead; error-rate badge always hidden. Needs a design decision (map `outcome` → STATUS/error-rate, `type` → EVENT, add actor/client/tenant columns, or defer column rework to B6-1b with explicit F-mode).
2. **`outcome: failure` is the error signal** — no F-mode maps it; `_errorRate` from `statusCode` is always 0 against real payloads.
3. **>100 events ceiling** — no pagination/offset; `{count} entries` shows page size, not total.
4. **Out-of-order refresh race** (F10 extension).

## 5. Acceptance-mapping consequences (must-fix before implementation)

- **AC-1** (`test/audit_log_tab_test.dart`): fixtures `POST /api/v1/admin/clients 200` /
  `DELETE /api/v1/admin/users 200` and assertions `find.textContaining('/api/v1/admin/clients')`
  are **unsatisfiable against the real server** — the server emits `type: admin_client_created`
  (etc.), `outcome`, `timestamp`, and **no path**. The query assertions
  (`limit == '100'`, no other params) are valid and stay.
- **AC-5** (CSV regression): `"POST","/api/v1/admin/clients"` CSV assertion is likewise
  ring-shaped; real CSV rows would be `timestamp,type,outcome,...` — the CSV format
  decision ("preserved verbatim") conflicts with the real payload.
- **AC-6** unaffected (transport untouched). ✅
- The **rework of `audit_log_tab.dart`** ("CSV/Clear/sort/filter preserved verbatim,
  retargeted at server rows") must change: the METHOD dropdown and PATH search operate
  on fields the server never sends; only TIME/EVENT columns + label search survive.

## 6. Recommended corrections (minimal, in-scope)

1. **Extend `AuditEventRow`** with `id`, `outcome` (→ STATUS column as success/failure
   chip or error-rate signal), and at least `actorId`/`clientId` (→ PATH column shows
   `client_id`/`actor_id` instead of a dead field). Keep `method/path/statusCode` only
   as fallback vocabulary for non-snaplink deployments (E13 defense) — but stop
   building the primary columns on them.
2. **Rewrite the mapper fixture matrix** in `test/audit_event_row_test.dart` to include
   the real shape as its primary case (`{'events': [{'id','type','outcome','timestamp',
   'actor_id','client_id'}]}`) — this is the F4 gap.
3. **Rewrite AC-1/AC-5 fixtures** to real events (`type: admin_client_created`,
   `outcome: success`, `timestamp`), asserting `find.textContaining('admin_client_created')`,
   and re-specify the CSV header/columns to match the mapped fields.
4. **Error-rate badge**: compute from `outcome == 'failure'` (server truth) or drop it
   to B6-1b with an explicit F-mode; never from a field that is always 0.
5. **Add F12 (field-vocabulary divergence)** + F10 extension (ordering guard), and
   document the 100-row ceiling (no pagination).
6. Everything else in the design (transport, gate, wiring, limit, skipCache, C1-C10,
   migration order, AC-2/3/4/6) is **confirmed** against the real implementation.

## 7. Evidence index

- `snaplink/platform/audit/handlers.go:37-41` — `{events, count}` envelope; `parseQuery` params; error codes
- `snaplink/platform/audit/auditspi/event.go` — Event JSON tags (no method/path/status)
- `snaplink/platform/audit/auditspi/query.go:5-9` — DefaultQueryLimit=100, MaxQueryLimit=1000
- `snaplink/platform/audit/query_test.go:119-135` — NormalizedLimit matrix
- `snaplink/platform/audit/memory_sink.go:67-88` / `sqlite/query.go:82` — newest-first, limit/offset
- `snaplink/platform/audit/doc.go:30-33` — mount gate → 404 when audit disabled
- `snaplink/docs/openapi.yaml:15394-15447, 4393-4490` — AuditEvent / AuditEventList / operation schema
- `snaplink/interfaces/sso/server_discovery.go:381` — route delegate
- `snaplink-console/nginx.conf:56-57,94-95` — audit path → snaplink upstream (no BFF reshaping)
- `snaplink-console/lib/api/snaplink_admin_api.dart:117-124` — query branch bypasses cache; `:307-327` retry/401
- `snaplink-console/lib/screens/admin/governance_tab.dart:104,423-440` — skipCache precedent; real field usage
- `snaplink-console/lib/services/sensitive_data.dart:24-36` — redact allowlist keeps real fields
