# B6-1a — F12 design: search-box debounce + (method, path, query)-aware in-flight dedup

> Applies to: `lib/screens/admin/audit_log_tab.dart`, `lib/api/snaplink_admin_api.dart`, `test/audit_log_tab_test.dart`, `test/snaplink_admin_api_test.dart`. Supersedes, in part: the FM-9/FM-12 rows of `docs/proposals/b6-1a-lib-screens-admin-auditlogtab-server-read-design.md` §3 and the AC-1/AC-2 re-query pin `:143-152` of `test/audit_log_tab_test.dart`.
> Origin: **F12 [HIGH]** of the api_contract_reviewer adversarial report — "the search box floods the wire": `onChanged: (_) => _refresh()` per keystroke, no debounce, no in-flight guard, no cancellation, `_request` retries up to `maxRetries=3` on 5xx/timeout/network error with exponential backoff. Typing a 5-char term against a struggling sink = 5+ concurrent round-trips, up to 20 wire hits (5 × (1+3)).
> Root cause chain (reproduced against the tree): `DataCache._key(method, path)` is path-only (`data_cache.dart:166`), so query-bearing GETs were excluded from cache *and* dedup; `get()`'s `query != null` branch (`snaplink_admin_api.dart:134-135`) calls `_request` directly with no collapse. The tab's refresh button is disabled while loading, but `onChanged` fires `_refresh()` regardless — the only flood source, and the FM-9 race's own trigger.
> Status: **design + validation complete (applied, ran, restored byte-identical; tree left at the pre-F12 certified change set)**. Landing is a follow-up commit per §7.

## 1. Design

Two minimal production changes, each preserving a certified contract:

### 1.1 Debounce (tab layer — kills the per-keystroke rate)

`lib/screens/admin/audit_log_tab.dart`:

- `static const _debounceWindow = Duration(milliseconds: 300);` + `Timer? _searchDebounce;` on `_AuditLogTabState`; cancelled in `dispose()`.
- `onChanged: (_) => _refresh()` → `onChanged: _onSearchChanged`:

```dart
void _onSearchChanged(String _) {
  _searchDebounce?.cancel();
  setState(_applyFilter);          // narrow the fetched page instantly, client-side
  _searchDebounce = Timer(_debounceWindow, () {
    if (mounted) _refresh();       // one freshness re-query per settled burst
  });
}
```

Design decisions, each load-bearing:

- **Immediate client-side filter on every keystroke.** `_applyFilter` reads `_searchCtrl.text` at commit time anyway, so the displayed page narrows the moment typing starts; the debounced re-query only adds freshness. Keystroke UX is unchanged — only wire traffic is deferred.
- **300ms window.** Above the inter-keystroke gap of fast typing (~120-200ms), below the perceived-lag threshold (~400-500ms). One settled burst → exactly one re-query.
- **`dispose()` cancels the timer.** No pending-timer leak; widget teardown mid-burst never fires `_refresh` on an unmounted state (the `mounted` check is belt-and-suspenders).
- **Non-search triggers stay immediate.** The header refresh button (disabled while loading), the Retry button, the filter dropdown, and the debug Clear action all keep calling `_refresh()` directly — discrete user actions, no flood class.

### 1.2 (method, path, query)-aware in-flight dedup (transport layer — bounds concurrency)

`lib/api/snaplink_admin_api.dart`:

- New field `final Map<String, Completer<Map<String, dynamic>>> _inFlightQuery = {};` — a pending-only registry for query-bearing GETs. It never caches: the certified cache-bypass semantics of `get()` (every query-bearing read is a fresh server read, FM-12) are untouched.
- `get()`'s `query != null` branch becomes register-or-join (mirroring `DataCache.registerOrGet/resolve/reject`, including the unhandled-error observer):

