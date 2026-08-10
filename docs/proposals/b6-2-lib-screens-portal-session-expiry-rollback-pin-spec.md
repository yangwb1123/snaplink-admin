# B6-2 Requirements Specification — Pin PortalApi session-expiry hook firing and token-state rollback semantics (module `lib/screens/portal`, test-only)

> Source direction: **"Pin PortalApi session-expiry hook firing and token-state rollback semantics (test-only; the state machine around the already-pinned login leg)"** (value 7 / risk-reduction 7 / effort 2 / confidence 9), from `docs/auto/analyses/lib-screens-portal-44bdd36d.json`.
>
> Verification basis: **HEAD `de9b446`** (working tree checked 2026-08-08; every cited span re-checked via the live tree; no `lib/` working-tree diff). The direction's premise — that `test/portal_api_test.dart`'s five tests never assert the hook fires, that `login()` rollback / `fetchMe` / `fetchListOrEmpty` / JWT claim decode are untested — **holds at HEAD** (verified below). Nothing has landed for this direction; this spec is a build request for the test-only change set. Line positions in the direction's evidence list are from an earlier snapshot and are refreshed here with `[CORRECTION]` markers where they drifted.

## 0. Direction premise vs HEAD (verified, no delta)

| Direction claim | Reality at HEAD `de9b446` | Where |
|---|---|---|
| `test/portal_api_test.dart`'s five tests never assert `onSessionExpired` fires | **Confirmed.** 5 tests, 109 lines; the only `currentSessionId`/`currentClientId` asserts are the explicit-value leg (`:70-71`, opaque-token login with `sessionId:`/`clientId:`) — zero `onSessionExpired`, zero rollback, zero `fetchMe`, zero `fetchListOrEmpty`, zero JWT-decode coverage | `test/portal_api_test.dart` (full-file grep) |
| `_notifyIfSessionExpired` fires only on 401, deliberately preserving 403 | **Confirmed.** `lib/api/portal_api.dart:103-110` `[CORRECTION: direction cites :64-77]`; 403-preservation comment (trusted-device enrollment until MFA) at `:104-107` `[CORRECTION: direction cites :66-68]`; guard `if (r.statusCode == 401) onSessionExpired?.call();` at `:108` | `lib/api/portal_api.dart` |
| Hook exercised by get/post/patch/put/delete/deleteWithQuery and the SSE path | **Confirmed.** `_notifyIfSessionExpired(r)` invoked at `:114` (`get`), `:167` (`post`), `:179` (`patch`), `:187` (`put`), `:212` (`_delete`, shared by `delete`/`deleteWithQuery`); the SSE path fires the hook **inline** (not via `_notifyIfSessionExpired`) at `:132-133` `[CORRECTION: direction cites :130-136]` inside `notificationEvents` (`:121-147`), which also has a no-token guard `throw PortalApiError(401, ...)` at `:124` that does **not** fire the hook | `lib/api/portal_api.dart` |
| `login()` rollback of `_token`/`_sessionId`/`_clientId` on non-200 and transport error is untested | **Confirmed.** `login(` `:233`; previous-state capture `:238-240`, tentative install `:241-243`, `get('/me')` probe `:245`, non-200 throw `:246-248`, rollback `:251-253`, `PortalApiError(0, ...)` on transport error `:255` (rethrow of `PortalApiError` at `:254`). Spans `:233-257` — matches the direction citation exactly | `lib/api/portal_api.dart:233-257` |
| `fetchMe` non-200 throw and `fetchListOrEmpty` swallow-any-error semantics are untested | **Confirmed.** `fetchMe` `:270-276` (non-200 → `PortalApiError(status, 'Could not load your profile.')` at `:272-274`); `fetchListOrEmpty` `:282-290` `[CORRECTION: direction cites :282-292; the file ends at :292]` — non-200 → `const []` at `:285`, catch-all → `const []` at `:288-289` | `lib/api/portal_api.dart` |
| `currentSessionId`/`currentClientId` JWT claim decode (`_sidFromToken`/`_claimFromToken`) is untested | **Confirmed.** Getters at `:65`/`:70`; `_sidFromToken` `:72-74`, `_claimFromToken` `:76-99` `[CORRECTION: direction cites :82-99]`; list-claim first-element `return value.first.toString();` at `:89-91`; null for non-3-part tokens at `:80-81`; catch-all null at `:93-96`. Helpers are private — the tests exercise them through the public getters | `lib/api/portal_api.dart:65-99` |
| B6-2 request-bound login pins exist (the "already-pinned login leg") | **Confirmed.** `test/portal_entry_test.dart:301-338` (paste login) + `:340-363` (stored-session resume): zero POSTs / exactly one `GET /me` validation, 6 testWidgets total — the login *emission* leg is pinned; the client's *state machine* around it is what this spec pins | `test/portal_entry_test.dart:301-363` |
| A misroute of 401 or a stale `clientId` leaks into TrustedDeviceToken scoping | **Confirmed risk sites.** `lib/screens/portal/sessions_tab.dart:69-70` (`currentClientId` → `TrustedDeviceToken.clear(clientId)` after bulk revocation); `lib/screens/portal/security_account_credentials.dart:64-65` (same after password change); `lib/screens/portal/trusted_devices_card.dart:70-71` (`currentClientId` scopes `_trustCurrentDevice`; null/empty → gate). All three read the getters this spec pins | `sessions_tab.dart:69-70`, `security_account_credentials.dart:64-65`, `trusted_devices_card.dart:70-71` |
| 401 mid-session routes through hosted login | **Confirmed wiring.** `portal_screen.dart` arms `_api.onSessionExpired = _handleSessionExpired` at `:125` (paste login) and `:213` (resume); `_handleSessionExpired` (`:294-310`) disarms the hook (`:296`), clears `Session` (`:298`), stops notifications, and — when `_usesHostedLogin` — `_startHostedLogin()` (`:302`). `[CORRECTION: the direction cites :241-258 for the session-clearing block; that span lands inside the sibling `_signOut()` (`:230-255`), whose cleanup block performs the same `_api.signOut()` (`:242`)/`Session.clear()` (`:245`)/hosted-login sequence (`:246-249`, redirect call `:247`) — substance identical, positions refreshed]` | `lib/screens/portal/portal_screen.dart` |
| Test-only, zero `lib/` changes | **Confirmed.** `git diff HEAD --stat -- lib/` is empty at the working tree (verified); `lib/screens/portal/portal_api.dart` is a re-export shim of `lib/api/portal_api.dart` (verified, 196 bytes) — no change to either | `git diff HEAD --stat -- lib/` |

