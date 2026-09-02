"""Documentation contracts for generated route-catalog facts."""
import re
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
