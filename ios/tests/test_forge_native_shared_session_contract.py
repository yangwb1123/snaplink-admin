"""Host-side regression tests for the Android/iOS native input contract."""

from __future__ import annotations

import copy
import json
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from forge_native_shared_session_contract import validate_session_resource_pair
from forge_native_shared_session_contract import (
    validate_native_admission_paths,
    validate_runner_admission_resource_binding,
)


ROOT = Path(__file__).resolve().parents[2]
FIXTURE = ROOT / "docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json"


class NativeSharedSessionContractTest(unittest.TestCase):
    def setUp(self) -> None:
        value = json.loads(FIXTURE.read_text())
        self.session = value["session_view"]
        self.resource = value["resource_view"]

    def test_mobile_instance_and_conversation_converge(self) -> None:
        validate_session_resource_pair(
            self.session,
            self.resource,
            conversation_id="conversation-002",
            client_instance_id="client-mobile-001",
        )

    def test_hidden_conversation_fails_closed(self) -> None:
        session = copy.deepcopy(self.session)
        selected = next(
            row for row in session["instances"] if row["instance_id"] == "client-mobile-001"
        )
        selected["session_ids"] = []
        with self.assertRaises(ValueError):
            validate_session_resource_pair(
                session,
                self.resource,
                conversation_id="conversation-002",
                client_instance_id="client-mobile-001",
            )

    def test_missing_instance_fails_closed(self) -> None:
        resource = copy.deepcopy(self.resource)
        resource["instances"] = [
            row for row in resource["instances"] if row["instance_id"] != "client-mobile-001"
        ]
        with self.assertRaises(ValueError):
            validate_session_resource_pair(
                self.session,
                resource,
                conversation_id="conversation-002",
                client_instance_id="client-mobile-001",
            )

    def test_owner_and_instance_drift_fail_closed(self) -> None:
        owner_drift = copy.deepcopy(self.resource)
        owner_drift["owner_declaration"]["subject"] = "other-user"
        with self.assertRaises(ValueError):
            validate_session_resource_pair(
                self.session,
                owner_drift,
                conversation_id="conversation-002",
                client_instance_id="client-mobile-001",
            )

        instance_drift = copy.deepcopy(self.resource)
        selected = next(
            row for row in instance_drift["instances"] if row["instance_id"] == "client-mobile-001"
        )
        selected["observed_at_ms"] += 1
        with self.assertRaises(ValueError):
            validate_session_resource_pair(
                self.session,
                instance_drift,
                conversation_id="conversation-002",
                client_instance_id="client-mobile-001",
            )

    def test_unsupported_instance_status_fails_closed(self) -> None:
        session = copy.deepcopy(self.session)
        selected = next(
            row for row in session["instances"] if row["instance_id"] == "client-mobile-001"
        )
        selected["status"] = "running"
        with self.assertRaises(ValueError):
            validate_session_resource_pair(
                session,
                self.resource,
                conversation_id="conversation-002",
                client_instance_id="client-mobile-001",
            )


class NativeAdmissionEvidenceContractTest(unittest.TestCase):
    def setUp(self) -> None:
        self.resource = json.loads(
            (ROOT / "docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json").read_text()
        )["resource_view"]
        self.dispatch = json.loads(
            (ROOT / "docs/contracts/fixtures/forge-runner-dispatch-admission-v1.json").read_text()
        )
        self.transport = json.loads(
            (ROOT / "docs/contracts/fixtures/forge-runner-transport-admission-v1.json").read_text()
        )

    def test_dispatch_target_is_bound_to_device_or_runner_resource(self) -> None:
        validate_runner_admission_resource_binding(
            self.dispatch,
            self.resource,
            kind="dispatch",
        )
        device_target = copy.deepcopy(self.dispatch)
        device_target["target_id"] = "device-a"
        validate_runner_admission_resource_binding(
            device_target,
            self.resource,
            kind="dispatch",
        )

    def test_transport_target_is_bound_without_opening_runner_transport(self) -> None:
        candidate = copy.deepcopy(self.transport)
        candidate["target_id"] = "runner-a"
        candidate["transport_path"] = "/api/v1/runners/runner-a/dispatch"
        validate_runner_admission_resource_binding(
            candidate,
            self.resource,
            kind="transport",
        )

    def test_foreign_owner_target_and_authority_fail_closed(self) -> None:
        foreign_target = copy.deepcopy(self.dispatch)
        foreign_target["target_id"] = "runner-foreign"
        with self.assertRaises(ValueError):
            validate_runner_admission_resource_binding(
                foreign_target,
                self.resource,
                kind="dispatch",
            )

        owner_drift = copy.deepcopy(self.dispatch)
        owner_drift["owner"]["subject"] = "other-user"
        with self.assertRaises(ValueError):
            validate_runner_admission_resource_binding(
                owner_drift,
                self.resource,
                kind="dispatch",
            )

        authority_drift = copy.deepcopy(self.dispatch)
        authority_drift["authority"]["dispatch_performed"] = True
        with self.assertRaises(ValueError):
            validate_runner_admission_resource_binding(
                authority_drift,
                self.resource,
                kind="dispatch",
            )

        path_drift = copy.deepcopy(self.transport)
        path_drift["target_id"] = "runner-a"
        with self.assertRaises(ValueError):
            validate_runner_admission_resource_binding(
                path_drift,
                self.resource,
                kind="transport",
            )

    def test_native_trace_allows_only_observation_and_preview_paths(self) -> None:
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
        with self.assertRaises(ValueError):
            validate_native_admission_paths(
                [{"method": "POST", "path": "/api/v1/runners/runner-a/dispatch"}],
                conversation_id="conversation-1",
                run_id="run-1",
            )
        with self.assertRaises(ValueError):
            validate_native_admission_paths(
                [
                    {
                        "method": "GET",
                        "path": "/api/v1/conversations/conversation-1/runs/run-1/runner-dispatch-admission/preview",
                    }
                ],
                conversation_id="conversation-1",
                run_id="run-1",
            )


if __name__ == "__main__":
    unittest.main()
