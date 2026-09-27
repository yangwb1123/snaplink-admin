"""Host-only boundary tests for Android's opt-in shared-session runner."""

from __future__ import annotations

import argparse
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
RUNNER_PATH = ROOT / "android/tests/run_forge_shared_session_instrumentation.py"
FIXTURE_PATH = ROOT / "docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json"
SPEC = importlib.util.spec_from_file_location("android_shared_session_runner", RUNNER_PATH)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("cannot load Android shared-session runner")
RUNNER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(RUNNER)


class AndroidSharedSessionInstrumentationInputTest(unittest.TestCase):
    def test_https_and_loopback_origins_are_accepted(self) -> None:
        for origin in ("https://coordinator.example.test", "http://127.0.0.1:7467"):
            self._validate(origin)

    def test_public_http_and_non_origin_urls_are_rejected_before_adb(self) -> None:
        for origin in (
            "http://coordinator.example.test",
            "https://coordinator.example.test/api/v1",
            "https://user:pass@coordinator.example.test",
            "https://coordinator.example.test?token=leak",
        ):
            with self.assertRaises(SystemExit):
                with contextlib.redirect_stderr(io.StringIO()):
                    self._validate(origin)

    def _validate(self, origin: str) -> None:
        fixture = json.loads(FIXTURE_PATH.read_text())
        payload = {
            "api_url": origin,
            "access_token": "bearer-token",
            "conversation_id": "conversation-002",
            "client_instance_id": "client-mobile-001",
            "session_view": fixture["session_view"],
            "resource_view": fixture["resource_view"],
            "expected_version": 1,
            "after_cursor": 0,
            "prompt": "continue shared conversation",
            "idempotency_key": "android-shared-session-input-001",
        }
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "input.json"
            path.write_text(json.dumps(payload))
            os.chmod(path, 0o600)
            RUNNER.validate_coordinator_input(path, argparse.ArgumentParser())


if __name__ == "__main__":
    unittest.main()
