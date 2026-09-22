#!/usr/bin/env python3
"""Run the Android Forge storage and Activity lifecycle tests, or skip without a device.

The runner never discovers or starts an emulator implicitly. A real
instrumentation run requires an explicitly supplied disposable ``emulator-N``
serial; omitting ``--serial`` is an intentional, successful skip for host-only
and CI build checks.
"""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


FIXTURE_TEST_CLASS = ",".join(
    (
        "site.ywbsd.sso.sso_admin.forge.ForgeCredentialStorageInstrumentedTest",
        "site.ywbsd.sso.sso_admin.forge.ForgeMainActivityLifecycleInstrumentedTest",
    )
)
COORDINATOR_TEST_CLASS = "site.ywbsd.sso.sso_admin.forge.ForgeCoordinatorInstrumentationTest"
TEST_RUNNER = "site.ywbsd.sso.sso_admin.test/androidx.test.runner.AndroidJUnitRunner"
APP_PACKAGE = "site.ywbsd.sso.sso_admin"


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument(
        "--serial",
        help="Explicit disposable emulator serial (emulator-N); omit to skip",
    )
    parser.add_argument(
        "--app-apk",
        type=Path,
        default=root / "build/app/outputs/apk/debug/app-debug.apk",
    )
    parser.add_argument(
        "--test-apk",
        type=Path,
        default=root / "build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk",
    )
    parser.add_argument(
        "--coordinator-input",
        type=Path,
        help=(
            "Private JSON input for the opt-in Coordinator journey. Requires "
            "--serial; the bearer is copied into the app sandbox and is not "
            "passed as an instrumentation argument."
        ),
    )
    args = parser.parse_args()

    if args.serial is None:
        if args.coordinator_input is not None:
            parser.error("--coordinator-input requires an explicit --serial")
        print(
            "SKIP: Forge Android instrumentation needs an explicit disposable "
            "emulator; build/JVM and host-side shared-session checks remain valid."
        )
        return 0
    if not re.fullmatch(r"emulator-[0-9]+", args.serial):
        parser.error("Only an explicitly selected disposable emulator is supported")
    if shutil.which(args.adb) is None:
        print(
            f"ERROR: requested instrumentation uses {args.adb!r}, but adb is not installed.",
            file=sys.stderr,
        )
        return 1
    for apk in (args.app_apk, args.test_apk):
        if not apk.is_file():
            parser.error(f"Build the debug and androidTest APKs first: missing {apk}")

    if args.coordinator_input is not None:
        validate_coordinator_input(args.coordinator_input, parser)

    adb = [args.adb, "-s", args.serial]
    state = subprocess.run(adb + ["get-state"], capture_output=True, text=True)
    if state.returncode != 0 or state.stdout.strip() != "device":
        print(
            f"ERROR: requested emulator {args.serial!r} is not available; "
            "an explicit run must not silently pass.",
            file=sys.stderr,
        )
        return 1

    for apk in (args.app_apk, args.test_apk):
        subprocess.run(adb + ["install", "-r", str(apk)], check=True, timeout=120)
    coordinator_name = None
    try:
        test_class = FIXTURE_TEST_CLASS
        expected_test_count = 2
        extra = []
        if args.coordinator_input is not None:
            coordinator_name = f"forge-coordinator-input-{os.getpid()}.json"
            subprocess.run(
                adb + ["push", str(args.coordinator_input), f"/data/local/tmp/{coordinator_name}"],
                check=True,
                timeout=60,
                stdout=subprocess.DEVNULL,
            )
            subprocess.run(
                adb + [
                    "shell", "run-as", APP_PACKAGE, "cp",
                    f"/data/local/tmp/{coordinator_name}", f"files/{coordinator_name}",
                ],
                check=True,
                timeout=60,
                stdout=subprocess.DEVNULL,
            )
            subprocess.run(
                adb + ["shell", "run-as", APP_PACKAGE, "chmod", "600", f"files/{coordinator_name}"],
                check=True,
                timeout=60,
                stdout=subprocess.DEVNULL,
            )
            test_class = f"{FIXTURE_TEST_CLASS},{COORDINATOR_TEST_CLASS}"
            expected_test_count = 3
            extra = ["-e", "forge_coordinator_config", coordinator_name]

        result = subprocess.run(
            adb
            + [
                "shell",
                "am",
                "instrument",
                "-w",
                "-r",
                "-e",
                "class",
                test_class,
                *extra,
                TEST_RUNNER,
            ],
            capture_output=True,
            text=True,
            timeout=900 if args.coordinator_input is not None else 300,
        )
    finally:
        if coordinator_name is not None:
            subprocess.run(
                adb + ["shell", "run-as", APP_PACKAGE, "rm", "-f", f"files/{coordinator_name}"],
                check=False,
                timeout=30,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
            subprocess.run(
                adb + ["shell", "rm", "-f", f"/data/local/tmp/{coordinator_name}"],
                check=False,
                timeout=30,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
            )
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)
    return (
        0
        if result.returncode == 0
        and re.search(
            rf"^OK \({expected_test_count} test[s]?\)$",
            result.stdout,
            re.MULTILINE,
        )
        else 1
    )


def validate_coordinator_input(path: Path, parser: argparse.ArgumentParser) -> None:
    if not path.is_file():
        parser.error(f"Coordinator input does not exist: {path}")
    try:
        mode = path.stat().st_mode & 0o777
    except OSError as error:
        parser.error(f"Cannot inspect Coordinator input permissions: {error}")
    if mode & 0o077:
        parser.error(
            "Coordinator input must be owner-only (chmod 600 or stricter); "
            "it contains a bearer token"
        )
    try:
        value = json.loads(path.read_text(), object_pairs_hook=_reject_duplicate_keys)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        parser.error(f"Coordinator input is not valid JSON: {error}")
    expected = {
        "api_url",
        "access_token",
        "conversation_id",
        "expected_version",
        "after_cursor",
        "prompt",
        "idempotency_key",
    }
    if not isinstance(value, dict) or set(value) != expected:
        parser.error("Coordinator input must contain exactly the documented fields")
    for key in ("api_url", "access_token", "conversation_id", "prompt", "idempotency_key"):
        if not isinstance(value[key], str) or not value[key] or any(char in value[key] for char in "\r\n\x00"):
            parser.error(f"Coordinator input field {key!r} is invalid")
    for key, minimum in (("expected_version", 1), ("after_cursor", 0)):
        if not isinstance(value[key], int) or isinstance(value[key], bool) or value[key] < minimum or value[key] > 9007199254740991:
            parser.error(f"Coordinator input field {key!r} is invalid")


def _reject_duplicate_keys(pairs: list[tuple[object, object]]) -> dict[object, object]:
    value: dict[object, object] = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f"duplicate JSON field: {key!r}")
        value[key] = item
    return value


if __name__ == "__main__":
    raise SystemExit(main())
