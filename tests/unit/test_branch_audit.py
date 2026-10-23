"""Regression tests for the read-only branch/worktree debt audit."""
import contextlib
import hashlib
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


class GitFixture(unittest.TestCase):
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

    def file_snapshot(self, path=None):
        path = path or self.repo
        return {str(file.relative_to(path)): hashlib.sha256(file.read_bytes()).hexdigest()
                for file in path.rglob("*") if file.is_file()}


class BranchAuditTest(GitFixture):
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
        # Ancestry is not tree equality: main changed after this merge.
        self.assertTrue(entries["merged-work"]["merged"])
        self.assertEqual(entries["merged-work"]["ahead"], 0)
        self.assertTrue(entries["merged-work"]["unique_changes"])
        self.assertFalse(entries["merged-work"]["conflicts"])
        self.assertFalse(entries["equal-tree"]["merged"])
        self.assertFalse(entries["equal-tree"]["unique_changes"])
        self.assertEqual(entries["equal-tree"]["ahead"], 1)
        for field in ("merged", "ahead", "unique_changes", "conflicts"):
            self.assertEqual(entries["zz-dup-b"][field], entries["equal-tree"][field])
        self.assertGreaterEqual(entries["conflict-stale"]["age_days"], 365)
        self.assertEqual(document["base"], "main")
        self.assertEqual(document["counts"]["merged"], 1)
        self.assertEqual(document["counts"]["duplicate"], 2)

    def test_audit_does_not_mutate_refs_or_worktrees(self):
        self.build_history()
        before = git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads")
        files_before = self.file_snapshot()
        code, _, _ = run_tool(self.repo, "--suggest")
        self.assertEqual(code, 0)
        after = git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)", "refs/heads")
        self.assertEqual(before, after)
        # Includes source objects, index, config, reflogs and worktree contents.
        self.assertEqual(self.file_snapshot(), files_before)

    def test_sha256_repository_with_quoted_object_store_path(self):
        self.repo = Path(self.temporary.name) / 'sha256 "line\nλ:objects'
        self.repo.mkdir()
        git(self.repo, "init", "-q", "-b", "main", "--object-format=sha256")
        git(self.repo, "config", "user.email", "fixture@example.invalid")
        git(self.repo, "config", "user.name", "fixture")
        self.write("a.txt", "base\n")
        self.commit("sha256 base")
        self.build_history()
        before = self.file_snapshot()
        code, output, errors = run_tool(self.repo, "--json")
        self.assertEqual((code, errors), (0, ""))
        entries = self.entries(json.loads(output))
        self.assertTrue(entries["conflict-fresh"]["conflicts"])
        self.assertFalse(entries["merged-work"]["conflicts"])
        self.assertEqual(self.file_snapshot(), before)

    def test_stale_threshold_changes_only_classification(self):
        self.build_history()
        code, output, _ = run_tool(self.repo, "--json", "--stale-days", "100000")
        self.assertEqual(code, 0)
        entries = self.entries(json.loads(output))
        self.assertEqual(entries["conflict-stale"]["category"], "conflicting")
        self.assertEqual(entries["conflict-fresh"]["category"], "conflicting")

    def test_dangling_worktree_reported_without_cleanup_advice(self):
        outside = Path(self.temporary.name) / "wt"
        git(self.repo, "branch", "wt-branch")
        git(self.repo, "worktree", "add", "-q", str(outside), "wt-branch")
        shutil.rmtree(outside)
        code, output, _ = run_tool(self.repo, "--json")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(output)["dangling_worktrees"], 1)
        code, suggested, _ = run_tool(self.repo, "--suggest")
        self.assertEqual(code, 0)
        self.assertNotIn("git worktree prune", suggested)
        self.assertNotIn("git branch -", suggested)
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
        self.assertIn("git branch -d -- merged-work", output)
        self.assertNotIn("git branch -D", output)
        self.assertNotIn("archive/", output)
        self.assertNotIn("git worktree prune", output)
        commands = [line for line in output.splitlines() if line.startswith("git ")]
        self.assertEqual(commands, ["git branch -d -- merged-work"])
        self.assertTrue((self.repo / "a.txt").exists())
        self.assertNotEqual(git(self.repo, "rev-parse", "--abbrev-ref", "HEAD").strip(), "")

    def test_duplicate_conflicting_tips_reuse_confirmed_comparisons(self):
        self.build_history()
        git(self.repo, "branch", "zz-conflict", "conflict-fresh")
        code, output, _ = run_tool(self.repo, "--json")
        self.assertEqual(code, 0)
        entries = self.entries(json.loads(output))
        duplicate, original = entries["zz-conflict"], entries["conflict-fresh"]
        self.assertEqual(duplicate["category"], "duplicate")
        self.assertEqual(duplicate["duplicate_of"], "conflict-fresh")
        for field in ("merged", "ahead", "unique_changes", "conflicts"):
            self.assertEqual(duplicate[field], original[field])
        self.assertFalse(duplicate["merged"])
        self.assertGreater(duplicate["ahead"], 0)
        self.assertTrue(duplicate["unique_changes"])
        self.assertTrue(duplicate["conflicts"])

    def test_independently_landed_tree_is_not_merged_history(self):
        git(self.repo, "checkout", "-q", "-b", "equal-content")
        self.write("a.txt", "same content\n")
        self.commit("feature history")
        git(self.repo, "checkout", "-q", "main")
        self.write("a.txt", "same content\n")
        self.commit("independently landed history")
        code, output, _ = run_tool(self.repo, "--json")
        self.assertEqual(code, 0)
        entry = self.entries(json.loads(output))["equal-content"]
        self.assertEqual(entry["category"], "identical")
        self.assertFalse(entry["merged"])
        self.assertFalse(entry["unique_changes"])
        self.assertFalse(entry["conflicts"])
        self.assertEqual(entry["ahead"], 1)
        self.assertEqual(branch_audit.suggestions(json.loads(output)), [])

    def test_direct_and_module_cli_keep_json_output(self):
        self.build_history()
        for entry in ([str(ROOT / "tools" / "branch_audit.py")], ["-m", "tools.branch_audit"]):
            with self.subTest(entry=entry):
                result = subprocess.run(
                    [sys.executable, *entry, "--repo", str(self.repo), "--json", "--suggest"],
                    cwd=ROOT, capture_output=True, text=True, timeout=30,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(json.loads(result.stdout)["suggestions"], ["git branch -d -- merged-work"])

    def test_json_with_suggestions_is_one_document(self):
        self.build_history()
        code, output, errors = run_tool(self.repo, "--json", "--suggest")
        self.assertEqual((code, errors), (0, ""))
        document = json.loads(output)
        self.assertEqual(document["suggestions"], ["git branch -d -- merged-work"])
        self.assertEqual(document["branch_count"], 6)


if __name__ == "__main__":
    unittest.main()