```dart
if (query != null) {
  final key = _inFlightKey('GET', path, query);
  final pending = _inFlightQuery[key];
  if (pending != null) return pending.future; // join the leader
  final completer = Completer<Map<String, dynamic>>();
  unawaited(completer.future.then<void>((_) {}, onError: (_, _) {}));
  _inFlightQuery[key] = completer;
  try {
    final data = await _request('GET', path, query: query);
    if (!completer.isCompleted) completer.complete(data);
    return data;
  } catch (error, stackTrace) {
    if (!completer.isCompleted) completer.completeError(error, stackTrace);
    rethrow;
  } finally {
    _inFlightQuery.remove(key);
  }
}
```

- Canonical key — sorted `key=value` pairs:

```dart
static String _inFlightKey(String method, String path, Map<String, String> query) {
  final pairs = query.entries.map((e) => '${e.key}=${e.value}').toList()..sort();
  return '$method:$path?${pairs.join('&')}';
}
```

Design decisions:

- **Key is (method, path, query) — never path alone.** Different filters never share a wire call (a future server-side filter UI gets correct isolation today); identical concurrent re-queries do. Sorted pairs make `{'limit':'100','outcome':'failure'}` and the reversed map one identity — insertion order can never defeat collapse.
- **The collapse is unconditional: `skipCache()`/`forceRefresh` do NOT bypass it.** This is the F12-closing property. The tab calls `skipCache()` on every refresh; if the flag bypassed the collapse, each settled burst while a previous request hangs against a struggling sink would stack a fresh request — unbounded concurrency again (30s of slow typing ≈ 30+ concurrent round-trips), i.e. the exact defect being closed. `skipCache` remains cache-only semantics (still inert for the query branch, as certified F11/F13); an in-flight request is by definition not cache-served, so joining it honors the freshness intent.
- **Retries are shared, not multiplied.** `_request`'s internal retry budget (≤3, exponential backoff) belongs to the leader; joiners await the leader's completer across the whole retry cycle. A collapsed group costs ≤ (1+3) wire hits, never N×(1+3).
- **Failure is shared.** Leader failure → `completeError` → every joiner receives the same error; registry released in `finally`, so the next trigger is a fresh leader.
- **`DataCache` and `clearCache()` untouched.** The path-only cache/dedup for query-less GETs is byte-identical; query registry entries are always resolved by their leader, so `clearCache()` needs no coupling (documented boundary).
- **Cancellation.** Effect-cancellation is the generation guard (already certified); flood-cancellation is the debounce; concurrency-cancellation is the dedup. Aborting the wire request itself is out of scope — `http.Client` has no supported abort path here, and no longer necessary.

## 2. Certified semantics preservation

| Certified contract | Status under this design | Evidence |
|---|---|---|
| AC-1/AC-2 "2 requests" (initial + exactly one re-query, each wire `{'limit':'100'}`, search terms never ride the wire) | **Preserved.** Debounce collapses a burst to exactly one re-query; the wire is unchanged (`AuditReadClient.list` untouched). Test updated only to advance the fake clock past the debounce window (below). | `audit_log_tab_test.dart` AC-1, ran 16/16 |
| FM-9 generation guard (`_generation`, only the newest fetch commits) | **Mechanism preserved verbatim.** Its classic out-of-order race is now structurally impossible for identical requests — the dedup collapses them — so the race test's premise is superseded (see §3). The guard remains load-bearing for the gate path (`_generation++` on capability-absent) and for any future *different-query* consumer (the documented facets/filter-UI direction), where out-of-order commits become possible again. | §3 test rewrite; guard code diff = zero |
| FM-12 fresh-read semantics (query-bearing GET never cache-served) | **Preserved.** The registry never stores; only in-flight identity. | `_inFlightQuery` has no read path |
| Wire contract + guard scans (AC-3.1-3.4, scan 5) | **Preserved.** No audit literals, no `bff` tokens, no raw `MapEntry(key, '$value')`, no `query:` map literals added anywhere; `AuditQuery`/`AuditReadClient` untouched. | 51/51 guard/query/read-client/row |
| `skipCache()` semantics | **Unchanged** (cache-only flag; still consumed-cleared before the query branch). | — |
| 33-suite (`admin_support_tabs_test` search-touching tests) | **Green unchanged.** Both search tests pass without edits: the immediate client-side filter narrows `_displayed` on the same frame, and the debounce timer is cancelled by `dispose()` at teardown, so no request-count pin, no pending-timer failure. | 18/18 support+navigation |

