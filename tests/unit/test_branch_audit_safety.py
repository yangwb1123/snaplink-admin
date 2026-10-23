"""Fail-closed Git inspection and suggestion safety using disposable repositories."""
import json
import shlex
import shutil
import subprocess
import unittest
from pathlib import Path
from unittest import mock

from test_branch_audit import GitFixture, branch_audit, git, run_tool


class GitFailureTest(GitFixture):
    def setUp(self):
        super().setUp()
        self.build_history()

    def assert_unconfirmed(self, result):
        code, output, errors = result
        self.assertEqual(code, 2)
        self.assertEqual(output, "", "no partial classification or cleanup advice")
        self.assertIn("repository state unconfirmed", errors)
        self.assertNotIn("synthetic internal detail", errors)
        self.assertNotIn("git branch", errors)
        self.assertNotIn("git worktree", errors)

    def intercept(self, operation, returncode=128, stdout="", timeout=False):
        original = subprocess.run

        def run(command, **kwargs):
            if operation in command:
                if timeout:
                    raise subprocess.TimeoutExpired(command, 30)
                return subprocess.CompletedProcess(command, returncode, stdout,
                                                   "synthetic internal detail")
            return original(command, **kwargs)

        return mock.patch.object(branch_audit.subprocess, "run", side_effect=run)

    def test_unexpected_predicate_statuses_are_not_boolean_results(self):
        for operation in ("merge-base", "diff", "merge-tree"):
            for status in (-9, 2, 128, 129):
                with self.subTest(operation=operation, status=status):
                    with self.intercept(operation, status):
                        self.assert_unconfirmed(run_tool(self.repo, "--json", "--suggest"))

    def test_failed_queries_never_emit_partial_report_or_advice(self):
        for operation in ("for-each-ref", "rev-list", "worktree", "status"):
            with self.subTest(operation=operation):
                with self.intercept(operation):
                    self.assert_unconfirmed(run_tool(self.repo, "--suggest"))

    def test_query_timeouts_remain_unknown(self):
        for operation in ("rev-parse", "for-each-ref", "merge-base", "rev-list",
                          "diff", "merge-tree", "worktree", "status"):
            with self.subTest(operation=operation):
                with self.intercept(operation, timeout=True):
                    self.assert_unconfirmed(run_tool(self.repo, "--json", "--suggest"))

    def test_base_probe_error_does_not_fall_back_to_master(self):
        git(self.repo, "branch", "master", "main")
        original, probes = subprocess.run, []

        def run(command, **kwargs):
            if "rev-parse" in command:
                probes.append(command[-1])
                if command[-1] == "refs/heads/main":
                    return subprocess.CompletedProcess(command, 128, "", "")
            return original(command, **kwargs)

        with mock.patch.object(branch_audit.subprocess, "run", side_effect=run):
            self.assert_unconfirmed(run_tool(self.repo, "--suggest"))
        self.assertEqual(probes, ["refs/heads/main"])

    def test_merge_inspection_failure_has_no_legacy_fallback(self):
        original, calls = subprocess.run, []

        def run(command, **kwargs):
            if "merge-tree" in command:
                calls.append(command)
                # Even conflict-looking output does not turn a fatal status into a conflict.
                return subprocess.CompletedProcess(command, 128, "CONFLICT synthetic\n", "")
            return original(command, **kwargs)

        with mock.patch.object(branch_audit.subprocess, "run", side_effect=run):
            self.assert_unconfirmed(run_tool(self.repo, "--json", "--suggest"))
        self.assertEqual(len(calls), 1)
        self.assertIn("--write-tree", calls[0])

    def test_merge_status_requires_a_valid_inspected_tree(self):
        for status in (0, 1):
            for output in ("", "usage: merge-tree\n", "CONFLICT synthetic\n"):
                with self.subTest(status=status, output=output):
                    with self.intercept("merge-tree", status, output):
                        self.assert_unconfirmed(run_tool(self.repo, "--suggest"))

    def test_malformed_success_output_is_not_empty_or_zero(self):
        for operation, output in (("rev-list", ""), ("rev-list", "not a count\n"),
                                  ("for-each-ref", "broken ref row\n"),
                                  ("worktree", ""), ("worktree", "worktree\0\0")):
            with self.subTest(operation=operation, output=output):
                with self.intercept(operation, 0, output):
                    self.assert_unconfirmed(run_tool(self.repo, "--suggest"))


