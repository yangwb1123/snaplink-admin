"""Unit tests for the lcov coverage gate in checks/coverage.py.

The gate previously reported 0.0% for lib/ subtrees because the parser
produced keys relative to lib/ ("screens/portal") while engineering.yaml
declared repository-relative targets ("lib/screens/portal"). These tests
pin the aggregation semantics so the gate cannot silently pass on wrong
numbers again.
"""
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from checks.coverage import parse_lcov_line_coverage, check_coverage_targets


class CoverageParserTest(unittest.TestCase):
    def _write_lcov(self, lines: list[str]) -> Path:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        path = Path(directory.name) / "lcov.info"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        return path

    def _lcov(self, file_path: str, hits: list[int]) -> list[str]:
        lines = [f"SF:{file_path}"]
        for line_no, hit in enumerate(hits, start=1):
            lines.append(f"DA:{line_no},{hit}")
        lines.append("end_of_record")
        return lines

    def test_lib_aggregates_every_lib_file(self):
        lcov = self._write_lcov(
            self._lcov("lib/screens/portal/overview_tab.dart", [1, 0, 1])
            + self._lcov("lib/api/portal_api.dart", [1, 1, 1])
            + self._lcov("test/portal_screens_test.dart", [1, 1])
        )
        coverage = parse_lcov_line_coverage(lcov)
        # Whole-project: 7/8 hit. Whole-lib: 5/6. Subtree: 2/3.
        self.assertEqual(coverage["."], 87.5)
        self.assertEqual(coverage["lib"], 83.3)
        self.assertEqual(coverage["lib/screens/portal"], 66.7)
        self.assertNotIn("screens/portal", coverage)

    def test_subtree_keys_match_engineering_yaml_targets(self):
        lcov = self._write_lcov(
            self._lcov("lib/screens/oidc_login/oidc_login_screen.dart", [1, 1])
            + self._lcov("lib/screens/oidc_login/mfa_view.dart", [0, 0])
        )
        coverage = parse_lcov_line_coverage(lcov)
        self.assertEqual(coverage["lib/screens/oidc_login"], 50.0)
        self.assertNotIn("screens/oidc_login", coverage)

    def test_gate_passes_when_targets_are_met(self):
        lcov = self._write_lcov(
            self._lcov("lib/main.dart", [1, 1])
            + self._lcov("lib/screens/portal/overview_tab.dart", [1, 1])
            + self._lcov("lib/screens/oidc_login/mfa_view.dart", [1, 1])
        )
        coverage = parse_lcov_line_coverage(lcov)
        targets = {
            ".": 50,
            "lib": 50,
            "lib/screens/oidc_login": 50,
            "lib/screens/portal": 50,
        }
        self.assertEqual(check_coverage_targets(coverage, targets), 0)

    def test_gate_fails_when_a_subtree_target_is_missed(self):
        lcov = self._write_lcov(
            self._lcov("lib/screens/portal/overview_tab.dart", [0, 0])
            + self._lcov("lib/screens/oidc_login/mfa_view.dart", [1, 1])
        )
        coverage = parse_lcov_line_coverage(lcov)
        targets = {
            ".": 0,
            "lib": 0,
            "lib/screens/oidc_login": 50,
            "lib/screens/portal": 50,
        }
        self.assertEqual(check_coverage_targets(coverage, targets), 1)

    def test_missing_coverage_data_reports_zero(self):
        lcov = self._write_lcov(
            self._lcov("lib/screens/portal/overview_tab.dart", [0, 0])
        )
        coverage = parse_lcov_line_coverage(lcov)
        self.assertEqual(coverage.get("lib/screens/oidc_login", 0.0), 0.0)


if __name__ == "__main__":
    unittest.main()
