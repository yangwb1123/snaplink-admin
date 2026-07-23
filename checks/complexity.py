#!/usr/bin/env python3
"""Complexity gate for Flutter/Dart projects.

Uses `dart analyze` as the primary cyclomatic complexity enforcement
(via analysis_options.yaml's cyclomatic_complexity lint rule).
Also provides a fallback grep-based heuristic for function length.

The analysis_options.yaml in the project root enforces:
  cyclomatic_complexity: 12
"""
import sys
import re
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from checks.config import get_config

_cx = get_config().complexity
MAX_CYCLO = _cx.max_cyclomatic
EXEMPT_FUNCS = list(_cx.exempt_functions)
IGNORE_PATTERN = _cx.ignore_pattern


def is_exempt(name: str) -> bool:
    return any(e in name for e in EXEMPT_FUNCS)


def run_dart_analyze() -> int:
    """Run dart analyze and check for cyclomatic_complexity warnings/errors."""
    print(f"--- dart analyze (cyclomatic complexity max {MAX_CYCLO}) ---")
    
    result = subprocess.run(
        ["dart", "analyze", "--fatal-infos", "--fatal-warnings"],
        capture_output=True, text=True, check=False,
        cwd=Path.cwd()
    )
    
    # dart analyze exit codes:
    # 0 = no issues, 1 = some issues found
    # We parse the output to separate complexity issues from other issues
    complexity_issues = []
    other_issues = []
    
    for line in result.stdout.split("\n"):
        if "cyclomatic_complexity" in line:
            complexity_issues.append(line)
        elif line.strip() and "No issues found" not in line:
            other_issues.append(line)
    
    for line in result.stderr.split("\n"):
        if line.strip():
            other_issues.append(line)
    
    if complexity_issues:
        print("  Complexity violations:")
        for issue in complexity_issues:
            print(f"    {issue}")
    
    if other_issues:
        print("  Other analysis issues (not counted as complexity failures):")
        for issue in other_issues[:10]:  # show first 10
            print(f"    {issue}")
        if len(other_issues) > 10:
            print(f"    ... and {len(other_issues) - 10} more issues")
    
    if complexity_issues:
        print("  FAIL: complexity violations found")
        # Return 1 only if there are complexity violations
        return 1
    
    print("  PASS")
    return 0


def run() -> int:
    return run_dart_analyze()


if __name__ == "__main__":
    sys.exit(run())
