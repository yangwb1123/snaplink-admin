import json
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
        self.assertTrue(robust_proxy.should_proxy('GET', '/readyz'))
        self.assertFalse(robust_proxy.should_proxy('GET', '/readyzcheck'))
        self.assertTrue(robust_proxy.should_proxy('GET', '/end_session?id_token_hint=fixture'))
        self.assertTrue(robust_proxy.should_proxy('GET', '/check_session_iframe'))
        self.assertFalse(robust_proxy.should_proxy('GET', '/end_session-evil'))
        self.assertFalse(robust_proxy.should_proxy('GET', '/check_session_iframe-evil'))

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

    def test_agent_hub_has_its_own_route_and_missing_config_returns_json_503(self):
        hub = 'https://agent-hub.example.test'
        with patch.object(robust_proxy, 'AGENT_HUB_BACKEND', hub):
            self.assertEqual(
                robust_proxy.backend_for('/api/v1/agent/instances'), hub
            )
            self.assertEqual(
                robust_proxy._build_backend_url(
                    '/api/v1/agent/sessions?after=session%2F1'
                )[0],
                f'{hub}/api/v1/agent/sessions?after=session%2F1',
            )
        with patch.object(robust_proxy, 'AGENT_HUB_BACKEND', ''):
            self.assertEqual(
                robust_proxy.backend_for('/api/v1/agent/instances'), ''
            )
            with patch.object(robust_proxy, '_forward_response') as forward:
                robust_proxy.proxy_request(
                    object(), 'GET', '/api/v1/agent/instances', {}, None
                )
            args = forward.call_args.args
            self.assertEqual(args[1], 503)
            self.assertEqual(
                json.loads(args[3])['error']['code'],
                'agent_hub_unconfigured',
            )

    def test_audit_compatibility_paths_rewrite_request_targets(self):
        governance = 'http://audit-governance.example.test:8089'
        with patch.object(
            robust_proxy,
            'AUDIT_GOVERNANCE_BACKEND',
            governance,
        ):
            cases = {
                '/api/v1/audit/events':
                    f'{governance}/api/v1/compat/snaplink/audit/events',
                '/api/v1/audit/events?limit=1&cursor=%2F':
                    f'{governance}/api/v1/compat/snaplink/audit/events?limit=1&cursor=%2F',
                '/api/v1/audit/events/event%2Fid?tenant=t%2F1&empty=':
                    f'{governance}/api/v1/compat/snaplink/audit/events/event%2Fid?tenant=t%2F1&empty=',
                '/api/v1/audit/facets?outcome=success':
                    f'{governance}/api/v1/compat/snaplink/audit/facets?outcome=success',
            }
            for request_path, expected_url in cases.items():
                with self.subTest(request_path=request_path):
                    url, query = robust_proxy._build_backend_url(request_path)
                    self.assertEqual(url, expected_url)
                    self.assertEqual(query, request_path.split('?', 1)[1] if '?' in request_path else '')
                    self.assertEqual(
                        robust_proxy.backend_for(request_path), governance
                    )

            # The compatibility locations are exact/segment-bounded, matching
            # nginx rather than capturing lookalikes or an empty detail segment.
            for request_path in (
                '/api/v1/audit/events-evil?limit=1',
                '/api/v1/audit/events/',
                '/api/v1/audit/facets/',
            ):
                with self.subTest(non_route=request_path):
                    url, _ = robust_proxy._build_backend_url(request_path)
                    self.assertEqual(url, f'{robust_proxy.BACKEND}{request_path}')
                    self.assertEqual(
                        robust_proxy.backend_for(request_path), robust_proxy.BACKEND
                    )

        # An absent optional upstream must fail closed, never become the core
        # Snaplink backend through an implicit fallback.
        with patch.object(robust_proxy, 'AUDIT_GOVERNANCE_BACKEND', ''):
            self.assertNotEqual(
                robust_proxy.backend_for('/api/v1/audit/events'),
                robust_proxy.BACKEND,
            )

    def test_billing_and_forge_paths_use_independent_upstreams(self):
        with patch.multiple(robust_proxy,
                            BILLING_BACKEND='https://billing.test',
                            FORGE_BACKEND='https://forge.test'):
            for path in ('/api/v1/admin/commerce/plans', '/api/v1/commerce',
                         '/api/v1/metering/usage?tenant=t%2F1'):
                with self.subTest(path=path):
                    self.assertEqual(robust_proxy.backend_for(path), 'https://billing.test')
            for path in ('/api/v1/conversations',
                         '/api/v1/conversations/c%2F1/prompts?cursor=%2F',
                         '/api/v1/conversation-changes/stream?wait_ms=15000'):
                with self.subTest(path=path):
                    self.assertEqual(robust_proxy._build_backend_url(path)[0],
                                     f'https://forge.test{path}')
            for path in ('/api/v1/admin/commerce-x', '/api/v1/commerce-x',
                         '/api/v1/metering-x', '/api/v1/conversations-x',
                         '/api/v1/conversation-changes-x', '/api/v1/agent-x',
                         '/api/v1/checkout/sessions-extra'):
                with self.subTest(lookalike=path):
                    self.assertEqual(robust_proxy.backend_for(path), robust_proxy.BACKEND)

    def test_every_missing_independent_service_returns_json_without_fallback(self):
        cases = (
            ('/api/v1/agent/instances', 'agent_hub', 'AGENT_HUB_UPSTREAM'),
            ('/api/v1/admin/commerce/plans', 'billing', 'SNAPLINK_BILLING_UPSTREAM'),
            ('/api/v1/checkout/sessions', 'stripe_adapter', 'SNAPLINK_STRIPE_ADAPTER_UPSTREAM'),
            ('/api/v1/audit/events', 'audit_governance', 'AUDIT_GOVERNANCE_UPSTREAM'),
            ('/api/v1/conversations', 'forge', 'FORGE_CONVERSATIONS_UPSTREAM'),
        )
        with patch.multiple(robust_proxy, AGENT_HUB_BACKEND='', BILLING_BACKEND='',
                            STRIPE_ADAPTER_BACKEND='', AUDIT_GOVERNANCE_BACKEND='',
                            FORGE_BACKEND=''):
            for path, service, setting in cases:
                with self.subTest(path=path):
                    with patch.object(robust_proxy, '_forward_response') as forward, \
                            patch.object(robust_proxy.UPSTREAM_OPENER, 'open') as upstream:
                        robust_proxy.proxy_request(object(), 'GET', path, {}, None)
                    self.assertEqual(forward.call_args.args[1], 503)
                    error = json.loads(forward.call_args.args[3])['error']
                    self.assertEqual(error['code'], f'{service}_unconfigured')
                    self.assertIn(setting, error['message'])
                    upstream.assert_not_called()

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
