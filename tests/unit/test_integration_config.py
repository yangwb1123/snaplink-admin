import importlib.util
import os
from pathlib import Path
import unittest
from unittest.mock import patch


_PATH = Path(__file__).parents[1] / 'integration' / 'test_config.py'
_SPEC = importlib.util.spec_from_file_location('integration_test_config', _PATH)
assert _SPEC and _SPEC.loader
config_module = importlib.util.module_from_spec(_SPEC)
_SPEC.loader.exec_module(config_module)


class IntegrationConfigTest(unittest.TestCase):
    def test_defaults_only_cover_local_service_origins(self):
        with patch.dict(os.environ, {}, clear=True):
            config = config_module.IntegrationConfig.from_environment()

        self.assertEqual(config.api_url, 'http://localhost:8080')
        self.assertEqual(config.proxy_url, 'http://localhost:4444')
        self.assertEqual(config.username, '')
        with self.assertRaises(config_module.IntegrationConfigurationError):
            config.require_credentials()

    def test_environment_drives_urls_credentials_and_login_payload(self):
        values = {
            'SNAPLINK_API_URL': 'https://api.example.test/',
            'SNAPLINK_PROXY_URL': 'http://127.0.0.1:4555/',
            'SNAPLINK_TEST_USERNAME': 'operator',
            'SNAPLINK_TEST_PASSWORD': 'test-only-secret',
            'SNAPLINK_TEST_CLIENT_ID': 'console-e2e',
            'SNAPLINK_TEST_USER_ID': 'user-42',
        }
        with patch.dict(os.environ, values, clear=True):
            config = config_module.IntegrationConfig.from_environment()

        self.assertEqual(config.api_admin_url, 'https://api.example.test/api/v1/admin')
        self.assertEqual(config.proxy_host, '127.0.0.1')
        self.assertEqual(config.proxy_port, 4555)
        self.assertEqual(config.login_payload()['credential']['username'], 'operator')
        self.assertEqual(config.login_payload()['client_id'], 'console-e2e')
        self.assertEqual(config.user_id, 'user-42')
        self.assertEqual(config.proxy_environment()['BACKEND'], config.api_url)
        self.assertTrue(config.manages_local_proxy)

    def test_invalid_origins_fail_before_network_access(self):
        with patch.dict(
            os.environ, {'SNAPLINK_API_URL': 'localhost:8080'}, clear=True
        ):
            with self.assertRaises(config_module.IntegrationConfigurationError):
                config_module.IntegrationConfig.from_environment()

    def test_every_live_script_uses_shared_config_without_baked_credentials(self):
        integration_dir = _PATH.parent
        for script in integration_dir.glob('*.py'):
            if script.name == 'test_config.py':
                continue
            source = script.read_text()
            with self.subTest(script=script.name):
                self.assertIn('from test_config import CONFIG', source)
                self.assertNotIn("'password': 'admin'", source)
                self.assertNotIn('"password": "admin"', source)


if __name__ == '__main__':
    unittest.main()
