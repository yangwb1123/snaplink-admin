"""Fail-closed Git inspection and suggestion safety using disposable repositories."""
import json
import os
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
        for operation in ("config", "for-each-ref", "rev-list", "init", "worktree"):
            with self.subTest(operation=operation):
                with self.intercept(operation):
                    self.assert_unconfirmed(run_tool(self.repo, "--suggest"))

    def test_query_timeouts_remain_unknown(self):
        for operation in ("config", "rev-parse", "for-each-ref", "merge-base", "rev-list",
                          "diff", "init", "merge-tree", "worktree"):
            with self.subTest(operation=operation):
                with self.intercept(operation, timeout=True):
                    self.assert_unconfirmed(run_tool(self.repo, "--json", "--suggest"))

    def test_every_git_query_disables_fetch_transport_and_prompts(self):
        original, calls = subprocess.run, []

        def run(command, **kwargs):
            calls.append(command)
            for key, value in {"GIT_NO_LAZY_FETCH": "1", "GIT_ALLOW_PROTOCOL": "",
                               "GIT_TERMINAL_PROMPT": "0", "GIT_PROTOCOL_FROM_USER": "0",
                               "GIT_ASKPASS": "/bin/false", "SSH_ASKPASS": "/bin/false"}.items():
                self.assertEqual(kwargs["env"].get(key), value, key)
            return original(command, **kwargs)

        with mock.patch.object(branch_audit.subprocess, "run", side_effect=run):
            code, _, errors = run_tool(self.repo, "--json")
            self.assertEqual((code, errors), (0, ""))
            branch_audit.git(self.repo, "rev-parse", "--git-dir",
                             env={"GIT_NO_LAZY_FETCH": "0", "GIT_ALLOW_PROTOCOL": "file",
                                  "GIT_TERMINAL_PROMPT": "1", "GIT_PROTOCOL_FROM_USER": "1",
                                  "GIT_ASKPASS": "fixture", "SSH_ASKPASS": "fixture"})
        self.assertTrue(calls)

    def test_partial_configuration_is_rejected_before_object_reads(self):
        for key, value in (("extensions.partialClone", "origin"),
                           ("remote.origin.promisor", "true"),
                           ("remote.origin.partialCloneFilter", "tree:0")):
            with self.subTest(key=key):
                git(self.repo, "config", key, value)
                before = self.file_snapshot()
                with mock.patch.object(branch_audit.subprocess, "run", wraps=subprocess.run) as query:
                    self.assert_unconfirmed(run_tool(self.repo, "--json", "--suggest"))
                self.assertEqual([call.args[0][3] for call in query.call_args_list], ["config"])
                self.assertEqual(self.file_snapshot(), before)
                git(self.repo, "config", "--unset", key)

    def test_worktree_inspection_queries_only_registrations(self):
        linked = Path(self.temporary.name) / "linked worktree"
        git(self.repo, "worktree", "add", "-q", str(linked), "merged-work")
        with mock.patch.object(branch_audit, "git", wraps=branch_audit.git) as query:
            rows = branch_audit.worktrees(self.repo)
        query.assert_called_once_with(self.repo, "worktree", "list", "--porcelain", "-z")
        self.assertEqual({row["branch"] for row in rows}, {"main", "merged-work"})
        for row in rows:
            self.assertIsNone(row["dirty"])

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
        for operation, output in (("config", "broken config output\n"), ("config", "\0"),
                                  ("rev-list", ""), ("rev-list", "not a count\n"),
                                  ("for-each-ref", "broken ref row\n"),
                                  ("worktree", ""), ("worktree", "worktree\0\0")):
            with self.subTest(operation=operation, output=output):
                with self.intercept(operation, 0, output):
                    self.assert_unconfirmed(run_tool(self.repo, "--suggest"))


