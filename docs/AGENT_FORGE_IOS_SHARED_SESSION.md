# Forge iOS host shared-session rotation boundary

The host-side native lifecycle test
`test/forge_mobile_shared_session_e2e_test.dart` accepts an explicit
`ios-host` marker. It uses the same versioned `ForgeCredentialStore` record
and owner-bound `ForgeChangeCursorStore` used by the iOS route, with an
in-memory backend injected because this Linux environment cannot run an iOS
Keychain or simulator.

The test now exercises a credential rotation across two cold starts. The first
client restores the original access token, reads the owner Conversation and
change cursor, and appends one Prompt. The persistent record is then replaced
with a different access/refresh tuple. After the in-memory client slot is
cleared, the second cold start must restore the rotated access token, preserve
the owner cursor, replay the same idempotent Prompt, and observe one matching
owner change. Forge Core's real JWT authentication and Go-to-Rust Coordinator
path serve these requests; device, inventory, placement, reservation,
dispatch, and execution routes are asserted absent.

The Go integration supplies the two valid tokens and runs both `android-host`
and `ios-host` variants:

```sh
FORGE_RUNTIME_BIN=/path/to/forge-runtime \
FORGE_CONSOLE_E2E=1 \
FORGE_MOBILE_SHARED_SESSION_E2E=1 \
SNAPLINK_CONSOLE_ROOT=/path/to/snaplink-console \
go test ./internal/appserver \
  -run '^TestIndependentClientsShareOwnedConversationAndPrompts$' -count=1
```

This is host-side authenticated lifecycle evidence. It does not claim a
physical iPhone, iOS Keychain, simulator, or production device execution.

## Explicit iOS XCTest boundary

The repository also carries a native boundary harness at
`ios/RunnerTests/ForgeIOSSharedSessionAcceptanceTests.swift` and an opt-in
runner at `ios/tests/run_forge_shared_session_acceptance.sh`. The runner is
closed by default. When explicitly enabled, the only value passed to
`xcodebuild` is the path of a private JSON file; the bearer values are not
placed in launch arguments or printed. The Linux-safe validator checks the
same file before any Xcode command runs:

```sh
chmod 600 /private/path/forge-ios-shared-session.json
FORGE_IOS_SHARED_SESSION_ACCEPTANCE=1 \
FORGE_IOS_SHARED_SESSION_INPUT=/private/path/forge-ios-shared-session.json \
  ios/tests/run_forge_shared_session_acceptance.sh
```

The JSON has exactly the following fields: `platform` (`ios-simulator` or
`ios-device`), `api_url`, the original and rotated access tokens,
`conversation_id`, `client_instance_id`, strict display-only `session_view`
and `resource_view` observations, `expected_version`, `after_cursor`,
`prompt`, and `idempotency_key`. The selected instance must be a `mobile`
row, contain the Conversation in both observations, and have identical
owner-bound instance rows and an offline authority declaration. A missing or
hidden row, owner drift, or instance drift rejects the input before a Prompt
request can be considered. `https` origins are accepted; `http` is accepted
only for loopback. The XCTest asserts the explicit opt-in marker, credential
rotation shape, and the request allowlist: Conversation listing, change-feed
reads, owner client-instance/session-view and resource-view GETs, and the
owner Conversation's Prompt GET/POST. Device, inventory mutation, placement,
reservation, dispatch, run-intent, execution, receipt, and heartbeat paths are
rejected. On Linux the script reports a skip after validating the input,
because physical iOS XCTest requires macOS and `xcodebuild`.

The validator opens the file with no-follow semantics and checks the descriptor
metadata before reading it, closing the symlink replacement window. Conversation
and idempotency identifiers are restricted to path-safe ASCII characters so a
fixture cannot turn the route allowlist into a path-construction escape.

This native boundary still does not claim a physical iPhone, iOS Keychain
write, simulator API call, device enrollment, placement, scheduling, remote
execution, or receipt. Both mobile validators reject duplicate JSON keys and
keep `expected_version`/cursor values within the Forge JSON-safe integer
ceiling. The authenticated Go → Rust → Flutter `ios-host`
journey above remains the evidence path for the real Coordinator contract;
the XCTest keeps the future native runner's input and route boundary explicit
until an Apple runner is available.

## Metadata-only Runner admission contract

`ios/tests/run_forge_admission_contract.sh` runs the Linux-safe native
contract subset for both iOS and Android evidence. It validates the strict
dispatch and transport admission response shapes, binds their owner and
target to the read-only resource image, and rejects foreign targets or any
authority flag. The local trace permits only session/resource reads and the
two admission preview endpoints; direct Runner dispatch is rejected.

This contract harness does not invoke `xcodebuild`, a simulator, HTTP, a
transport payload, reservation, or execution. The opt-in XCTest and the
authenticated `ios-host` journey remain separate platform evidence and retain
their existing default-off boundaries.
