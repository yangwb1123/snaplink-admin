"""Documentation contracts for generated route-catalog facts."""
import re
import shlex
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
ROUTES_BLOCK = re.compile(r"const routes\s*=\s*'''(?P<body>.*?)''';", re.DOTALL)
ROUTE_LINE = re.compile(r"^(?P<method>[A-Z]+)\s+(?P<path>/\S+)\s*$")
SCOPES = (
    "/api/v1/admin/",
    "/api/v1/audit/",
    "/api/v1/compliance/",
    "/api/v1/netpolicy/",
    "/api/v1/scim/",
)


class DocumentationContractsTest(unittest.TestCase):
    def test_deploy_local_proxy_example_is_one_copyable_shell_command(self):
        deploy = (ROOT / "DEPLOY.md").read_text(encoding="utf-8")
        blocks = re.findall(r"```bash\n(.*?)```", deploy, re.DOTALL)
        expected = {
            "SNAPLINK_API_URL",
            "SNAPLINK_PROXY_PORT",
            "SNAPLINK_STRIPE_ADAPTER_URL",
            "AUDIT_GOVERNANCE_UPSTREAM",
        }
        proxy_blocks = [
            block
            for block in blocks
            if "python3 tools/robust_proxy.py" in block
            and all(f"{name}=" in block for name in expected)
        ]
        self.assertTrue(proxy_blocks, "copyable local proxy example is missing")

        lines = [line.strip() for line in proxy_blocks[0].splitlines() if line.strip()]
        self.assertTrue(
            all(line.endswith("\\") for line in lines[:-1]),
            "continued proxy command lines must end with a POSIX shell continuation",
        )

        # Collapse only explicit shell line continuations, then parse the
        # command so a documentation-only line cannot hide a split assignment.
        command = re.sub(r"\\[ \t]*\n", " ", proxy_blocks[0]).strip()
        tokens = shlex.split(command, posix=True)
        self.assertEqual(tokens[-2:], ["python3", "tools/robust_proxy.py"])
        assignments = tokens[:-2]
        self.assertEqual(
            {token.split("=", 1)[0] for token in assignments}, expected
        )
        self.assertIn(
            "AUDIT_GOVERNANCE_UPSTREAM=<your-audit-governance-origin>",
            assignments,
        )

    def test_feature_coverage_uses_scoped_route_catalog_count(self):
        source = (ROOT / "lib/api/snaplink_admin_types.dart").read_text(
            encoding="utf-8"
        )
        match = ROUTES_BLOCK.search(source)
        self.assertIsNotNone(match, "routes block is missing")

        routes = []
        for line in match.group("body").splitlines():
            if not line.strip():
                continue
            route = ROUTE_LINE.fullmatch(line)
            self.assertIsNotNone(route, f"unparseable route line: {line!r}")
            routes.append((route["method"], route["path"]))

        scoped_count = sum(
            path.startswith(SCOPES) for _, path in routes
        )
        coverage = (ROOT / "docs/FEATURE_COVERAGE.md").read_text(encoding="utf-8")
        self.assertRegex(
            coverage,
            rf"管理、审计、合规、网络策略及 SCIM 目录共\s*{scoped_count}\s*个\s*精确操作",
        )


if __name__ == "__main__":
    unittest.main()
