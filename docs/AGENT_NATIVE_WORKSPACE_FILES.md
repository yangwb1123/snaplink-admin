# Native workspace file access

This increment adds system file selection and saving to the existing workspace
bundle flow. Input remains explicit user-selected JSON; output is verified by the
Hub API client before any save dialog is opened. The HTTP and Vault contracts do
not change. No background directory scan or source-directory overwrite is added.

## Client flow

In Agent Operations, select an authorized session and open Compute tasks. Enable
workspace input, choose a JSON bundle (or paste one), upload it and select the
resulting snapshot. Submit a task with explicit output paths. Once its workspace
result is ready, save the verified output JSON through the system dialog.
Cancelling either dialog leaves the operation available for retry. Viewing and
copying the JSON remains available alongside native saving.

The output is a `pbatch.workspace.v1` bundle. Saving it does not extract its files
into a project. The existing CLI `fleet compute workspace-output TASK_ID
--directory NEW_DIRECTORY` retrieves the remote task output and restores it into
a new directory; it is not a local bundle import command.

## Host contract

Flutter's standard method codec uses channel
`site.ywbsd.sso/agent_workspace_files`:

| Method | Arguments | Result |
| --- | --- | --- |
| `capabilities` | none | `{version: 1, pick: true, save: true}` |
| `pickJson` | `{maxBytes: int}` with `1 <= maxBytes <= 524288` | typed bytes, or `null` on cancellation |
| `saveJson` | `{filename: string, bytes: typed bytes}` | `true` after saving; `false` on cancellation |

The host rejects files beyond 512 KiB and reads at most `maxBytes + 1` bytes before
checking the bound. If metadata size is consulted, it is only an early rejection,
never the sole check. It must not import/copy an entire unknown file before
checking the bound.
Suggested names match `^workspace-[A-Za-z0-9_-]{1,96}\.json$` in full. The Dart caller
also checks byte size and decodes picked UTF-8 strictly before bundle validation.
The filename rule applies to the suggestion supplied by Dart; users may rename
the output in the system dialog.

Only one file operation is active per host. Stable errors are
`invalid_arguments`, `too_large`, `busy`, `io_error`, and `unavailable`; neither
errors nor logs include contents, paths or provider URIs. Cancellation is distinct
from failure and success. Callbacks must complete at most once, including activity
or window teardown. Export staging, when required by the platform, uses a private
temporary location with bounded content and cleanup after dismissal.

Missing or incompatible hosts expose neither capability; JSON view/copy/paste
remains available. Native save dialogs allow the user to choose a destination and
confirm replacement. Web retains its browser upload/download behavior. Downloads
and picker responses for an old session/task must not populate the new selection.

## Platform integration

- Android: system document provider intents; `INTERNET` in the main manifest.
  See [Android implementation and evidence](AGENT_WORKSPACE_ANDROID_FILES.md).
- iOS: security-scoped document selection and a bounded temporary export.
- macOS: open/save panels with network client and user-selected read/write sandbox
  entitlements. See [Apple implementation and evidence](AGENT_NATIVE_APPLE_FILES.md).
- Linux: GTK file chooser with background bounded file I/O.
- Windows: system file dialogs with background bounded file I/O.
  See [desktop implementation and evidence](AGENT_DESKTOP_WORKSPACE_FILES.md).

## Verification

The follow-up [native acceptance report](AGENT_NATIVE_ACCEPTANCE.md) records the
fixed SDK, strict dependency lock verification, Android device instrumentation,
and Windows cross-compilation/runtime checks. The measurements below belong to
the preceding implementation increment and retain its original limitations.

### Initial implementation verification (2026-09-13)

The Flutter/UI increment was tested at `25aa5fe` before integrating native host
sources. Its Dart source is unchanged by the host integrations. After merging all
hosts, their sources were compared with the platform worktrees, the complete
engineering harness passed again, and workflow YAML/shell syntax and the complete
diff were checked. The integrated harness log is
`/tmp/hub-native-resume/console-integrated-harness.log`.

| Check | Result |
| --- | --- |
| Flutter analysis | No issues |
| Full Flutter VM suite | 1,332 passed |
| Chrome workspace and existing browser contracts | 60 passed |
| Audit guard suite and exact count pin | 83 passed |
| Python engineering tests | 24 passed |
| Web release, release artifact check, complete harness | Passed |
| Kubernetes manifests | Both overlays rendered locally |

The 17 new Flutter tests cover channel response validation, size and UTF-8 bounds,
missing hosts, cancellation, concurrent calls, fixed error messages, 320 px
English/Chinese layouts, digest verification before saving, and late callbacks
when the selected session/task changes. Native-host test/build results are listed
separately below; Flutter channel mocks do not establish native platform behavior.

Logs are `/tmp/hub-native-{analyze,all-tests,browser-tests,guard-tests,python-tests,
web-build,artifact,harness,k8s}.log`. The Web build uses `/app/` as base href,
`SNAPLINK_ADMIN_OAUTH_RESOURCES=billing-api,stripe-adapter-api,audit-governance`
and `SNAPLINK_AGENT_HUB_RESOURCE=agent-hub`.

### Toolchain and dependency limits

Local Flutter is `3.48.0-0.5.pre` (master), with Dart `3.12.0-168.0.dev`.
Its offline package resolution selected `intl 0.20.2`, `matcher 0.12.18`,
`meta 1.18.0`, `test_api 0.7.9`, and `vector_math 2.2.0`; the committed lockfile
instead specifies `0.20.3`, `0.12.20`, `1.19.0`, `0.7.12`, and `2.4.2` respectively.
The automatic lockfile changes were restored before the `--no-pub` checks.
No dependency manifest or lockfile change is part of this increment. These local
results describe the resolved package configuration, not a successful
`--enforce-lockfile` build. The new native CI workflow enforces the committed lock
and must pass on compatible SDKs before platform release.

### Platform evidence

| Platform | Build/runtime evidence |
| --- | --- |
| Android | Debug APK built and started on a temporary emulator; 20 JVM tests passed; SAF smoke did not reach channel assertions because VM evaluation failed |
| iOS | Source/target/scheme checks passed; 14 XCTest cases authored, not executed; build and native UI unverified |
| macOS | Source/target/scheme/entitlement checks passed; 14 XCTest cases authored, not executed; build and native UI unverified |
| Linux | Debug app built; 7 C++ native test groups passed under Xvfb, including chooser and background-I/O lifecycle checks |
| Windows | Native source reviewed; portable argument tests passed with Clang; Windows build, Win32 I/O/worker tests and system dialogs unverified |

Android APK: `/tmp/hub-native-resume/android/build/app/outputs/flutter-apk/app-debug.apk`.
Linux bundle: `/tmp/hub-native-resume/desktop/build/linux/x64/debug/bundle/`.
Web output contains 93 files (44,974,628 bytes); its content-manifest SHA-256 is
`eb0e19e2ec507b958b9936aec9b405f741caafd2813cd6874848333ff9d81cb4`.
The per-file manifest is `/tmp/hub-native-resume/console-web-manifest.json`.
The new workflow includes native tests/builds for all five hosts, but it has not
been executed remotely.

No production deployment, remote ecosystem account access, physical-device test,
or remote GitHub Actions run has been performed by this increment.
