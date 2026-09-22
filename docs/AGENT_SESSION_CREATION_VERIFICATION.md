# Session creation verification — 2026-09-14

Changes were developed in an isolated Console worktree based on `92b91f3`.
That baseline includes existing Forge work, which is preserved and is not part of
this increment. Production changes are limited to Agent API/models/screens and
Agent localization, with targeted tests and these Agent documents. Verification
applies to this isolated snapshot only. Concurrent Forge/native edits made later
in the primary Console workspace were not read into or validated by this run.

## Toolchain and baseline

The baseline's `pubspec.lock` SHA-256 is
`4daea7853cefa01ff3ba0bcb881df93b94f574b4498a3953b9ca6e9b24b2581e`.
`flutter pub get --enforce-lockfile` passes using the available Flutter
`3.48.0-0.5.pre` SDK, framework `2d06a6e304`, engine
`460e8e85b1945c78f9430c7f3a6d3756474d0230`, Dart `3.12.0-168.0.dev`.
No dependency manifest or lockfile is changed by this increment.

The repository's CI-pinned Flutter `3.47.4 stable` does not satisfy this baseline
lock: strict resolution requests changes to intl, matcher, meta, test_api and
vector_math. Its failed strict-resolution log is retained. This is a pre-existing
SDK/lock mismatch, distinct from the prior native acceptance baseline with lock
SHA-256 `f6c3611874b23077c4d6c4620ec0e74fd8c8e4ec0b40257f0f79a1f87eae8dcb`.
Checks below use the lock-compatible SDK and do not establish success on the
current CI-pinned SDK.

## Results

| Check | Result |
| --- | --- |
| Strict lock resolution with the compatible SDK | Passed; lock unchanged |
| `flutter analyze --no-pub` | Passed; no issues |
| New API/controller/widget suite plus existing Hub API and Operations regressions | 30 passed, including 17 new tests |
| Full Flutter VM suite | 1404 passed, 3 skipped, 1 existing Forge failure |
| Existing browser target (`make test-browser`) | 60 passed |
| New creation API/controller/widget suite in Chrome | 17 passed |
| Audit guard count pin | 83 passed, exact existing count |
| Python engineering unit tests | 24 passed |
| Web release with `/app/` base href and `agent-hub` resource | Passed |
| Release artifact check | Passed |
| Kubernetes minimal/full renders | Passed |
| Engineering harness | Existing Forge file-size failures; remaining checks passed |

The VM failure is `Forge sign-out clears only this client and returns to login`
in `test/forge_native_route_test.dart:205`: no `OidcLoginScreen` is found after
sign-out. The same test fails in a separate, unmodified `92b91f3` worktree
(1 passed, 1 failed in that file).

The harness rejects these unchanged baseline files against the existing 400-line
limit: `lib/api/forge_conversations_api.dart` (454),
`lib/api/forge_conversations_models.dart` (948), and
`lib/screens/forge/forge_sessions_screen.dart` (872). The unmodified baseline's
`check-filesize` reproduces all three failures. Complexity, architecture, directory
fan-out, root policy, security invariants and B6-1b source/artifact checks pass.
All new production modules and touched Agent files remain below 400 lines. No
exemptions, test skips, pins, or thresholds were added or loosened.

Logs are under `/tmp/hub-session-create-20260914/console-*.log` in the development
environment. They are local evidence paths, not deployed artifacts.

The final change received an independent read-only review. The review found and
verified fixes for unknown-result recovery after a later permission denial and
late 401 responses affecting newer credentials. An unknown request keeps its key
through `network failure → 403 → accepted` recovery; late responses only clean up
a still-mounted screen's matching bearer. Name validation rejects Unicode Cc/Cf
in the original input before trimming, including bidi and zero-width controls.
Identifiers retain the Hub's 256-character bound separately from the name's
256-byte bound.

## Scope of evidence

Mock HTTP tests exercise the real Console transport, state and widget behavior.
They do not run an authenticated production Hub, real Gateway, or paid model.
The shared Flutter UI is validated on the VM and compiled for Web; this increment
does not add Android/iOS/macOS/Linux/Windows native build or device acceptance.
The previous native acceptance reports remain historical evidence for their own
commits and toolchains.