class SuggestionSafetyTest(GitFixture):
    def commands(self, document):
        lines = branch_audit.suggestions(document)
        self.assertFalse(any("prune" in line or "archive/" in line for line in lines))
        commands = [shlex.split(line) for line in lines if not line.startswith("#")]
        for command in commands:
            self.assertEqual(command[:4], ["git", "branch", "-d", "--"])
        return commands

    def document(self):
        code, output, errors = run_tool(self.repo, "--json", "--suggest")
        self.assertEqual((code, errors), (0, ""))
        return json.loads(output)

    def test_shell_special_names_are_quoted_and_option_terminated(self):
        names = ["merged';echo_fixture", "merged$(fixture)", "merged&fixture"]
        for index, name in enumerate(names):
            self.write("a.txt", f"main step {index}\n")
            self.commit(f"main step {index}")
            git(self.repo, "branch", "--", name)
        self.write("a.txt", "main after merged branches\n")
        self.commit("main later")
        document = self.document()
        self.assertEqual(self.commands(document), [["git", "branch", "-d", "--", *sorted(names)]])
        command = document["suggestions"][0]
        for name in names:
            self.assertIn(shlex.quote(name), command)
        self.assertEqual(set(self.entries(document)), set(names))
        # Printing suggestions must not execute the shell-special text or delete refs.
        self.assertEqual(len(git(self.repo, "for-each-ref", "refs/heads").splitlines()), 4)

    def test_base_tip_duplicate_is_reported_and_has_no_deletion_advice(self):
        git(self.repo, "branch", "same-tip", "main")
        document = self.document()
        entry = self.entries(document)["same-tip"]
        self.assertTrue(entry["merged"])
        self.assertEqual(entry["ahead"], 0)
        self.assertFalse(entry["unique_changes"])
        self.assertFalse(entry["conflicts"])
        self.assertEqual(entry["duplicate_of"], "main")
        self.assertEqual(self.commands(document), [])
        self.assertEqual(git(self.repo, "rev-parse", "same-tip"), git(self.repo, "rev-parse", "main"))

    def test_merged_identical_tree_has_no_deletion_advice(self):
        git(self.repo, "branch", "merged-same-tree")
        git(self.repo, "commit", "-q", "--allow-empty", "-m", "new main history, same tree")
        document = self.document()
        entry = self.entries(document)["merged-same-tree"]
        self.assertEqual(entry["category"], "merged")
        self.assertTrue(entry["merged"])
        self.assertEqual(entry["ahead"], 0)
        self.assertFalse(entry["unique_changes"])
        self.assertFalse(entry["conflicts"])
        self.assertEqual(entry["duplicate_of"], "")
        self.assertNotEqual(git(self.repo, "rev-parse", "merged-same-tree"),
                            git(self.repo, "rev-parse", "main"))
        self.assertEqual(self.commands(document), [])

    def test_duplicates_and_other_unmerged_branches_have_no_deletion_advice(self):
        self.build_history()
        git(self.repo, "branch", "zz-conflict", "conflict-fresh")
        git(self.repo, "branch", "zz-merged", "merged-work")
        # Include a stale, cleanly mergeable branch, not only stale conflicts.
        git(self.repo, "checkout", "-q", "-b", "stale-clean")
        self.write("old.txt", "owned old work\n")
        self.commit("old independent work", date="2020-01-01T00:00:00Z")
        git(self.repo, "checkout", "-q", "main")
        document = self.document()
        self.assertEqual(self.entries(document)["stale-clean"]["category"], "stale")
        # Even the representative of a duplicate merged tip gets no deletion recipe.
        self.assertEqual(self.commands(document), [])

    def snapshot(self, paths):
        files, indexes = {}, {}
        for path in paths:
            if not path.is_dir():
                continue
            files[str(path)] = {
                str(file.relative_to(path)): file.read_bytes()
                for file in path.rglob("*")
                if ".git" not in file.relative_to(path).parts and file.is_file()
            }
            index = Path(git(path, "rev-parse", "--git-path", "index").strip())
            if not index.is_absolute():
                index = path / index
            indexes[str(path)] = index.read_bytes()
        return (git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)"),
                git(self.repo, "worktree", "list", "--porcelain", "-z"), files, indexes)

    def test_checked_out_dirty_locked_and_missing_worktrees_are_protected(self):
        paths = {}
        # Distinct, merged tips: duplicate suppression must not mask worktree protection.
        for name in ("clean", "dirty", "locked", "missing", "available", "root-checked"):
            self.write("a.txt", f"main at {name}\n")
            self.commit(name)
            git(self.repo, "branch", name)
            if name not in ("available", "root-checked"):
                path = Path(self.temporary.name) / ("clean ' path\nline" if name == "clean" else name)
                paths[name] = path
                git(self.repo, "worktree", "add", "-q", str(path), name)
        self.write("a.txt", "main later\n")
        self.commit("main after all branch tips")
        git(self.repo, "checkout", "-q", "root-checked")
        # Both staged and unstaged contents, plus untracked files, must survive.
        for path in (self.repo, paths["dirty"]):
            (path / "a.txt").write_text("staged owned change\n", encoding="utf-8")
            git(path, "add", "a.txt")
            (path / "a.txt").write_text("unstaged owned change\n", encoding="utf-8")
            (path / "untracked.txt").write_text("owned untracked\n", encoding="utf-8")
        git(self.repo, "worktree", "lock", "--reason", "owned fixture lock", str(paths["locked"]))
        shutil.rmtree(paths["missing"])
        all_paths = [self.repo, *paths.values()]
        before = self.snapshot(all_paths)
        document = self.document()
        self.assertEqual(self.snapshot(all_paths), before)
        self.assertEqual(self.commands(document), [["git", "branch", "-d", "--", "available"]])
        rows = {row["branch"]: row for row in document["worktrees"]}
        self.assertEqual(rows["clean"]["path"], str(paths["clean"]))
        self.assertFalse(rows["clean"]["dirty"])
        self.assertTrue(rows["dirty"]["dirty"])
        self.assertTrue(rows["root-checked"]["dirty"])
        self.assertTrue(rows["locked"]["locked"])
        self.assertFalse(rows["locked"]["missing"])
        self.assertTrue(rows["missing"]["missing"])
        self.assertIsNone(rows["missing"]["dirty"])
        self.assertEqual(document["dangling_worktrees"], 1)


if __name__ == "__main__":
    unittest.main()
