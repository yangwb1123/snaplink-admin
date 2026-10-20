"""Lightweight safety guards; real-browser evidence is a separate opt-in suite."""

import base64
import importlib.util
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch


INTEGRATION = Path(__file__).parents[1] / 'integration'


def load(name, dependencies=None):
    spec = importlib.util.spec_from_file_location(name, INTEGRATION / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    with patch.dict(sys.modules, dependencies or {}):
        spec.loader.exec_module(module)
    return module


rp_module = load('browser_sso_rp')
fixture_module = load('browser_sso_fixture', {'browser_sso_rp': rp_module})
browser_module = load('browser_sso_test', {
    'browser_sso_rp': rp_module, 'browser_sso_fixture': fixture_module,
})


class BrowserFixtureSafetyTest(unittest.TestCase):
    def test_environment_cannot_override_disposable_configuration(self):
        values = {'PATH': '/tools', 'HOME': '/home/fixture', 'PORT': '4444',
                  'BACKEND': 'https://live.test', 'STATIC_DIR': '/live',
                  'SSO_CONFIG_FILE': '/live/config', 'SSO_IDENTITY__BACKEND': 'postgres',
                  'SNAPLINK_TEST_PASSWORD': 'not-for-fixture', 'AUDIT_GOVERNANCE_UPSTREAM': '/live',
                  'AGENT_HUB_UPSTREAM': '/live', 'FORGE_CONVERSATIONS_UPSTREAM': '/live'}
        with patch.dict(os.environ, values, clear=True):
            self.assertEqual(fixture_module.fixture_environment(), {'PATH': '/tools', 'HOME': '/home/fixture'})
            self.assertEqual(dict(os.environ), values)

    def test_configuration_owns_stores_and_explicit_capabilities(self):
        cfg = fixture_module.fixture_config(Path('/temporary'), 'https://127.0.0.1:40001', 40002, [])
        self.assertEqual(cfg['identity']['backend'], 'sqlite')
        self.assertEqual(cfg['identity']['sqlite']['dsn'], 'file:/temporary/identity.db')
        self.assertTrue(cfg['bootstrap']['disabled'])
        self.assertTrue(cfg['oidc']['browser_sso']['enabled'])
        self.assertTrue(cfg['oauth']['auth_code']['enabled'])
        self.assertTrue(cfg['oauth']['refresh_token']['enabled'])
        self.assertFalse(cfg['logging']['access_log']['enabled'])
        self.assertEqual(cfg['server']['listen'], '127.0.0.1:40002')

    def test_failed_start_cleans_only_registered_fixture_resources(self):
        fixture = fixture_module.BrowserFixture(Path('/missing'), Path('/missing'), 'python')
        owned_cleanup = Mock()

        def fail_start():
            fixture.stack.callback(owned_cleanup)
            raise rp_module.FixtureFailure('Controlled fixture failure')
        with patch.object(fixture, 'start', side_effect=fail_start):
            with self.assertRaises(rp_module.FixtureFailure):
                with fixture:
                    self.fail('failed fixture was entered')
        owned_cleanup.assert_called_once_with()

    def test_process_cleanup_does_not_touch_an_exited_process(self):
        process = Mock()
        process.poll.return_value = 0
        fixture_module.stop_process(process)
        process.terminate.assert_not_called()
        process.kill.assert_not_called()

    def test_owned_process_cleanup_is_bounded(self):
        process = Mock()
        process.poll.return_value = None
        process.wait.side_effect = [subprocess.TimeoutExpired('fixture', 10), 0]
        fixture_module.stop_process(process)
        process.terminate.assert_called_once_with()
        process.kill.assert_called_once_with()
        self.assertEqual(process.wait.call_args_list[0].kwargs, {'timeout': 10})

    def test_command_failure_never_exposes_process_output(self):
        result = SimpleNamespace(returncode=1, stdout=b'private output', stderr=b'private output')
        with patch.object(fixture_module.subprocess, 'run', return_value=result):
            with self.assertRaises(rp_module.FixtureFailure) as raised:
                fixture_module.run_checked(['fixture-command'])
        self.assertNotIn('private output', str(raised.exception))

    def test_browser_network_is_restricted_to_owned_origins(self):
        browser = Mock()
        fixture = SimpleNamespace(issuer='https://127.0.0.1:40001',
                                  rps=[SimpleNamespace(origin='http://127.0.0.1:40002')])
        context = browser_module.browser_context(browser, fixture)
        route_request = context.route.call_args.args[1]
        for url, allowed in [('https://127.0.0.1:40001/auth/login', True),
                             ('http://127.0.0.1:40002/callback', True),
                             ('http://127.0.0.1:4444/auth/login', False),
                             ('https://external.test/', False)]:
            with self.subTest(url=url):
                route = Mock()
                route.request.url = url
                route_request(route)
                self.assertEqual(route.continue_.called, allowed)
                self.assertEqual(route.abort.called, not allowed)

    def test_external_resource_counter_keeps_counts_not_urls_or_secrets(self):
        browser = Mock()
        fixture = SimpleNamespace(issuer='https://127.0.0.1:40001', rps=[])
        network = {'external_requests': 0}
        context = browser_module.browser_context(browser, fixture, locale='zh-CN', network=network)
        route_request = context.route.call_args.args[1]
        route = Mock()
        route.request.url = 'https://fonts.gstatic.com/private-fixture.woff2?value=fixture-only'
        route_request(route)
        route.abort.assert_called_once_with()
        route.continue_.assert_not_called()
        self.assertEqual(network, {'external_requests': 1})
        self.assertNotIn('fixture-only', repr(network))
        self.assertEqual(browser.new_context.call_args.kwargs['locale'], 'zh-CN')

    def test_python_gateway_handshakes_only_in_a_bounded_worker(self):
        from tools import robust_proxy
        names = ('BACKEND', 'STATIC', 'BILLING_BACKEND', 'STRIPE_ADAPTER_BACKEND',
                 'FORGE_BACKEND', 'AUDIT_GOVERNANCE_BACKEND', 'AGENT_HUB_BACKEND')
        original = {name: getattr(robust_proxy, name) for name in names}
        with patch.multiple(robust_proxy, **original), \
                patch.object(fixture_module, 'create_tls', return_value=(Path('/cert'), Path('/key'))), \
                patch.object(fixture_module, 'start_server') as start, \
                patch.object(fixture_module.ssl, 'SSLContext') as context:
            fixture_module.python_gateway(object(), Path('/fixture'), Path('/web'),
                                          'http://127.0.0.1:40001', 'http://127.0.0.1:40002')
            server = start.call_args.args[1]
            self.addCleanup(server.server_close)
            tls = context.return_value
            # An accepted connection sends no TLS ClientHello. get_request
            # must still return without performing a listener-thread handshake.
            with socket.create_connection(server.server_address, timeout=2):
                server.get_request()
            accepted = tls.wrap_socket.call_args.args[0]
            self.addCleanup(accepted.close)
            self.assertEqual(accepted.gettimeout(), 5)
            self.assertFalse(tls.wrap_socket.call_args.kwargs['do_handshake_on_connect'])
            tls.wrap_socket.return_value.do_handshake.assert_not_called()

    def test_primary_input_waits_for_focus_and_types_once(self):
        page = Mock()
        field = page.get_by_role.return_value
        assertions = Mock()
        expect = Mock(return_value=assertions)
        events = []
        field.click.side_effect = lambda: events.append('click')
        assertions.to_be_focused.side_effect = lambda **_: events.append('focus')
        page.keyboard.type.side_effect = lambda *_, **__: events.append('type')
        page.evaluate.side_effect = lambda *_: events.append('frame')
        page.keyboard.press.side_effect = lambda *_: events.append('tab')
        assertions.to_have_value.side_effect = lambda *_, **__: events.append('value')
        with patch.dict(sys.modules, {'playwright': SimpleNamespace(),
                                     'playwright.sync_api': SimpleNamespace(expect=expect)}):
            browser_module.type_primary_field(page, 'Password', 'fixture-only')
        self.assertEqual(events, ['click', 'focus', 'frame', 'focus', 'type', 'frame', 'value', 'tab', 'value'])
        page.keyboard.type.assert_called_once_with('fixture-only', delay=50)
        self.assertEqual(assertions.to_have_value.call_count, 2)
        assertions.to_have_value.assert_called_with('fixture-only', timeout=10000)
        self.assertEqual(page.evaluate.call_count, 2)
        for call in page.evaluate.call_args_list:
            self.assertIn('requestAnimationFrame', call.args[0])
            self.assertIn('setTimeout', call.args[0])
            self.assertIn('5000', call.args[0])
            self.assertNotIn('fixture-only', call.args[0])
        page.get_by_role.assert_called_once_with('textbox', name='Password', exact=True)

    def test_primary_input_failure_has_no_secret_details_or_retry(self):
        for stage, type_count in [('to_be_focused', 0), ('to_have_value', 1)]:
            with self.subTest(stage=stage):
                page = Mock()
                assertions = Mock()
                getattr(assertions, stage).side_effect = AssertionError('secret-assertion-fixture')
                expect = Mock(return_value=assertions)
                with patch.dict(sys.modules, {'playwright': SimpleNamespace(),
                                             'playwright.sync_api': SimpleNamespace(expect=expect)}):
                    with self.assertRaises(rp_module.FixtureFailure) as raised:
                        browser_module.type_primary_field(page, 'Password', 'secret-input-fixture')
                self.assertNotIn('secret-', str(raised.exception))
                self.assertTrue(raised.exception.__suppress_context__)
                self.assertEqual(page.keyboard.type.call_count, type_count)
                page.get_by_role.assert_called_once_with('textbox', name='Password', exact=True)
                page.request.post.assert_not_called()

    def test_observer_retains_counts_not_credentials_and_checks_origin(self):
        context = Mock()
        counts = browser_module.observe(context, 'https://127.0.0.1:40001')
        callback = context.on.call_args.args[1]
        request = SimpleNamespace(url='https://127.0.0.1:40001/auth/login', method='POST',
                                  post_data_json={'credential': {'password': 'fixture-only'}})
        callback(request)
        request.url = 'http://127.0.0.1:4444/auth/login'
        callback(request)
        self.assertEqual(counts, {'password': 1, 'resume': 0, 'continuation': 0, 'unexpected': 0})
        self.assertNotIn('fixture-only', repr(counts))


class RelyingPartyBoundaryTest(unittest.TestCase):
    def setUp(self):
        self.rp = rp_module.RelyingParty('rp-fixture', 'Fixture RP', False)
        self.addCleanup(self.rp.close)
        self.rp.issuer = 'https://127.0.0.1:40001'
        self.url = self.rp.authorization_url('')
        self.params = rp_module.urllib.parse.parse_qs(rp_module.urllib.parse.urlsplit(self.url).query)

    def test_request_is_code_pkce_and_bound_to_own_resource(self):
        self.assertEqual(self.params['response_type'], ['code'])
        self.assertEqual(self.params['code_challenge_method'], ['S256'])
        self.assertEqual(self.params['redirect_uri'], [self.rp.redirect])
        self.assertEqual(self.params['resource'], ['rp-fixture-api'])
        self.assertTrue(self.params['nonce'][0])
        self.assertTrue(self.params['state'][0])
        self.assertFalse(self.rp.client_config()['skip_consent'])
        with self.assertRaises(rp_module.FixtureFailure):
            self.rp.authorization_url('prompt=login&prompt=none')
        with self.assertRaises(rp_module.FixtureFailure):
            self.rp.authorization_url('redirect_uri=https://outside.test/')

    def test_issuer_state_and_duplicate_fail_before_token_exchange(self):
        callback = {'iss': [self.rp.issuer], 'state': self.params['state'], 'code': ['fixture-code']}
        with patch.object(rp_module, 'json_request') as network:
            for changes in ({'iss': ['https://outside.test']}, {'state': ['unknown']},
                            {'code': ['fixture-code', 'duplicate']}):
                with self.subTest(changes=changes):
                    with self.assertRaises(rp_module.FixtureFailure):
                        self.rp.exchange({**callback, **changes})
            network.assert_not_called()

    def test_callback_state_is_consumed_once_with_server_side_exchange(self):
        payload = {'client_id': self.rp.client_id, 'aud': 'rp-fixture-api',
                   'scope': 'openid rp-fixture:read', 'iss': self.rp.issuer}
        encoded = base64.urlsafe_b64encode(json.dumps(payload).encode()).decode().rstrip('=')
        tokens = {'access_token': 'test.' + encoded + '.test', 'id_token': 'fixture-id'}
        identity = {'sub': 'fixture-user'}
        callback = {'iss': [self.rp.issuer], 'state': self.params['state'], 'code': ['fixture-code']}
        with patch.object(rp_module, 'json_request', side_effect=[tokens, identity]) as network, \
                patch.object(self.rp, 'verify_identity', return_value=identity) as verify:
            self.rp.exchange(callback)
            with self.assertRaises(rp_module.FixtureFailure):
                self.rp.exchange(callback)
            self.assertEqual(network.call_count, 2)
            verify.assert_called_once_with('fixture-id', self.params['nonce'][0])
            self.assertEqual(network.call_args_list[0].args, (self.rp.issuer + '/token',))
            self.assertNotIn('token', callback)
            self.assertEqual(len(self.rp.grants), 1)


if __name__ == '__main__':
    unittest.main()
