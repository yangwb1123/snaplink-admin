"""Strict Git result and worktree parsing for the read-only branch audit."""
import re
from pathlib import Path


class AuditError(RuntimeError):
    """Raised when the repository state cannot be inspected safely."""


def query_status(result, allowed=(0, 1)):
    """Only command-documented statuses may be interpreted as predicates."""
    if result.returncode not in allowed:
        raise AuditError("git query failed")
    return result.returncode


def is_object_id(value):
    return re.fullmatch(r"(?:[0-9a-f]{40}|[0-9a-f]{64})", value) is not None


def parse_worktrees(output):
    """Parse NUL-delimited porcelain without treating quoted paths as missing."""
    if not output or not output.endswith("\0\0"):
        raise AuditError("invalid worktree listing")
    rows = []
    for record in output[:-2].split("\0\0"):
        fields = record.split("\0")
        key, separator, path = fields[0].partition(" ")
        if key != "worktree" or not separator or not path or not Path(path).is_absolute():
            raise AuditError("invalid worktree path")
        row = {"path": path, "branch": "", "prunable": False, "locked": False,
               "bare": False, "dirty": None}
        seen = set()
        for field in fields[1:]:
            key, _, value = field.partition(" ")
            if key in seen:
                raise AuditError("duplicate worktree field")
            seen.add(key)
            if key == "branch":
                if not value.startswith("refs/heads/") or not value.removeprefix("refs/heads/"):
                    raise AuditError("invalid worktree branch")
                row["branch"] = value.removeprefix("refs/heads/")
            elif key == "HEAD":
                if not is_object_id(value):
                    raise AuditError("invalid worktree HEAD")
            elif key in ("prunable", "locked", "bare"):
                row[key] = True
            elif key != "detached":
                raise AuditError("unknown worktree field")
        if row["branch"] and (row["bare"] or "detached" in seen):
            raise AuditError("inconsistent worktree listing")
        if not row["bare"] and ("HEAD" not in seen or not (row["branch"] or "detached" in seen)):
            raise AuditError("incomplete worktree listing")
        rows.append(row)
    return rows


def inspect_worktrees(repo, run_git):
    """Missing/locked registrations stay protected; missing dirtiness is unknown."""
    rows = parse_worktrees(run_git(repo, "worktree", "list", "--porcelain", "-z").stdout)
    for row in rows:
        try:
            row["missing"] = not Path(row["path"]).is_dir()
        except OSError as error:
            raise AuditError("worktree state unconfirmed") from error
        if not row["missing"] and not row["bare"]:
            # Disable configured status helpers and optional index refresh writes.
            row["dirty"] = bool(run_git(
                row["path"], "-c", "core.fsmonitor=false", "-c", "core.untrackedCache=false",
                "status", "--porcelain=v1", "-z", "--untracked-files=all",
                "--ignore-submodules=none",
            ).stdout)
    return rows
