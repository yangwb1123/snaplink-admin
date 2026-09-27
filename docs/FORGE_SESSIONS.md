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
does not skip feed events. After a successful periodic feed read, a previously
failed conversation snapshot is retried automatically so a transient network
outage can recover without a manual refresh. The default Sessions construction
continues to use this bounded polling path.

An explicit caller may use `ForgeConversationsApi.conversationChangesStream`
for the same owner-scoped feed over `/api/v1/conversation-changes/stream`.
The method sends `after_cursor`, a bounded `limit`, and a bounded `wait_ms`,
requests `text/event-stream`, and returns one validated
`ForgeConversationChangePage` for a `200` response. A `204` response means the
bounded wait ended without a new owner change and returns `null`. The parser
requires exactly one `conversation_changes` event, rejects unknown or
duplicate SSE fields, rejects duplicate JSON members and unsafe numeric
values, and requires the SSE `id` to equal `scanned_through_cursor` in the
decoded page. A caller may opt the Sessions widget into this transport with
`enableConversationChangesStream: true` and an optional bounded
`conversationChangesStreamWaitMS`. The widget starts the stream after its
initial owner snapshot, allows only one foreground stream request at a time,
reconnects after a successful `204`, and falls back to the existing polling
path after a transport, authorization-refresh, or framing failure. A replay
cursor advances only after the same conversation/history merge used by the
polling path succeeds. The stream is read-only and opens no execution or
device authority. The shared `ForgeSessionsGate` forwards this option only
when a caller explicitly sets `enableConversationChangesStream`; its default
is `false` with a 15-second bounded wait. Before either stream or polling feed
is consumed under an instance filter, the latest owner-bound observation must
still contain the selected instance. A removed instance fails closed before
transport, clears private state through the existing visibility guard, and
leaves the owner-local cursor unchanged. The in-memory cursor is published
only after its persistent checkpoint accepts the new value.

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

Callers that already hold an authenticated owner declaration can opt in to a
paired session/resource read through `ForgeSessionsGate`. Console performs one
owner-bound GET for each existing view, validates the owner and complete
instance rows as a single display envelope, and feeds both existing panels
only after the pair converges. The default Gate leaves the owner and reader
unset, keeps all authority flags false, and makes no candidate request. A
failed refresh retains the last validated pair and marks it stale. A write
boundary reuses a current validated pair instead of starting a duplicate GET;
missing, loading, stale, failed, or drifted observations still block the
operation. The built-in inventory and resource candidate readers use
wall-clock request deadlines so real HTTP IO is not expired by a caller's
virtual frame clock.

The pair guard also re-decodes injected session/resource values before using
them as a local filter. A manually assembled outer convergence envelope cannot
hide a malformed nested schema, owner, row, ordering, or authority field.

The inventory/resource convergence reader also requires each v2 inventory
device's `snapshot_observed_at_ms` to equal the paired resource device's
`observed_at_ms`. A counter or resource match from a different persisted
Runner observation is rejected as stale, while client-instance row timestamps
remain independent display metadata.

Before a locally constructed pair is accepted as a convergence boundary,
Console round-trips both observations through their strict wire decoders. A
tampered envelope, owner, capacity, lifecycle, GPU, revision/generation/
heartbeat, or authority field therefore fails closed even when the caller
constructed the typed value in memory.

Callers may also provide an `initialClientInstanceID` selection hint to the
shared Gate. When an owner-bound session/resource observation declares that
instance, the Gate loads that observation before the first Conversation page,
filters the local list, and hydrates Prompt/Run detail only for a declared
session. An unknown or unavailable instance produces an empty local
projection and performs no private history read. The hint is a display
selection only; it is not client authentication, Prompt authorization,
inventory authority, target selection, reservation, scheduling, or Runner
execution.

Pending Run-intent submission keeps the same CAS binding as Core: a fresh
(`replayed=false`) receipt must report `aggregate_version ==
expected_version + 1` within the JSON-safe integer ceiling. A replay is the
original idempotent receipt and may retain its historical aggregate version;
the Console accepts that version only when `replayed=true`. Any binding-valid
but version-drifted fresh response is rejected before it reaches Sessions
state.

During an owner-scoped refresh, a selected Conversation that is absent from
the newly returned first page is revalidated with its detail read before the
selection is retained. A deleted, revoked, foreign, or unavailable detail
response clears the selected Conversation and its private Prompt/Run panels
while keeping the fresh owner page. This prevents the screen from continuing
to display or read a stale session after deletion or revocation.

Private Prompt, Run, and Run timeline reads also fail closed on a deterministic
owner rejection or a foreign/malformed response. The selected Conversation and
its private projections are removed before the error is shown, while transient
timeouts, rate limits, and server failures retain the existing stale/error
behavior for retry. This is a read boundary only; it does not add session,
device, scheduling, or Runner authority.

The selected-instance create boundary follows the same rule. Before an
owner-wide Conversation create, Sessions refreshes the selected owner-bound
session/resource declaration. If the returned Conversation is not listed by
that declaration, the owner storage result is retained without selecting it,
changing the URL, or reading its Prompt/Run details. A focused widget test
proves one create request and zero private Prompt/Run reads; instance
membership and execution authority remain outside this display projection.
