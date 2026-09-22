# Forge Sessions client

The independent `/forge/` surface lists conversations owned by the current
Snaplink principal, creates global, project, or group conversations, reads
prompt history, and appends prompts. It is separate from Agent Operations:
Forge requests its own resource and conversation scopes and does not call the
Agent Hub API.

## Authorization

The page uses a token stored in a client-scoped `Session` slot. Its sign-in
route explicitly selects the `forge-console` Snaplink client so a Forge token
cannot replace the Admin Console token in the same browser tab. When Forge
returns an authorization failure, the sign-in action returns through the
existing Snaplink login page with only the Forge resource and these scopes:

- `forge:conversations:read`
- `forge:conversations:write`

Selecting “Sign out of Forge on this device” immediately hides the current
owner's Conversation, Prompt, Run, and local observation state while token
revocation and secure credential cleanup complete. A slow or unavailable
provider therefore cannot leave the previous owner view visible during logout.
If secure-store cleanup fails, the owner view remains hidden and the route
offers an explicit retry.

The client ID defaults to `forge-console` and can be set with
`SNAPLINK_FORGE_CLIENT_ID`. The resource defaults to `forge-api` and can be set
with `SNAPLINK_FORGE_RESOURCE`; it must match Forge's configured Snaplink
audience. Provision a dedicated Snaplink client with the same nonempty
`tenant_id` and public `subject_type` used by `forge-cli`, plus the exact
resource and both scopes. If Snaplink's scope registry is enabled, register
both scopes there as well. The login token is isolated from the default Admin
session, and an authorization failure clears only the Forge client slot. A
successful login does not create these grants or change Forge's server policy.
An explicit Console logout clears both the default session and its registered
client-scoped token slots.

The login route passes the client ID, resource, and scopes through the
Console's existing login path. Web tokens remain tab-scoped in
`sessionStorage`. Android and iOS use the platform secure store; macOS uses
device-bound Keychain storage, Windows uses Windows Credential Manager-backed
encrypted storage, and Linux uses Secret Service through libsecret. The Forge
route restores the saved native credential after a cold start, and token
rotation replaces the stored access/refresh pair before the updated session
is used. The Forge API client only keeps the bearer in memory and sends it in
the `Authorization` header. It does not put the token in a URL, preferences,
local storage, or a request body.

On Linux, macOS, and Windows, the credential store uses one per-client
advisory `FileLock` in the application-support directory for restore, login
writes, sign-out clears, and refresh-token rotation. This coordinates separate
Console processes and makes a login or logout wait for an in-flight rotation
before changing the secure record. The refresh callback uses a lock-owned
scope for its reload/store/clear operations, so the non-reentrant file lock is
never acquired recursively. A lock or secure-store failure fails closed. Web
and mobile keep their existing tab/process-scoped behavior and use a no-op
inter-process lock.

Linux builds need the libsecret development package and deployed apps need the
libsecret runtime package plus an available Secret Service (for example,
GNOME Keyring or KWallet). If secure storage is unavailable, Forge login fails
closed instead of keeping the credential in process memory. Windows desktop
builds require the Visual Studio C++ ATL libraries. macOS Runner entitlements
include the Keychain access-group capability required by the secure-storage
plugin.

## API origin

Web builds use the current page origin by default, so the deployment gateway
must route `/api/v1/conversations` and nested prompt paths to Forge. Any build
may instead set
`--dart-define=FORGE_CONVERSATIONS_API_ORIGIN=https://forge.example`; it must
be an HTTPS origin with no credentials, path, query, or fragment. HTTP is
accepted only for localhost and loopback development. If no override is set,
native builds use the Console's configured Snaplink origin. A cross-origin web
deployment must allow the Console page origin and the `Authorization`,
`Content-Type`, `Idempotency-Key`, and `Cache-Control` request headers in
Forge's CORS policy.

## API behavior and limits

The client uses `GET` and `POST /api/v1/conversations`,
`GET /api/v1/conversations/{id}/prompts`, and
`POST /api/v1/conversations/{id}/prompts`. Writes include a fresh
`Idempotency-Key`; an ambiguous network result keeps the same request and key
for an explicit retry. Prompt appends send the current `aggregate_version` as
`expected_version`; a conflict refreshes the conversation before another
write. GET reads use at most three attempts with 50 ms and 100 ms backoff for
transport failures and transient HTTP 408, 425, 429, or 5xx responses. POST
writes are not retried for transient failures; the existing one-time 401 token
retry preserves the original idempotency key. Responses are capped at 1 MiB.
Each attempt times out after 20 seconds, so a GET that exhausts all three
attempts can take about 60 seconds including backoff.

The `/api/v1/conversation-changes` feed uses dense cursors scoped to the exact
authenticated owner tuple. Foreign-owner changes do not create cursor gaps or
advance another owner's head, and the API does not expose the Hub's global
journal cursor. The Console polls every 15 seconds, up to four pages of 128
changes per poll. It stores the replay cursor in browser `localStorage` or
native platform preferences. The checkpoint key is a SHA-256 binding over the
API origin, Forge client/resource, and the token's issuer/tenant/subject
claims; the token itself is never stored there. These claims only partition
this local cache and do not authorize API access. A scanned cursor is saved
only after required conversation and selected-history refreshes succeed. If
local storage is unavailable, the current screen continues in memory and a
later restart may replay changes. Writes serialize within the app's Dart
isolate, and Web Locks serialize updates across browser tabs where supported.
Older embedded browsers without Web Locks may replay a stale suffix, which
does not skip feed events. Delivery remains polling rather than a push stream.
After a successful periodic feed read, a previously failed conversation
snapshot is retried automatically so a transient network outage can recover
without a manual refresh.

The Console also keeps a bounded last-successful conversation metadata
snapshot so the first page can remain useful during a network outage. The
snapshot contains only conversation ID, scope, title, timestamps, and
aggregate version; it never stores prompt content, run data, bearer tokens, or
owner claims. Its key and record are bound to a SHA-256 hash of the normalized
Forge origin, client/resource, and JWT issuer/tenant/subject. Opaque tokens do
not enable this cache. Records with unknown fields, invalid metadata, a
different binding, more than 128 conversations, or more than 256 KiB of JSON
are ignored. A stale/offline banner identifies when the displayed list came
from this cache, and a successful network refresh replaces it. Explicit Forge
sign-out removes the current owner's snapshot.

This slice stores and displays conversation prompts. The Sessions surface also
supports explicitly injected or local-file, display-only client-instance and
device-resource observations, including local imports of the complete
instance-to-session and instance-to-resource views; those values remain
unverified declarations and
never select a target. It does not yet create Agent runs, stream model output,
accept authoritative device inventory, or dispatch compute tasks. Those
capabilities require separate Forge API contracts and the P3b/P4 governance
decisions.

The shared client-instance fixtures include sorted CLI, TUI, Web, desktop App,
and Mobile declarations. The matrix is a local observation of the five client
kinds; it does not authenticate an installation or grant Prompt, device, or
execution authority.
