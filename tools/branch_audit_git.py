"""Strict, isolated Git inspection for the read-only branch audit."""
import os
import re
import tempfile
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


def inspect_merge(repo, branch, base, run_git):
    """Merge immutable tips in disposable storage, never in the audited repo.

    merge-tree writes objects and can execute configured merge/filter drivers.
    A new bare repository borrows only objects, not refs, attributes files,
    configuration, templates, hooks, an index or a worktree from the source.
    """
    if not is_object_id(branch) or not is_object_id(base) or len(branch) != len(base):
        raise AuditError("invalid merge tips")
    try:
        output = run_git(repo, "rev-parse", "--path-format=absolute", "--git-path", "objects").stdout
        if not output.endswith("\n"):
            raise AuditError("object store unconfirmed")
        objects = Path(output[:-1])
        if not objects.is_absolute() or not objects.is_dir():
            raise AuditError("object store unconfirmed")
        environment = {"GIT_CONFIG_NOSYSTEM": "1", "GIT_CONFIG_GLOBAL": os.devnull,
                       "GIT_ATTR_NOSYSTEM": "1", "GIT_NO_REPLACE_OBJECTS": "1",
                       "GIT_NO_LAZY_FETCH": "1"}
        with tempfile.TemporaryDirectory(prefix="branch-audit-") as temporary:
            object_format = "sha1" if len(base) == 40 else "sha256"
            run_git(temporary, "init", "--bare", "--quiet", "--template=",
                    f"--object-format={object_format}", env=environment)
            # Git accepts C-quoted alternate paths. Octal bytes preserve even
            # separators, quotes, newlines and non-UTF-8 filesystem names.
            environment["GIT_ALTERNATE_OBJECT_DIRECTORIES"] = (
                '"' + "".join(f"\\{byte:03o}" for byte in os.fsencode(objects)) + '"'
            )
            return run_git(temporary, "merge-tree", "--write-tree", base, branch,
                           check=False, env=environment)
    except OSError as error:
        raise AuditError("isolated merge inspection did not complete") from error


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
    """Protect every registration without inspecting working-tree contents.

    Dirty state stays unknown: even git status can run configured clean filters.
    """
    rows = parse_worktrees(run_git(repo, "worktree", "list", "--porcelain", "-z").stdout)
    for row in rows:
        try:
            row["missing"] = not Path(row["path"]).is_dir()
        except OSError as error:
            raise AuditError("worktree state unconfirmed") from error
    return rows
