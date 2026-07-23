#!/usr/bin/env python3
"""Architecture dependency direction gate for Flutter Dart imports.

Checks that lib/ subdirectories do not import from forbidden packages.
The forbidden-import map and excluded dirs live in engineering.yaml.
"""
import sys
import re
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from checks.config import get_config

_cfg = get_config()
_arch = _cfg.architecture
FORBIDDEN = dict(_arch.forbidden)
EXCLUDED_DIRS = set(_arch.excluded_dirs)

# The lib/ directory resolved relative to cwd
LIB_DIR = Path.cwd() / "lib"


def get_package(file_path: Path) -> str:
    """Get the logical package name for a file under lib/.
    
    Examples:
      lib/screens/admin/clients_tab.dart -> "screens/admin"
      lib/sso_client.dart -> "." (root of lib)
    """
    try:
        rel = file_path.relative_to(LIB_DIR)
    except ValueError:
        return None
    if rel.parent == Path("."):
        return "."
    parts = rel.parts[:-1]  # drop filename
    return "/".join(parts)


def check_file_imports(file_path: Path) -> list[str]:
    """Check that a single .dart file does not import forbidden packages."""
    rel = file_path.relative_to(Path.cwd())
    pkg = get_package(file_path)
    if pkg is None or pkg == ".":
        return []
    
    # Find which packages this file's package is forbidden from importing
    forbidden_targets = []
    for pkg_pattern, targets in FORBIDDEN.items():
        # Pattern can be exact ("screens/admin") or a prefix ("screens/")
        if pkg == pkg_pattern or pkg.startswith(pkg_pattern + "/"):
            forbidden_targets.extend(targets)
    
    if not forbidden_targets:
        return []
    
    violations = []
    content = file_path.read_text(encoding="utf-8")
    
    # Parse import statements
    import_pattern = re.compile(r'^\s*import\s+[\'\"](?:package:[\w_.]+/)?lib/([^\'\"]+)[\'\"]')
    for line in content.split("\n"):
        m = import_pattern.match(line)
        if not m:
            continue
        imported_path = m.group(1)
        # Check if the imported path matches any forbidden target
        for target in forbidden_targets:
            if imported_path.startswith(target):
                violations.append(
                    f"  FAIL: {rel} imports lib/{imported_path} (forbidden: {pkg} -> {target})"
                )
                break
    
    return violations


def run(package_dirs: list[Path] = None) -> int:
    print("--- architecture check ---")
    all_violations = []
    
    if not LIB_DIR.exists():
        print("  PASS (no lib/ directory)")
        return 0
    
    if package_dirs:
        for d in package_dirs:
            for f in sorted(d.resolve().rglob("*.dart")):
                all_violations.extend(check_file_imports(f))
    else:
        for f in sorted(LIB_DIR.rglob("*.dart")):
            rel = str(f.relative_to(Path.cwd()))
            if any(excluded in rel for excluded in EXCLUDED_DIRS):
                continue
            if f.name.endswith("_test.dart"):
                continue
            all_violations.extend(check_file_imports(f))
    
    for v in sorted(set(all_violations)):
        print(v)
    
    if all_violations:
        print("\n  FAIL: architecture violations found")
        return 1
    print("  PASS")
    return 0


if __name__ == "__main__":
    args = [Path(a) for a in sys.argv[1:]] if len(sys.argv) > 1 else None
    sys.exit(run(args))
