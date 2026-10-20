"""Regression tests for the read-only branch/worktree debt audit."""
import contextlib
import io
import json
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))

import branch_audit  # noqa: E402


def git(repo, *args, date=None):
    environment = dict(os.environ)
    environment.update({"GIT_TERMINAL_PROMPT": "0", "LC_ALL": "C"})
    if date:
        environment.update({"GIT_AUTHOR_DATE": date, "GIT_COMMITTER_DATE": date})
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True,
                            text=True, timeout=30, env=environment)
    if result.returncode:
        raise AssertionError(f"fixture git {args[0]} failed: {result.stderr.strip()[:200]}")
    return result.stdout


def run_tool(repo, *extra):
    stream, errors = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(stream), contextlib.redirect_stderr(errors):
        code = branch_audit.main(["--repo", str(repo), *extra])
    return code, stream.getvalue(), errors.getvalue()


class BranchAuditTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.repo = Path(self.temporary.name) / "repo"
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main")
        git(self.repo, "config", "user.email", "fixture@example.invalid")
        git(self.repo, "config", "user.name", "fixture")
        (self.repo / "a.txt").write_text("base\n", encoding="utf-8")
        git(self.repo, "add", "a.txt")
        git(self.repo, "commit", "-q", "-m", "base")

    def tearDown(self):
        self.temporary.cleanup()

    def write(self, name, text):
        (self.repo / name).write_text(text, encoding="utf-8")

    def commit(self, message, date=None):
        git(self.repo, "add", "-A")
        git(self.repo, "commit", "-q", "-m", message, date=date)
        return git(self.repo, "rev-parse", "HEAD").strip()

    def build_history(self):
        # merged: committed on a branch, then merged into main.
        git(self.repo, "checkout", "-q", "-b", "merged-work")
        self.write("merged.txt", "merged\n")
        self.commit("merged change")
        git(self.repo, "checkout", "-q", "main")
        git(self.repo, "merge", "-q", "--no-ff", "-m", "merge merged-work", "merged-work")
        shared = git(self.repo, "rev-parse", "HEAD").strip()
        # fresh conflict: both sides rewrite the same line.
        git(self.repo, "checkout", "-q", "-b", "conflict-fresh")
        self.write("a.txt", "branch side\n")
        self.commit("branch side")
        git(self.repo, "checkout", "-q", "main")
        self.write("a.txt", "main side\n")
        self.commit("main side")
        # stale conflict: branched before the main edit, committed 2020.
        git(self.repo, "checkout", "-q", "-b", "conflict-stale", shared)
        self.write("a.txt", "stale side\n")
        self.commit("stale side", date="2020-01-01T00:00:00Z")
        git(self.repo, "checkout", "-q", "main")
        # equal content on unrelated history: an empty commit keeps main's tree.
        git(self.repo, "checkout", "-q", "-b", "equal-tree", "main")
        git(self.repo, "commit", "-q", "--allow-empty", "-m", "empty tree")
        git(self.repo, "branch", "zz-dup-a", "equal-tree")
        git(self.repo, "branch", "zz-dup-b", "equal-tree")
        git(self.repo, "checkout", "-q", "main")

    def entries(self, document):
        return {row["branch"]: row for row in document["branches"]}

    def test_categories(self):
        self.build_history()
        code, output, _ = run_tool(self.repo, "--json")
        self.assertEqual(code, 0)
        document = json.loads(output)
        entries = self.entries(document)
        self.assertEqual(entries["merged-work"]["category"], "merged")
        self.assertEqual(entries["zz-dup-b"]["category"], "duplicate")
        self.assertEqual(entries["zz-dup-b"]["duplicate_of"], "equal-tree")
        self.assertEqual(entries["equal-tree"]["category"], "identical")
        self.assertEqual(entries["conflict-fresh"]["category"], "conflicting")
        self.assertEqual(entries["conflict-stale"]["category"], "stale-conflicting")
        self.assertTrue(entries["conflict-fresh"]["conflicts"])
        self.assertGreaterEqual(entries["conflict-stale"]["age_days"], 365)
        self.assertEqual(document["base"], "main")
        self.assertEqual(document["counts"]["merged"], 1)
        self.assertEqual(document["counts"]["duplicate"], 2)

    def test_audit_does_not_mutate_refs_or_worktrees(self):
        self.build_history()
        before = git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads")
        code, _, _ = run_tool(self.repo, "--suggest")
        self.assertEqual(code, 0)
        after = git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads")
        self.assertEqual(before, after)

    def test_stale_threshold_changes_only_classification(self):
        self.build_history()
        code, output, _ = run_tool(self.repo, "--json", "--stale-days", "100000")
        self.assertEqual(code, 0)
        entries = self.entries(json.loads(output))
        self.assertEqual(entries["conflict-stale"]["category"], "conflicting")
        self.assertEqual(entries["conflict-fresh"]["category"], "conflicting")

    def test_dangling_worktree_reported_and_prune_only_suggested(self):
        outside = Path(self.temporary.name) / "wt"
        git(self.repo, "branch", "wt-branch")
        git(self.repo, "worktree", "add", "-q", str(outside), "wt-branch")
        shutil.rmtree(outside)
        code, output, _ = run_tool(self.repo, "--json")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(output)["dangling_worktrees"], 1)
        code, suggested, _ = run_tool(self.repo, "--suggest")
        self.assertEqual(code, 0)
        self.assertIn("git worktree prune", suggested)
        self.assertIn("wt-branch", git(self.repo, "worktree", "list", "--porcelain"))

    def test_rejects_non_git_directory_without_side_effects(self):
        empty = Path(self.temporary.name) / "empty"
        empty.mkdir()
        code, _, errors = run_tool(empty)
        self.assertEqual(code, 2)
        self.assertEqual(list(empty.iterdir()), [])
        self.assertIn("not a git worktree", errors)

    def test_suggestions_are_text_not_commands(self):
        self.build_history()
        code, output, _ = run_tool(self.repo, "--suggest")
        self.assertEqual(code, 0)
        self.assertIn("git branch -d", output)
        self.assertIn("archive/", output)
        self.assertTrue((self.repo / "a.txt").exists())
        self.assertNotEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").strip(), "")


if __name__ == "__main__":
    unittest.main()
