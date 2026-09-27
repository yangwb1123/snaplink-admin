#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONSOLE_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
cd "$CONSOLE_ROOT"

# This is a host-only contract run.  It never starts xcodebuild, an iOS
# simulator, HTTP, or a Runner connection; the opt-in native XCTest remains a
# separate future platform exercise.
PYTHONPATH="$SCRIPT_DIR" python3 -m unittest \
  test_forge_native_shared_session_contract.NativeAdmissionEvidenceContractTest
