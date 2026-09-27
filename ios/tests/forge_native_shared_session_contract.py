"""Strict display-only client-instance/session/resource acceptance contract.

This module is shared by the Linux-side iOS input validator and the Android
instrumentation runner.  It deliberately validates observations only.  The
pair carries no registration, inventory mutation, reservation, dispatch, or
execution authority.
"""

from __future__ import annotations

import json
import re
from typing import Any, NoReturn


MAX_SAFE_INTEGER = 9_007_199_254_740_991
IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:+/-]{0,127}$")
CLIENT_KINDS = {"cli", "tui", "web", "app", "mobile"}
INSTANCE_STATUSES = {"active", "idle", "offline", "unknown"}
ADMISSION_KINDS = {"dispatch", "transport"}
AUTHORITY_KEYS = {
    "owner_authenticated",
    "session_read_authorized",
    "prompt_write_authorized",
    "device_identity_verified",
    "reservation_created",
    "execution_authorized",
    "dispatch_performed",
    "audit_published",
}
SESSION_VIEW_KEYS = {
    "schema_version",
    "evaluation_mode",
    "owner_declaration",
    "owner_declaration_unverified",
    "instances",
    "read_only",
    "authority",
}
RESOURCE_VIEW_KEYS = SESSION_VIEW_KEYS | {
    "devices",
    "device_attributes_unverified",
}
INSTANCE_KEYS = {
    "instance_id",
    "client_kind",
    "session_ids",
    "observed_at_ms",
    "status",
}
DEVICE_KEYS = {
    "device_id",
    "runner_instance_id",
    "owner",
    "revision",
    "generation",
    "heartbeat_sequence",
    "observed_at_ms",
    "approval_state",
    "cordon_state",
    "reservation_state",
    "liveness",
    "os",
    "architecture",
    "cpu_cores",
    "available_cpu_cores",
    "memory_bytes",
    "available_memory_bytes",
    "storage_bytes",
    "available_storage_bytes",
    "gpu_count",
    "available_gpu_memory_bytes",
}


def fail(message: str) -> NoReturn:
    raise ValueError(message)


def _object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(f"{label} must be an object")
    return value


def _exact(value: dict[str, Any], expected: set[str], label: str) -> None:
    if set(value) != expected:
        fail(f"{label} must contain exactly the documented fields")


def _text(value: Any, label: str, maximum: int = 512) -> str:
    if not isinstance(value, str) or not value or len(value.encode()) > maximum:
        fail(f"{label} must be a bounded non-empty string")
    if any(ord(char) < 0x20 or ord(char) == 0x7F for char in value):
        fail(f"{label} contains a control character")
    return value


def _identifier(value: Any, label: str) -> str:
    result = _text(value, label, 128)
    if not IDENTIFIER_PATTERN.fullmatch(result):
        fail(f"{label} must be a path-safe identifier")
    return result


def _integer(value: Any, label: str, *, positive: bool = False) -> int:
    if isinstance(value, bool) or not isinstance(value, int):
        fail(f"{label} must be an integer")
    minimum = 1 if positive else 0
    if value < minimum or value > MAX_SAFE_INTEGER:
        fail(f"{label} is outside the safe Forge integer range")
    return value


def _owner(value: Any, label: str) -> dict[str, str]:
    owner = _object(value, label)
    _exact(owner, {"issuer", "subject", "tenant_id"}, label)
    return {
        key: _text(owner[key], f"{label}.{key}")
        for key in ("issuer", "subject", "tenant_id")
    }


def _authority(value: Any, label: str) -> None:
    authority = _object(value, label)
    _exact(authority, AUTHORITY_KEYS, label)
    if any(value is not False for value in authority.values()):
        fail(f"{label} must remain entirely false")


def _all_false_authority(
    value: Any,
    expected: set[str],
    label: str,
) -> None:
    authority = _object(value, label)
    _exact(authority, expected, label)
    if any(item is not False for item in authority.values()):
        fail(f"{label} must remain entirely false")


