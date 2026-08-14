#!/usr/bin/env python3
"""Directory fan-out gate: no directory may hold more than the configured
number of subdirectories.

Direct port from snaplink's checks/directory_fanout.py.
Max subdirs and exempt dirs live in engineering.yaml.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from checks.config import get_config

_df = get_config().directory_fanout
MAX_SUBDIRS = _df.max_subdirs
EXEMPT_DIRS = set(_df.exempt_dirs)


def _is_exempt(rel: str) -> bool:
    """True if a directory is exempt: a single path component anywhere in
    the path (legacy semantics) or a multi-segment exempt dir matched as a
    path prefix (e.g. `docs/auto` for pi-batch run outputs)."""
    if any(part in EXEMPT_DIRS for part in Path(rel).parts):
        return True
    return any(rel == e or rel.startswith(e.rstrip("/") + "/") for e in EXEMPT_DIRS)


def check(root: Path = None) -> list[str]:
    root = root or Path.cwd()
    violations = []
    for dirpath in sorted(root.rglob("*")):
        if not dirpath.is_dir():
            continue
        rel = str(dirpath.relative_to(root))
        if _is_exempt(rel):
            continue
        if rel.startswith("."):
            continue
        subdirs = [d for d in dirpath.iterdir() if d.is_dir() and not d.name.startswith(".")]
        subdir_count = len(subdirs)
        if subdir_count > MAX_SUBDIRS:
            violations.append(f"{rel}/ has {subdir_count} subdirs (max {MAX_SUBDIRS})")
    return violations


def run() -> int:
    violations = check()
    if violations:
        print(f"FAIL: {len(violations)} directory fan-out violation(s)")
        for v in violations:
            print(f"  {v}")
        return 1
    print(f"PASS: directory fan-out (max {MAX_SUBDIRS} subdirs)")
    return 0


if __name__ == "__main__":
    sys.exit(run())
