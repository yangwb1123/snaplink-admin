import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import robust_proxy


class RobustProxyRoutingTest(unittest.TestCase):
    def test_api_and_spa_device_routes_are_distinguished(self):
        self.assertTrue(robust_proxy.should_proxy('POST', '/device/verify'))
        self.assertTrue(
            robust_proxy.should_proxy('GET', '/device/verify?check=ABCD-EFGH')
        )
        self.assertFalse(robust_proxy.should_proxy('GET', '/device/verify'))
        self.assertTrue(robust_proxy.should_proxy('PATCH', '/me/profile'))
        self.assertFalse(robust_proxy.should_proxy('GET', '/metadata'))
        self.assertFalse(robust_proxy.should_proxy('GET', '/healthcheck'))

    def test_checkout_uses_the_explicit_adapter_upstream(self):
        with patch.object(
            robust_proxy,
            'STRIPE_ADAPTER_BACKEND',
            'https://stripe-adapter.example.test',
        ):
            self.assertEqual(
                robust_proxy.backend_for(
                    '/api/v1/checkout/sessions?retry=1'
                ),
                'https://stripe-adapter.example.test',
            )
        self.assertEqual(
            robust_proxy.backend_for('/api/v1/admin/clients'),
            robust_proxy.BACKEND,
        )

    def test_static_assets_support_production_app_prefix(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'index.html').write_text('index', encoding='utf-8')
            (root / 'main.dart.js').write_text('main', encoding='utf-8')
            with patch.object(robust_proxy, 'STATIC', root):
                self.assertEqual(
                    robust_proxy.resolve_static_file('/app/main.dart.js'),
                    root / 'main.dart.js',
                )
                self.assertEqual(
                    robust_proxy.resolve_static_file('/portal/security'),
                    root / 'index.html',
                )
                self.assertIsNone(
                    robust_proxy.resolve_static_file('/app/missing.js')
                )

    def test_static_path_cannot_escape_build_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            (root / 'index.html').write_text('index', encoding='utf-8')
            with patch.object(robust_proxy, 'STATIC', root):
                self.assertIsNone(
                    robust_proxy.resolve_static_file('/%2e%2e/secret.txt')
                )


if __name__ == '__main__':
    unittest.main()
