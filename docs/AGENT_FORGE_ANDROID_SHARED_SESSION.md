# Forge Android shared-session storage boundary

The Android instrumentation case
`ForgeCredentialStorageInstrumentedTest` exercises the actual
`flutter_secure_storage` Android backend used by `ForgeCredentialStore`. It
writes a Forge-shaped versioned credential record, creates a second native
storage instance, restores the record, and deletes it. The test uses a unique
`storageNamespace` so it cannot read or remove an operator's normal Forge
credential slot.

`ForgeMainActivityLifecycleInstrumentedTest` additionally starts the real
`MainActivity` and Flutter engine with the named debug entrypoint
`forgeAndroidInstrumentationMain`. The production `ForgeSessionsGate` restores
the default Forge credential record from Android secure storage, then the real
`ForgeSessionsScreen` reads a bounded Conversation/Prompt fixture. The test
recreates the Activity and proves a second authenticated Conversation read
occurs after the lifecycle transition. The fixture is read-only and contains
no device or execution route.

The storage case remains deliberately a storage boundary test. It does not
start `MainActivity` or a Flutter engine. The Activity case does not contact
Snaplink or Forge Hub: its bounded client fixture validates the authenticated
shared-session client path and lifecycle re-entry without an external server,
append a Prompt, call a device route, or create a Run intent. The Dart
host-side lifecycle test remains the evidence for real coordinator API calls,
idempotent Prompt replay, and change-feed visibility.

## Build and run

Builds and JVM tests do not require an emulator:

```sh
flutter build apk --debug --no-pub
android/gradlew -p android :app:assembleDebugAndroidTest :app:testDebugUnitTest --console=plain
```

The explicit runner executes both Android cases and is a successful skip when
no emulator is supplied. This keeps host-only development and CI build checks
independent of ADB:

```sh
python3 android/tests/run_forge_shared_session_instrumentation.py
# SKIP: ... explicit disposable emulator ...
```

For a real Activity lifecycle assertion, pass only a disposable emulator
serial. The
runner never discovers, starts, resets, or stops an emulator and rejects
non-`emulator-N` serials:

```sh
python3 android/tests/run_forge_shared_session_instrumentation.py \
  --serial emulator-5554
```

An explicitly requested but unavailable emulator is an error, while an omitted
serial is the intentional skip path. No physical-device result is claimed by
the host-side or build-only checks.

## Opt-in Coordinator journey

The same runner has a separate real-network mode for a disposable emulator.
It requires a private JSON input file containing the Coordinator origin, one
owner Conversation, the current aggregate version and change cursor, a Prompt,
an idempotency key, the access token, a `client_instance_id`, and strict
display-only `session_view`/`resource_view` observations. The selected instance
must be a mobile row containing that Conversation in both views; missing,
hidden, owner-drifted, or instance-drifted observations fail before the
activity can issue a Prompt request. The runner pushes that file into the
debug app sandbox and passes only its filename to instrumentation; the token
is never an `am instrument` argument:

```sh
umask 077
cat > /tmp/forge-android-coordinator.json <<'JSON'
{
  "api_url": "http://10.0.2.2:8080",
  "access_token": "<short-lived Snaplink JWT>",
  "conversation_id": "conversation-001",
  "client_instance_id": "client-mobile-001",
  "session_view": { "...": "strict forge.client-instance-session-view/v1 observation" },
  "resource_view": { "...": "strict forge.client-instance-resource-view/v1 observation" },
  "expected_version": 4,
  "after_cursor": 19,
  "prompt": "Prompt from Android Coordinator journey",
  "idempotency_key": "android-coordinator-journey-001"
}
JSON
chmod 600 /tmp/forge-android-coordinator.json
python3 android/tests/run_forge_shared_session_instrumentation.py \
  --serial emulator-5554 \
  --coordinator-input /tmp/forge-android-coordinator.json
rm -f /tmp/forge-android-coordinator.json
```

The Coordinator must already be reachable from the emulator (the Android
emulator commonly reaches the host through `10.0.2.2`). The journey restores
the credential through Android secure storage, validates the converged
client-instance observations before the authenticated Conversation/change-
feed/Prompt reads, performs idempotent Prompt replay, persists the owner-local
cursor, then recreates `MainActivity` and repeats the probe with the same key.
It asserts that every recorded request stays on the Conversation, Prompt,
change-feed, or read-only client-instance view paths. It does not register a
client, mutate inventory, select or reserve a device, schedule, dispatch,
execute, or publish a receipt.

The runner also rejects duplicate JSON keys and keeps the expected aggregate
version and owner cursor within the Forge JSON-safe integer ceiling. An
explicitly requested emulator or Coordinator failure is an error. Omitting
`--serial` still skips the ordinary fixture instrumentation; supplying
`--coordinator-input` without a serial is rejected. This is real Android
emulator evidence only when the opt-in command completes; it does not claim an
iOS run or physical-device behavior.

## Metadata-only Runner admission contract

`android/tests/run_forge_admission_contract.py` is the native admission
evidence that can run on Linux without ADB. It consumes the strict shared
session/resource and dispatch/transport admission fixtures, accepts a target
only when it matches an owner-bound `device_id` or `runner_instance_id`, and
rejects owner drift, foreign targets, and any non-false authority flag. Its
trace allowlist contains only the two resource observations and the two
metadata preview endpoints. A direct Runner dispatch path is rejected.

The harness never starts an emulator, opens HTTP, sends a payload, reserves a
device, or connects to a Runner. It is safe as the default native contract
check; the existing explicit emulator Coordinator journey remains the only
Android network/instrumentation path.
