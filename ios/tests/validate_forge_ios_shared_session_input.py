#!/usr/bin/env python3
"""Validate the private input boundary for the opt-in iOS acceptance harness.

The bearer values are deliberately validated for shape only and are never
printed.  This validator is runnable on Linux; the Xcode XCTest that consumes
the same file is only available on macOS.
"""

from __future__ import annotations

import json
import os
import re
import stat
import sys
from pathlib import Path
from typing import NoReturn
from urllib.parse import urlparse


EXPECTED_KEYS = {
    "platform",
    "api_url",
    "access_token",
    "rotated_access_token",
    "conversation_id",
    "expected_version",
    "after_cursor",
    "prompt",
    "idempotency_key",
}
PLATFORMS = {"ios-device", "ios-simulator"}
MAX_INPUT_BYTES = 64 * 1024
MAX_TOKEN_BYTES = 16 * 1024
MAX_PROMPT_BYTES = 32 * 1024
MAX_IDENTIFIER_BYTES = 512
MAX_SAFE_INTEGER = 9_007_199_254_740_991
IDENTIFIER_PATTERN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,511}$")


def fail(message: str) -> NoReturn:
    raise ValueError(message)


def non_empty_string(value: object, field: str, maximum: int) -> str:
    if not isinstance(value, str) or not value:
        fail(f"{field} must be a non-empty string")
    if len(value.encode("utf-8")) > maximum:
        fail(f"{field} exceeds its bounded length")
    if any(ord(char) < 0x20 or ord(char) == 0x7F for char in value):
        fail(f"{field} contains a control character")
    return value


def integer(value: object, field: str) -> int:
    # bool is an int subclass in Python; it must not pass this boundary.
    if isinstance(value, bool) or not isinstance(value, int) or value < 0:
        fail(f"{field} must be a non-negative integer")
    return value


def identifier(value: object, field: str) -> str:
    result = non_empty_string(value, field, MAX_IDENTIFIER_BYTES)
    if not IDENTIFIER_PATTERN.fullmatch(result):
        fail(f"{field} must be a path-safe ASCII identifier")
    return result


def validate_api_url(value: object) -> str:
    url = non_empty_string(value, "api_url", 2048)
    parsed = urlparse(url)
    if parsed.scheme == "https":
        pass
    elif parsed.scheme == "http" and parsed.hostname in {
        "localhost",
        "127.0.0.1",
        "::1",
    }:
        pass
    else:
        fail("api_url must use HTTPS or HTTP on a loopback host")
    if parsed.username or parsed.password or parsed.query or parsed.fragment:
        fail("api_url may not contain credentials, query, or fragment")
    if not parsed.netloc or parsed.path not in ("", "/"):
        fail("api_url must be an origin without a path")
    try:
        parsed.port
    except ValueError:
        fail("api_url contains an invalid port")
    return url.rstrip("/")


def validate(path: Path) -> dict[str, object]:
    no_follow = getattr(os, "O_NOFOLLOW", 0)
    if no_follow == 0:
        fail("platform cannot enforce no-follow input reads")
    descriptor = os.open(
        os.fspath(path),
        os.O_RDONLY | no_follow | getattr(os, "O_CLOEXEC", 0),
    )
    try:
        metadata = os.fstat(descriptor)
        if not stat.S_ISREG(metadata.st_mode):
            fail("input must be a regular, non-symlink file")
        if stat.S_IMODE(metadata.st_mode) & 0o077:
            fail("input must not be group/world readable")
        with os.fdopen(descriptor, "rb", closefd=True) as stream:
            descriptor = -1
            raw = stream.read(MAX_INPUT_BYTES + 1)
    finally:
        if descriptor != -1:
            os.close(descriptor)
    if len(raw) > MAX_INPUT_BYTES:
        fail("input exceeds the 64 KiB bound")
    try:
        value = json.loads(raw, object_pairs_hook=_reject_duplicate_keys)
    except json.JSONDecodeError as error:
        fail(f"input is not valid JSON: {error.msg}")
    except ValueError as error:
        fail(f"input is not valid JSON: {error}")
    if not isinstance(value, dict) or set(value) != EXPECTED_KEYS:
        fail("input must contain exactly the shared-session fields")
    if value["platform"] not in PLATFORMS:
        fail("platform must be ios-device or ios-simulator")
    validate_api_url(value["api_url"])
    non_empty_string(value["access_token"], "access_token", MAX_TOKEN_BYTES)
    non_empty_string(value["rotated_access_token"], "rotated_access_token", MAX_TOKEN_BYTES)
    if value["access_token"] == value["rotated_access_token"]:
        fail("rotated_access_token must differ from access_token")
    identifier(value["conversation_id"], "conversation_id")
    non_empty_string(value["prompt"], "prompt", MAX_PROMPT_BYTES)
    identifier(value["idempotency_key"], "idempotency_key")
    expected_version = integer(value["expected_version"], "expected_version")
    after_cursor = integer(value["after_cursor"], "after_cursor")
    if not 1 <= expected_version <= MAX_SAFE_INTEGER:
        fail("expected_version is outside the safe Forge range")
    if after_cursor > MAX_SAFE_INTEGER:
        fail("after_cursor is outside the safe Forge range")
    return value


def _reject_duplicate_keys(pairs: list[tuple[object, object]]) -> dict[object, object]:
    value: dict[object, object] = {}
    for key, item in pairs:
        if key in value:
            raise ValueError(f"duplicate JSON field: {key!r}")
        value[key] = item
    return value


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(f"usage: {argv[0]} INPUT_JSON", file=sys.stderr)
        return 2
    try:
        validate(Path(argv[1]))
    except (OSError, ValueError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1
    print("PASS: iOS Forge shared-session input boundary")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