## 3. Test changes (the minimum that preserves the certified semantics)

### 3.1 `test/audit_log_tab_test.dart` — two edits, one rewrite

**AC-1 re-query phase** — the certified "2 requests" assertion needs the fake clock advanced past the 300ms window. `pumpAndSettle` alone advances only ~100ms (one frame — the immediate filter render — then no scheduled frames), which would strand the timer and fail `hasLength(2)`:

```dart
await tester.enterText(find.byType(TextField), 'admin_client');
await tester.pump(const Duration(milliseconds: 350));  // debounce window
await tester.pumpAndSettle();
expect(requests, hasLength(2));
```

**FM-9 test — rewritten as the dedup-join test.** Under the collapse, the old scenario ("second wire request via search while loading") cannot exist — the second refresh joins the in-flight one. The rewrite pins the three behaviors that now define the contract:

1. **F12 in-flight guard:** typing during an in-flight load fires the debounced re-query, which joins — the MockClient handler is called exactly once (`calls == 1` after `pump(350ms)`).
2. **Single commit:** the shared response renders exactly once; the generation guard discards the superseded leader commit (no double commit, no crash).
3. **Post-join freshness:** after the join resolves, the next explicit trigger (refresh button) is a fresh wire call (`calls == 2`).

```dart
testWidgets('a search re-query during an in-flight load joins the single wire '
    'request; the next trigger after it resolves fetches fresh', (tester) async {
  final first = Completer<http.Response>();
  var calls = 0;
  final api = SnaplinkAdminApi(/* MockClient: calls++; return first.future; */);
  // ... pump AuditLogTab; explicit pumps only while held ...
  await tester.pump();
  expect(calls, 1);
  await tester.enterText(find.byType(TextField), 'event');
  await tester.pump(const Duration(milliseconds: 350)); // debounce fires
  await tester.pump();
  expect(calls, 1);                      // join, not a second wire call
  first.complete(http.Response(jsonEncode({'events': [{...newer-event...}]}), 200));
  await tester.pumpAndSettle();
  expect(find.text('1 entries'), findsOneWidget);
  expect(find.textContaining('newer-event'), findsOneWidget);
  await tester.tap(find.byIcon(Icons.refresh));  // fresh request after release
  await tester.pumpAndSettle();
  expect(calls, 2);
});
```

The old test's `second` completer and its "complete NEWER first, then OLDER" choreography are gone — that race is unreachable by construction and its certification duty moves to the transport pins below.

### 3.2 `test/snaplink_admin_api_test.dart` — four new transport pins (group `query-bearing GET in-flight dedup (F12)`)

- **identical concurrent (method, path, query) GETs collapse into one wire request** — two concurrent `get('/api/v1/audit/events', {'limit':'100'})` → 1 handler call, both resolve with the same map, and a third call after release is a fresh wire call;
- **query-map insertion order does not defeat collapse** — reversed literal order still collapses;
- **different queries never collapse** — `{'limit':'100'}` vs `{'limit':'50'}` → 2 wire calls, each resolves its own body;
- **a failed leader rejects joiners with the same error** — 500 (with `maxRetries = 0`) → both futures throw `SnaplinkAdminApiError`, 1 wire call, retry after release is fresh.

Harness note (the one real trap): `MockClient.send` consumes the request body stream (`await bodyStream.toBytes()`) *before* invoking the handler, so the handler runs on a microtask — plain `test()` bodies must `await Future<void>.delayed(Duration.zero)` before counting calls, and error expectations must be attached before the flush so a failed leader never surfaces as an unhandled async error.

## 4. Failure-mode table (F12 closure ledger)

