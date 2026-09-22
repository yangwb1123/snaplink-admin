#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONSOLE_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
VALIDATOR="$SCRIPT_DIR/validate_forge_ios_shared_session_input.py"

if [[ "${FORGE_IOS_SHARED_SESSION_ACCEPTANCE:-0}" != "1" ]]; then
  echo "SKIP: iOS shared-session acceptance is opt-in (set FORGE_IOS_SHARED_SESSION_ACCEPTANCE=1)."
  exit 0
fi

input_path="${FORGE_IOS_SHARED_SESSION_INPUT:-}"
if [[ -z "$input_path" ]]; then
  echo "FORGE_IOS_SHARED_SESSION_INPUT must point to a private JSON file." >&2
  exit 2
fi
if [[ ! -f "$input_path" || -L "$input_path" ]]; then
  echo "FORGE_IOS_SHARED_SESSION_INPUT must be a regular, non-symlink file." >&2
  exit 2
fi

# Keep the bearer values in the file.  Only the path is passed to the test
# runner, and the validator never echoes the decoded JSON.
python3 "$VALIDATOR" "$input_path"

if [[ "$(uname -s)" != "Darwin" ]] || ! command -v xcodebuild >/dev/null 2>&1; then
  echo "SKIP: iOS XCTest requires macOS with xcodebuild; the input boundary passed."
  exit 0
fi

destination="${FORGE_IOS_DESTINATION:-platform=iOS Simulator,name=iPhone 15}"
cd "$CONSOLE_ROOT"
FORGE_IOS_SHARED_SESSION_ACCEPTANCE=1 \
FORGE_IOS_SHARED_SESSION_INPUT="$input_path" \
xcodebuild \
  -workspace ios/Runner.xcworkspace \
  -scheme Runner \
  -destination "$destination" \
  test \
  -only-testing:RunnerTests/ForgeIOSSharedSessionAcceptanceTests
