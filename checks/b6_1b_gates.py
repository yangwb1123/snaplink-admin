#!/usr/bin/env python3
"""B6-1b — debug-only ring copy surface gates (AC-1).

Source gates, executed on every landing via `python cli.py harness`
(ci.yml "Engineering gates" step — zero new CI wiring):

- old ring-scoped keys (en + zh) have zero hits in lib/ after the
  migration ('Clear audit log?' / 'local audit entries' / 'Clear log'
  and 清空审计日志 / 本地审计记录 / 清除日志);
- each of the five B6-1b keys lives in exactly one lib/i18n file
  (spread-override precedence: a duplicate in a later map would win
  silently);
- seam shape pins on lib/services/audit_log_service.dart (post-seam
  values, design b6-1b storage-seam §1.7): `kDebugMode` = 6 (two
  foldable initializers + four direct guards), the
  `_storageEnabled = kDebugMode` initializer pin, and
  `if (!kDebugMode) return;` = 4 — matched FIXED-STRING (as an `rg`
  regex the `(`/`)`/`!` are metacharacters and match 0 lines, F5);
  the `_ringCopyEnabled = kDebugMode` pin and the tab-file count (1)
  are unchanged;
- key-literal residence: `sso_audit_log` appears in exactly one lib/
  file and that file is the service (mirror of scan-6 R2.1);
- mask ban (open finding 1 — mirror of scan-6 R2.6, extended with the
  base64 family): no key-reconstruction construct in the service file:
  `String.fromCharCodes` / `base64Decode` / `base64Url` (the base64
  idioms in portal_api / token_refresh_service / federated_login are
  legitimately outside this file — the ban is scoped to the file that
  owns the key literal). Documented residual: the decoy-literal evasion
  — keeping the pinned literal in the service file (unused, DCE'd)
  while doing real I/O with a reconstructed key passes every source
  pin; the artifact gate then carries the burden (the reconstructed
  key's bytes land in the bundle unless hidden further — and the
  base64/base64Url encodings of the key are artifact needles too), and
  deliberate reintroduction becomes a manual-review matter, not a gate
  one.

Count semantics (W-3/W-4, FD-5): every count here is an OCCURRENCE
count (`rg -o`), identical to scan-6's `allMatches`. Each pinned line
holds exactly one occurrence, so occurrence counts and line counts
agree on today's layouts — but dart2js may emit several occurrences on
one line in a future bundle, and the artifact `== 2` pre-seam baseline
(sso_audit_log, one const per use site: setItem/getItem) holds only as
an occurrence count (W-3). The `== 2` line-count reading was 2 only by
coincidence of dart2js layout.

The release-web artifact gate (`make release-artifact-check`) greps
build/web/ recursively (open finding 2 — a chunked build cannot
silently widen the surface) for the old-key needles, the `sso_audit_log`
key needle, and its base64/base64Url encodings, and is wired into ci.yml
right after `make build-prod`. It is fail-closed: a missing build/web is
a FAILURE here, never a silent skip (the Makefile target likewise fails
red on a missing artifact). W-1/W-2: the `sso_audit_log` needle is live,
so a fresh pre-seam bundle (exactly 2 occurrences) is red — the gate is
no longer green independent of the seam; post-seam the const is DCE'd
to 0.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT))

from checks.config import get_config  # noqa: E402


def _grep(pattern: str, path: Path, fixed: bool = False) -> int:
    """Count occurrences of pattern under path (recursive).

    `rg -o` emits one line per match, so the output line count IS the
    occurrence count — the same semantics as scan-6's `allMatches`
    (W-3/W-4, FD-5). For fixed-string matches (every literal pin) `-F`
    is mandatory: regex metacharacters would match 0 lines (F5).
    """
    cmd = ["rg", "--no-heading", "-o"]
    if fixed:
        cmd.append("-F")
    cmd += [pattern, str(path)]
    result = subprocess.run(
        cmd, capture_output=True, text=True, check=False, cwd=str(ROOT)
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(f"rg failed for {pattern!r}: {result.stderr.strip()}")
    return len([line for line in result.stdout.splitlines() if line.strip()])


def _files_with(pattern: str, path: Path) -> list:
    """Files under path containing the fixed string (rg -l -F)."""
    result = subprocess.run(
        ["rg", "-l", "-F", pattern, str(path)],
        capture_output=True,
        text=True,
        check=False,
        cwd=str(ROOT),
    )
    if result.returncode not in (0, 1):
        raise RuntimeError(f"rg failed for {pattern!r}: {result.stderr.strip()}")
    return [line.strip() for line in result.stdout.splitlines() if line.strip()]


def run() -> int:
    cfg = get_config().b6_1b_gates
    results = []
    failures = 0

    # 1. Old en keys: zero hits anywhere in lib/ after landing.
    en_pattern = "|".join(cfg.old_en_needles)
    n = _grep(en_pattern, ROOT / "lib")
    ok = n == 0
    results.append((ok, f"Old en ring keys zero hits in lib/ (found {n})"))
    if not ok:
        failures += 1

    # 2. Old zh values: zero hits anywhere in lib/ after landing.
    zh_pattern = "|".join(cfg.old_zh_needles)
    n = _grep(zh_pattern, ROOT / "lib")
    ok = n == 0
    results.append((ok, f"Old zh ring values zero hits in lib/ (found {n})"))
    if not ok:
        failures += 1

    # 3. New-key uniqueness: exactly one lib/i18n file contains each key,
    #    and it is the admin-core catalog.
    catalog = (ROOT / cfg.catalog_file).resolve()
    for key in cfg.new_keys:
        files = _files_with(key, ROOT / cfg.catalog_dir)
        matched = [Path(f).resolve() for f in files]
        ok = len(matched) == 1 and matched[0] == catalog
        detail = ", ".join(files) if files else "none"
        results.append(
            (ok, f"Key {key!r} unique in {cfg.catalog_dir} -> {detail}")
        )
        if not ok:
            failures += 1

    # 4. Seam shape pins (post-seam values, design §1.7). The gate is
    #    red until the storage seam lands — the intended safe direction
    #    (W-1/W-2). All literal pins use fixed-string matching (F5).
    service = ROOT / cfg.service_file

    n = _grep(cfg.guard_line, service, fixed=True)
    ok = n == cfg.guard_line_count
    results.append(
        (
            ok,
            f"Direct guards {cfg.guard_line!r} in {cfg.service_file} = "
            f"{cfg.guard_line_count} (found {n})",
        )
    )
    if not ok:
        failures += 1

    n = _grep(cfg.storage_initializer_pin, service, fixed=True)
    ok = n == 1
    results.append(
        (
            ok,
            f"Storage initializer pin {cfg.storage_initializer_pin!r} in "
            f"{cfg.service_file} = exactly 1 (found {n})",
        )
    )
    if not ok:
        failures += 1

    n = _grep("kDebugMode", service)
    ok = n == cfg.service_kdebug_count
    results.append(
        (
            ok,
            f"kDebugMode in {cfg.service_file} = {cfg.service_kdebug_count} "
            f"(found {n})",
        )
    )
    if not ok:
        failures += 1

    n = _grep(cfg.initializer_pin, service, fixed=True)
    ok = n == 1
    results.append(
        (
            ok,
            f"Initializer pin {cfg.initializer_pin!r} in "
            f"{cfg.service_file} = exactly 1 (found {n})",
        )
    )
    if not ok:
        failures += 1

    n = _grep("kDebugMode", ROOT / cfg.tab_file)
    ok = n == cfg.tab_kdebug_count
    results.append(
        (
            ok,
            f"kDebugMode in {cfg.tab_file} = {cfg.tab_kdebug_count} "
            f"(found {n})",
        )
    )
    if not ok:
        failures += 1

    # 5. Key-literal residence (mirror of scan-6 R2.1): exactly one
    #    lib/ file contains the storage key, and it is the service.
    files = _files_with("sso_audit_log", ROOT / "lib")
    matched = [Path(f).resolve() for f in files]
    ok = len(matched) == 1 and matched[0] == service.resolve()
    detail = ", ".join(files) if files else "none"
    results.append(
        (ok, f"sso_audit_log lives in exactly one lib/ file -> {detail}")
    )
    if not ok:
        failures += 1

    # 6. Mask ban (open finding 1): key-reconstruction constructs banned
    #    in the service file — mirror of scan-6 R2.6, extended with the
    #    base64 family. Scoped to the service file: base64 is a
    #    legitimate idiom elsewhere in lib/.
    for token in cfg.banned_service_tokens:
        n = _grep(token, service, fixed=True)
        ok = n == 0
        results.append(
            (
                ok,
                f"Banned key-reconstruction token {token!r} absent from "
                f"{cfg.service_file} (found {n})",
            )
        )
        if not ok:
            failures += 1

    # 7. Release-web artifact gate (requires `make build-prod` first;
    #    wired into ci.yml after the Build step). Recursive over
    #    artifact_dir, occurrence counts, fail-closed: a missing build
    #    is a FAILURE, never a silent skip. Old-key needles and the
    #    key/mask needles are stable pins; zh escapes are advisory
    #    (toolchain-dependent).
    artifact_dir = ROOT / cfg.artifact_dir
    if not artifact_dir.is_dir():
        failures += 1
        results.append(
            (
                False,
                f"Artifact dir {cfg.artifact_dir} missing — run "
                "`make build-prod` first (fail-closed, no silent skip)",
            )
        )
    else:
        for needle in cfg.artifact_en_needles:
            n = _grep(needle, artifact_dir, fixed=True)
            ok = n == 0
            results.append(
                (ok, f"Artifact: {needle!r} absent from {cfg.artifact_dir}/ "
                     f"(found {n})")
            )
            if not ok:
                failures += 1
        for needle in cfg.artifact_key_masks:
            n = _grep(needle, artifact_dir, fixed=True)
            ok = n == 0
            results.append(
                (ok, f"Artifact (key mask): {needle} absent from "
                     f"{cfg.artifact_dir}/ (found {n})")
            )
            if not ok:
                failures += 1
        for needle in cfg.artifact_zh_escaped:
            n = _grep(needle, artifact_dir, fixed=True)
            ok = n == 0
            results.append(
                (ok, f"Artifact (advisory): {needle} absent from "
                     f"{cfg.artifact_dir}/ (found {n})")
            )
            if not ok:
                failures += 1

    print("=== B6-1b Debug Ring Copy Surface Gates (AC-1) ===")
    passed = 0
    for ok, msg in results:
        prefix = "[+]" if ok else "[-]"
        print(f"  {prefix} {msg}")
        passed += 1 if ok else 0
    print(
        f"\nResult: {passed} passed, {failures} failures "
        f"(exit {1 if failures else 0})"
    )
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(run())
