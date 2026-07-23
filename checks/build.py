#!/usr/bin/env python3
"""Build gate: verify the Flutter web build compiles successfully.

Build output dir and binary list live in engineering.yaml (`build:` section).
"""
import sys
import subprocess
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from checks.config import get_config

_cfg = get_config()
BUILD = _cfg.build


def run() -> int:
    print("--- flutter build web ---")
    result = subprocess.run(
        ["flutter", "build", "web", "--release"],
        capture_output=True, text=True, check=False,
        cwd=Path.cwd()
    )
    
    for line in result.stdout.split("\n"):
        if line.strip():
            print(f"  {line}")
    
    if result.stderr:
        for line in result.stderr.split("\n"):
            if line.strip():
                print(f"  {line}")
    
    if result.returncode != 0:
        print("FAIL: build")
        return 1
    
    # Verify output exists
    output_dir = Path.cwd() / BUILD.output_dir
    if not output_dir.exists() or not (output_dir / "main.dart.js").exists():
        print(f"  FAIL: expected output not found in {BUILD.output_dir}")
        return 1
    
    print("PASS: build")
    return 0


if __name__ == "__main__":
    sys.exit(run())
