# Native workspace acceptance follow-up

This follow-up makes the native workspace file boundary reproducible: Android
uses device instrumentation in place of VM expression evaluation, Windows tests
compile and execute actual Win32 code, and Console CI pins the SDK used for strict
dependency resolution. The session, prompt, compute, and Vault API contracts are
unchanged.

## SDK and dependency lock

Both workflows use Flutter **3.47.4 stable**, framework
`9584c6713b324636289d067944a46fd6b49df14b`, Dart **3.13.3**, and engine
`06a2e2a110089dff50fe635cffd2a61e1b24fbcd`. The Linux SDK was downloaded from
the [official release archive](https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.47.4-stable.tar.xz)
and checked against the [official release manifest](https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json):
SHA-256 `5b45f0ceda99b9bebdc873e7e69f6450aeb4c30f454b505e2e62fc9255a907d3`.

`flutter pub get --enforce-lockfile` passed in both Console and Android test
worktrees. The committed `pubspec.lock` remains byte-identical, SHA-256
`f6c3611874b23077c4d6c4620ec0e74fd8c8e4ec0b40257f0f79a1f87eae8dcb`.
There is no dependency downgrade or manifest change. This resolves the earlier
prerelease SDK's dependency mismatch; its original measurements remain in the
[initial implementation report](AGENT_NATIVE_WORKSPACE_FILES.md).

## Verified results (2026-09-13)

| Check | Result |
| --- | --- |
| Strict lock resolution and Flutter analysis | Passed; no analysis issues |
| Full Flutter VM suite | 1,332 passed |
| Browser suite through `make test-browser` | 60 passed |
| Audit guard count pin | 83 passed; a subset of the VM suite |
| Python engineering tests | 24 passed |
| Web release, artifact gate, engineering harness | Passed |
| Kubernetes profiles | Both rendered locally |
| Linux debug application and native tests under Xvfb | Built; 7 test groups passed |
| Windows stable engine cross-compilation and Wine | 9 translation units compiled; both runtime groups passed |
| Android debug APK, JVM and device instrumentation | Built twice; 20 JVM and 9 device tests passed |

Android's second `--no-pub` build left tracked files and the lock unchanged.
The SDK's two Gradle compatibility properties are committed explicitly to retain
the existing Kotlin plugin and DSL. Generated profile/release manifests contain
no debug test Activity. The stable-SDK device run took 37.634 seconds; APK hashes
and JVM/manifest evidence are in
`/tmp/hub-native-acceptance/locked-android-evidence.json`. See the Android report
for the exact scope of each device case.

The browser target now includes workspace file selection, API, and model tests.
Previously these ran only in the manual browser acceptance command. The 60-test
target covers UTF-8 and size bounds, digest verification, Unicode ordering, and
authorization/error handling on the browser platform as well as existing browser
contracts. Some model/API tests also run in the VM suite; counts are not additive.

Console logs and command results are under `/tmp/hub-native-acceptance/`:
`locked-pub-get.{log,json}`, `locked-console-checks.json`, and
`locked-{analyze,all-tests,browser-tests,guard-tests,web-build,artifact,harness,
linux-build,linux-test-build,linux-tests}.log`. Python and manifest-render logs are
`python-tests.log` and `k8s.log` in the same directory.

The Web release uses base href `/app/`, OAuth resources
`billing-api,stripe-adapter-api,audit-governance`, and Hub resource `agent-hub`.
It contains 93 files, 44,581,389 bytes. Its per-file manifest is
`/tmp/hub-native-acceptance/console-web-manifest.json`, with canonical file-list
SHA-256 `1a37bdd4b5f9519c0e6bc529c726bc000399d26a187155bf7a1c102ac2c8b5cb`.
The Linux debug bundle is retained at
`/tmp/hub-native-acceptance/console/build/linux/x64/debug/bundle/`, with its file
manifest in `/tmp/hub-native-acceptance/linux-bundle-manifest.json`.

## Repeatable native checks

Android's non-exported debug Activity hosts the production channel and Flutter
standard codec. The device runner requires an explicit emulator serial, API 29+
and English locale, then rejects incomplete or failed instrumentation results.
CI builds the application, instrumentation APK and JVM tests before starting an
isolated API 36.1 Google Play x86_64 emulator. See the
[Android cases and limitations](AGENT_WORKSPACE_ANDROID_FILES.md).

Windows CI's CMake target includes the production contract, I/O, worker, channel
and Flutter codec. The supplemental Linux cross-compilation script emits exact
commands and file hashes; Wine execution is a separate result. Matching official
Windows artifacts from the stable engine passed the nine translation-unit build
and both runtime test groups. See the
[Windows dependencies and evidence](AGENT_WINDOWS_WORKSPACE_VERIFICATION.md).

The integrated code and workflow received an independent read-only review with
no blocking findings. Workflow YAML and applicable Bash syntax were checked.

## Local revalidation (2026-09-27)

This host currently has Flutter 3.49.0-0.1.pre, not the workflow's pinned
3.47.4 stable SDK; results below are local evidence and do not replace a run of
the configured CI workflow.

- `flutter analyze --no-pub`: passed with no issues.
- Debug Android APK, `:app:assembleDebugAndroidTest`, and
  `:app:testDebugUnitTest`: passed.
- `android/tests/run_workspace_instrumentation.py` on the local API 36.1 English
  emulator: all 9 instrumentation tests passed (48.65 seconds).
- Focused native workspace Flutter tests: 17 passed; Python unit tests: 24
  passed; browser suite: 61 passed.
- Audit guard regressions caused by the `0xdbff` Unicode high-surrogate literal
  were removed without weakening the guard; its baseline and mutation suites
  pass. The two fixture-backed execution-evidence tests now explicitly skip
  when their required external fixture paths are absent; those acceptance cases
  remain unrun without the fixtures.
- The pending-timeline refresh test now uses an owner-bound test JWT so its
  local cursor checkpoint can persist; this removes the duplicate-read fixture
  failure. Forge literal copy now uses `LocalizedText`, and the missing Chinese
  catalog entries are filled. Full `flutter test --no-pub -r expanded` passes:
  2,054 passed, 172 skipped, and no failures. The run log is
  `/tmp/snaplink-console-flutter-test-file-splits-final.log`.
- Linux debug build was attempted but this host lacks `libsecret-1`; the native
  workflow now installs `libsecret-1-dev`. The local Linux application and C++
  test have therefore not been verified in this run.

## Remaining acceptance boundaries

Android instrumentation does not traverse MainActivity, FlutterEngine, the
Flutter form, or authenticated Hub requests. Eight cases use the production
channel with system UI/lifecycle checks; the ninth injects an existing provider
URI to verify truncate-mode I/O. Channel replacement on the same test Activity
does not establish real Activity/engine recreation.

Windows cross-compilation and Wine tests do not establish an MSVC build, complete
Windows application startup, system file dialogs, busy/pending destruction, or
physical Windows behavior. Apple source integration and XCTest definitions remain
unexecuted here because Xcode and Apple SDKs are unavailable. The configured
remote CI has not been run. No production deployment, physical-device acceptance,
or authenticated cross-service end-to-end test is claimed.
