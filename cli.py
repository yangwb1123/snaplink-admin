#!/usr/bin/env python3
"""sso-admin engineering CLI — adapted from snaplink's cli.py for Flutter/Dart.

Usage:
    python cli.py <command> [options]

Commands:
    check                 Quick check (filesize + analyze)
    check-filesize        File size check
    complexity            Dart analyze complexity check
    architecture          Import dependency direction check
    directory-fanout      Directory structure fan-out check
    root-policy           lib/ root business code policy check
    invariants            Security & code quality invariant checks
    coverage              Run flutter test --coverage + check targets
    test                  Run flutter test
    analyze               Run dart analyze
    build                 Run flutter build web
    format                Run dart format --check
    vet                   Run dart analyze (alias)
    help                  Show this message

Gate thresholds are declared in engineering.yaml, not hardcoded here.
"""

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd()

# Ensure checks/ is on the path
sys.path.insert(0, str(ROOT))


def run(*args: str, **kwargs) -> subprocess.CompletedProcess:
    return subprocess.run(list(args), capture_output=False, text=True, check=False, **kwargs)


def _run_check(module_name: str) -> int:
    """Dynamically import a checks/ module and run its run() function."""
    try:
        mod = __import__(f"checks.{module_name}", fromlist=["run"])
        return mod.run()
    except ImportError as e:
        print(f"ERROR: check module 'checks.{module_name}' not found: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"ERROR: check 'checks.{module_name}' failed: {e}", file=sys.stderr)
        return 1


def cmd_check():
    """Quick check: filesize + dart analyze."""
    ec = _run_check("filesize")
    ec += _run_check("complexity")
    return 1 if ec > 0 else 0


def cmd_check_filesize():
    return _run_check("filesize")


def cmd_complexity():
    return _run_check("complexity")


def cmd_architecture():
    return _run_check("architecture")


def cmd_directory_fanout():
    return _run_check("directory_fanout")


def cmd_root_policy():
    return _run_check("root_business_code")


def cmd_invariants():
    return _run_check("invariants")


def cmd_coverage():
    return _run_check("coverage")


def cmd_test():
    print("--- flutter test ---")
    result = run("flutter", "test")
    if result.returncode != 0:
        print("FAIL: tests")
        return 1
    print("PASS: tests")
    return 0


def cmd_analyze():
    """Run dart analyze with fatal warnings."""
    print("--- dart analyze ---")
    result = run("dart", "analyze", "--fatal-infos", "--fatal-warnings")
    if result.returncode != 0:
        print("FAIL: analyze")
        return 1
    print("PASS: analyze")
    return 0


def cmd_build():
    return _run_check("build")


def cmd_format():
    """Check dart format."""
    print("--- dart format --check ---")
    result = run(
        "dart",
        "format",
        "--output=none",
        "--set-exit-if-changed",
        ".",
    )
    if result.returncode != 0:
        print("FAIL: formatting issues found")
        return 1
    print("PASS: formatting")
    return 0


def cmd_vet():
    """Alias for analyze."""
    return cmd_analyze()


def cmd_harness():
    """Full engineering gates suite."""
    ec = cmd_check_filesize()
    ec += cmd_complexity()
    ec += cmd_architecture()
    ec += cmd_directory_fanout()
    ec += cmd_root_policy()
    ec += cmd_invariants()
    ec += _run_check("b6_1b_gates")
    return 1 if ec > 0 else 0


def cmd_help():
    print(__doc__.strip())
    return 0


COMMANDS = {
    "check": cmd_check,
    "check-filesize": cmd_check_filesize,
    "complexity": cmd_complexity,
    "architecture": cmd_architecture,
    "directory-fanout": cmd_directory_fanout,
    "root-policy": cmd_root_policy,
    "invariants": cmd_invariants,
    "coverage": cmd_coverage,
    "test": cmd_test,
    "analyze": cmd_analyze,
    "build": cmd_build,
    "format": cmd_format,
    "vet": cmd_vet,
    "harness": cmd_harness,
    "help": cmd_help,
}


def main():
    parser = argparse.ArgumentParser(
        prog="cli",
        description="sso-admin engineering CLI",
        add_help=False,
    )
    parser.add_argument("command", nargs="?", default="help", help="Command to run")
    parser.add_argument("args", nargs=argparse.REMAINDER, help="Command arguments")

    parsed, unknown = parser.parse_known_args()
    cmd = parsed.command

    if cmd in ("-h", "--help"):
        cmd = "help"

    if cmd not in COMMANDS:
        print(f"ERROR: unknown command '{cmd}'. Use 'python cli.py help' for usage.", file=sys.stderr)
        return 1

    handler = COMMANDS[cmd]
    return handler()


if __name__ == "__main__":
    sys.exit(main())
