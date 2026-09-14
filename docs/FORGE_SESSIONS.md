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
`sessionStorage`; native tokens stay in memory. The Forge API client only
keeps the bearer in memory and sends it in the `Authorization` header. It does
not put the token in a URL, preferences, local storage, or a request body.

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
write. Responses are capped at 1 MiB and requests time out after 20 seconds.

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

This slice stores and displays conversation prompts. It does not yet create
Agent runs, stream model output, expose instance/device inventory, or dispatch
compute tasks. Those capabilities require separate Forge API contracts.