def _instance(value: Any, label: str) -> dict[str, Any]:
    instance = _object(value, label)
    _exact(instance, INSTANCE_KEYS, label)
    instance_id = _identifier(instance["instance_id"], f"{label}.instance_id")
    client_kind = _text(instance["client_kind"], f"{label}.client_kind", 32)
    if client_kind not in CLIENT_KINDS:
        fail(f"{label}.client_kind is unsupported")
    raw_sessions = instance["session_ids"]
    if not isinstance(raw_sessions, list) or len(raw_sessions) > 128:
        fail(f"{label}.session_ids must be a bounded array")
    sessions = [_identifier(item, f"{label}.session_ids") for item in raw_sessions]
    if sessions != sorted(set(sessions)):
        fail(f"{label}.session_ids must be sorted and unique")
    status = _text(instance["status"], f"{label}.status", 32)
    if status not in INSTANCE_STATUSES:
        fail(f"{label}.status is unsupported")
    return {
        "instance_id": instance_id,
        "client_kind": client_kind,
        "session_ids": sessions,
        "observed_at_ms": _integer(instance["observed_at_ms"], f"{label}.observed_at_ms", positive=True),
        "status": status,
    }


def _view(value: Any, *, resource: bool, label: str) -> tuple[dict[str, str], list[dict[str, Any]]]:
    view = _object(value, label)
    _exact(view, RESOURCE_VIEW_KEYS if resource else SESSION_VIEW_KEYS, label)
    schema = "forge.client-instance-resource-view/v1" if resource else "forge.client-instance-session-view/v1"
    mode = "owner_bound_instance_resource_view_only" if resource else "owner_bound_session_view_only"
    if view["schema_version"] != schema or view["evaluation_mode"] != mode:
        fail(f"{label} schema or evaluation mode is invalid")
    if view["owner_declaration_unverified"] is not True or view["read_only"] is not True:
        fail(f"{label} must be unverified and read-only")
    _authority(view["authority"], f"{label}.authority")
    owner = _owner(view["owner_declaration"], f"{label}.owner_declaration")
    raw_instances = view["instances"]
    if not isinstance(raw_instances, list) or len(raw_instances) > 128:
        fail(f"{label}.instances must be a bounded array")
    instances = [_instance(item, f"{label}.instances[{index}]") for index, item in enumerate(raw_instances)]
    ids = [item["instance_id"] for item in instances]
    if ids != sorted(set(ids)):
        fail(f"{label}.instances must be sorted and unique")
    if resource:
        if view["device_attributes_unverified"] is not True:
            fail(f"{label}.device_attributes_unverified must be true")
        _devices(view["devices"], owner, f"{label}.devices")
    return owner, instances


def _devices(value: Any, owner: dict[str, str], label: str) -> None:
    if not isinstance(value, list) or len(value) > 128:
        fail(f"{label} must be a bounded array")
    keys: list[tuple[str, str]] = []
    for index, raw in enumerate(value):
        device = _object(raw, f"{label}[{index}]")
        _exact(device, DEVICE_KEYS, f"{label}[{index}]")
        device_owner = _owner(device["owner"], f"{label}[{index}].owner")
        if device_owner != owner:
            fail(f"{label}[{index}] owner drifted from its resource view")
        device_id = _identifier(device["device_id"], f"{label}[{index}].device_id")
        runner_id = _identifier(device["runner_instance_id"], f"{label}[{index}].runner_instance_id")
        for field in ("revision", "generation", "heartbeat_sequence", "observed_at_ms"):
            _integer(device[field], f"{label}[{index}].{field}", positive=True)
        for field in (
            "cpu_cores",
            "available_cpu_cores",
            "memory_bytes",
            "available_memory_bytes",
            "storage_bytes",
            "available_storage_bytes",
            "gpu_count",
            "available_gpu_memory_bytes",
        ):
            _integer(device[field], f"{label}[{index}].{field}")
        if device["available_cpu_cores"] > device["cpu_cores"]:
            fail(f"{label}[{index}] CPU capacity is inconsistent")
        if device["available_memory_bytes"] > device["memory_bytes"]:
            fail(f"{label}[{index}] memory capacity is inconsistent")
        if device["available_storage_bytes"] > device["storage_bytes"]:
            fail(f"{label}[{index}] storage capacity is inconsistent")
        if device["approval_state"] not in {"approved", "pending", "revoked", "unknown"}:
            fail(f"{label}[{index}].approval_state is invalid")
        if device["cordon_state"] not in {"clear", "cordoned", "unknown"}:
            fail(f"{label}[{index}].cordon_state is invalid")
        if device["reservation_state"] not in {"none", "reserved", "unknown"}:
            fail(f"{label}[{index}].reservation_state is invalid")
        if device["liveness"] not in {"online", "offline", "unknown"}:
            fail(f"{label}[{index}].liveness is invalid")
        _text(device["os"], f"{label}[{index}].os", 128)
        _text(device["architecture"], f"{label}[{index}].architecture", 128)
        keys.append((device_id, runner_id))
    if keys != sorted(set(keys)):
        fail(f"{label} must be sorted and unique")