class PromisorSafetyTest(GitFixture):
    def setUp(self):
        super().setUp()
        git(self.repo, "checkout", "-q", "-b", "candidate")
        self.write("candidate.txt", "owned candidate\n")
        self.commit("candidate")
        tree = git(self.repo, "rev-parse", "HEAD^{tree}").strip()
        git(self.repo, "checkout", "-q", "main")
        self.linked = Path(self.temporary.name) / "linked worktree"
        git(self.repo, "worktree", "add", "-q", str(self.linked), "candidate")
        self.promisor = Path(self.temporary.name) / "promisor.git"
        git(self.repo, "clone", "-q", "--bare", "--no-hardlinks", str(self.repo), str(self.promisor))
        git(self.promisor, "config", "uploadpack.allowFilter", "true")
        git(self.promisor, "config", "uploadpack.allowAnySHA1InWant", "true")
        git(self.repo, "config", "remote.origin.url", self.promisor.as_uri())
        git(self.repo, "config", "remote.origin.promisor", "true")
        git(self.repo, "config", "remote.origin.partialclonefilter", "tree:0")
        for path in (self.repo, self.linked):
            (path / "a.txt").write_text("owned staged content\n", encoding="utf-8")
            git(path, "add", "a.txt")
            (path / "a.txt").write_text("owned unstaged content\n", encoding="utf-8")
            (path / "untracked.txt").write_text("owned untracked content\n", encoding="utf-8")
        self.missing_tree = self.repo / ".git" / "objects" / tree[:2] / tree[2:]
        self.missing_tree.unlink()

    def assert_missing_tree_fails_closed(self, repo, before_object_reads=True):
        self.assertFalse(self.missing_tree.exists())
        paths = (self.repo, self.linked, self.promisor)
        before = tuple(self.file_snapshot(path) for path in paths)
        with mock.patch.object(branch_audit.subprocess, "run", wraps=subprocess.run) as query:
            code, output, errors = run_tool(repo, "--json", "--suggest")
        # Includes all objects, refs, reflogs, indexes, registrations and contents.
        self.assertEqual(tuple(self.file_snapshot(path) for path in paths), before)
        self.assertEqual((code, output), (2, ""))
        self.assertIn("repository state unconfirmed", errors)
        if before_object_reads:
            self.assertEqual([call.args[0][3] for call in query.call_args_list], ["config"])

    def test_full_audit_missing_promised_tree_at_root(self):
        self.assert_missing_tree_fails_closed(self.repo)

    def test_full_audit_missing_promised_tree_at_linked_worktree(self):
        self.assert_missing_tree_fails_closed(self.linked)

    def test_included_promisor_configuration_is_rejected(self):
        git(self.repo, "config", "--remove-section", "remote.origin")
        included = self.repo / ".git" / "owned-promisor.config"
        git(self.repo, "config", "--file", str(included), "remote.origin.url", self.promisor.as_uri())
        git(self.repo, "config", "--file", str(included), "remote.origin.promisor", "true")
        git(self.repo, "config", "include.path", str(included))
        for repo in (self.repo, self.linked):
            with self.subTest(repo=repo):
                self.assert_missing_tree_fails_closed(repo)

    def test_worktree_local_promisor_configuration_is_rejected(self):
        git(self.repo, "config", "--remove-section", "remote.origin")
        git(self.repo, "config", "extensions.worktreeConfig", "true")
        git(self.linked, "config", "--worktree", "remote.origin.url", self.promisor.as_uri())
        git(self.linked, "config", "--worktree", "remote.origin.promisor", "true")
        self.assert_missing_tree_fails_closed(self.linked)

    def test_missing_unpromised_tree_also_fails_closed_without_mutation(self):
        git(self.repo, "config", "--remove-section", "remote.origin")
        for repo in (self.repo, self.linked):
            with self.subTest(repo=repo):
                self.assert_missing_tree_fails_closed(repo, before_object_reads=False)


