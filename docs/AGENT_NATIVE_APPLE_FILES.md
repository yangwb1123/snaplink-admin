# Apple workspace JSON files

The iOS and macOS Runner targets register
`site.ywbsd.sso/agent_workspace_files`. The channel advertises version 1 with
`pick` and `save` support. Flutter still owns UTF-8, JSON/schema, digest and Hub
validation. The native host returns bytes from a file the user selects; it does
not accept a path or URL from Flutter.

On iOS, import opens a document in place through `UIDocumentPickerViewController`.
Export first writes a bounded JSON bundle into a private temporary directory and
uses the document picker to copy it to the user's destination. Completion,
cancellation and engine detachment remove that export directory. Save success is
reported only after the document picker reports a selected export destination.

On macOS, import uses `NSOpenPanel` and export uses `NSSavePanel`. The suggested
filename is validated before the dialog. Users may rename the file in the dialog;
the JSON bundle is written atomically to their chosen destination. Both sandbox
entitlements grant access to user-selected files and permit client networking.
The channel does not grant arbitrary filesystem access.

Both hosts require exactly the supported argument keys. Pick limits are integers
from 1 through 524,288; booleans, floating point values and extra keys are rejected.
Save accepts only the codec's UInt8 typed buffer, at most 524,288 bytes, and a
suggested basename matching `workspace-[A-Za-z0-9_-]{1,96}.json` in full. Errors use
fixed codes/messages with no selected paths, URLs or exception details.

Each operation owns a UUID, callback and file coordinator. Picker/panel callbacks
are consumed before asynchronous I/O; completion checks the UUID, so a delayed
callback cannot finish a successor request. Shutdown cancels coordination and
invalidates the pending callback before dismissing the dialog. iOS publishes its
plugin so Flutter calls its engine-detachment hook. macOS FlutterPlugin has no
such hook in the inspected SDK, so window closure and published-plugin release
perform cleanup.

`WorkspaceFileAccess.swift` is identical in both Runner targets. Security-scoped
access surrounds background I/O. Reads open a nonblocking descriptor and check
that descriptor is a regular file before reading, including for symlinks. The
loop preserves short reads, stops at EOF, and reads at most the requested limit
plus one byte. FIFOs, devices and directories are rejected. Cancellation stops
pending coordination and is checked between read chunks. An atomic write already
inside its filesystem operation can finish after cancellation; a stale operation
never reports success to a newer request. This follows Apple's documented
[cancellation behavior](https://developer.apple.com/documentation/foundation/nsfilecoordinator/cancel%28%29).

## Verification status — 2026-09-13

Executed in the Linux development environment:

- Parsed both OpenStep Xcode project files and verified each plugin/helper source
  belongs to the Runner source build phase exactly once.
- Parsed shared scheme XML and verified the RunnerTests target references.
- Parsed both macOS entitlement plists and checked file/client-network grants.
- Confirmed the shared I/O helper is byte-identical across Apple targets.
- `git diff --check` passed.

Each platform has 14 authored XCTest cases covering argument rejection, exact
filenames, UInt8-only buffers, limits, closed plugins, short reads, EOF, read
failure, regular-file/FIFO handling, cancellation, and replacing a longer file
with a shorter bundle at a renamed destination. These tests and the Apple app
builds were **not executed**: this host has no Xcode, Apple SDK or Swift compiler.
The source/structure checks above do not establish Apple compile or runtime
success. Native picker interactions also remain unverified on Apple devices.

The platform CI workflow is expected to run XCTest with the shared Runner scheme
after Flutter builds the platform dependencies. macOS uses destination
`platform=macOS`; iOS uses an available iPhone simulator UUID after an iOS
simulator build. A local example for macOS is:

```sh
flutter build macos --debug --no-pub
xcodebuild -workspace macos/Runner.xcworkspace -scheme Runner \
  -configuration Debug -destination 'platform=macOS' \
  test CODE_SIGNING_ALLOWED=NO
```

The CI workflow itself has not been run from this development session. These
exports remain JSON bundles; saving does not unpack them or modify a project's
source tree.
