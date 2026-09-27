#!/usr/bin/env python3
"""Run the Android/iOS metadata-only Runner admission contract.

This host-side harness is intentionally independent of ADB, an emulator, an
Xcode runner, HTTP, and any Runner connection.  It validates the same strict
resource target boundary used by the native acceptance inputs and exercises
both preview response shapes with a synthetic, local trace only.
"""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys


CONSOLE_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(CONSOLE_ROOT / "ios" / "tests"))
from forge_native_shared_session_contract import (  # noqa: E402
    validate_native_admission_paths,
    validate_runner_admission_resource_binding,
)


def read_fixture(name: str) -> dict[str, object]:
    path = CONSOLE_ROOT / "docs" / "contracts" / "fixtures" / name
    return json.loads(path.read_text())


def main() -> int:
    resource = read_fixture(
        "forge-client-instance-session-resource-convergence-v1.json"
    )["resource_view"]
    dispatch = read_fixture("forge-runner-dispatch-admission-v1.json")
    transport = read_fixture("forge-runner-transport-admission-v1.json")
    validate_runner_admission_resource_binding(
        dispatch, resource, kind="dispatch"
    )
    transport = copy.deepcopy(transport)
    transport["target_id"] = "runner-a"
    transport["transport_path"] = "/api/v1/runners/runner-a/dispatch"
    validate_runner_admission_resource_binding(
        transport, resource, kind="transport"
    )
    validate_native_admission_paths(
        [
            {"method": "GET", "path": "/api/v1/client-instances/session-view"},
            {"method": "GET", "path": "/api/v1/client-instances/resource-view"},
            {
                "method": "POST",
                "path": "/api/v1/conversations/conversation-1/runs/run-1/runner-dispatch-admission/preview",
            },
            {
                "method": "POST",
                "path": "/api/v1/conversations/conversation-1/runs/run-1/runner-transport-admission/preview",
            },
        ],
        conversation_id="conversation-1",
        run_id="run-1",
    )
    try:
        invalid = copy.deepcopy(dispatch)
        invalid["target_id"] = "runner-foreign"
        validate_runner_admission_resource_binding(
            invalid, resource, kind="dispatch"
        )
    except ValueError:
        pass
    else:
        raise AssertionError("foreign native admission target was accepted")
    try:
        validate_native_admission_paths(
            [{"method": "POST", "path": "/api/v1/runners/runner-a/dispatch"}],
            conversation_id="conversation-1",
            run_id="run-1",
        )
    except ValueError:
        pass
    else:
        raise AssertionError("live Runner dispatch path entered native evidence")
    print("PASS: native Android/iOS metadata-only Runner admission contract")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
