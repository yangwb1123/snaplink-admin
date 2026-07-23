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
            except ValueError:
                pass
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
    
    # Group by directory
    dir_stats: dict[str, tuple[int, int]] = {}
    for file_path, (hit, total) in file_lines.items():
        if total == 0:
            continue
        # Get the directory relative to lib/
        if "lib/" in file_path:
            dir_key = file_path.split("lib/")[1]
            dir_key = "/".join(dir_key.split("/")[:-1]) or "."
        else:
            continue
        
        if dir_key not in dir_stats:
            dir_stats[dir_key] = [0, 0]
        dir_stats[dir_key][0] += hit
        dir_stats[dir_key][1] += total
    
    return {
        dir_key: round(hit / total * 100, 1)
        for dir_key, (hit, total) in dir_stats.items()
        if total > 0
    }


def check_coverage_targets(coverage: dict[str, float]) -> int:
    """Check per-directory coverage against targets."""
    print("--- coverage targets ---")
    failures = 0
    
    for target_key, target_pct in sorted(COVERAGE_TARGETS.items()):
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