class MergeIsolationTest(GitFixture):
    def test_configured_merge_driver_cannot_write_to_audited_repository(self):
        self.write(".gitattributes", "a.txt merge=audit_fixture\n")
        self.commit("synthetic merge attribute")
        self.build_history()
        linked = Path(self.temporary.name) / "linked worktree"
        git(self.repo, "worktree", "add", "-q", "--detach", str(linked), "main")
        marker = Path(self.temporary.name) / "driver-marker"
        driver = (f"printf fixture > {shlex.quote(str(marker))}; "
                  f"printf 'driver changed tracked file\\n' > {shlex.quote(str(self.repo / 'a.txt'))}; "
                  "exit 0")
        git(self.repo, "config", "merge.audit_fixture.driver", driver)
        git(self.repo, "config", "merge.default", "audit_fixture")
        self.write("a.txt", "owned staged content\n")
        git(self.repo, "add", "a.txt")
        self.write("a.txt", "owned unstaged content\n")
        before = self.file_snapshot(), self.file_snapshot(linked)
        refs = git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)")
        registrations = git(self.repo, "worktree", "list", "--porcelain", "-z")
        for repo in (self.repo, linked):
            with self.subTest(repo=repo):
                code, output, errors = run_tool(repo, "--json", "--suggest")
                self.assertEqual((code, errors), (0, ""))
                self.assertFalse(marker.exists(), "configured merge driver was executed")
                entries = self.entries(json.loads(output))
                self.assertTrue(entries["conflict-fresh"]["conflicts"])
                self.assertTrue(entries["conflict-stale"]["conflicts"])
                self.assertEqual(git(self.repo, "for-each-ref", "--format=%(refname) %(objectname)"), refs)
                self.assertEqual(git(self.repo, "worktree", "list", "--porcelain", "-z"), registrations)
                self.assertEqual((self.file_snapshot(), self.file_snapshot(linked)), before)
                self.assertEqual((self.repo / "a.txt").read_text(), "owned unstaged content\n")

    def test_configured_filters_are_not_executed_during_merge_inspection(self):
        self.write(".gitattributes", "a.txt filter=audit_fixture\n")
        self.commit("synthetic filter attribute")
        self.build_history()
        base = git(self.repo, "rev-parse", "main").strip()
        tip = git(self.repo, "rev-parse", "conflict-fresh").strip()
        marker = Path(self.temporary.name) / "filter-marker"
        driver = f"printf fixture > {shlex.quote(str(marker))}; cat"
        git(self.repo, "config", "merge.renormalize", "true")
        for operation in ("clean", "smudge"):
            git(self.repo, "config", f"filter.audit_fixture.{operation}", driver)
        git(self.repo, "config", "filter.audit_fixture.required", "true")
        before = self.file_snapshot()
        self.assertTrue(branch_audit.conflicts(self.repo, tip, base))
        self.assertFalse(marker.exists(), "configured filter driver was executed")
        self.assertEqual(self.file_snapshot(), before)

    def test_temporary_merge_storage_is_cleaned_on_success_conflict_and_failure(self):
        self.build_history()
        base = git(self.repo, "rev-parse", "main").strip()
        original = subprocess.run
        for outcome in ("clean", "conflict", "fatal", "timeout"):
            branch = "merged-work" if outcome == "clean" else "conflict-fresh"
            tip = git(self.repo, "rev-parse", branch).strip()
            inspected = []

            def run(command, **kwargs):
                if "init" in command or "merge-tree" in command:
                    self.assertEqual(kwargs["env"]["GIT_CONFIG_NOSYSTEM"], "1")
                    self.assertEqual(kwargs["env"]["GIT_CONFIG_GLOBAL"], os.devnull)
                    self.assertEqual(kwargs["env"]["GIT_ATTR_NOSYSTEM"], "1")
                    self.assertNotIn("GIT_OBJECT_DIRECTORY", kwargs["env"])
                    self.assertNotIn("GIT_DIR", kwargs["env"])
                    self.assertNotIn("GIT_WORK_TREE", kwargs["env"])
                if "merge-tree" in command:
                    inspected.append(Path(command[2]))
                    self.assertEqual(command[-2:], [base, tip])
                    if outcome == "fatal":
                        return subprocess.CompletedProcess(command, 128, b"", b"synthetic detail")
                    if outcome == "timeout":
                        raise subprocess.TimeoutExpired(command, 30)
                return original(command, **kwargs)

            with self.subTest(outcome=outcome):
                before = self.file_snapshot()
                with mock.patch.object(branch_audit.subprocess, "run", side_effect=run):
                    if outcome in ("fatal", "timeout"):
                        with self.assertRaises(branch_audit.AuditError):
                            branch_audit.conflicts(self.repo, tip, base)
                    else:
                        self.assertEqual(branch_audit.conflicts(self.repo, tip, base), outcome == "conflict")
                self.assertEqual(len(inspected), 1)
                self.assertNotEqual(inspected[0], self.repo)
                self.assertFalse(inspected[0].exists(), "temporary merge storage leaked")
                self.assertEqual(self.file_snapshot(), before)


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
        self.assertIsNone(rows["clean"]["dirty"])
        self.assertIsNone(rows["dirty"]["dirty"])
        self.assertIsNone(rows["root-checked"]["dirty"])
        self.assertTrue(rows["locked"]["locked"])
        self.assertFalse(rows["locked"]["missing"])
        self.assertTrue(rows["missing"]["missing"])
        self.assertIsNone(rows["missing"]["dirty"])
        self.assertEqual(document["dangling_worktrees"], 1)


if __name__ == "__main__":
    unittest.main()