Pin-safety note: `test/portal_api_test.dart` is **not** part of any count-gated suite (guard-count-pin gates the four `audit_contract_guard*`/developer/oidc guard files; entry_ux/liveness/API pins name their own files — grep over `test/`, `Makefile`, `ci.yml` shows zero references to `portal_api_test.dart`), so appending tests to it does not disturb the G7 count pins. `test/portal_entry_test.dart` is executed but **not modified** by this direction.

## 1. Problem statement (verified)

The B6-2 request-bound pins (`test/portal_entry_test.dart:301-363`) cover **what** `PortalApi.login` issues — exactly one `GET /me` validation, zero POSTs — but the client's session-expiry and state-recovery semantics are unpinned:

- **S1 — Hook firing matrix unpinned.** `_notifyIfSessionExpired` (`lib/api/portal_api.dart:103-110`) decides whether a stale bearer silently continues (no redirect) or the session is declared expired and routed back through hosted login (`portal_screen.dart:125/:213` wiring; `_handleSessionExpired` redirect at `:302`). The 401-only / 403-preserving rule (`:104-108`) is deliberate (403 = feature-gated state, e.g. trusted-device enrollment until MFA), but `test/portal_api_test.dart` never arms `onSessionExpired`, so a regression that fires the hook on 403 (spurious hosted-login redirect mid-enrollment) or on 500 (spurious redirect on transient server error), or that stops firing on 401 (silent stale bearer), is undetected. The SSE path's inline 401 check (`:132-133`) is likewise unpinned — and its 401 additionally throws `PortalApiError(401)`, so the redirect behavior of `portal_screen_notifications.dart:18-20`'s `onError: (_) {}` consumer depends on the hook having fired **before** the throw.
- **S2 — `login()` rollback unpinned.** `login()` installs the candidate token *tentatively* (`:241-243`) and rolls back on non-200 /me (`:246-248`) and on transport error (`:251-255`). If rollback regressed (e.g. a refactor that only restores `_token`), a rejected token would leave `_token`/`_sessionId`/`_clientId` in the *candidate's* state — and because `currentClientId` falls back to JWT decode (`:70`), a stale `clientId` would silently leak into TrustedDeviceToken scoping at `sessions_tab.dart:69-70`, `security_account_credentials.dart:64-65`, `trusted_devices_card.dart:70-71`, clearing/creating grants scoped to a client the session never authenticated as.
- **S3 — `fetchMe`/`fetchListOrEmpty` error semantics unpinned.** `fetchMe` (`:270-276`) is the only convenience method that throws on non-200; `fetchListOrEmpty` (`:282-290`) deliberately swallows **any** error (404 "not wired", 500, transport) as `const []`. Both are documented contracts with no test.
- **S4 — JWT claim decode unpinned.** `currentSessionId`/`currentClientId` (`:65`/`:70`) decode `sid`/`aud` straight out of the bearer JWT payload (`:76-99`), including list-valued claims (first element, `:89-91`) and null for non-JWT/malformed tokens (`:80-81`, `:93-96`). The portal uses these to decide "was the session I just revoked the one I'm riding" and to scope trusted-device grants — untested.