def validate_session_resource_pair(
    session_view: Any,
    resource_view: Any,
    *,
    conversation_id: Any,
    client_instance_id: Any,
) -> None:
    """Validate two display-only observations and their selected instance.

    The selected instance and Conversation must be visible in both views.  A
    missing or hidden row, owner mismatch, or any instance image drift rejects
    the complete pair before a native acceptance journey can use it.
    """

    conversation = _identifier(conversation_id, "conversation_id")
    selected_id = _identifier(client_instance_id, "client_instance_id")
    session_owner, session_instances = _view(session_view, resource=False, label="session_view")
    resource_owner, resource_instances = _view(resource_view, resource=True, label="resource_view")
    if session_owner != resource_owner:
        fail("session/resource owner declaration drifted")
    if session_instances != resource_instances:
        fail("session/resource instance image drifted")
    selected = [item for item in session_instances if item["instance_id"] == selected_id]
    if not selected:
        fail("client_instance_id is missing from the converged views")
    if selected[0]["client_kind"] != "mobile":
        fail("client_instance_id is not a mobile instance")
    if conversation not in selected[0]["session_ids"]:
        fail("conversation_id is hidden from the selected client instance")


def validate_runner_admission_resource_binding(
    admission: Any,
    resource_view: Any,
    *,
    kind: str,
) -> None:
    """Validate a native metadata-only admission candidate against resources.

    This is deliberately a local observation check.  It does not authenticate
    the candidate, reserve a device, open a Runner connection, or inspect a
    transport payload.  A target is displayable only when its owner matches
    the read-only resource owner and it names either a device or its Runner
    instance row.
    """

    if kind not in ADMISSION_KINDS:
        fail("admission kind is unsupported")
    value = _object(admission, "admission")
    expected_keys = {
        "schema_version",
        "evaluation_mode",
        "owner",
        "conversation_id",
        "run_id",
        "attempt_id",
        "attempt_state",
        "attempt_state_admissible",
        "command_id",
        "command_sha256",
        "target_id",
        "lease_epoch",
        "lease_issued_at_ms",
        "lease_expires_at_ms",
        "evaluated_at_ms",
        "lease_proof_current",
        "lease_active",
        "command_binding_valid",
        "admission_ready",
        "rejection_reasons",
        "preview_only",
        "authority",
    }
    if kind == "transport":
        expected_keys |= {
            "transport_method",
            "transport_path",
            "transport_timestamp",
            "transport_nonce",
            "transport_payload_sha256",
            "transport_payload_bytes",
            "transport_replay_checked",
            "transport_binding_valid",
        }
    _exact(value, expected_keys, "admission")
    expected_schema = f"forge.runner-{kind}-admission/v1"
    expected_mode = (
        "durable_lease_bound_dispatch_admission_preview"
        if kind == "dispatch"
        else "fenced_runner_transport_admission_preview"
    )
    if value["schema_version"] != expected_schema or value["evaluation_mode"] != expected_mode:
        fail("admission schema or evaluation mode is invalid")
    candidate_owner = _owner(value["owner"], "admission.owner")
    resource_owner, _ = _view(resource_view, resource=True, label="resource_view")
    if candidate_owner != resource_owner:
        fail("admission/resource owner drifted")
    target_id = _identifier(value["target_id"], "admission.target_id")
    for field in ("conversation_id", "run_id", "attempt_id", "command_id"):
        _identifier(value[field], f"admission.{field}")
    if value["attempt_state"] != "accepted":
        fail("admission attempt state is not accepted")
    for field in (
        "attempt_state_admissible",
        "lease_proof_current",
        "lease_active",
        "command_binding_valid",
        "admission_ready",
        "preview_only",
    ):
        if value[field] is not True:
            fail(f"admission.{field} must be true")
    if value["rejection_reasons"] != []:
        fail("admission.rejection_reasons must be empty")
    authority_keys = (
        {
            "device_identity_verified",
            "reservation_created",
            "execution_authorized",
            "dispatch_performed",
            "audit_published",
        }
        if kind == "dispatch"
        else {
            "device_identity_verified",
            "transport_authenticated",
            "reservation_created",
            "execution_authorized",
            "dispatch_performed",
            "audit_published",
        }
    )
    _all_false_authority(value["authority"], authority_keys, "admission.authority")
    for field in (
        "lease_epoch",
        "lease_issued_at_ms",
        "lease_expires_at_ms",
        "evaluated_at_ms",
    ):
        _integer(value[field], f"admission.{field}", positive=True)
    _text(value["command_sha256"], "admission.command_sha256", 128)
    if kind == "transport":
        if value["transport_method"] != "POST":
            fail("transport admission method is invalid")
        transport_path = _text(value["transport_path"], "admission.transport_path", 2048)
        if transport_path != f"/api/v1/runners/{target_id}/dispatch":
            fail("transport admission path drifted from target_id")
        _integer(value["transport_timestamp"], "admission.transport_timestamp")
        _identifier(value["transport_nonce"], "admission.transport_nonce")
        _text(value["transport_payload_sha256"], "admission.transport_payload_sha256", 128)
        _integer(value["transport_payload_bytes"], "admission.transport_payload_bytes")
        if value["transport_replay_checked"] is not True or value["transport_binding_valid"] is not True:
            fail("transport admission binding is not checked")
    targets = {
        _identifier(device["device_id"], "resource_view.devices.device_id")
        for device in _object(resource_view, "resource_view")["devices"]
    }
    targets |= {
        _identifier(device["runner_instance_id"], "resource_view.devices.runner_instance_id")
        for device in _object(resource_view, "resource_view")["devices"]
    }
    if target_id not in targets:
        fail("admission target is absent from the resource image")


