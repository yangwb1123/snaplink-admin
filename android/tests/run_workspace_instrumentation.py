#!/usr/bin/env python3
"""Run SAF acceptance only on an explicitly named, disposable Android emulator."""

import argparse
from pathlib import Path
import re
import subprocess
import sys


def property_value(adb: list[str], name: str) -> str:
    return subprocess.run(adb + ["shell", "getprop", name], check=True,
                          capture_output=True, text=True, timeout=30).stdout.strip()


def main() -> int:
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", default="adb")
    parser.add_argument("--serial", required=True, help="Disposable emulator serial (emulator-N)")
    parser.add_argument("--app-apk", type=Path,
                        default=root / "build/app/outputs/apk/debug/app-debug.apk")
    parser.add_argument("--test-apk", type=Path,
                        default=root / "build/app/outputs/apk/androidTest/debug/app-debug-androidTest.apk")
    args = parser.parse_args()
    if not re.fullmatch(r"emulator-[0-9]+", args.serial):
        parser.error("Only an explicitly selected disposable emulator is supported")
    for apk in (args.app_apk, args.test_apk):
        if not apk.is_file():
            parser.error(f"Build the debug and androidTest APKs first: missing {apk}")
    adb = [args.adb, "-s", args.serial]
    sdk = property_value(adb, "ro.build.version.sdk")
    if not sdk.isdecimal() or int(sdk) < 29:
        parser.error("The document fixture requires an emulator with API 29 or newer")
    locale = property_value(adb, "persist.sys.locale") or property_value(adb, "ro.product.locale")
    if re.split("[-_]", locale)[0] != "en":
        parser.error(f"DocumentsUI selectors require an English test emulator; got {locale!r}")
    for apk in (args.app_apk, args.test_apk):
        subprocess.run(adb + ["install", "-r", str(apk)], check=True, timeout=120)
    result = subprocess.run(adb + [
        "shell", "am", "instrument", "-w", "-r", "-e", "class",
        "site.ywbsd.sso.sso_admin.workspace.WorkspaceDocumentsInstrumentedTest",
        "site.ywbsd.sso.sso_admin.test/androidx.test.runner.AndroidJUnitRunner",
    ], capture_output=True, text=True, timeout=600)
    print(result.stdout, end="")
    print(result.stderr, end="", file=sys.stderr)
    # Android's am command can exit zero when the instrumentation itself failed.
    return 0 if result.returncode == 0 and re.search(r"^OK \(9 tests\)$", result.stdout, re.M) else 1


if __name__ == "__main__":
    raise SystemExit(main())