All four gaps are closed by tests alone; no `lib/` behavior changes.

## 2. Requirements (test-only; zero `lib/` changes)

### REQ-1 — Session-expiry hook fires on 401 exactly once per response; never on 403 or 500, across every authenticated request path
For each of `get`, `post`, `patch`, `put`, `delete`, `deleteWithQuery` (all via `_notifyIfSessionExpired`, `lib/api/portal_api.dart:103-110`) and `notificationEvents` (SSE inline 401 check, `:132-133`): with `onSessionExpired` armed, a **401** response invokes the hook exactly once; a **403** response never invokes it (403-preservation for feature-gated states such as trusted-device enrollment, documented at `:104-107`); a **500** response never invokes it. A non-401 response must not leak a hook invocation from the login/SSE no-token guard (`:124` is out of scope — it throws without a response).

### REQ-2 — `login()` restores the previous token state on rejected and failed attempts; a later 200 installs the new state
`login()` (`:233-257`) may only persist `_token`/`_sessionId`/`_clientId` when `GET /me` returns 200. On any non-200 response (probe rejection, `:246-248`) and on any transport error (throwing client → `PortalApiError(0, 'That token was not accepted.')`, `:255`), the previous `_token`/`_sessionId`/`_clientId` are restored (`:251-253`), so `hasToken` and `currentSessionId`/`currentClientId` revert to their pre-attempt values. A subsequent attempt with a 200 response installs the new token/session/client state.

### REQ-3 — `fetchMe` throws on non-200; `fetchListOrEmpty` swallows every error as `const []`
`fetchMe` (`:270-276`) throws `PortalApiError(status)` on any non-200 and decodes the body on 200. `fetchListOrEmpty` (`:282-290`) returns `const []` for non-200 (404 "not wired", 500) and for transport errors, without throwing; returns the keyed list on 200 (positive control).

### REQ-4 — `currentSessionId`/`currentClientId` decode `sid`/`aud` from the bearer JWT payload, including list-valued claims
The public getters (`:65`/`:70`) decode `sid`/`aud` from the payload of a 3-part JWT (`_claimFromToken`, `:76-99`); a list-valued claim yields its **first** element (`:89-91`); non-JWT tokens (≠ 3 dot-separated parts) and malformed payloads (invalid base64, non-JSON, JSON that is not a map) yield `null` (`:80-81`, `:93-96`).

## 3. Testable acceptance checks (direction acceptance preserved in substance, pinned to exact assertions)

