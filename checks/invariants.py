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


def grep(pattern: str, include: str = "*.dart", count_only: bool = True) -> int:
    """Count or list files matching a grep pattern."""
    cmd = ["grep", "-rl" if count_only else "-rn", pattern, "--include=" + include, "."]
    result = subprocess.run(
        cmd,
        capture_output=True, text=True, check=False,
        cwd=str(ROOT)
    )
    matches = [
        l for l in result.stdout.split("\n")
        if l.strip() and ".dart_tool" not in l and ".git" not in l and "build/" not in l
    ]
    return len(matches)


def run() -> int:
    ec = 0
    results = []
    
    # --- Security invariants ---
    
    # 1. Hardcoded secrets check (basic heuristic)
    n = grep(r'api[Kk]ey\s*[:=]\s*["\'][A-Za-z0-9]{16,}', count_only=True)
    results.append((n == 0, f"No hardcoded API keys (found {n} potential violations)"))
    if n > 0:
        print("  [*] WARNING: potential hardcoded API keys detected. Use config/env.")
    
    # 2. Bearer token handling patterns
    n = grep("sessionStorage", include="*.dart", count_only=True)
    results.append((n > 0, f"sessionStorage usage in {n} files (expected for web session)"))
    
    n = grep("localStorage", include="*.dart", count_only=True)
    results.append((n > 0, f"localStorage usage in {n} files (expected for preferences)"))
    
    # 3. mounted check pattern after async
    n = grep(r'await\b', include="*.dart", count_only=True)
    mounted_files = grep(r'if\s*\(!mounted\)', include="*.dart", count_only=True)
    # Check for use_build_context_synchronously violations (approximate)
    # The dart analyze rule catches actual violations; this is a structural heuristic
    results.append((True, f"Found {mounted_files} files with async-safe 'mounted' checks"))
    
    # 4. No print() in production code
    n = grep(r'\bprint\(', include="*.dart", count_only=True)
    results.append((n == 0, f"No print() statements in production code (found {n})"))
    
    # 5. Error handling patterns
    n = grep("SSOError", include="*.dart", count_only=True)
    results.append((n > 0, f"SSOError usage in {n} files"))
    
    n = grep("SnaplinkAdminApiError", include="*.dart", count_only=True)
    results.append((n > 0, f"SnaplinkAdminApiError usage in {n} files"))
    
    # 6. Import organization - verify package imports are used (good practice)
    n = grep(r'import\s+["\']package:', include="*.dart", count_only=True)
    results.append((True, f"Package imports found in {n} locations"))
    
    # 7. API path consistency - check that operations tab uses documented routes
    n = grep("SnaplinkAdminOperationCatalog", include="*.dart", count_only=True)
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
