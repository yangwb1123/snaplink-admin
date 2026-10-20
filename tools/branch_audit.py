#!/usr/bin/env python3
"""Read-only branch/worktree debt audit.

Classifies every local branch against the base branch so a campaign or a
maintainer can see, before spending compute, which refs are already merged,
duplicated, content-identical, stale-conflicting or actively unmerged.

The audit never deletes a branch, never prunes a worktree and never touches the
index; ``--suggest`` only prints the commands a human may choose to run.
Usage: ``python3 tools/branch_audit.py [--json] [--stale-days N] [--suggest]``.
"""

import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

GIT_TIMEOUT = 30
DEFAULT_STALE_DAYS = 14
CATEGORY_ORDER = ("merged", "duplicate", "identical", "stale-conflicting", "conflicting", "stale", "active")


class AuditError(RuntimeError):
    """Raised when the repository state cannot be inspected safely."""


def git(repo, *args, check=True):
    """Run one bounded, non-interactive Git query."""
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args], capture_output=True, text=True,
            timeout=GIT_TIMEOUT, env={"GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C", "PATH": "/usr/bin:/bin"},
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise AuditError("git query did not complete") from error
    if check and result.returncode:
        raise AuditError("git query failed")
    return result


def base_branch(repo):
    """Return the configured base branch name or fail closed."""
    for candidate in ("main", "master"):
        if git(repo, "rev-parse", "--verify", "--quiet", f"refs/heads/{candidate}", check=False).returncode == 0:
            return candidate
    raise AuditError("no main/master base branch")


def local_branches(repo):
    """Return (name, commit, committer unix time) for every local branch."""
    output = git(repo, "for-each-ref", "--format=%(refname:short)%09%(objectname)%09%(committerdate:unix)", "refs/heads").stdout
    rows = []
    for line in output.splitlines():
        name, commit, stamp = line.split("\t")
        rows.append({"name": name, "commit": commit, "committed": int(stamp or 0)})
    return rows


def is_merged(repo, branch, base):
    return git(repo, "merge-base", "--is-ancestor", branch, base, check=False).returncode == 0


def ahead_count(repo, branch, base):
    text = git(repo, "rev-list", "--count", f"{base}..{branch}").stdout.strip()
    return int(text or 0)


def has_unique_changes(repo, branch, base):
    """True when the branch tree differs from the base tree.

    A two-dot tree comparison (not a three-dot history diff) is what catches a
    branch whose content already landed in the base by cherry-pick or squash: its
    history is unrelated but nothing would be gained by merging it.
    """
    return git(repo, "diff", "--quiet", base, branch, check=False).returncode != 0


def conflicts(repo, branch, base):
    """True when merging the branch into the base would conflict."""
    modern = git(repo, "merge-tree", "--write-tree", base, branch, check=False)
    if modern.returncode in (0, 1) and "CONFLICT" not in modern.stdout:
        return modern.returncode == 1
    legacy = git(repo, "merge-tree", base, branch, check=False)
    return "CONFLICT" in legacy.stdout or "changed in both" in legacy.stdout


def worktrees(repo):
    """Return worktree entries, flagging those whose directory is gone."""
    rows, current = [], {}
    for line in git(repo, "worktree", "list", "--porcelain").stdout.splitlines():
        if not line:
            if current:
                rows.append(current)
                current = {}
            continue
        key, _, value = line.partition(" ")
        if key == "worktree":
            current = {"path": value, "branch": "", "prunable": False}
        elif key == "branch":
            current["branch"] = value.removeprefix("refs/heads/")
        elif key == "prunable":
            current["prunable"] = True
    if current:
        rows.append(current)
    for row in rows:
        row["missing"] = not Path(row["path"]).is_dir()
    return rows