All new tests go in **`test/portal_api_test.dart`** (append; the file's existing 5 tests stay untouched). The existing import (`package:http/testing.dart` `MockClient`) is sufficient; no new dependencies.

### AC-1 (REQ-1) — Hook firing matrix: 7 paths × 3 statuses, data-driven
One data-driven group: for each path in `{get, post, patch, put, delete, deleteWithQuery, notificationEvents}` and each status in `{401, 403, 500}`:
- Seed: `api = PortalApi(httpClient: mock)`, `api.onSessionExpired = () => fired++;` then `await api.login('t')` where the mock returns `200 {}` for the **first** request (the login probe) and `http.Response('', status)` for the **second** (the path under test) — gate on a request counter, not on `url.path`, so the matrix is path-agnostic (and the SSE stream path `/me/notifications/stream` is never confused with the `/me` probe).
- Issue exactly **one** request through the path under test (the mock returns `http.Response('', status)`); for `notificationEvents`, drain via `await expectLater(api.notificationEvents(), throwsA(isA<PortalApiError>().having((e) => e.status, 'status', equals(status))))` — the hook must fire before the throw.
- Assert `fired == 1` for `401` and `fired == 0` for `403` and `500`, with a per-scenario reason string citing the 403-preservation comment (`portal_api.dart:104-107`).

### AC-2 (REQ-2) — `login()` rollback and re-install, one stateful MockClient sequence
With a stateful `MockClient` answering `/me` as `200 → 500 → throw http.ClientException('down') → 200` in request order:
1. `await api.login('first-token', sessionId: 's-1', clientId: 'c-1')` → succeeds; `hasToken` true; `currentSessionId == 's-1'`; `currentClientId == 'c-1'`.
2. `await expectLater(api.login('second-token'), throwsA(isA<PortalApiError>().having((e) => e.status, 'status', equals(500))))` (non-200 leg; 500 chosen so the hook matrix's 401 semantics cannot couple into this test) → state **reverted**: `hasToken` true, `currentSessionId == 's-1'`, `currentClientId == 'c-1'`.
3. `await expectLater(api.login('third-token'), throwsA(isA<PortalApiError>().having((e) => e.status, 'status', equals(0))))` (transport-error leg → `PortalApiError(0, ...)` at `:255`) → state **reverted again**: `hasToken` true, `'s-1'`/`'c-1'`.
4. `await api.login('good-token')` (200) → installed: `hasToken` true, `currentSessionId`/`currentClientId` now reflect the new token (`null` for opaque non-JWT, via the decode fallback at `:65`/`:70`).
5. Testability pins: all tokens are **opaque** (no `.`), so the JWT-decode fallback getters cannot mask a failed revert; the previous state is non-null (step 1), so "revert" is observable on `hasToken` + both getters.

### AC-3 (REQ-3) — `fetchMe`/`fetchListOrEmpty` error semantics
- `fetchMe`: after login, a mock returning 404 and a mock returning 500 each make `expectLater(api.fetchMe(), throwsA(isA<PortalApiError>().having((e) => e.status, 'status', equals(404/500))))` pass; a 200 `{'name': 'x'}` decodes to the body map.
- `fetchListOrEmpty('/me/roles', 'roles')`: returns `const []` **without throwing** for 404, for 500, and for a throwing `MockClient` handler (transport error); positive control: 200 `{'roles': ['a']}` returns `['a']`.

### AC-4 (REQ-4) — JWT claim decode through the public getters
Helpers are private, so each case goes through `login(token)` with a mock that 200s `/me` (token shape is irrelevant to the probe), then reads `currentSessionId`/`currentClientId`:
- String claims: `h.<b64url('{"sid":"s-9","aud":"console-client"}')>.s` → `'s-9'` / `'console-client'`.
- List-valued claims (first element): payload `{"sid":["s-list","s-2"],"aud":["c-1","c-2"]}` → `'s-list'` / `'c-1'`.
- Non-JWT: `'no-dots'`, `'two.parts'`, `'a.b.c.d'` (4 parts) → both getters `null`.
- Malformed payloads: 3-part tokens whose middle segment is invalid base64 (`'a.!!!.c'`), base64 of non-JSON (`'a.<b64url("not json")>.c'`), and base64 of a JSON non-map (`'a.<b64url("[1,2]")>.c'`) → both getters `null` (catch at `:93-96`).
- Each case asserts `hasToken` is true (the decode path is only reachable with an installed token).

### AC-5 (suite + zero-lib gate)
- `flutter test test/portal_api_test.dart test/portal_entry_test.dart` → all green (portal_entry_test untouched, re-run as the request-bound regression guard).
- `git diff --exit-code --stat -- lib/` → **empty** (zero `lib/` changes; REQ-1..REQ-4 are test-only).

## 4. Scope guard (non-goals, unchanged from the direction)

- **No `lib/` changes of any kind** — not `lib/api/portal_api.dart`, not the `lib/screens/portal/portal_api.dart` re-export shim, not `portal_screen.dart` wiring (`:125/:213`), not the TrustedDeviceToken call sites. Any behavioral change needed to make a test pass is a spec violation.
- **No SSE reconnect/backoff design change** — the current no-reconnect lifecycle is a separate direction (analysis candidate 3); this direction only pins the 401/403/500 hook firing on the stream.
- **No change to `login()`'s wire behavior** — the request-bound pins (`test/portal_entry_test.dart:301-363`) stay byte-identical in scope; the new tests never assert on emitted requests beyond the seeded `/me` 200s.
- **No edits to count-gated suites** — the four guard files, `test/edge_generation_*`, and the census files are untouched; `test/portal_api_test.dart` is not in any count pin (verified), so appending is pin-neutral.
- **No new dependencies** — `package:http/testing.dart` (already imported by the file) covers `MockClient`, including the `send()`-based SSE path.

## 5. Verification commands (executed post-change)

```bash
cd /home/u1/workspace/demo/snaplink-console
flutter test test/portal_api_test.dart test/portal_entry_test.dart   # AC-5 leg 1
git diff --exit-code --stat -- lib/                                  # AC-5 leg 2 (empty)
```
