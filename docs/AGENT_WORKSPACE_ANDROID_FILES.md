# Android workspace document channel

Android uses the system Storage Access Framework for workspace JSON import and
export. It requests a document from the user with `ACTION_OPEN_DOCUMENT` or
`ACTION_CREATE_DOCUMENT`, with the `application/json` MIME type and
`CATEGORY_OPENABLE`. It does not request broad storage access. The main manifest
declares `INTERNET` so release builds can contact the configured Agent Hub.

The channel name is `site.ywbsd.sso/agent_workspace_files`:

| Method | Input | Result |
| --- | --- | --- |
| `capabilities` | none | `{version: 1, pick: true, save: true}` |
| `pickJson` | `{maxBytes: int}` | Flutter typed bytes, or `null` on cancellation |
| `saveJson` | `{filename: String, bytes: Uint8List}` | `true` after closing the completed write, or `false` on cancellation |

The host validates `maxBytes` in `1..524288`, and save bytes at most 524288.
Suggested filenames must fully match `^workspace-[A-Za-z0-9_-]{1,96}\.json$`. Unknown,
missing, and incorrectly typed arguments are rejected. The user may rename the
document in the system save dialog. Selection does not parse
JSON; Dart owns strict UTF-8, workspace schema, and digest validation.

Provider I/O runs on a background worker. Reads consume at most `maxBytes + 1`
bytes, including documents whose length is unknown. Writes use bounded chunks;
the descriptor uses explicit truncate mode `wt`, because provider mode `w` is
not guaranteed to truncate ([ContentResolver documentation](https://developer.android.com/reference/android/content/ContentResolver#openFileDescriptor(android.net.Uri,java.lang.String,android.os.CancellationSignal))).
Success is returned only after flush and close. Neither operation preloads or
copies an unbounded provider document. Only one request can own a picker or
transfer at a time. Duplicate callbacks cannot complete another request, and
process-unique request codes prevent an old Activity result from completing a
request after recreation. Destroying or detaching the Activity cancels its
provider signal and worker, closes its descriptor, and completes the request as
unavailable once. As with other document providers, an interrupted or failed save
can leave a partial new document; it must not be reported as a successful save.

Public errors are `invalid_arguments`, `too_large`, `busy`, `io_error`, and
`unavailable`. Their messages are fixed and contain no document content, URI,
path, provider exception, or filename. The channel does not accept a filesystem
path or URI from Dart and does not retain document access grants.

## Verification

The plain JVM suite lives under `android/app/src/test/`. It covers strict input
types and filename boundaries, inclusive size limits, unknown provider lengths,
fragmented and zero-length reads, bounded writes, cancellation, I/O failure,
byte ownership, duplicate/stale callbacks, and Activity request recreation.

The device suite under `android/app/src/androidTest/` calls the **production
`WorkspaceFilesChannel` through Flutter's `StandardMethodCodec`**. A non-exported
Activity in `src/debug/` owns the channel. It is absent from profile and release
source sets and manifests; no Dart VM service or expression evaluation is needed.
The test messenger replaces only the incoming Dart transport. Android Activity
results, system DocumentsUI, and the Downloads provider perform real operations.

Eight device cases cover capabilities and malformed arguments, pick/save
cancellation, busy rejection, an exact 512 KiB read, oversized provider input,
UTF-8 saving with a user-selected name, same-name saving, and close/stale callback
ownership. Downloads allocates a new document for a duplicate save name; the
test checks that the existing file remains unchanged. A ninth case injects an
existing provider URI as the Activity result to check truncate-mode I/O and exact
bytes before acknowledgment. **That ninth descriptor check does not claim a
real dialog selection of an existing file.**

The ownership test closes and replaces a channel on the same debug Activity. It
does not simulate a real Activity/engine recreation. The suite does not traverse
`MainActivity`, `FlutterEngine`, the Flutter form, or authenticated Hub requests;
the existing Dart/widget tests cover the client adapter and form separately.

After Flutter dependency resolution and generation of the Android Gradle wrapper,
build both APKs and the JVM tests:

```sh
flutter build apk --debug --no-pub
android/gradlew -p android :app:assembleDebugAndroidTest :app:testDebugUnitTest --console=plain
python3 android/tests/run_workspace_instrumentation.py --serial emulator-5554
```

Use a **dedicated disposable emulator** with API 29+ and English locale. The runner
requires its explicit `emulator-N` serial, checks API/locale, installs only to that
emulator, and requires all nine test results. An instrumentation command's zero
process exit alone does not pass the gate. Fixtures use unique filenames and are
deleted through the appropriate document or MediaStore provider. The runner does
not create, reset, or stop an emulator. Pass `--adb` to choose an SDK binary, and
`--app-apk`/`--test-apk` to override the generated APK paths.

Set `JAVA_HOME` and Android SDK environment variables for the current command if
needed. Do not alter global Flutter configuration just to select a local SDK.
This repository currently signs the release build with the debug signing config;
a successful APK build does not establish production signing or store readiness.

The initial build used Flutter `3.48.0-0.5.pre`, Dart `3.12.0-168.0.dev`, and JDK 21.
It reused the dependency resolution from the preceding Console validation while
preserving the committed `pubspec.lock`. That SDK's resolved package versions
differed from the committed lock, so that initial run was not an enforce-lockfile test.
Native tests do not establish a complete authenticated Hub upload/download
workflow or behavior of every third-party document provider.

### Initial instrumentation result (2026-09-13)

- `:app:assembleDebug :app:assembleDebugAndroidTest :app:testDebugUnitTest`:
  passed; 20 JVM tests, zero failures/errors/skips (16 policy and 4 ownership).
- Device instrumentation: **9 passed in 34.149 seconds**, using disposable
  `emulator-5582`, pixel_6 profile, Android 16 image
  `system-images;android-36.1;google_apis_playstore;x86_64`, emulator 36.4.9,
  English `en-US`, DocumentsUI version 16 (`361153320`).
- Generated debug, profile, and release manifests were checked: the test Activity
  appears only in debug. Python syntax compilation and `git diff --check` passed;
  a physical-device serial was rejected before any ADB operation.
- Debug APK: 152,556,800 bytes, SHA-256
  `0c2e37d40f9baa1fb7feba789aa5edd7e049491e42a0ae8be190f2b2f858d72d`.
- Instrumentation APK: 440,929 bytes, SHA-256
  `e79f40f1a868baf82f7dade91e19fabd97f187440803ad0d4eab47077c3e76d8`.

The earlier VM-expression smoke harness never reached its channel assertions
(VM error 113). It has been replaced by the instrumentation suite above. No
physical device or authenticated Hub workflow was tested.

The committed dependency lock was unchanged. The stable SDK verification below
replaces the initial run's dependency-resolution limitation.

### Stable SDK and strict-lock result (2026-09-13)

Flutter **3.47.4 stable** (`9584c6713b324636289d067944a46fd6b49df14b`),
Dart **3.13.3**, and JDK 21 were used for this second build and device run.
`flutter pub get --enforce-lockfile` passed. The committed lock's SHA-256 stayed
`f6c3611874b23077c4d6c4620ec0e74fd8c8e4ec0b40257f0f79a1f87eae8dcb` before
resolution and after the builds; no dependency versions were changed.

Flutter's `DisableBuiltInKotlinMigration` and `DisableNewDslMigration` were
checked in this SDK's `packages/flutter_tools/lib/src/android/migrations/`.
They add disabled built-in Kotlin and new-DSL flags when those properties are
absent. `android/gradle.properties` now records both `false` values explicitly
to keep the existing Kotlin plugin and Android Gradle DSL. Gradle 8.14,
AGP 8.11.1, and Kotlin 2.2.20 are unchanged. A second `--no-pub` APK build left
the tracked file diff byte-for-byte unchanged, confirming the migration does
not recur. The tool reports future-support warnings for those build-tool
versions; no dependency-validation bypass was used.

- Debug APK builds: passed in **163.9 seconds**, then **6.5 seconds**.
- Android test APK, 20 JVM tests, and release/profile manifest generation:
  passed in **21 seconds**; zero JVM failures, errors, or skipped tests.
- The same nine device cases: **9 passed in 37.634 seconds** on the dedicated
  API 36.1 emulator described above. The callback-injection and test-owner
  boundaries remain as described in the verification section.
- Generated manifests again contain the test Activity only in debug.
- Debug APK: 157,297,706 bytes, SHA-256
  `b1b88459dd03ffc039464dfff43ad5e781297ed5905b50a98fa55de1ac3f40ad`.
- Instrumentation APK: 430,648 bytes, SHA-256
  `ea117777ed8fda948bf62b1a664703fdcd1756afd6a9a9842a734496a390a5a1`.

After verification, the dedicated emulator was stopped and its temporary AVD,
including test fixtures, was removed. Other devices were not modified.