def validate_native_admission_paths(
    paths: Any,
    *,
    conversation_id: Any,
    run_id: Any,
) -> None:
    """Allow only observation and preview paths in native evidence.

    The preview endpoints return metadata only.  Direct Runner dispatch,
    payload transport, enrollment, reservation, and execution paths are
    rejected even if a caller tries to include them in a native trace.
    """

    conversation = _identifier(conversation_id, "conversation_id")
    run = _identifier(run_id, "run_id")
    if not isinstance(paths, list) or len(paths) > 32:
        fail("native admission paths must be a bounded array")
    allowed = {
        "/api/v1/client-instances/session-view": "GET",
        "/api/v1/client-instances/resource-view": "GET",
        f"/api/v1/conversations/{conversation}/runs/{run}/runner-dispatch-admission/preview": "POST",
        f"/api/v1/conversations/{conversation}/runs/{run}/runner-transport-admission/preview": "POST",
    }
    for index, raw in enumerate(paths):
        item = _object(raw, f"paths[{index}]")
        _exact(item, {"method", "path"}, f"paths[{index}]")
        if item["path"] not in allowed or item["method"] != allowed[item["path"]]:
            fail(f"paths[{index}] is outside the native metadata-only allowlist")


def reject_duplicate_keys(pairs: list[tuple[object, object]]) -> dict[object, object]:
    value: dict[object, object] = {}
    for key, item in pairs:
        if key in value:
            fail(f"duplicate JSON field: {key!r}")
        value[key] = item
    return value


def parse_json(raw: bytes, *, max_bytes: int = 2 * 1024 * 1024) -> dict[str, Any]:
    if len(raw) > max_bytes:
        fail("input exceeds its bounded length")
    try:
        value = json.loads(raw, object_pairs_hook=reject_duplicate_keys)
    except json.JSONDecodeError as error:
        fail(f"input is not valid JSON: {error.msg}")
    if not isinstance(value, dict):
        fail("input must be an object")
    return value