def classify(repo, base, stale_days, now):
    """Classify every non-base branch; deterministic order, no mutation."""
    branches = [row for row in local_branches(repo) if row["name"] != base]
    first_seen = {}
    report = []
    for row in sorted(branches, key=lambda item: item["name"]):
        name, commit, committed = row["name"], row["commit"], row["committed"]
        age_days = max(0, (now - committed) // 86400) if committed else 0
        entry = {"branch": name, "commit": commit[:12], "age_days": age_days, "ahead": 0,
                 "unique_changes": False, "conflicts": False, "category": "active", "duplicate_of": ""}
        if is_merged(repo, name, base):
            entry["category"] = "merged"
        elif commit in first_seen:
            entry["category"], entry["duplicate_of"] = "duplicate", first_seen[commit]
        else:
            first_seen[commit] = name
            entry["ahead"] = ahead_count(repo, name, base)
            entry["unique_changes"] = has_unique_changes(repo, name, base)
            if not entry["unique_changes"]:
                entry["category"] = "identical"
            else:
                entry["conflicts"] = conflicts(repo, name, base)
                if entry["conflicts"]:
                    entry["category"] = "stale-conflicting" if age_days >= stale_days else "conflicting"
                elif age_days >= stale_days:
                    entry["category"] = "stale"
        report.append(entry)
    return {"base": base, "stale_days": stale_days, "branches": report, "worktrees": worktrees(repo)}


def summarise(result):
    counts = {category: 0 for category in CATEGORY_ORDER}
    for entry in result["branches"]:
        counts[entry["category"]] = counts.get(entry["category"], 0) + 1
    missing = [row for row in result["worktrees"] if row["missing"] or row["prunable"]]
    return {"counts": counts, "branch_count": len(result["branches"]),
            "worktree_count": len(result["worktrees"]), "dangling_worktrees": len(missing)}


def suggestions(result):
    """Print-only cleanup commands; nothing here is executed."""
    merged = [entry["branch"] for entry in result["branches"] if entry["category"] == "merged"]
    duplicates = [entry["branch"] for entry in result["branches"] if entry["category"] == "duplicate"]
    identical = [entry["branch"] for entry in result["branches"] if entry["category"] == "identical"]
    stale = [entry["branch"] for entry in result["branches"] if entry["category"] == "stale-conflicting"]
    lines = []
    if merged:
        lines.append("# already merged into %s (safe to delete)" % result["base"])
        lines.append("git branch -d " + " ".join(merged))
    if duplicates:
        lines.append("# duplicate tips (keep one, delete the rest)")
        lines.append("git branch -D " + " ".join(duplicates))
    if identical:
        lines.append("# no unique content vs %s (archive then delete)" % result["base"])
        lines.append("git branch -D " + " ".join(identical))
    if stale:
        lines.append("# stale + conflicting: archive the tip, then delete the worktree/branch")
        for name in stale:
            lines.append(f"git tag archive/{name.replace('/', '-')} {name} && git branch -D {name}")
    if any(row["missing"] or row["prunable"] for row in result["worktrees"]):
        lines.append("git worktree prune -v")
    return lines


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--repo", default=".", help="repository path (default: current directory)")
    parser.add_argument("--json", action="store_true", help="machine-readable output")
    parser.add_argument("--stale-days", type=int, default=DEFAULT_STALE_DAYS, help="age at which an unmerged conflicting branch is stale")
    parser.add_argument("--suggest", action="store_true", help="print cleanup commands without running them")
    args = parser.parse_args(argv)
    if args.stale_days < 1:
        parser.error("--stale-days must be >= 1")
    repo = Path(args.repo).resolve()
    if not (repo / ".git").exists():
        print("branch audit: not a git worktree", file=sys.stderr)
        return 2
    try:
        result = classify(repo, base_branch(repo), args.stale_days, int(time.time()))
    except AuditError:
        print("branch audit: repository state unconfirmed; nothing changed", file=sys.stderr)
        return 2
    summary = summarise(result)
    if args.json:
        print(json.dumps({**result, **summary}, indent=2, sort_keys=True))
    else:
        print(f"base={result['base']} stale_days={result['stale_days']} branches={summary['branch_count']} "
              f"worktrees={summary['worktree_count']} dangling={summary['dangling_worktrees']}")
        print("counts: " + " ".join(f"{key}={value}" for key, value in summary["counts"].items()))
        for entry in sorted(result["branches"], key=lambda item: (CATEGORY_ORDER.index(item["category"]), item["branch"])):
            if entry["category"] == "merged":
                continue
            extra = f" duplicate_of={entry['duplicate_of']}" if entry["duplicate_of"] else ""
            print(f"  {entry['category']:<18} {entry['branch']} ahead={entry['ahead']} "
                  f"age={entry['age_days']}d conflicts={entry['conflicts']}{extra}")
    if args.suggest:
        for line in suggestions(result):
            print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
