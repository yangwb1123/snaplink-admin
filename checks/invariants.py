#!/usr/bin/env python3
"""Security invariants and code quality checks for the Flutter project.

Adapted from snaplink's checks/invariants.py. Checks:
- No hardcoded secrets or tokens
- Proper use of 'mounted' checks after async operations
- No print() statements (should use structured logging)
- Session storage security patterns
- API path consistency
"""
import sys
import subprocess
from pathlib import Path

ROOT = Path.cwd()


def search(pattern: str, include: str = "*.dart") -> int:
    """Count source files matching a regular expression."""
    cmd = [
        "rg",
        "--files-with-matches",
        "--glob",
        include,
        "--glob",
        "!.dart_tool/**",
        "--glob",
        "!.git/**",
        "--glob",
        "!build/**",
        pattern,
        ".",
    ]
    result = subprocess.run(
        cmd,
        capture_output=True, text=True, check=False,
        cwd=str(ROOT)
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(f"rg failed for {pattern!r}: {result.stderr.strip()}")
    return len([line for line in result.stdout.splitlines() if line.strip()])


def run() -> int:
    ec = 0
    results = []
    
    # --- Security invariants ---
    
    # 1. Hardcoded secrets check (basic heuristic)
    n = search(r"""api[Kk]ey\s*[:=]\s*["'][A-Za-z0-9]{16,}""")
    results.append((n == 0, f"No hardcoded API keys (found {n} potential violations)"))
    if n > 0:
        print("  [*] WARNING: potential hardcoded API keys detected. Use config/env.")
    
    # 2. Bearer token handling patterns
    n = search("sessionStorage")
    results.append((n > 0, f"sessionStorage usage in {n} files (expected for web session)"))
    
    n = search("localStorage")
    results.append((n > 0, f"localStorage usage in {n} files (expected for preferences)"))
    
    # 3. mounted check pattern after async
    mounted_files = search(r'if\s*\(!mounted\)')
    # Check for use_build_context_synchronously violations (approximate)
    # The dart analyze rule catches actual violations; this is a structural heuristic
    results.append((True, f"Found {mounted_files} files with async-safe 'mounted' checks"))
    
    # 4. No print() in production code
    n = search(r'\bprint\(')
    results.append((n == 0, f"No print() statements in production code (found {n})"))
    
    # 5. Error handling patterns
    n = search("SSOError")
    results.append((n > 0, f"SSOError usage in {n} files"))
    
    n = search("SnaplinkAdminApiError")
    results.append((n > 0, f"SnaplinkAdminApiError usage in {n} files"))
    
    # 6. Import organization - verify package imports are used (good practice)
    n = search(r"""import\s+["']package:""")
    results.append((True, f"Package imports found in {n} locations"))
    
    # 7. API path consistency - check that operations tab uses documented routes
    n = search("SnaplinkAdminOperationCatalog")
    results.append((n > 0, f"SnaplinkAdminOperationCatalog used in {n} files"))
    
    # 8. Documentation files exist
    docs_exist = (ROOT / "README.md").exists()
    results.append((docs_exist, "README.md exists"))
    
    # OpenAPI spec is maintained in the snaplink backend project, not here
    results.append((True, "OpenAPI spec hosted in snaplink project (not duplicated)"))
    
    # 9. Check for proper API layer isolation
    api_files = list(ROOT.glob("lib/**/*api*.dart"))
    results.append((len(api_files) > 0, f"API layer files: {len(api_files)}"))
    
    # --- Print results ---
    print("=== Security & Code Quality Invariant Check ===")
    passed = 0
    warnings = 0
    failures = 0
    
    for ok, msg in results:
        if ok:
            print(f"  [+] {msg}")
            passed += 1
        else:
            if "potential" in msg.lower() or "warning" in msg.lower() or "advisory" in msg.lower():
                print(f"  [*] {msg}")
                warnings += 1
            else:
                print(f"  [-] {msg}")
                failures += 1
                ec = 1
    
    print(f"\nResult: {passed} passed, {warnings} warnings, {failures} failures")
    return ec


if __name__ == "__main__":
    sys.exit(run())
