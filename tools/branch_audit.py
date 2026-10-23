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
import shlex
import subprocess
import sys
import time
from pathlib import Path

if __package__:
    from .branch_audit_git import AuditError, inspect_merge, inspect_worktrees, is_object_id, query_status
else:
    from branch_audit_git import AuditError, inspect_merge, inspect_worktrees, is_object_id, query_status

GIT_TIMEOUT = 30
DEFAULT_STALE_DAYS = 14
CATEGORY_ORDER = ("merged", "duplicate", "identical", "stale-conflicting", "conflicting", "stale", "active")


def git(repo, *args, check=True, env=None):
    """Run one bounded, non-interactive Git query without inherited environment."""
    environment = {"GIT_TERMINAL_PROMPT": "0", "GIT_OPTIONAL_LOCKS": "0",
                   "LC_ALL": "C", "PATH": "/usr/bin:/bin"}
    if env is not None:
        environment.update(env)
    try:
        result = subprocess.run(
            ["git", "-C", str(repo), *args], capture_output=True,
            timeout=GIT_TIMEOUT, env=environment,
        )
    except (OSError, subprocess.TimeoutExpired) as error:
        raise AuditError("git query did not complete") from error
    if check:
        query_status(result, (0,))
    # Decode without universal-newline translation: worktree paths may contain CR/LF.
    for field in ("stdout", "stderr"):
        value = getattr(result, field)
        if isinstance(value, bytes):
            setattr(result, field, value.decode("utf-8", errors="surrogateescape"))
    return result


def base_branch(repo):
    """Return the configured base branch name or fail closed."""
    for candidate in ("main", "master"):
        probe = git(repo, "rev-parse", "--verify", "--quiet", f"refs/heads/{candidate}", check=False)
        if query_status(probe) == 0:
            if not is_object_id(probe.stdout.strip()):
                raise AuditError("invalid base ref")
            return candidate
    raise AuditError("no main/master base branch")


def local_branches(repo):
    """Return (name, commit, committer unix time) for every local branch."""
    output = git(repo, "for-each-ref", "--format=%(refname)%09%(objectname)%09%(committerdate:unix)", "refs/heads").stdout
    rows = []
    for line in output.splitlines():
        fields = line.split("\t")
        if len(fields) != 3:
            raise AuditError("invalid branch listing")
        ref, commit, stamp = fields
        name = ref.removeprefix("refs/heads/")
        if not ref.startswith("refs/heads/") or not name or not is_object_id(commit) or not stamp.isdecimal():
            raise AuditError("invalid branch facts")
        rows.append({"name": name, "commit": commit, "committed": int(stamp)})
    return rows


def is_merged(repo, branch, base):
    return query_status(git(repo, "merge-base", "--is-ancestor", branch, base, check=False)) == 0


def ahead_count(repo, branch, base):
    text = git(repo, "rev-list", "--count", f"{base}..{branch}").stdout.strip()
    if not text.isdecimal():
        raise AuditError("invalid ahead count")
    return int(text)


def has_unique_changes(repo, branch, base):
    """True when the branch tree differs from the base tree.

    A two-dot tree comparison (not a three-dot history diff) is what catches a
    branch whose content already landed in the base by cherry-pick or squash: its
    history is unrelated but nothing would be gained by merging it.
    """
    result = git(repo, "diff", "--quiet", "--no-ext-diff", "--no-textconv",
                 "--ignore-submodules=none", base, branch, "--", check=False)
    return query_status(result) == 1


def conflicts(repo, branch, base):
    """True only for a confirmed conflict; unsupported/failed inspection is unknown."""
    result = inspect_merge(repo, branch, base, git)
    status = query_status(result)
    lines = result.stdout.splitlines()
    if not lines or not is_object_id(lines[0]):
        raise AuditError("merge inspection unconfirmed")
    # Modern merge-tree documents 0=clean, 1=conflicted; never fall back on errors.
    return status == 1


def worktrees(repo):
    """Return all registrations; dirtiness remains unknown and is not inspected."""
    return inspect_worktrees(repo, git)


def classify(repo, base, stale_days, now):
    """Classify every non-base branch; deterministic order, no mutation."""
    snapshot = local_branches(repo)
    base_tips = [row["commit"] for row in snapshot if row["name"] == base]
    if len(base_tips) != 1:
        raise AuditError("base branch state unconfirmed")
    base_tip = base_tips[0]
    branches = [row for row in snapshot if row["name"] != base]
    first_seen, comparisons = {base_tip: base}, {}
    report = []
    for row in sorted(branches, key=lambda item: item["name"]):
        name, commit, committed = row["name"], row["commit"], row["committed"]
        age_days = max(0, (now - committed) // 86400) if committed else 0
        if commit not in comparisons:
            # Compare immutable tips, once per tip. Ancestry, content and mergeability
            # are independent facts, including for merged and duplicate branches.
            comparisons[commit] = {"merged": is_merged(repo, commit, base_tip),
                                   "ahead": ahead_count(repo, commit, base_tip),
                                   "unique_changes": has_unique_changes(repo, commit, base_tip),
                                   "conflicts": conflicts(repo, commit, base_tip)}
        duplicate_of = first_seen.get(commit, "")
        first_seen.setdefault(commit, name)
        entry = {"branch": name, "commit": commit[:12], "age_days": age_days,
                 "category": "active", "duplicate_of": duplicate_of, **comparisons[commit]}
        if entry["merged"]:
            entry["category"] = "merged"
        elif duplicate_of:
            entry["category"] = "duplicate"
        elif not entry["unique_changes"]:
            entry["category"] = "identical"
        elif entry["conflicts"]:
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
    """Optional, non-forcing advice from confirmed facts; always recheck before use.

    Tip identity, equal content and age never establish disposability. Protect
    every registered worktree, including missing/locked ones, and both names of
    a duplicate tip. No worktree removal or global pruning is recommended.
    """
    protected = {row["branch"] for row in result["worktrees"]}
    for entry in result["branches"]:
        if entry["duplicate_of"]:
            protected.update((entry["branch"], entry["duplicate_of"]))
    merged = sorted(entry["branch"] for entry in result["branches"]
                    if entry["category"] == "merged" and entry.get("merged") is True
                    and entry.get("unique_changes") is True and entry.get("conflicts") is False
                    and entry["branch"] not in protected)
    return ["git branch -d -- " + " ".join(shlex.quote(name) for name in merged)] if merged else []


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
    if args.suggest:
        result["suggestions"] = suggestions(result)
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
            for line in result["suggestions"]:
                print(line)
    return 0


if __name__ == "__main__":
    sys.exit(main())
