#!/usr/bin/env python3
"""Gate: forbid business code files in lib/ root directory.

Adapted from snaplink's checks/root_business_code.py for Flutter projects.
lib/ root should only contain composition files (main.dart, app_router.dart),
not business logic. Business logic MUST be in sub-packages (screens/, api/, etc.).
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from checks.config import get_config

_rp = get_config().root_policy
BANNED_PATTERNS = list(_rp.banned_patterns)
BANNED_FILES = list(_rp.banned_files)
EXEMPT = set(_rp.exempt_files)
ALLOWED_PREFIXES = tuple(_rp.allowed_prefixes)
ALLOWED_FILES = set(_rp.allowed_files)


def _allowed_by_prefix(name: str) -> bool:
    return name.endswith(".dart") and name.startswith(ALLOWED_PREFIXES)


def run() -> int:
    root = Path.cwd() / "lib"
    if not root.exists():
        print("PASS: no lib/ directory (not a Dart project?)")
        return 0

    violations = []

    # Check banned file patterns (glob patterns)
    for pattern in BANNED_PATTERNS:
        for f in root.glob(pattern):
            if not f.is_file():
                continue
            if f.name in EXEMPT or _allowed_by_prefix(f.name) or f.name in ALLOWED_FILES:
                continue
            violations.append(f"  {f.name} matches pattern {pattern}")

    # Check specific banned filenames
    for filename in BANNED_FILES:
        f = root / filename
        if f.is_file() and filename not in EXEMPT and not _allowed_by_prefix(filename):
            violations.append(f"  {filename} is business logic in lib/ root")

    # Check total files in lib/ root
    root_files = [f for f in root.iterdir() if f.is_file() and f.suffix == ".dart"]
    max_files = _rp.max_files
    actual_dart = [f for f in root_files if not _allowed_by_prefix(f.name) and f.name not in EXEMPT]
    if len(root_files) > max_files:
        violations.append(
            f"  lib/ has {len(root_files)} .dart files (max {max_files})"
        )

    if violations:
        print(f"FAIL: {len(violations)} policy violation(s) in lib/")
        print("\n".join(sorted(set(violations))))
        print("\n" + "=" * 70)
        print("lib/ Root Directory Policy Violation")
        print("=" * 70)
        print("\nlib/ root should only contain app composition files:")
        print("  - main.dart")
        print("  - app_router.dart")
        print("  - app_settings.dart")
        print("\nBusiness logic MUST be in sub-packages:")
        print("  - lib/screens/       → UI screens and their logic")
        print("  - lib/api/           → API clients")
        print("  - lib/widgets/       → Shared widgets")
        print("  - lib/i18n/         → Internationalization")
        print("  - lib/models/       → Data models")
        return 1

    print("PASS: no business code in lib/ root")
    return 0


if __name__ == "__main__":
    sys.exit(run())
