#!/usr/bin/env python3
"""Coverage gate for Flutter/Dart projects.

Runs `flutter test --coverage` and checks per-package coverage targets.
Coverage targets live in engineering.yaml.
"""
import sys
import subprocess
import json
import re
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from checks.config import get_config

_cfg = get_config()
COVERAGE_TARGETS = _cfg.coverage_targets


def run_flutter_test() -> int:
    """Run flutter test with coverage."""
    print("--- flutter test --coverage ---")
    result = subprocess.run(
        ["flutter", "test", "--coverage"],
        capture_output=True, text=True, check=False,
        cwd=Path.cwd()
    )
    
    for line in result.stdout.split("\n"):
        if line.strip():
            print(f"  {line}")
    
    if result.stderr:
        for line in result.stderr.split("\n"):
            if line.strip():
                print(f"  stderr: {line}")
    
    # Check if lcov.info was generated
    lcov_file = Path.cwd() / "coverage" / "lcov.info"
    if not lcov_file.exists():
        print("  FAIL: coverage data not generated")
        return 1
    
    return result.returncode


def parse_lcov_line_coverage(lcov_file: Path) -> dict[str, float]:
    """Parse lcov.info and return per-directory line coverage percentages."""
    if not lcov_file.exists():
        return {}
    
    content = lcov_file.read_text(encoding="utf-8")
    
    # Parse lcov format
    # SF:<file_path>
    # DA:<line>,<hit_count>
    # end_of_record
    
    file_lines: dict[str, tuple[int, int]] = {}
    current_file = None
    
    for line in content.split("\n"):
        line = line.strip()
        if line.startswith("SF:"):
            current_file = line[3:]
            # Normalize to relative path
            try:
                current_file = str(Path(current_file).relative_to(Path.cwd()))
            except ValueError as exc:
                print(f'coverage: relative path failed: {exc}')
            if current_file not in file_lines:
                file_lines[current_file] = [0, 0]  # [hit, total]
        elif line.startswith("DA:"):
            # DA:<line>,<hit_count>
            if current_file:
                parts = line[3:].split(",")
                if len(parts) == 2:
                    hit_count = int(parts[1])
                    file_lines[current_file][0] += 1 if hit_count > 0 else 0
                    file_lines[current_file][1] += 1
    
    # Aggregate per-file data into the keys used by engineering.yaml.
    #
    # Target keys follow repository-relative paths: "." covers every file in
    # the report, "lib" covers the whole lib tree, and "lib/screens/..."
    # covers a single subtree. Files outside lib/ only contribute to ".".
    dir_stats: dict[str, tuple[int, int]] = {}
    for file_path, (hit, total) in file_lines.items():
        if total == 0:
            continue
        # "." aggregates the whole project (including lib).
        if "." not in dir_stats:
            dir_stats["."] = [0, 0]
        dir_stats["."][0] += hit
        dir_stats["."][1] += total
        if not file_path.startswith("lib/"):
            continue
        # "lib" aggregates the whole lib tree.
        if "lib" not in dir_stats:
            dir_stats["lib"] = [0, 0]
        dir_stats["lib"][0] += hit
        dir_stats["lib"][1] += total
        # "lib/<dir>" aggregates a subtree, e.g. lib/screens/oidc_login.
        lib_rel = file_path[len("lib/"):]
        parts = lib_rel.split("/")
        for depth in range(1, len(parts)):
            sub_key = "lib/" + "/".join(parts[:depth])
            if sub_key not in dir_stats:
                dir_stats[sub_key] = [0, 0]
            dir_stats[sub_key][0] += hit
            dir_stats[sub_key][1] += total

    return {
        dir_key: round(hit / total * 100, 1)
        for dir_key, (hit, total) in dir_stats.items()
        if total > 0
    }


def check_coverage_targets(
    coverage: dict[str, float],
    targets: dict[str, float] | None = None,
) -> int:
    """Check per-directory coverage against targets."""
    print("--- coverage targets ---")
    failures = 0

    if targets is None:
        targets = COVERAGE_TARGETS
    for target_key, target_pct in sorted(targets.items()):
        actual = coverage.get(target_key, 0.0)
        status = "PASS" if actual >= target_pct else "FAIL"
        if status == "FAIL":
            failures += 1
        print(f"  {status}: {target_key} = {actual}% (target {target_pct}%)")
    
    return 1 if failures > 0 else 0


def run() -> int:
    ec = run_flutter_test()
    if ec != 0:
        return ec

    lcov_file = Path.cwd() / "coverage" / "lcov.info"
    coverage = parse_lcov_line_coverage(lcov_file)
    
    ec = check_coverage_targets(coverage)
    if ec == 0:
        print("PASS: coverage")
    else:
        print("FAIL: coverage targets not met")
    return ec


if __name__ == "__main__":
    sys.exit(run())