| Scenario | Before (F12) | After |
|---|---|---|
| 5-char term, healthy sink | 5 round-trips (1 per keystroke) | 1 (initial) + 1 (settled burst) = 2 |
| 5-char term, struggling sink (5xx) | 5 concurrent × ≤4 hits = up to 20 wire hits | ≤2 requests; if the re-query joins the initial, exactly 1 request × ≤4 hits |
| 30s of slow typing, hung sink | unbounded stacking (per keystroke) | 1 active events request, ever (dedup) |
| Burst ends mid-in-flight | N+1 concurrent, stale commits discarded by guard | re-query joins; 1 commit; guard discards superseded leader commit |
| Leader fails mid-group | — | all joiners get the same error; next trigger is a fresh leader |
| Filter dropdown during in-flight | second request, guard arbitrates | joins (same key), filter applies at commit |

## 5. Validation (all runs with the design applied; tree then restored)

| Command | Result |
|---|---|
| `flutter test test/audit_log_tab_test.dart` | **16/16** (AC-1 debounce pump, FM-9 join rewrite, all other pins untouched) |
| `flutter test test/audit_contract_guard_test.dart test/audit_query_test.dart test/audit_read_client_test.dart test/audit_event_row_test.dart` | **51/51** (guard/query/read-client/row; none of the four files touched — md5s unchanged from the pre-existing uncommitted set; census note: the campaign's earlier "47" baseline predates 4 tests added to this set by the uncommitted change set, not by this design) |
| `flutter test test/admin_support_tabs_test.dart test/admin_navigation_test.dart` | **18/18** (both search-touching support-tab tests pass byte-unchanged) |
| `flutter test test/snaplink_admin_api_test.dart` | **19/19** (15 pre-existing + 4 new dedup pins) |
| `flutter test` (bare; the `make test` flutter leg) | **797/797, exit 0** (twice consecutively + once with `-r expanded`) |
| `python3 -m unittest discover -s tests/unit -p 'test_*.py'` | **18/18 OK** (pre-existing coverage-relative-path warnings, unchanged) |
| `flutter analyze` | **No issues found** |
| `flutter test test/audit_contract_guard_mutation_test.dart` | 15 tests, 3 pre-existing failures — **A/B-proven identical on the pristine tree** (same 3 red: two `{id}` mutation probes, one accepted-escape-route probe); not caused by, and not exercised by, this design |
| Tree restore | All four files restored byte-identical (md5 match with the pre-F12 snapshot `d7071ab3`/`cb5c151a`/`edade35b`/`91012c77`) |

Environment note: bare `flutter test` in this checkout executes a pre-existing subset of the 124 test files (the runner starts all 124; ~44-46 report tests — the campaign's reviewers always ran the audit suites explicitly for exactly this reason). The F12 validation therefore uses explicit multi-file invocations, matching the certified-command pattern of §5 in the parent design doc.

## 6. Guard-scan compatibility (AC-3)

No scan input changes: the debounce adds `dart:async` usage and no literals; the transport adds a `Completer` registry and a static key builder with no audit-path literals. `scanSecondConsumer`'s trigger (queryable audit literal + `query:` argument without `AuditQuery`) is not touched — the audit path still builds wire through `AuditReadClient`/`AuditQuery` only. Verified green in the 51/51 run.

## 7. Landing steps (follow-up commit, after the certified B6-1a/b/c set)

1. Apply §1.1 + §1.2 to the two production files; apply §3.1 + §3.2 to the two test files (diffs in this doc are the authoritative landing text).
2. Re-run the §5 command block — all four explicit suites must stay green, plus `flutter analyze`.
3. Commit atomically with the parent change set or as a tagged follow-up (test lock-step with production, per the parent doc's §4 convention).
4. Scope guard — do not expand: no wire-request cancellation machinery, no `skipCache`-bypass of the collapse, no debounce on the filter dropdown / refresh / Retry (discrete actions), no changes to `DataCache` or `AuditQuery`.
