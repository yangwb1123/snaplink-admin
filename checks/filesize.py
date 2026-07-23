#!/usr/bin/env python3
"""File size gate: source files must stay under the configured line budget.

Adapted from snaplink's checks/filesize.py for .dart files.
Thresholds, ignore patterns, and exemptions live in engineering.yaml.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from checks.config import get_config

_fs = get_config().filesize
MAX_LINES = _fs.max_lines
IGNORE_PATTERNS = tuple(_fs.ignore_patterns)
EXEMPTIONS = list(_fs.exemptions)


def is_exempt(path: Path, rel: str, exemptions: list = None) -> bool:
    if exemptions is None:
        exemptions = EXEMPTIONS
    for e in exemptions:
        if e.endswith("/*"):
            base = e[:-2]
            if rel.startswith(base):
                return True
        if e == rel or rel.endswith("/" + e):
            return True
    return False


def check_file(path: Path, root: Path) -> bool:
    if path.suffix not in (".dart", ".py", ".yaml", ".yml", ".md"):
        return True
    path = path.resolve()
    try:
        rel = str(path.relative_to(root))
    except ValueError:
        rel = str(path)
    for pat in IGNORE_PATTERNS:
        if pat in rel:
            return True
    if is_exempt(path, rel):
        return True
    lines = len(path.read_text().splitlines())
    if lines > MAX_LINES:
        print(f"  FAIL: {rel} ({lines} lines, max {MAX_LINES})")
        return False
    return True


def run(files: list[Path] = None) -> int:
    root = Path.cwd()
    if files:
        ok = all(check_file(f, root) for f in files)
    else:
        dart_files = sorted(root.rglob("*.dart"))
        ok = True
        for f in dart_files:
            rel = str(f.relative_to(root))
            if "/.git/" in rel or "/.dart_tool/" in rel:
                continue
            if not check_file(f, root):
                ok = False
    if ok:
        print("PASS: filesize")
        return 0
    print("FAIL: split files exceeding the line budget before continuing")
    return 1


if __name__ == "__main__":
    args = [Path(a) for a in sys.argv[1:]] if len(sys.argv) > 1 else None
    sys.exit(run(args))
